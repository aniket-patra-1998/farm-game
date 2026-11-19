# The art and UX polish loop

A second scheduled session (restarted 18 Nov 20:30 IST, until 08:35 IST 19 Nov) works as a professional game designer on the look
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

## The survey (18 Nov, noon and dusk) and the agreed target
Why it is not beautiful yet, biggest first:
1. The lawn outshines what stands on it: the brightest, most saturated thing on screen (acid green); stripes and
   dark hollows read as stains. The ground must be calmer than its subjects.
2. Three styles on one farm: crisp black-outlined high-contrast buildings, soft painted animals, noisy candy
   trees (pink, teal, orange). Neighbours do not belong together.
3. Flat light: noon has no shape; dusk is the same picture darker and greyer (no golden warmth, no cool shadow,
   no rim light).
4. Nothing grounded: weak or no soft contact shadow under decorations and animals.
5. Clutter with no rest for the eye (rows of animals, a wall of noisy trees).
Target (approved by the owner): a warm storybook farm in Hay Day's spirit, refined from what exists: warm sun and
cool shadows, a golden dusk; a calmer ground so subjects pop; one family of soft painted materials with warm dark
outlines instead of black; the existing palette made richer and in tune; everything grounded.
Order of work: (1) lighting and grade, the ground's calm, contact shadows; (2) building outlines and the trees' finish into
the animals' style (shape and shading only, never their colours); (3) icons, menus, motion.

## Taste changes wait for the owner's eye; objective fixes merge
- Taste changes (lighting, grade, colours, the trees' or buildings' style) go on branch `art-polish` (rebased on
  main each time), never main. When it holds a set worth judging (about every 2-3 hours), make ONE before/after
  sheet (same views, before = main, after = art-polish, noon and dusk), upload it into the log doc under a
  heading "Art: waiting for your look" (Claude Docs: guide topic.uploads), list what changed beside it, and add a
  row to "Reported, not built". Merge art-polish into main only after the owner approves in the log or in chat.
- Objective fixes (broken pieces, misalignment, clipping, missing contact shadows, timing, consistent outline
  weights and spacing) merge to main directly as docs/POLISH.md says.

## Colour rule (owner, 18 Nov 16:47)
Things keep vibrant, distinct colours, as FarmVille had: each tree, crop, flower, animal and building keeps its own
bold hue. The tree crowns' gentle softening (leaf_tone: each hue kept, a little less saturated) is approved and is
the limit: do not mute objects further or pull them towards one colour. Calm the ground and the light instead.

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
- Animal life, small version (owner-approved 18 Nov; looks only, never coins, finds or timers; each animal thinks
  every 1-2 s and only on screen; settings in the animals' rig data): animals face away from rain and stand closer
  in a storm, an activity rhythm through the day (busy morning, resting in the afternoon heat, still at night), and
  animals turning to look as the farmer walks past. Herds, mothers and babies, fleeing into buildings and the dog
  companion wait until after the feature freeze.
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

## Panel motion (owner, 19 Nov 10:30: "panels open and close with no animation; it looks broken; it should be very smooth")
Measured: only BookPanel and the level-up popup open with motion (UiFx.open); nothing closes with motion
(BookPanel.close_panel just hides), and other surfaces (BuildingSheet, message boxes, the goal sheet, prompts,
the inbox's letters, bubbles) appear and vanish in one frame. The fix, one motion language for every surface:
- UiFx gains `close(panel, then)` beside `open`: open = fade in + scale from ~0.94 + a few px rise, ~0.22 s, ease
  out (cubic); close = the reverse, ~0.16 s, ease in, and only then hidden (then `then`). The dim backdrop fades
  with it. Interruptible both ways (opening while closing reverses from where it is; a second open never stacks).
- Every panel, sheet, dialog and popup opens and closes through these two; a tab switch crossfades its page
  (~0.12 s); nothing bounces or overshoots (POLISH.md: calm, weighty). Only modulate, scale and position: cheap
  on a phone. Input is ignored on a closing panel; Game.modal_open follows the real state.
- A test lists every panel-like class and fails if one shows or hides without UiFx.
- Built (19 Nov, art/panel-motion): UiFx.open / open_with / close / is_open / crossfade, 0.22 s open (cubic out,
  from 0.94 and 8 px low), 0.16 s close (quad in), 0.12 s tab fade; its own frame clock counts a long frame (a panel
  built as it opens) as at most 1/30 s, so the motion is never skipped. On it: BookPanel (every menu, the goal sheet,
  settings, the inbox), BuildingSheet (slides and fades), the away card, the level-up card, the reveal card (fade),
  the tapped thing's bubble, name bubbles, the placing bar (fade); tabs in panels and sheets fade their page in; the
  Market's tapped-item strip fades in. Tests: ui_kit 549 (no surface shows or hides itself without UiFx) and 550.
