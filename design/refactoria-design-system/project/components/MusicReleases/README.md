# MusicReleases

Spotify-style release cards with cover, kind pill, title and listen cue, plus platform links and a Discord note.

Source: `src/components/custom/MusicReleases.astro`

## When to use

Use it in the RefactorIA Music section.

## Props and slots

- No props or slots. Releases (P(DOOM) single, RefactorIA album) and platform links (Apple Music, YouTube Music via `links.ts`) are hardcoded.

## States and motion

- Card hover (`@media (hover: hover)`): `translateY(-lift-md)` + `glow-md`, border toward `brand-500`, play overlay fades in over the cover, `Escuchar en Spotify` lights with `text-glow-strong`.
- Fine pointers: a `brand-500` spotlight follows the pointer and the cover tilts up to 8deg towards it (script). The preview scales the cover instead of tilting.
- Press: `scale(press-scale)`. Reduced motion: no tilt, no lift.
- Grid: one column, two from 44rem.

## Do / don't

- Do use real 1:1 cover art at 112px.
- Do keep `aria-label` "Escuchar <title> en Spotify" on each card.
- Don't add more than one primary listen target per card.
