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
