# Roadmap — flota Cortex (mac, agent-dev, agent-gentle, agent-refactoria, nan, tars)

Estado al 2026-10-14. Este documento navega; la ejecución vive en `odd/tasks/<feature>.md` según ODD.

## Visión

Cada máquina de la flota se actualiza por su canal formal, pasa un chequeo de salud
reproducible con un solo comando, y las piezas caseras se reducen a las que upstream
aún no cubre.

## Épicas

### E1 — fleet-check versionado · **NÚCLEO HECHO** (5/6 máquinas; tars offline al censo, nan con hallazgos: pi 1.0.2 desactualizado + sin API key)
Un comando (`bin/fleet-check`) que responde "¿está todo bien en este equipo?":
runtime, wrappers, pi gestionado, extensiones, arranque real, `gs sync` + compat.
- Skills: `cortex-test-designer` (criterios) · `cortex-qa-no-ci` (ejecución sin CI)
- Feature: `odd/tasks/fleet-check.md`

### E2 — adopción de canal main en agents · **BLOQUEADA POR CALENDARIO**
agent-dev y agent-refactoria completan la migración cuando maduren las versiones
(`gentle-pi@4.1.0` madura 2026-10-19 bajo `min-release-age=7`). Políticas intactas.
- Skills: `cortex-test-runner` (verificación post-migración)

### E3 — engram alineado upstream · **ESPERANDO UPSTREAM**
Único binario casero restante. Issue `gentle-shell#2183` (rate limit → ls-remote)
sin respuesta; engram sin canal oficial.
- Skills: `cortex-maintainer-delivery` (issue→PR cuando haya señal)
- Decisión pendiente: contribution upstream vs mantener `go install` casero

### E4 — consolidación de cortex-dotfiles · **PENDIENTE**
WIP local sin commitear (47 archivos), ramas viejas, `TODO.md` obsoleto (todo tildado),
untracked (`docs/refactoria-branding.md`, `fish/atuin/`).
- Skills: `cortex-requirements-analyst` (spec de limpieza) · `cortex-evidence-auditor`

### E6 — RefactorIA parity en nan · **HECHO (pendiente gate visual del usuario)**
Tema pi `refactoria` + starship con config del repo. Fish/Claude/Herdr no aplican
(no instalados en nan). Verificación técnica completa; el render visual requiere
sesión observada por el usuario (mismo gate que los rollouts de octubre).
- Feature: `odd/tasks/refactoria-nan-themes.md`

### E5 — limpieza de residuos de migración · **PENDIENTE**
Cuarentenas de mise (~7 GB entre máquinas), backups de wrappers `*.wrapper-backup*`,
`settings.json.pre-*` — borrar solo tras una semana sin incidencias.
- Skills: `cortex-evidence-auditor` (decidir qué evidencia ya no hace falta)
