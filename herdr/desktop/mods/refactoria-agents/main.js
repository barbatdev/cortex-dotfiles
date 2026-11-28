// Agents as session cards (design/herdr-desktop-ux/04-sessions-v2.html, on 02): Needs you and
// Running cards, most urgent first; a calm block when nothing runs; idle rows grouped by recency.
// Drawn as the activity tray of design/herdr-spaces/04-split-roles.html: a darker surface with
// rounded top corners, its own edge and a bold header with a live summary in words.
// The card model is pure (./model.js); this file draws it with the theme's tokens.

import { View, div, svg, image } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { agents, terminals, spaces, run, theme, shared, setShared, setAgentOrder, window, layout } from "herdr";
import { FeedSource, isGentle, liveState, needsYou, selectSession } from "./feed.js";
import { agentCards, traySummary, buildCard, sortCards, splitCards, liveAgents, timeAgo, disambiguate, idleSince, freshIdle, sections, recencyGroups, todaySummary, lastFinished, programIcon, machineIcon, pillLabel, idleLines } from "./model.js";

const ICON = { sub: "mods/refactoria-agents/icons/sub.svg", chev: "mods/refactoria-agents/icons/chev.svg", archive: "mods/refactoria-agents/icons/archive.svg", calm: "mods/refactoria-agents/icons/calm.svg" };

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
// The tray (artboard .tray): darker than the sidebar, with a decorative #4A3D66 edge and grip.
const TRAY = "#0B0714";
const EDGE = "#4A3D66";
const palette = (t) => ({
  ...t,
  grey: t.ansi8 ?? "#8F839D",
  failed: t.ansi1 ?? "#FF6B8A",
  error: t.ansi1 ?? "#FF6B8A",
  waiting: t.working,
  idle: t.ansi8 ?? "#8F839D",
});

const activate = (e) => e?.key === "enter" || e?.key === "space" || e?.keystroke === "enter" || e?.keystroke === "space";

export default class Agents extends View {
  init(_props, cx) {
    // Gentle Shell sessions (./feed.js), following refactoria-spaces, the one reader.
    this.feed = new FeedSource();
    this.feed.start(cx, null, 10000);
    // Each agent's last state and when it changed (ms), kept across restarts.
    this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}");
    this.earlierOpen = localStorage.getItem("earlierOpen") === "true";
    this.staleOpen = localStorage.getItem("staleOpen") === "true";
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

  glyph(path, color, size = 12) {
    return svg(path).size(size).flex_none().text_color(color);
  }

  chip(t, c, lit) {
    const lead = c.kind === "subagent" ? this.glyph(ICON.sub, t.working, 11)
      : div().flex_none().font_bold().text_color({ job: t.working, consult: t.accent, failed: t.failed }[c.kind] ?? t.dim).child({ job: "▸", consult: "⇄", failed: "×" }[c.kind] ?? "·");
    return h_flex().max_w_full().gap(5).items_center().px(7).h(22).rounded(6)
      .bg(lit ? t.chrome : TRAY).border(1).border_color(c.kind === "failed" ? t.failed : t.raised)
      .text_size(11).text_color(t.dim)
      .child(lead)
      .child(div().min_w(0).truncate().child(c.label));
  }

  button(t, id, label, primary, onClick) {
    return div().id(id).tab_index(0).px(10).h(26).rounded(6).flex().items_center().text_size(11).cursor_pointer()
      .when(primary, (el) => el.bg(t.solid).text_color(t.solid_foreground).font_semibold())
      .when(!primary, (el) => el.border(1).border_color(t.unknown).text_color(t.muted))
      .focus((el) => el.border(2).border_color(SPARK))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(); })
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); onClick(); } })
      .child(label);
  }

  // A session card (artboard 04 states b/c): program glyph, name, state pill (icon + word), then
  // the question and Answer, the error and See error, or the task bar and the work chips.
  card(t, c, open, now) {
    const rail = t[c.status] ?? t.dim;
    const lit = c.focused || this.hovered === c.address;
    const meta = lit ? t.unknown : t.grey;
    const failures = c.chips.filter((x) => x.kind === "failed");
    const work = c.chips.filter((x) => x.kind !== "failed");
    const ran = c.status === "working" && c.since ? timeAgo(now - c.since) : "";
    return v_flex()
      .id(`ag-${c.address}`)
      .tab_index(0)
      .flex_none()
      .rounded(10)
      .border(1)
      .border_color(lit ? rail : t.raised)
      .border_l(3)
      .bg(lit ? t.raised : t.chrome)
      .pl(10)
      .pr(11)
      .pt(10)
      .pb(9)
      .cursor_pointer()
      .focus((el) => el.border_color(SPARK))
      .accessibility_label(`${c.name}, ${c.program.name}, ${c.word}${c.time ? `, ${c.time}` : ""}${c.question ? `, ${c.question}` : ""}`)
      .on_hover(this.hover(c.address))
      .on_click(() => open(c))
      .on_key_down((e) => { if (activate(e)) open(c); })
      .child(h_flex().gap(7).items_center()
        .child(this.glyph(programIcon(c.program), t.unknown, 14))
        .child(div().flex_1().min_w(0).truncate().text_size(13).font_medium().text_color(t.foreground).child(c.name))
        .child(h_flex().flex_none().gap(4).items_center().h(19).pl(5).pr(7).rounded_full().border(1).border_color(rail)
          .text_size(10.5).font_semibold().text_color(rail)
          .child(this.stateIcon(t, c.status, 11))
          .child(div().whitespace_nowrap().child(pillLabel(c, now)))))
      .when(Boolean(c.sub), (el) => el.child(div().ml(21).mt(2).truncate().text_size(11.5).text_color(t.muted).child(c.sub)))
      .when(Boolean(c.question), (el) => el.child(div().ml(21).mt(6).mb(2).pl(8).py(2).border_l(2).border_color(t.blocked)
        .text_size(12.5).text_color(c.quoted ? t.foreground : t.muted).child(c.quoted ? `“${c.question}”` : c.question))
        .child(h_flex().ml(21).mt(6).gap(6)
          .child(this.button(t, `ans-${c.address}`, "Answer", true, () => open(c)))
          .child(this.button(t, `open-${c.address}`, "Open pane", false, () => open(c)))))
      .when(!c.question && failures.length > 0, (el) => el
        .child(div().ml(21).mt(6).text_size(11.5).text_color(t.failed).child(failures.map((x) => x.label).join(" · ")))
        // No safe retry action exists in Herdr for a failed subagent or job: See error only.
        .child(h_flex().ml(21).mt(8).gap(6).child(this.button(t, `err-${c.address}`, "See error", false, () => open(c)))))
      .when(Boolean(c.task) && !c.question && failures.length === 0, (el) => el.child(h_flex().ml(21).mt(7).gap(8).items_center()
        .accessibility_label(`${c.task.label} todos`)
        .child(div().flex_1().h(4).rounded(4).bg(t.background).border(1).border_color(t.raised)
          .child(div().h_full().rounded(4).bg(t.working).w(`${Math.max(0, Math.min(100, c.task.pct))}%`)))
        .child(div().flex_none().text_size(10.5).text_color(t.muted).child(c.task.label))))
      .when(work.length > 0 && !c.question, (el) => el.child(h_flex().ml(21).mt(7).gap(5).flex_wrap().children(work.map((x) => this.chip(t, x, lit)))))
      .child(h_flex().ml(21).mt(7).gap(5).items_center().min_w(0).text_size(10.5).text_color(meta)
        .child(this.glyph(machineIcon(c.machine), meta, 11))
        .child(div().flex_1().min_w(0).truncate().child([...c.meta, ran].filter(Boolean).join(" · "))));
  }

  // A quiet row, two lines: glyph, name, New, age; then the last task and where it runs.
  idleRow(t, c, now, open, group) {
    const lit = this.hovered === c.address || c.focused;
    const l = idleLines(c, now);
    const fresh = group === "now";
    const dim = lit ? t.unknown : fresh ? t.dim : t.grey;
    return h_flex()
      .id(`ag-${c.address}`)
      .tab_index(0)
      .flex_none()
      .min_h(44)
      .px(8)
      .py(6)
      .gap(8)
      .rounded(8)
      .items_start()
      .cursor_pointer()
      .when(fresh && !lit, (el) => el.bg(`${t.raised}99`))
      .when(lit, (el) => el.bg(t.raised))
      .focus((el) => el.border(1).border_color(SPARK))
      .accessibility_label(`${c.program.name}, ${l.label}`)
      .on_hover(this.hover(c.address))
      .on_click(() => open(c))
      .on_key_down((e) => { if (activate(e)) open(c); })
      .child(div().mt(2).child(this.stateIcon(t, l.isNew ? "done" : "idle", 12)))
      .child(v_flex().flex_1().min_w(0)
        .child(h_flex().gap(6).items_center().min_w(0)
          .child(this.glyph(programIcon(c.program), t.unknown, 12))
          .child(div().min_w(0).truncate().text_size(12.5)
            .when(group === "earlier", (el) => el.text_color(t.muted))
            .when(group !== "earlier", (el) => el.font_medium().text_color(t.foreground))
            .child(l.name))
          .when(l.isNew, (el) => el.child(div().flex_none().px(5).rounded(4).bg(t.done).text_color(t.background).text_size(9.5).font_bold().child("New")))
          .child(div().flex_1())
          .when(Boolean(l.age), (el) => el.child(div().flex_none().text_size(10.5).text_color(lit ? t.unknown : fresh ? t.done : t.grey).child(l.age))))
        .child(h_flex().mt(2).gap(8).items_center().min_w(0).text_size(11).text_color(dim)
          .when(Boolean(l.task), (el) => el.child(div().min_w(0).truncate().text_color(lit ? t.unknown : group === "earlier" ? t.grey : t.dim).child(l.task)))
          .child(h_flex().flex_none().gap(3).items_center()
            .child(this.glyph(machineIcon(c.machine), dim, 10))
            .child(div().whitespace_nowrap().child(l.where)))));
  }

  heading(t, label, n, extra) {
    // Artboard .h3: sentence case, 11 px semibold in muted; the count lighter, in grey (5.60 on the tray).
    return h_flex().px(4).pt(9).pb(5).gap(6).items_center().flex_none()
      .child(div().text_size(11).font_semibold().text_color(t.muted).child(label))
      .when(n != null, (el) => el.child(div().text_size(11).font_medium().text_color(t.grey).child(n)))
      .when(Boolean(extra), (el) => el.child(div().flex_1()).child(extra));
  }

  link(t, id, label, onClick) {
    return div().id(id).tab_index(0).h(24).flex().items_center().text_size(10.5).text_color(t.accent).underline().cursor_pointer()
      .focus((el) => el.border(1).border_color(SPARK).rounded(4))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(); })
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); onClick(); } })
      .child(label);
  }

  // Nothing runs and nothing needs you (artboard 04 state a): a calm block with today's activity
  // and the last finished turn.
  calm(t, cards, now, open) {
    const d = todaySummary(cards, now);
    const last = lastFinished(cards, now);
    const stat = (n, label, icon) => h_flex().flex_1().min_w(0).gap(7).items_baseline()
      .child(div().flex_none().min_w(20).text_size(17).font_semibold().text_color(t.foreground).child(String(n)))
      .child(h_flex().min_w(0).gap(3).items_center().text_size(11).text_color(t.grey).when(Boolean(icon), (el) => el.child(icon)).child(div().min_w(0).truncate().child(label)));
    return v_flex().id("ag-calm").mx(2).mt(6).rounded(12).border(1).border_color(t.raised).bg(t.chrome).px(14).pt(14).pb(13)
      .accessibility_label(`All quiet. Today: ${d.ran} ran, ${d.finished} finished, ${d.failed} failed, ${d.needs} need you`)
      .child(h_flex().gap(11).items_start()
        .child(image(ICON.calm).size(30).flex_none())
        .child(v_flex().flex_1().min_w(0)
          .child(div().text_size(14).font_semibold().text_color(t.foreground).child("All quiet"))
          .child(div().mt(2).whitespace_normal().text_size(12).text_color(t.dim).child("Nothing is running and nothing needs you."))))
      .child(v_flex().mt(14).mb(4).pt(11).border_t(1).border_color(t.raised).gap(10)
        .child(h_flex().w_full().min_w(0).gap(8)
          .child(stat(d.ran, "Ran"))
          .child(stat(d.finished, "Finished", this.stateIcon(t, "done", 10))))
        .child(h_flex().w_full().min_w(0).gap(8)
          .child(stat(d.failed, "Failed", this.stateIcon(t, "failed", 10)))
          .child(stat(d.needs, "Needs you", this.stateIcon(t, "blocked", 10)))))
      .child(div().mt(8).whitespace_normal().mb(12).text_size(10.5).text_color(t.grey).child(`Today · ${d.machines} machine${d.machines === 1 ? "" : "s"} online`))
      .when(Boolean(last), (el) => el.child(v_flex().pt(11).border_t(1).border_color(t.raised)
        .child(h_flex().min_w(0).gap(4).items_center().text_size(10.5).text_color(t.done)
          .child(div().flex_none().child(`${last.label} · `)).child(this.glyph(machineIcon(last.card.machine), t.done, 10)).child(div().min_w(0).truncate().child(last.where)))
        .child(h_flex().mt(5).min_w(0).gap(7).items_center()
          .child(this.glyph(programIcon(last.card.program), t.unknown, 14))
          .child(div().min_w(0).truncate().text_size(13).font_medium().text_color(t.foreground).child(last.card.name)))
        .when(Boolean(idleLines(last.card, now).task), (el) => el.child(div().ml(21).mt(2).truncate().text_size(11.5).text_color(t.dim).child(idleLines(last.card, now).task)))
        .child(h_flex().ml(21).mt(10).gap(6).flex_wrap()
          .child(this.button(t, "calm-review", "Review result", true, () => open(last.card)))
          .child(this.button(t, "calm-open", "Open pane", false, () => open(last.card))))));
  }

  render(cx) {
    const t = palette(theme());
    const collapsed = narrow();
    const now = Date.now();
    const all = terminals();
    const termOf = new Map(all.map((x) => [x.address, x]));
    const sessions = this.feed.sessions();
    const byTerm = new Map(sessions.filter((s) => s.terminal && s.feed).map((s) => [s.terminal.address, s]));
    const tabs = new Map(spaces().flatMap((s) => s.tabs).map((tab) => [tab.id, tab]));

    // No stale duplicates: one entry per live terminal. A sub-agent with its own terminal shows on
    // its parent's card (a chip; blocked or failed raises the parent), not as a card of its own.
    // model.js agentCards: the same reduction refactoria-spaces turns into its dots.
    this.track(liveAgents(agents(), all), now);
    const sinceOf = (a) => {
      const tab = tabs.get(a.tab);
      // Herdr's own status_ms first: the mod's stamp counts done and idle as one, so a kept
      // terminal looked at long ago would read as idle since then (L17: "27d" rows).
      return (a.status === "working" && tab?.working_since) || idleSince(termOf.get(a.address), this.changed[a.address]?.at) || tab?.changed_at || null;
    };
    const sessionOf = (a) => {
      const s = isGentle(a.app) ? byTerm.get(a.address) : null;
      return s ? { session: s, feed: s.feed, live: liveState(s.feed), need: needsYou(s.feed) } : null;
    };
    const cards = agentCards({ agents: agents(), terms: all, sessionOf, sinceOf, now });
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

    const toggle = (key) => () => {
      this[key] = !this[key];
      localStorage.setItem(key, String(this[key]));
      cx.notify();
    };
    const { needs, running, quiet } = sections(shown);
    const body = [];
    if (needs.length) {
      body.push(this.heading(t, "Needs you", `${needs.length} · most urgent first`));
      body.push(v_flex().gap(8).children(needs.map((c) => this.card(t, c, open, now))));
    }
    if (running.length) {
      body.push(this.heading(t, "Running", String(running.length)));
      body.push(v_flex().gap(8).children(running.map((c) => this.card(t, c, open, now))));
    }
    if (!needs.length && !running.length) body.push(this.calm(t, cards, now, open));
    // The quiet list (unseen finished turns lead as "New"), grouped by recency.
    const staleRows = this.staleOpen ? split.idle.filter((c) => !fresh.includes(c)) : [];
    const quietRows = [...quiet, ...staleRows];
    if (quietRows.length) {
      body.push(this.heading(t, "Idle", String(quietRows.length)));
      for (const g of recencyGroups(quietRows, now, this.earlierOpen)) {
        body.push(h_flex().px(8).pt(10).pb(3).gap(6).items_center().text_size(10.5).font_semibold()
          .text_color(g.id === "now" ? t.accent : g.id === "hour" ? t.muted : t.grey)
          .child(g.label).child(div().font_medium().text_color(g.id === "now" ? t.accent : t.grey).child(String(g.count))));
        body.push(v_flex().gap(1).children(g.rows.map((c) => this.idleRow(t, c, now, open, g.id))));
        if (g.more || (g.id === "earlier" && this.earlierOpen && g.count > 2)) {
          const label = g.more ? `Show ${g.more} more from earlier today` : "Show less";
          body.push(h_flex().id("idle-more").tab_index(0).pl(30).pr(8).h(28).gap(4).items_center().rounded(7).cursor_pointer()
            .text_size(11).text_color(t.accent)
            .when(this.hovered === "idle-more", (el) => el.bg(t.raised))
            .focus((el) => el.border(1).border_color(SPARK))
            .accessibility_label(label)
            .on_hover(this.hover("idle-more"))
            .on_click(toggle("earlierOpen"))
            .on_key_down((e) => { if (activate(e)) toggle("earlierOpen")(); })
            .child(label).child(this.glyph(ICON.chev, t.accent, 11)));
        }
      }
    }
    if (hidden) body.push(h_flex().px(8).pt(10).gap(6).items_center().text_size(10.5).text_color(t.grey)
      .child(this.glyph(ICON.archive, t.grey, 12))
      .child(this.staleOpen ? `${hidden} untouched for over a day, shown ·` : `${hidden} untouched for over a day are tucked away ·`)
      .child(this.link(t, "stale-toggle", this.staleOpen ? "Hide" : "Show", toggle("staleOpen"))));

    // The tray: its own surface and header (bold "Agents" with the live summary), docked under
    // Spaces with rounded top corners, so activity never reads as more navigation.
    const sum = traySummary(shown);
    const tone = { blocked: t.blocked, failed: t.failed, working: t.working };
    const header = h_flex().flex_none().px(12).pt(6).pb(9).gap(8).items_center().flex_wrap().border_b(1).border_color(t.raised)
      .child(div().flex_none().text_size(13).font_bold().text_color(t.foreground).child("Agents"))
      .child(h_flex().id("ag-summary").min_w(0).gap(9).flex_wrap().items_center().text_size(11)
        .role("status").accessibility_label(sum.label)
        .children(sum.parts.map((x) => h_flex().flex_none().gap(4).items_center()
          .when(x.kind !== "idle", (el) => el.font_semibold().text_color(tone[x.kind]).child(this.stateIcon(t, x.kind, 11)))
          .when(x.kind === "idle", (el) => el.font_medium().text_color(t.grey))
          .child(div().whitespace_nowrap().child(x.text)))));
    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .text_size(13)
      .child(v_flex().flex_1().min_h(0).mx(6).bg(TRAY).border_t(1).border_l(1).border_r(1).border_color(EDGE).rounded_t(14)
        .role("region").accessibility_label(`Agents: ${sum.label}`)
        .child(div().flex_none().mt(6).mx_auto().w(32).h(4).rounded(4).bg(EDGE))
        .child(header)
        .child(v_flex().id("ag-list").flex_1().min_h(0).px(8).pt(4).pb(12).overflow_y_scrollbar().children(body)));
  }
}
