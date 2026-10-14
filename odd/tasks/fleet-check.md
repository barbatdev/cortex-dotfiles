# Fleet check — un comando de salud por equipo

Un solo comando que responde "¿está todo bien en este equipo?" tras las migraciones
de octubre: runtime, wrappers, pi gestionado, extensiones, arranque real de pi,
`gs sync` + compat. Reporte legible y exit code 0/1.

## Specs

- S1: "Tenemos que asegurarnos que este todo bien en todos mis equipos" — `bin/fleet-check` verifica cada equipo con un chequeo único y reporta `RESULTADO: TODO OK` o `RESULTADO: HAY FALLAS`, exit 0/1.
- S2: Verifica: git/node/go/pnpm presentes, `GOROOT` sin valor podrido, wrappers `gs`/`gentle-shell` sin referencias a mise, esquema de pi (gestionado o npm) con runtime existente, extensiones de pi que resuelven (`pi-pretty`, `claude-agent-sdk`) cuando `npm:gentle-pi` está instalado, `gentle-shell --version` responde, arranque real de pi sin errores de extensión, `gs sync` exit=0 con `compat: OK`.
- S3: `--quick` omite el arranque real de pi y `gs sync` (para chequeos frecuentes sin llamadas al modelo ni builds).
- S4: En modo workshop (clones en `~/dev/gentle`) el chequeo de extensión `npm:gentle-pi` se omite sin fallar.
- S6: Detección de perfil: si no hay `gentle-shell` ni `pi`, reporta perfil "sin stack gentle" y exit 0; si solo hay `pi`, valida solo pi y sus extensiones (perfil mínimo); el perfil completo valida todo (S2).
- S5: Cada chequeo fallido se lista con ✗ y motivo; los pasados con ✓. Los bugs conocidos del verificador no deben producir falsos positivos (`go version`, no `go --version`; la versión de pi puede imprimirse sin prefijo).

## Tasks

- T1 (S1-S5): implementar `bin/fleet-check` (bash, sin dependencias nuevas), verificar en mac (full + quick), desplegar a las 3 machines remotas y correr allí.

## Log

- L1 (user): "Tenemos que asegurarnos que este todo bien en todos mis equipos ... podes?" y "vamos con tu recomendación" (roadmap en odd/, E1 primero).
- L2: Base del script = el chequeo manual de 2026-10-13 (/tmp/fleet-check.sh) con sus dos falsos positivos corregidos (`go version`, versión de pi sin prefijo) y el modo workshop soportado (S4).
- L3 (user): la flota son 6 equipos: local, agent-dev, agent-gentle, agent-refactoria, nan, tars.
- L4: nan = Ubuntu 24.04, consumidor mínimo (solo pi 1.0.2, sin node/go/pnpm). tars = offline al censo (reintentar). Spec actualizada: S6.
- L5 (2026-10-14): verificado en 5 máquinas. mac/agent-dev/agent-gentle/agent-refactoria: TODO OK (quick; mac también full). nan (perfil mínimo): 2 hallazgos reales — pi 1.0.2 desactualizado (estándar flota: 1.2.0) y sin API key configurada. tars: offline al censo, pendiente. El chequeo marcó hallazgos correctos, no falsos positivos.
- L6: despliegue de bin/fleet-check en las 5 máquinas alcanzables (~/.local/share/cortex-dotfiles/bin/), md5 verificado.
