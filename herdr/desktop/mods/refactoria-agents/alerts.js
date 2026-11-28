// Alerts (T26): the Dock badge, one notification per transition to needs you / failed / finished,
// and the "while you were away" summary. Pure, over model.js cards (agentCards), so node --test
// loads it (tests/herdr_toast_test.mjs). No "herdr" import.

import { QUESTION_ELSEWHERE, sections } from "./model.js";

// The Dock badge: how many agents need you, the tray's "N needs you" (blocked); none at 0.
export function badgeText(cards) {
  const n = sections(cards ?? []).needs.filter((c) => c.status === "blocked").length;
  return n ? String(n) : null;
}

const ALERT = { blocked: "warning", failed: "error", done: "success" };
const failures = (c) => (c.chips ?? []).filter((x) => x.kind === "failed").map((x) => x.label);

// One key per alert-worthy state: agent + state + what it is about (the question, the failed
// records, the finished turn's time). Null for states that do not alert.
export function alertKey(c) {
  if (!ALERT[c?.status]) return null;
  const id = c.status === "blocked" ? c.question : c.status === "failed" ? failures(c).join(" | ") : String(c.since ?? "");
  return `${c.address}|${c.status}|${id ?? ""}`;
}

const short = (s, max = 100) => (s.length > max ? `${s.slice(0, max - 1)}…` : s);

// The notification: the agent's name and a short reason; clicking goes to that agent.
export function alertFor(c) {
  const why = failures(c).join(" · ");
  const body = c.status === "blocked" ? (c.question && c.question !== QUESTION_ELSEWHERE ? `asks: ${c.question}` : "needs you")
    : c.status === "failed" ? (why ? `failed: ${why}` : "failed") : "finished";
  const n = { title: c.name, body: short(body), level: ALERT[c.status] };
  if (c.pane) n.action = { name: "pane.focus", args: { pane: c.pane } };
  else if (c.address && !String(c.address).startsWith("feed|")) n.action = { name: "agent.focus", args: { terminal: c.address } };
  return n;
}

// Herdr itself notifies (and sounds) when an agent needs you or finishes, so only failures pop a
// toast here; every transition still feeds the "While you were away" summary.
export const popsUp = (e) => e?.state === "failed";

// The alert keys this window saw last (`seen`: address → key) against the cards now: an event for
// each key that is new. The first look (seen null) only seeds, so a start alerts nothing.
export function transitions(seen, cards) {
  const next = {};
  const events = [];
  for (const c of cards ?? []) {
    const key = alertKey(c);
    if (!key) continue;
    next[c.address] = key;
    if (seen && seen[c.address] !== key) events.push({ key, address: c.address, state: c.status, alert: alertFor(c) });
  }
  return { seen: next, events };
}

export const CLAIM_MS = 86400000;

// Every window sees the same agents: the first to write a key to the shared claims file
// (`text`, its current contents) notifies it. Returns the new contents and the keys this one won.
export function claimAlerts(text, keys, now) {
  let claims = {};
  try { claims = JSON.parse(text ?? "{}") ?? {}; } catch { claims = {}; }
  if (typeof claims !== "object" || Array.isArray(claims)) claims = {};
  for (const [k, at] of Object.entries(claims)) if (!(now - at < CLAIM_MS)) delete claims[k];
  const won = keys.filter((k) => !(k in claims));
  for (const k of won) claims[k] = now;
  return { text: JSON.stringify(claims), won };
}

// Away this long (unfocused or hidden) earns a summary when the window comes back.
export const AWAY_MS = 120000;

// What changed since `from` (the log holds { state, at, address } events), in words:
// "3 finished · 1 failed · 1 needs you"; null when nothing changed.
export function awaySummary(log, from) {
  const n = { done: 0, failed: 0, blocked: 0 };
  for (const e of log ?? []) if (e.at >= from && e.state in n) n[e.state]++;
  const parts = [];
  if (n.done) parts.push(`${n.done} finished`);
  if (n.failed) parts.push(`${n.failed} failed`);
  if (n.blocked) parts.push(`${n.blocked} need${n.blocked === 1 ? "s" : ""} you`);
  return parts.length ? parts.join(" · ") : null;
}
