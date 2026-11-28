// Ctrl/Cmd-click handler for terminal links (layout root "link_handlers": ["refactoria-links"]):
// - path:line[:col] or path#Lnn → Neovim inside Herdr: the nvim pane already open in that space
//   (sent `:edit +LINE path` through its server), else a split to the right running nvim there.
//   Remote terminals do it on their machine, with that machine's path.
// - #123 → the issue/PR of the clicked terminal's repo, in the browser.
// - http://localhost:PORT or 127.0.0.1:PORT from an agent-dev/agent-gentle terminal → an ssh -L
//   tunnel to that machine (reused for the same machine and port), then the browser locally.
// Everything else passes to Herdr's default. Pure logic lives in ./model.js.
import { exec, hc, panes, spaces, run } from "herdr";
import {
  classify, nvimKeys, nvimArgv, nvimPane, slug, issueUrl, sshTarget, choosePort, liveTunnel, localUrl, TUNNEL_IDLE_S,
} from "./model.js";

// Sends keys to the Neovim whose TUI is pid $1: its server socket belongs to the TUI or to its
// embedded child (nvim.<pid>.0 under $XDG_RUNTIME_DIR on Linux, $TMPDIR/nvim.$USER/*/ on macOS).
const NVIM_SEND = `for p in "$1" $(pgrep -P "$1"); do
  for s in "\${XDG_RUNTIME_DIR:-/nonexistent}/nvim.$p.0" "\${TMPDIR:-/tmp}"/nvim."$USER"/*/nvim."$p".0 /tmp/nvim."$USER"/*/nvim."$p".0; do
    [ -S "$s" ] && exec nvim --server "$s" --remote-send "$2"
  done
done
exit 3`;

// One tunnel: ssh -L in the background, ended when Herdr is gone (the first Herdr process above
// pid $4) or after $5 seconds with no connection through it.
const TUNNEL = `local=$1 port=$2 target=$3 owner=$4 limit=$5
while [ "\${owner:-1}" -gt 1 ] && ! ps -o comm= -p "$owner" | grep -qi herdr; do owner=$(ps -o ppid= -p "$owner" | tr -d ' '); done
[ "\${owner:-1}" -gt 1 ] || owner=$$
ssh -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ServerAliveInterval=30 -L "$local:localhost:$port" "$target" </dev/null >/dev/null 2>&1 &
ssh=$! idle=0
while kill -0 "$ssh" 2>/dev/null && kill -0 "$owner" 2>/dev/null && [ "$idle" -lt "$limit" ]; do
  sleep 15
  if lsof -nP -iTCP:"$local" -sTCP:ESTABLISHED >/dev/null 2>&1; then idle=0; else idle=$((idle + 15)); fi
done
kill "$ssh" 2>/dev/null`;

const TUNNELS_KEY = "refactoria.links.tunnels";

async function openInNvim(c, source) {
  const space = spaces().find((s) => s.id === source.space) ?? null;
  const pane = nvimPane(panes(), space);
  if (pane) {
    const got = await hc(["get", pane.terminal, "--json"]);
    const pid = got.code === 0 ? JSON.parse(got.stdout || "{}").foreground?.pid : null;
    if (pid) {
      const sent = await exec("sh", ["-c", NVIM_SEND, "sh", String(pid), nvimKeys(c.path, c.line, c.column)],
        { on: source.machine ?? undefined, timeout: 5000 });
      if (sent.code === 0) {
        run("pane.focus", { pane: pane.pane });
        return "handled";
      }
    }
  }
  if (source.pane) run("pane.focus", { pane: source.pane });
  run("terminal.open", { argv: nvimArgv(c.path, c.line, c.column), folder: source.cwd ?? undefined, place: source.pane ? "right" : "tab" });
  return "handled";
}

async function openIssue(c, source) {
  if (!source.cwd) return "pass";
  const o = await exec("git", ["remote", "get-url", "origin"], { cwd: source.cwd, on: source.machine ?? undefined, timeout: 5000 });
  const repo = o.code === 0 ? slug(o.stdout) : null;
  if (!repo) return "pass";
  await exec("open", [issueUrl(repo, c.number)]);
  return "handled";
}

const listening = async (port) => (await exec("nc", ["-z", "127.0.0.1", String(port)], { timeout: 2000 })).code === 0;

function loadTunnels() {
  try { return JSON.parse(globalThis.localStorage?.getItem(TUNNELS_KEY) ?? "[]"); } catch { return []; }
}

function saveTunnels(list) {
  try { globalThis.localStorage?.setItem(TUNNELS_KEY, JSON.stringify(list)); } catch { /* reuse is best effort */ }
}

async function tunnel(c) {
  const now = Date.now();
  let list = loadTunnels();
  const known = liveTunnel(list, c.machine, c.port, now);
  if (known && await listening(known.local)) {
    await exec("open", [localUrl(c.url, known.local)]);
    return "handled";
  }
  list = list.filter((t) => t !== known);
  const ls = await hc(["machine", "ls", "--json"]);
  const target = ls.code === 0 ? sshTarget(JSON.parse(ls.stdout || "{}"), c.machine) : null;
  if (!target) throw new Error(`No ssh target for ${c.machine} in hc machine ls`);
  const busy = new Set(list.map((t) => t.local));
  let local = choosePort(c.port, busy);
  while (local !== null && local < c.port + 50 && await listening(local)) {
    busy.add(local);
    local = choosePort(c.port, busy);
  }
  if (local === null || local >= c.port + 50) throw new Error(`No free local port near ${c.port}`);
  // The watcher looks for Herdr above this sh ($PPID) and stops with it.
  await exec("sh", ["-c", `nohup sh -c "$0" sh "$1" "$2" "$3" "$PPID" "$4" >/dev/null 2>&1 &`, TUNNEL,
    String(local), String(c.port), target, String(TUNNEL_IDLE_S)], { timeout: 5000 });
  for (let i = 0; i < 40 && !(await listening(local)); i++) await exec("sleep", ["0.25"]);
  if (!(await listening(local))) throw new Error(`ssh -L ${local}:localhost:${c.port} ${target} did not open`);
  list.push({ machine: c.machine, port: c.port, local, until: now + 24 * 3600 * 1000 });
  saveTunnels(list);
  await exec("open", [localUrl(c.url, local)]);
  return "handled";
}

export async function handleLink({ link, source }) {
  const c = classify(link, source);
  if (c.kind === "file") return openInNvim(c, source);
  if (c.kind === "issue") return openIssue(c, source);
  if (c.kind === "tunnel") return tunnel(c);
  return "pass";
}
