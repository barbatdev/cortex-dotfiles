# SectionHeading

An eyebrow label above a large section title, left-aligned or centered.

Source: `src/components/custom/SectionHeading.astro`

## When to use

Use it to open every home section. Use `level="h1"` on pages without a hero.

## Props and slots

- `eyebrow` (required): short label, rendered with Eyebrow (`mono-label`).
- `title` (required): heading text, `h2` type style.
- `centered` (optional, default `false`).
- `level` (optional): `h2` (default) | `h1`. Only the tag changes; the style stays `h2`.

## States and motion

- Static component. In the page it enters with the blur-to-focus reveal: `blur-reveal`, `reveal-offset`, `duration-reveal`, `ease-out-expo`, siblings `duration-stagger` apart (shown in the preview; the reveal itself lives in the page script, not in this component).
- Reduced motion: no reveal.

## Do / don't

- Do keep titles as one short sentence ending in a period.
- Don't skip the eyebrow; it is required.
- Don't use more than one `h1` per page.
