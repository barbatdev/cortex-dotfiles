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
