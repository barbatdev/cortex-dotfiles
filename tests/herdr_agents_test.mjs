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

test("OSC 7501 records as Herdr stores them: an object keyed by record id", () => {
  // Observed live (hc events, hc 0.1.22): {"todo":{"progress":44,"state":"working","title":"<b64>"}}
  assert.deepEqual(recordsWork(null), { working: 0, blocked: 0 });
  assert.deepEqual(recordsWork({}), { working: 0, blocked: 0 });
  assert.deepEqual(
    recordsWork({ todo: { progress: 44, state: "working" }, "subagents/a": { state: "blocked", kind: "question" }, "bg/1": { state: "error" } }),
    { working: 1, blocked: 1 },
  );
});

// ---- T6: sessions as cards (model.js) ----
import { decodeB64, parseRecords, programBadge, timeAgo, timeLabel, URGENCY, buildCard, sortCards, splitCards, idleView, liveAgents } from "../herdr/desktop/mods/refactoria-agents/model.js";

const b64 = (s) => Buffer.from(s, "utf8").toString("base64");

test("base64 UTF-8 decode, non-ASCII included; bad input stays as given", () => {
  assert.equal(decodeB64(b64("Fix docs link checker")), "Fix docs link checker");
  assert.equal(decodeB64(b64("¿Sacamos PRs de la sidebar? — sí ✓ 🚀")), "¿Sacamos PRs de la sidebar? — sí ✓ 🚀");
  assert.equal(decodeB64(""), "");
  assert.equal(decodeB64(undefined), "");
  assert.equal(decodeB64("not base64!"), "not base64!");
});

test("records: every id kind decoded and classified", () => {
  const r = parseRecords({
    todo: { state: "working", progress: 44, title: b64("Write tests") },
    "bg/j1": { state: "working", title: b64("monitor CI") },
    "bg/j2": { state: "error", title: b64("build"), msg: b64("exit 1") },
    "subagents/t1": { state: "working", title: b64("design sidebar") },
    "subagents/t2": { state: "blocked", kind: "question", title: b64("verify"), msg: b64("question for parent") },
    "subagents/t3": { state: "error", title: b64("verify docs"), msg: b64("timed out") },
    "wait/cortex": { state: "working", msg: b64("consulting cortex") },
    "sent/infra": { state: "idle" },
    "ask/gentle": { state: "blocked", msg: b64("question from gentle") },
  });
  assert.deepEqual(r.todo, { title: "Write tests", progress: 44, state: "working" });
  assert.deepEqual(r.jobs.map((j) => [j.name, j.state]), [["monitor CI", "working"], ["build", "error"]]);
  assert.deepEqual(r.subagents.map((s) => [s.name, s.state]), [["design sidebar", "working"], ["verify", "blocked"], ["verify docs", "error"]]);
  assert.deepEqual(r.consults, ["cortex"]);
  assert.deepEqual(r.sent, ["infra"]);
  assert.deepEqual(r.asks, [{ peer: "gentle", msg: "question from gentle" }]);
  assert.deepEqual(r.failed.map((f) => `${f.kind}:${f.name}:${f.msg}`), ["job:build:exit 1", "subagent:verify docs:timed out"]);
  assert.deepEqual(r.blocked.map((b) => b.msg), ["question for parent", "question from gentle"]);
  assert.deepEqual(parseRecords(null), { todo: null, jobs: [], subagents: [], consults: [], sent: [], asks: [], failed: [], blocked: [] });
});

test("program badge: GS / CC / CX / shell", () => {
  assert.deepEqual(programBadge({ app: "gentle-shell" }), { badge: "GS", name: "Gentle Shell" });
  assert.deepEqual(programBadge({ app: "pi" }), { badge: "GS", name: "Gentle Shell" });
  assert.deepEqual(programBadge({ app: "claude-code" }), { badge: "CC", name: "Claude Code" });
  assert.deepEqual(programBadge({ program: { key: "codex", name: "Codex" } }), { badge: "CX", name: "Codex" });
  assert.deepEqual(programBadge({ program: { key: "shell", name: "zsh" } }), { badge: "shell", name: "zsh" });
});

test("time labels say what the time means", () => {
  const m = 60000;
  assert.equal(timeAgo(20000), "<1m");
  assert.equal(timeAgo(4 * m), "4m");
  assert.equal(timeAgo(130 * m), "2h");
  assert.equal(timeAgo(50 * 60 * m), "2d");
  assert.equal(timeLabel("blocked", 4 * m), "waiting 4m");
  assert.equal(timeLabel("working", 12 * m), "for 12m");
  assert.equal(timeLabel("waiting", 12 * m), "for 12m");
  assert.equal(timeLabel("done", 10 * m), "done 10m ago");
  assert.equal(timeLabel("failed", 30000), "failed <1m ago");
  assert.equal(timeLabel("idle", 2 * 60 * m), "2h");
  assert.equal(timeLabel("working", null), "");
});

const agent = (over = {}) => ({ address: "t1", pane: "p1", space: "s1", space_name: "cortex", tab: "tb1", tab_name: "1", status: "idle", app: null, program: { key: "shell", name: "zsh" }, title: "", pane_name: null, seq: 1, focused: false, ...over });
const NOW = 1_000_000_000;

test("card: Gentle Shell session, blocked with the question and its wait", () => {
  const f = feed({ identity: { sessionId: "s", sessionName: "cortex", cwd: "/w/cortex", pid: 1 }, project: { cwd: "/w/cortex", branch: "main" },
    model: { id: "opus-5-5", effort: "low" }, context: { percent: 61 }, cost: { total: 0 },
    pendingQuestion: { kind: "choice", question: "¿Sacamos PRs de la sidebar?", openedAt: new Date(NOW - 4 * 60000).toISOString() } });
  const c = buildCard({ agent: agent({ app: "gentle-shell", status: "blocked" }), feed: f, live: { status: "blocked", label: "Needs you", agents: 0, jobs: 0 }, need: { word: "Question", reason: "¿Sacamos PRs de la sidebar?" }, now: NOW });
  assert.equal(c.status, "blocked");
  assert.equal(c.word, "Blocked");
  assert.equal(c.time, "waiting 4m");
  assert.equal(c.name, "cortex");
  assert.equal(c.question, "¿Sacamos PRs de la sidebar?");
  assert.equal(c.sub, "Gentle Shell asks you");
  assert.deepEqual(c.program, { badge: "GS", name: "Gentle Shell" });
  assert.deepEqual(c.meta, ["This computer", "main", "opus-5-5 low", "ctx 61%"]);
});

test("card: records give task, progress, chips and failures; remote machine", () => {
  const records = {
    todo: { state: "working", progress: 60, title: b64("Fix docs link checker") },
    "subagents/a": { state: "working", title: b64("design sidebar directions") },
    "bg/1": { state: "working", title: b64("monitor CI") },
    "wait/cortex": { state: "working" },
    "subagents/b": { state: "error", title: b64("verify docs"), msg: b64("timed out") },
  };
  const c = buildCard({ agent: agent({ address: "agent-gentle/t4", app: "gentle-shell", status: "working", space_name: "gentle-shell-issue-3388" }), records, now: NOW, since: NOW - 60000 });
  assert.equal(c.status, "failed");
  assert.equal(c.activity, "working");
  assert.equal(c.word, "1 failed");
  assert.deepEqual(c.task, { title: "Fix docs link checker", pct: 60, label: "60%" });
  assert.deepEqual(c.chips.map((x) => [x.kind, x.label]), [["subagent", "design sidebar directions"], ["job", "monitor CI"], ["consult", "consulting cortex"], ["failed", "verify docs · timed out"]]);
  assert.equal(c.meta[0], "agent-gentle");
  assert.equal(c.name, "gentle-shell-issue-3388");
});

test("card: feed todo progress wins as done/total; a blocked record raises state and gives the question", () => {
  const f = feed({ todo: { items: [{ title: "T8 Design", state: "in_progress" }], progress: { done: 5, total: 7 }, current: null }, cost: { total: 1.84 }, context: { percent: 42 } });
  const c = buildCard({ agent: agent({ app: "pi", status: "working" }), feed: f, live: { status: "working", label: "Working", agents: 0, jobs: 0 }, records: { "ask/infra": { state: "blocked", msg: b64("question from infra") } }, now: NOW });
  assert.equal(c.status, "blocked");
  assert.equal(c.question, "question from infra");
  assert.deepEqual(c.task, { title: "T8 Design", pct: 71, label: "5/7" });
  assert.equal(c.sub, "Gentle Shell asks you");
  assert.deepEqual(c.meta, ["This computer", "main", "ctx 42%", "$1.84"]);
});

test("card: non-Gentle agent keeps what Herdr knows; name never the tab index", () => {
  // L17: the task-like title names the card over the space name.
  const c = buildCard({ agent: agent({ address: "agent-dev/t9", status: "working", app: "codex", program: { key: "codex", name: "Codex" }, space_name: "infra", title: "Rotate Terraform state locks" }), now: NOW, since: NOW - 12 * 60000 });
  assert.equal(c.name, "Rotate Terraform state locks");
  assert.equal(c.sub, "");
  assert.equal(c.word, "Working");
  assert.equal(c.time, "for 12m");
  assert.deepEqual(c.meta, ["agent-dev", "Codex"]);
  const named = buildCard({ agent: agent({ pane_name: "api", tab_name: "2" }), now: NOW });
  assert.equal(named.name, "api");
  const tab = buildCard({ agent: agent({ tab_name: "deploy" }), now: NOW });
  assert.equal(tab.name, "deploy");
  const path = buildCard({ agent: agent({ status: "working", title: "~/dev/x" }), now: NOW });
  assert.equal(path.sub, "");
  const done = buildCard({ agent: agent({ status: "done", app: "claude-code", title: "Landing hero copy pass" }), now: NOW, since: NOW - 10 * 60000 });
  assert.equal(done.word, "New");
  assert.equal(done.time, "done 10m ago");
});

test("urgency: blocked > failed > working > waiting > done > idle; longest wait first among blocked", () => {
  assert.ok(URGENCY.blocked > URGENCY.failed && URGENCY.failed > URGENCY.working && URGENCY.working > URGENCY.waiting && URGENCY.waiting > URGENCY.done && URGENCY.done > URGENCY.idle);
  const cs = [
    { address: "d", status: "done", since: 5 }, { address: "w", status: "working", since: 9 }, { address: "b2", status: "blocked", since: 8 },
    { address: "f", status: "failed", since: 1 }, { address: "wt", status: "waiting", since: 1 }, { address: "b1", status: "blocked", since: 2 }, { address: "w2", status: "working", since: 10 },
  ];
  assert.deepEqual(sortCards(cs).map((c) => c.address), ["b1", "b2", "f", "w2", "w", "wt", "d"]);
});

test("idle agents split off, collapsed by default to a summary line", () => {
  const cs = [{ address: "a", status: "working" }, { address: "b", status: "idle", machine: null }, { address: "c", status: "idle", machine: "agent-dev" }];
  const { active, idle } = splitCards(cs);
  assert.deepEqual(active.map((c) => c.address), ["a"]);
  assert.deepEqual(idle.map((c) => c.address), ["b", "c"]);
  assert.deepEqual(idleView(idle, false), { summary: "2 idle · 2 machines", rows: [], open: false });
  assert.equal(idleView(idle, true).rows.length, 2);
  assert.equal(idleView([idle[0]], false).summary, "1 idle · this computer");
  assert.equal(idleView([], false).summary, "");
});

test("stale agents removed: finished terminals and duplicate addresses", () => {
  const list = [agent({ address: "t1" }), agent({ address: "t2" }), agent({ address: "t1" }), agent({ address: "t3" }), agent({ address: "t4" })];
  const terms = [{ address: "t1", state: "live" }, { address: "t2", state: "exited" }, { address: "t3", state: "dead" }];
  assert.deepEqual(liveAgents(list, terms).map((a) => a.address), ["t1", "t4"]);
});

test("sub-agent terminals: chips on the parent; a blocked one raises it", () => {
  const c = buildCard({ agent: agent({ status: "working", app: "claude-code" }), kids: [{ name: "explore", status: "working" }, { name: "review", status: "blocked" }], now: NOW });
  assert.deepEqual(c.chips.map((x) => x.label), ["explore"]);
  assert.equal(c.status, "blocked");
  assert.equal(c.question, "review waits for you");
});

test("chips: OSC records name the work; the feed's names only when no record does (no duplicates)", () => {
  const f = feed({ agents: { items: [{ id: "a1", name: "gentle-ai-worker", state: "running" }], active: 1 }, jobs: { running: [{ id: "j1", name: "npm test" }], recent: [] } });
  const live = { status: "working", label: "Working", agents: 1, jobs: 1 };
  const withRec = buildCard({ agent: agent({ app: "pi", status: "working" }), feed: f, live, records: { "subagents/a1": { state: "working", title: b64("implement sessions as cards") } }, now: NOW });
  assert.deepEqual(withRec.chips.map((x) => x.label), ["implement sessions as cards", "npm test"]);
  const feedOnly = buildCard({ agent: agent({ app: "pi", status: "working" }), feed: f, live, now: NOW });
  assert.deepEqual(feedOnly.chips.map((x) => x.label), ["gentle-ai-worker", "npm test"]);
});

// ---- L17: stale idle rows, duplicate names, empty state ----
import { agentName, disambiguate, idleSince, freshIdle, emptyLine, STALE_MS } from "../herdr/desktop/mods/refactoria-agents/model.js";

test("idle since: Herdr's status_ms first, then the mod's own stamp, then the terminal's creation", () => {
  assert.equal(idleSince({ status_ms: 50, created_ms: 10 }, 30), 50);
  assert.equal(idleSince({ status_ms: null, created_ms: 10 }, 30), 30);
  assert.equal(idleSince({ created_ms: 10 }, null), 10);
  assert.equal(idleSince(undefined, null), null);
});

test("stale idle rows hidden after 24 h unless focused or pinned; unknown age stays", () => {
  const day = 86400000;
  assert.equal(STALE_MS, day);
  const rows = [
    { address: "fresh", since: NOW - day + 1 },
    { address: "old", since: NOW - 27 * day },
    { address: "oldFocused", since: NOW - 27 * day, focused: true },
    { address: "oldPinned", since: NOW - 27 * day, pinned: true },
    { address: "unknown", since: 0 },
  ];
  const r = freshIdle(rows, NOW);
  assert.deepEqual(r.rows.map((c) => c.address), ["fresh", "oldFocused", "oldPinned", "unknown"]);
  assert.equal(r.hidden, 1);
  assert.deepEqual(freshIdle([], NOW), { rows: [], hidden: 0 });
});

test("names: session name, pane name, the decoded agent title, tab, then space", () => {
  const f = feed({ identity: { sessionId: "s", sessionName: "Fix login", cwd: "/w/app", pid: 1 } });
  assert.equal(agentName(agent({ title: "π - other", pane_name: "api" }), f), "Fix login");
  assert.equal(agentName(agent({ title: "π - other", pane_name: "api" }), null), "api");
  assert.equal(agentName(agent({ app: "gentle-shell", title: "π - review sidebar spec", space_name: "cortex" }), null), "review sidebar spec");
  assert.equal(agentName(agent({ app: "claude-code", title: "✳ Rotate state locks", space_name: "infra" }), null), "Rotate state locks");
  assert.equal(agentName(agent({ title: "~/dev/x", tab_name: "deploy" }), null), "deploy");
  assert.equal(agentName(agent({ title: "zsh", tab_name: "1", space_name: "infra" }), null), "infra");
  assert.equal(agentName(agent({ title: "", tab_name: "1", space_name: "infra" }), feed({ identity: { sessionId: "s", cwd: "/w/app", pid: 1 } })), "app");
});

test("colliding names get the tab name, else #n; distinct names stay", () => {
  const cs = [
    { address: "a", name: "innit-core", tab: "api" }, { address: "b", name: "innit-core", tab: "web" },
    { address: "c", name: "innit-core", tab: "web" }, { address: "d", name: "gestion", tab: "" },
    { address: "e", name: "Gestion", tab: "" }, { address: "f", name: "infra", tab: "" },
  ];
  assert.deepEqual(disambiguate(cs).map((c) => c.name), ["innit-core · api", "innit-core · web #1", "innit-core · web #2", "gestion #1", "Gestion #2", "infra"]);
});

test("empty state: a quiet line with the idle count", () => {
  assert.equal(emptyLine(18), "Nothing running · 18 idle");
  assert.equal(emptyLine(0), "Nothing running");
});

test("card name comes from agentName and keeps the tab for disambiguation", () => {
  const c = buildCard({ agent: agent({ app: "claude-code", title: "✳ Rotate state locks", space_name: "infra", tab_name: "ops" }), now: NOW });
  assert.equal(c.name, "Rotate state locks");
  assert.equal(c.tab, "ops");
  assert.equal(c.sub, "");
});

// T10 / L18: the observed t3y sequence on `hc events` (seq 8383-8387): status done -> working ->
// working (todo record gone) -> done, then turn 28 done with herdr.seen 26; the feed snapshot read
// "idle" meanwhile. The card must stay active the whole way.
test("T10: a working Gentle Shell session never reads as idle mid-turn", () => {
  const idleFeed = feed();
  const live = { status: "idle", label: "Idle", agents: 0, jobs: 0 };
  const term = (state, records, turn = 27, seen = "26") => ({ address: "t3y", status: { app: "gentle-shell", state }, records, turn, labels: { "herdr.seen": seen } });
  const card = (herdr, t) => buildCard({ agent: agent({ address: "t3y", app: "gentle-shell", status: herdr }), feed: idleFeed, live, records: t.records, term: t, now: NOW, since: NOW - 5000 });
  const sub = { "subagents/a": { state: "working", title: b64("fix") } };
  // Herdr says working, the feed snapshot says idle: Herdr's live state wins.
  assert.equal(card("working", term("working", { ...sub, todo: { state: "working", progress: 73 } })).status, "working");
  assert.equal(card("working", term("working", {})).status, "working");
  // Between wakeups Herdr reports done (seen, so agents() says idle) while a subagent still runs.
  assert.equal(card("idle", term("done", sub)).status, "working");
  // Turn finished, not seen yet (turn 28 > seen 26): a visible New card, not idle.
  const unseen = card("idle", term("done", {}, 28, "26"));
  assert.equal(unseen.status, "done");
  assert.equal(splitCards([unseen]).active.length, 1);
  // Reported working through the terminal while agents() lags at idle.
  assert.equal(card("idle", term("working", null)).status, "working");
  // Finished and seen, nothing running: idle.
  assert.equal(card("idle", term("done", {}, 28, "28")).status, "idle");
  assert.equal(card("idle", term("done", null, 28, "28")).status, "idle");
});

// ---- T11: design/herdr-desktop-ux/04-sessions-v2.html (calm idle) ----
import { recencyGroups, todaySummary, lastFinished, programIcon, machineIcon, machineLabel, pillLabel, sections, idleLines } from "../herdr/desktop/mods/refactoria-agents/model.js";

const NOON = new Date(2026, 10, 27, 12, 0).getTime();
const M = 60000;

test("idle grouped by recency: Just now <15m, This hour, Earlier today behind Show N more", () => {
  const rows = [
    { address: "a", since: NOON - 9 * M }, { address: "b", since: NOON - 31 * M }, { address: "c", since: NOON - 56 * M },
    { address: "d", since: NOON - 2 * 60 * M }, { address: "e", since: NOON - 3 * 60 * M }, { address: "f", since: NOON - 4 * 60 * M },
    { address: "g", since: 0 }, { address: "h", since: NOON - 15 * M },
  ];
  const g = recencyGroups(rows, NOON, false);
  assert.deepEqual(g.map((grp) => [grp.id, grp.label, grp.count, grp.rows.map((r) => r.address), grp.more]), [
    ["now", "Just now", 1, ["a"], 0],
    ["hour", "This hour", 3, ["h", "b", "c"], 0],
    ["earlier", "Earlier today", 4, ["d", "e"], 2],
  ]);
  assert.equal(recencyGroups(rows, NOON, true)[2].rows.length, 4);
  assert.equal(recencyGroups(rows, NOON, true)[2].more, 0);
  assert.deepEqual(recencyGroups([{ address: "x", since: NOON - M }], NOON, false).map((grp) => grp.id), ["now"]);
  assert.deepEqual(recencyGroups([], NOON, false), []);
});

test("sections: needs you (blocked, failed), running (working, waiting), quiet (done unseen and idle)", () => {
  const cs = [{ address: "b", status: "blocked" }, { address: "f", status: "failed" }, { address: "w", status: "working" }, { address: "wt", status: "waiting" }, { address: "d", status: "done" }, { address: "i", status: "idle" }];
  const s = sections(cs);
  assert.deepEqual(s.needs.map((c) => c.address), ["b", "f"]);
  assert.deepEqual(s.running.map((c) => c.address), ["w", "wt"]);
  assert.deepEqual(s.quiet.map((c) => c.address), ["d", "i"]);
});

test("today: ran, finished, failed and needs you among agents touched today; machines online", () => {
  const cs = [
    { status: "idle", since: NOON - 2 * 60 * M, machine: null }, { status: "done", since: NOON - 9 * M, machine: "agent-dev" },
    { status: "failed", since: NOON - 2 * M, machine: "agent-gentle" }, { status: "blocked", since: NOON - 4 * M, machine: null },
    { status: "working", since: NOON - M, machine: null }, { status: "idle", since: NOON - 13 * 60 * M, machine: "agent-dev" },
    { status: "idle", since: 0, machine: null },
  ];
  assert.deepEqual(todaySummary(cs, NOON), { ran: 5, finished: 2, failed: 1, needs: 1, machines: 3 });
  assert.deepEqual(todaySummary([], NOON), { ran: 0, finished: 0, failed: 0, needs: 0, machines: 0 });
});

test("last finished: the most recent quiet agent today, with a labeled time and where", () => {
  const cs = [
    { address: "old", status: "idle", since: NOON - 3 * 60 * M, machine: null },
    { address: "new", status: "done", since: NOON - 9 * M, machine: "agent-dev" },
    { address: "w", status: "working", since: NOON - M },
    { address: "y", status: "idle", since: NOON - 13 * 60 * M },
  ];
  const l = lastFinished(cs, NOON);
  assert.equal(l.card.address, "new");
  assert.equal(l.label, "Last finished · 9m ago");
  assert.equal(l.where, "agent-dev");
  assert.equal(lastFinished([{ status: "idle", since: NOON - 13 * 60 * M }], NOON), null);
  assert.equal(lastFinished([], NOON), null);
});

test("glyphs: program and machine icons, generic server for other machines", () => {
  const p = (n) => `mods/refactoria-agents/icons/${n}.svg`;
  assert.equal(programIcon({ badge: "GS" }), p("p-gs"));
  assert.equal(programIcon({ badge: "CC" }), p("p-cc"));
  assert.equal(programIcon({ badge: "CX" }), p("p-cx"));
  assert.equal(programIcon({ badge: "shell" }), p("p-sh"));
  assert.equal(programIcon(null), p("p-sh"));
  assert.equal(machineIcon(null), p("laptop"));
  assert.equal(machineIcon("agent-dev"), p("server"));
  assert.equal(machineIcon("agent-gentle"), p("cloud"));
  assert.equal(machineIcon("build-box"), p("server"));
  assert.equal(machineLabel(null), "This computer");
  assert.equal(machineLabel("agent-dev"), "agent-dev");
});

test("pill: state word with a short time", () => {
  assert.equal(pillLabel({ status: "blocked", since: NOON - 4 * M }, NOON), "Needs you · 4m");
  assert.equal(pillLabel({ status: "failed", since: NOON - 2 * M }, NOON), "Failed · 2m");
  assert.equal(pillLabel({ status: "working", since: NOON - 12 * M }, NOON), "Working");
  assert.equal(pillLabel({ status: "waiting", since: 0 }, NOON), "Waiting");
  assert.equal(pillLabel({ status: "blocked", since: 0 }, NOON), "Needs you");
});

test("idle row lines: name, New when unseen, age; dim task and machine", () => {
  const l = idleLines({ name: "innit-pay", status: "done", sub: "Refactor payment webhooks", machine: "agent-dev", since: NOON - 9 * M }, NOON);
  assert.deepEqual(l, { name: "innit-pay", isNew: true, age: "9m", task: "Refactor payment webhooks", where: "agent-dev",
    label: "innit-pay, finished, not seen yet, Refactor payment webhooks, agent-dev, 9m ago" });
  const q = idleLines({ name: "refactoria", status: "idle", sub: "", task: { title: "Landing hero" }, machine: null, since: NOON - 2 * 60 * M }, NOON);
  assert.equal(q.isNew, false);
  assert.equal(q.task, "Landing hero");
  assert.equal(q.where, "This computer");
  assert.equal(q.label, "refactoria, idle, Landing hero, This computer, 2h ago");
  const bare = idleLines({ name: "infra", status: "idle", sub: "", machine: null, since: 0, space: "infra" }, NOON);
  assert.equal(bare.task, "");
  assert.equal(bare.age, "");
  assert.equal(idleLines({ name: "api", status: "idle", sub: "", machine: null, since: 0, space: "innit-core" }, NOON).task, "innit-core");
});

test("card keeps the space for the idle row's second line", () => {
  assert.equal(buildCard({ agent: agent({ space_name: "innit-core" }), now: NOW }).space, "innit-core");
});

test("T13: Herdr hands record titles and messages already decoded; plain text stays as is", () => {
  // Observed live (hc events, hc 0.1.22): {"bg/job-1":{"state":"error","title":"e2e probe failing job","msg":"exited 3"}}
  const r = parseRecords({
    "bg/job-1": { state: "error", title: "e2e probe failing job", msg: "exited 3" },
    "subagents/a": { state: "working", title: "design" },
    "bg/job-3": { state: "working", title: "test" },
    todo: { state: "working", progress: 73, title: "Ledger" },
  });
  const titles = JSON.stringify(r);
  for (const t of ["e2e probe failing job", "exited 3", "design", "test", "Ledger"]) assert.ok(titles.includes(t), t);
});

// T19 (design/herdr-spaces/04-split-roles.html): the tray's live summary, the Spaces dot, and the
// card list both sidebars reduce from (one reduction, shared by a byte-identical model.js copy).
import { spaceDot, dotTooltip, traySummary, agentCards } from "../herdr/desktop/mods/refactoria-agents/model.js";

const dc = (status, program = "Gentle Shell") => ({ status, program: { name: program } });

test("T19 spaceDot: needs you › failed › working › done; idle has no dot", () => {
  assert.equal(spaceDot([]), null);
  assert.equal(spaceDot([dc("idle"), dc("idle")]), null);
  assert.deepEqual(spaceDot([dc("done")]), { kind: "done", status: "done", word: "done, not seen yet", label: "Gentle Shell done, not seen yet" });
  assert.deepEqual(spaceDot([dc("done"), dc("working", "Codex")]), { kind: "working", status: "working", word: "working", label: "Codex working" });
  assert.deepEqual(spaceDot([dc("waiting")]), { kind: "working", status: "waiting", word: "waiting on its subagents", label: "Gentle Shell waiting on its subagents" });
  assert.deepEqual(spaceDot([dc("working"), dc("failed", "Claude Code")]).label, "Claude Code failed");
  assert.deepEqual(spaceDot([dc("failed"), dc("blocked", "Codex"), dc("working")]), { kind: "blocked", status: "blocked", word: "needs you", label: "Codex needs you" });
});

test("T19 dotTooltip: space name, then who and what", () => {
  assert.equal(dotTooltip("cortex-dotfiles", spaceDot([dc("working")])), "cortex-dotfiles · Gentle Shell working");
  assert.equal(dotTooltip("x", null), "");
});

test("T19 traySummary: only non-zero parts, in words; all quiet says so", () => {
  const busy = [dc("blocked"), dc("working"), dc("waiting"), dc("done"), ...Array(8).fill(dc("idle"))];
  assert.deepEqual(traySummary(busy), {
    parts: [{ kind: "blocked", text: "1 needs you" }, { kind: "working", text: "2 running" }, { kind: "idle", text: "9 idle" }],
    label: "1 needs you, 2 running, 9 idle",
  });
  assert.deepEqual(traySummary([dc("failed"), dc("working")]).parts, [{ kind: "failed", text: "1 failed" }, { kind: "working", text: "1 running" }]);
  assert.deepEqual(traySummary(Array(12).fill(dc("idle"))), { parts: [{ kind: "idle", text: "All quiet · 12 idle" }], label: "All quiet, 12 idle" });
  assert.deepEqual(traySummary([]), { parts: [{ kind: "idle", text: "All quiet" }], label: "All quiet" });
});

test("T19 agentCards: one card per live top-level agent, with its space id; sub-agents become chips", () => {
  const ags = [
    { address: "t1", pane: "p1", space: "sp-a", space_name: "a", app: "gentle-shell", status: "idle", program: null },
    { address: "t2", pane: "p2", space: "sp-a", space_name: "a", status: "working", program: { key: "codex", name: "Codex" } },
    { address: "t3", pane: "p3", space: "sp-b", space_name: "b", status: "blocked", program: { key: "claude", name: "Claude" } },
    { address: "t4", pane: "p4", space: "sp-c", space_name: "c", status: "idle", program: null },
  ];
  const terms = [
    { address: "t1", state: "live" }, { address: "t2", state: "live" }, { address: "t3", state: "live", parent: "t2" }, { address: "t4", state: "exited" },
  ];
  const feedWorking = feed({ activity: { state: "working" } });
  const sessionOf = (a) => (a.address === "t1" ? { session: { key: "s1" }, feed: feedWorking, live: { status: "working" }, need: null } : null);
  const cards = agentCards({ agents: ags, terms, sessionOf, sinceOf: () => 0, now: 0 });
  assert.deepEqual(cards.map((c) => [c.address, c.spaceId, c.status]), [["t1", "sp-a", "working"], ["t2", "sp-a", "blocked"]]);
  assert.deepEqual(cards[0].session, { key: "s1" });
  assert.equal(cards[1].session, null);
  // The Spaces dot of sp-a is the reduction of exactly those cards.
  assert.equal(spaceDot(cards.filter((c) => c.spaceId === "sp-a")).label, "Codex needs you");
});

// ---- T22: the question text in Needs you cards, from the best source that carries it ----
const blockedGs = (over = {}) => agent({ address: "agent-dev/t4k", app: "gentle-shell", status: "blocked", title: "π - Orquestador roadmap #827", ...over });

test("question: the feed's pending question wins and is quoted", () => {
  const f = feed({ pendingQuestion: { kind: "questionnaire", question: "Which DB?" }, activity: { state: "blocked", blockedLabel: "Questionnaire awaiting input" } });
  const c = buildCard({ agent: blockedGs({ address: "t1" }), feed: f, records: { "ask/x": { state: "blocked", msg: "question from x" } }, term: { report: { state: "blocked", msg: "Questionnaire awaiting input" } }, now: NOW });
  assert.equal(c.question, "Which DB?");
  assert.equal(c.quoted, true);
});

test("question: else a blocked record's msg with its title", () => {
  const records = { "subagents/t2": { state: "blocked", title: "verify docs", msg: "question for parent" } };
  const c = buildCard({ agent: blockedGs(), records, term: { report: { state: "blocked", msg: "Questionnaire awaiting input" } }, now: NOW });
  assert.equal(c.question, "verify docs · question for parent");
  assert.equal(c.quoted, true);
  const ask = buildCard({ agent: blockedGs(), records: { "ask/gentle": { state: "blocked", msg: "question from gentle" } }, now: NOW });
  assert.equal(ask.question, "question from gentle");
});

test("question: else Herdr's status msg (remote session), unless it is just the session title", () => {
  const c = buildCard({ agent: blockedGs(), term: { status: "blocked", report: { app: "gentle-shell", kind: "question", state: "blocked", msg: "Questionnaire awaiting input" } }, now: NOW });
  assert.equal(c.question, "Questionnaire awaiting input");
  assert.equal(c.quoted, true);
  const evStream = buildCard({ agent: blockedGs(), term: { status: { state: "blocked", msg: "Approve deploy?" } }, now: NOW });
  assert.equal(evStream.question, "Approve deploy?");
  const echo = buildCard({ agent: blockedGs(), term: { report: { state: "blocked", msg: "Orquestador roadmap #827" } }, now: NOW });
  assert.equal(echo.question, "The question is in its terminal · Open the pane to answer");
  assert.equal(echo.quoted, false);
});

test("question: nothing carries it, so an honest line, never invented text; not blocked, none", () => {
  const c = buildCard({ agent: blockedGs(), now: NOW });
  assert.equal(c.status, "blocked");
  assert.equal(c.question, "The question is in its terminal · Open the pane to answer");
  assert.equal(c.quoted, false);
  assert.equal(c.sub, "Gentle Shell asks you");
  const w = buildCard({ agent: blockedGs({ status: "working" }), term: { report: { state: "working", msg: "Running tests" } }, now: NOW });
  assert.equal(w.question, "");
});
