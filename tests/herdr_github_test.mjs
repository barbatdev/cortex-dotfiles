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
