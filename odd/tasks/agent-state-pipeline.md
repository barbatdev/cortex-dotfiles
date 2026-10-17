# Agent-state pipeline: estados, labels y notificaciones Herdr

Estado de agentes Cortex reportado automáticamente a Herdr (panes, labels, notificaciones) y SketchyBar, sobre el contrato `cortex.agent_state.v1` (docs/agent-state-v1.md).

## Specs

- S1: "eso de los estados y varias cosas mas" — estados de agente automáticos working/blocked/idle reportados a Herdr sin intervención manual.
- S2 (usuario, verbatim): "Quiero también que se actualicen los labels, temas de notificaciones, que info muestran, etc".
- S3 (usuario, elección "Todos los cambios"): notificaciones en todos los cambios de estado (working→blocked→idle y vuelta), usando sonidos `request`/`done` de Herdr para distinguir.
- S4 (usuario, elección de superficie SketchyBar): "Ítem por agente", "Agregado compacto" y "Agregado + popup detalle" — item agregado compacto con popup de detalle por agente (nombre, estado, pane, mensaje).
- S5 (usuario, elección de labels): "Símbolos + texto corto" — p. ej. "⚙ Testing…", "⛔ Aprobación necesaria"; compacto para la sidebar.
- S6: Alcance de adaptadores: Pi + Claude Code + paridad fish + consumidor SketchyBar (elección "Todo el pipeline").
- S7: No duplicar las integraciones nativas de Herdr (`herdr integration install pi|claude|opencode`); actualizar las desactualizadas y complementar con la capa `cortex.agent_state.v1` para superficies externas.

## Descubrimientos (exploración)

- Herdr tiene integraciones nativas de ciclo de vida: en la Mac, `herdr integration status` muestra pi v8<v9, claude v9<v10, opencode v11<v13, grok v1<v2 desactualizadas; codex/cursor/hermes current.
- `herdr pane report-agent --source --agent --state idle|working|blocked|unknown --message --seq --agent-session-id [-- resume-args]` — lifecycle completo con resume tras restart.
- `herdr pane report-metadata --state-label STATUS=TEXT --title --token NAME=VALUE --clear-*` — labels display-only.
- `herdr notification show <TITLE> --body --position top-left|top-right|bottom-left|bottom-right --sound none|done|request` — toast in-app.
- `herdr api snapshot` — estado vivo de la sesión; base para consumidor externo (SketchyBar).
- `zsh/scripts/agent-state.sh` existe (report/list/get/clear, persiste en $XDG_STATE_HOME/cortex/agent-state/, reporta a panes con report-metadata) pero nada lo emite automáticamente; solo zsh, sin fish.
- No hay consumidor SketchyBar ni notificaciones hoy.

## Tasks

- T1 (S7): `herdr integration install` para pi, claude, opencode, grok (actualizar las outdated). Commit.
- T2 (S1,S6): emisor automático en Pi (extensión) que llama `agent-state report` en transiciones de turno; estados normalizados. Commit.
- T3 (S1,S6): hooks de Claude Code (`Notification`/`Stop`/`PreToolUse`) → `agent-state report`. Commit.
- T4 (S2,S5): labels "símbolos + texto corto" vía report-metadata state-labels (working/blocked/idle). Commit.
- T5 (S3): notificaciones Herdr en todos los cambios de estado, sound request para blocked, done para idle. Commit.
- T6 (S4): consumidor SketchyBar: ítem agregado compacto + popup detalle por agente (colores RefactorIA). Commit.
- T7 (S6): paridad fish para agent-state. Commit.
- T8: verificación RED/GREEN por regla + chequeo diferencial de comandos existentes que comparten código. Por unidad.

## Log

- L1 (user): "como hacemos para mejorar la integración con herdr?" → elegida dimensión "Estado de agentes en tiempo real".
- L2 (user): "eso de los estados y varias cosas mas ... pero me diste a elegir una sola opción. Quiero también que se actualicen los labels, temas de notificaciones, que info muestran, etc" → alcance ampliado: estados automáticos + labels + notificaciones + info mostrada.
- L3 (user, elecciones): notificaciones "Todos los cambios"; SketchyBar "Ítem por agente", "Agregado compacto", "Agregado + popup detalle"; labels "Símbolos + texto corto".
