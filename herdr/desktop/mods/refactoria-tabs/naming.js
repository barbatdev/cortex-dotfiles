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

// Rename only names Herdr gave (unnamed, its number, the terminal title) or the one this mod set
// last; a name the person chose stays until they clear it.
export function shouldRename({ tab, computed, last, title }) {
  if (!tab || !computed || tab.name === computed) return false;
  const ours = last != null && tab.name === last;
  const herdrs = !tab.named || tab.name === "" || tab.name === String(tab.index) || (title != null && (tab.name === title || tab.name === plain(title)));
  return ours || herdrs;
}
