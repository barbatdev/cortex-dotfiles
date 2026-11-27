# Video and multimedia

The rules above were written for the site and interfaces. Video is a different medium: it is watched on a phone, often muted, for under a minute, and it has to explain one idea. This section sets the rules for RefactorIA video (Shorts, Reels, TikTok and the animated pieces cut from the lives). Where it differs from the rest of the brand book, **this section wins for video only**; the site keeps its own rules.

It is codified from the first animated Shorts (November 2026): Juan's voice from a live, branded motion graphics on top, no screen or camera footage.

## Format

- Vertical 1080×1920, 30 fps, H.264 + AAC.
- Length: 55–80 s is the target. Shorter is accepted when the source idea is shorter; never pad with filler.
- Safe zones: keep text out of the top 220 px (platform header) and the bottom 380 px (platform caption and buttons), and 64 px from the sides. Subtitles live just above the bottom safe line.
- Header on every frame: the beard mark (`refactoria-mark-light.svg`) with the wordmark and a small `text-2` line saying where the audio comes from ("en vivo · <show>").

## Structure

1. **Hook first.** The strongest sentence of the clip opens it, even when it was said in the middle. No intro card, no logo animation.
2. **One scene per idea.** Each spoken idea gets its own visual metaphor (a context window filling up, a queue vs. a loop, a pruned class tree). Scenes are diagrams and objects, not stock imagery.
3. **Close with the takeaway** in one short line ("Cuidá tu contexto.", "Una cola se retoma, un loop se pierde."), then the CTA card: `refactoria.dev/links`.

## Type in video

- Inter at **700–900** is allowed on screen; it is the only way text holds up on a phone at a glance. The site stays at 400/500.
- On-screen phrases are short (2–6 words), sentence case, Rioplatense voseo. A takeaway line may end with a period; labels do not.
- Mono (`mono` family) for anything code: snippets, file names, repo names (`github.com/refactor-ia/cortex`), commands.

## Subtitles

- Karaoke style: Inter Black, white (`text`), the word being spoken in `video-accent`.
- At most 18 characters per line, never more than 2 lines, fixed position above the bottom safe zone.
- Subtitles follow what was said, corrected only for transcription errors. Keep the speaker's own words and nicknames ("Claudio", "porquería"); never "clean up" his voice.

## Color in video

- The ground is `background` (`dark-900`) with a slow violet glow; violet stays the lead.
- `video-accent` for accented words and the active subtitle word; `brand-500` for fills, rings and diagrams.
- `video-signal-problem` and `video-signal-ok` exist only for video, to show states inside a scene (a "PROBLEMA REAL" stamp, a check on a queue item). Always pair them with a shape or icon.
- `accent-spark` keeps its role: a small spark, never a fill.

## Motion in video

The site rule "nothing bounces, overshoots or spins" does **not** apply to video. Motion in video exists to explain:

- Stamps can slam in with a slight rotation and overshoot; counters can race; a robot can wobble when it gets "dizzy"; clocks and loops can spin.
- Each motion must carry meaning (growth, failure, time passing, loss). No decorative motion.
- Entrances: fades and scale-ins with `ease-out-expo`; words can fall away or fade to show loss.

## Audio

- Loudness −14 LUFS integrated, true peak −1.5 dBTP or lower.
- Voice chain: high-pass and a gentle compressor. **No noise reduction**: on Meet recordings it makes the voice sound canned.
- Music: only RefactorIA's own tracks, low under the voice with ducking, fading in and out.
- Silences longer than 0.4 s are tightened; cuts land on word boundaries.

## Honesty on screen

- Every technical claim is checked before publishing. When the speaker simplifies, the screen may add the nuance in a small line ("la IA no se cansa: se le diluye la atención").
- Cite the source of a factual claim on screen, small, in `text-2` ("Liu et al. 2023, \"Lost in the Middle\"").
- Never put words on screen that the speaker did not say as if they were his; illustrative numbers and configs must read as illustrations, not as real data.
- Participants of the lives never appear (face, voice or name) without their permission.
