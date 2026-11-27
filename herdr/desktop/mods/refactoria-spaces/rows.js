// Pure row model for the spaces list: sessions per space, git line, shortcuts, heights.
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

// The task the session is on: todo.current, else the first in-progress item, with done/total.
// Same answer as refactoria-agents/rows.js: ./model.js (a copy of the Agents one) imports it.
export function currentTask(feed) {
  const todo = feed?.todo;
  if (!todo) return null;
  const cur = todo.current;
  let title = typeof cur === "string" ? cur : cur?.title;
  if (!title) title = (todo.items ?? []).find((i) => IN_PROGRESS.test(String(i?.state ?? "")))?.title;
  if (!title) return null;
  return { title: String(title), done: Number(todo.progress?.done) || 0, total: Number(todo.progress?.total) || 0 };
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
export const HEIGHT = { head: 36, pad: 8, machine: 32, row2: 47, folded: 22, loading: 28, empty: 28, compact: 26 };
// Every space row is two lines (04-split-roles: the agent is a dot, its detail lives in Agents).
export const rowHeight = () => HEIGHT.row2;

// parts: [{ kind: "machine" | "row" | "folded" | "loading" | "empty" | "compact" }].
export function blockHeight(parts) {
  let px = HEIGHT.head + HEIGHT.pad;
  for (const p of parts ?? []) px += p.kind === "row" ? rowHeight() : HEIGHT[p.kind] ?? 0;
  return px;
}
