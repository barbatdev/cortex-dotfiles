// Clone of the shipped workspace-chrome mod: same header and footer, with the
// Refactoria beard and wordmark in place of the Herdr logo and name. On the
// macOS rail the header grows so the beard alone fits under the traffic lights.
import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, run, props, window, shared, setShared, updates, layout } from "herdr";

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

// Header height: the shipped 46px, taller on the macOS rail to hold the beard.
const BRAND_PX = 46;
const BRAND_RAIL_PX = 84;

// Keep the brand block's height in step with the rail, whichever way it narrowed
// (the toggle button or dragging the edge). Asks once per change.
let pendingBrandPx = null;
function syncBrandHeight(want) {
  const current = find(layout(), "brand")?.size?.px;
  if (current === undefined || current === want) { pendingBrandPx = null; return; }
  if (pendingBrandPx === want) return;
  pendingBrandPx = want;
  run("layout.resize", { id: "brand", px: want });
}

export default class RefactoriaChrome extends View {
  button(id, label, action) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.muted).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_click(action).child(label);
  }
  render() {
    const t = theme();
    const collapsed = narrow();
    if (props()?.footer) {
      const row = (id, icon, label, dim, action) => h_flex().id(id).h(28).px(8).gap(9).items_center().rounded(8)
        .text_color(dim ? t.dim : t.muted).hover(s => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
        .on_click(action).child(svg(`mods/workspace-chrome/${icon}.svg`).size(14))
        .when(!collapsed, el => el.child(label));
      return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(8).pt(4).pb(8).text_size(13)
        .child(row("settings", "settings", "Settings", false, () => run("app.settings"))
          .when(Boolean(updates().app.ready), el => el.child(div().size(6).rounded_full().bg(t.accent))))
        .child(row("machine", "plus", "Add machine", true, () => run("mod.open", { name: "machine-add" })));
    }
    const macRail = collapsed && window()?.platform === "macos";
    syncBrandHeight(macRail ? BRAND_RAIL_PX : BRAND_PX);
    if (macRail) {
      // The traffic lights fill the top row; the beard sits under them.
      return v_flex().size_full().bg(t.chrome).items_center().justify_end().pb(10)
        .child(image("mods/refactoria-chrome/logo.png").size(28).rounded(6));
    }
    return h_flex().size_full().bg(t.chrome).pl(collapsed ? 6 : 14).pr(10).gap(4).items_center().text_size(13.5)
      .when(window()?.platform === "macos" && !collapsed, el => el.pl(76))
      .when(!collapsed, el => el.child(h_flex().flex_1().gap(8).items_center().child(image("mods/refactoria-chrome/logo.png").size(20).rounded(5)).child(image("mods/refactoria-chrome/wordmark.png").h(16).w(108))))
      .when(!collapsed, el => el.child(this.button("search", svg("mods/workspace-chrome/search.svg").size(15), () => run("mod.open", { name: "picker" }))))
      // On the macOS rail the traffic lights fill the row; the agents list's » unfolds it.
      .when(!(collapsed && window()?.platform === "macos"), el => el.child(this.button("sidebar-toggle", svg("mods/workspace-chrome/sidebar.svg").size(15), toggleSidebar)));
  }
}
