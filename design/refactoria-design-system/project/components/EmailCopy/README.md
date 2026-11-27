# EmailCopy

The official email shown as a mono mailto link with a secondary Copiar button that copies it to the clipboard.

Source: `src/components/custom/EmailCopy.astro`

## When to use

Use it wherever the contact address appears as the call to action (the Contacto section).

## Props and slots

- `email` (required): the address shown, linked as `mailto:` and copied.
- No slots.

## States and motion

- The button ships `hidden` and is revealed by the script, so no-JS visitors only get the mailto link.
- Link hover: `text-glow-strong` and a lighter violet, `duration-hover`.
- Button: standard Button `secondary` states (`glow-sm` hover, `glow-press` press).
- Confirm: label swaps to `Copiado ✓`, border turns `brand-500` and a `glow-press` pulse runs; reverts after 2s. If the clipboard fails, nothing changes.
- Reduced motion: pulse removed, label swap kept.

## Do / don't

- Do keep the mailto link: it is the fallback.
- Don't use it more than once per page (the script binds the first `.emailcopy_wrap` only).
- Don't change the confirmation copy per page.
