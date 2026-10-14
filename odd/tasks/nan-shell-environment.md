# Entorno de shell de nan — réplica de agent-dev

Convertir nan en un equipo de desarrollo con el mismo entorno de shell que
agent-dev (referencia del usuario), en una sola pasada de replicación — no
comando por comando.

## Specs

- S1: "dejar nan funcional **como cualquier equipo mío**" — nan debe correr fish como shell default (con el config de la flota), con las funciones de navegación y helpers (`dev`, `innit`, `barbat`, `gentle`, `refactoria`, `work`, `dotfiles`, etc.) operativas.
- S2: las funciones deben resolver en el layout de nan: `$WORKSPACE_DIR=$HOME/dev` con dirs creados según se necesite; las tools ausentes degradan sin romper (patrón `_go_first_existing_dir`).
- S3: theme RefactorIA de fish activo en nan (mismo selector visual que agent-dev).
- S4: starship como prompt en fish.
- S5: gh instalado (para `gs pr/issue`).
- S6: fleet-check full en nan con perfil full → TODO OK, y verificación de cada comando de navegación en shell de login.

## Tasks

- T1 (S1): instalar fish + chsh.
- T2 (S1,S2): replicar `~/.config/fish/` de agent-dev → nan (sin fish_variables), crear dirs de workspace.
- T3 (S3): theme RefactorIA de fish activo.
- T4 (S4): starship init en fish.
- T5 (S5): gh instalado.
- T6 (S6): fleet-check full + verificación de navegación en login fish.

## Log

- L1 (user): "dev no funciona ... no replicaste nada me estas sacando comandos uno a uno iterando contigo al re pedo cuando te pedí dejar nan funcional como cualquier equipo mío" — crítica aceptada: el enfoque piecemeal fue el defecto; la réplica integral con agent-dev como referencia es el estándar que el usuario fijó antes ("con agent-dev como referencia creo yo").
- L2: agente-dev: fish 3.7.1 (nix-profile) default shell, 69 functions, conf.d con host-files (fish_frozen_*, gentle-ai-channel, nvm, zz-refactoria-theme), starship init NO está en config.fish (localizar), gh 2.96, ~/dev con layout completo.
- L3 (2026-10-14): T1-T6 ejecutados. fish 3.7.1 + gh 2.45 (apt), chsh→fish, repo clonado en ~/dev/barbatdev/cortex/cortex-dotfiles (main 714e507), fish env replicado (tar de agent-dev) + 50 symlinks nix rotos reemplazados por archivos reales del repo (dev/barbat/_go_* entre ellos), paths /home/jbarbat→/home/nan corregidos, dirs de workspace creados. Verificado en login fish: dev/innit/barbat/gentle/refactoria navegan, starship ✓, gh ✓, fleet-check full TODO OK (compat OK). Nota: $theme vacío en fish (el overlay zz-refactoria setea variables de color directamente, no la var universal) — gate visual pendiente del usuario. Host-specific sin fuente en repo: solo .bak viejos (eliminados).
- L4 (2026-10-14): la sesión interactiva del usuario en nan es bash (pre-chsh) — las funciones fish no existen en bash. Paridad añadida: _go_first_existing_dir/_go_dev_dir/dev/innit/barbat/gentle/refactoria como funciones bash en ~/.bashrc (mismo contrato de fallback que fish/zsh). Verificado en bash -ic: dev→~/dev, barbat→~/dev/barbatdev. El usuario activa en su sesión actual con `source ~/.bashrc`; sesiones nuevas (bash o fish) lo traen solas.
