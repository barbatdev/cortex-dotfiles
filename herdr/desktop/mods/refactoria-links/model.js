// Pure model of the refactoria-links link handler: a clicked link in, what to do out.
// Tested with node --test tests/herdr_links_test.mjs; no Herdr imports here.

// An ssh -L tunnel ends this many seconds after its last connection closed, or when Herdr quits.
export const TUNNEL_IDLE_S = 900;

// owner/name from an origin URL (ssh, https, or an ssh host alias). Copy of refactoria-github's.
export function slug(url) {
  const m = String(url ?? "").trim().match(/[:/]([^/:\s]+\/[^/\s]+?)(?:\.git)?\/?$/);
  return m ? m[1] : null;
}

export const issueUrl = (repo, n) => `https://github.com/${repo}/issues/${n}`;

const isAbs = (p) => p.startsWith("/") || p.startsWith("~");

// The path of a plain file link without its :line[:col] or #L suffix.
function bare(raw) {
  return String(raw ?? "").replace(/^file:\/\//, "").replace(/#L\d+.*$/, "").replace(/(:\d+){1,2}$/, "");
}

// What a click means:
// file with a line → { kind: "file", path, line, column } (Neovim in that space)
// "#123"           → { kind: "issue", number } (the clicked terminal's repo)
// localhost:PORT on another machine → { kind: "tunnel", machine, port, url }
// anything else    → { kind: "pass" } (Herdr's default opener)
export function classify(link, source) {
  const raw = String(link?.raw ?? "").trim();
  const issue = raw.match(/^#(\d+)$/);
  if (issue) return { kind: "issue", number: Number(issue[1]) };
  if (link?.kind === "file") {
    if (!link.line) return { kind: "pass" };
    let path = link.path ?? bare(raw);
    if (!path) return { kind: "pass" };
    if (!isAbs(path)) {
      if (!source?.cwd) return { kind: "pass" };
      path = `${source.cwd.replace(/\/+$/, "")}/${path.replace(/^\.\//, "")}`;
    }
    return { kind: "file", path, line: link.line, column: link.column ?? null };
  }
  if (link?.kind === "url" && source?.machine) {
    const m = String(link.url ?? "").match(/^https?:\/\/(?:localhost|127\.0\.0\.1):(\d+)(?:[/?#]|$)/i);
    if (m) return { kind: "tunnel", machine: source.machine, port: Number(m[1]), url: link.url };
  }
  return { kind: "pass" };
}

// :edit escaping (fnameescape's set), then `<` written as <lt> for --remote-send.
const exEscape = (p) => p.replace(/[ \t\n*?[{`$\\%#'"|!<]/g, (c) => `\\${c}`).replace(/</g, "<lt>");

// Keys for `nvim --server <sock> --remote-send`: leave any mode, open the file at the line.
export function nvimKeys(path, line, column) {
  const go = `<C-\\><C-N>:edit +${line} ${exEscape(path)}<CR>`;
  return column ? `${go}:call cursor(${line}, ${column})<CR>` : go;
}

// A new nvim at the line (and column).
export function nvimArgv(path, line, column) {
  return ["nvim", column ? `+call cursor(${line}, ${column})` : `+${line}`, path];
}

// The pane running Neovim in `space`: in its shown tab first, else its first one.
export function nvimPane(panes, space) {
  if (!space) return null;
  const tabs = space.tabs ?? [];
  const order = [...tabs.filter((t) => t.active), ...tabs.filter((t) => !t.active)].map((t) => t.id);
  const nv = (panes ?? []).filter((p) => p.terminal && p.program?.key === "nvim");
  for (const tab of order) {
    const p = nv.find((x) => x.tab === tab);
    if (p) return p;
  }
  return null;
}

// The ssh target of a Herdr machine (`hc machine ls --json`).
export function sshTarget(ls, name) {
  return (ls?.machines ?? []).find((m) => m.name === name)?.target ?? null;
}

// The port itself when free, else the next free one; null past 65535.
export function choosePort(preferred, busy) {
  for (let p = preferred; p <= 65535; p++) if (!busy.has(p)) return p;
  return null;
}

// A tunnel already open for this machine and remote port, or null.
export function liveTunnel(list, machine, port, now) {
  return (list ?? []).find((t) => t.machine === machine && t.port === port && t.until > now) ?? null;
}

// The clicked URL at the local end of the tunnel.
export function localUrl(url, local) {
  return String(url).replace(/^(https?:\/\/)(?:localhost|127\.0\.0\.1):\d+/i, `$1localhost:${local}`);
}
