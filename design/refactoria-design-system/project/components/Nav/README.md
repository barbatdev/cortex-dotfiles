# Nav

The sticky top bar: RefactorIA wordmark with a blinking cursor and the section links, collapsing behind a toggle on narrow screens.

Source: `src/components/Global/Nav.astro (links via src/components/Global/NavLink.astro)`

## When to use

Use it once per page, at the top.

## Props and slots

- `render`: `false` skips rendering.
- `overlap`: fixes the bar over the page instead of sticky; give the first section `paddingTop="navoverlap"`.
- Links are hardcoded NavLinks (Qué es, Contenido, Open Source, Música, Creador, Contacto). NavLink props: `href` (required, compared to the URL to set `aria-current="page"`), `render`, plus `a` attributes; slot is the label.

## States and motion

- Cursor `_` in `brand-500` blinks; stops under reduced motion.
- Below 48rem: toggle animates to an X and the menu opens with a `grid-template-rows` reveal (source uses `--open-duration`/`--open-ease`, not in tokens; preview uses `duration-card` + `ease-out-expo`). Closes on link click, Escape (returns focus), outside click, or growing past 48rem.
- Hover: wordmark and toggle dim to 60%; links go to `text` (preview adds `text-glow-soft`). Current page is underlined on desktop.
- No-JS: menu is shown open.

## Do / don't

- Do keep link labels to one or two words.
- Don't add buttons to the bar.
- Don't render two navs.
