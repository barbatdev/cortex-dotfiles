# RepoChips

A wrapped row of mono Button links to the public RefactorIA repositories.

Source: `src/components/custom/RepoChips.astro`

## When to use

Use it in the Open Source section to point to the repos.

## Props and slots

- No props or slots. The repo list (cortex, presupuestos, streamdeck-nan) is hardcoded in the component.

## States and motion

- Each chip is a Button `variant`-less `element="link"` with class `mono-label`. Approved look (maintainer, 2026-10-15): underlined mono links, as in the preview (rule travels on hover + `text-glow-strong`). The site currently omits `variant="link"` and renders filled primary buttons; fix that in the website refactor.
- Hover only under `@media (hover: hover)`; focus ring per Button.

## Do / don't

- Do edit the array in the source to add a repo.
- Don't add non-repo links here.
