# Footer

The site footer: wordmark with cursor, motto, creator line, and identity and community link columns over a copyright bar.

Source: `src/components/Global/Footer.astro`

## When to use

Use it once per page, at the bottom.

## Props and slots

- `render`: `false` skips rendering. Everything else is fixed; links come from `src/data/links.ts`.

## States and motion

- Cursor `_` in `brand-500` blinks every `duration-blink`; off under reduced motion.
- Column links: `text-2` to `text` on hover (preview adds `text-glow-soft`); the creator link turns violet.
- Year is filled by script.
- Grid: stacks, then `2fr 1fr 1fr` from 44rem.

## Do / don't

- Do edit links in `links.ts`.
- Don't add calls to action here; the footer is reference, not conversion.
