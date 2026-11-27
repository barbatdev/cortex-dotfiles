// Agents as session cards (design/herdr-desktop-ux/02-sessions-as-cards.html): one card per
// active session, most urgent first, and a quiet idle list collapsed to a summary line.
// The card model is pure (./model.js); this file draws it with the theme's tokens.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { agents, terminals, spaces, run, theme, shared, setShared, setAgentOrder, window, layout } from "herdr";
import { FeedSource, isGentle, liveState, needsYou, selectSession } from "./feed.js";
import { buildCard, sortCards, splitCards, idleView, liveAgents, timeAgo, disambiguate, idleSince, freshIdle, emptyLine } from "./model.js";

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

// To the rail (on macOS wide enough for the traffic lights), or back to the width it had.
function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  // Mods edited before the rail went by width still read the flag.
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

// Colors the theme has no name for, from the artboard's contrast table: grey text only on
// chrome/background (5.16+), never on raised (4.19); the focus ring (10.45 on chrome).
const SPARK = "#FFB547";
const palette = (t) => ({
  ...t,
  grey: t.ansi8 ?? "#8F839D",
  failed: t.ansi1 ?? "#FF6B8A",
  error: t.ansi1 ?? "#FF6B8A",
  waiting: t.working,
  idle: t.ansi8 ?? "#8F839D",
});

const short = (machine) => (machine ? machine.replace(/^agent-/, "") : "here");
const activate = (e) => e?.key === "enter" || e?.key === "space" || e?.keystroke === "enter" || e?.keystroke === "space";

export default class Agents extends View {
  init(_props, cx) {
    // Gentle Shell sessions (./feed.js), following refactoria-spaces, the one reader.
    this.feed = new FeedSource();
    this.feed.start(cx, null, 10000);
    // Each agent's last state and when it changed (ms), kept across restarts.
    this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}");
    this.idleOpen = localStorage.getItem("idleOpen") === "true";
    this.hovered = null;
    cx.timer.every(30000, (cx) => cx.notify());
  }

  // Stamps agents whose state changed. Done and idle count as one: looking at a finished
  // agent turns done into idle, and looking isn't the agent doing anything.
  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed)) if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
  }

  hover(id) {
    return (on, cx) => {
      if (on) this.hovered = id;
      else if (this.hovered === id) this.hovered = null;
      cx.notify();
    };
  }

  // State never by color alone: each state has its own shape, and the card says the word.
  stateIcon(t, s, size = 14) {
    const box = () => div().size(size).flex_none().flex().items_center().justify_center().text_size(size - 4).font_bold().text_color(t.chrome);
    if (s === "working") return svg("mods/workspace-chrome/spinner.svg").size(size - 2).mx(1).flex_none().text_color(t.working).spin(900);
    if (s === "blocked") return box().rounded(4).bg(t.blocked).child("?");
    if (s === "failed" || s === "error") return box().rounded(4).bg(t.failed).child("×");
    if (s === "done") return box().rounded_full().bg(t.done).child(svg("mods/workspace-chrome/check.svg").size(size - 5).text_color(t.chrome));
    const ring = Math.max(7, size - 6);
    return div().size(size).flex_none().flex().items_center().justify_center()
      .child(div().size(ring).rounded_full().border(1.5).border_color(s === "waiting" ? t.working : t.grey));
  }

  badge(t, text, color) {
    return div().flex_none().px(4).h(15).rounded(4).border(1).border_color(color).text_color(color)
      .text_size(10).font_semibold().font_family("FiraCode Nerd Font Mono Beard").flex().items_center().child(text);
  }

  chip(t, c, lit) {
    const tone = { subagent: ["↳", t.working], job: ["▸", t.working], consult: ["⇄", t.accent], failed: ["×", t.failed] }[c.kind] ?? ["·", t.dim];
    return h_flex().max_w_full().gap(5).items_center().px(7).h(22).rounded(6)
      .bg(lit ? t.background : t.chrome).border(1).border_color(c.kind === "failed" ? t.failed : t.raised)
      .text_size(11).text_color(t.dim)
      .child(div().flex_none().text_color(tone[1]).font_bold().child(tone[0]))
      .child(div().min_w(0).truncate().child(c.label));
  }

  button(t, id, label, primary, onClick) {
    return div().id(id).tab_index(0).px(10).h(24).rounded(6).flex().items_center().text_size(11).cursor_pointer()
      .when(primary, (el) => el.bg(t.solid).text_color(t.solid_foreground).font_semibold())
      .when(!primary, (el) => el.border(1).border_color(t.unknown).text_color(t.muted))
      .focus((el) => el.border(2).border_color(SPARK))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(); })
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); onClick(); } })
      .child(label);
  }

  card(t, c, open) {
    const rail = t[c.status] ?? t.dim;
    const lit = c.focused || this.hovered === c.address;
    const time = c.time ? ` · ${c.time}` : "";
    const meta = lit ? t.unknown : t.grey;
    return v_flex()
      .id(`ag-${c.address}`)
      .tab_index(0)
      .flex_none()
      .rounded(10)
      .border(1)
      .border_color(lit ? rail : t.raised)
      .bg(lit ? t.raised : t.background)
      .px(11)
      .pt(10)
      .pb(9)
      .cursor_pointer()
      .focus((el) => el.border_color(SPARK))
      .accessibility_label(`${c.name}, ${c.program.name}, ${c.word}${c.time ? `, ${c.time}` : ""}`)
      .on_hover(this.hover(c.address))
      .on_click(() => open(c))
      .on_key_down((e) => { if (activate(e)) open(c); })
      .child(h_flex().gap(7).items_center()
        .child(this.stateIcon(t, c.activity))
        .child(div().flex_1().min_w(0).truncate().text_size(13).font_medium().text_color(t.foreground).child(c.name))
        .child(h_flex().flex_none().gap(4).items_center().h(19).pl(5).pr(7).rounded_full().border(1).border_color(rail)
          .text_size(10.5).font_semibold().text_color(rail)
          .child(this.stateIcon(t, c.status, 11))
          .child(div().whitespace_nowrap().child(`${c.word}${time}`))))
      .when(Boolean(c.sub), (el) => el.child(div().ml(21).mt(2).truncate().text_size(11).text_color(t.muted)
        .child(c.task && c.sub === c.task.title && !c.question ? `${c.sub}${/\//.test(c.task.label) ? ` · ${c.task.label} todos` : ""}` : c.sub)))
      .when(Boolean(c.question), (el) => el.child(div().ml(21).mt(6).mb(2).pl(8).py(2).border_l(2).border_color(t.blocked)
        .text_size(12.5).text_color(t.foreground).child(`“${c.question}”`))
        .child(h_flex().ml(21).mt(6).gap(6)
          .child(this.button(t, `ans-${c.address}`, "Answer", true, () => open(c)))
          .child(this.button(t, `open-${c.address}`, "Open pane", false, () => open(c)))))
      .when(Boolean(c.task) && !c.question, (el) => el.child(h_flex().ml(21).mt(7).gap(8).items_center()
        .child(div().flex_1().h(4).rounded(4).bg(t.background).border(1).border_color(t.raised)
          .child(div().h_full().rounded(4).bg(t.working).w(`${Math.max(0, Math.min(100, c.task.pct))}%`)))
        .child(div().flex_none().text_size(10.5).text_color(t.muted).child(c.task.label))))
      .when(c.chips.length > 0, (el) => el.child(h_flex().ml(21).mt(7).gap(5).flex_wrap().children(c.chips.map((x) => this.chip(t, x, lit)))))
      .child(h_flex().ml(21).mt(7).gap(4).items_start().min_w(0).text_size(10.5).text_color(meta)
        .child(this.badge(t, c.program.badge, meta))
        .child(div().flex_1().min_w(0).child(c.meta.join(" · "))));
  }

  idleRow(t, c, now, open) {
    const lit = this.hovered === c.address || c.focused;
    return h_flex()
      .id(`ag-${c.address}`)
      .tab_index(0)
      .flex_none()
      .h(26)
      .px(8)
      .gap(8)
      .rounded(6)
      .items_center()
      .cursor_pointer()
      .when(lit, (el) => el.bg(t.raised))
      .focus((el) => el.border(1).border_color(SPARK))
      .accessibility_label(`${c.name}, ${c.program.name}, idle`)
      .on_hover(this.hover(c.address))
      .on_click(() => open(c))
      .on_key_down((e) => { if (activate(e)) open(c); })
      .child(this.stateIcon(t, "idle", 12))
      .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(t.muted).child(c.name))
      .child(div().flex_none().text_size(10.5).text_color(lit ? t.unknown : t.grey)
        .child([c.program.badge, short(c.machine), c.since ? timeAgo(now - c.since) : ""].filter(Boolean).join(" · ")));
  }

  heading(t, label, n, extra) {
    return h_flex().px(8).pt(14).pb(6).gap(6).items_center().flex_none()
      .child(div().text_size(10.5).font_semibold().text_color(t.grey).child(label))
      .when(n != null, (el) => el.child(div().text_size(10.5).text_color(t.muted).child(n)))
      .when(Boolean(extra), (el) => el.child(div().flex_1()).child(extra));
  }

  render(cx) {
    const t = palette(theme());
    const collapsed = narrow();
    const now = Date.now();
    const all = terminals();
    const records = new Map(all.map((x) => [x.address, x.records]));
    const termOf = new Map(all.map((x) => [x.address, x]));
    const sessions = this.feed.sessions();
    const byTerm = new Map(sessions.filter((s) => s.terminal && s.feed).map((s) => [s.terminal.address, s]));
    const tabs = new Map(spaces().flatMap((s) => s.tabs).map((tab) => [tab.id, tab]));

    // No stale duplicates: one entry per live terminal. A sub-agent with its own terminal shows on
    // its parent's card (a chip; blocked or failed raises the parent), not as a card of its own.
    const list = liveAgents(agents(), all);
    this.track(list, now);
    const listed = new Set(list.map((a) => a.address));
    const parentOf = new Map(all.filter((x) => x.parent).map((x) => [x.address, x.parent]));
    const kidsOf = new Map();
    for (const a of list) {
      const p = parentOf.get(a.address);
      if (!p || !listed.has(p)) continue;
      const term = all.find((x) => x.address === a.address);
      kidsOf.set(p, [...(kidsOf.get(p) ?? []), { name: term?.name || term?.template || a.title || a.program?.name || a.address, status: a.status }]);
    }

    const sinceOf = (a) => {
      const tab = tabs.get(a.tab);
      // Herdr's own status_ms first: the mod's stamp counts done and idle as one, so a kept
      // terminal looked at long ago would read as idle since then (L17: "27d" rows).
      return (a.status === "working" && tab?.working_since) || idleSince(termOf.get(a.address), this.changed[a.address]?.at) || tab?.changed_at || null;
    };
    const cards = list.filter((a) => !listed.has(parentOf.get(a.address))).map((a) => {
      const s = isGentle(a.app) ? byTerm.get(a.address) : null;
      const c = buildCard({ agent: a, feed: s?.feed ?? null, live: s ? liveState(s.feed) : null, need: s ? needsYou(s.feed) : null, records: records.get(a.address), term: termOf.get(a.address), since: sinceOf(a), now, kids: kidsOf.get(a.address) ?? [] });
      return { ...c, session: s ?? null };
    });
    // Sessions running outside this window (another terminal on this computer): a card while they
    // do something; an idle one there is not worth a row (it would read as a stale duplicate).
    for (const s of sessions.filter((s) => s.feed && !s.terminal)) {
      const live = liveState(s.feed);
      if (live.status === "idle") continue;
      const c = buildCard({ agent: { address: `feed|${s.key}`, pane: null, app: "gentle-shell", status: "idle", program: null }, feed: s.feed, live, need: needsYou(s.feed), now, since: Date.parse(s.feed.updatedAt ?? "") || null });
      cards.push({ ...c, session: s });
    }

    // Idle agents untouched for 24 h (kept terminals of old work) are hidden unless focused or
    // pinned (model.js freshIdle); names that still collide get the tab name or #n.
    const split = splitCards(cards);
    const { rows: fresh, hidden } = freshIdle(split.idle, now);
    const { active, idle } = splitCards(sortCards(disambiguate([...split.active, ...fresh])));
    const idleSorted = [...idle].sort((x, y) => (y.since ?? 0) - (x.since ?? 0));
    const shown = [...active, ...idleSorted];
    setAgentOrder(shown.filter((c) => c.pane).map((c) => c.address));
    const open = (c) => {
      if (c.session) selectSession(c.session);
      else if (c.pane) run("pane.focus", { pane: c.pane });
    };

    if (collapsed) {
      return v_flex().size_full().min_h(0).bg(t.chrome).border_t(1).border_color(t.border).text_size(13)
        .child(v_flex().id("ag-list").flex_1().min_h(0).overflow_y_scrollbar().children(shown.map((c, i) => h_flex()
          .id(`ag-${c.address}`).h(26).px(8).flex_none().items_center().gap(4).hover((s) => s.bg(t.hover))
          .accessibility_label(`${c.name}, ${c.word}`)
          .on_click(() => open(c))
          .child(div().flex_1().min_w(0).whitespace_nowrap().text_right().text_color(t.muted).child(String(i + 1)))
          .child(h_flex().w(14).flex_none().items_center().justify_center().child(this.stateIcon(t, c.status, 12))))))
        .child(h_flex().h(28).items_center().justify_center()
          .child(div().id("collapse").text_size(13).text_color(t.muted).hover((s) => s.text_color(t.foreground)).on_click(toggleSidebar).child("»")));
    }

    const iv = idleView(idleSorted, this.idleOpen);
    const toggleIdle = () => {
      this.idleOpen = !this.idleOpen;
      localStorage.setItem("idleOpen", String(this.idleOpen));
      cx.notify();
    };
    const toggle = this.button(t, "idle-toggle", this.idleOpen ? "Collapse" : "Show", false, toggleIdle);

    const body = [];
    // The section keeps its header with nothing running: one quiet line instead of the cards.
    body.push(this.heading(t, "ACTIVE AGENTS", active.length ? `${active.length} · most urgent first` : null));
    if (active.length) body.push(v_flex().gap(8).children(active.map((c) => this.card(t, c, open))));
    else body.push(div().id("ag-empty").px(8).h(24).flex().items_center().text_size(11.5).text_color(t.grey).child(emptyLine(idle.length)));
    if (idle.length) {
      body.push(this.heading(t, "IDLE", String(idle.length), toggle));
      if (iv.open) body.push(v_flex().children(iv.rows.map((c) => this.idleRow(t, c, now, open))));
      else body.push(div().id("idle-summary").px(8).h(24).flex().items_center().rounded(6).cursor_pointer()
        .text_size(11).text_color(this.hovered === "idle-summary" ? t.unknown : t.grey)
        .when(this.hovered === "idle-summary", (el) => el.bg(t.raised))
        .on_hover(this.hover("idle-summary"))
        .on_click(toggleIdle)
        .child(iv.summary));
    }
    if (hidden) body.push(div().px(8).h(22).flex().items_center().text_size(10.5).text_color(t.grey).child(`${hidden} untouched for over a day, hidden`));

    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .text_size(13)
      .child(v_flex().id("ag-list").flex_1().min_h(0).px(8).pb(12).overflow_y_scrollbar().children(body));
  }
}
