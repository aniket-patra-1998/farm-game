# The art and UX polish loop

A second scheduled session (18 Nov 2026, 09:55 to 17:55 IST) works as a professional game designer on the look
and feel. It follows docs/POLISH.md (the goal, the owner's taste, the guardrails, how to merge, frugal use) and,
for its own subject, this page. Its rows go in the same log doc, prefixed "Art:".

## The brief (the owner's words, 18 Nov)
Polish the UI, icons, art and broken pieces: the look and polish of the farm, each component, every menu, every
icon. Do not change the art completely: polish, refine, improve animations a bit, simplify, make it modern, and
make the whole game's art and design look unified and coherent, not parts pieced together. Look at the colour
palette and gradients for improvement opportunities.

## The broad goal (owner, 18 Nov)
Today the game as a whole is not attractive or beautiful to look at. By the end it should be: a farm a player
enjoys just looking at, and a game that reads as one designed product. Every change serves that, through:
1. Better colour: the existing palette improved (richer, harmonious hues, gradients with depth and light), never
   limited.
2. One icon set: same outline, shading, highlight, sticker edge and visual size.
3. One panel style: one spacing grid, corner radius, shadow and type scale; calmer, clearer menus.
4. One motion language: smooth, consistent timing; nothing too fast or bouncy.
5. No broken pieces in any screen surveyed.
6. A record: each change logged with what it improved; before/after pictures kept, sent only when asked.

## The lens: do things look good together? (owner, 18 Nov)
Judge every piece next to its neighbours, never alone. Does an animal look good standing by a tree? A tree and an
animal by a building? A farmer among crops, a decoration on the lawn, a vehicle by a shed? Do they look alive and
as if they belong to one world, or out of place, pasted in from another game? Check each pairing for:
- scale: sizes that read right against each other (data/scale_guide.json);
- style: the same level of detail, edge softness, outline and painted light (file-made and code-built pieces alike);
- colour: saturation, value and warmth in one family; nothing far brighter, darker or greyer than its neighbours;
- light: each reacts to the sun, dusk and night the same way (shaders: same ambient, rim, wrap and shadow);
- grounding: a contact shadow or footing, so nothing floats or looks stuck on;
- life: a gentle idle motion where the real thing would move; nothing frozen beside something swaying.
Render compositions of these pairings (look_shot views or a scratch scene) at noon and dusk. Comparisons within one
render hold even though this renderer is brighter than a phone; absolute colour does not, so tune relative to the
neighbours, and keep the farm's best-looking pieces (the owner's picks) as the reference the rest moves towards.

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
