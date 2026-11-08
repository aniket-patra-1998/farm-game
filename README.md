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

### Land expansion and unwither

- Farm grows from 12x12 to 30x30 in 9 steps (Market > Land). Coins need a level; gems expand right away
- The next expansion shows on the farm as a dashed area of wild grass
- Unwither revives every withered crop: start with 2, earn 1 per collection trade-in and every 5 levels, or pay 3 gems
- Older saves carry over automatically

### Bees and strays

- Beehive (level 3) is built from a frame (smokers, beeswax, boards, nails, bricks) and needs a Queen Bee:
  a rare find on flower harvests, or 10 gems. Worker bees then join on flower harvests (25%), up to 200, for 6 coins of honey each a day
- Bees pollinate fertilized crops as you harvest them (bees / 400, up to 50%): 5 free pollinated seeds of that crop, lasting 2 days.
  Pollinated crops stay ripe twice as long and super-harvest 3x as often
- Collecting honey can leave a Fertilize All (fertilizes every growing crop). Bees leave if you're away more than 3 days, the queen after 14
- Every 3 to 6 hours a lonely animal may wander onto open grass, marked with a heart. Tap to adopt it; unadopted strays leave after a day
- New ribbons: Animal Lover and Beekeeper

### Buildings module, the FarmVille way

- Every building has its own shape: a coop on legs with a ramp and nesting boxes, a dairy barn with a gambrel roof, silo and milk cans,
  a long stable with half-doors, a pastel nursery with a heart and a pen, stacked hive boxes, a fenced orchard, a muddy pig pen
- Pig Pen (level 16, from a frame): feed slop (150 coins) and the pigs forage 8 hours for truffles, 1 per 5 pigs.
  10 truffles trade for a rare breed: Berkshire, Tamworth, Spotted or Kunekune
- Orchard harvests can sprout a rare sapling of a tree inside (10%): Rainier Cherry, Honeycrisp Apple, Alphonso Mango and 11 more, paying 1.5x
- Debug button: +20 bees (puts a queen in your hives)

### Vehicles, fuel and the Garage (FarmVille's rules)

- Tractor (level 12, 5,000 coins) plows, Harvester (13, 30,000) harvests, Seeder (14, 30,000) plants the last seed you picked.
  Each works a 2x2 area per tap. Pick it in the toolbar, then tap the field
- Combine (level 31): a 500,000-coin chassis finished with 40 Vehicle Parts (+5,000 XP); harvests, plows and plants in one tap, 3 fuel a plot
- One shared fuel tank of 150, 1 fuel a plot. It refills by itself (1 every 10 minutes); spare tanks cost 3 gems and open when it runs dry
- Garage (level 22, 50,000 coins, frame of bricks, nails and boards): parks up to 20 vehicles and upgrades them with Vehicle Parts:
  2, 5, 10, 15 parts for 3x2, 3x3, 4x3, 4x4 (the last two at level 26). Gearhead ribbon for upgrades
- Vehicle Parts came from neighbours in FarmVille; here they drop while farming once you own a Garage or a Combine chassis

### FarmVille roster, rebalance, starter farm and the barn

- 29 crops and flowers in FarmVille's unlock order and grow times, compressed into levels 1-20
- Economy: every crop profits after plowing; slower crops always pay more per harvest
- Faster level curve: level 20 in about two weeks of regular play (the beta window)
- 14 fruit trees and 12 animals, including ducks, geese, turkeys, rabbits, donkeys and llamas
- Starter farm: farmhouse, mailbox, farm stand, 2 chickens, a cow and a run-down Barn
- Building parts (bricks, nails, wooden boards) from harvests, collecting and a daily gift
- Repair the Barn with 5 of each part; it then stores trees, animals and scenery (Store tool)

## Run it

1. Install Godot 4.7 or newer (standard build) from godotengine.org.
2. Open Godot, choose Import, and select `project.godot` in this folder.
3. Press F5 to run. Mouse clicks act as touches.

To test phone and tablet layouts, resize the game window, or set a test size under
Project Settings > Display > Window.

## Tests

Automated tests cover the game rules: farming, drops, collections, ribbons, buildings,
land expansion, bees, strays, saving and the data files.

- **In Godot:** open `tests/run_tests.tscn` and press F6 (Run Current Scene). Results print in the Output panel.
- **On GitHub:** every push runs the tests automatically (Actions tab). A red cross on a commit means a test failed.

Tests use a throwaway farm with saving off, so they never touch your real save.

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
| `data/expansions.json` | Land expansion steps: size, level, coin and gem prices |
| `scripts/book_panel.gd` | The pop-up menu used for Collections and Ribbons |
| `scripts/farm_grid.gd` | Draws the farm and turns taps into actions |
| `scripts/placeholder_art.gd` | Every visual, drawn with simple shapes; swap for sprites here |
| `scripts/hud.gd` | Top bar, toolbar, messages |
| `scripts/main.gd` | Wires everything together and frames the farm on any screen |

## Art

All art is original placeholder art drawn in code. Replacing it means editing only
`placeholder_art.gd` (for example, `draw_texture` with your sprite sheets).

## Next milestones

4. Vehicles, parts, upgrades, fuel
5. Crafting, decor, storage, land expansion
6. Breeding, greenhouse, rare animal home
7. Shop, tutorial, sound, Play Store release
