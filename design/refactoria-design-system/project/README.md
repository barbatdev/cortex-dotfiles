RefactorIA is a developer community about modernizing software with engineering judgment. Motto: **Modernize with engineering judgment. No hype.** The look is violet-black and quiet: one brand violet, one sans, a mono voice for anything code-flavoured, and the braille-rendered full-beard mark.

## Content fundamentals

- Write site copy in Rioplatense Spanish with voseo: "Escribinos.", "Usá Node.js 24". The motto and product taglines stay in English.
- Headings are short, declarative and end with a period: "Criterio de ingeniería, no ruido.", "El software también se canta.", "Creada y dirigida por Juan Barbat."
- Sentence case everywhere. The name is always written **RefactorIA** (capital I and A). Sub-brands keep the prefix: RefactorIA Devs, RefactorIA Labs, RefactorIA Music.
- Every section opens with a two-to-three word eyebrow ("Qué es RefactorIA", "Contenido", "Open Source", "Contacto") above an `h2`.
- No emoji, no hype words ("revolucionario", "game changer"), no exclamation marks. State what the thing is and why it is useful.

## Visual foundations

### Color

- The default theme is **dark**: `background` (`dark-900`) with `text` (`light-100`). Use `light` for paper-like contexts and `brand` only for a single emphasis section.
- `brand-500` is the brand hue. `accent-spark` (amber) is its only companion: a spark at about 2% of any piece, on the eyebrow, the blinking `_` cursor, the braille texture or one icon. Never on buttons, headings, links or large fills. Proportion: about 70% dark ground, 20% white text, 8% violet, 2% amber.
- Violet stays the lead everywhere: spend it on primary buttons (`button-background`), the hovered link underline (`link-border-hover`) and one accented word per heading (`heading-accent`). Never use it for body text in dark: it reaches 3.3:1 on `dark-900`, legible only at 24px and up.
- Raise surfaces with `background-2`, then `background-3`; never with shadows. The source defines no shadow tokens.
- Use `text-2` for captions, meta and taglines; `border` for hairlines. `border` is decorative (under 3:1): pair it with fill or text when it bounds a control. The secondary button's outline uses `button-2-border` (`text-2`) for that reason.
- Primary buttons invert on hover: `button-background-hover` takes the theme's `text`, and `button-text-hover` its `background`.

### Type

- One sans, **Inter**, for everything readable; two weights ship: 400 for text and 500 for headings. The 500 file is Google Fonts' Latin subset of Inter (SIL OFL 1.1).
- Headings (`display`, `h1`–`h6`) use weight 500, letter-spacing −0.03em and `text-wrap: balance`. Body (`text-large`, `text-main`, `text-small`) uses 400 and `text-wrap: pretty`.
- All sizes are fluid between a 320px and a 1440px viewport; the tokens hold the 1440px maximum and each usage note holds the minimum.
- The mono face is **FiraCode Nerd Font Mono Beard**, the brand's custom FiraCode (SIL OFL 1.1), shipped as a Latin, punctuation, arrows and box-drawing subset with its ligatures. Its private beard glyph (U+F0F00) draws the retired beard and is left out; never use it.
- Use the `mono` family (`mono-label`) for eyebrows, the hero's typed motto ("> … No hype."), repo chips and anything that quotes code.

### Spacing and layout

- Space with `space-1`…`space-8` inside components and `section-space-small|medium|large` between sections. Both scales are fluid.
- Page width: content max 1440px, with `site-margin` on the sides and `site-gutter` between columns. The nav is 80px tall.

### Shape, borders, focus, motion

- `radius-small` for inputs and chips, `radius-main` for cards and release covers, `radius-small` for text buttons, `radius-round` for round mark buttons and pill tags.
- Lines are `border-width` (1px) in `border`.
- Focus: a solid `focus-width` (2px) ring in `text`, offset by `focus-offset`. It holds above 3:1 on every surface in every theme.
- Motion follows the Motion section below.

## Motion

### Character: electric with glow

Interactive things **lift, light up and come into focus**. Light is violet (`brand-500`), never a grey drop shadow. Nothing bounces, overshoots or spins. Movement is small; the glow carries the feedback. Two terminal details stay on top of that: the blinking `_` cursor and typed confirmations, used only on mono, code-flavoured elements.

- Use `ease-out-expo` for every lift, glow and reveal.
- Glow levels climb with importance: `glow-sm` (controls) → `glow-md` (cards) → `glow-lg` (rewards only, one on screen at a time). Text uses `text-glow-soft` (ambient) and `text-glow-strong` (hover, confirmation).

### States

| State | Button | Card / cover | Mono accent (email, eyebrow link) |
| --- | --- | --- | --- |
| Hover | `translateY(-lift-sm)` + `glow-sm`, fill flips to `button-background-hover`, `duration-hover` | `translateY(-lift-md)` + `glow-md` + border toward `brand-500`, `duration-card` | `text-glow-strong`, `duration-hover` |
| Press | `scale(press-scale)` + `glow-press`, `duration-press` | `scale(press-scale)` | — |
| Focus | 2px solid `text` ring, offset `focus-offset`; never only a glow | same | same |
| Confirm | label swaps to the result ("Copiado") | — | typed `copiado_` + one `glow-press` pulse |

Apply hover effects only under `@media (hover: hover)`.

### Entrances

- **Blur-to-focus**: from `opacity: 0`, `blur(blur-reveal)`, `translateY(reveal-offset)` to rest, in `duration-reveal`. Default for headings and blocks entering the viewport.
- **Stagger**: siblings start `duration-stagger` apart; braille rows 55ms apart.
- Trigger once, at 10% visibility, never on scroll back up.

### UX rewards

Rewards acknowledge the visitor. Each appears once per page, and none blocks reading.

| Reward | Where | Behaviour |
| --- | --- | --- |
| Beard reveal | Hero | Braille rows fade up one by one with `text-glow-soft`. |
| Typed motto | Hero | Phrase types in mono, ends on the accented "No hype." with a blinking `_`. |
| Scroll reveal | Section blocks | Blur-to-focus with stagger. |
| Scroll progress | Top of page | Thin `brand-500` bar driven by scroll position. |
| Copy email | Contact | Typed `copiado_` and a `glow-press` pulse. |
| Topic marquee | Content | Continuous horizontal loop. |
| Cursor blink | Nav, footer | `_` blinking every `duration-blink`. |

### Scroll effects and parallax

- Parallax moves **background layers only** (braille texture, glow orbs, artwork), never text or controls, by at most `parallax-max` of the section height.
- Animate only `transform`, `opacity` and `filter`. Prefer CSS scroll-driven animations (`animation-timeline: view()`); fall back to a static layout where unsupported.
- At most one parallax section per screen height.

### Reduced motion

Under `prefers-reduced-motion: reduce`: no lift, parallax, marquee movement, blur or stagger; content renders at rest. Colour and glow changes on hover and focus stay, because they carry state.

## Iconography and marks

- The brand mark is a full beard in solid silhouette, with upswept sides and a moustache set into it. It is a beard, not a moustache: never isolate or exaggerate the moustache. Use `refactoria-mark-light.svg` on dark grounds, `refactoria-mark-dark.svg` on light grounds, and `refactoria-mark-tile.svg` where a square is needed (avatars, favicons). Never redraw or outline it.
- The wordmark is "Refactor" in `text` plus "IA" in `brand-500`, always one word with no space (`refactoria-wordmark.png`). The "IA" accent is the only coloured part.
- On the hero the mark is drawn as braille characters (U+2800 block) in the mono family. That texture is a brand motif: use `refactoria-braille.txt` exactly as shipped (56 columns × 36 rows, line-height 1.12, letter-spacing 0) and never re-flow or resize it by changing the column count.
- UI icons are a small set of single-stroke SVGs (arrow, arrow-full, check, close, play, pause) drawn in `currentColor`. Do not add an icon library.
- No illustrations, mascots or stock photos. The only imagery is release artwork for RefactorIA Music.
