# OmniWM migration
Objective: replace yabai/skhd progressively with OmniWM, retaining recovery. Branch: feat/omniwm-migration.
Delivery: ask-on-risk; forecast <400 authored lines. Checks: host status, official app installation, independent safety verification, interactive desktop checks.

## Specs
S1. Replacement target: "https://github.com/OmniNull/OmniWM"; "enfoquemonos en sacar la basura de yabai".
S2. Preserve Karabiner: "lo del caps lock lo uso como control ... por ahora dejalo y después vemos".
S3. Native Spaces may be replaced: "si hayq eu perder los nativos no tengo drama".
S4. Progressive execution authorized: "bueno vamos y vamos viendo".

## Tasks
T1 | S1,S2,S4 | parent | done | OmniWM 0.7.6 installed successfully via Homebrew (exit 0); effective configs backed up and cmp matched; commit pending.
T2 | S1,S2,S4 | parent | done | yabai/skhd stopped, no conflicting processes, code signature verified, OmniWM process running; native Spaces/display map untouched.
T3 | S1,S3,S4 | parent + independent verifier | blocked | Independent safety check passed conditionally; waiting for human macOS permissions and desktop/hub observations. No permanent cleanup yet.

## Log
L1. Original request: "analiza como tenemos yabai configurado ... y si tenemos personalizaciones también porque te voy a dar la misión de sustituirlo con otra cosa".
L2. User: "Odio profundamente a yabai así que tengo un sustituto." Target: "https://github.com/OmniNull/OmniWM".
L3. User: "lo del caps lock lo uso como control ... por ahora dejalo y después vemos ... enfoquemonos en sacar la basura de yabai".
L4. User: "que es lo que recomienda omnivm .... si hayq eu perder los nativos no tengo drama".
L5. User: "bueno vamos y vamos viendo". Parent stages reversible installation and trial before permanent cleanup. No initial Space deletion or monitor rearrangement; no secret files in backup.
L6. Preflight: clean main branch, arm64, macOS 27.2; /Applications/OmniWM.app and ~/.config/omniwm absent. Earlier runtime queries confirmed yabai 7.1.25 and skhd active, AeroSpace inactive. ~/.skhdrc points to cortex-dotfiles-main/skhd/skhdrc; ~/.yabairc points here. Official docs require Accessibility and Input Monitoring, prohibit concurrent resident window managers, and tolerate extra native Spaces for initial trial.
L7. Risk: item 5 (host application installation and service transition). No meaningful automated RED for interactive host setup; use observed installation/status and independent safety verification. User must grant macOS permissions; never automate consent.
L8. Homebrew install exited 0; installed 0.7.6 (website/main documentation can describe newer features). cmp backups passed and independent verifier confirmed copies. No source behavior changed; no automated source tests applicable yet.
L9. skhd --stop-service succeeded. yabai --stop-service failed exit 1 because binary expects com.asmvik.yabai, while actual loaded label is com.koekeishiya.yabai. Recovered with launchctl bootout gui/$(id -u)/com.koekeishiya.yabai. Both processes absent before launch; codesign verification passed; open succeeded; OmniWM PID 42367 observed.
L10. Recovery uses actual existing plists, not mismatched binary service helper: quit OmniWM and verify process gone; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.koekeishiya.yabai.plist and equivalent com.koekeishiya.skhd.plist. Both plist paths confirmed present. Original configs and Karabiner untouched. Human permissions and actual window management/hub behavior remain unverified; blocked before permanent removal.
