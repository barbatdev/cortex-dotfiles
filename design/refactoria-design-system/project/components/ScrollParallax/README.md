# ScrollParallax

Background-only parallax: decorative layers (glow orb, braille texture) move with scroll while text and controls stay fixed.

Move layers by at most `parallax-max` of the section height, animate only `transform`, `opacity` and `filter`, prefer CSS `animation-timeline: view()` on the site, and render static under reduced motion. One parallax section per screen height.
