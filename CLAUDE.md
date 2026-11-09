# Farm game: notes for contributors and reviewers

A single-player recreation of the original FarmVille (2009) in Godot 4.7 (GDScript) for Android phones and
tablets. Principle: first pure FarmVille, then our own touch, clearly marked.

## Layout
- `autoload/game.gd` (`Game`, class `GameState`): the shared core (coins, gems, XP, time, plots and crops,
  placed objects, mastery, tutorial), saving, and every signal. It owns one of each subsystem.
- `scripts/systems/*.gd`: the subsystems, each a `GameSystem` with its own state and rules, reached as
  `Game.crafting`, `Game.vehicles`, `Game.bees`, `Game.strays`... Each saves its own fields
  (`reset`/`save_to`/`load_from`); a new feature with its own state gets its own system, not more `game.gd`.
- `data/catalog/*.json` + `data/catalog/schema.json`: every item, by category -> family -> variant.
  Loaded into the classes in `scripts/catalog/` (ItemDef -> CropDef, PlaceableDef -> ProducerDef ->
  TreeDef/AnimalDef, BuildingDef -> BarnDef/CraftingDef, VehicleDef, DecorationDef, RecipeDef...).
- `scripts/farm_grid.gd`: farm geometry and input; owns the world layers in `scripts/world/`
  (GroundLayer, ShadowLayer, ObjectLayer of FarmPiece nodes, OverlayLayer) and `scripts/fx/`.
- `scripts/world/farm_camera.gd`: eased zoom, momentum, elastic edges.
- `scripts/hud.gd`: top bar, toolbar, menus. `scripts/placeholder_art.gd`: code-drawn art until painted art
  (`art/final`, via `SpriteBank`) replaces it.
- `tests/test_runner.gd`: rule tests (run headless in CI). `tests/shots.gd`: screenshots in CI.

## Rules
- Follow `REVIEW.md`. Item behaviour on catalog classes; numbers as named constants or data.
- Player-facing text lives in `locale/strings.csv` (keys, en) and code shows it with `tr("KEY")`
  (`TranslationServer.translate` in static functions; constants hold keys). `tools/strings_lint.py` checks it in CI.
- Regenerate `docs/CATALOG.md`, `art/manifest.json` and `tools/generate_art.ipynb` with their tools after
  catalog or art changes (CI checks them).
