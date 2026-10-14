# RefactorIA themes en nan

Aplicar las superficies visuales RefactorIA aplicables a nan (contenedor headless, shell bash): tema de pi y starship con la config del repo.

## Specs

- S1: `~/.pi/agent/themes/refactoria.json` en nan con el mismo contenido que agent-dev, y `"theme": "refactoria"` en `~/.pi/agent/settings.json` (backup previo del settings).
- S2: starship instalado (última release oficial) y `~/.config/starship.toml` = `starship.toml` del repo cortex-dotfiles; init de starship en `~/.bashrc` (idempotente).
- S3: Fish/Claude/Herdr/Ghostty no aplican en nan (no instalados) — fuera de alcance.
- S4: Verificación: theme file presente e idéntico al fuente, selector en settings, `starship --version`, config en su lugar, arranque de pi sin errores.

## Tasks

- T1 (S1-S4): replicar theme, instalar starship, desplegar config, verificar.

## Log

- L1 (user): "faltan los themes de refactoria ... eso no esta dentro de este proyecto?" — nan no estaba en la flota en el rollout original de octubre. Alcance elegido: pi theme + starship (fish/claude/herdr no instalados en nan).
- L2 (2026-10-14): T1 ejecutado. theme md5 idéntico al fuente de agent-dev (9a6f49a2), selector refactoria activo, pi --version carga la config sin errores, starship 1.26.0 + starship.toml del repo + init bash. Pendiente: gate visual del usuario (como en los rollouts previos). Nota: un pi -p de verificación colgó 300s por la API de nan (red), no por el theme — el arranque con theme activo ya quedó demostrado en la corrida previa.
