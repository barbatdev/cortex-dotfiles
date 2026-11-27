// Row model of the refactoria-spaces mod: node --test tests/herdr_spaces_test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { sessionName, currentTask, pickSession } from "../herdr/desktop/mods/refactoria-spaces/rows.js";

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
  assert.deepEqual(currentTask(feed({ todo: { items, current: null } })), { title: "Write", done: 0, total: 0 });
  assert.deepEqual(currentTask(feed({ todo: { items, current: { title: "Plan" }, progress: { done: 1, total: 3 } } })), { title: "Plan", done: 1, total: 3 });
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

// T17 (design/herdr-spaces/01-quiet-list.html): row lines, shortcut numbers, git summary, height model.
import { parseStatus, shortcutNumbers, branchLine, foldedSummary, HEIGHT, rowHeight, blockHeight } from "../herdr/desktop/mods/refactoria-spaces/rows.js";

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

test("foldedSummary: shortcut range and first names", () => {
  const rows = [6, 7, 8, 9, null, null].map((n, i) => ({ name: ["gestion", "innit-core", "innit-pay", "x", "y", "z"][i], n }));
  assert.equal(foldedSummary(rows), "6–9 · gestion, innit-core, innit-pay +3");
  assert.equal(foldedSummary([{ name: "solo", n: null }]), "solo");
  assert.equal(foldedSummary([{ name: "a", n: 3 }]), "3 · a");
});

test("T19 height model: every space row is two lines; block is the sum of its parts", () => {
  assert.equal(rowHeight(), HEIGHT.row2);
  assert.equal(rowHeight(3), HEIGHT.row2);
  assert.equal(HEIGHT.row3, undefined);
  const parts = [{ kind: "machine" }, { kind: "row" }, { kind: "row" }, { kind: "machine" }, { kind: "folded" }];
  assert.equal(blockHeight(parts), HEIGHT.head + HEIGHT.pad + 2 * HEIGHT.machine + 2 * HEIGHT.row2 + HEIGHT.folded);
});

// T19: Spaces reduces agent state with the Agents model itself, a byte-identical copy (a mod
// cannot import outside its folder), on top of the same rows.js helpers.
import { readFileSync } from "node:fs";
import * as agentsRows from "../herdr/desktop/mods/refactoria-agents/rows.js";
import { spaceDot, agentCards } from "../herdr/desktop/mods/refactoria-spaces/model.js";

test("T19 model.js: refactoria-spaces carries a byte-identical copy of refactoria-agents/model.js", () => {
  const mods = new URL("../herdr/desktop/mods/", import.meta.url);
  assert.ok(readFileSync(new URL("refactoria-spaces/model.js", mods)).equals(readFileSync(new URL("refactoria-agents/model.js", mods))));
});

test("T19 rows.js: the helpers model.js imports answer the same in both mods", () => {
  const f = feed({ todo: { items: [{ title: "Write", state: "in_progress" }], progress: { done: 2, total: 5 }, current: null } });
  assert.deepEqual(currentTask(f), agentsRows.currentTask(f));
  assert.equal(sessionName(f), agentsRows.sessionName(f));
});

test("T19 the copy reduces a space's dot like Agents: a working session is a blue dot", () => {
  const ags = [{ address: "t8", pane: "p8", space: "sp-dot", space_name: "cortex-dotfiles", app: "gentle-shell", status: "idle", program: null }];
  const f = feed({ todo: { items: [], current: "T19", progress: { done: 3, total: 7 } } });
  const cards = agentCards({ agents: ags, terms: [{ address: "t8", state: "live" }], sessionOf: () => ({ session: null, feed: f, live: { status: "working" }, need: null }), sinceOf: () => 0, now: 0 });
  assert.deepEqual(spaceDot(cards.filter((c) => c.spaceId === "sp-dot")), { kind: "working", status: "working", word: "working", label: "Gentle Shell working" });
  assert.equal(cards[0].task.label, "3/7");
});
