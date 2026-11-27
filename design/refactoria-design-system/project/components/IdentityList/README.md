# IdentityList

The official identity list: each row pairs a platform label with its canonical, verifiable link.

Source: `src/components/custom/IdentityList.astro`

## When to use

Use it where identity must be verifiable (Quién está detrás, links pages).

## Props and slots

- No props or slots. Rows come from `src/data/links.ts` via `link(id)` for: github-personal, github-org, youtube-labs, youtube-devs, spotify, apple-music, youtube-music.

## States and motion

- Link hover (`@media (hover: hover)`): color toward `brand-500` plus `text-glow-strong`, `duration-hover`.
- Rows separated by a `border` rule; wraps at narrow widths.

## Do / don't

- Do change links in `links.ts`, the single source.
- Don't hardcode URLs in the component.
