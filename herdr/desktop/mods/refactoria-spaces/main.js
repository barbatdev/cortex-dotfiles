// Workspace spaces as navigation (design/herdr-spaces/04-split-roles.html on 01-quiet-list):
// machine labels, two-line rows (name + one state dot + shortcut number, branch with
// ahead/behind/uncommitted), worktrees under their checkout, a soft raised selection with an
// accent bar. The dot is the space's most urgent agent, reduced by ./model.js exactly as the
// Agents tray does (a byte-identical copy); the detail lives in Agents. Click or Enter to switch,
// right-click for its menu, drag to reorder.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { FeedSource, liveState, needsYou, isGentle } from "./feed.js";
import { agentCards, spaceDot, dotTooltip } from "./model.js";
import { parseStatus, shortcutNumbers, branchLine, foldedSummary, HEIGHT, rowHeight, blockHeight } from "./rows.js";
import { spaces, agents, terminals, machines, panes, run, openOverlay, exec, hc, theme, shared, setShared, watchFolder, window, layout, nextCommand } from "herdr";

const ICONS = "mods/refactoria-spaces/icons";
// Colors the theme has no name for, from the artboard's contrast table: grey meta only on
// chrome (5.16), never on raised (4.19); the focus ring (10.45 on chrome, 8.49 on raised).
const SPARK = "#FFB547";
const CONNECTOR = "#4A3D66";
const MONO = "Menlo";
const palette = (t) => ({ ...t, grey: t.ansi8 ?? "#8F839D", failed: t.ansi1 ?? "#FF6B8A" });
const activate = (e) => e?.key === "enter" || e?.key === "space" || e?.keystroke === "enter" || e?.keystroke === "space";
const machineGlyph = (m) => (!m ? "laptop" : m === "agent-gentle" ? "cloud" : "server");
function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// Where a space is now: its first terminal's live folder, else where it was made.
// `ps`: panes(), read once by the caller (each read copies every pane).
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
// The most the spaces block grows to (about 60% of a laptop-height sidebar); past it, it scrolls.
const FIT_MAX = 520;
const where = (s, ps) => JSON.stringify([s.machine ?? null, place(s, ps)]);
const base = (path) => path.replace(/\/+$/, "").split("/").pop();
// Changes made outside Herdr (an editor's save, a commit in another app): looked
// for this often, in repos the list shows, while the window is in front.
const FALLBACK = 60000;

// The agent a space jumps to: the one that needs you most, then the latest to change.
const URGENCY = { blocked: 3, done: 2, working: 1, idle: 0 };
export function pickAgent(list) {
  return [...list].sort((x, y) => (URGENCY[y.status] ?? 0) - (URGENCY[x.status] ?? 0) || y.seq - x.seq)[0] ?? null;
}

// A space speaks up only when something in it needs you.
export function waits(status) {
  return status === "blocked" || status === "done";
}

export function glyph(status) {
  return waits(status) ? "●" : "·";
}

export function tone(t, status) {
  return t[status] ?? t.unknown;
}

export default class Spaces extends View {
  init(_props, cx) {
    this.git = {}; // where() -> { name, branch, ahead, behind, repo, linked }, null: not a repo
    this.checked = {}; // where() -> when it was last looked at
    this.unsure = new Set(); // where()s git couldn't answer for (a machine away)
    this.pending = new Set(); // where()s to look at next
    this.busy = {}; // pane -> an agent working or a program in front of its shell
    this.ready = {}; // machine -> its layout was readable at the last look
    this.at = {}; // space -> its where() at the last look
    this.watching = new Set(); // local repos' git folders
    // Spaces made while this runs wait (at most a moment) for their git, so a
    // worktree appears under its repo instead of jumping there.
    this.shown = new Set(spaces().map((s) => s.id));
    this.born = {};
    this.pressed = null;
    this.over = null;
    this.machines = [];
    this.folded = new Set(JSON.parse(localStorage.getItem("machines.folded") ?? "[]"));
    // Gentle Shell sessions (./feed.js): this mod is the one reader that
    // publishes them for every other refactoria mod.
    this.feed = new FeedSource();
    this.feed.start(cx, null, 10000, { lead: true });
    this.refreshMachines(cx);
    cx.timer.every(15000, cx => this.refreshMachines(cx));
    // `git status` walks the whole tree, on another machine a process there:
    // only when its answer could have changed (see `due`).
    cx.timer.every(250, (cx) => this.checkNew(cx));
    this.listenKeys(cx);
    // The block takes the height its rows need (render tallies it), so Agents sits right below.
    this.hovered = null;
    this.measured = 0;
    this.sizedTo = null;
    cx.timer.every(500, () => this.fitBlock());
    // Dots follow the agents' state as the Agents tray does (it redraws on the same changes).
    cx.timer.every(2000, (cx) => cx.notify());
  }

  // Sizes the "spaces" layout block to its content (rows.js blockHeight: header, machine labels,
  // two-line rows, folded summaries), between 90 px and FIT_MAX, beyond which it scrolls.
  fitBlock() {
    if (!this.measured) return;
    const px = Math.max(90, Math.min(FIT_MAX, Math.ceil(this.measured)));
    if (px === this.sizedTo) return;
    this.sizedTo = px;
    run("layout.resize", { id: "spaces", px });
  }

  // keys.json "refactoria-spaces.agent-N" (Ctrl+A Ctrl+N, as in Herdr TUI): go to
  // the agent of the Nth space as this list numbers them; a space without one is shown.
  listenKeys(cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const m = /^agent-([1-9])$/.exec(await nextCommand());
        if (m) this.focusAgent(Number(m[1]));
        cx.notify();
      }
    });
  }

  // Spaces in the order the list shows them: this computer first, then machines by name.
  spaceOrder() {
    const rows = this.ordered();
    const remote = [...new Set(rows.map((r) => r.w.machine).filter(Boolean))].sort();
    return [null, ...remote].flatMap((m) => rows.filter((r) => (r.w.machine ?? null) === m).map((r) => r.w));
  }

  focusAgent(n) {
    const w = this.spaceOrder()[n - 1];
    if (!w) return;
    const best = pickAgent(agents().filter((a) => a.space === w.id));
    best ? run("pane.focus", { pane: best.pane }) : run("space.select", { id: w.id });
  }

  checkNew(cx) {
    const now = Date.now();
    const sp = spaces();
    for (const s of sp) if (!this.shown.has(s.id)) this.born[s.id] ??= now;
    const due = this.due(now, sp, panes());
    if (due.size) this.refreshGit(due, cx);
    if (sp.some((s) => !this.shown.has(s.id))) cx.notify();
  }

  // Places whose git could have changed: new ones (a new space, a cd), where a
  // command or an agent's turn just ended (a checkout, a commit, edits), those on
  // a machine that is back, and repos in view whose fallback is due.
  due(now, sp, ps) {
    // Moved there: what it knew of that place may be old.
    const at = {};
    for (const s of sp) at[s.id] = where(s, ps);
    const keys = new Set(Object.values(at).filter((k) => JSON.parse(k)[1]));
    const due = new Set([...keys].filter((k) => !(k in this.git)));
    for (const [id, k] of Object.entries(at)) if (this.at[id] && this.at[id] !== k && keys.has(k)) due.add(k);
    this.at = at;
    const spaceOf = {};
    for (const s of sp) for (const t of s.tabs ?? []) spaceOf[t.id] = s;
    const busy = {};
    for (const p of ps) {
      if (!p.terminal || !spaceOf[p.tab]) continue;
      busy[p.pane] = p.status === "working" || !(p.program?.shell || p.program?.agent);
      if (this.busy[p.pane] && !busy[p.pane]) this.sameRepo(at[spaceOf[p.tab].id], keys).forEach((k) => due.add(k));
    }
    this.busy = busy;
    for (const m of machines()) {
      const ready = m.layout === "ready";
      if (ready && this.ready[m.name] === false) for (const k of keys) if (JSON.parse(k)[0] === m.name) due.add(k);
      this.ready[m.name] = ready;
    }
    if (window().active) {
      for (const k of keys) {
        const asks = this.git[k] || this.unsure.has(k);
        if (asks && !this.folded.has(JSON.parse(k)[0]) && now - (this.checked[k] ?? 0) > FALLBACK) due.add(k);
      }
    }
    return due;
  }

  // `key` and the other places in its repo (a commit there moves their ahead/behind).
  sameRepo(key, keys) {
    const repo = this.git[key]?.repo;
    return [key, ...(repo ? [...keys].filter((k) => this.git[k]?.repo === repo) : [])];
  }

  refreshMachines(cx) {
    cx.spawn(async cx => {
      try { const r = await hc(["machine", "ls", "--json"]); if (r.code === 0) this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => !m.temporary); } catch {}
      cx.notify();
    });
  }

  // One look at a time, each place once however often it was asked for meanwhile.
  refreshGit(keys, cx) {
    for (const k of keys) this.pending.add(k);
    if (this.refreshing) return;
    this.refreshing = true;
    cx.spawn(async (cx) => {
      while (this.pending.size) {
        const keys = [...this.pending];
        this.pending.clear();
        for (const key of keys) await this.check(key, cx);
      }
      const used = new Set(Object.values(this.git).filter(Boolean).map((g) => JSON.parse(g.repo)).filter(([on]) => !on).map(([, repo]) => repo));
      for (const repo of this.watching) if (!used.has(repo)) this.watching.delete(repo);
      this.refreshing = false;
      cx.notify();
    });
  }

  // One place's git: branch, ahead/behind, its repo.
  async check(key, cx) {
    const [on, cwd] = JSON.parse(key);
    this.checked[key] = Date.now();
    this.unsure.delete(key);
    try {
      // No optional locks: a status that touched the index would wake the watch again.
      // Writes nothing under .git (index lock, fsmonitor cookie): watch() would wake on it.
      const r = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"], { cwd, on });
      if (r.code !== 0) {
        // Only git's own "no" is remembered as no repo; anything else is asked again.
        if (!/not a git repository/i.test(r.stderr)) this.unsure.add(key);
        this.git[key] = null;
        return;
      }
      // The repo's own .git folder names it; a worktree's top differs from it.
      const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
      const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, on });
      const repo = common.stdout.trim();
      const name = repo.endsWith("/.git") ? base(repo.slice(0, -5)) : base(repo).replace(/\.git$/, "");
      // Branch (null when detached), ahead/behind and the uncommitted count (rows.js parseStatus).
      this.git[key] = { name, ...parseStatus(r.stdout), repo: JSON.stringify([on, repo]), linked: repo !== `${top.stdout.trim()}/.git` };
      if (!on) this.watch(repo, cx);
    } catch {
      // Couldn't ask (the machine is away): keep what it showed, look again later.
      this.git[key] ??= null;
      this.unsure.add(key);
    }
  }

  watch(repo, cx) {
    if (this.watching.has(repo)) return;
    this.watching.add(repo);
    cx.spawn(async (cx) => {
      try {
        while (this.watching.has(repo)) {
          await watchFolder(repo);
          const mine = JSON.stringify([null, repo]);
          if (this.watching.has(repo)) this.refreshGit(Object.keys(this.git).filter((k) => this.git[k]?.repo === mine), cx);
        }
      } catch { this.watching.delete(repo); }
    });
  }

  menu(w) {
    // A popup is as tall as its items; height is only the most.
    openOverlay({ mod: "menu", kind: "popup", width: 200, height: 260, props: { tab: "space", target: { id: w.id } } });
  }

  // Spaces in order, each worktree space moved under its main checkout's.
  ordered() {
    const sp = spaces(), ps = panes();
    const ready = (w) => this.shown.has(w.id) || where(w, ps) in this.git || Date.now() - (this.born[w.id] ??= Date.now()) > 1500;
    for (const w of sp) if (!this.shown.has(w.id) && ready(w)) this.shown.add(w.id);
    const list = sp.map((w, i) => ({ w, i, g: this.git[where(w, ps)] ?? null })).filter((r) => this.shown.has(r.w.id));
    const mains = new Set(list.filter((r) => r.g && !r.g.linked).map((r) => r.g.repo));
    const nested = (r) => r.g?.linked && mains.has(r.g.repo);
    const out = [];
    const placed = new Set(); // repos whose worktrees are listed (under the first of its spaces)
    for (const r of list) {
      if (nested(r)) continue;
      out.push({ ...r, tree: null });
      if (!r.g || r.g.linked || placed.has(r.g.repo)) continue;
      placed.add(r.g.repo);
      const kids = list.filter((k) => nested(k) && k.g.repo === r.g.repo);
      kids.forEach((k, n) => out.push({ ...k, tree: n === kids.length - 1 ? "└─" : "├─" }));
    }
    return out;
  }

  // Space id -> its dot (model.js spaceDot over the same cards the Agents tray draws).
  dotsBySpace() {
    const byTerm = new Map(this.feed.sessions().filter((s) => s.terminal && s.feed).map((s) => [s.terminal.address, s]));
    const sessionOf = (a) => {
      const s = isGentle(a.app) ? byTerm.get(a.address) : null;
      return s ? { session: s, feed: s.feed, live: liveState(s.feed), need: needsYou(s.feed) } : null;
    };
    const by = {};
    for (const c of agentCards({ agents: agents(), terms: terminals(), sessionOf })) if (c.spaceId) (by[c.spaceId] ??= []).push(c);
    return Object.fromEntries(Object.entries(by).map(([id, cards]) => [id, spaceDot(cards)]));
  }

  // The rows, under a header per machine once one isn't this computer. `parts` collects what is
  // drawn (rows.js blockHeight) so the block takes the height its content needs.
  grouped(t, collapsed, parts) {
    const rows = this.ordered();
    const nums = shortcutNumbers(this.spaceOrder().map((w) => w.id));
    const draw = (r) => (collapsed ? this.compact(r, t, parts) : this.row(r, t, nums[r.w.id], parts));
    const remote = [...new Set([...rows.map(r => r.w.machine).filter(Boolean), ...this.machines.map(m => m.name)])].sort();
    const loading = m => {
      const layout = machines().find(k => k.name === m)?.layout;
      return layout === "loading" || (!layout && this.machines.some(k => k.name === m && k.state === "connected"))
        || spaces().some(s => (s.machine ?? null) === m && !this.shown.has(s.id));
    };
    const loadingRow = m => (parts.push({ kind: "loading" }), div().id(`machine-loading-${m ?? "local"}`).h(HEIGHT.loading).flex_none().px(8).flex().items_center().text_size(11).text_color(t.grey).child(collapsed ? "…" : "Loading…"));
    if (!remote.length) return loading(null) && !rows.length ? [loadingRow(null)] : rows.map(draw);
    return [null, ...remote].flatMap((m) => {
      const mine = rows.filter((r) => (r.w.machine ?? null) === m);
      const waiting = mine.filter((r) => this.dots?.[r.w.id]?.kind === "blocked").length;
      const machine = this.machines.find(k => k.name === m);
      const connected = !m || machine?.state === "connected";
      const folded = this.folded.has(m);
      const id = `machine-${m ?? "local"}`;
      const lit = this.hovered === id;
      const fold = (cx) => {
        folded ? this.folded.delete(m) : this.folded.add(m);
        localStorage.setItem("machines.folded", JSON.stringify([...this.folded]));
        cx.notify();
      };
      const meta = lit ? t.unknown : t.grey;
      const word = connected ? "Online" : (machine?.state ?? "asleep").replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase());
      parts.push({ kind: "machine" });
      const head = h_flex().id(id).tab_index(0).h(HEIGHT.machine).flex_none().px(collapsed ? 2 : 8).pt(6).gap(6).items_center().rounded(7)
        .text_size(10.5).font_semibold().text_color(meta).cursor_pointer()
        .when(lit, (el) => el.bg(t.raised))
        .focus((el) => el.border(2).border_color(SPARK))
        .accessibility_label(`${m ?? "This computer"}, ${mine.length} spaces, ${waiting ? `${waiting} needs you` : word}, ${folded ? "collapsed" : "expanded"}`)
        .on_hover(this.hover(id))
        .on_click((_e, cx) => fold(cx))
        .on_key_down((e, cx) => { if (activate(e)) fold(cx); })
        .child(this.glyph(folded ? "chev-right" : "chev", meta, 11))
        .child(this.glyph(machineGlyph(m), meta, 12))
        .when(!collapsed, (el) => el
          .child(div().min_w(0).truncate().child((m ?? "This computer").toUpperCase()))
          .child(div().flex_none().font_medium().text_color(t.muted).child(String(mine.length)))
          .child(div().flex_1())
          // Folded with someone waiting: the needs-you pill speaks for the hidden rows.
          .when(waiting > 0 && folded, (el) => el.child(this.pill(t, { kind: "blocked", word: `${waiting} needs you` })))
          .when(!(waiting > 0 && folded), (el) => el.child(h_flex().flex_none().gap(3).items_center().font_medium().text_color(meta)
            .child(this.glyph(connected ? "online" : "offline", connected ? t.done : meta, 10)).child(word)))
          .when(connected, (el) => el.child(div().id(`machine-add-${m ?? "local"}`).tab_index(0).size(22).flex_none().rounded(6).flex().items_center().justify_center()
            .hover((s) => s.bg(t.chrome))
            .focus((el) => el.border(2).border_color(SPARK))
            .accessibility_label(`New space on ${m ?? "this computer"}`)
            .on_click((_e, cx) => { cx.stop_propagation(); run("space.new", m ? { machine: m } : {}); })
            .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); run("space.new", m ? { machine: m } : {}); } })
            .child(this.glyph("plus", t.unknown, 12)))));
      if (folded) {
        if (!mine.length || collapsed) return [head];
        parts.push({ kind: "folded" });
        const summary = foldedSummary(mine.map((r) => ({ name: r.w.name, n: nums[r.w.id] ?? null })));
        return [head, div().h(HEIGHT.folded).flex_none().pl(26).pr(8).flex().items_center().text_size(11).text_color(t.grey).child(div().min_w(0).truncate().child(summary))];
      }
      if (mine.length) return [head, ...mine.map(draw)];
      if (loading(m)) return [head, loadingRow(m)];
      parts.push({ kind: "empty" });
      const empty = h_flex().id(`machine-new-${m ?? "local"}`).tab_index(0).h(HEIGHT.empty).flex_none().px(8).pl(26).gap(6).items_center().rounded(7)
        .text_size(11).text_color(t.accent).hover((s) => s.bg(t.raised))
        .focus((el) => el.border(2).border_color(SPARK))
        .on_click(() => run("space.new", m ? { machine: m } : {}))
        .on_key_down((e) => { if (activate(e)) run("space.new", m ? { machine: m } : {}); })
        .child(this.glyph("plus", t.accent, 11)).when(!collapsed, el => el.child("New space there"));
      return [head, empty];
    });
  }

  hover(id) {
    return (on, cx) => {
      if (on) this.hovered = id;
      else if (this.hovered === id) this.hovered = null;
      cx.notify();
    };
  }

  glyph(name, color, size = 12) {
    return svg(`${ICONS}/${name}.svg`).size(size).flex_none().text_color(color);
  }

  // State never by color alone: a shape per state (as in refactoria-agents), next to its word.
  stateIcon(t, kind, size = 11) {
    const box = () => div().size(size).flex_none().flex().items_center().justify_center().text_size(size - 3).font_bold().text_color(t.chrome);
    if (kind === "working") return svg("mods/workspace-chrome/spinner.svg").size(size).flex_none().text_color(t.working).spin(900);
    if (kind === "blocked") return box().rounded(3).bg(t.blocked).child("?");
    if (kind === "failed") return box().rounded(3).bg(t.failed).child("×");
    if (kind === "waiting") return div().size(size).flex_none().flex().items_center().justify_center()
      .child(div().size(Math.max(7, size - 3)).rounded_full().border(1.5).border_color(t.working));
    if (kind === "done") return box().rounded_full().bg(t.done).child(svg("mods/workspace-chrome/check.svg").size(size - 4).text_color(t.chrome));
    return div().size(size).flex_none().flex().items_center().justify_center()
      .child(div().size(Math.max(7, size - 3)).rounded_full().border(1.5).border_color(t.grey));
  }

  // An outlined state pill (artboard .pl): icon + word in the state's color; only a folded
  // machine's "N needs you" uses it now.
  pill(t, p) {
    const c = { blocked: t.blocked, failed: t.failed, working: t.working, waiting: t.working, done: t.done, idle: t.grey }[p.kind] ?? t.grey;
    return h_flex().flex_none().gap(4).items_center().h(18).pl(5).pr(7).rounded_full().border(1)
      .border_color(p.kind === "idle" ? CONNECTOR : c)
      .text_size(10.5).font_semibold().text_color(c)
      .child(this.stateIcon(t, p.kind, 11))
      .child(div().whitespace_nowrap().child(p.word));
  }

  // The space's dot (artboard .dot, 8 px, never animated): the color of its most urgent agent,
  // with a tooltip and an accessible label; the row's own label says it too.
  dot(t, w, d) {
    const c = { blocked: t.blocked, failed: t.failed, working: t.working, done: t.done }[d.kind] ?? t.grey;
    return div().id(`dot-${w.id}`).size(14).flex_none().flex().items_center().justify_center()
      .role("image").accessibility_label(d.label).tooltip(dotTooltip(w.name, d))
      .child(div().size(8).rounded_full().bg(c));
  }

  // A space row (artboard .q): glyph, name, the agent dot, shortcut number; the branch line with
  // ahead/behind and uncommitted counts. Two lines always.
  row({ w, i, g, tree }, t, n, parts) {
    const on = w.active;
    const id = `space-${w.id}`;
    const lit = this.hovered === id;
    const d = this.dots?.[w.id] ?? null;
    const b = branchLine(g);
    const raised = on || lit;
    // #8F839D fails on #2C2144 (4.19): raised rows switch grey meta to #C7A6FF.
    const meta = raised ? t.unknown : t.grey;
    parts.push({ kind: "row" });
    const count = (icon, v, label) => h_flex().flex_none().gap(2).items_center().text_color(t.dim).accessibility_label(label)
      .child(this.glyph(icon, t.dim, 10)).child(String(v));
    const label = [w.name, on ? "current space" : "", n ? `Control A, Control ${n}` : "", b.label, d?.label ?? "", w.machine ?? "This computer"].filter(Boolean).join(", ");
    const select = () => run("space.select", { id: w.id });
    return div()
      .relative()
      .id(id)
      .tab_index(0)
      .h(rowHeight() - 1)
      .mb(1)
      .flex_none()
      .when(Boolean(tree), (el) => el.ml(14))
      .pl(8)
      .pr(8)
      .pt(6)
      .rounded(9)
      .cursor_pointer()
      .when(raised, (el) => el.bg(t.raised))
      .focus((el) => el.border(2).border_color(SPARK))
      .when(this.pressed !== null && this.over === i && this.pressed !== i, (el) => el.border_t(2).border_color(t.accent))
      .accessibility_label(label)
      .on_hover(this.hover(id))
      .on_mouse_down("left", () => {
        this.pressed = i;
        this.over = i;
      })
      .on_mouse_up("left", (_e, cx) => {
        const from = this.pressed;
        this.pressed = null;
        if (from !== null && from !== i) run("space.move", { id: spaces()[from].id, index: i + 1 });
        else select();
        cx.notify();
      })
      .on_mouse_down("right", () => this.menu(w))
      .on_key_down((e) => { if (activate(e)) select(); })
      // Selected: a soft raised row with an accent bar, not a solid block.
      .when(on, (el) => el.child(div().absolute().left(0).top(9).bottom(9).w(3).rounded(3).bg(t.accent)))
      // A worktree hangs off its repo: a decorative connector (#4A3D66), plus its own glyph.
      .when(Boolean(tree), (el) => el.child(div().absolute().left(-7).top(-4).h(22).w(7).border_l(1).border_b(1).rounded_bl(5).border_color(CONNECTOR)))
      .child(h_flex().gap(9).items_start()
        .child(div().mt(2).child(this.glyph(tree ? "wt" : g ? "repo" : "folder", meta, 14)))
        .child(v_flex().flex_1().min_w(0)
          .child(h_flex().h(18).gap(6).items_center().min_w(0)
            .child(div().min_w(0).truncate().text_size(12.5).text_color(t.foreground).when(on, (el) => el.font_semibold()).when(!on, (el) => el.font_medium()).child(w.name))
            .when(Boolean(d), (el) => el.child(this.dot(t, w, d)))
            .child(div().flex_1())
            .when(Boolean(n), (el) => el.child(div().flex_none().min_w(16).h(16).px(3).rounded(4).bg(t.background).border(1).border_color(t.raised)
              .flex().items_center().justify_center().text_size(10).font_semibold().text_color(t.unknown).child(String(n)))))
          .child(h_flex().mt(2).h(16).gap(8).items_center().min_w(0).text_size(11).text_color(meta)
            .when(Boolean(b.branch), (el) => el.child(h_flex().min_w(0).gap(4).items_center()
              .child(this.glyph("branch", meta, 10))
              .child(div().min_w(0).truncate().font_family(MONO).text_size(10.5).child(b.branch))))
            .when(!g, (el) => el.child(div().child("no git branch")))
            .when(b.ahead > 0, (el) => el.child(count("up", b.ahead, `${b.ahead} ahead`)))
            .when(b.behind > 0, (el) => el.child(count("down", b.behind, `${b.behind} behind`)))
            .when(b.dirty > 0, (el) => el.child(count("dirty", b.dirty, `${b.dirty} uncommitted`))))));
  }

  // The narrow rail: the shortcut number and a dot when someone waits.
  compact({ w, i }, t, parts) {
    parts.push({ kind: "compact" });
    const d = this.dots?.[w.id] ?? null;
    const dot = d ? { blocked: t.blocked, failed: t.failed, working: t.working, done: t.done }[d.kind] : t.unknown;
    return h_flex()
      .id(`space-${w.id}`)
      .h(HEIGHT.compact)
      .flex_none()
      .justify_center()
      .gap(4)
      .rounded(6)
      .when(w.active, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.raised))
      .accessibility_label([w.name, d?.label].filter(Boolean).join(", "))
      .on_click(() => run("space.select", { id: w.id }))
      .child(div().text_color(w.active ? t.foreground : t.muted).child(String(i + 1)))
      .child(div().text_color(dot).child(d ? "●" : "·"));
  }

  render() {
    const t = palette(theme());
    const collapsed = narrow();
    const colors = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
    const sp = spaces();
    // Other mods still read each space's stored color: keep assigning it.
    const ids = new Set(sp.map(p => p.id));
    const kept = Object.fromEntries(Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id)));
    let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
    for (const p of sp) {
      if (kept[p.id] || p.name === "~") continue;
      const uses = c => Object.values(kept).filter(v => v === c).length;
      kept[p.id] = colors.reduce((best, c) => uses(c) < uses(best) ? c : best);
      changed = true;
    }
    if (changed) setShared("space.colors", kept);
    this.dots = this.dotsBySpace();
    const parts = [];
    const list = this.grouped(t, collapsed, parts);
    this.measured = blockHeight(parts);
    const lit = this.hovered === "space-new";
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(h_flex().h(HEIGHT.head).flex_none().pl(16).pr(10).pt(8).gap(6).items_center()
        .when(!collapsed, (el) => el
          .child(div().text_size(10.5).font_semibold().text_color(t.grey).child("SPACES"))
          .child(div().text_size(10.5).font_medium().text_color(t.muted).child(String(sp.length))))
        .child(div().flex_1())
        .child(div().id("space-new").tab_index(0).size(24).rounded(6).flex().items_center().justify_center().cursor_pointer()
          .when(lit, (el) => el.bg(t.raised))
          .focus((el) => el.border(2).border_color(SPARK))
          .accessibility_label("New space")
          .on_hover(this.hover("space-new"))
          .on_click(() => run("space.new"))
          .on_key_down((e) => { if (activate(e)) run("space.new"); })
          .child(this.glyph("plus", t.accent, 12))))
      .child(v_flex().flex_1().min_h(0).px(8).pb(HEIGHT.pad).overflow_y_scrollbar().mode("always")
        .on_mouse_up("left", (_e, cx) => { this.pressed = null; cx.notify(); })
        .children(list));
  }
}
