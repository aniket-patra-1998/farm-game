# Farm game: notes for contributors and reviewers

A single-player recreation of the original FarmVille (2009) in Godot 4.7 (GDScript) for Android phones and
tablets. Principle: first pure FarmVille, then our own touch, clearly marked.

## Layout
- `autoload/game.gd` (`Game`, class `GameState`): the shared core (coins, gems, XP, time, plots and crops,
  placed objects, mastery, tutorial), saving, and every signal. It owns one of each subsystem.
- `autoload/feedback.gd` (`Feedback`, data/feedback.json): the game's polish in one place: each moment's sound and buzz (`Feedback.moment("place")`) and the colour of each floating text (`Feedback.color("coins")`). Never call `Sound.play`/`Sound.buzz` for a game moment or hard-code a buzz length or float colour; add it to the data, and a test checks every name exists.
- `autoload/sound.gd` (`Sound`): sound effects and vibration. Every sound is a recipe in `data/sounds.json`
  (synthesised once, ahead of time) or a recording; code plays them by name (`Sound.play("harvest")`), and a
  test checks every name it asks for exists. Volume, mute and vibration live in `user://settings.cfg`.
- Vehicles at work are a simulation in `scripts/systems/`, not a picture: `VehicleWork` drives the lanes of `VehicleRoute` with `VehicleMotion`'s weight (data/vehicle_motion.json; size and weight per vehicle in the catalog) and works each plot as it passes, run by `Game.vehicles.advance` (`settle()` for tests); the view only follows it.
- Layout synergies (`AdjacencySystem`, `Game.adjacency`, data/synergies.json; our own touch, Balance `synergy.enabled`): homes of one kind that share an edge pay +10% coins each, up to 4; derived like `LinksSystem`, nothing saved; shown as a line in the building panel and a glow and "+N%" tag while placing.
- Boosts per home (`HomeBoostSystem`, `Game.boosts`, data/home_boosts.json; our own touch, Balance `synergy.home_boosts`): a stocked home adds to a farm-wide boost (feed chance, golden luck), capped; derived, nothing saved.
- Pick up and drop (`Placement`, `HousingSystem.fit`/`homes_for`): what is carried is offered only to buildings that take it now (finished, right kind, room), lit by an outline of the building itself (`Objects3D.outline_of`, `grid.outliner`); unbuilt, broken or full ones are not marked and a drop on them (or on bad ground) sends a lifted or Barn-stored thing back where it came from, while a purchase stays in hand. Rules come from the catalog (`holds`, `holds_kind`); `tests/suites/drops_test.gd` checks every home from the data.
- Feed Mill (our own touch): a crafting building whose `feed_mill_recipes` (data/catalog/recipes.json, field `feed`) make rich feed for the Barn instead of goods. Dogs: a find family in data/finds.json with a Dog House; a family's `helps` adds to another family's find chance.
- `scripts/systems/*.gd`: the subsystems, each a `GameSystem` with its own state and rules, reached as
  `Game.crafting`, `Game.vehicles`, `Game.bees`, `Game.strays`... `Game.player` is the farmer: farm work is
  queued there and happens when the farmer has walked to it (the farm grid shows results from its
  `action_done` signal; tests drive it with `player.advance(seconds)`). Each saves its own fields
  (`reset`/`save_to`/`load_from`); saving and loading the farm itself is `Persistence` (`Game.persistence`, with `SaveCheck` mending damaged saves); a new feature with its own state gets its own system, not more `game.gd`.
- `data/catalog/*.json` + `data/catalog/schema.json`: every item, by category -> family -> variant.
  Loaded into the classes in `scripts/catalog/` (ItemDef -> CropDef, PlaceableDef -> ProducerDef ->
  TreeDef/AnimalDef, BuildingDef -> BarnDef/CraftingDef, VehicleDef, DecorationDef, RecipeDef...).
- `scripts/farm_grid.gd`: farm geometry and input (`Placement` in `scripts/world/placement.gd` holds what is in hand and the drop rules); owns the world layers in `scripts/world/`
  (GroundLayer, ShadowLayer, ObjectLayer of FarmPiece nodes, OverlayLayer) and `scripts/fx/`.
- `scripts/world/space_fit.gd` (`SpaceFit`, game-wide, pure rules, tests/suites/space_fit_test.gd): fitting things into space. Every tile keeps a clear border (`TILE_MARGIN`; `fit_model` brings a model inside it, so neighbours never touch), and `pack` puts things (animals in a yard, anything with a radius) in a room clear of its edge, of what is taken and of each other, drawn smaller when crowded (down to `MIN_SIZE`), then only as many as fit. Use it for any placing of things inside a space, not a new per-feature layout. A tree's crown overhangs its tile by design (never shrink trees to fit); instead `Game.can_place` (strict) keeps trees and buildings off each other's edges, and `settle_objects` is not strict so no save moves.
- `scripts/world3d/instancer.gd` (`Instancer`, game-wide): anything that repeats is built once per look and shared: `copy_of` (own node, shared meshes: standalone trees, buildings; `variant(row,col)` picks one of `VARIANTS` looks so copies are not clones) or `parts_of` + `place` (MultiMesh batches for crowds like orchard trees; far zoom swaps them for cheap blobs, `BuildingFill._plant_lod`). Build new repeated things through it, not from scratch each time.
- `scripts/world/farm_camera.gd`: eased zoom, momentum, elastic edges.
- `scripts/hud.gd`: top bar, toolbar, messages; its panels live in `scripts/hud/` (`HudMarket`, `HudCrafting`, `HudBuildings`, `HudBarn`, `HudBooks`, `HudSettings`, each reached as `hud.market` etc.). `scripts/placeholder_art.gd`: code-drawn art until painted art
  (`art/final`, via `SpriteBank`) replaces it.
- `tests/suites/*_test.gd`: rule tests, one `TestSuite` per area (helpers in `tests/test_suite.gd`), run by
  `tests/test_runner.gd` headless in CI. `tests/shots.gd`: screenshots in CI.
- Tools to look before and after a change: `tools/perf_probe.tscn` (frame cost, draw calls, what each system
  costs, on the showcase farm), `tools/contact_sheet.tscn` (every model in a labelled grid, to spot broken
  pieces) and `tools/state_sheet.tscn` (every building as a frame, empty, half full and full and ready); all
  run with a renderer under xvfb (see their headers).
- `scripts/world/animals/`: code-drawn, procedurally animated animals: `AnimalRig` (data/animal_rigs.json),
  `AnimalBehaviour` (what each animal does), `AnimalPose` (one frame), `AnimalArt` and its shape classes.
- `scripts/world3d/`: the farm in real 3D (`Farm3D`; the 2D world stays as a fallback). Models are built in
  code from data and merged by `ModelKit.bake`: `BuildingModel` (data/building_models.json: each size's
  changes, staged construction sites), `TreeModel` (data/tree_shapes.json), `VehicleModel`, `DecorModel`,
  `CropModels` + `CropForms` (data/crop_forms.json: a form per crop); `Animal3D` with `AnimalMotion` (springs: lean, sway, lag, squash, trot); `BuildingFill`
  (animals out in yards, heads at the windows when full, produce piling up, doors opening on collect); `Ground3D` (shade and wear map, tufts); `SurfaceWeather` (rain wets and snow settles on everything, eased over time, through the global shader values `wetness` and `snow_cover` that the ground, wall, paint, canopy and foliage shaders read: a new surface shader should read them too); `LinkLayer` (fences, hedges, walls and paths join their neighbours: `LinksSystem` works out the sides from the farm, nothing is saved; `LinkShape` turns a 4-bit mask into one of six shapes, `LinkModels` builds each as a mesh shared by all pieces, the layer draws them as MultiMeshes and snaps what joined; groups in `data/linking.json`, keyed by catalog `shape`); `VehicleRuns`/`VehicleRun` (the picture of a vehicle at work: wheels and reels turning, springs, `DustPuffs`, tracks; it only follows the real run, `VehicleWork`; implements (plough, seed drill; meta `VehicleModel.LIFT`) go down to work and lift to drive, and the engine hums by `Feedback.hum("engine")`, a `"loop": true` recipe played by `Sound.start_loop`, capped at `Sound.MAX_LOOPS`); `Crowding` (a universal look: kinds listed in `Crowding.GROUPS` that stand packed together grow taller, wider and darker underneath, so a grove or orchard reads as one leafy mass over visible trunks; add a kind there and honour `crowd` in its model).

## Rules
- docs/AUDIT.md is the plan: every system a full FarmVille replica first, smooth on low-end phones. A request
  is a starting point: apply each fix to every similar module, not just the one named.
- Follow `REVIEW.md`. Item behaviour on catalog classes; numbers as named constants or data.
- Player-facing text lives in `locale/strings.csv` (keys, en) and code shows it with `tr("KEY")`
  (`TranslationServer.translate` in static functions; constants hold keys). `tools/strings_lint.py` checks it in CI.
- Regenerate `docs/CATALOG.md`, `art/manifest.json` and `tools/generate_art.ipynb` with their tools after
  catalog or art changes (CI checks them).
- Every new farm action (feed, and any future one) is also offered to the helper that fits it (farmhands, arborists, vehicles), declared once in `data/actions.json` (`Actions`) and enforced by a test; never player-only by accident. Feeding (`FeedSystem`, data/feeds.json) is our own touch and switchable (`feeds.enabled`).
- Objects join and leave the farm only through `Game.add_object` / `remove_object` / `set_objects` (a test enforces it).
