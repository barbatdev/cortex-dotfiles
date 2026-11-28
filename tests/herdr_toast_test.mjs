// Alerts (T26): node --test tests/herdr_toast_test.mjs
// Dock badge count, transition detection, dedupe keys and claims, alert text, away summary,
// and the look of the refactoria-toast mod.
import { test } from "node:test";
import assert from "node:assert/strict";
import { badgeText, alertKey, alertFor, transitions, claimAlerts, awaySummary, AWAY_MS, popsUp } from "../herdr/desktop/mods/refactoria-agents/alerts.js";
import { QUESTION_ELSEWHERE } from "../herdr/desktop/mods/refactoria-agents/model.js";
import { toastLook } from "../herdr/desktop/mods/refactoria-toast/look.js";

const card = (over = {}) => ({ address: "local/t1", pane: "p1", name: "Fix login", status: "idle", since: 1000, question: "", chips: [], ...over });

test("badge: how many agents need you (blocked), none at 0", () => {
  assert.equal(badgeText([]), null);
  assert.equal(badgeText([card({ status: "working" }), card({ status: "failed" }), card({ status: "done" })]), null);
  assert.equal(badgeText([card({ status: "blocked" }), card({ address: "b", status: "blocked" }), card({ status: "failed" })]), "2");
});

test("alert key: agent + state + question or record id", () => {
  assert.equal(alertKey(card({ status: "blocked", question: "Deploy?" })), "local/t1|blocked|Deploy?");
  assert.equal(alertKey(card({ status: "failed", chips: [{ kind: "failed", label: "build · exited 1" }] })), "local/t1|failed|build · exited 1");
  assert.equal(alertKey(card({ status: "done", since: 5000 })), "local/t1|done|5000");
  assert.equal(alertKey(card({ status: "working" })), null);
  assert.equal(alertKey(card({ status: "idle" })), null);
});

test("alert text: agent name + short reason, no sound, focuses the agent", () => {
  assert.deepEqual(alertFor(card({ status: "blocked", question: "Deploy to prod?" })), {
    title: "Fix login", body: "asks: Deploy to prod?", level: "warning", action: { name: "pane.focus", args: { pane: "p1" } },
  });
  assert.equal(alertFor(card({ status: "blocked", question: QUESTION_ELSEWHERE })).body, "needs you");
  assert.equal(alertFor(card({ status: "failed", chips: [{ kind: "job", label: "x" }, { kind: "failed", label: "exited 1" }] })).body, "failed: exited 1");
  assert.equal(alertFor(card({ status: "failed" })).body, "failed");
  const done = alertFor(card({ status: "done", pane: null, address: "agent-dev/t9" }));
  assert.equal(done.body, "finished");
  assert.equal(done.level, "success");
  assert.deepEqual(done.action, { name: "agent.focus", args: { terminal: "agent-dev/t9" } });
  assert.equal(alertFor(card({ status: "done", pane: null, address: "feed|s1" })).action, undefined);
  const long = alertFor(card({ status: "blocked", question: "x".repeat(200) })).body;
  assert.ok(long.length <= 100 && long.endsWith("…"));
});

test("transitions: the first look seeds without alerting", () => {
  const r = transitions(null, [card({ status: "blocked", question: "Q" })]);
  assert.deepEqual(r.events, []);
  assert.deepEqual(r.seen, { "local/t1": "local/t1|blocked|Q" });
});

test("transitions: one event per new alert state, none while it stays", () => {
  let r = transitions({}, [card({ status: "working" })]);
  assert.deepEqual(r.events, []);
  r = transitions(r.seen, [card({ status: "blocked", question: "Q" })]);
  assert.deepEqual(r.events.map((e) => e.key), ["local/t1|blocked|Q"]);
  r = transitions(r.seen, [card({ status: "blocked", question: "Q" })]);
  assert.deepEqual(r.events, []);
  // A new question from the same agent is a new transition.
  r = transitions(r.seen, [card({ status: "blocked", question: "Q2" })]);
  assert.deepEqual(r.events.map((e) => e.state), ["blocked"]);
  r = transitions(r.seen, [card({ status: "failed", chips: [{ kind: "failed", label: "exited 1" }] })]);
  assert.deepEqual(r.events.map((e) => e.key), ["local/t1|failed|exited 1"]);
  r = transitions(r.seen, [card({ status: "working" })]);
  r = transitions(r.seen, [card({ status: "done", since: 9000 })]);
  assert.deepEqual(r.events.map((e) => [e.state, e.alert.body]), [["done", "finished"]]);
  // Seen (done turns idle), then the same key again: it alerts, the state left in between.
  r = transitions(r.seen, [card({ status: "idle" })]);
  assert.deepEqual(r.seen, {});
});

test("claims: only one window alerts a key; old claims expire", () => {
  const now = 10 * 86400000;
  const a = claimAlerts(null, ["k1", "k2"], now);
  assert.deepEqual(a.won, ["k1", "k2"]);
  const b = claimAlerts(a.text, ["k1", "k3"], now + 1);
  assert.deepEqual(b.won, ["k3"]);
  assert.deepEqual(Object.keys(JSON.parse(b.text)).sort(), ["k1", "k2", "k3"]);
  const later = claimAlerts(b.text, ["k4"], now + 2 * 86400000);
  assert.deepEqual(Object.keys(JSON.parse(later.text)), ["k4"]);
  assert.deepEqual(claimAlerts("not json", ["k1"], now).won, ["k1"]);
});

test("away summary: what changed while away, in words; nothing when nothing changed", () => {
  const ev = (state, at, address = "a") => ({ state, at, address });
  const log = [ev("done", 100, "a"), ev("done", 200, "b"), ev("failed", 300, "c"), ev("blocked", 400, "d"), ev("done", 500, "e"), ev("done", 50, "old")];
  assert.equal(awaySummary(log, 100), "3 finished · 1 failed · 1 needs you");
  assert.equal(awaySummary(log, 1000), null);
  assert.equal(awaySummary([ev("blocked", 10), ev("blocked", 20, "b")], 0), "2 need you");
  assert.equal(AWAY_MS, 120000);
});

test("toast look: state icon + word per level, Herdr's own toasts keep their text", () => {
  assert.deepEqual(toastLook({ level: "warning", title: "Fix login", body: "asks: Deploy?" }), { kind: "blocked", word: "Needs you" });
  assert.deepEqual(toastLook({ level: "error", title: "Command failed" }), { kind: "failed", word: "Failed" });
  assert.deepEqual(toastLook({ level: "success", title: "x", body: "finished" }), { kind: "done", word: "Finished" });
  assert.deepEqual(toastLook({ level: "warning", title: "Disk almost full" }), { kind: "blocked", word: "Heads up" });
  assert.deepEqual(toastLook({ title: "While you were away", body: "1 finished" }), { kind: "info", word: "Info" });
  assert.deepEqual(toastLook(null), { kind: "info", word: "Info" });
});

test("only failures pop a toast: Herdr already notifies needs-you and finished turns", () => {
  assert.equal(popsUp({ state: "failed" }), true);
  assert.equal(popsUp({ state: "blocked" }), false);
  assert.equal(popsUp({ state: "done" }), false);
});
