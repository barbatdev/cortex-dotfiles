# Herdr Desktop UX

Improve the `refactoria` Herdr Desktop layout (Herdr app 0.1.18, live homes `herdr-app-2` and `herdr-app-4`).
Branch `feat/herdr-desktop-ux`, worktree `../cortex-dotfiles-herdr-ux`. Gentle Shell Desktop (`gentle-shell desktop`) is NOT used.

## Specs

- S1. "Tenemos que crear un sidebar nuevo (como el de files, changes) para todo lo que es github". Sections chosen: "PRs con detalle" (reviews, checks expandidos, diff y acciones), "Issues" (issues del repo y los asignados a vos), "Actions y CI" (workflow runs recientes y fallos), "Notificaciones" (menciones y reviews que te pidieron).
- S2. "Tenems que restaurar el pane de agentes." Chosen form: "Rehacerlo con el feed" — mostrar estado, tarea actual y pendientes de cada sesión.
- S3. "Tenemso que mejroar la UI". Pain points: "Densidad y jerarquía visual", "Información que falta", and "no se cambian los nombres, no se muestra estado, ni tarea ni nada. Creo que la UI puede ser mas rica aprovechando las bondades de herdr desktop y los eventos de gentle-shell". Reference screenshot: spaces sidebar (machine groups, repo rows with branch, "te espera" badges).
- S4. (see L6: the event system is OSC 7501 records from PR #3348; the desktop file feed is a local-only complement) "Tenemos que incorporar el sistema de eventos de gentle-shell, que es nuevo, para poder usarlo bien con herdr y aprovecharlo como es debido". Sources: gentle-pi docs `desktop-feed.md` (`gentle-shell.desktop-feed/v1`, `~/.gentle-shell/agent/desktop/sessions/*.json`) and `agent-status.md` (`gentle-shell.agent-status/v1`).
- S5. "no vamos a usar gentle-shell desktop." Keep our own `refactoria` layout and mods.

## Tasks

- T1 (S4) Map the gentle-shell feed/status formats and the current refactoria mods; design shared data layer — explore — done (no commit)
- T2 (S4, S3) Shared feed reader used by mods (names, state, task) — inline — done (commit: see log)
- T3 (S2, S4) Agents panel rebuilt on the feed — done (commit f2c5766)
- T4 (S3) Richer spaces sidebar: name, state, task — done (commit 0883adc)
- T5 (S1) GitHub sidebar panel — reopened by L10 (tab clicks, refresh on space switch, panel lost on switch with no way back)
- T6 (S3) Visual density/hierarchy pass + screenshot check — pending

## Log

- L1 (user, verbatim): "tenemos que mejorar la UX ... no estoy muy conforme en como esta esto andando hoy.
Tenemos que crear un sidebar nuevo (como el de files, changes) para todo lo que es github
Tenems que restaurar el pane de agentes.
Tenemso que mejroar la UI
Tenemos que incorporar el sistema de eventos de gentle-shell, que es nuevo, para poder usarlo bien con herdr y aprovecharlo como es debido"
- L2 (user answers): base was first "Partir de gentle-shell", then corrected: "no vamos a usar gentle-shell desktop." / "tengo abierto herdr si, es herdr desktop lo que uso." / "Sobre el branch si ... abri uno nuevo" / UI: "no se cambian los nombres, no se muestra estado, ni tarea ni nada. Creo que la UI puede ser mas rica aprovechando las bondades de herdr desktop y los eventos de gentle-shell"; no reference app.
- L3: live Herdr windows use HERDR_APP_HOME herdr-app-2 and herdr-app-4, layout refactoria, errors []. Their mod/layout symlinks point at the main checkout (`cortex-dotfiles`), not this worktree.
- L4: T1 explorer handoff: feed `gentle-shell.desktop-feed/v1` (identity.sessionName, activity.state/label, todo.current, pendingQuestion, agents, jobs); match snapshot→terminal by pid chain, paneId fallback; upstream reader gentle-pi herdr/mods/*/snapshot.js (MIT) with leader/follower via setShared. Herdr API: pane.rename/tab.rename, palette entries in mod.json, `stack` panels, exec timeout.
- L5: T2 decision: vendor snapshot.js as refactoria-spaces/feed.js (leader refactoria-spaces, keys prefixed `refactoria.`). `herdr-app check` refuses a symlinked feed.js ("resolves outside the application directory"), so each mod carries a byte-identical copy, tests/herdr_feed_test.py guards it and install.sh copies feed.js files. Policy blocks the agent from reading ~/.gentle-shell/agent/desktop/sessions, so live feed checks go through Herdr screenshots.
- L6 (user): "https://github.com/Gentleman-Programming/gentle-shell/pull/3348" — the gentle-shell event system meant by S4: PR #3348 (merged 2026-11-18) "publish Gentle Shell activity as OSC 7501 status records". Sub-records per terminal: `todo` (title = in-progress todo, progress %), `bg/<jobId>` (working/error), `subagents/<taskId>` (working, blocked/question with msg `waiting for user`/`question for parent`, error), `wait/<target>` (`consulting <target>`), `sent/<target>` (5 s), `ask/<peer>` (blocked, `question from <name>`). Titles/msgs base64. Contract: gentle-pi docs/gentle-shell.md "OSC 7501 activity record contract". Herdr stock Agents panel counts them once herdrdev/herdr-app#628 lands (still OPEN). Unlike the file feed, OSC records travel through herdr-core, so they also work for agent-dev/agent-gentle terminals.
- L7: probe: `hc get t8 --json` (this gentle-shell session) shows `status: {app, state}` only; no records surfaced there, and Herdr 0.1.18 `AgentInfo` has no records field. Where a mod can read sub-records is still unknown.
- L8: T2b result. herdr-app#628 (OPEN) says "`records` is already in `terminals()`" (terminals() = untyped `hc ls --json` entries). Observed on hc 0.1.22: no terminal in `hc ls --json` or `hc get t8 --json` carries `records`; t8 (this gentle-shell session, todo in progress) shows only `status: {app, state}`. The publisher (gentle-pi extensions/gentle-herdr-desktop-status.ts:77) requires PI_PROGRAM_STATUS_APP=gentle-shell (set by the launcher, runtime/gentle-shell-launcher.mjs:1250); the agent's tool shell does not show it, so whether this session publishes is unproven. Decision: T3/T4 read the local desktop feed (feed.js) now, and read `terminals()[i].records` opportunistically when present (no-op today); remote sessions keep Herdr's own status until records are observed.
- L9: T3 result. refactoria-agents follows the feed (FeedSource follower, byte-identical feed.js) plus a pure rows.js (tests/herdr_agents_test.mjs, `node --test`). Gentle Shell agents matched to a snapshot show session name, live state (or the open question when blocked), current todo with done/total, and pending counts as tooltip; feed sessions outside this window get their own row (click → selectSession). Other agents keep Herdr status. `terminals()[i].records` raise state only (no-op today). rows.js is imported, so install.sh copies it like feed.js. Layout: agents block back between spaces and prs, weight 1 each.
- L10 (user, T5 manual check, verbatim): "issues - si clickeo no se abre, queda todo en prs
la info no se refresca con el cambio de proyecto/space
si cambio de proyecto desaparece ese pane y no tengo como agregarlo"
- L11 (user): "Sacar PRs de la sidebar" → refactoria-prs block removed from the layout (commit c609035).
