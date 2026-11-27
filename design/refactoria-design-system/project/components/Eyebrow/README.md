# Eyebrow

A small mono label with a thin marker, or a filled pill, set above a heading or inside a card.

Source: `src/components/Typography/Eyebrow.astro`

## When to use

Use `default` above section titles (via SectionHeading) and `tag` for release kinds such as Single or Álbum.

## Props and slots

- `tag`: `p` (default) | `span` | `h1`–`h6`; changes semantics only, never the look.
- `variant`: `default` (marker) | `tag` (`text` fill, `background` text, `radius-small`).
- `render`: `false` skips rendering. Default slot: the label; nothing renders when empty.
- Other `div` attributes and `class` pass through.

## States and motion

- No interaction or motion of its own. Inside a linked card it inherits the card's hover.

## Do / don't

- Do keep it to one to three words.
- Do pick `tag` by meaning (`span` inside a sentence, a heading level when it titles a section).
- Don't use it as a button or link.
