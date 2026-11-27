# ContentCard

A surface card with a title and short description that optionally links as a whole.

Source: `src/components/custom/ContentCard.astro`

## When to use

Use it for channels, formats or any set of equal destinations inside a card grid.

## Props and slots

- `title` (required): rendered as an `h3`.
- `href` (optional): the whole card becomes an `<a rel="noopener">`; without it, a plain `<article>`.
- Default slot: the description paragraph.

## States and motion

- Hover (linked only, `@media (hover: hover)`): `translateY(-lift-md)` + `glow-md`, border toward `brand-500`, `duration-card`, `ease-out-expo`.
- Spotlight: a `brand-500` radial glow follows the pointer (`--spot-x/--spot-y`) on fine pointers, on any card.
- Press: `scale(press-scale)`. Focus: `text` ring at `focus-offset`.
- Reduced motion: no lift or scale.

## Do / don't

- Do keep descriptions to one or two sentences.
- Don't nest links or buttons inside a linked card.
- Don't mix linked and unlinked cards in one grid.
