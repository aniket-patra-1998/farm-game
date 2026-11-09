# Code review standard

Every push to `main` is reviewed against this standard by an independent reviewer (see
`.github/workflows/review.yml`). Findings go on the commit and into the "Code review log" issue, and the
next change fixes them. Severity: **Blocker** (wrong behaviour, crash, data loss, broken save) ·
**Major** (design flaw that will cost us later, missing test for new logic, a real performance problem on
phones) · **Minor** (clarity, naming, small duplication) · **Nit** (style).

## What every change is checked for

1. **Correctness.** Does the logic do what the commit says? Edge cases: empty farm, full farm, level 1 and
   high levels, a save from an older version, time going backwards or jumping days ahead, zero coins.
2. **Design and object orientation.**
   - One responsibility per class. Game rules live in `autoload/game.gd` (the shared core), its
     subsystems (`scripts/systems/`, one per feature: crafting, vehicles, the beehive...) and the catalog
     classes (`scripts/catalog/`); a feature with its own state belongs in its own `GameSystem`, and a
     system reaches others through `game`, never by copying their state; drawing lives in the world layers (`scripts/world/`) and `PlaceholderArt`;
     input lives in `FarmGrid` and `FarmCamera`; menus in `FarmHud`. Nothing crosses those lines without
     a reason.
   - Item behaviour belongs on its catalog class (`CropDef`, `AnimalDef`, `BuildingDef`...), chosen by
     data, not by `if id == "cow"` checks scattered around the code.
   - Composition over deep inheritance; signals over reaching into another node's internals.
3. **Generality.** New content should need data, not code: a new crop, animal, recipe or building is a
   catalog entry. Tunable numbers are named constants or data, never magic numbers inline. Player-facing
   text is a key in `locale/strings.csv` shown with `tr()`, never a sentence in code, and whole sentences
   are one key (no gluing words together or adding "s" for plurals: use one key per form).
4. **Transferability.** Could a new developer pick this up? Clear names, a doc comment on every class and
   public function saying *why*, no dead code, no clever tricks without a comment.
5. **Performance on a phone.** Nothing heavy every frame: redraw only what changed, no per-frame
   allocation in hot loops, no work proportional to the whole farm on each tap.
6. **Feel.** Motion is frame-rate independent (tweens, or exponential easing with `delta`), effects are
   pooled or capped, and nothing blocks input.
7. **Tests.** New rules come with tests in `tests/suites/`; drawing changes come with a screenshot
   in `tests/shots.gd`. CI must stay green.
8. **FarmVille fidelity.** Where the change copies a FarmVille feature, it follows FarmVille's rules; our
   own additions are marked as ours.
