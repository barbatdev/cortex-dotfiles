# Herdr Desktop UX

Improve the `refactoria` Herdr Desktop layout (Herdr app 0.1.18, live homes `herdr-app-2` and `herdr-app-4`).
Branch `feat/herdr-desktop-ux`, worktree `../cortex-dotfiles-herdr-ux`. Gentle Shell Desktop (`gentle-shell desktop`) is NOT used.

## Specs

- S1. "Tenemos que crear un sidebar nuevo (como el de files, changes) para todo lo que es github". Sections chosen: "PRs con detalle" (reviews, checks expandidos, diff y acciones), "Issues" (issues del repo y los asignados a vos), "Actions y CI" (workflow runs recientes y fallos), "Notificaciones" (menciones y reviews que te pidieron).
- S2. "Tenems que restaurar el pane de agentes." Chosen form: "Rehacerlo con el feed" — mostrar estado, tarea actual y pendientes de cada sesión.
- S3. "Tenemso que mejroar la UI". Pain points: "Densidad y jerarquía visual", "Información que falta", and "no se cambian los nombres, no se muestra estado, ni tarea ni nada. Creo que la UI puede ser mas rica aprovechando las bondades de herdr desktop y los eventos de gentle-shell". Reference screenshot: spaces sidebar (machine groups, repo rows with branch, "te espera" badges).
- S4. "Tenemos que incorporar el sistema de eventos de gentle-shell, que es nuevo, para poder usarlo bien con herdr y aprovecharlo como es debido". Sources: gentle-pi docs `desktop-feed.md` (`gentle-shell.desktop-feed/v1`, `~/.gentle-shell/agent/desktop/sessions/*.json`) and `agent-status.md` (`gentle-shell.agent-status/v1`).
- S5. "no vamos a usar gentle-shell desktop." Keep our own `refactoria` layout and mods.

## Tasks

- T1 (S4) Map the gentle-shell feed/status formats and the current refactoria mods; design shared data layer — explore — done (no commit)
- T2 (S4, S3) Shared feed reader used by mods (names, state, task) — inline — done (commit: see log)
- T3 (S2, S4) Agents panel rebuilt on the feed — pending
- T4 (S3) Spaces sidebar richer: session name, state, task — pending
- T5 (S1) GitHub sidebar panel (PRs detail, issues, actions, notifications) — pending
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
