# RefactorIA branding contract

This bounded surface makes RefactorIA the default visual language for Ghostty, Herdr, and SketchyBar without changing behavior, keybindings, services, installed fonts, or host configuration.

## Official source evidence

The source of truth is the published RefactorIA site, treated as data only:

- `https://refactoria.dev` — the `pre.hero-beard` element contains exactly 36 `.hero-beard_row` spans.
- `https://refactoria.dev/_astro/Paragraph.qwlurlYD.css` — official tokens: `light100 #fff`, `light200 #ebebeb`, `light300 #f2effa`, `dark700 #2c2144`, `dark800 #17102a`, `dark900 #0b0714`, `brand500 #7127ff`, and `brand-text #fff`.
- `https://refactoria.dev/_astro/index.BwOF64gR.css` — `.hero-beard` uses the site text color, `line-height: 1.12`, and the mono family.
- The favicon and legacy external PNG are intentionally not used: neither proves equality with the site beard.

Recorded source SHA-256 values:

| Source | SHA-256 |
| --- | --- |
| site HTML | `39ed1d64fbe8e39b59e8068da9948dc1bf3e56c5b6679a9b64415b997b1055db` |
| Paragraph CSS | `4c34ae19aecde86b6152d40b8443160ffdfb7439e4e0ba47f747ebf8958c9638` |
| index CSS | `37ae077c398c012ad534081ea7f0f9dafcdadaacda137bd762bbb61a386c2cd4` |

## Palette roles

The exact site tokens are used for surfaces, text, selection, and the brand accent. Terminal and status colors are separate adapted semantic roles so errors, warnings, and successes remain distinguishable:

| Role | Value | Classification |
| --- | --- | --- |
| background | `#0b0714` | official `dark900` |
| surface 2 | `#17102a` | official `dark800` |
| surface 3 | `#2c2144` | official `dark700` |
| text | `#ffffff` | official `light100` / `brand-text` |
| secondary text | `#ebebeb` / `#f2effa` | official `light200` / `light300` |
| brand accent | `#7127ff` | official `brand500` |
| error | `#ff6b8a` | adapted semantic color |
| success | `#58e6a8` | adapted semantic color |
| warning | `#ffc857` | adapted semantic color |
| info | `#8cc8ff` | adapted semantic color |

Selection follows the site contract: white background with the dark900 foreground. The same palette is repeated in `ghostty/config` and `ghostty/profiles/refactoria.conf`, and in `herdr/config.toml` and `herdr/profiles/refactoria.toml`, so the default and optional RefactorIA launchers do not drift. `herdr/config-base.toml` remains behavior-only.

## Local adaptation and exception

This section is local-only. It does not revise official RefactorIA tokens or imply a remote rollout:

- Adapted legible text violet: `#A477FF`.
- The beard glyph uses the official `accent-spark` amber `#FFB547` in both the Starship success prompt (`color_beard`) and SketchyBar. SketchyBar keeps its palette in `sketchybar/colors.sh`, sourced by `sketchybarrc` and every plugin; semantic status colors remain separate.
- In the audited host plugin configuration, Neovim selects only Kanagawa (`gentleman-kanagawa-blur`); no RefactorIA highlight overlay was found, and runtime activation was not confirmed.
- Site tokens, published source hashes, and remote behavior remain unchanged.

## Isotipo and font

`assets/refactoria-braille.txt` is the exact 36-row hero source. The existing custom font identity remains stable:

- Family: `FiraCode Nerd Font Mono Beard`
- Glyph: `U+F0F00`
- Output: `fonts/FiraCodeNerdFontMonoBeard-Reg.ttf`

`fonts/patch_beard.py` converts canonical Braille dots into a deterministic monochrome SVG (`fonts/refactoria-isotipo.svg`) and then imports that vector into FontForge. This is an offline vectorization of verified site text, not a trace of an unverified logo image. External SVG input remains supported for controlled regeneration.

Regenerate only the repository artifact with the verified source font:

```bash
fontforge -script fonts/patch_beard.py \
  --font ~/Library/Fonts/FiraCodeNerdFontMono-Regular.ttf \
  --braille assets/refactoria-braille.txt \
  --svg fonts/refactoria-isotipo.svg \
  --output-dir fonts
```

The command does not install the generated font. It preserves the source font's other glyph metrics and restores the target glyph's mono-cell advance width after outline transforms.

## Recovery checklist

1. Capture `git status --short --untracked-files=all` and SHA-256 values before editing.
2. Compare only the allowed paths from this change against that baseline; do not restore a whole dirty file containing unrelated work.
3. If regeneration is needed, verify the source-font hash and rerun the offline command above; never copy the result into `~/Library/Fonts` during repository work.
4. Validate configuration and shell syntax before any human-owned activation or reload.

Recorded repository artifact hashes:

| Artifact | SHA-256 |
| --- | --- |
| verified source font | `ad88c69cb6a497db9f2714e4b414817aabbee621484a1560bfdb3fd73abdd564` |
| canonical Braille | `785f7832c6f11951c2fc371d86a02791df753213d39dcae0ae2efa1b2c9dae9b` |
| generated SVG | `ffa74a2b5821f56c5aac0a2a6846478e1262a6d651a8fe0ef5b7caa27af6e64c` |
| generated font | `83527223cf5dcd7597e7417347e62bfdf5f7de1b457cf658c8ae615ab7fc4f7f` |
