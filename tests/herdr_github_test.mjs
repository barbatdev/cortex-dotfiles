// Model of the refactoria-github mod: node --test tests/herdr_github_test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  slug, checkState, rollup, reviewLabel, prRow, issueGroups, runRow, notificationUrl, inbox, counts,
} from "../herdr/desktop/mods/refactoria-github/model.js";

test("slug reads owner/name from ssh, https and host-alias remotes", () => {
  assert.equal(slug("git@github.com:acme/app.git\n"), "acme/app");
  assert.equal(slug("https://github.com/acme/app"), "acme/app");
  assert.equal(slug("git@github-workdev:acme/app.git"), "acme/app");
  assert.equal(slug("not a url"), null);
});

test("check state covers check runs and status contexts", () => {
  assert.equal(checkState({ __typename: "CheckRun", status: "COMPLETED", conclusion: "SUCCESS" }), "pass");
  assert.equal(checkState({ __typename: "CheckRun", status: "COMPLETED", conclusion: "FAILURE" }), "fail");
  assert.equal(checkState({ __typename: "CheckRun", status: "IN_PROGRESS", conclusion: "" }), "pending");
  assert.equal(checkState({ __typename: "CheckRun", status: "COMPLETED", conclusion: "SKIPPED" }), "skip");
  assert.equal(checkState({ __typename: "StatusContext", state: "ERROR" }), "fail");
  assert.equal(checkState({ __typename: "StatusContext", state: "PENDING" }), "pending");
});

test("rollup: failure wins, then pending, with counts and named items", () => {
  const ok = { __typename: "CheckRun", name: "lint", status: "COMPLETED", conclusion: "SUCCESS" };
  const bad = { __typename: "CheckRun", name: "test", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: "https://x/1" };
  const run = { __typename: "StatusContext", context: "ci/deploy", state: "PENDING", targetUrl: "https://x/2" };
  assert.deepEqual(rollup([]), { state: "none", pass: 0, fail: 0, pending: 0, items: [] });
  assert.equal(rollup([ok, run]).state, "pending");
  const r = rollup([ok, bad, run]);
  assert.equal(r.state, "fail");
  assert.deepEqual([r.pass, r.fail, r.pending], [1, 1, 1]);
  // Failures first, then pending, then the rest.
  assert.deepEqual(r.items.map((i) => [i.name, i.state, i.url]), [["test", "fail", "https://x/1"], ["ci/deploy", "pending", "https://x/2"], ["lint", "pass", null]]);
});

test("review label names the decision", () => {
  assert.equal(reviewLabel("APPROVED"), "approved");
  assert.equal(reviewLabel("CHANGES_REQUESTED"), "changes");
  assert.equal(reviewLabel("REVIEW_REQUIRED"), "review");
  assert.equal(reviewLabel(""), "");
  assert.equal(reviewLabel(null), "");
});

test("prRow flattens gh pr list JSON", () => {
  const pr = {
    number: 7, title: "Add x", url: "https://github.com/a/b/pull/7", isDraft: false, headRefName: "feat/x",
    author: { login: "ana" }, reviewDecision: "APPROVED", additions: 10, deletions: 2, changedFiles: 3,
    statusCheckRollup: [{ __typename: "CheckRun", name: "t", status: "COMPLETED", conclusion: "SUCCESS" }],
    reviewRequests: [{ login: "bob" }, { name: "core", __typename: "Team" }],
    latestReviews: [{ author: { login: "cy" }, state: "APPROVED" }],
  };
  const row = prRow(pr);
  assert.equal(row.number, 7);
  assert.equal(row.author, "ana");
  assert.equal(row.branch, "feat/x");
  assert.equal(row.review, "approved");
  assert.equal(row.checks.state, "pass");
  assert.deepEqual([row.additions, row.deletions, row.files], [10, 2, 3]);
  assert.deepEqual(row.reviewers, [{ name: "cy", state: "approved" }, { name: "bob", state: "requested" }, { name: "core", state: "requested" }]);
  const bare = prRow({ number: 1, title: "t", url: "u", headRefName: "b" });
  assert.equal(bare.author, "");
  assert.deepEqual(bare.reviewers, []);
  assert.equal(bare.checks.state, "none");
});

test("issue groups: assigned first, recent without the assigned ones", () => {
  const i = (n) => ({ number: n, title: `i${n}`, url: `u${n}`, author: { login: "z" }, labels: [{ name: "bug" }] });
  const g = issueGroups([i(2)], [i(1), i(2), i(3)]);
  assert.deepEqual(g.assigned.map((x) => x.number), [2]);
  assert.deepEqual(g.recent.map((x) => x.number), [1, 3]);
  assert.deepEqual(g.assigned[0].labels, ["bug"]);
  assert.deepEqual(issueGroups(null, null), { assigned: [], recent: [] });
});

test("runRow maps run status and conclusion", () => {
  const base = { databaseId: 5, displayTitle: "Fix", workflowName: "CI", headBranch: "main", event: "push", url: "https://r/5", createdAt: "2026-11-27T10:00:00Z" };
  assert.equal(runRow({ ...base, status: "completed", conclusion: "failure" }).state, "fail");
  assert.equal(runRow({ ...base, status: "completed", conclusion: "success" }).state, "pass");
  assert.equal(runRow({ ...base, status: "in_progress", conclusion: "" }).state, "pending");
  assert.equal(runRow({ ...base, status: "completed", conclusion: "cancelled" }).state, "skip");
  const r = runRow({ ...base, status: "completed", conclusion: "success" });
  assert.deepEqual([r.title, r.workflow, r.branch, r.url], ["Fix", "CI", "main", "https://r/5"]);
});

test("notificationUrl converts API subject urls to web pages", () => {
  const repo = { html_url: "https://github.com/a/b" };
  assert.equal(notificationUrl({ subject: { url: "https://api.github.com/repos/a/b/pulls/12" }, repository: repo }), "https://github.com/a/b/pull/12");
  assert.equal(notificationUrl({ subject: { url: "https://api.github.com/repos/a/b/issues/3" }, repository: repo }), "https://github.com/a/b/issues/3");
  assert.equal(notificationUrl({ subject: { url: "https://api.github.com/repos/a/b/commits/abc" }, repository: repo }), "https://github.com/a/b/commit/abc");
  assert.equal(notificationUrl({ subject: { url: null }, repository: repo }), "https://github.com/a/b");
  assert.equal(notificationUrl({ subject: { url: "https://api.github.com/repos/a/b/releases/9" }, repository: repo }), "https://github.com/a/b/releases");
  assert.equal(notificationUrl({}), "https://github.com/notifications");
});

test("inbox puts review requests, then mentions, first; newest first within", () => {
  const n = (id, reason, at) => ({ id, reason, updated_at: at, unread: true, subject: { title: `t${id}`, type: "PullRequest", url: null }, repository: { full_name: "a/b", html_url: "https://github.com/a/b" } });
  const rows = inbox([n("1", "subscribed", "2026-11-27T10:00:00Z"), n("2", "mention", "2026-11-26T10:00:00Z"), n("3", "review_requested", "2026-11-25T10:00:00Z"), n("4", "mention", "2026-11-27T09:00:00Z")]);
  assert.deepEqual(rows.map((r) => r.id), ["3", "4", "2", "1"]);
  assert.deepEqual([rows[0].reason, rows[0].repo, rows[0].title, rows[0].url], ["review", "a/b", "t3", "https://github.com/a/b"]);
  assert.deepEqual(inbox(null), []);
});

test("counts per tab, null when not loaded", () => {
  assert.deepEqual(counts({ prs: null, issues: null, runs: null, inbox: null }), { prs: null, issues: null, ci: null, inbox: null });
  const c = counts({ prs: [1, 2], issues: { assigned: [1], recent: [2, 3] }, runs: [{ state: "fail" }, { state: "pass" }], inbox: [1] });
  assert.deepEqual(c, { prs: 2, issues: 3, ci: 1, inbox: 1 });
});

test("nextFetch: a space switch always reloads, even while a load is running", async () => {
  const { nextFetch } = await import("../herdr/desktop/mods/refactoria-github/model.js");
  const base = { key: "b", last: "a", visible: false, appeared: false, at: 0, now: 1000, loading: true, every: 90000 };
  assert.equal(nextFetch(base), "switch");
  assert.equal(nextFetch({ ...base, loading: false, visible: true }), "switch");
  assert.equal(nextFetch({ ...base, key: null }), "switch");
});

test("nextFetch: same space refreshes only when shown, on appearing or when stale, and never twice", async () => {
  const { nextFetch } = await import("../herdr/desktop/mods/refactoria-github/model.js");
  const base = { key: "a", last: "a", visible: true, appeared: false, at: 0, now: 1000, loading: false, every: 90000 };
  assert.equal(nextFetch(base), null);
  assert.equal(nextFetch({ ...base, appeared: true }), "refresh");
  assert.equal(nextFetch({ ...base, now: 90001 }), "refresh");
  assert.equal(nextFetch({ ...base, appeared: true, loading: true }), null);
  assert.equal(nextFetch({ ...base, visible: false, now: 999999 }), null);
  assert.equal(nextFetch({ ...base, key: null, last: null, appeared: true }), null);
});

// ---- T15: artboard 02 rich tabs ----
import * as M from "../herdr/desktop/mods/refactoria-github/model.js";
const NOW = Date.parse("2026-11-27T12:00:00Z");
const ago = (ms) => new Date(NOW - ms).toISOString();
const MIN = 60000, H = 60 * MIN, D = 24 * H;

test("relTime: labeled short ages, empty for missing", () => {
  assert.equal(M.relTime(ago(20000), NOW), "now");
  assert.equal(M.relTime(ago(5 * MIN), NOW), "5m");
  assert.equal(M.relTime(ago(3 * H), NOW), "3h");
  assert.equal(M.relTime(ago(D), NOW), "1d");
  assert.equal(M.relTime(ago(12 * D), NOW), "12d");
  assert.equal(M.relTime(ago(65 * D), NOW), "2mo");
  assert.equal(M.relTime(ago(400 * D), NOW), "1y");
  assert.equal(M.relTime("", NOW), "");
  assert.equal(M.relTime(null, NOW), "");
});

test("duration: minutes and zero-padded seconds", () => {
  assert.equal(M.duration("2026-11-27T10:00:00Z", "2026-11-27T10:00:22Z"), "0m 22s");
  assert.equal(M.duration("2026-11-27T10:00:00Z", "2026-11-27T10:01:02Z"), "1m 02s");
  assert.equal(M.duration("2026-11-27T10:00:00Z", "2026-11-27T11:05:00Z"), "65m 00s");
  assert.equal(M.duration("2026-11-27T10:00:00Z", ""), "");
  assert.equal(M.duration("0001-01-01T00:00:00Z", "2026-11-27T10:00:00Z"), "");
});

test("initials and avatar tone are stable per login", () => {
  assert.equal(M.initials("mrios"), "MR");
  assert.equal(M.initials("martina-rios"), "MR");
  assert.equal(M.initials("gentle_man"), "GM");
  assert.equal(M.initials("x"), "X");
  assert.equal(M.initials(""), "?");
  assert.equal(M.avatarTone("ana"), M.avatarTone("ana"));
  assert.ok(["#3B2D5C", "#1F3A4A", "#3A2A1E", "#203A2E"].includes(M.avatarTone("ana")));
});

test("sizeBar: five segments split by additions and deletions", () => {
  assert.deepEqual(M.sizeBar(18, 11), { plus: 3, minus: 2, empty: 0 });
  assert.deepEqual(M.sizeBar(186, 4), { plus: 5, minus: 0, empty: 0 });
  assert.deepEqual(M.sizeBar(97, 0), { plus: 5, minus: 0, empty: 0 });
  assert.deepEqual(M.sizeBar(1, 1), { plus: 1, minus: 1, empty: 3 });
  assert.deepEqual(M.sizeBar(0, 0), { plus: 0, minus: 0, empty: 5 });
  assert.deepEqual(M.sizeBar(2, 200), { plus: 0, minus: 5, empty: 0 });
});

test("labelTone: artboard colors for known labels, AA for any GitHub color", () => {
  assert.deepEqual(M.labelTone({ name: "bug", color: "d73a4a" }), { text: "#FF8FA3", bg: "#37223B", border: "#7A4A62" });
  assert.deepEqual(M.labelTone({ name: "enhancement", color: "a2eeef" }).text, "#8FDCE3");
  assert.equal(M.labelTone({ name: "documentation", color: "0075ca" }).text, "#8CC8FF");
  for (const color of ["000000", "ffffff", "0e8a16", "5319e7", "fbca04", "b60205", "c5def5", "", "zzz"]) {
    const l = M.labelTone({ name: `x-${color}`, color });
    assert.ok(M.contrast(l.text, l.bg) >= 4.5, `${color} on its tint`);
    assert.ok(M.contrast(l.text, M.mix(l.text, "#2C2144", 0.14)) >= 4.5, `${color} on raised tint`);
  }
});

const pr = (o = {}) => ({
  number: 113, title: "feat: x", url: "https://github.com/a/b/pull/113", isDraft: false, headRefName: "fix/x",
  author: { login: "mrios" }, reviewDecision: "REVIEW_REQUIRED", mergeable: "MERGEABLE", additions: 42, deletions: 8, changedFiles: 3,
  createdAt: ago(3 * H), updatedAt: ago(H),
  statusCheckRollup: [{ __typename: "CheckRun", name: "lint", status: "COMPLETED", conclusion: "SUCCESS" }],
  reviewRequests: [], latestReviews: [], closingIssuesReferences: [{ number: 109 }], ...o,
});

test("prCard: age, avatar, check word, review state, merge state, linked issue", () => {
  const c = M.prCard(pr(), "jb", NOW);
  assert.deepEqual([c.age, c.initials, c.linked], ["3h", "MR", [109]]);
  assert.deepEqual(c.checkWord, { state: "pass", word: "1/1" });
  assert.deepEqual(c.state, { kind: "waiting", word: "Awaiting review" });
  assert.equal(c.merge, "mergeable");
  assert.equal(M.prCard(pr({ isDraft: true }), "jb", NOW).state.word, "Draft");
  assert.deepEqual(M.prCard(pr({ mergeable: "CONFLICTING" }), "jb", NOW).state, { kind: "conflict", word: "Merge conflict" });
  assert.deepEqual(M.prCard(pr({ reviewDecision: "CHANGES_REQUESTED" }), "jb", NOW).state, { kind: "changes", word: "Changes requested" });
  assert.deepEqual(M.prCard(pr({ reviewDecision: "APPROVED" }), "jb", NOW).state, { kind: "approved", word: "Approved · ready to merge" });
  const bad = { __typename: "CheckRun", name: "t", status: "COMPLETED", conclusion: "FAILURE" };
  const run = { __typename: "CheckRun", name: "r", status: "IN_PROGRESS" };
  assert.deepEqual(M.prCard(pr({ reviewDecision: "APPROVED", statusCheckRollup: [bad] }), "jb", NOW).state.word, "Approved");
  assert.deepEqual(M.prCard(pr({ statusCheckRollup: [bad, run] }), "jb", NOW).checkWord, { state: "fail", word: "1 failing" });
  assert.deepEqual(M.prCard(pr({ statusCheckRollup: [run] }), "jb", NOW).checkWord, { state: "pending", word: "1 running" });
  assert.deepEqual(M.prCard(pr({ statusCheckRollup: [] }), "jb", NOW).checkWord, { state: "none", word: "No checks yet" });
  assert.deepEqual(M.prCard(pr({ closingIssuesReferences: null }), "jb", NOW).linked, []);
});

test("prGroups: review requested of me, then mine, then others; empty groups dropped", () => {
  const cards = [
    M.prCard(pr({ number: 1 }), "jb", NOW),
    M.prCard(pr({ number: 2, author: { login: "jb" } }), "jb", NOW),
    M.prCard(pr({ number: 3, reviewRequests: [{ login: "jb" }] }), "jb", NOW),
  ];
  assert.deepEqual(M.prGroups(cards).map((g) => [g.id, g.label, g.items.map((c) => c.number)]),
    [["requested", "Review requested", [3]], ["yours", "Yours", [2]], ["others", "Others", [1]]]);
  assert.deepEqual(M.prGroups([cards[0]]).map((g) => g.id), ["others"]);
});

test("blocker: the one line that says why it cannot merge", () => {
  const fail = { __typename: "CheckRun", name: "t", status: "COMPLETED", conclusion: "FAILURE" };
  assert.equal(M.blocker(M.prCard(pr({ statusCheckRollup: [fail] }), "jb", NOW)), "Blocked: 1 check failing");
  assert.equal(M.blocker(M.prCard(pr({ statusCheckRollup: [fail, fail] }), "jb", NOW)), "Blocked: 2 checks failing");
  assert.equal(M.blocker(M.prCard(pr({ mergeable: "CONFLICTING" }), "jb", NOW)), "Blocked: merge conflict");
  assert.equal(M.blocker(M.prCard(pr({ isDraft: true }), "jb", NOW)), "Draft: not ready for review");
  assert.equal(M.blocker(M.prCard(pr({ reviewDecision: "CHANGES_REQUESTED" }), "jb", NOW)), "Blocked: changes requested");
  assert.equal(M.blocker(M.prCard(pr(), "jb", NOW)), "Blocked: review required");
  assert.equal(M.blocker(M.prCard(pr({ reviewDecision: "APPROVED" }), "jb", NOW)), "Ready to merge");
});

test("prDetail: files count with top files, checks with duration and run id", () => {
  const d = M.prDetail({
    files: [{ path: "a", additions: 1, deletions: 0 }, { path: "b", additions: 31, deletions: 6 }, { path: "c", additions: 9, deletions: 2 }, { path: "d", additions: 2, deletions: 0 }],
    statusCheckRollup: [
      { __typename: "CheckRun", name: "lint", status: "COMPLETED", conclusion: "FAILURE", startedAt: "2026-11-27T10:00:00Z", completedAt: "2026-11-27T10:00:22Z", detailsUrl: "https://github.com/a/b/actions/runs/777/job/9" },
      { __typename: "CheckRun", name: "ok", status: "COMPLETED", conclusion: "SUCCESS", startedAt: "2026-11-27T10:00:00Z", completedAt: "2026-11-27T10:00:09Z", detailsUrl: "https://ci.example/x" },
    ],
  });
  assert.equal(d.files.count, 4);
  assert.deepEqual(d.files.top.map((f) => f.path), ["b", "c", "d"]);
  assert.deepEqual(d.checks.map((c) => [c.name, c.state, c.duration, c.runId]), [["lint", "fail", "0m 22s", 777], ["ok", "pass", "0m 09s", null]]);
  assert.deepEqual(M.rerunTargets(d.checks), [777]);
  assert.deepEqual(M.prDetail(null), { files: { count: 0, top: [] }, checks: [] });
});

test("runIdOf reads Actions run ids only", () => {
  assert.equal(M.runIdOf("https://github.com/a/b/actions/runs/123/job/4"), 123);
  assert.equal(M.runIdOf("https://ci.example/runs/123"), null);
  assert.equal(M.runIdOf(null), null);
});

const run = (o = {}) => ({ databaseId: 5, displayTitle: "Fix", workflowName: "CI", headBranch: "main", event: "push", url: "u", status: "completed", conclusion: "failure", createdAt: ago(2 * H), startedAt: "2026-11-27T10:00:00Z", updatedAt: "2026-11-27T10:01:02Z", ...o });

test("runCard: duration, age, re-run only for a finished failure", () => {
  const c = M.runCard(run(), NOW);
  assert.deepEqual([c.duration, c.age, c.rerun, c.word], ["1m 02s", "2h", true, "Failed"]);
  assert.equal(M.runCard(run({ conclusion: "success" }), NOW).rerun, false);
  assert.equal(M.runCard(run({ conclusion: "success" }), NOW).word, "Passed");
  assert.equal(M.runCard(run({ status: "in_progress", conclusion: "" }), NOW).rerun, false);
  assert.equal(M.runCard(run({ status: "in_progress", conclusion: "" }), NOW).word, "Running");
  assert.equal(M.runCard(run({ conclusion: "cancelled" }), NOW).word, "Cancelled");
  assert.equal(M.canRerun({ state: "fail", id: null }), false);
});

test("failedStep names the first failed job and step", () => {
  const jobs = { jobs: [
    { name: "build", conclusion: "success", steps: [{ name: "x", conclusion: "success" }] },
    { name: "test", conclusion: "failure", steps: [{ name: "setup", conclusion: "success" }, { name: "shellcheck", conclusion: "failure" }] },
  ] };
  assert.equal(M.failedStep(jobs), "test › shellcheck");
  assert.equal(M.failedStep({ jobs: [{ name: "test", conclusion: "failure", steps: [] }] }), "test");
  assert.equal(M.failedStep({ jobs: [] }), null);
  assert.equal(M.failedStep(null), null);
});

test("attention: what needs the user on each tab", () => {
  const cards = (o) => [M.prCard(pr(o), "jb", NOW)];
  const fail = [{ __typename: "CheckRun", name: "t", status: "COMPLETED", conclusion: "FAILURE" }];
  const none = { prs: [], runs: [], inbox: [], me: "jb" };
  assert.deepEqual(M.attention(none), { prs: false, issues: false, ci: false, inbox: false });
  assert.equal(M.attention({ ...none, prs: cards({ reviewRequests: [{ login: "jb" }] }) }).prs, true);
  assert.equal(M.attention({ ...none, prs: cards({ author: { login: "jb" }, statusCheckRollup: fail }) }).prs, true);
  assert.equal(M.attention({ ...none, prs: cards({ author: { login: "jb" }, reviewDecision: "CHANGES_REQUESTED" }) }).prs, true);
  assert.equal(M.attention({ ...none, prs: cards({ statusCheckRollup: fail }) }).prs, false, "someone else's failing PR");
  // CI: the latest run per workflow+branch failing, on main or a branch of mine.
  const r = (o) => M.runCard(run(o), NOW);
  assert.equal(M.attention({ ...none, runs: [r({})] }).ci, true);
  assert.equal(M.attention({ ...none, runs: [r({ conclusion: "success", databaseId: 6 }), r({})] }).ci, false, "fixed by a newer run");
  assert.equal(M.attention({ ...none, runs: [r({ headBranch: "feat/other" })] }).ci, false);
  assert.equal(M.attention({ ...none, prs: cards({ author: { login: "jb" }, headRefName: "feat/mine" }), runs: [r({ headBranch: "feat/mine" })] }).ci, true);
  assert.equal(M.attention({ ...none, inbox: [{ unread: true }] }).inbox, true);
  assert.equal(M.attention({ ...none, inbox: [{ unread: false }] }).inbox, false);
  assert.deepEqual(M.attention({ prs: null, runs: null, inbox: null, me: null }), { prs: false, issues: false, ci: false, inbox: false });
});

test("issue groups carry age, comments and toned label pills", () => {
  const g = M.issueGroups([{ number: 1, title: "t", url: "u", author: { login: "ana" }, createdAt: ago(D), comments: [{}, {}], labels: [{ name: "bug", color: "d73a4a" }] }], [], NOW);
  const i = g.assigned[0];
  assert.deepEqual([i.age, i.comments, i.initials, i.labels], ["1d", 2, "AN", ["bug"]]);
  assert.equal(i.pills[0].text, "#FF8FA3");
  assert.equal(M.issueGroups([{ number: 2, title: "t", url: "u", comments: 3 }], []).assigned[0].comments, 3);
});

test("syncedLabel is short so the repo name keeps its room", () => {
  assert.equal(M.syncedLabel(0, NOW), "");
  assert.equal(M.syncedLabel(NOW - 20000, NOW), "now");
  assert.equal(M.syncedLabel(NOW - 2 * MIN, NOW), "2m");
});
