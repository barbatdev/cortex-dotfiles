// Pure model of the refactoria-github mod: gh JSON in, rows out.
// Tested with node --test tests/herdr_github_test.mjs; no Herdr imports here.

// owner/name from an origin URL (ssh, https, or an ssh host alias).
export function slug(url) {
  const m = String(url ?? "").trim().match(/[:/]([^/:\s]+\/[^/\s]+?)(?:\.git)?\/?$/);
  return m ? m[1] : null;
}

const FAIL = ["FAILURE", "ERROR", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED"];
const SKIP = ["SKIPPED", "NEUTRAL", "CANCELLED", "STALE"];

// One check (CheckRun or StatusContext) as pass | fail | pending | skip.
export function checkState(c) {
  if (c?.__typename === "StatusContext") {
    if (FAIL.includes(c.state)) return "fail";
    return c.state === "SUCCESS" ? "pass" : "pending";
  }
  if (c?.status !== "COMPLETED") return "pending";
  if (FAIL.includes(c.conclusion)) return "fail";
  if (SKIP.includes(c.conclusion)) return "skip";
  return "pass";
}

const ORDER = { fail: 0, pending: 1, pass: 2, skip: 3 };

// All of a PR's checks: one state (a failure wins, then anything running), counts, and items.
export function rollup(list) {
  const items = (list ?? []).map((c) => ({
    name: c.name || c.context || "check",
    state: checkState(c),
    url: c.detailsUrl || c.targetUrl || null,
  })).sort((a, b) => ORDER[a.state] - ORDER[b.state]);
  const n = (s) => items.filter((i) => i.state === s).length;
  const r = { state: "none", pass: n("pass"), fail: n("fail"), pending: n("pending"), items };
  if (r.fail) r.state = "fail";
  else if (r.pending) r.state = "pending";
  else if (items.length) r.state = "pass";
  return r;
}

export function reviewLabel(decision) {
  return { APPROVED: "approved", CHANGES_REQUESTED: "changes", REVIEW_REQUIRED: "review" }[decision] ?? "";
}

const REVIEW_STATE = { APPROVED: "approved", CHANGES_REQUESTED: "changes", COMMENTED: "commented", DISMISSED: "dismissed", PENDING: "pending" };

// One open PR from `gh pr list --json`.
export function prRow(pr) {
  const reviewers = [
    ...(pr.latestReviews ?? []).map((r) => ({ name: r.author?.login ?? "", state: REVIEW_STATE[r.state] ?? "commented" })),
    ...(pr.reviewRequests ?? []).map((r) => ({ name: r.login || r.name || r.slug || "", state: "requested" })),
  ].filter((r) => r.name);
  return {
    number: pr.number,
    title: pr.title ?? "",
    url: pr.url,
    draft: Boolean(pr.isDraft),
    branch: pr.headRefName ?? "",
    author: pr.author?.login ?? "",
    review: reviewLabel(pr.reviewDecision),
    checks: rollup(pr.statusCheckRollup),
    additions: pr.additions ?? 0,
    deletions: pr.deletions ?? 0,
    files: pr.changedFiles ?? 0,
    reviewers,
  };
}

function issueRow(i, now) {
  const author = i.author?.login ?? "";
  return {
    number: i.number, title: i.title ?? "", url: i.url, author,
    initials: initials(author),
    tone: avatarTone(author),
    age: relTime(i.createdAt, now),
    comments: Array.isArray(i.comments) ? i.comments.length : Number(i.comments) || 0,
    labels: (i.labels ?? []).map((l) => l.name),
    pills: (i.labels ?? []).map((l) => ({ name: l.name, ...labelTone(l) })),
  };
}

// Issues assigned to me, and recent open ones that are not already listed there.
export function issueGroups(assigned, recent, now = Date.now()) {
  const mine = (assigned ?? []).map((i) => issueRow(i, now));
  const seen = new Set(mine.map((i) => i.number));
  return { assigned: mine, recent: (recent ?? []).filter((i) => !seen.has(i.number)).map((i) => issueRow(i, now)) };
}

// One workflow run from `gh run list --json`.
export function runRow(r) {
  let state = "pending";
  if (r.status === "completed") {
    const c = String(r.conclusion ?? "").toUpperCase();
    state = FAIL.includes(c) ? "fail" : SKIP.includes(c) ? "skip" : "pass";
  }
  return {
    id: r.databaseId,
    title: r.displayTitle ?? "",
    workflow: r.workflowName ?? "",
    branch: r.headBranch ?? "",
    event: r.event ?? "",
    url: r.url,
    at: r.createdAt ?? "",
    state,
  };
}

// The web page of a notification: its API subject url turned into a github.com one.
export function notificationUrl(n) {
  const repo = n?.repository?.html_url;
  const api = n?.subject?.url;
  const m = api && api.match(/^https:\/\/api\.github\.com\/repos\/([^/]+\/[^/]+)\/(pulls|issues|commits|releases)\/([^/?#]+)/);
  if (m) {
    const base = `https://github.com/${m[1]}`;
    if (m[2] === "pulls") return `${base}/pull/${m[3]}`;
    if (m[2] === "issues") return `${base}/issues/${m[3]}`;
    if (m[2] === "commits") return `${base}/commit/${m[3]}`;
    return `${base}/releases`;
  }
  return repo || "https://github.com/notifications";
}

const REASON = { review_requested: "review", mention: "mention", team_mention: "mention", assign: "assigned", author: "author", comment: "comment", ci_activity: "ci", state_change: "state", subscribed: "watching" };
const RANK = { review: 0, mention: 1 };

// Notifications: review requests, then mentions, then the rest; newest first within each.
export function inbox(list) {
  return (list ?? []).map((n) => ({
    id: n.id,
    reason: REASON[n.reason] ?? n.reason ?? "",
    title: n.subject?.title ?? "",
    type: n.subject?.type ?? "",
    repo: n.repository?.full_name ?? "",
    unread: Boolean(n.unread),
    at: n.updated_at ?? "",
    url: notificationUrl(n),
  })).sort((a, b) => (RANK[a.reason] ?? 2) - (RANK[b.reason] ?? 2) || (a.at < b.at ? 1 : a.at > b.at ? -1 : 0));
}

// Tab badges: how many of each (CI counts failures); null while not loaded.
export function counts({ prs, issues, runs, inbox: notes }) {
  return {
    prs: prs ? prs.length : null,
    issues: issues ? issues.assigned.length + issues.recent.length : null,
    ci: runs ? runs.filter((r) => r.state === "fail").length : null,
    inbox: notes ? notes.length : null,
  };
}

// What the panel's timer should load now: "switch" when the active space's place
// changed (always, even over a running load, which then goes stale), "refresh"
// for the same place while shown, on appearing or once `every` ms passed, else null.
export function nextFetch({ key, last, visible, appeared, at, now, loading, every }) {
  if (key !== last) return "switch";
  if (!key || !visible || loading) return null;
  return appeared || now - at > every ? "refresh" : null;
}

// ---- Artboard 02 · Rich tabs (design/herdr-github-panel/02-rich-tabs.html) ----

const ms = (iso) => {
  const t = Date.parse(iso ?? "");
  return Number.isFinite(t) && t > 0 ? t : null;
};

// Short labeled age: now, 5m, 3h, 1d, 2mo, 1y; "" when unknown.
export function relTime(iso, now = Date.now()) {
  const t = ms(iso);
  if (t === null) return "";
  const s = Math.max(0, (now - t) / 1000);
  if (s < 60) return "now";
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  if (s < 30 * 86400) return `${Math.floor(s / 86400)}d`;
  if (s < 365 * 86400) return `${Math.floor(s / (30 * 86400))}mo`;
  return `${Math.floor(s / (365 * 86400))}y`;
}

// "Synced 1m ago" shortened to the age alone (the header shows a clock glyph before it).
export function syncedLabel(at, now = Date.now()) {
  return at ? relTime(new Date(at).toISOString(), now) : "";
}

// Run or check length as "1m 02s"; "" without both ends (GitHub's zero date counts as none).
export function duration(start, end) {
  const a = ms(start), b = ms(end);
  if (a === null || b === null || b < a || a < Date.UTC(2000, 0, 1)) return "";
  const s = Math.round((b - a) / 1000);
  return `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, "0")}s`;
}

// Two initials from a login: its first two words, else its first two letters.
export function initials(login) {
  const words = String(login ?? "").split(/[-_.\s]+/).filter(Boolean);
  if (!words.length) return "?";
  const out = words.length > 1 ? words[0][0] + words[1][0] : words[0].slice(0, 2);
  return out.toUpperCase();
}

// Avatar background (artboard: #F2EFFA initials >= 10.5:1 on each).
const TONES = ["#3B2D5C", "#1F3A4A", "#3A2A1E", "#203A2E"];
export function avatarTone(login) {
  let h = 0;
  for (const ch of String(login ?? "")) h = (h * 31 + ch.codePointAt(0)) >>> 0;
  return TONES[h % TONES.length];
}

// Five segments, GitHub style: additions green, deletions red, in proportion; empty when no change.
export function sizeBar(additions, deletions) {
  const a = Math.max(0, additions || 0), d = Math.max(0, deletions || 0);
  const total = a + d;
  if (!total) return { plus: 0, minus: 0, empty: 5 };
  if (total < 5) return { plus: a, minus: d, empty: 5 - total };
  const plus = Math.round((5 * a) / total);
  return { plus, minus: 5 - plus, empty: 0 };
}

// ---- colour helpers (WCAG 2.x relative luminance) ----
const rgb = (hex) => {
  const m = String(hex ?? "").replace(/^#/, "").match(/^([0-9a-f]{6})$/i);
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};
const hex = (c) => "#" + c.map((v) => Math.round(Math.min(255, Math.max(0, v))).toString(16).padStart(2, "0")).join("").toUpperCase();
const lum = (hx) => {
  const [r, g, b] = rgb(hx).map((v) => { const c = v / 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
export function contrast(a, b) {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}
// `weight` of a over b.
export function mix(a, b, weight) {
  const x = rgb(a), y = rgb(b);
  return hex(x.map((v, i) => v * weight + y[i] * (1 - weight)));
}

const PANEL = "#17102A", RAISED = "#2C2144";
// Artboard pills: GitHub hue toned to the palette, text on its own 14% tint.
const KNOWN_LABELS = {
  enhancement: { text: "#8FDCE3", bg: "#282D44", border: "#4A6E7E" },
  bug: { text: "#FF8FA3", bg: "#37223B", border: "#7A4A62" },
  "status:approved": { text: "#7FE0B0", bg: "#262D3D", border: "#48705F" },
  docs: { text: "#8CC8FF", bg: "#272A48", border: "#4A638A" },
  documentation: { text: "#8CC8FF", bg: "#272A48", border: "#4A638A" },
  stale: { text: "#C7B9A0", bg: "#30283B", border: "#6A5F64" },
  "needs-triage": { text: "#FFC857", bg: "#372A30", border: "#7A6440" },
};

// Any GitHub label colour: lightened toward white until the text passes AA on its tint over
// the panel and over a raised (hovered) row.
export function labelTone(label) {
  const known = KNOWN_LABELS[String(label?.name ?? "").toLowerCase()];
  if (known) return { ...known };
  let text = rgb(label?.color) ? `#${String(label.color).toUpperCase()}` : "#C7A6FF";
  const ok = (c) => contrast(c, mix(c, PANEL, 0.14)) >= 4.5 && contrast(c, mix(c, RAISED, 0.14)) >= 4.5;
  for (let i = 0; i < 40 && !ok(text); i++) text = mix("#FFFFFF", text, 0.12);
  return { text, bg: mix(text, PANEL, 0.14), border: mix(text, PANEL, 0.4) };
}

// ---- pull requests ----

// The rollup as the card's word: "2 failing", "1 running", "5/5", "No checks yet".
function checkWord(ck) {
  if (ck.state === "fail") return { state: "fail", word: `${ck.fail} failing` };
  if (ck.state === "pending") return { state: "pending", word: `${ck.pending} running` };
  if (ck.state === "pass") return { state: "pass", word: `${ck.pass}/${ck.items.length - ck.items.filter((i) => i.state === "skip").length}` };
  return { state: "none", word: "No checks yet" };
}

// A PR card (3 lines): line 1 glyph, #num title, age; line 2 state + links; line 3 checks, reviewers, size.
export function prCard(raw, me, now = Date.now()) {
  const pr = prRow(raw);
  const merge = raw.isDraft ? "draft" : { CONFLICTING: "conflict", MERGEABLE: "mergeable" }[raw.mergeable] ?? "unknown";
  let state;
  if (pr.draft) state = { kind: "draft", word: "Draft" };
  else if (merge === "conflict") state = { kind: "conflict", word: "Merge conflict" };
  else if (pr.review === "changes") state = { kind: "changes", word: "Changes requested" };
  else if (pr.review === "approved") state = { kind: "approved", word: merge === "mergeable" && ["pass", "none"].includes(pr.checks.state) ? "Approved · ready to merge" : "Approved" };
  else state = { kind: "waiting", word: "Awaiting review" };
  const requested = Boolean(me) && (raw.reviewRequests ?? []).some((r) => r.login === me);
  return {
    ...pr,
    age: relTime(raw.createdAt, now),
    updated: relTime(raw.updatedAt, now),
    initials: initials(pr.author),
    tone: avatarTone(pr.author),
    merge,
    state,
    checkWord: checkWord(pr.checks),
    linked: (raw.closingIssuesReferences ?? []).map((i) => i.number).filter((n) => n != null),
    size: sizeBar(pr.additions, pr.deletions),
    reviewers: pr.reviewers.map((r) => ({ ...r, initials: initials(r.name), tone: avatarTone(r.name), me: r.name === me })),
    group: requested ? "requested" : me && pr.author === me ? "yours" : "others",
  };
}

const GROUPS = [["requested", "Review requested"], ["yours", "Yours"], ["others", "Others"]];
export function prGroups(cards) {
  return GROUPS.map(([id, label]) => ({ id, label, items: (cards ?? []).filter((c) => c.group === id) })).filter((g) => g.items.length);
}

// Why the PR cannot merge, in one line.
export function blocker(card) {
  if (card.draft) return "Draft: not ready for review";
  if (card.merge === "conflict") return "Blocked: merge conflict";
  const f = card.checks.fail;
  if (f) return `Blocked: ${f} check${f === 1 ? "" : "s"} failing`;
  if (card.review === "changes") return "Blocked: changes requested";
  if (card.review === "approved") return card.checks.pending ? "Waiting: checks running" : "Ready to merge";
  return "Blocked: review required";
}

// The Actions run id behind a check's details URL.
export function runIdOf(url) {
  const m = String(url ?? "").match(/^https:\/\/github\.com\/[^/]+\/[^/]+\/actions\/runs\/(\d+)/);
  return m ? Number(m[1]) : null;
}

// `gh pr view N --json files,statusCheckRollup`, loaded when a card expands.
export function prDetail(json) {
  const files = json?.files ?? [];
  const top = [...files].sort((a, b) => (b.additions + b.deletions) - (a.additions + a.deletions)).slice(0, 3)
    .map((f) => ({ path: f.path, additions: f.additions ?? 0, deletions: f.deletions ?? 0 }));
  const checks = rollup(json?.statusCheckRollup).items.map((c, i) => {
    const src = (json.statusCheckRollup ?? []).find((x) => (x.name || x.context || "check") === c.name && (x.detailsUrl || x.targetUrl || null) === c.url) ?? {};
    return { ...c, duration: duration(src.startedAt, src.completedAt), runId: runIdOf(c.url) };
  });
  return { files: { count: files.length, top }, checks };
}

// Runs worth `gh run rerun <id> --failed`: those of failed checks, once each.
export function rerunTargets(checks) {
  return [...new Set((checks ?? []).filter((c) => c.state === "fail" && c.runId).map((c) => c.runId))];
}

// ---- CI ----
const RUN_WORD = { pass: "Passed", fail: "Failed", pending: "Running", skip: "Skipped" };
export function canRerun(r) {
  return r?.state === "fail" && r?.id != null && r?.done !== false;
}
export function runCard(raw, now = Date.now()) {
  const r = runRow(raw);
  const c = String(raw.conclusion ?? "").toLowerCase();
  const done = raw.status === "completed";
  return {
    ...r,
    done,
    word: done && c === "cancelled" ? "Cancelled" : RUN_WORD[r.state],
    age: relTime(raw.createdAt, now),
    duration: done ? duration(raw.startedAt, raw.updatedAt) : "",
    rerun: done && canRerun({ ...r, done }),
  };
}

// `gh run view <id> --json jobs`: "job › step" of the first failure, or the job alone.
export function failedStep(json) {
  const bad = (x) => ["failure", "timed_out", "startup_failure"].includes(String(x?.conclusion ?? "").toLowerCase());
  const job = (json?.jobs ?? []).find(bad);
  if (!job) return null;
  const step = (job.steps ?? []).find(bad);
  return step ? `${job.name} › ${step.name}` : job.name;
}

// The attention dot of each tab: something there needs the user.
export function attention({ prs, runs, inbox: notes, me }) {
  const mine = (prs ?? []).filter((c) => me && c.author === me);
  const branches = new Set(["main", "master", ...mine.map((c) => c.branch)]);
  const latest = new Map();
  for (const r of runs ?? []) {
    const k = `${r.workflow}\u0000${r.branch}`;
    if (!latest.has(k) || r.id > latest.get(k).id) latest.set(k, r);
  }
  return {
    prs: (prs ?? []).some((c) => c.group === "requested") || mine.some((c) => c.checks.state === "fail" || c.review === "changes"),
    issues: false,
    ci: [...latest.values()].some((r) => r.state === "fail" && branches.has(r.branch)),
    inbox: (notes ?? []).some((n) => n.unread),
  };
}

// ---- Start work / Mark read ----

// gs (gs/env.go) works on this org's repos only; `gs issue <repo> <n>` makes the worktree
// (~/dev/worktrees/<repo>-issue-<n>, branch <prefix>/<n>-<slug>) and opens the agent itself.
export const GS_ORG = "Gentleman-Programming";

// A new space at the repo's folder, on the space's machine, running `gs issue` in a login shell
// that stays open afterwards (gs prints the kickoff for repos it does not open an agent on).
export function startWork(repo, number, folder, machine) {
  const [owner, name] = String(repo ?? "").split("/");
  const n = String(number);
  if (owner !== GS_ORG || !/^[A-Za-z0-9._-]+$/.test(name ?? "") || !/^\d+$/.test(n)) return null;
  const command = `gs issue ${name} ${n}`;
  return {
    name: `${name} #${n}`,
    folder,
    machine: machine ?? null,
    argv: ["sh", "-c", 'exec "${SHELL:-sh}" -lic "$0"', `${command}; exec "\${SHELL:-sh}" -l`],
    command,
  };
}

// `gh` arguments that mark one notification thread read, or all of them.
export function markReadArgs(id) {
  return /^\d+$/.test(String(id)) ? ["api", "-X", "PATCH", `notifications/threads/${id}`, "--silent"] : null;
}
export const markAllArgs = () => ["api", "-X", "PUT", "notifications", "--silent"];

// The inbox without a row that was just marked read.
export function withoutNote(list, id) {
  return list ? list.filter((n) => n.id !== id) : list;
}
