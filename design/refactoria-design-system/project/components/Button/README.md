# Button

The one interactive control: a labelled button or link in primary or secondary weight, a quiet underline link, or a round icon mark (play, close, arrow).

Source: `src/components/Button.astro`

## When to use

Use it for every action and every link styled as a control. `primary` for the single main action in a group, `secondary` beside it, `link` for inline or listed destinations (repo chips, platform links), and the mark variants for media and dialog controls.

## Props and slots

- `variant`: `main` (default) | `link` | `play` | `close` | `arrow`.
- `emphasis`: `primary` (default) | `secondary`. Not allowed on `link`.
- `element`: `button` (default) | `link` (renders `<a>`); `href` only with `link` (falls back to `#`).
- `type`: `button` (default) | `submit` | `reset`; `disabled` (buttons only).
- `label`: accessible name for mark variants (defaults `Play`/`Pause`, `Close`, `Next`/`Previous`).
- `pressed` (`play` only): shows the pause mark and sets `aria-pressed`.
- `direction` (`arrow` only): `forward` (default) | `back` (mark rotated 180deg).
- `render`: `false` skips rendering. Default slot: the label (`main`, `link`); nothing renders when it is empty.
- Other HTML attributes and `class` pass through.

## States and motion

- Hover (only under `@media (hover: hover)`): `translateY(-lift-sm)` + `glow-sm`, fill flips to `button-background-hover` / `button-text-hover`, `duration-hover`, `ease-out-expo`.
- Press: `scale(press-scale)` + `glow-press`, `duration-press`.
- Focus: `focus-width` solid `text` ring at `focus-offset`, never a glow alone.
- `link`: the `link-border-hover` rule travels across the bottom border in twice `duration-hover`; mono labels add `text-glow-strong`.
- Disabled: 50% opacity, `not-allowed` cursor, no hover or press.
- Reduced motion: transforms and transitions removed.

## Do / don't

- Do use one primary per group; pair it with secondary.
- Do give every mark variant a `label` when the default name is not accurate.
- Don't use `emphasis` on `link`; it carries no weight by design.
- Don't build ad-hoc buttons; extend this one.
