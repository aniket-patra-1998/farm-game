# The art and UX polish loop

A second scheduled session (18 Nov 2026, 09:55 to 17:55 IST) works as a professional game designer on the look
and feel. It follows docs/POLISH.md (the goal, the owner's taste, the guardrails, how to merge, frugal use) and,
for its own subject, this page. Its rows go in the same log doc, prefixed "Art:".

## The brief (the owner's words, 18 Nov)
Polish the UI, icons, art and broken pieces: the look and polish of the farm, each component, every menu, every
icon. Do not change the art completely: polish, refine, improve animations a bit, simplify, make it modern, and
make the whole game's art and design look unified and coherent, not parts pieced together. Look at the colour
palette and gradients for improvement opportunities.

## What a run may change directly (refinement)
- Colour: improve the existing palette, never shrink or limit it: richer, more harmonious hues that sit well
  together across UI, icons and 3D (data/ui_theme.json, model colours, shader tints); better gradients (depth,
  light, consistent direction and highlight); saturation tuned where it reads immature or dull; contrast for
  legibility on a phone.
- Shape and finish: outline weights, corner radii, shadows, highlights and sticker edges made the same everywhere;
  icons nudged to sit in one set (tools/make_ui_icons.py), without changing what an icon depicts.
- Layout and type: spacing on one grid, alignment, type roles, padding, text that clips or crowds, menus made
  simpler and calmer (fewer boxes, clearer hierarchy) while doing the same things.
- Motion: easing, timing and amplitude of UI and world animations (pop-ins, panels, bobs, sways), restrained and
  smooth; nothing too fast, bouncy or jittery.
- Broken pieces: anything misdrawn, misaligned, z-fighting, clipped, overlapping, missing a state, or out of style.

## What a run only reports (never builds)
A new design or concept (a different icon subject, a new art style, a redrawn model, a new layout or screen), a
change to a look the owner picked (docs/POLISH.md lists them: keep them), or a large redo. Describe it in the
log's "Reported, not built" with what and why; the owner picks before anything is built.

## How a run works
1. Survey before changing: render the screens and views it will touch (tools/look_shot.tscn with --out and
   --hour; tools/ui_sheet, tools/icon_sheet, tools/contact_sheet) and look at them yourself at 1x; never send them.
2. Pick the change with the best gain for effort; make it data-driven and apply it to every similar component.
3. Render again and compare with the before (tools/look_compare.py); keep it only if it is clearly better.
4. Art builders are fingerprinted (data/art_sources.json): a change to a builder file needs its re-export
   (CLAUDE.md, docs/ASSETS.md); avoid touching builder files for non-visual reasons.
5. Merge as docs/POLISH.md says (rebase, full precheck, fast-forward main), log, next step until ~50 minutes.
