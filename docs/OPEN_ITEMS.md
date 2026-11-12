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
- Vehicles: done: sizes and weights per kind (Combine ~1.9x the Tractor's width, garage doorway fits two at their own sizes), VehicleRun drives the field (wheels and reels turn, springs, dust, smoke, tracks laid lane by lane). The work itself happens as it drives (VehicleWork: each plot is worked, fuel burned and paid for as the vehicle passes it). Not yet: engine sound loop, implements (plow blades, seed drills) and a look pass on the models.
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
- Done: feeding (docs/FEEDS_DRAFT.md, approved): `FeedSystem`, five feeds from harvests and trees, tastes, one effect per
  feeding, hunger (-30% coins, never none), the Barn's stock, the farmhand feeds; the action registry
  (data/actions.json) so every action is offered to its helper.
- Postponed by the owner (look at later): quests (data/quests.json: missions across all systems, rewards, the counts ribbons use).
- Layout synergies (AdjacencySystem, data/synergies.json): done for orchards and animal homes (coins). Open: bloom gardens, same-crop plots, crafting beside crops, paths and decor, XP boosts, a tag on the farm outside placing.
- Boosts per home (HomeBoostSystem, data/home_boosts.json): done (feed chance, golden luck). Open: more boost kinds.
- Feed Mill (crafting building, bushels to rich feed, data/catalog recipes `feed_mill_recipes`) and dogs (find family + Dog House; dogs add +3% each to gopher finds, cap 50%) are done; the Nursery already existed. Dogs do not dig up finds of their own; the Feed Mill and Dog House have only code-drawn looks so far.
- Queen Bee is now a find (family `queen_bee` in data/finds.json: conditional trigger, pity, grants a queen to the Barn). Birds and collectibles are still on their own system (own pity, collection book, ribbons); moving them is open.
- Feeding look and feel done: hungry animals wear a bubble, a fed one hops and says what the feed did (tests 185). Not yet: look-test tool, central Feedback service. Feeding still needs a balance pass in the simulator (animals and hunger are not in the bot yet).

## Joined structures (fences, hedges, walls, paths)
- The 2D fallback world still draws them as separate straight tiles (no joins); 3D is the real game.
- Hedges sway again (paint3d/canopy3d read each instance's own foot, so MultiMesh pieces sway on their own beats). Gates (a swing gate in a straight run) and tall close-board fences exist as fence styles (`style` in the catalog).
- Not yet: drag to draw a whole line (done for fences, see links tests), the 2D fallback joins, joining to building yards and pens, corner posts shared with neighbouring paths' edges. Old saves keep their `flip` field; it's ignored for these.

## Animal rendering rework (perf probe, 2026-11-12)
On the showcase farm (188 objects) a frame is about 2,744 draw calls; 576 drawn meshes are animals (`Animal3D`), the largest group by far (next: pig pen, 16). Every animal draws its parts as separate meshes. Batch them (one merged mesh per animal with per-part transforms, or a shared batch per species) and check `tools/perf_probe.tscn` before and after. Touches `Animal3D` and `AnimalMotion`. Postponed by the user; to do after the decided items.

## From the code review (2026-11-12)
Fixed: a signal connected every frame in `AmbientLife`; `day_number()` now turns over at the player's local midnight; animal and tree collects no longer feed the crop collectible pity; clock set back is mended on load (timers shift by the skew); `level()` is cached; saves go through a version chain (`SaveMigrations`); crops rebuild only when something changed (growth drawn in 12 steps); a "while you were away" line (ripened, withered, ready; `AbsenceReport`).
Checked and already fine: loose animals are not animated off screen (`Animal3D.animate` returns early outside the view).
Open: Android local notifications when crops ripen (needs an Android plugin and a permission flow; the away line is the in-game half); crops grown continuously by the shader instead of in steps (custom data is full: colour and richness; needs a second data channel); O(size²) free-tile scans in mass sell (not in the perf probe yet).
