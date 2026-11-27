import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";

// Exercise the mod's rendered rows and commands without the native GPUI runtime.
function fixture(spaces, { git = {}, folded = [], machines = [], agents = [] } = {}) {
  const calls = [];
  function element() {
    const node = { children: [], events: {} };
    const proxy = new Proxy(node, {
      get(target, key) {
        if (key in target) return target[key];
        return (...args) => {
          if (key === "child") target.children.push(args[0]);
          else if (key === "children") target.children.push(...args[0]);
          else if (key === "id") target.id = args[0];
          else if (key === "when" && args[0]) args[1](proxy);
          else if (key.startsWith("on_")) target.events[`${key}${typeof args[0] === "string" ? `_${args[0]}` : ""}`] = args.at(-1);
          return proxy;
        };
      },
    });
    return proxy;
  }
  const source = readFileSync(new URL("../herdr/desktop/mods/refactoria-spaces/main.js", import.meta.url), "utf8")
    .replace(/^import .*;\n/gm, "")
    .replaceAll("export function ", "function ")
    .replace("export default class Spaces", "class Spaces");
  const context = vm.createContext({
    View: class {}, div: element, svg: element, v_flex: element, h_flex: element,
    spaces: () => spaces, panes: () => [], machines: () => [], agents: () => agents,
    shared: () => ({}), run: (...args) => calls.push(structuredClone(args)),
  });
  const Spaces = vm.runInContext(`${source}\nSpaces`, context);
  const view = new Spaces();
  Object.assign(view, { git, shown: new Set(spaces.map(s => s.id)), born: {}, folded: new Set(folded), machines, seen: new Set(), pressed: null });
  const theme = new Proxy({}, { get: (_, key) => key });
  const rows = (compact = true) => view.grouped(theme, compact).filter(row => row.id?.startsWith("space-"));
  const labels = () => rows().map(row => [row.id.slice(6), row.children[0].children[0]]);
  function assertTargets(expected) {
    assert.deepEqual(structuredClone(labels()), expected.map((id, i) => [id, String(i + 1)]));
    calls.length = 0;
    for (let i = 1; i <= expected.length + 1; i++) view.focusAgent(i);
    assert.deepEqual(calls, expected.map(id => ["space.select", { id }]));
  }
  return { view, calls, rows, assertTargets };
}

const space = (id, machine = null) => ({ id, name: id, folder: `/${id}`, machine });
const gitKey = id => JSON.stringify([null, `/${id}`]);

test("local-first and alphabetic machine labels match shortcut targets", () => {
  fixture([space("remote", "vps"), space("local"), space("alpha", "alpha")])
    .assertTargets(["local", "alpha", "remote"]);
});

test("worktree created before main uses its displayed ordinal", () => {
  fixture([space("worktree"), space("main")], { git: {
    [gitKey("worktree")]: { repo: "repo", linked: true },
    [gitKey("main")]: { repo: "repo", linked: false },
  } }).assertTargets(["main", "worktree"]);
});

test("folded machine spaces occupy no ordinal and renumber on unfolding", () => {
  const f = fixture([space("hidden", "alpha"), space("last", "vps"), space("local")], { folded: ["alpha"] });
  f.assertTargets(["local", "last"]);
  f.view.folded.delete("alpha");
  f.assertTargets(["local", "hidden", "last"]);
});

test("folded local group is skipped only when machine headers exist", () => {
  fixture([space("local"), space("remote", "vps")], { folded: [null] }).assertTargets(["remote"]);
  fixture([space("local")], { folded: [null] }).assertTargets(["local"]);
  fixture([space("local")], { folded: [null], machines: [{ name: "empty" }] }).assertTargets([]);
});

test("spaces waiting to be shown occupy no ordinal", () => {
  const f = fixture([space("pending"), space("shown")]);
  f.view.shown.delete("pending");
  f.assertTargets(["shown"]);
});

test("agent focus still selects by urgency, then most recent change", () => {
  const f = fixture([space("local")], { agents: [
    { space: "local", status: "working", seq: 99, pane: "working" },
    { space: "local", status: "blocked", seq: 1, pane: "old" },
    { space: "local", status: "blocked", seq: 2, pane: "new" },
  ] });
  f.view.focusAgent(1);
  assert.deepEqual(f.calls, [["pane.focus", { pane: "new" }]]);
});

test("wide rows preserve source indices for drag-and-drop and selection", () => {
  const f = fixture([space("remote", "vps"), space("local")]);
  const [local, remote] = f.rows(false);
  const cx = { notify() {} };
  local.events.on_mouse_down_left();
  remote.events.on_mouse_up_left({}, cx);
  remote.events.on_mouse_down_left();
  remote.events.on_mouse_up_left({}, cx);
  assert.deepEqual(f.calls, [
    ["space.move", { id: "local", index: 1 }],
    ["space.select", { id: "remote" }],
  ]);
});
