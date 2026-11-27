// Pure row model for the spaces list: what a space's Gentle Shell session adds to its row.
// No "herdr" import so node --test can load it (tests/herdr_spaces_test.mjs).
// Kept apart from refactoria-agents/rows.js: a mod cannot import outside its folder.

const baseName = (p) => String(p ?? "").replace(/[/\\]+$/, "").split(/[/\\]/).pop() || "";

// The session's name, else its project folder's name.
export function sessionName(feed) {
  const id = feed?.identity;
  if (!id) return "";
  const name = typeof id.sessionName === "string" ? id.sessionName.trim() : "";
  return name || baseName(id.realCwd || feed?.project?.cwd || id.cwd);
}

const IN_PROGRESS = /^(in[_ -]?progress|active|doing|working)$/i;

// The title of the task the session is on: todo.current, else the first in-progress item.
export function currentTask(feed) {
  const todo = feed?.todo;
  if (!todo) return null;
  const cur = todo.current;
  let title = typeof cur === "string" ? cur : cur?.title;
  if (!title) title = (todo.items ?? []).find((i) => IN_PROGRESS.test(String(i?.state ?? "")))?.title;
  return title ? String(title) : null;
}

const trim = (p) => String(p ?? "").replace(/\/+$/, "");

// The space id a session belongs to, or null. `session`: { terminal: its Herdr terminal address or
// null, project: feed.js projectOf }. `ctx`: { home, byTerminal: terminal address -> space id
// (agents()/panes()), places: [{ id, place: the space's live folder, repo: that folder is in a git
// repo, machine }] }. A session in a Herdr terminal belongs to that terminal's space, exactly.
// Otherwise its project folder must be a local space's folder, or inside it when that space is a
// repo: a plain parent (home, ~/dev) never captures the projects under it. Deepest wins.
export function spaceOfSession(session, ctx) {
  if (session?.terminal) {
    const id = ctx?.byTerminal?.[session.terminal];
    if (id) return id;
  }
  const path = trim(session?.project);
  if (!path) return null;
  let best = null;
  for (const s of ctx?.places ?? []) {
    const f = trim(s?.place);
    if (!f || s.machine || f === trim(ctx?.home)) continue;
    if (!(path === f || (s.repo && path.startsWith(`${f}/`)))) continue;
    if (!best || f.length > trim(best.place).length) best = s;
  }
  return best?.id ?? null;
}

const URGENCY = { blocked: 3, working: 2, waiting: 1, idle: 0 };

// The session a space shows among those in it ({ feed, live }, live = feed.js liveState):
// the one that needs the person most, then the latest to change.
export function pickSession(list) {
  return [...(list ?? [])].sort((x, y) =>
    (URGENCY[y.live?.status] ?? 0) - (URGENCY[x.live?.status] ?? 0)
    || String(y.feed?.updatedAt ?? "").localeCompare(String(x.feed?.updatedAt ?? "")))[0] ?? null;
}

// A space row's text: `state` the indicator after the name (null when idle), `other` the
// session's name when it differs from the space's, `second` the second line (the task, else
// the git line `git`), `tooltip` the git line when the task took its place.
export function spaceLines({ space, git, session }) {
  const live = session?.live;
  const state = live && live.status !== "idle" ? { status: live.status, label: live.label } : null;
  const name = session ? sessionName(session.feed) : "";
  // Not repeated when it only says the space's or the project folder's name.
  const id = session?.feed?.identity;
  const same = [space, baseName(id?.realCwd || session?.feed?.project?.cwd || id?.cwd)].map((x) => String(x ?? "").toLowerCase());
  const other = name && !same.includes(name.toLowerCase()) ? name : "";
  const task = session ? currentTask(session.feed) : null;
  return { state, other, second: task || git || "", tooltip: task && git ? git : "" };
}

// ---- Quiet list (design/herdr-spaces/01-quiet-list.html) ----

// `git status --porcelain=v2 --branch` -> branch (null when detached), ahead, behind, and how
// many paths have uncommitted changes (tracked, renamed, unmerged or untracked; not ignored).
export function parseStatus(stdout) {
  const info = { branch: null, ahead: 0, behind: 0, dirty: 0 };
  for (const line of String(stdout ?? "").split("\n")) {
    if (line.startsWith("# branch.head ")) {
      const b = line.slice(14).trim();
      info.branch = b === "(detached)" ? null : b;
    } else if (line.startsWith("# branch.ab ")) {
      const [a, b] = line.slice(12).split(" ");
      info.ahead = Math.abs(parseInt(a, 10)) || 0;
      info.behind = Math.abs(parseInt(b, 10)) || 0;
    } else if (/^[12u?] /.test(line)) info.dirty += 1;
  }
  return info;
}

// Space id -> its shortcut number (Ctrl+A Ctrl+N, keys.json "refactoria-spaces.agent-N"),
// for the first nine in the order the list shows them.
export function shortcutNumbers(ids) {
  const out = {};
  (ids ?? []).slice(0, 9).forEach((id, i) => { out[id] = i + 1; });
  return out;
}

// The branch line: the branch (always, a quiet list has room), ahead/behind and uncommitted
// counts, and the words a screen reader says for it.
export function branchLine(g) {
  if (!g) return { branch: "", ahead: 0, behind: 0, dirty: 0, label: "no git branch" };
  const branch = g.branch || "detached";
  const ahead = g.ahead || 0, behind = g.behind || 0, dirty = g.dirty || 0;
  const label = [branch, ahead && `${ahead} ahead`, behind && `${behind} behind`, dirty && `${dirty} uncommitted change${dirty === 1 ? "" : "s"}`].filter(Boolean).join(", ");
  return { branch, ahead, behind, dirty, label };
}

const WORD = { blocked: "Needs you", failed: "Failed", working: "Working", waiting: "Waiting", done: "New", idle: "Idle" };

// A row's state pill and its third line. `session`: { feed, live } (pickSession) or null;
// `agent`: { status, program: name } (the space's pickAgent) or null; `question`: the open
// question; `waits`: spaceWaits(); `status`: the space's own status; `failed`: a failure record.
// Needs you > Failed > Working > Waiting (on its subagents) > New > Idle (a session that is just there).
export function spaceRow({ session = null, agent = null, question = "", waits = false, status = null, failed = false } = {}) {
  const live = session?.live?.status;
  let kind = null;
  if (live === "blocked" || agent?.status === "blocked" || (waits && status === "blocked")) kind = "blocked";
  else if (failed) kind = "failed";
  else if (live === "working" || agent?.status === "working") kind = "working";
  else if (live === "waiting") kind = "waiting";
  else if (waits) kind = "done";
  else if (session) kind = "idle";
  const program = session ? "Gentle Shell" : agent?.program || "";
  const text = kind === "blocked" && question ? `Asks: “${question}”` : session ? currentTask(session.feed) || "" : "";
  const task = program && text ? `${program} · ${text}` : "";
  return { pill: kind ? { kind, word: WORD[kind] } : null, task, lines: task ? 3 : 2 };
}

// A folded machine's one line: the shortcut range it holds, then its first space names.
export function foldedSummary(rows, shown = 3) {
  const ns = (rows ?? []).map((r) => r.n).filter((n) => n != null);
  const range = ns.length ? (ns.length === 1 ? String(ns[0]) : `${Math.min(...ns)}–${Math.max(...ns)}`) : "";
  const names = (rows ?? []).slice(0, shown).map((r) => r.name).join(", ");
  const more = (rows ?? []).length > shown ? ` +${rows.length - shown}` : "";
  return [range, names + more].filter(Boolean).join(" · ");
}

// Fixed heights (px) of what the block draws, so it can take the height its content needs and
// Agents sits right below it. Rows include their 1 px gap.
export const HEIGHT = { head: 36, pad: 8, machine: 32, row2: 47, row3: 65, folded: 22, loading: 28, empty: 28, compact: 26 };
export const rowHeight = (lines) => (lines >= 3 ? HEIGHT.row3 : HEIGHT.row2);

// parts: [{ kind: "machine" | "row" (with lines) | "folded" | "loading" | "empty" | "compact" }].
export function blockHeight(parts) {
  let px = HEIGHT.head + HEIGHT.pad;
  for (const p of parts ?? []) px += p.kind === "row" ? rowHeight(p.lines) : HEIGHT[p.kind] ?? 0;
  return px;
}
