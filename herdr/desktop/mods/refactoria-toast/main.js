// Notifications in the RefactorIA style (design/herdr-desktop-ux/04-sessions-v2.html): a card with
// a state rail, the state's icon + word (never color alone), the title and a short body. Shows
// Herdr's own notifications and every notify() (layout root "toast"), with the shipped toast's
// contract: props {title, body, level, icon, action, timeout, overlay, fitHeight}; Herdr closes
// it after its timeout; a click (or Enter / Space) runs its action and dismisses it.

import { View, div, svg, image } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { props, closeOverlay, run, theme } from "herdr";
import { toastLook } from "./look.js";

// Focus ring from the artboard's table (10.45 on chrome, 9.0+ on raised).
const SPARK = "#FFB547";

const activate = (e) => e?.key === "enter" || e?.key === "space" || e?.keystroke === "enter" || e?.keystroke === "space";

export default class Toast extends View {
  stateIcon(t, kind, color, size = 12) {
    const box = () => div().size(size).flex_none().flex().items_center().justify_center().text_size(size - 4).font_bold().text_color(t.chrome);
    if (kind === "blocked") return box().rounded(4).bg(color).child("?");
    if (kind === "failed") return box().rounded(4).bg(color).child("×");
    if (kind === "done") return box().rounded_full().bg(color).child(svg("mods/workspace-chrome/check.svg").size(size - 5).text_color(t.chrome));
    return div().size(size).flex_none().flex().items_center().justify_center()
      .child(div().size(size - 4).rounded_full().border(1.5).border_color(color));
  }

  render(cx) {
    const t = theme();
    const p = props() ?? {};
    const look = toastLook(p);
    const color = { blocked: t.blocked, failed: t.ansi1 ?? "#FF6B8A", done: t.done, info: t.accent }[look.kind];
    // Herdr's machine login toast keeps its Copy button (shipped toast).
    const login = /^([a-z0-9][a-z0-9_.-]{0,31}) needs login; run hc machine login \1$/.exec(p.body ?? "");
    const command = login ? `hc machine login ${login[1]}` : null;
    const text = (value) => p.fitHeight
      ? div().whitespace_normal().child(value)
      : div().truncate().child(typeof value === "string" ? value.split("\n", 1)[0] : value);
    const go = () => {
      if (p.action?.name) run(p.action.name, p.action.args ?? {});
      closeOverlay(p.overlay);
    };
    const title = login ? `${login[1]} needs a login: run` : p.title ?? "";
    return h_flex()
      .id("toast")
      .tab_index(0)
      .when(p.fitHeight, (el) => el.w_full().min_h(70).flex_none().py(12))
      .when(!p.fitHeight, (el) => el.size_full())
      .pl(8)
      .pr(16)
      .gap(12)
      .items_center()
      .rounded(10)
      .bg(t.chrome)
      .border(1)
      .border_color(t.raised)
      .shadow_lg()
      .cursor_pointer()
      .hover((s) => s.bg(t.raised))
      .focus((el) => el.border_color(SPARK))
      .accessibility_label(`${look.word}: ${title}${p.body && !login ? `, ${p.body}` : ""}`)
      .on_click(go)
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); go(); } })
      // The state rail (artboard card border-left), in the state's color.
      .child(div().w(3).self_stretch().my(8).rounded(2).flex_none().bg(color))
      .when(Boolean(p.icon), (el) => el.child(image(p.icon).w(18).h(18).flex_none()))
      .child(
        v_flex()
          .flex_1()
          .min_w(0)
          .overflow_hidden()
          .gap(3)
          .child(h_flex().gap(8).items_center().min_w(0)
            .child(h_flex().flex_none().gap(4).items_center().h(19).pl(5).pr(7).rounded_full().border(1).border_color(color)
              .text_size(10.5).font_semibold().text_color(color)
              .child(this.stateIcon(t, look.kind, color, 11))
              .child(div().whitespace_nowrap().child(look.word)))
            .child(text(title).flex_1().min_w(0).font_semibold().text_size(13).text_color(t.foreground)))
          // Body text in muted (#EBEBEB: 15.40 on chrome, 12.51 on raised), never grey on raised.
          .when(!login && Boolean(p.body), (el) => el.child(text(p.body).text_size(12).text_color(t.muted)))
          .when(Boolean(login), (el) => el.child(h_flex().gap(8).items_center()
            .child(div().flex_1().min_w(0).truncate().tooltip(command).text_size(12).text_color(t.muted).child(command))
            .child(div().id("toast-login-copy").tab_index(0).flex_none().px(8).h(24).flex().items_center().rounded(6).bg(t.raised)
              .text_size(12).text_color(t.foreground).cursor_pointer().hover((s) => s.bg(t.hover))
              .focus((el) => el.border(2).border_color(SPARK))
              .on_click((_e, cx) => { cx.stop_propagation(); cx.write_to_clipboard(command); this.copied = true; cx.notify(); })
              .child(this.copied ? "Copied" : "Copy")))),
      );
  }
}
