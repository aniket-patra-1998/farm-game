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
- Debug builds have "skip 1 h" and "new farm" buttons for testing
- Starter farm and a 3-step tutorial; a quiet coin top-up if you can't afford seeds

### Milestone 2: surprises, collections, ribbons, camera

- Every harvest rolls for a surprise: golden harvest (5x coins), a collectible, bonus coins or bonus XP
- Pity counters guarantee a collectible every 30 harvests and a golden harvest every 250
- Mastery stars raise your odds of rare finds
- 4 collections of 5 items; trade a full set in for coins and XP
- 6 ribbons with Yellow, White, Red and Blue tiers
- Zoom and move: pinch or mouse wheel to zoom; two fingers, the Hand tool, or right-drag to move
- Ripe crops twinkle

### Milestone 3 (part 1): placement, trees, animals, buildings

- Market for 6 fruit trees, 6 animals and 4 buildings, unlocked by level
- Placement system: drag the outline onto grass (green fits, red doesn't), let go to place
- Move tool to rearrange anything; objects can't overlap crops or each other
- Trees and animals produce on real-time timers; tap when ready to collect
- Chicken Coop, Cow Shed, Horse Stable and Orchard: move loose animals or trees in,
  collect from all of them in one tap, upgrade through 3 levels for more space

### Level-ups, gems and test tools

- Level-up celebration: popup with confetti, +100 coins per level, +1 gem, and what just unlocked
- Gems: premium currency (working name), shown under coins; uses come with the gem shop milestone
- Debug buttons (test builds only): +10,000 coins (and +10 gems), level up, skip 1 h, new farm

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
| `data/collections.json` | Collection sets, which crops drop them, rewards |
| `data/ribbons.json` | Ribbons, tier thresholds and rewards |
| `data/items.json` | Trees, animals and buildings: prices, timers, sizes, capacities, upgrade costs |
| `scripts/book_panel.gd` | The pop-up menu used for Collections and Ribbons |
| `scripts/farm_grid.gd` | Draws the farm and turns taps into actions |
| `scripts/placeholder_art.gd` | Every visual, drawn with simple shapes; swap for sprites here |
| `scripts/hud.gd` | Top bar, toolbar, messages |
| `scripts/main.gd` | Wires everything together and frames the farm on any screen |

## Art

All art is original placeholder art drawn in code. Replacing it means editing only
`placeholder_art.gd` (for example, `draw_texture` with your sprite sheets).

## Next milestones

3. (part 2) Bees and hives, stray animals
4. Vehicles, parts, upgrades, fuel
5. Crafting, decor, storage, land expansion
6. Breeding, greenhouse, rare animal home
7. Shop, tutorial, sound, Play Store release
