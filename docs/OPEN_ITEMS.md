# Open items

Kept in the order we agreed: stress round done first, then visual detail, then the farming-core roadmap.

## Performance (stress round, part 2)
- Draw calls on the max farm: about 2,800 (was 8,000; the woods are baked per area and yard animals thin out
  when zoomed out). Next biggest: buildings (~45 surfaces each); use `tools/perf_probe` census to find them.
- Saving: a queued save now copies the farm (about 11 ms on the full-barn stress farm, was 25) and writes on a thread; pausing/closing still saves before returning.
- Off-screen free animals still think every second frame (cheap); building yards already throttle.
- 2D world in 3D mode: measured at 350 of 7,400 nodes, nothing per frame (the overlay and taps use it), so it stays; revisit only if memory matters.

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
- Vehicles: done: sizes and weights per kind (Combine ~1.9x the Tractor's width, garage doorway fits two at their own sizes), VehicleRun drives the field (wheels and reels turn, springs, dust, smoke, tracks laid lane by lane). The work itself happens as it drives (VehicleWork: each plot is worked, fuel burned and paid for as the vehicle passes it). Not yet: engine sound loop, implements (plow blades, seed drills) and a look pass on the models.
- Decoration detail kit (ridge caps, lanterns).

## Systems
- Save validation (SaveValidator, `add_object` invariants, migrations test).
- CI: fail on import errors, read-only permissions, SHA-pinned actions; README sync; Android export preset.
- HUD split, PlacementSystem, game.gd persistence module.

## Balance (the numbers)
- Done: every number in `data/balance.json` read through `Balance`; weather as steady seasonal spells; `tools/balance_sim.tscn`
  and docs/BALANCE.md (baseline, findings).
- Done: pace retuned to "slower, FarmVille-like" (level 20 in ~14 days at three visits a day, ~28 at one) via
  `economy.level_xp`; the bot buys land, trees and animals and has a per-visit action budget.
- To tune next: the coin sinks (land costs, building prices, crafting) once the bot buys buildings too; coins still pile up.

## Farming core
- Done: feeding (docs/FEEDS_DRAFT.md, approved): `FeedSystem`, five feeds from harvests and trees, tastes, one effect per
  feeding, hunger (-30% coins, never none), the Barn's stock, the farmhand feeds; the action registry
  (data/actions.json) so every action is offered to its helper.
- Postponed by the owner (look at later): quests (data/quests.json: missions across all systems, rewards, the counts ribbons use).
- Layout synergies (AdjacencySystem, data/synergies.json): done for orchards and animal homes (coins). Open: bloom gardens, same-crop plots, crafting beside crops, paths and decor, XP boosts, a tag on the farm outside placing.
- Boosts per home (HomeBoostSystem, data/home_boosts.json): done (feed chance, golden luck). Open: more boost kinds.
- Feed Mill (crafting building, bushels to rich feed, data/catalog recipes `feed_mill_recipes`) and dogs (find family + Dog House; dogs add +3% each to gopher finds, cap 50%) are done; the Nursery already existed. Dogs do not dig up finds of their own; the Feed Mill and Dog House have only code-drawn looks so far.
- Queen Bee is now a find (family `queen_bee` in data/finds.json: conditional trigger, pity, grants a queen to the Barn). Birds and collectibles are still on their own system (own pity, collection book, ribbons); moving them is open.
- Feeding look and feel done: hungry animals wear a bubble, a fed one hops and says what the feed did (tests 185). Done since: the look-test tool (`tools/look_test.tscn`, record in `tests/look_refs.json`) and the central Feedback service (`Feedback`, data/feedback.json). Feeding still needs a balance pass in the simulator (animals and hunger are not in the bot yet).

## Joined structures (fences, hedges, walls, paths)
- The 2D fallback world still draws them as separate straight tiles (no joins); 3D is the real game.
- Hedges sway again (paint3d/canopy3d read each instance's own foot, so MultiMesh pieces sway on their own beats). Gates (a swing gate in a straight run) and tall close-board fences exist as fence styles (`style` in the catalog).
- Not yet: drag to draw a whole line (done for fences, see links tests), the 2D fallback joins, joining to building yards and pens, corner posts shared with neighbouring paths' edges. Old saves keep their `flip` field; it's ignored for these.

## Animal rendering rework (perf probe, 2026-11-12)
Done: animals were already one skinned mesh each; they are now one painted surface (the shared `ModelKit.coat()`; each part's colour and shine ride in its vertex colour and alpha, `paint3d` `shine_in_alpha`) plus the contact shade. Animals went from 3 mesh instances and 4-5 surfaces to 2 and 2; the showcase farm from 3,016 to 2,710 draw calls (animal meshes 576 to 384). Thin parts (legs, ears, tail) now cast a shadow too, so the shadow pass has about 5% more triangles. Open: the contact shades are still one draw per animal; a shared MultiMesh for them would save about 190 more on that farm.

## From the code review (2026-11-12)
Fixed: a signal connected every frame in `AmbientLife`; `day_number()` now turns over at the player's local midnight; animal and tree collects no longer feed the crop collectible pity; clock set back is mended on load (timers shift by the skew); `level()` is cached; saves go through a version chain (`SaveMigrations`); crops rebuild only when something changed (growth drawn in 12 steps); a "while you were away" line (ripened, withered, ready; `AbsenceReport`).
Checked and already fine: loose animals are not animated off screen (`Animal3D.animate` returns early outside the view).
Open: Android local notifications when crops ripen (needs an Android plugin and a permission flow; the away line is the in-game half); crops grown continuously by the shader instead of in steps (custom data is full: colour and richness; needs a second data channel); O(size²) free-tile scans in mass sell (not in the perf probe yet).

## Interface
- Portrait phones: the interface is landscape only for now (docs/UI.md); a portrait layout is a later pass.
- Neighbour bar: a placeholder quick bar until there are neighbours (with the social feature).

## Decorations at scale (measured 2026-11-15 on a 30x30 farm of 16 kinds of decoration; branch `decor-look`)
Done: standalone decorations are drawn in batches (`DecorLayer`: one MultiMesh per part of a look per 12-tile
region; `Instancer.pieces_of` takes a model apart; the grass and stones round each are six shared looks), a plain
decoration's key is made cheaply, a big farm finishes building (the build budget counts building only), and
decorations that never vary are built once, not in eight looks.
Measured, once built (before -> after): 100 decorations 350 -> 170 draws; 300: 1,098 -> 183 draws, 1,786 -> 727
nodes, built in 9.3 s over 48 frames -> 0.3 s in 1; 700: 2,610 -> 433 draws, 4,136 -> 1,696 nodes, 634,000 ->
451,000 triangles, a change on the farm 17.9 -> 9.3 ms of script (the farm's whole budget is 2,250 draws).
Open, in order of what it buys:
- Done since: what one change costs on that 700-decoration farm went from about 40 ms of script to about 8 ms.
  The whole field was laid again after every change (now only the plots whose tile holds something else:
  `Game.tiles_revision`, `objects_updated`), the hidden 2D layer placed and redrew every piece (17 ms -> 2), and
  the ground and the fences looked again though nothing had moved.
- What is left of a change is the 3D layer looking at every thing (4 ms at 700) and the occupancy being rebuilt
  (1.5 ms): to go lower, a change has to name its thing (`objects_changed` carries nothing; things are plain
  dictionaries changed in place in 35 places).
- The timer's look each second at trees and buildings still runs in one frame on this branch (spread over
  frames on `building-look`, not merged).
- A simpler far version of each decoration (they average about 650 triangles and are small on screen zoomed out).
- Trees that are decorations, the bridge, buildings and animals are still a node each; the same layer could draw
  whatever of those stands still.
- Decorations made as files (docs/ASSETS.md), as animals, trees and the farmer are.
## Buildings and their panels (measured on the showcase farm, 2026-11-15; branch `building-look`)
Done: what a change on the farm costs in script time went from about 35 ms to about 8 ms (the hidden 2D layer no
longer places and redraws its pieces in 3D; fences, neighbour masks and the ground's shade are redone only when
something comes, goes or moves); the timer's look each second is spread over frames; a tapped building opens as a
small sheet that is built once and refilled.
Open:
- The full building panel (the sheet's More), and the crafting and Barn panels, are still thrown away and built
  again on every refresh (about 23 ms for a dairy). Make them update in place like the sheet, and restyle them to
  match it.
- The 3D look at everything after a change is still about 7 ms (every thing's key is made again). To cut it further
  the game has to say which thing changed (`objects_changed` carries nothing).
- The 2D layer still keeps a hidden piece per thing (224 on the showcase farm). Removing it altogether touches
  placement and taps.
- The sheet covers the building it is about and overlaps the bottom bars: move the camera so the building sits
  above it. Its Move, Turn and Sell are words, not icons yet.
- Crafting buildings (bakery, winery, spa, feed mill) have the smaller footprint but not yet their own identity
  and countable upgrades.

## Feel (branch `feel-upgrades`)

- Done: a swipe's plots climb a scale and count up over the finger ("x7"); the farmer's jobs of one kind done in a
  row climb the same scale and say their count every fifth (Balance `feel.*`, `Feedback.moment(name, step)`). The
  Next ready button (beside the zoom buttons, with a count) travels to the nearest ready thing not yet shown. While
  you were away is a card of rows that each go to their thing (`AwayCard`, `AbsenceReport.items`). After 20 s with
  no touch the interface fades away until the next touch (`feel.idle_view_seconds`, 0 turns it off).
- Already there before this branch, so not redone: coins and stars fly to the top bar and the coin counter rolls.
- Open: numbered markers on the farmer's queued plots (they are outlined, and a tap takes one back out, but
  carry no number); the streak and the swipe notes have been tested but not heard on a phone; the idle view and
  the camera's journey have not been watched in motion; the away card's "hungry" and "stray" rows use a barn and
  a star for their pictures.

## Seasons, progress and life on the farm (branch `feel-upgrades`)

- Done: seasons on the real calendar by region (`Season`, `data/seasons.json`, Balance `seasons.*`): the monsoon,
  home seasons for every crop, off-season crops sell for more and wither sooner (seed shelf says so), rain waters
  growing crops (+10%), a forecast under the clock, a lawn coloured by the season, the region in Settings.
- Done: a mastered crop's plants stand fuller with a golden cast (the plant's fourth instance value); the farmhouse
  gains a wing, a second storey, then a balcony and flag at the farmer's levels 10, 20 and 35.
- Done: animals sleep at night and a rooster crows at first light on a farm with chickens; a home that eats has
  a feed trough in its yard, full when fed and bare when hungry, and hungry animals look about instead of grazing.
- Open: fruit appearing one piece at a time and falling when picked (trees are drawn from files with a ready and a
  bare look: it needs new tree art); a hungry animal walking to its trough (yard animals stray only a little from
  their place); heads at the windows drooping at night; collections and ribbons shown on the farm (a trophy, a
  plaque); crops looking tired in summer heat; the season's lawn follows a changed region only at the next
  start; the seasons' numbers (1.5x, half the ripe time, +10% for rain, from level 6) are first guesses, not
  yet run through the balance simulation; the weather is the game's own, made from the date, not the real sky.

## Finds, reveals and smooth growth (branch `feel-upgrades`)

- Done: a crop's luck is decided when it is planted and kept with its plot (`FieldSystem._hold_luck`,
  `HarvestDrops.decide_drop`/`give_drop`, `FindsSystem.decide`/`give`); a ripe plot that holds a find glints in its
  rarity's colour (`Glints3D`); every find, on a plot or on a thing, is said by one burst with one colour, size and
  chime per rarity (`Game.found`, `Game.found_on`, `FarmGrid.show_find`, `Feedback.rarity`, data/feedback.json).
- Done: a mystery young one shakes three times and opens into what it was (`Objects3D.hatch`), named in its
  rarity; a Mystery Egg and the Mystery Box open the same way over the panels (`RevealCard`).
- Done: a crop's life is one smooth change: each stage starts at the height the one before ended at, the ripe plant
  is drawn from three-quarters grown with green fruit that colours up, and a ripe crop wilts over the last 40%
  of its time (crop3d). A tree's fruit grows on the tree, one piece at a time, by the farm's clock (fruit3d,
  `Objects3D.ripen`); trees are one model each now, not a bare and a full one.
- Open: a crop left to wither loses what it held, and the luck spent on it is not given back; the withered crop
  is still its own model, taken up at the wilted plant's colour and lowness (a small change, not a blend);
  blooms still change picture when they open and when they wither; picked fruit does not fall and bounce; the
  shake-open of a mystery young one, the glints' twinkle and the reveal have been seen in stills, not in motion;
  in the 2D fallback view (not what ships) there are no glints and a mystery opens at once.

## Blooms and the Bloom Garden (branch `feel-upgrades`)

- Done: each of the six blooms is its own flower (`BloomModel`: a rose's layered cup, a tulip's egg, a daisy's
  rays, a sunflower's disc, a lily's recurved star, an iris's standards and falls), with its own leaves. A bloom
  fills its tile (`data/scale_guide.json`: 0.85-1.1 tiles tall) and is mostly head. A Single Bloom is its
  flower and a smaller one beside it; a Full Bloom is a tall bunch of seven in a rosette of leaves, built to
  stand inside one tile (`FULL_*`), its heads lighter (`_head`'s `light`). Petals and leaves are smooth shared
  blades that carry their own colours: foot to tip, a darker crease or a lighter vein (a tulip's warm foot, a
  lily's pale throat, a sunflower's orange-to-yellow rays, a rose's light rims). A bloom is one surface, one
  draw. Nothing in a flower is ruled: stems are bent tubes, heads look a little their own way, petals and
  leaves each sit, tilt, measure and twist a little differently, a rose's petals follow a spiral, and each flower
  takes its own tone of the kind's colour (`TONES`), which is painted softer than the catalog's (`SOFT`). Light
  wraps round petals and leaves and they never shine (bloom3d's `light`). Its whole life is its shader's (bloom3d): heads start as closed green buds and open at their turn, and
  a Single Bloom left too long yellows, browns and bends over the last 40% of the time it may stand ready. One
  model per bloom, never rebuilt (`Objects3D.ripen`); a garden's blooms are planted once, smaller, as a bed. The
  Bloom Garden has a white picket fence and its arch from the first size.
- Done: blooms are made ahead of time as files like trees (`art/models/blooms/<id>.scn`, four looks each,
  `tools/export_plants`; `Objects3D.bloom_look`): a bloom on its own comes from its file, one crowded by
  neighbours is still built once in code, as a tree is. Ripening and wilting times are a material's own, shared
  by everything on the same cycle (`Objects3D.timed_material`), not per-instance shader values: the renderer
  holds only 4,096 things with those, and CI's screenshot run on a full farm went over it.
- Open: a Bloom Garden's blooms are still built in code, as an Orchard's trees are; petals shade but have no
  speckles (FarmVille's tiger lily); a Full Bloom of
  sunflowers is 2,950 triangles (the heaviest; the test's limit is 3,100); the Bloom Garden's ground is plain soil, with no
  raised beds or paths between rows; only the six flowers the catalog has (FarmVille had dozens).

## Crafting: recipes, pictures and the menu (branch `feel-upgrades`)

- Done, recipes and balance: Bakery, Winery and Spa each have 15 recipes over four stars (4, 4, 4, 3, by what
  they are worth), made only of what the
  first release grows and raises (`data/catalog/recipes.json`); FarmVille's recipes that need other crops are
  kept there as planned, for when those crops come. A new catalog class, Ingredient
  (`data/catalog/ingredients.json`): eggs, milk, goat milk, wool, feathers, truffles, honey, ten orchard fruits
  and five cut flowers, dropped when collecting from animals, the beehive, trees and blooms once you own a
  crafting building (`crafting.produce_chance`), held with the bushels and used by recipes like one. A good's
  price, fuel, XP and time rise with its star (`recipes.markup_per_star`, `fuel_per_recipe_star`,
  `crafting.craft_xp_*`, `craft_hours_by_star`); every star's goods sell for more than any below (tested).
- Done, pictures: every good and every produce is a small 3D model (`GoodsModel`): a good is its recipe's
  `shape` in the colours of what goes into it, produce its own shape; ItemIcons pictures them and the CI baker
  covers them.
- Done, the menu (`HudCrafting`): three tabs, built from the menus' shared pieces (CardList cards, a strip that
  tells about the card picked, `UiKit.count_row`, the panel's buttons). Make: the slots as cards with a bar and
  the time left (kept up to date; a craft that finishes with the panel open lands in Goods), the recipe picked
  (what it gives, each ingredient as have of need, Make or the missing ingredients for gems), every recipe as a
  card (tap to pick), the next star. Goods: the goods as cards; the one picked is sold or used, and Sell all.
  Pantry: what is held, and the Farmers Market as cards (a tap buys one).
- Open: the new numbers (produce chance, markups, craft times) have not been run through the balance bot; the
  feed sacks differ only by colour; goods are only pictures (nothing shows on the building or flies to the
  shelf when a craft is done); the planned FarmVille recipes return with the crops exercise; sunflower blooms
  give no produce (the crop already gives sunflowers); making a recipe is two taps (pick its card, then Make).

## Buildings: the storybook redesign and the building rules (branch `feel-upgrades`)

The rules are in CLAUDE.md (four types: decor, crafting, harvesting, storing). Done for the four crafting
buildings (Feed Mill, Bakery, Winery, Spa), and held by a test (`world3d_test` test_385):

- Four levels, a look each, 1 to 4 slots; the 15 recipes are spread 4, 4, 4, 3 by what they are worth (the Feed
  Mill's ten: 4, 2, 2, 2), and times, prices, XP, fuel and level costs are retuned for four tiers.
- Animated parts 0, 1, 1, 2 by level, moving only while crafting: the mill's sails (level 1's are broken), the
  bakery's oven and roof chimney, the winery's press and tap, the spa's steam and fountain.
- Storage parts 1, 1, 2, 2 with four looks (empty, a quarter, half, full): the mill's silos (a glass up the
  side; a full one runs over), the bakery's and spa's shelves, the winery's casks (kegs drawn off them).
- A maxed building has gold roof edges, a gold band and a gold star (still: only animated parts move).

Open:

- Decor (no upgrades, a yellow light at night), harvesting and storing buildings are not brought under the
  rules yet; the other buildings still have the older shapes.
- The new numbers (four tiers) have not been run through the balance bot.
- A building under construction is drawn as a square frame even when it will be a round tower.
- The moving parts have only been checked in still pictures, not on a phone.
- Animals' walking still looks unconnected to the ground (not started).
