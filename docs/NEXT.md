# Where work stands (handoff for the next session)

Read this, CLAUDE.md, and the design doc "Farm game: buildings, end to end"
(https://claude.ai/artifact/BCxz5VHsfe6G7dSQnHLWsf) before starting. Don't re-read whole files: grep.

## Decided (in the design doc)
FarmVille footprints (with a save migration), FarmVille limits, the 5 planned buildings
(Greenhouse, Windmill, Juice Press, Spinning Mill, Silo) each get a job, materials buyable with gems.

## Done in phase 1
- Sizes are records (`sizes` in buildings.json; BuildingDef: capacity, size_name, size_materials, star_cost).
- `Game.buildings` (scripts/systems/building_system.gd): can_buy / can_expand / can_sell -> Verdict;
  limits (5 Dairy, 3 crafting, 1 of most); buy missing materials with gems. Tests 108-110.

## Done in phase 2 (step 1)
- FarmVille footprints: Coop 3x2, Stable 3x4, Pig Pen 3x4, Bakery/Winery/Spa 4x3, Garden Shed 2x1;
  building_models.json bodies rescaled to keep about the same block in tiles (test 107 passes).
- Save v2 (`SAVE_VERSION 2`, `OLDEST_SAVE_VERSION 1`). `Game.settle_objects()` runs on every load: an
  object that no longer fits moves to the nearest free spot, with message SOME_BUILDINGS_CHANGED_SHAPE_AND
  (appended to absence_note). Test 111 (saving_test.gd) loads a v1 save.
- Known: the 2D placeholder refs (art/refs, drawn by PlaceholderArt into a square diamond) now show the
  3x4 Stable as a long low shed. The 3D model is fine; fix with the phase 3 silhouettes.

## Next, in order
1. Market tabs by category (BuildingDef.tab()).
2. Phase 3 of the doc: each building its own silhouette; ready sparkle; broken Barn.
3. The 5 planned buildings, each with a job.

## How to work cheaply
- CI is the compiler: batch changes, push once, wait once (`until gh run list ... grep completed <sha>`).
- Read failures with: gh api .../jobs/<id>/logs | grep -E "  - |checks,|SCRIPT ERROR" | head
- Look at screenshots only when the look changed.
