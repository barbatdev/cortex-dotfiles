// Tab auto-naming of the refactoria-tabs mod (T20): node --test tests/herdr_tabs_test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { programLabel, contextLabel, tabName, truncate, decodeTitle, shouldRename } from "../herdr/desktop/mods/refactoria-tabs/naming.js";

const shell = { key: "shell", name: "zsh", shell: true, agent: false };
const agentProg = (key, name) => ({ key, name, shell: false, agent: true });

test("program label", () => {
  assert.equal(programLabel({ app: "gentle-shell" }), "Pi");
  assert.equal(programLabel({ app: "pi" }), "Pi");
  assert.equal(programLabel({ app: "claude-code" }), "Claude");
  assert.equal(programLabel({ app: "codex" }), "Codex");
  assert.equal(programLabel({ app: "opencode" }), "Opencode");
  assert.equal(programLabel({ app: null, program: agentProg("claude", "Claude Code") }), "Claude");
  assert.equal(programLabel({ app: null, program: shell }), "zsh");
  assert.equal(programLabel({ app: null, program: { key: "program", name: "htop" } }), "Htop");
});

test("Pi context: todo, then session title, then space", () => {
  const base = { program: "Pi", title: "π - refactor auth", space: "cortex" };
  assert.equal(contextLabel({ ...base, todo: { title: "T19 split roles", state: "working" } }), "T19 split roles");
  assert.equal(contextLabel({ ...base, todo: { title: Buffer.from("Tarea ñ").toString("base64"), state: "working" } }), "Tarea ñ");
  assert.equal(contextLabel({ ...base, todo: { title: "T1", state: "done" } }), "refactor auth");
  assert.equal(contextLabel({ ...base, todo: null }), "refactor auth");
  assert.equal(contextLabel({ ...base, title: "gentle-shell" }), "cortex");
});

test("other agents: meaningful title else space; shells: cwd folder", () => {
  assert.equal(contextLabel({ program: "Claude", title: "✳ Fix login", space: "app" }), "Fix login");
  assert.equal(contextLabel({ program: "Claude", title: "~/dev/app", space: "refactoria" }), "refactoria");
  assert.equal(contextLabel({ program: "Claude", title: "Claude", space: "refactoria" }), "refactoria");
  assert.equal(contextLabel({ program: "zsh", shell: true, cwd: "/Users/me/dev/infra/", space: "x" }), "infra");
  assert.equal(contextLabel({ program: "zsh", shell: true, cwd: null, space: "home" }), "home");
});

test("tab name format, truncation and control characters", () => {
  assert.equal(tabName({ app: "pi", todo: { title: "T19 split", state: "working" }, title: "π - x", space: "s" }), "Pi · T19 split");
  assert.equal(tabName({ app: null, program: shell, cwd: "/w/infra", space: "s" }), "zsh · infra");
  assert.equal(tabName({ app: "claude-code", title: "", space: "refactoria" }), "Claude · refactoria");
  const long = tabName({ app: "pi", todo: { title: "a".repeat(50), state: "working" }, space: "s" });
  assert.equal(long, "Pi · " + "a".repeat(31) + "…");
  assert.equal(truncate("a\u0007b\nc"), "a b c");
  assert.equal(decodeTitle("Planning"), "Planning");
  assert.equal(decodeTitle(btoa("Plan it")), "Plan it");
});

test("should rename: Herdr names and ours yes, the person's name never", () => {
  const tab = (name, named, index = 2) => ({ name, named, index });
  assert.equal(shouldRename({ tab: tab("2", false), computed: "Pi · x", last: null }), true);
  assert.equal(shouldRename({ tab: tab("π - x", true), computed: "Pi · x", last: null, title: "π - x" }), true);
  assert.equal(shouldRename({ tab: tab("Pi · old", true), computed: "Pi · x", last: "Pi · old" }), true);
  assert.equal(shouldRename({ tab: tab("my work", true), computed: "Pi · x", last: "Pi · old", title: "π - x" }), false);
  assert.equal(shouldRename({ tab: tab("Pi · x", true), computed: "Pi · x", last: "Pi · x" }), false);
  assert.equal(shouldRename({ tab: tab("2", false), computed: "", last: null }), false);
});

// ---- hardening: invalid UTF-8 code points and the stateful rename plan ----
import { planRenames } from "../herdr/desktop/mods/refactoria-tabs/naming.js";

const b64 = (bytes) => Buffer.from(bytes).toString("base64");

test("decodeTitle keeps a title whose base64 decodes past U+10FFFF, to a surrogate or an overlong form", () => {
  const past = b64([0xf4, 0x90, 0x80, 0x80, 0x41, 0x42]); // U+110000
  const surrogate = b64([0xed, 0xa0, 0x80, 0x41, 0x42, 0x43]); // U+D800
  const overlong = b64([0xe0, 0x80, 0xaf, 0x41, 0x42, 0x43]); // overlong "/"
  for (const s of [past, surrogate, overlong]) assert.equal(decodeTitle(s), s);
  assert.equal(decodeTitle(b64([...Buffer.from("Café · ñandú")])), "Café · ñandú");
});

const space = (tabs) => [{ name: "cortex-dotfiles", tabs }];
const pane = (tab, extra = {}) => ({ pane: `${tab}p`, tab, terminal: `${tab}t`, title: "π - cortex-dotfiles", cwd: "/x/cortex-dotfiles", program: { key: "pi" }, ...extra });

test("planRenames renames Herdr's own name and records it", () => {
  const plan = planRenames({ spaces: space([{ id: "t1", index: 1, named: false, name: "" }]), panes: [pane("t1")], agents: [], terminals: [], stored: "{}", machinesReady: true });
  assert.deepEqual(plan.renames, [{ id: "t1", name: "Pi · cortex-dotfiles" }]);
  assert.deepEqual(JSON.parse(plan.stored), { t1: "Pi · cortex-dotfiles" });
});

test("planRenames never overwrites a name the person set, and follows its own earlier name", () => {
  const stored = JSON.stringify({ t1: "Pi · old task", t2: "Pi · old task" });
  const tabs = [{ id: "t1", index: 1, named: true, name: "my scratch" }, { id: "t2", index: 2, named: true, name: "Pi · old task" }];
  const plan = planRenames({ spaces: space(tabs), panes: [pane("t1"), pane("t2")], agents: [], terminals: [], stored, machinesReady: true });
  assert.deepEqual(plan.renames, [{ id: "t2", name: "Pi · cortex-dotfiles" }]);
  assert.equal(JSON.parse(plan.stored).t1, "Pi · old task");
});

test("planRenames tolerates malformed storage and forgets closed tabs only when machines are ready", () => {
  const tabs = [{ id: "t1", index: 1, named: true, name: "Pi · cortex-dotfiles" }];
  for (const bad of ["not json", "[1,2]", "null"]) {
    const plan = planRenames({ spaces: space(tabs), panes: [pane("t1")], agents: [], terminals: [], stored: bad, machinesReady: true });
    assert.deepEqual(plan.renames, []);
  }
  const stored = JSON.stringify({ gone: "Pi · x" });
  assert.equal(JSON.parse(planRenames({ spaces: space([]), panes: [], agents: [], terminals: [], stored, machinesReady: false }).stored).gone, "Pi · x");
  assert.equal(JSON.parse(planRenames({ spaces: space([]), panes: [], agents: [], terminals: [], stored, machinesReady: true }).stored).gone, undefined);
});

test("planRenames keeps naming the other tabs when one tab's data throws", () => {
  const evil = { tab: "t1", pane: "t1p", terminal: "t1t", get title() { throw new Error("boom"); } };
  const tabs = [{ id: "t1", index: 1, named: false, name: "" }, { id: "t2", index: 2, named: false, name: "" }];
  const plan = planRenames({ spaces: space(tabs), panes: [evil, pane("t2")], agents: [], terminals: [], stored: "{}", machinesReady: true });
  assert.deepEqual(plan.renames, [{ id: "t2", name: "Pi · cortex-dotfiles" }]);
});

test("planRenames prefers the focused agent pane and reads its terminal's todo record", () => {
  const panes = [pane("t1", { pane: "a", focused: false }), pane("t1", { pane: "b", terminal: "tb", focused: true })];
  const agents = [{ pane: "a", address: "ta", app: "gentle-shell" }, { pane: "b", address: "tb", app: "gentle-shell" }];
  const terminals = [{ address: "tb", records: { todo: { state: "working", title: "T21 Harden tab names" } } }];
  const plan = planRenames({ spaces: space([{ id: "t1", index: 1, named: false, name: "" }]), panes, agents, terminals, stored: "{}", machinesReady: true });
  assert.deepEqual(plan.renames, [{ id: "t1", name: "Pi · T21 Harden tab names" }]);
});
