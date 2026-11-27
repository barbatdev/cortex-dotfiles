// Row model of the refactoria-spaces mod: node --test tests/herdr_spaces_test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { sessionName, currentTask, pickSession, spaceLines } from "../herdr/desktop/mods/refactoria-spaces/rows.js";

const feed = (over = {}) => ({
  identity: { sessionId: "s1", sessionName: "Fix login", cwd: "/w/app", realCwd: "/w/app", pid: 10 },
  project: { cwd: "/w/app" },
  todo: { items: [], progress: { done: 0, total: 0 }, current: null },
  activity: { state: "idle" },
  updatedAt: "2026-01-01T00:00:00Z",
  ...over,
});

test("session name and current task", () => {
  assert.equal(sessionName(feed()), "Fix login");
  assert.equal(sessionName(feed({ identity: { cwd: "/w/app/" } })), "app");
  const items = [{ title: "Read", state: "done" }, { title: "Write", state: "in_progress" }];
  assert.equal(currentTask(feed({ todo: { items, current: null } })), "Write");
  assert.equal(currentTask(feed({ todo: { items, current: { title: "Plan" } } })), "Plan");
  assert.equal(currentTask(feed()), null);
});

test("pickSession: most urgent, then newest", () => {
  const a = { feed: feed({ updatedAt: "2026-01-02" }), live: { status: "idle" } };
  const b = { feed: feed({ updatedAt: "2026-01-01" }), live: { status: "working" } };
  const c = { feed: feed({ updatedAt: "2026-01-03" }), live: { status: "working" } };
  assert.equal(pickSession([a, b, c]), c);
  assert.equal(pickSession([a]), a);
  assert.equal(pickSession([]), null);
});

test("spaceLines: no session keeps the git line", () => {
  assert.deepEqual(spaceLines({ space: "app", git: "spike", session: null }), { state: null, other: "", second: "spike", tooltip: "" });
});

test("spaceLines: task replaces branch, branch goes to tooltip", () => {
  const session = { feed: feed({ todo: { items: [], current: "Ship it" } }), live: { status: "working", label: "Working" } };
  assert.deepEqual(spaceLines({ space: "app", git: "spike", session }), {
    state: { status: "working", label: "Working" }, other: "Fix login", second: "Ship it", tooltip: "spike",
  });
});

test("spaceLines: same session name is not repeated, idle has no indicator", () => {
  const session = { feed: feed({ identity: { sessionName: "App" } }), live: { status: "idle", label: "Idle" } };
  assert.deepEqual(spaceLines({ space: "app", git: "", session }), { state: null, other: "", second: "", tooltip: "" });
});

import { spaceOfSession } from "../herdr/desktop/mods/refactoria-spaces/rows.js";

const ctx = {
  home: "/u",
  byTerminal: { "t8": "sp-dot" },
  places: [
    { id: "sp-dev", place: "/u/dev", repo: false },
    { id: "sp-dot", place: "/u/dev/cortex-dotfiles", repo: true },
    { id: "sp-cx", place: "/u/dev/cortex", repo: true },
    { id: "sp-home", place: "/u", repo: false },
    { id: "sp-far", place: "/u/dev/app", repo: true, machine: "box" },
  ],
};

test("spaceOfSession: the terminal's space wins over the folder", () => {
  assert.equal(spaceOfSession({ terminal: "t8", project: "/u/dev/cortex" }, ctx), "sp-dot");
});

test("spaceOfSession: folder fallback, exact or inside a repo space only", () => {
  assert.equal(spaceOfSession({ terminal: null, project: "/u/dev/cortex" }, ctx), "sp-cx");
  assert.equal(spaceOfSession({ terminal: null, project: "/u/dev/cortex/sub" }, ctx), "sp-cx");
  // A parent-folder space never captures a sibling project; home and remote spaces hold nothing.
  assert.equal(spaceOfSession({ terminal: null, project: "/u/dev/refactoria" }, ctx), null);
  assert.equal(spaceOfSession({ terminal: null, project: "/u" }, ctx), null);
  assert.equal(spaceOfSession({ terminal: null, project: "/u/dev/app" }, ctx), null);
  assert.equal(spaceOfSession({ terminal: "t99", project: null }, ctx), null);
});

test("spaceLines: a name equal to the space or the project folder is hidden", () => {
  const live = { status: "idle", label: "Idle" };
  const s = (sessionName) => ({ feed: feed({ identity: { sessionName, realCwd: "/w/cortex-dotfiles" } }), live });
  assert.equal(spaceLines({ space: "Cortex-Dotfiles", git: "", session: s("cortex-dotfiles") }).other, "");
  assert.equal(spaceLines({ space: "dots", git: "", session: s("cortex-dotfiles") }).other, "");
  assert.equal(spaceLines({ space: "dots", git: "", session: s("Fix login") }).other, "Fix login");
});

// T17 (design/herdr-spaces/01-quiet-list.html): row lines, shortcut numbers, git summary, height model.
import { parseStatus, shortcutNumbers, spaceRow, branchLine, foldedSummary, HEIGHT, rowHeight, blockHeight } from "../herdr/desktop/mods/refactoria-spaces/rows.js";

test("parseStatus: branch, ahead/behind and uncommitted count from porcelain v2", () => {
  const out = [
    "# branch.oid abc", "# branch.head feat/x", "# branch.upstream origin/feat/x", "# branch.ab +2 -1",
    "1 .M N... 100644 100644 100644 a b zsh/zshrc", "2 R. N... 100644 100644 100644 a b R100 new\told",
    "u UU N... 1 2 3 4 a b c conflict", "? design/new.html", "! ignored", "",
  ].join("\n");
  assert.deepEqual(parseStatus(out), { branch: "feat/x", ahead: 2, behind: 1, dirty: 4 });
  assert.deepEqual(parseStatus("# branch.head (detached)\n"), { branch: null, ahead: 0, behind: 0, dirty: 0 });
});

test("shortcutNumbers: the first nine spaces in list order get 1-9", () => {
  const ids = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"];
  const n = shortcutNumbers(ids);
  assert.equal(n.a, 1);
  assert.equal(n.i, 9);
  assert.equal(n.j, undefined);
});

test("branchLine: branch always shown, calm counts, no repo says so", () => {
  assert.deepEqual(branchLine({ branch: "main", ahead: 2, behind: 0, dirty: 3 }),
    { branch: "main", ahead: 2, behind: 0, dirty: 3, label: "main, 2 ahead, 3 uncommitted changes" });
  assert.deepEqual(branchLine({ branch: null, ahead: 0, behind: 1, dirty: 0 }),
    { branch: "detached", ahead: 0, behind: 1, dirty: 0, label: "detached, 1 behind" });
  assert.deepEqual(branchLine(null), { branch: "", ahead: 0, behind: 0, dirty: 0, label: "no git branch" });
});

const gs = (status, over = {}) => ({ feed: feed({ todo: { items: [], current: "T16 Redesign Spaces" }, ...over }), live: { status, label: status } });

test("spaceRow: a running session adds a third line with program and task", () => {
  assert.deepEqual(spaceRow({ session: gs("working") }), { pill: { kind: "working", word: "Working" }, task: "Gentle Shell · T16 Redesign Spaces", lines: 3 });
});

test("spaceRow: blocked asks the question; waits beats working", () => {
  const r = spaceRow({ session: gs("blocked"), question: "¿Publico la beta?", waits: true, status: "blocked" });
  assert.deepEqual(r, { pill: { kind: "blocked", word: "Needs you" }, task: "Gentle Shell · Asks: “¿Publico la beta?”", lines: 3 });
});

test("spaceRow: done unseen is New, idle session is Idle, nothing is two lines", () => {
  assert.deepEqual(spaceRow({ agent: { status: "done", program: "Codex" }, waits: true, status: "done" }).pill, { kind: "done", word: "New" });
  assert.deepEqual(spaceRow({ session: gs("idle") }).pill, { kind: "idle", word: "Idle" });
  assert.deepEqual(spaceRow({}), { pill: null, task: "", lines: 2 });
  assert.deepEqual(spaceRow({ agent: { status: "working", program: "Claude Code" } }), { pill: { kind: "working", word: "Working" }, task: "", lines: 2 });
  assert.deepEqual(spaceRow({ failed: true, session: gs("idle") }).pill, { kind: "failed", word: "Failed" });
});

test("foldedSummary: shortcut range and first names", () => {
  const rows = [6, 7, 8, 9, null, null].map((n, i) => ({ name: ["gestion", "innit-core", "innit-pay", "x", "y", "z"][i], n }));
  assert.equal(foldedSummary(rows), "6–9 · gestion, innit-core, innit-pay +3");
  assert.equal(foldedSummary([{ name: "solo", n: null }]), "solo");
  assert.equal(foldedSummary([{ name: "a", n: 3 }]), "3 · a");
});

test("height model: rows by line count, block is the sum of its parts", () => {
  assert.equal(rowHeight(2), HEIGHT.row2);
  assert.equal(rowHeight(3), HEIGHT.row3);
  const parts = [{ kind: "machine" }, { kind: "row", lines: 2 }, { kind: "row", lines: 3 }, { kind: "machine" }, { kind: "folded" }];
  assert.equal(blockHeight(parts), HEIGHT.head + HEIGHT.pad + 2 * HEIGHT.machine + HEIGHT.row2 + HEIGHT.row3 + HEIGHT.folded);
});

test("spaceRow: a session waiting on its subagents reads Waiting, as on its Agents card", () => {
  assert.deepEqual(spaceRow({ session: gs("waiting") }).pill, { kind: "waiting", word: "Waiting" });
});
