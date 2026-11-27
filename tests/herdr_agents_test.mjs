// Row model of the refactoria-agents mod: node --test tests/herdr_agents_test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { sessionName, currentTask, pendingParts, recordsWork, sessionRow } from "../herdr/desktop/mods/refactoria-agents/rows.js";

const feed = (over = {}) => ({
  schema: "gentle-shell.desktop-feed/v1",
  identity: { sessionId: "s1", sessionName: "Fix login", cwd: "/w/app", realCwd: "/w/app", pid: 10 },
  project: { cwd: "/w/app", branch: "main" },
  todo: { items: [], progress: { done: 0, total: 0, open: 0 }, current: null },
  agents: { items: [], active: 0 },
  jobs: { running: [], recent: [] },
  activity: { state: "idle" },
  pendingQuestion: null,
  ...over,
});

test("session name falls back to the project folder name", () => {
  assert.equal(sessionName(feed()), "Fix login");
  assert.equal(sessionName(feed({ identity: { sessionId: "s", cwd: "/w/app/", pid: 1 } })), "app");
  assert.equal(sessionName(null), "");
});

test("current task: todo.current, else the first in-progress item, with progress", () => {
  const items = [{ id: "1", title: "Read", state: "done" }, { id: "2", title: "Write", state: "in_progress" }, { id: "3", title: "Ship", state: "pending" }];
  const progress = { done: 1, total: 3, open: 2 };
  assert.deepEqual(currentTask(feed({ todo: { items, progress, current: null } })), { title: "Write", done: 1, total: 3 });
  assert.deepEqual(currentTask(feed({ todo: { items, progress, current: "Plan" } })), { title: "Plan", done: 1, total: 3 });
  assert.deepEqual(currentTask(feed({ todo: { items, progress, current: { title: "Obj" } } })), { title: "Obj", done: 1, total: 3 });
  assert.equal(currentTask(feed()), null);
});

test("pending parts: the question, then running agents and jobs", () => {
  const need = { kind: "question", word: "Question", reason: "Which DB?" };
  assert.deepEqual(pendingParts(need, { agents: 2, jobs: 1 }), ["Question: Which DB?", "2 agents", "1 job"]);
  assert.deepEqual(pendingParts(null, { agents: 1, jobs: 0 }), ["1 agent"]);
  assert.deepEqual(pendingParts(null, { agents: 0, jobs: 0 }), []);
});

test("OSC 7501 records: absent is a no-op, working/blocked count as work", () => {
  assert.deepEqual(recordsWork(undefined), { working: 0, blocked: 0 });
  assert.deepEqual(recordsWork([]), { working: 0, blocked: 0 });
  assert.deepEqual(recordsWork([{ id: "todo", state: "working" }, { id: "subagents/a", state: "blocked" }, { id: "bg/1", state: "error" }, null]), { working: 1, blocked: 1 });
});

test("session row joins name, state, task and pending", () => {
  const live = { status: "working", label: "Working · 2 agents", agents: 2, jobs: 0 };
  const f = feed({ todo: { items: [{ title: "Write", state: "in_progress" }], progress: { done: 0, total: 1 }, current: null } });
  assert.deepEqual(sessionRow(f, live, null), {
    name: "Fix login", status: "working", label: "Working · 2 agents", task: { title: "Write", done: 0, total: 1 }, pending: ["2 agents"],
  });
  const blocked = sessionRow(f, { status: "blocked", label: "Needs you", agents: 0, jobs: 0 }, { word: "Permission", reason: "Run rm?" });
  assert.equal(blocked.status, "blocked");
  assert.deepEqual(blocked.pending, ["Permission: Run rm?"]);
});

test("records raise an idle snapshot to working, blocked wins", () => {
  const idle = { status: "idle", label: "Idle", agents: 0, jobs: 0 };
  assert.equal(sessionRow(feed(), idle, null, [{ state: "working" }]).status, "working");
  assert.equal(sessionRow(feed(), idle, null, [{ state: "blocked" }]).label, "Needs you");
  assert.equal(sessionRow(feed(), idle, null, undefined).status, "idle");
});
