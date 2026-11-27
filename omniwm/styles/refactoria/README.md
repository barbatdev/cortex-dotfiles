# RefactorIA Continuum for native OmniShell

An API 1 style targeting **OmniWM 0.8.0 build 89**: a flat 36-point dark top bar, violet active underline, monitor-local workspace tabs, and real native telemetry. Brand authority is `design/refactoria-design-system/project/README.md` and its `tokens.css`, superseding the earlier SketchyBar palette. This is not an HTML application. This source correction does not activate or write host settings.

## Updating the already-installed profile

The parent deploys only the changed owned files after backing up their installed counterparts:

- `lib/continuum.luau` (runtime change)
- `checks/behavior.luau` (offline fixtures)
- `README.md` (documentation)

**Preserve installed `lib/mark.luau`, `lib/config.luau`, profile-local and top-level host `shell.toml`, all monitor overrides, and `themes/refactoria.toml`.** This update moves Retina's existing Apple menu action onto the official violet isotipo and removes the redundant Apple symbol. The separate native Hidden Icons Bar target is unchanged; other displays retain their plain marks. The already-installed mark remains a runtime dependency. No monitor geometry, reservation, default widget, Hidden Bar setting or drawer change is needed. Do not recopy the whole folder over an activated profile: that would erase local ID/name mappings. The generator, official SVG and Python tests stay in this repository; none is loaded by OmniWM. The fresh-install path below is not an update procedure.

After deploying, let OmniWM reload the active RefactorIA profile (or explicitly reselect it if necessary). Before testing clicks, run `omniwmctl query shell-widgets`: expect these **six required widgets** loaded without errors—`refactoria-spaces`, `refactoria-status`, `wifi`, `calendar`, `volume`, `hidden-bar`. The three metric panels belong only in `drawer refactoria-panels`; `hidden-bar` retains its existing `hidden bar` placement, never leading/center/trailing. The parent has already confirmed that Hidden Bar widget placement; this update does not add a second loader or visible default widget. A top-level profile override of this drawer can supersede the profile-local table; reconcile that specific override manually if the query does not show these members. Do not copy settings or native libraries out of `default/`.

## Brand mapping and native limits

| Canonical token/rule | Native treatment |
|---|---|
| `background`, `background-2`, `background-3` | Dark ground `#0b0714`, hover `#17102a`, active fill `#2c2144`; dark in both macOS appearances |
| `text`, `text-2` | White labels; secondary text is white at 0.6 alpha (`#ffffff99`), not a lavender substitute |
| `border` | White at 0.2 alpha (`#ffffff33`); decorative edge/dividers, never the sole active-state cue |
| `brand-500` | `#7127ff` for the active 3-point underline and official mark; never small labels or telemetry |
| Official isotipo | Full-beard path, violet by explicit user choice, 22-point height × 17.094-point width on Retina, LG, Xiaomi and Samsung; replaces both wordmark text runs |
| Inter 400/500 | `font = "Inter"`, weights `regular`/`medium`; no semibold/bold substitutions |
| Mono | `font = "FiraCode Nerd Font Mono Beard"`, retaining `style = "mono"` for native fallback |
| `space-3` (16px → 16-point native spacing) | All four mapped displays: one 16-point spacer before the leading content and one after the trailing content; zero-gap outer rows, no inset on either inner/notch-facing edge |

**Font fallback is real, not bundled Inter.** Pinned API 1 explicitly supports custom family names, but loads only uncompressed `.ttf`/`.otf` files from profile/shared `fonts/` folders (16 files per folder, 16 MiB each). The supplied design assets are **WOFF2**, unsupported by that loader. No fonts are installed, converted, downloaded or bundled here. The family requests work if suitable fonts are already supplied through those native folders; otherwise OmniWM logs unknown families once and uses its native fallback. `ShellTextStore.swift` selects the system sans for ordinary text and **monospaced-digit system font** for `style = "mono"` (not a promise of Fira Code). Weights remain 400/500. A matching globally installed family alone is not the documented profile-font contract. Actual label font metrics and overflow need host inspection; the mark has no font dependency.

**Alpha is RGBA, not ARGB.** The pinned layout reference documents `#RRGGBBAA` and UI role alpha such as `foreground/0.6`. `ShellTheme.swift` parses palette TOML literals as RGB/RGBA, with alpha in the last byte; palette entries do not accept CSS `rgba()` or role aliases. The structural tests resolve the actual default `:root` in `tokens.css` to these native literals.

No amber spark is added: there is no appropriate existing eyebrow/cursor in this bar, and amber is not a metric or border color. No retired U+F0F00 glyph, beard redraw or substitute geometry is shipped. No SVG-document loader, CSS glow stack, CSS easing, scroll reveal, blur-to-focus, cursor animation or parallax is invented. The mark and existing rectangular underline use documented native `ui.path`; the bar stays static and uses raised fills without shadows. Web spacing/fluid typography/nav-height tokens do not replace the established 36-point native geometry, outer insets or workspace viewports.

### Exact official mark — source, regeneration and API evidence

Source: `design/refactoria-design-system/project/assets/Logos/refactoria-mark-light.svg`, SHA-256 `9bf77758fc360c6c91c8d48a740ea912efe0509cb7260233afa0e0797cf8531a`.
The Python-standard-library generator retains the original `viewBox="238 130 777 1000"` and mechanically bakes `translate(0,1254) scale(.1,-.1)` into **every** control/end point: `x′ = x/10`, `y′ = 1254 − y/10`. It uses exact decimal arithmetic, preserves both closed subpaths and their winding, and emits readable absolute `M/L/C/Z` commands, one per line. No tracing, simplification, rounding or discarded geometry is involved. The approved native `fill = "accent"` deliberately overrides the source's fixed light fill `#f2effa`; this is not an automatic recoloring of unrelated assets.

```sh
# From the repository root; regenerate only lib/mark.luau:
python3 -B omniwm/styles/refactoria/tools/generate_mark.py
# Read-only reproducibility check:
python3 -B omniwm/styles/refactoria/tools/generate_mark.py --check
```

The generator accepts only the supplied `M/m`, `L/l`, `C/c`, `Z/z` subset, including implicit repeats, move-to-line conversion and relative moves after close. Unsupported commands or changed SVG structure fail instead of silently dropping content. Generated `lib/mark.luau` is self-contained: **no SVG file loader, generator or Python runtime is needed on the host**.

Pinned 0.8.0/API 1 proof was read before implementation: `omniwm.d.luau` exposes `ui.path(PathProps)` with `d`, numeric-list `viewBox` and inherited `w/h/fill`. `ShellRender.cpp` transports the data and four viewBox numbers; `ShellPath.swift` parses absolute cubic/line/close commands (limit 4096) and fits by `size.width/viewBox.width` and `size.height/viewBox.height`, subtracting the viewBox origin. Therefore explicit **17.094 × 22 points** preserves the 777:1000 aspect ratio without a second transform. `ShellLayerScene.swift` creates a `CAShapeLayer`; `ShellLayerScene+Enter.swift` fits the path and defaults to nonzero fill; `ShellLayerScene+Paint.swift` applies the resolved fill color. Both subpaths remain one native filled path, not individual shapes or a glyph.

Python independently interprets the official source and compares every generated command/control/end point, the source SHA, bounds and size; `--check` verifies byte-reproducibility. Real Luau fixtures assert exactly one accent mark first in each mapped leading lane (inside the native clickable wrapper on Retina only), none on unknown displays or in trailing lanes, and retain the existing workspace/inset/status checks. These structural/API proofs do **not** establish native compilation, rasterization, optical legibility or live click behavior.

## Local install — deliberate, manual steps

1. From this dotfiles repository root, copy the **whole profile folder**, not just its widgets. These commands are instructions, **not executed** by this implementation. They refuse to overwrite an existing profile:

   ```sh
   mkdir -p "$HOME/.config/omniwm/shell"
   test ! -e "$HOME/.config/omniwm/shell/refactoria" && \
     cp -R omniwm/styles/refactoria "$HOME/.config/omniwm/shell/refactoria"
   ```

   The destination is `~/.config/omniwm/shell/refactoria/`. If it already exists, stop and back it up/reconcile it manually. Do not overwrite the top-level `shell.toml` or `default/`.

2. With IPC already enabled, run the read-only `omniwmctl query displays`. Otherwise inspect display identities in OmniWM before enabling IPC yourself. Edit the installed `refactoria/lib/config.luau`: for **each** of `retina`, `lg`, `xiaomi`, and `samsung`, fill `id` with the exact current `display:…` identity and `name` with the exact display name. Blank defaults deliberately select no variant; there is no assumed numbering. Adjust `widths` only if necessary: these are workspace scroll viewport sizes in points, not detected monitor dimensions.
3. Open **Settings → Styles & Widgets**, choose **RefactorIA Continuum**, inspect the preview, then explicitly choose **Use Style** when ready. Enable the Workspace Bar and check that all four connected displays are enabled. The style does not turn on the global bar switch. Existing per-profile overrides can supersede its layout: use **Use Style Layout…** and reset conflicting appearance overrides if needed. Do not copy unrelated host settings.
4. Keep Full Width on for all four displays, including **LG**: its background now spans the display instead of forming a centered compact strip. For LG, retain top/Overlapping Menu Bar placement, 36-point height and Notch Mode **Off**. If an existing LG monitor override disables Full Width, enable it in that display's Bar controls without changing other settings. The GUI writes its native monitor override, including persistent identity, without inventing a TOML UUID. The profile already defaults to full width.
5. Run `omniwmctl query shell-widgets`; inspect the six required widgets for compile/runtime/configuration errors. If `hidden-bar` is absent, stop and report it rather than changing settings or requesting permissions. Verify the live checklist below before relying on it. No dependency installation is needed; see the explicit native font fallbacks above.

**Side effect to expect only when you activate:** an enabled full-width bar at overlapping-menu-bar placement requests macOS **menu-bar auto-hide**. This is native OmniWM behavior, not an installer action. Normal disable/quit restores the previous preference subject to OmniWM's documented safeguards. No SketchyBar service is started or changed.

## Four display variants

| Role | Leading lane | Trailing lane |
|---|---|---|
| Retina | Violet isotipo (Apple Menu target) · Hidden Icons Bar target · named workspace tabs · monitor-local focused app | CPU · used RAM · output volume/mute · Wi-Fi state · localized date/time · battery/charging |
| LG portrait | Violet isotipo · workspace numbers; tooltips retain full host names | Localized clock only; no date or other metrics |
| Xiaomi | Violet isotipo · named tabs · monitor-local focused app | CPU · used RAM · localized date/time |
| Samsung | Same wide-display treatment, with a wider workspace viewport | CPU · used RAM · localized date/time |
| Unmapped/mismatched display | Host workspace names only | Nothing |

The artboard's intended workspace arrangement is below. Configure names and display assignments **in OmniWM**; this style renders the current `bar.workspaces` in host order, never creates fake tabs, moves workspaces, or changes application rules.

| Retina | LG (number → full name) | Xiaomi | Samsung |
|---|---|---|---|
| internet, mail, herdr | 1 grok bot; 2 discord; 3 whatsapp + whatsapp web; 4 chatgpt; 5 spotify; 6 ventana de herdr; 7 X.com | herdr, varios | herdr, remotedesktopmanager |

**Outer clearance on all four mapped displays:** content starts 16 points farther from the left edge and ends 16 points farther from the right edge, using `space-3` and the same before-leading/after-trailing zero-gap wrapper already used on Retina. Metric values/order, existing click actions and lane gaps stay identical. Retina's isotipo now owns the existing Apple menu action; the redundant Apple symbol is removed and the separate Hidden Icons Bar target remains. Workspace viewports are not narrowed to make room. Retina, Xiaomi, Samsung and LG retain the same outer insets; unmapped/mismatched displays keep their prior uninset, names-only fallback. The rectangular backgrounds, 36-point bar height, existing host padding/notch settings, workspace viewports and click-target sizes are unchanged; no rounding or padding on both sides of each lane is added. LG stays top-aligned with a full-width background; the parent enables its existing display override without changing other geometry. These are additional widget-content insets, not a claim of an absolute 16-point distance from the physical screen edge.

Each active tab has a 3-point violet underline, brighter white medium-weight text and a flat raised background. Inactive labels and telemetry values use neutral `text-2`; metric labels use white. Click targets use the **host workspace ID**, not its label: `switch-workspace <id>`. Each render uses the latest monitor-local snapshot. Long labels stay complete in a horizontally scrollable workspace viewport. App names are capped at 160 points with full tooltips; an absent focused app is omitted. No global focused app is substituted onto other monitors.

CPU is a native percentage; RAM uses `system.memory.used` bytes, not a made-up GB value. Optional measurements show `—`, while real zero remains zero. Wi-Fi needs only power/connected state, not SSID or a Location authorization request. Date and time use the host's locale rather than hard-coded example text. Wide external displays deliberately omit battery, volume and Wi-Fi. LG shows the same 22-point violet official isotipo as Retina, its real host-provided spaces numbered in host order, and only the localized clock on the right: no date, focused app, CPU, RAM, volume, battery or Wi-Fi. Its 252-point workspace viewport fits seven 36-point click targets without manufacturing extra spaces. Numbers are centered within each 36-point click target using a native `ui.stack` and `align = "center"` on its text child; API 1's row `center` property only centers across the row's cross axis, not horizontally. Zero tab padding, ID actions, full-name tooltips and the full-tab active underline are unchanged; other display tabs remain rows.

**Dependencies are registered by executed reads**, including reads inside library helpers (pinned API 1 context-data reference). The status widget delegates directly to `view.trailing`: it needs no eager feed declarations or additional polling. LG reads only `bar` and `clock`, and unmapped displays read only `bar`; the LG branch runs before any wide-role telemetry access. Other widgets/monitors may still request system feeds independently. Status refresh interval remains two seconds.

## Retina menu access — Apple menu and resident icons

The **Retina isotipo opens Apple Menu**: its exact existing 17.094 × 22-point violet path is centered in a native **28 × 28-point** clickable `ui.stack`. There is **no separate Apple symbol**. The separate 28 × 28-point Hidden Icons Bar target stays next to it, before the workspace viewport, with the existing 12-point leading-lane gap. Its native symbol remains neutral `foreground`; both targets use the existing `surface` hover token. On LG, Xiaomi and Samsung, the mark remains the exact **plain nonclickable path**, without a wrapper or menu action. Unmapped/mismatched displays still have no mark or menu target. No active-app menu is added.

| Target / API `help` name | Visual | Exact action |
|---|---|---|
| Official Retina isotipo / Apple Menu | Unchanged violet full-beard path | `menu apple` |
| Hidden Icons Bar | Native `app.dashed` symbol, unchanged | `shell toggle hidden-bar` |

The Apple Menu tooltip/action and native clickable stack follow the pinned default `apple-menu` widget and `lib/menu-button.luau`, but the existing official path replaces its Apple symbol. Hidden Bar's `app.dashed` remains a native `ui.symbol`, not emoji, custom icon artwork or an added icon library. Descriptive `help` names use the API's tooltip field; actual VoiceOver exposure and keyboard reachability still need host verification, not an invented accessibility-label property.

**Apple Menu delegates to OmniWM's native menu action.** The renderer does not recreate Settings, restart, shutdown or logout items, and does not run any of those commands. Open the menu manually to inspect it; do not select power/session actions during verification.

**Hidden Icons Bar means resident menu-bar/status icons**, such as OmniWM's icon—not all running apps, open windows or a task switcher. The existing loaded `hidden-bar` widget supplies its own popout, item images, names and native activation/menu handling. This renderer neither reads `ctx.data.hiddenBar` nor enumerates processes/windows to build a replacement. `ShellAction` accepts the exact three words `shell toggle hidden-bar`; dispatch selects the loaded widget's native popout. As with the metric panels, this cross-widget action retains the Retina monitor but does not forward the button anchor: expect the supported visible-frame top-right fallback, not a promise of opening below the leading target. A repeat toggle closes it.

**Availability is not proof of permission.** A loaded widget does not establish that Hidden Bar concealment is enabled, supported or authorized, or that any resident icons are selected. The pinned default popout shows **No hidden items** for absent/empty data. Pinned feature documentation describes macOS 27 and Full Disk Access as concealment requirements; that documentation is not evidence of this host's status or a reason to request access. The user reports that the panel opens with no hidden apps; this mark-action refinement does not diagnose or change that empty state. No availability/permission state was verified here. This change does not enable Hidden Bar, grant/request Full Disk Access or other permissions, read private Control Center preferences, or run any menu/activation action. If empty/unavailable, report that boundary and leave permissions/settings untouched; it is not a task-switcher fallback.

**No second bar or geometry fix:** preserve the current 36-point full-width overlapping bars, `reserveLayoutSpace`, position and all monitor overrides. The parent's read-only observations found an external top inset of 36 points attributable to the existing bar and zero extra Retina inset—not evidence of a duplicate reservation. These menu targets do not justify changing that reservation, moving a bar or resetting defaults.

## Retina clicks — native panels, opened manually

| Retina target | Exact API 1 action | Native panel |
|---|---|---|
| Wi-Fi state | `shell toggle wifi` | Status and **Wi-Fi Settings…**; **not a network chooser**. Connect to another network in macOS Settings. |
| Localized date/time | `shell toggle calendar` | Month navigation and agenda, subject to existing Calendar access. |
| VOL value/mute | `shell toggle volume` | Output volume slider/mute and native output controls; slider availability depends on the selected audio device. |

Click again to close; opening another panel replaces the current one. Only Retina gets these click actions. CPU/RAM/battery stay read-only; Xiaomi/Samsung retain nonclick date/time/status and LG retains its nonclick clock only. Workspace switching is unchanged on every display. No extra visible bar widgets, custom panel redraw, metric spacing, token, font or geometry changes are introduced.

**Panel availability is configured, not assumed.** Native API 1 only discovers active-profile packages explicitly referenced by lanes or services (shared root widgets are a separate case). Merely having default widgets on disk is insufficient. This profile references the existing native panels via a non-hover drawer, outside all three bar lanes:

```toml
[drawer.refactoria-panels]
edge = "right"
widgets = ["wifi", "calendar", "volume"]
hover = false
```

This declaration loads the default widgets and their existing native libraries without copying them or creating duplicate bar items on any display. The drawer is an availability container, not a new bar control: clicks toggle the individual widget, **not** the combined drawer. Do not add these widgets to leading/center/trailing. API 1 also exposes this container to explicit drawer commands; it is not a monitor access-control rule. No hover or automatic opening is enabled.

**Accepted anchor limitation:** `ShellAction` parses three-word string toggles. `ShellWidgetHost+Interaction.swift` calls `toggle(widget, on: origin.monitor)` without forwarding the click anchor; `ShellWidgetHost+Drawers.swift` then calls `togglePopout` without an explicit anchor. An unplaced widget uses the native **top-right of the clicked monitor's visible frame**, not the clicked metric's rectangle. This is the supported hidden/headless fallback; no unsupported `ui.popout("wifi")`, callback table, cross-widget anchor API or OS command is invented. Host position/notch/visible-frame behavior still needs live confirmation.

**No consent is automated.** The bar still reads only Wi-Fi power/connected status, never SSID, and does not copy a network name. The default Wi-Fi panel may show already-authorized network details or an explicit Location access button; opening it does not invoke that button. Calendar agenda requires existing Calendar access; without it the native month/permission UI remains. Native audio panels may offer additional app-volume permissions. This implementation grants no permissions, sends no authorization or network-connection commands, handles no credentials, and does not auto-click any native prompt. Any later permission choice belongs to the user.

## Display identity and reconnect limitation

The tagged API documents `ctx.data.bar.monitorId` and `bar.monitor` (a non-unique human-readable name). **No UUID is exposed in `Bar`; `SystemDisplay` has only `w`, `h`, and `hz`, with no identity to join to a bar.** Native monitor settings may store a UUID, but widgets cannot read that settings identity through this API.

Accordingly, `lib/config.luau` explicitly maps a session display ID **and** exact name to a role. Duplicate configured IDs or a name mismatch fail closed to spaces-only. There is no name-only, width/order, or guessed UUID fallback. After a reconnect, re-run `omniwmctl query displays` and update the installed mapping if IDs changed. Even an unchanged ID/name pair can be reused by another same-named monitor: automatic reconnect-safe physical identity is **not guaranteed** in API 1. Recheck all four roles after reconnecting or rearranging displays. Native per-display geometry overrides and this widget mapping are separate.

## Eventual GitHub installation — do not publish yet

This folder already has the official profile shape:

```text
refactoria/
├── style.toml
├── shell.toml
├── themes/refactoria.toml
├── lib/{config,continuum,mark}.luau
├── tools/generate_mark.py       # repository-only regeneration tool
├── widgets/refactoria-spaces/init.luau
├── widgets/refactoria-status/init.luau
└── checks/behavior.luau
```

OmniWM v0.8.0 discovers a public GitHub style either at **repository-root `style.toml`**, or as **root-level `styles/refactoria/style.toml`**, matching `styles/celestial` in the official repository. For a future dedicated repository, copy this folder's *contents* to its root; for a collection, copy the whole folder to root-level `styles/refactoria/`. Keep `name = "refactoria"`. Review licensing/credits and version metadata before any public release; no license or publishing decision is made here.

**The present dotfiles path `omniwm/styles/refactoria/` is not discoverable by Add from GitHub on this repository.** A GitHub `/tree/…` subfolder URL is not a workaround. After separately authorized publication in one of the supported layouts, **Get Styles → Add from GitHub…** accepts the repository's main-page URL and reads one default-branch snapshot. Installation leaves the current style selected until **Use Style**. Personal display mappings must be configured locally after installation, not published. Updates can require reapplying those mappings; back up edits first.

## Verification and remaining live checks

From the dotfiles root:

```sh
python3 -B tests/omniwm_refactoria_test.py
python3 -B tests/omniwm_refactoria_test.py --tagged-api
# Only if a real Luau CLI is already installed:
luau omniwm/styles/refactoria/checks/behavior.luau
```

Python checks exact official path transformation/reproducibility, bounds and proportional size, TOML, package wiring, geometry, palette provenance, documentation and a bounded pinned upstream API inventory (including the actual path parser and layer renderer). It does **not** simulate Luau behavior. The optional Luau check runs the actual view module with recorded UI constructors and immutable fixture snapshots: 17 checks for Retina's mark-wrapper Apple action, absence of a separate Apple symbol, unchanged plain non-Retina marks and Hidden Bar target, help names and exact native actions (with no extra leading data feeds), four-role mark placement/size/fill and Retina metric click strings across unavailable/off/offline/connected Wi-Fi and mute states (with private Wi-Fi fields rejected), nonclick external-display status, four variants, seven real LG spaces with exact ID actions/tooltips, centered stack labels and unchanged full-tab underline structure, clock-only LG dependency reads, local focus, unavailable/zero data, mapping rejection, remapping, native brand/type trees and all four mapped displays' outer insets with unchanged workspace click targets/viewports. Retina/wide content and the uninset unknown-display fallback remain covered. These fixtures are test-only, never live metrics. The Python runner skips that check if `luau` is absent.

**Runtime proof unavailable in this implementation environment:** no Luau CLI was found; native compilation, widget diagnostics, live clicks, reconnects and four-display screenshots were not executed. Structural checks are not proof of rendering or a complete host typecheck.

Before delivery on the host:

- [ ] All six required widgets load without errors on installed 0.8.0 build 89; all four bars appear. The three metric panels report only the hidden drawer placement; `hidden-bar` retains `hidden bar` placement, with no duplicate bar items.
- [ ] On Retina, the isotipo itself is the Apple Menu target, with no extra Apple symbol; Hidden Icons Bar remains separate. Check tooltips Apple Menu / Hidden Icons Bar, unchanged violet path size/legibility, VoiceOver names, keyboard reachability and notch/space fit. Other displays keep exactly their previous plain marks and leading content.
- [ ] Manually click the Retina isotipo to open Apple Menu and inspect native Settings/session entries without selecting any power/session action. Manually open Hidden Icons Bar and check native resident-icon access, repeat-close and panel replacement. Empty/unavailable or permission-limited results must be reported honestly; do not grant permissions or read private preferences to force a pass.
- [ ] On Retina, manually click Wi-Fi, date/time and VOL: the correct native panel opens at the visible frame's top-right, a repeat click closes it and another target replaces it. Wi-Fi Settings opens only when selected; the month works without auto-granting Calendar access, existing permitted agenda appears, and the output slider works when supported. Do not automate permission controls.
- [ ] Xiaomi/Samsung status and LG clock remain nonclick; no panels open on hover. No new Location, Calendar or audio permission is requested by rendering the bar or merely opening these panels.
- [ ] Each bar lists only its monitor's real spaces; clicks focus by ID and move the underline correctly.
- [ ] LG is a full-width horizontal top bar with the violet isotipo, seven actual numbered spaces centered in their 36-point targets and a right-hand clock only; full space names are available in tooltips. The active underline still spans its whole tab; no date, app or other metrics appear.
- [ ] All four mapped displays have 16-point additional left/right outer content clearance. Retina keeps its exact violet mark shape/size, workspace/status order and metrics, with only the Apple action moved to the mark wrapper and redundant Apple symbol removed; wide backgrounds remain full-width and rectangular, all bars remain 36 points high, and unknown displays keep their uninset fallback. Wide displays show actual CPU, used RAM and date/time, with no battery.
- [ ] Reconnect displays, re-query IDs, update mapping and verify that roles were not swapped.
- [ ] Check long Samsung names/scrolling, notched Retina clearance and narrow-display overflow at actual scaling.
- [ ] Confirm the exact full-beard mark is visible and upright on all four mapped displays, 22 points high without clipping/stretching or added effects. No left RefactorIA text remains. Small labels stay neutral, text-2 remains readable and actual fallback fonts are acceptable.

The source artboard is `design/omniwm-refactoria/02-continuum.html`; its HTML and example numbers are not shipped. Native differences: dimensions are points, the host owns padding and notch geometry, `barBorder` paints a native edge rather than a CSS bottom-only rule, and localized dates may be longer. The middle lane is intentionally empty; native split-around-notch layout handles the Retina gap. Status overflow and exact physical alignment still require live inspection.

## Pinned API provenance

All research is pinned to v0.8.0 commit **bf118cca1449468397dee3662acbba5544657545**, never latest/main. Paths below are relative to [that commit](https://github.com/OmniNull/OmniWM/tree/bf118cca1449468397dee3662acbba5544657545):

| Source | Used for |
|---|---|
| `styles/celestial/{style,shell}.toml`, `themes/celestial.toml` | Installable API 1 manifest, profile layout and palette format |
| `website/src/content/docs/omnishell/configuration/{profiles-palettes,bars-drawers,development}.md` | Local installation, overrides, GitHub UI and diagnostics |
| `website/src/content/docs/omnishell/reference/{context-data,ui-elements,layout-styling}.mdx` | Monitor ID/reconnect contract, data dependencies, native UI and colors; explicit `w`/`h` in points, intrinsic unsized rows, ordered row children and `gap` between children. `pad` is equal on all sides, so all four mapped roles use transparent fixed-width outer boxes instead; row `center` affects only the cross axis, while stack-child `align = "center"` centers LG digits within fixed targets; context-data documents read-driven dependencies, including library helpers |
| `Sources/OmniWM/Resources/omniwm.d.luau` | Exact fields/types for Bar, BarWorkspace, BarItem, System, WiFi and UI properties; `PathProps` and `ui.path` |
| `Sources/OmniWMScriptHost/ShellRender.cpp` | Native path `d`/viewBox transport (numeric four-entry list) |
| `Sources/OmniWM/Core/Shell/ShellPath.swift` | Cubic/line/close parser, 4096-command limit and viewBox-origin fitting |
| `Sources/OmniWM/Core/Shell/ShellLayerScene.swift`, `ShellLayerScene+{Enter,Paint}.swift` | CAShapeLayer creation, fitted path/nonzero fill rule and palette fill application |
| `Sources/OmniWM/ShellDefault/widgets/workspaces/init.luau` | Host workspace-ID actions and underline construction |
| `Sources/OmniWM/Core/Shell/ShellWidgetHost.swift` | Exact `ShellAction` parser: three words `shell toggle <widget>` become `.toggle(widget:)`, including `hidden-bar`; `ShellRequest` maps `menu apple` to `.menu(.apple)` |
| `Sources/OmniWM/ShellDefault/widgets/apple-menu/init.luau`, `ShellDefault/lib/menu-button.luau` | Apple Menu tooltip/action and native clickable `ui.stack` / `help` construction; RefactorIA uses its official violet path instead of the default Apple symbol |
| `Sources/OmniWM/ShellDefault/widgets/hidden-bar/init.luau`, `UI/WorkspaceBar/WorkspaceBarManager+ShellHiddenBar.swift`, `website/src/content/docs/features/hidden-bar.md` | Native resident-icon popout, `app.dashed` fallback and empty state; native hidden-bar placement/data bridge; documented concealment requirements, not host permission proof |
| `Sources/OmniWM/Core/Shell/ShellWidgetHost+{Interaction,Drawers}.swift` | Command dispatch keeps caller monitor but not caller anchor; loaded unplaced panels use the headless visible-frame top-right fallback; individual toggles differ from drawer toggles |
| `Sources/OmniWM/Core/Shell/ShellWidgetHost+{Lifecycle,Delivery}.swift`, `ShellConfig+Services.swift` | Drawer members are discovered/loaded from profile/default/bundle; absent lane means no bar instances; `hover = false` disables edge opening |
| `Sources/OmniWM/ShellDefault/widgets/{wifi,calendar,volume}/init.luau`, `ShellDefault/lib/{wifi,calendar,audio}.luau` | Reuse existing native popout implementations: Wi-Fi status/Settings with explicit Location action, month/agenda with explicit Calendar action, audio slider; no native network chooser |
| `Sources/OmniWM/Core/Shell/{ShellStyleManifest,ShellGitHubStyleSource,ShellConfig}.swift` | Manifest keys, GitHub root/collection discovery and profile parsing |
| `Sources/OmniWM/Core/Shell/ShellTheme.swift` | Palette RGB/RGBA parsing, last-byte alpha and role-alpha multiplication |
| `Sources/OmniWM/Core/Shell/{ShellFontLibrary,ShellTextStore}.swift` | TTF/OTF-only profile loading, custom family weights and exact native sans/mono fallback |
| `Sources/OmniWM/Core/Config/MonitorBarSettings.swift`, `Sources/OmniWM/UI/WorkspaceBar/WorkspaceBarOptions.swift` | Per-monitor geometry and exact placement/notch enum values |

The tagged audit also fetches the font/color sources and UI references above, recording their SHA-256 digests. This is API evidence, not runtime or visual proof. Palette provenance is now the canonical default dark `tokens.css`; the artboard still governs layout, not superseded colors. Amber spark is not reused for general telemetry.
