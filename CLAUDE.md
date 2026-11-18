# Farm game: notes for contributors and reviewers

A single-player recreation of the original FarmVille (2009) in Godot 4.7 (GDScript) for Android phones and
tablets. Principle: first pure FarmVille, then our own touch, clearly marked.

## Map (the detail: docs/ARCHITECTURE.md; open only the part you touch)
- `autoload/game.gd` (`Game`, `GameState`): the shared core and every signal; owns the subsystems in
  `scripts/systems/` (`Game.storage`, `Game.crafting`, `Game.social`...), each a `GameSystem` that saves its own
  fields and says what the showcase farm shows of it (`showcase()`: a new feature with a state worth seeing
  adds its own, so the showcase keeps up). `Game.player` is the farmer: farm work is queued and done when the farmer
  walks there.
- `data/catalog/*.json` → `scripts/catalog/` classes (item behaviour lives there); every other number or rule
  is in `data/*.json` (Balance, Release, Quality, Feedback, sounds, weather...).
- `scripts/farm_grid.gd` and `scripts/world/`: farm geometry, input, placing; `scripts/world3d/`: the 3D farm,
  models built from data. `scripts/hud.gd`, `scripts/hud/`, `scripts/ui/`: the interface on one kit (docs/UI.md).
- `autoload/sound.gd`, `autoload/feedback.gd`: sounds and the game's moments. `tests/suites/`: one `TestSuite`
  per area. `tools/`: precheck, generators, probes (perf, contact sheet, state sheet).
- Docs: V1.md (the first release's line), AUDIT.md (the plan), ASSETS.md and ART_BIBLE.md (art), UI.md,
  WEATHER.md, SEARCH.md, PLAYER_EXPERIENCE.md, VIP.md (VIP and the Barn), RUST.md (vehicle rust), WATER.md
  (water and what lives on it), NEXT.md (handoff between sessions), POLISH.md (the polish loop: vision and guardrails), ART_POLISH.md (its art and UX run).

## Rules
- Before every push `tools/precheck.sh <godot>` passes (the pre-push hook runs it: set it up once per clone
  with `git config core.hooksPath tools/hooks`). CI runs Tests on main pushes and PRs; docs-only changes skip
  Tests, Screenshots, the phone build and the review.
- docs/V1.md is the line for the first release; `Release.has(id)` / `Release.on(feature)` apply it, nothing
  is deleted, tests run with everything on. docs/AUDIT.md is the plan: apply each fix to every similar module.
- Follow `REVIEW.md`. Numbers as named constants or data; item behaviour on catalog classes.
- Player-facing text in `locale/strings.csv`, shown with `tr("KEY")`; numbers through `UiTheme.number` and
  every shown text through `UiTheme.tidy`; sizes by type role. New UI uses the kit (`BookPanel`, `UiKit`'s paper
  look, `CardList` for card menus, `FloatText` for words over the farm), never colours of its own.
- A game moment's sound, buzz and float colour go through `Feedback` (data/feedback.json), never
  `Sound.play`/`Sound.buzz` directly; every sound has its row in art/sound/SOURCES.md (CC0 or made here).
- Objects join and leave the farm only through `Game.add_object` / `remove_object` / `set_objects`; a change
  in place says which: `Game.objects_updated(uid)`. New things arrive only through `BarnStorage.welcome`.
- Every "can I?" about a building is a `BuildingSystem` `Verdict`; the UI asks, never repeats a rule.
- A plot's row and column are `GameState.row_of`/`col_of`, `Game.on_farm(i)` whether it is on the farm.
- Every new farm action is declared in `data/actions.json` for the helper that fits it (a test enforces it).
- 3D: repeated things through `Instancer`, fitting things into space through `SpaceFit`, shader globals through
  `ShaderGlobals`, a new costly look as a `Quality` field; hold data/perf_budget.json.
- Art follows docs/ASSETS.md (made offline as files, one registry, a fallback, a budget). Regenerate
  docs/CATALOG.md, art/manifest.json, tools/generate_art.ipynb and data/art_versions.json after catalog or art
  changes; exported art stays tied to its builders (data/art_sources.json).
- New looks and concepts (icons, art, layouts) are shown as a sheet of options first and wired into the game
  only after the owner picks one; nothing unpicked is pushed.
- One session per feature: before it ends, a short handoff in docs/NEXT.md.
