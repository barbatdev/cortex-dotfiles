// Model of the refactoria-links link handler: node --test tests/herdr_links_test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  classify, nvimKeys, nvimArgv, nvimPane, slug, issueUrl, sshTarget, choosePort, liveTunnel, localUrl, TUNNEL_IDLE_S,
} from "../herdr/desktop/mods/refactoria-links/model.js";

const src = (over = {}) => ({ terminal: "t7", machine: null, cwd: "/repo", pane: "p1", tab: "b1", space: "s1", ...over });

test("a file with a line opens in Neovim; the path comes from link.path, else the raw text against cwd", () => {
  assert.deepEqual(classify({ kind: "file", raw: "src/a.ts:12:3", path: "/repo/src/a.ts", line: 12, column: 3 }, src()),
    { kind: "file", path: "/repo/src/a.ts", line: 12, column: 3 });
  // Remote: link.path is null, the raw text is that machine's path.
  assert.deepEqual(classify({ kind: "file", raw: "src/a.ts:40", path: null, line: 40 }, src({ machine: "agent-dev", cwd: "/home/x/app" })),
    { kind: "file", path: "/home/x/app/src/a.ts", line: 40, column: null });
  assert.deepEqual(classify({ kind: "file", raw: "/etc/x.conf#L5-L9", path: null, line: 5 }, src({ machine: "agent-dev" })),
    { kind: "file", path: "/etc/x.conf", line: 5, column: null });
  assert.deepEqual(classify({ kind: "file", raw: "~/n.md:2", path: null, line: 2 }, src({ machine: "agent-dev" })),
    { kind: "file", path: "~/n.md", line: 2, column: null });
});

test("a file without a line, and a remote relative path without cwd, keep Herdr's default", () => {
  assert.equal(classify({ kind: "file", raw: "README.md", path: "/repo/README.md" }, src()).kind, "pass");
  assert.equal(classify({ kind: "file", raw: "a.ts:3", path: null, line: 3 }, src({ machine: "agent-dev", cwd: null })).kind, "pass");
});

test("#123 resolves against the clicked terminal's repo", () => {
  assert.deepEqual(classify({ kind: "url", raw: "#123", url: "#123" }, src()), { kind: "issue", number: 123 });
  assert.equal(issueUrl("acme/app", 123), "https://github.com/acme/app/issues/123");
  assert.equal(slug("git@github-workdev:acme/app.git\n"), "acme/app");
  assert.equal(slug("https://github.com/acme/app"), "acme/app");
  assert.equal(slug("nope"), null);
});

test("localhost on a remote terminal tunnels; on this computer and other URLs Herdr opens it", () => {
  assert.deepEqual(classify({ kind: "url", raw: "http://localhost:5173/a?b=1", url: "http://localhost:5173/a?b=1" }, src({ machine: "agent-dev" })),
    { kind: "tunnel", machine: "agent-dev", port: 5173, url: "http://localhost:5173/a?b=1" });
  assert.deepEqual(classify({ kind: "url", raw: "http://127.0.0.1:8080", url: "http://127.0.0.1:8080/" }, src({ machine: "agent-gentle" })),
    { kind: "tunnel", machine: "agent-gentle", port: 8080, url: "http://127.0.0.1:8080/" });
  assert.equal(classify({ kind: "url", raw: "http://localhost:5173", url: "http://localhost:5173/" }, src()).kind, "pass");
  assert.equal(classify({ kind: "url", raw: "http://localhost", url: "http://localhost/" }, src({ machine: "agent-dev" })).kind, "pass");
  assert.equal(classify({ kind: "url", raw: "https://github.com/acme/app/pull/4", url: "https://github.com/acme/app/pull/4" }, src()).kind, "pass");
});

test("nvim keys leave any mode, escape the path for :edit and set the column", () => {
  assert.equal(nvimKeys("/r/a b.ts", 12, null), "<C-\\><C-N>:edit +12 /r/a\\ b.ts<CR>");
  assert.equal(nvimKeys("/r/x<y>%.ts", 3, 7), "<C-\\><C-N>:edit +3 /r/x\\<lt>y>\\%.ts<CR>:call cursor(3, 7)<CR>");
  assert.deepEqual(nvimArgv("/r/a.ts", 12, null), ["nvim", "+12", "/r/a.ts"]);
  assert.deepEqual(nvimArgv("/r/a.ts", 12, 4), ["nvim", "+call cursor(12, 4)", "/r/a.ts"]);
});

test("the nvim pane of the clicked space: the shown tab's first, else any tab's", () => {
  const space = { id: "s1", tabs: [{ id: "b1", active: false }, { id: "b2", active: true }] };
  const nv = { key: "nvim" }, sh = { key: "shell" };
  const panes = [
    { pane: "p0", terminal: "t0", tab: "b9", program: nv },
    { pane: "p1", terminal: "t1", tab: "b1", program: nv },
    { pane: "p2", terminal: "t2", tab: "b2", program: sh },
    { pane: "p3", terminal: "t3", tab: "b2", program: nv },
  ];
  assert.equal(nvimPane(panes, space).pane, "p3");
  assert.equal(nvimPane(panes.slice(0, 3), space).pane, "p1");
  assert.equal(nvimPane([panes[0], panes[2]], space), null);
  assert.equal(nvimPane(panes, null), null);
});

test("ssh target is the Herdr machine's target", () => {
  const ls = { machines: [{ name: "agent-dev", target: "jbarbat@100.91.104.126" }, { name: "agent-gentle", target: "agent-gentle" }] };
  assert.equal(sshTarget(ls, "agent-dev"), "jbarbat@100.91.104.126");
  assert.equal(sshTarget(ls, "nope"), null);
});

test("a free local port: the same one when free, else the next free", () => {
  assert.equal(choosePort(5173, new Set()), 5173);
  assert.equal(choosePort(5173, new Set([5173, 5174])), 5175);
  assert.equal(choosePort(65535, new Set([65535])), null);
});

test("a tunnel for the same machine and port is reused while it lives", () => {
  const now = 1_000_000;
  const list = [
    { machine: "agent-dev", port: 3000, local: 3001, until: now + 5 },
    { machine: "agent-dev", port: 4000, local: 4000, until: now - 1 },
  ];
  assert.equal(liveTunnel(list, "agent-dev", 3000, now).local, 3001);
  assert.equal(liveTunnel(list, "agent-dev", 4000, now), null);
  assert.equal(liveTunnel(list, "agent-gentle", 3000, now), null);
  assert.equal(TUNNEL_IDLE_S, 900);
});

test("the local URL keeps path and query", () => {
  assert.equal(localUrl("http://localhost:5173/a?b=1#c", 5174), "http://localhost:5174/a?b=1#c");
  assert.equal(localUrl("http://127.0.0.1:8080/", 8080), "http://localhost:8080/");
});
