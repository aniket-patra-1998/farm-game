# Farm Game (working title)

Single-player farming game for Android phones and tablets, built with Godot 4.
This is milestone 1 of the V1 plan: the core farm.

## What works

- 12 × 12 isometric farm with a raised earth edge
- Plow (15 coins, +1 XP), plant, harvest; drag a finger across plots to repeat an action
- 12 crops with real-time growth, four growth stages, and withering
- Tapping a ripe crop harvests it with any tool; tapping a growing crop shows time left
- Coins, XP, levels (crops unlock by level), crop mastery with three stars
- Floating coin and XP numbers, short messages for level-ups and mastery stars
- Auto-save on every action and when the app goes to the background; growth continues while closed
- Debug builds have a "skip 1 h" button for testing timers

## Run it

1. Install Godot 4.7 or newer (standard build) from godotengine.org.
2. Open Godot, choose Import, and select `project.godot` in this folder.
3. Press F5 to run. Mouse clicks act as touches.

To test phone and tablet layouts, resize the game window, or set a test size under
Project Settings > Display > Window.

## Build for Android (later)

Install the Android export templates and an Android SDK, then Project > Export > Add Android.
Use AAB format for the Play Store.

## Project layout

| Path | What it holds |
| --- | --- |
| `autoload/game.gd` | All game rules and state: plots, crops, coins, XP, levels, mastery, save/load |
| `data/crops.json` | Crop list and numbers; edit to rebalance without touching code |
| `scripts/farm_grid.gd` | Draws the farm and turns taps into actions |
| `scripts/placeholder_art.gd` | Every visual, drawn with simple shapes; swap for sprites here |
| `scripts/hud.gd` | Top bar, toolbar, messages |
| `scripts/main.gd` | Wires everything together and frames the farm on any screen |

## Art

All art is original placeholder art drawn in code. Replacing it means editing only
`placeholder_art.gd` (for example, `draw_texture` with your sprite sheets).

## Next milestones

2. Surprise layer: drop tables, pity counter, collections, ribbons
3. Trees, animals, bees, strays
4. Vehicles, parts, upgrades, fuel
5. Crafting, decor, storage, land expansion
6. Breeding, greenhouse, rare animal home
7. Shop, tutorial, sound, Play Store release
