// Pure card model of the agents sidebar (design/herdr-desktop-ux/02-sessions-as-cards.html):
// OSC 7501 record decoding, program badges, labeled times, urgency order and the idle list.
// No "herdr" import so node --test can load it (tests/herdr_agents_test.mjs).

import { sessionName, currentTask } from "./rows.js";

const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// UTF-8 bytes to a string; null when the bytes are not valid UTF-8.
function utf8(bytes) {
  let out = "";
  for (let i = 0; i < bytes.length; ) {
    const b = bytes[i];
    const n = b < 0x80 ? 0 : b >= 0xf0 && b < 0xf8 ? 3 : b >= 0xe0 ? 2 : b >= 0xc0 ? 1 : -1;
    if (n < 0 || i + n >= bytes.length + (n ? 0 : 1)) return null;
    let cp = n === 0 ? b : b & (0x3f >> n);
    for (let k = 1; k <= n; k++) {
      const c = bytes[i + k];
      if (c === undefined || (c & 0xc0) !== 0x80) return null;
      cp = (cp << 6) | (c & 0x3f);
    }
    out += String.fromCodePoint(cp);
    i += n + 1;
  }
  return out;
}

// A record's title or msg: base64 of UTF-8 text. Text that is not base64 is returned as given.
export function decodeB64(s) {
  if (typeof s !== "string" || !s) return "";
  const clean = s.replace(/\s+/g, "");
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(clean) || clean.length % 4 === 1) return s;
  const bytes = [];
  let buf = 0, bits = 0;
  for (const ch of clean.replace(/=+$/, "")) {
    buf = (buf << 6) | B64.indexOf(ch);
    bits += 6;
    if (bits >= 8) { bits -= 8; bytes.push((buf >> bits) & 0xff); }
  }
  const text = utf8(bytes);
  return text == null ? s : text;
}

// A terminal's OSC 7501 sub-records (terminals()[i].records, an object keyed by id; L13), sorted by
// kind: todo, bg/<job>, subagents/<task>, wait/<peer> (consulting), sent/<peer>, ask/<peer> (blocked).
export function parseRecords(records) {
  const out = { todo: null, jobs: [], subagents: [], consults: [], sent: [], asks: [], failed: [], blocked: [] };
  if (!records || typeof records !== "object") return out;
  const entries = Array.isArray(records) ? records.map((r) => [r?.id, r]) : Object.entries(records);
  for (const [id, r] of entries) {
    if (typeof id !== "string" || !r || typeof r !== "object") continue;
    const title = decodeB64(r.title);
    const msg = decodeB64(r.msg);
    const slash = id.indexOf("/");
    const kind = slash < 0 ? id : id.slice(0, slash);
    const key = slash < 0 ? "" : id.slice(slash + 1);
    if (id === "todo") out.todo = { title, progress: Number(r.progress) || 0, state: r.state };
    else if (kind === "bg" || kind === "subagents") {
      const item = { id: key, name: title || key, state: r.state, msg };
      (kind === "bg" ? out.jobs : out.subagents).push(item);
      if (r.state === "error") out.failed.push({ kind: kind === "bg" ? "job" : "subagent", name: item.name, msg });
      if (r.state === "blocked") out.blocked.push({ kind: "subagent", name: item.name, title, msg: msg || "waiting for user" });
    } else if (kind === "wait") out.consults.push(key);
    else if (kind === "sent") out.sent.push(key);
    else if (kind === "ask") {
      const m = msg || `question from ${key}`;
      out.asks.push({ peer: key, msg: m });
      out.blocked.push({ kind: "ask", name: key, title, msg: m });
    }
  }
  // Failures sort jobs before subagents, as they are listed above.
  out.failed.sort((a, b) => (a.kind === b.kind ? 0 : a.kind === "job" ? -1 : 1));
  out.blocked.sort((a, b) => (a.kind === b.kind ? 0 : a.kind === "subagent" ? -1 : 1));
  return out;
}

const PROGRAMS = [
  { keys: ["gentle-shell", "pi"], badge: "GS", name: "Gentle Shell" },
  { keys: ["claude-code", "claude"], badge: "CC", name: "Claude Code" },
  { keys: ["codex"], badge: "CX", name: "Codex" },
];

// The program badge of an agent (app report first, then Herdr's program table).
export function programBadge(a) {
  for (const k of [a?.app, a?.program?.key]) {
    const p = PROGRAMS.find((p) => p.keys.includes(k));
    if (p) return { badge: p.badge, name: p.name };
  }
  return { badge: "shell", name: a?.program?.name || "shell" };
}

export function timeAgo(ms) {
  const m = Math.floor(Math.max(0, ms) / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

// A time with the word that says what it measures (S6: times labeled).
export function timeLabel(status, ms) {
  if (ms == null || !Number.isFinite(ms)) return "";
  const t = timeAgo(ms);
  if (status === "blocked") return `waiting ${t}`;
  if (status === "working" || status === "waiting") return `for ${t}`;
  if (status === "done") return `done ${t} ago`;
  if (status === "failed") return `failed ${t} ago`;
  return t;
}

// What needs you first (S6 order): blocked, failed recently, working, waiting, done unseen, idle.
export const URGENCY = { blocked: 5, failed: 4, working: 3, waiting: 2, done: 1, idle: 0 };

const WORD = { blocked: "Blocked", working: "Working", waiting: "Waiting", done: "New", idle: "Idle" };

const telling = (s) => {
  const raw = String(s ?? "").trim();
  if (/^[~/]|^[A-Za-z]:\\/.test(raw) || raw.includes("@")) return "";
  // Gentle Shell titles read "π - <session or folder>"; the π is the program, not the task.
  return raw.replace(/^π\s*[-–·:]\s*/u, "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
};

const meaningfulTab = (a) => (a?.tab_name && !/^\d+$/.test(a.tab_name) ? a.tab_name : "");
const SHELLS = /^(zsh|bash|fish|sh|nu|pwsh|login)$/i;

// What an agent is called (S6: the session or task, not the space): the Gentle Shell session's own
// name, the pane's name, the agent's decoded title when it reads like a task, the tab's name, the
// session's folder, then the space.
export function agentName(agent, feed) {
  const own = typeof feed?.identity?.sessionName === "string" ? feed.identity.sessionName.trim() : "";
  if (own) return own;
  if (agent?.pane_name) return agent.pane_name;
  const title = telling(agent?.title);
  if (title && !SHELLS.test(title) && title.toLowerCase() !== agent?.program?.key) return title;
  return meaningfulTab(agent) || sessionName(feed) || agent?.space_name || programBadge(agent).name;
}

// Names that still collide get the tab's name, then "#n" in list order.
export function disambiguate(cards) {
  const key = (s) => String(s ?? "").toLowerCase();
  const count = (xs, f) => xs.reduce((m, x) => m.set(f(x), (m.get(f(x)) ?? 0) + 1), new Map());
  const byName = count(cards, (c) => key(c.name));
  // An auto-named tab ("Pi · cortex-dotfiles · 2", refactoria-tabs) only adds what follows its
  // "Program · " prefix; when that repeats the card's name, only the rest is added.
  const extra = (c) => {
    const ctx = String(c.tab ?? "").replace(/^(Pi|Claude|Codex|Terminal|[a-z][\w-]*) · /, "");
    if (!ctx || key(ctx) === key(c.name)) return "";
    return key(ctx).startsWith(key(c.name)) ? ctx.slice(c.name.length) : ` · ${ctx}`;
  };
  const step = cards.map((c) => (byName.get(key(c.name)) > 1 && extra(c) ? { ...c, name: `${c.name}${extra(c)}` } : c));
  const left = count(step, (c) => key(c.name));
  const seen = new Map();
  return step.map((c) => {
    const k = key(c.name);
    if (left.get(k) < 2) return c;
    seen.set(k, (seen.get(k) ?? 0) + 1);
    return { ...c, name: `${c.name} #${seen.get(k)}` };
  });
}

// Since when an agent is in its state (ms): Herdr's terminal status_ms (local terminals), else the
// mod's own stamp of the last change it saw, else when the terminal started.
export function idleSince(term, changedAt) {
  return term?.status_ms || changedAt || term?.created_ms || null;
}

// Idle agents untouched for this long are hidden (kept terminals of old work), unless focused or
// pinned; an agent of unknown age stays.
export const STALE_MS = 24 * 3600000;

export function freshIdle(rows, now, max = STALE_MS) {
  const keep = (c) => c.focused || c.pinned || !c.since || now - c.since <= max;
  const out = (rows ?? []).filter(keep);
  return { rows: out, hidden: (rows ?? []).length - out.length };
}

// The Agents section with nothing running: one quiet line.
export const emptyLine = (idle) => (idle ? `Nothing running · ${idle} idle` : "Nothing running");

const machineOf = (address) => {
  const m = /^([^/]+)\/./.exec(typeof address === "string" ? address : "");
  return m ? m[1] : null;
};

const uniq = (xs) => [...new Set(xs.filter(Boolean))];

// One card: the agent (agents() entry), its feed snapshot with feed.js liveState / needsYou when it
// is a local Gentle Shell session, its OSC 7501 records, since when it is in its state (ms), and its
// sub-agent terminals ({ name, status }: they show as chips, a blocked or failed one raises the card).
// `term` is the agent's terminals() entry: its reported status, turn and herdr.seen label.
export function buildCard({ agent, feed = null, live = null, need = null, records = null, term = null, since = null, now = Date.now(), kids = [] }) {
  const rec = parseRecords(records);
  for (const k of kids) {
    const state = k.status === "blocked" ? "blocked" : k.status === "error" ? "error" : k.status === "working" ? "working" : "idle";
    rec.subagents.push({ id: k.name, name: k.name, state, msg: "" });
    if (state === "blocked") rec.blocked.push({ kind: "subagent", name: k.name, msg: `${k.name} waits for you` });
    if (state === "error") rec.failed.push({ kind: "subagent", name: k.name, msg: "" });
  }
  const program = programBadge(agent);
  const machine = machineOf(agent?.address);
  // The most urgent of every source (T10): the feed snapshot is polled and may lag, Herdr's
  // agents() turns a seen "done" into idle, and Gentle Shell reports "done" between wakeups.
  const known = (s) => (s === "blocked" || s === "working" || s === "waiting" || s === "done" ? s : "idle");
  const reported = term?.status?.state;
  const turn = Number(term?.turn), seen = Number(term?.labels?.["herdr.seen"]);
  const unseen = reported === "done" && Number.isFinite(turn) && Number.isFinite(seen) && turn > seen;
  let activity = [live?.status, agent?.status, reported === "working" || reported === "blocked" ? reported : null, unseen ? "done" : null]
    .map(known).reduce((a, b) => ((URGENCY[b] ?? 0) > (URGENCY[a] ?? 0) ? b : a), "idle");
  if (rec.blocked.length) activity = "blocked";
  else if ((activity === "idle" || activity === "done") && (rec.todo?.state === "working" || rec.jobs.some((j) => j.state === "working") || rec.subagents.some((s) => s.state === "working"))) activity = "working";
  const status = activity !== "blocked" && rec.failed.length ? "failed" : activity;

  const opened = Date.parse(feed?.pendingQuestion?.openedAt ?? "");
  const from = activity === "blocked" && Number.isFinite(opened) ? opened : since;
  const time = from ? timeLabel(status, now - from) : "";

  const tabName = meaningfulTab(agent);
  const name = agentName(agent, feed);

  const ask = activity === "blocked" ? questionText({ agent, feed, rec, term, name }) : null;
  const question = ask?.text ?? "";
  const ft = currentTask(feed);
  let task = null;
  if (ft) {
    const pct = ft.total ? Math.round((ft.done / ft.total) * 100) : rec.todo?.progress || 0;
    task = { title: ft.title, pct, label: ft.total ? `${ft.done}/${ft.total}` : `${pct}%` };
  } else if (rec.todo?.title) task = { title: rec.todo.title, pct: rec.todo.progress, label: `${rec.todo.progress}%` };

  const plain = !feed && !rec.todo ? telling(agent?.title) : "";
  const sub = activity === "blocked" ? `${program.name} asks you` : task ? task.title : plain && plain !== name && plain.toLowerCase() !== agent?.program?.key ? plain : "";

  const feedAgents = (feed?.agents?.items ?? []).filter((x) => /^(running|working|active)$/i.test(String(x?.state ?? ""))).map((x) => x.name || x.id);
  const feedJobs = (feed?.jobs?.running ?? []).map((j) => j?.name || j?.label || j?.command || j?.id);
  // The records and the feed describe the same subagents and jobs: records (task titles) win, the
  // feed's names stand in only when no record names any.
  const recAgents = rec.subagents.filter((s) => s.state === "working").map((s) => s.name);
  const recJobs = rec.jobs.filter((j) => j.state === "working").map((j) => j.name);
  const chips = [
    ...uniq(rec.subagents.length ? recAgents : feedAgents).map((label) => ({ kind: "subagent", label })),
    ...uniq(rec.jobs.length ? recJobs : feedJobs).map((label) => ({ kind: "job", label })),
    ...uniq(rec.consults).map((p) => ({ kind: "consult", label: `consulting ${p}` })),
    ...rec.failed.map((f) => ({ kind: "failed", label: f.msg ? `${f.name} · ${f.msg}` : `${f.name} failed` })),
  ];

  const meta = [machine ?? "This computer"];
  if (feed) {
    if (feed.project?.branch) meta.push(feed.project.branch);
    if (feed.model?.id) meta.push([feed.model.id, feed.model.effort].filter(Boolean).join(" "));
    if (Number.isFinite(feed.context?.percent)) meta.push(`ctx ${Math.round(feed.context.percent)}%`);
    if (Number(feed.cost?.total) > 0) meta.push(`$${Number(feed.cost.total).toFixed(2)}`);
  } else meta.push(program.name);

  const word = status === "failed" ? `${rec.failed.length} failed` : WORD[status] ?? "Idle";
  return { address: agent?.address, pane: agent?.pane ?? null, spaceId: agent?.space ?? null, space: agent?.space_name ?? "", focused: Boolean(agent?.focused), pinned: Boolean(agent?.pinned), tab: tabName, machine, name, program, status, activity, word, time, since: from ?? 0, question, quoted: Boolean(ask?.quoted), sub, task, chips, meta };
}

// The line a blocked card shows (T22), from the best source that carries real text: the feed's
// pending question (local sessions), its blocked label, a blocked OSC 7501 record's msg with its
// title, Herdr's status msg (remote sessions too) when it is not just the session title; else an
// honest line saying where the question is. Never invented text. `quoted`: it is the agent's words.
export const QUESTION_ELSEWHERE = "The question is in its terminal · Open the pane to answer";
const oneLine = (s) => (typeof s === "string" ? s.replace(/\s+/g, " ").trim() : "");
function questionText({ agent, feed, rec, term, name }) {
  const fromFeed = oneLine(feed?.pendingQuestion?.question) || oneLine(feed?.activity?.blockedLabel);
  if (fromFeed) return { text: fromFeed, quoted: true };
  const b = rec.blocked.find((x) => oneLine(x.msg));
  if (b) {
    const title = oneLine(b.title);
    return { text: title && title !== oneLine(b.msg) ? `${title} · ${oneLine(b.msg)}` : oneLine(b.msg), quoted: true };
  }
  const msg = oneLine(decodeB64(term?.report?.msg ?? (typeof term?.status === "object" ? term?.status?.msg : "")));
  const own = [agent?.title, telling(agent?.title), name, feed?.identity?.sessionName].map((x) => oneLine(x).toLowerCase());
  if (msg && !own.includes(msg.toLowerCase())) return { text: msg, quoted: true };
  return { text: QUESTION_ELSEWHERE, quoted: false };
}

// Most urgent first; among blocked the longest wait leads, otherwise the latest change.
export function sortCards(cards) {
  return [...cards].sort((x, y) => (URGENCY[y.status] ?? 0) - (URGENCY[x.status] ?? 0)
    || (x.status === "blocked" ? (x.since ?? 0) - (y.since ?? 0) : (y.since ?? 0) - (x.since ?? 0)));
}

export function splitCards(cards) {
  return { active: cards.filter((c) => c.status !== "idle"), idle: cards.filter((c) => c.status === "idle") };
}

// The quiet idle list: a summary line while collapsed (the default), every row when open.
export function idleView(rows, open) {
  if (!rows.length) return { summary: "", rows: [], open: Boolean(open) };
  const machines = new Set(rows.map((r) => r.machine ?? ""));
  const where = machines.size === 1 ? (rows[0].machine ?? "this computer") : `${machines.size} machines`;
  return { summary: `${rows.length} idle · ${where}`, rows: open ? rows : [], open: Boolean(open) };
}

// No stale duplicates: each address once, and never a terminal that is no longer live.
export function liveAgents(list, terms) {
  const state = new Map((terms ?? []).map((t) => [t.address, t.state]));
  const seen = new Set();
  return (list ?? []).filter((a) => {
    if (!a?.address || seen.has(a.address)) return false;
    seen.add(a.address);
    const s = state.get(a.address);
    return s === undefined || s === "live";
  });
}

// ---- Sessions v2 (design/herdr-desktop-ux/04-sessions-v2.html): calm idle ----

const ICONS = "mods/refactoria-agents/icons";
const startOfDay = (now) => { const d = new Date(now); d.setHours(0, 0, 0, 0); return d.getTime(); };
const today = (c, now) => Boolean(c?.since) && c.since >= startOfDay(now) && c.since <= now;

// The cards in the sidebar's order: what needs you (blocked, failed), what runs, and the quiet rest
// (a finished, unseen turn is quiet: a "New" row in the idle list, not a card).
export function sections(cards) {
  const of = (...s) => cards.filter((c) => s.includes(c.status));
  return { needs: of("blocked", "failed"), running: of("working", "waiting"), quiet: of("done", "idle") };
}

// Quiet agents by recency: Just now (<15 m), This hour, Earlier today (the first `shown` rows,
// the rest behind "Show N more" unless open). Unknown age counts as earlier.
export function recencyGroups(rows, now, open, shown = 2) {
  const sorted = [...(rows ?? [])].sort((x, y) => (y.since || 0) - (x.since || 0));
  const age = (c) => (c.since ? now - c.since : Infinity);
  const groups = [
    { id: "now", label: "Just now", all: sorted.filter((c) => age(c) < 15 * 60000) },
    { id: "hour", label: "This hour", all: sorted.filter((c) => age(c) >= 15 * 60000 && age(c) < 3600000) },
    { id: "earlier", label: "Earlier today", all: sorted.filter((c) => age(c) >= 3600000) },
  ];
  return groups.filter((g) => g.all.length).map(({ id, label, all }) => {
    const rows = id === "earlier" && !open ? all.slice(0, shown) : all;
    return { id, label, count: all.length, rows, more: all.length - rows.length };
  });
}

// Today's activity for the calm block: agents whose state changed today (Herdr's status_ms).
export function todaySummary(cards, now) {
  const ran = (cards ?? []).filter((c) => today(c, now));
  const n = (...s) => ran.filter((c) => s.includes(c.status)).length;
  const machines = new Set((cards ?? []).map((c) => c.machine ?? "")).size;
  return { ran: ran.length, finished: n("done", "idle"), failed: n("failed"), needs: n("blocked"), machines };
}

// The latest agent that finished today, for the calm block's "Last finished".
export function lastFinished(cards, now) {
  const c = (cards ?? []).filter((c) => (c.status === "done" || c.status === "idle") && today(c, now)).sort((x, y) => y.since - x.since)[0];
  return c ? { card: c, label: `Last finished · ${timeAgo(now - c.since)} ago`, where: machineLabel(c.machine) } : null;
}

const PROGRAM_ICON = { GS: "p-gs", CC: "p-cc", CX: "p-cx" };
export const programIcon = (program) => `${ICONS}/${PROGRAM_ICON[program?.badge] ?? "p-sh"}.svg`;
export const machineIcon = (machine) => `${ICONS}/${!machine ? "laptop" : machine === "agent-gentle" ? "cloud" : "server"}.svg`;
export const machineLabel = (machine) => machine || "This computer";

const PILL = { blocked: "Needs you", failed: "Failed", working: "Working", waiting: "Waiting", done: "New", idle: "Idle" };

// A card's state pill: the word, with how long for the states that wait on you.
export function pillLabel(c, now) {
  const word = PILL[c?.status] ?? "Idle";
  return (c?.status === "blocked" || c?.status === "failed") && c.since ? `${word} · ${timeAgo(now - c.since)}` : word;
}

// The two lines of a quiet row: name, "New" when the turn was not seen, age; then the last task
// (or the space when the name is not it) and where it runs.
export function idleLines(c, now) {
  const isNew = c.status === "done";
  const space = c.space && String(c.space).toLowerCase() !== String(c.name).toLowerCase() ? c.space : "";
  const task = c.sub || c.task?.title || space;
  const age = c.since ? timeAgo(now - c.since) : "";
  const where = machineLabel(c.machine);
  const label = [c.name, isNew ? "finished, not seen yet" : "idle", task, where, age && `${age} ago`].filter(Boolean).join(", ");
  return { name: c.name, isNew, age, task, where, label };
}

// ---- Split roles (design/herdr-spaces/04-split-roles.html): one reduction, two sidebars ----

// The cards of every live top-level agent (agents() entries `agents`, terminals() `terms`): a
// sub-agent with its own terminal is a chip on its parent's card, never a card of its own.
// `sessionOf(agent)`: { session, feed, live, need } for a local Gentle Shell session, else null;
// `sinceOf(agent)`: since when it is in its state (ms). refactoria-spaces reduces these same cards
// to its dots (spaceDot), so both sidebars agree on every agent's state at the same moment.
export function agentCards({ agents = [], terms = [], sessionOf = () => null, sinceOf = () => null, now = Date.now() } = {}) {
  const list = liveAgents(agents, terms);
  const listed = new Set(list.map((a) => a.address));
  const termOf = new Map((terms ?? []).map((x) => [x.address, x]));
  const parentOf = new Map((terms ?? []).filter((x) => x.parent).map((x) => [x.address, x.parent]));
  const kidsOf = new Map();
  for (const a of list) {
    const p = parentOf.get(a.address);
    if (!p || !listed.has(p)) continue;
    const term = termOf.get(a.address);
    kidsOf.set(p, [...(kidsOf.get(p) ?? []), { name: term?.name || term?.template || a.title || a.program?.name || a.address, status: a.status }]);
  }
  return list.filter((a) => !listed.has(parentOf.get(a.address))).map((a) => {
    const s = sessionOf(a);
    const c = buildCard({ agent: a, feed: s?.feed ?? null, live: s?.live ?? null, need: s?.need ?? null, records: termOf.get(a.address)?.records, term: termOf.get(a.address) ?? null, since: sinceOf(a), now, kids: kidsOf.get(a.address) ?? [] });
    return { ...c, session: s?.session ?? null };
  });
}

// A space's one dot: its most urgent agent, needs you › failed › working (or waiting) › done
// unseen; idle spaces have none. `kind` is the color (theme blocked / failed / working / done).
const DOT = { blocked: 4, failed: 3, working: 2, waiting: 2, done: 1 };
const DOT_WORD = { blocked: "needs you", failed: "failed", working: "working", waiting: "waiting on its subagents", done: "done, not seen yet" };
export function spaceDot(cards) {
  const top = (cards ?? []).filter((c) => DOT[c?.status]).reduce((a, c) => (!a || DOT[c.status] > DOT[a.status] ? c : a), null);
  if (!top) return null;
  const word = DOT_WORD[top.status];
  return { kind: top.status === "waiting" ? "working" : top.status, status: top.status, word, label: `${top.program?.name || "shell"} ${word}` };
}

// The dot's tooltip (the accessible label says the same in the row's name).
export const dotTooltip = (space, dot) => (dot ? `${space} · ${dot.label}` : "");

// The Agents tray header's live summary: only non-zero parts, in words (never color alone).
export function traySummary(cards) {
  const { needs, running, quiet } = sections(cards ?? []);
  const blocked = needs.filter((c) => c.status === "blocked").length;
  const failed = needs.length - blocked;
  const parts = [];
  if (blocked) parts.push({ kind: "blocked", text: `${blocked} needs you` });
  if (failed) parts.push({ kind: "failed", text: `${failed} failed` });
  if (running.length) parts.push({ kind: "working", text: `${running.length} running` });
  if (parts.length) {
    if (quiet.length) parts.push({ kind: "idle", text: `${quiet.length} idle` });
    return { parts, label: parts.map((p) => p.text).join(", ") };
  }
  const text = quiet.length ? `All quiet · ${quiet.length} idle` : "All quiet";
  return { parts: [{ kind: "idle", text }], label: text.replace(" · ", ", ") };
}
