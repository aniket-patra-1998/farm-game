# Code sweep

What a read through the code found, what was fixed, and what is left, in order of how much it matters.
Only what was actually read is listed; the sweep is not finished (see "Not yet swept").

## Fixed
- **Saves could be lost.** The save was written in place, so a crash or full disk mid-write left a broken
  file, and a broken file started a new farm silently. Now: written to a temp file, the last good save is kept
  as `.bak`, and loading falls back to it (test 124).
- **Every change serialised the whole farm.** A save ran at the end of the frame after any change. Saves are
  now batched (`SAVE_DELAY_MSEC`), and pausing or closing the app still saves at once.
- **The overlay walked every object every frame** in 3D just to find strays; now it skips them unless counts
  are shown or a stray exists. The ready-piece list no longer allocates a closure each frame.
- Objects join and leave the farm only through `add_object` / `remove_object` / `set_objects` (test 125).
- Crop field rules (plow, plant, fertilize, harvest, phase) moved out of `game.gd` into `FieldSystem` (`Game.field`).
- Weather is computed once a second, not several times a frame.
- Trees, orchards and crops sized to fill their space (see TILE_FILL, TREE_FILL, PLANT_SCALE).

## Open, worth doing (worst first)
1. `scripts/hud.gd` (1,800 lines) is the biggest class left: split it by menu (market, building panel,
   young/bloom panel). `game.gd` (1,340 lines) still holds placement and selling; move them to a
   PlacementSystem.
3. Animal minds are updated by `farm_life.gd` for every animal every frame, on or off screen. Update only
   those in view or near it, and the rest at a low rate.
4. The 2D world (`placeholder_art.gd`, 2,000 lines) still loads under the 3D one. It is the fallback; decide
   whether to keep it, and if so keep it out of the 3D path completely.
5. `Farmer3D._process` builds small arrays every frame; use fields.

## Not yet swept
Crafting, vehicles, bees, storage and strays rules for edge cases (a full barn, a removed home with residents);
shaders for low-end GPUs; memory over a long session; touch input on a real device.
