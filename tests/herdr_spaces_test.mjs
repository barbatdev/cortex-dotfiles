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
