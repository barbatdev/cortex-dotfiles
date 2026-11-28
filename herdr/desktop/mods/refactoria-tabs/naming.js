// Tab auto-naming for refactoria-tabs (T20): "Program · context", pure so node --test covers it
// (tests/herdr_tabs_test.mjs). main.js gathers the inputs and calls tab.rename.

const APPS = { "gentle-shell": "Pi", pi: "Pi", "claude-code": "Claude", claude: "Claude", codex: "Codex" };
const MAX = 32;

// Control characters out, whitespace collapsed.
const plain = (s) => String(s ?? "").replace(/[\p{Cc}\p{Cf}]+/gu, " ").replace(/\s+/g, " ").trim();
const cap = (s) => (s ? s[0].toUpperCase() + s.slice(1) : s);

// Truncates to `max` characters (code points) with "…".
export function truncate(s, max = MAX) {
  const chars = [...plain(s)];
  return chars.length > max ? chars.slice(0, max - 1).join("").trimEnd() + "…" : chars.join("");
}

// A record title: plain text as Pi sends it; base64 of UTF-8 text as a fallback.
export function decodeTitle(s) {
  if (typeof s !== "string" || !s) return "";
  const clean = s.replace(/\s+/g, "");
  if (clean.length < 8 || clean.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(clean)) return s;
  const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const bytes = [];
  let buf = 0, bits = 0;
  for (const ch of clean.replace(/=+$/, "")) {
    buf = ((buf << 6) | B64.indexOf(ch)) & 0xffffff;
    bits += 6;
    if (bits >= 8) { bits -= 8; bytes.push((buf >> bits) & 0xff); }
  }
  // Strict UTF-8: any invalid sequence or control byte means the title was plain text.
  let out = "";
  for (let i = 0; i < bytes.length;) {
    const b = bytes[i];
    const n = b < 0x80 ? 0 : b >= 0xc2 && b < 0xe0 ? 1 : b >= 0xe0 && b < 0xf0 ? 2 : b >= 0xf0 && b < 0xf5 ? 3 : -1;
    if (n < 0 || i + n >= bytes.length) return s;
    let cp = n ? b & (0x3f >> n) : b;
    for (let k = 1; k <= n; k++) {
      if ((bytes[i + k] & 0xc0) !== 0x80) return s;
      cp = (cp << 6) | (bytes[i + k] & 0x3f);
    }
    // Overlong forms, surrogates and code points past U+10FFFF are not UTF-8 either.
    const min = [0, 0x80, 0x800, 0x10000][n];
    if (cp < min || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) return s;
    if (cp < 0x20 || cp === 0x7f) return s;
    out += String.fromCodePoint(cp);
    i += n + 1;
  }
  return out;
}

// The program part: app report first, then the program table.
export function programLabel({ app, program } = {}) {
  const key = String(app ?? "").toLowerCase();
  if (APPS[key]) return APPS[key];
  const pkey = String(program?.key ?? "").toLowerCase();
  if (APPS[pkey]) return APPS[pkey];
  if (program?.shell) return plain(program.name) || "shell";
  return cap(plain(app || program?.name || "")) || "Terminal";
}

const isPi = (p) => p === "Pi";

// A terminal title that says something: not a path, user@host, the program itself or empty.
function telling(title, program) {
  const raw = plain(title).replace(/^π\s*[-–·:]\s*/u, "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
  if (!raw || /^[~/]|^[A-Za-z]:\\/.test(plain(title)) || raw.includes("@")) return "";
  const low = raw.toLowerCase();
  if (low === program.toLowerCase()) return "";
  return raw;
}

const basename = (p) => plain(p).replace(/[/\\]+$/, "").split(/[/\\]/).pop() || (plain(p) ? "/" : "");

// The context part. `todo`: the terminal's OSC 7501 todo record ({title, state}).
export function contextLabel({ program, todo, title, cwd, space, shell }) {
  if (shell) return basename(cwd) || plain(space);
  if (isPi(program)) {
    const t = todo && todo.state !== "done" ? plain(decodeTitle(todo.title)) : "";
    if (t) return t;
    const raw = plain(title);
    const session = /^π\s*[-–·:]\s*/u.test(raw) ? raw.replace(/^π\s*[-–·:]\s*/u, "").trim() : "";
    return session || plain(space);
  }
  return telling(title, program) || plain(space);
}

// The whole name for a tab's lead pane, or "" when nothing is known.
export function tabName({ app, program, todo, title, cwd, space }) {
  const prog = programLabel({ app, program });
  const shell = Boolean(program?.shell) && !app;
  const ctx = truncate(contextLabel({ program: prog, todo, title, cwd, space, shell }));
  return truncate(ctx ? `${prog} · ${ctx}` : prog, 48);
}

// One tick of auto-naming: which tabs to rename and the updated record of names this mod set
// (`stored`, the localStorage JSON shared by every window). Lead pane: the focused agent, else
// the first agent, else the focused pane, else the first. A tab whose data throws is skipped so
// the others still get named. Closed tabs are forgotten only once every machine is loaded, so an
// offline machine keeps its record.
export function planRenames({ spaces, panes, agents, terminals, stored, machinesReady }) {
  let last;
  try { last = JSON.parse(stored ?? "{}"); } catch { last = {}; }
  if (!last || typeof last !== "object" || Array.isArray(last)) last = {};
  const agentOf = new Map((agents ?? []).map((a) => [a.pane, a]));
  const termOf = (pane, agent) => (terminals ?? []).find((t) => (agent && t.address === agent.address) || (pane.terminal && (t.address === pane.terminal || t.id === pane.terminal)));
  const isAgent = (p) => agentOf.has(p.pane) || p.program?.agent;
  const renames = [];
  const live = new Set();
  const named = []; // tabs this mod names this tick: { tab, space, lead, computed, title }
  let changed = false;
  for (const space of spaces ?? []) for (const tab of space.tabs ?? []) {
    live.add(tab.id);
    try {
      const mine = (panes ?? []).filter((p) => p.tab === tab.id && p.terminal);
      const lead = mine.find((p) => isAgent(p) && p.focused) ?? mine.find(isAgent) ?? mine.find((p) => p.focused) ?? mine[0];
      if (!lead) continue;
      const agent = agentOf.get(lead.pane), term = termOf(lead, agent);
      const title = lead.title;
      const computed = tabName({ app: agent?.app ?? lead.app ?? term?.report?.app ?? null, program: lead.program, todo: term?.records?.todo ?? null, title, cwd: lead.cwd, space: space.name });
      if (!computed || !autoNamed({ tab, last: last[tab.id] ?? null, title })) continue;
      named.push({ tab, space, lead, computed, title });
    } catch {
      // this tab's data is unusable this tick; the others go on
    }
  }
  for (const { tab, name } of distinctNames(named)) {
    if (tab.name === name) continue;
    last[tab.id] = name; changed = true;
    renames.push({ id: tab.id, name });
  }
  if (machinesReady) for (const id of Object.keys(last)) if (!live.has(id)) { delete last[id]; changed = true; }
  return { renames, stored: JSON.stringify(last), changed };
}

// Tabs of one space that would read the same get the most telling difference: the pane names,
// else the lead panes' git branches (when every one is set and they all differ), else " · 2",
// " · 3" in tab order with the first keeping the plain name. The suffix always stays visible.
function distinctNames(named) {
  const groups = new Map();
  for (const n of named) {
    const key = `${n.space.id ?? n.space.name}\u0000${n.computed}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(n);
  }
  const out = [];
  for (const group of groups.values()) {
    if (group.length === 1) { out.push({ tab: group[0].tab, name: group[0].computed }); continue; }
    const by = [(n) => plain(n.lead.name), (n) => plain(n.lead.branch)]
      .map((f) => group.map(f))
      .find((vals) => vals.every(Boolean) && new Set(vals).size === vals.length);
    group.forEach((n, i) => {
      const extra = by ? truncate(by[i], 24) : i ? String(i + 1) : "";
      const suffix = extra ? ` · ${extra}` : "";
      out.push({ tab: n.tab, name: suffix ? truncate(n.computed, 48 - [...suffix].length) + suffix : n.computed });
    });
  }
  return out;
}

// A tab this mod may name: unnamed, Herdr's number, the terminal title, or the name this mod set
// last. A name the person chose stays until they clear it.
function autoNamed({ tab, last, title }) {
  const ours = last != null && tab.name === last;
  const herdrs = !tab.named || tab.name === "" || tab.name === String(tab.index) || (title != null && (tab.name === title || tab.name === plain(title)));
  return ours || herdrs;
}

// Rename only names Herdr gave or the one this mod set last, and only when the name changes.
export function shouldRename({ tab, computed, last, title }) {
  if (!tab || !computed || tab.name === computed) return false;
  return autoNamed({ tab, last, title });
}
