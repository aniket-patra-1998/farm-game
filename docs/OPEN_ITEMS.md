# Open items

Kept in the order we agreed: stress round done first, then visual detail, then the farming-core roadmap.

## Performance (stress round, part 2)
- Draw calls on the max farm: about 2,800 (was 8,000; the woods are baked per area and yard animals thin out
  when zoomed out). Next biggest: buildings (~45 surfaces each); use `tools/perf_probe` census to find them.
- Saving: a queued save now copies the farm (about 11 ms on the full-barn stress farm, was 25) and writes on a thread; pausing/closing still saves before returning.
- Off-screen free animals still think every second frame (cheap); building yards already throttle.
- 2D world in 3D mode: measured at 350 of 7,400 nodes, nothing per frame (the overlay and taps use it), so it stays; revisit only if memory matters.

## Ground: done
Meadow variety and bare earth, stronger lawn edge (mown border, earth lip, contact shade at the wall), forest floor under
the woods, worn dirt / shaded brick / stepping-stone paths, footprints and wheel tracks (Trails), pond and fountain banks.
Left as is: buildings already stand on a stone footing with contact shade and worn ground, so no extra berm; farmland keeps the plot soil material.

## Art (docs from the procedural art plan; checked against the code, all its findings hold)
Order: P0 fixed daylight showcase baseline -> P1 tree silhouettes (6-tree pilot: oak, mango, apple, willow, pine,
one fruit tree) -> P1 flower-bed and shrub compositions -> P1 ground tuft/flower variants and patches ->
P2 prop silhouettes -> P2 lighting calibration -> P3 distance simplification.
Rules we keep: no more balls to fix blobs; measure each step with the stress probe; no gameplay data, ids,
footprints or save changes; deterministic seeds; keep MultiMesh/bake.
- Vehicle models (bland): same pilot treatment. Also: sizes by kind (the Combine clearly bigger and heavier-looking than the Tractor, today all drawn alike in the Garage doorway), weight in the animation (slower, deeper bounce, dust), engine/wheel/work animations.
- Decoration detail kit (ridge caps, lanterns).

## Systems
- Save validation (SaveValidator, `add_object` invariants, migrations test).
- CI: fail on import errors, read-only permissions, SHA-pinned actions; README sync; Android export preset.
- HUD split, PlacementSystem, game.gd persistence module.

## Balance (the numbers)
- Done: every number in `data/balance.json` read through `Balance`; weather as steady seasonal spells; `tools/balance_sim.tscn`
  and docs/BALANCE.md (baseline, findings).
- Done: pace retuned to "slower, FarmVille-like" (level 20 in ~14 days at three visits a day, ~28 at one) via
  `economy.level_xp`; the bot buys land, trees and animals and has a per-visit action budget.
- To tune next: the coin sinks (land costs, building prices, crafting) once the bot buys buildings too; coins still pile up.

## Farming core
- Feeds and animal tastes (draft for review first), queen bee and flowers, adjacency synergies (super
  orchards), quests, boosts per home, Feed Mill/Nursery/dogs, look-test tool, central Feedback service.

## Joined structures (fences, hedges, walls, paths)
- The 2D fallback world still draws them as separate straight tiles (no joins); 3D is the real game.
- Hedges lost their wind sway when they moved to shared MultiMesh pieces (the sway shader isn't instance-aware yet).
- Not yet: drag to draw a whole line, gates, joining to building yards and pens, corner posts shared with neighbouring paths' edges, taller fence variants. Old saves keep their `flip` field; it's ignored for these.
