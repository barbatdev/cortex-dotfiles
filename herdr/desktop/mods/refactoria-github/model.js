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

function issueRow(i) {
  return { number: i.number, title: i.title ?? "", url: i.url, author: i.author?.login ?? "", labels: (i.labels ?? []).map((l) => l.name) };
}

// Issues assigned to me, and recent open ones that are not already listed there.
export function issueGroups(assigned, recent) {
  const mine = (assigned ?? []).map(issueRow);
  const seen = new Set(mine.map((i) => i.number));
  return { assigned: mine, recent: (recent ?? []).filter((i) => !seen.has(i.number)).map(issueRow) };
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
