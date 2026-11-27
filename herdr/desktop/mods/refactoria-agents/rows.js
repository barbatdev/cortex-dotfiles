// Pure row model for the agents list: what one Gentle Shell session shows.
// No "herdr" import so node --test can load it (tests/herdr_agents_test.mjs).

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
export function currentTask(feed) {
  const todo = feed?.todo;
  if (!todo) return null;
  const cur = todo.current;
  let title = typeof cur === "string" ? cur : cur?.title;
  if (!title) title = (todo.items ?? []).find((i) => IN_PROGRESS.test(String(i?.state ?? "")))?.title;
  if (!title) return null;
  return { title: String(title), done: Number(todo.progress?.done) || 0, total: Number(todo.progress?.total) || 0 };
}

const counted = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;

// What the session waits on: the open question (feed.js needsYou), then running agents and jobs.
export function pendingParts(need, live) {
  const out = [];
  if (need) out.push(`${need.word}: ${need.reason}`);
  if (live?.agents > 0) out.push(counted(live.agents, "agent"));
  if (live?.jobs > 0) out.push(counted(live.jobs, "job"));
  return out;
}

// OSC 7501 sub-records of a terminal (terminals()[i].records), when Herdr surfaces them.
export function recordsWork(records) {
  const out = { working: 0, blocked: 0 };
  for (const r of Array.isArray(records) ? records : []) {
    if (r?.state === "working") out.working++;
    else if (r?.state === "blocked") out.blocked++;
  }
  return out;
}

// One session row. `live` = feed.js liveState(feed), `need` = feed.js needsYou(feed); records only
// raise the state (blocked first), never lower what the snapshot says.
export function sessionRow(feed, live, need, records) {
  const rec = recordsWork(records);
  let status = live?.status ?? "idle";
  let label = live?.label ?? "Idle";
  if (rec.blocked && status !== "blocked") { status = "blocked"; label = "Needs you"; }
  else if (rec.working && status === "idle") { status = "working"; label = "Working"; }
  return { name: sessionName(feed), status, label, task: currentTask(feed), pending: pendingParts(need, live) };
}
