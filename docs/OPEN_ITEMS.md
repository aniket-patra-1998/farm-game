# Open items

Kept in the order we agreed: stress round done first, then visual detail, then the farming-core roadmap.

## Performance (stress round, part 2)
- Draw calls on the max farm: about 2,800 (was 8,000; the woods are baked per area and yard animals thin out
  when zoomed out). Next biggest: buildings (~45 surfaces each); use `tools/perf_probe` census to find them.
- `save_game` takes 24 ms with a full barn and gift box (516 KB): consider writing the file on a thread.
- Off-screen free animals still think every second frame (cheap); building yards already throttle.
- 2D world is still built in 3D mode (hidden, not processed).

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
- Vehicle models (bland): same pilot treatment.
- Decoration detail kit (ridge caps, lanterns).

## Systems
- Save validation (SaveValidator, `add_object` invariants, migrations test).
- CI: fail on import errors, read-only permissions, SHA-pinned actions; README sync; Android export preset.
- HUD split, PlacementSystem, game.gd persistence module.

## Farming core
- Feeds and animal tastes (draft for review first), queen bee and flowers, adjacency synergies (super
  orchards), quests, boosts per home, Feed Mill/Nursery/dogs, look-test tool, central Feedback service.
