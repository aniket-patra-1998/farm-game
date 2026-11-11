# System audit: what FarmVille had, what we have, what's missing

Goal, in order: (1) every system an exact replica of FarmVille's, built in depth, and the whole game
hyper-optimised to run smoothly on low-end phones; (2) then make each better, clearly marked.
The social side (neighbours, gifts, requests, quests: 8-10) waits for the social feature. Until then, what
FarmVille got from friends (building materials, help raising barns and vehicles, adopting strays) comes from
materials/parts found while farming or bought with gems; when friends arrive they replace those, since in
FarmVille more active friends meant faster building.
Base is FarmVille (2009-2012, "FV1"). Where the owner asked for a FarmVille 2 system (water, animal feed),
it's marked FV2 and adapted to FV1's look and pace. Status: done / partial / missing / broken.
Each system lands with rule tests, its UI reachable from the HUD, its 3D look, and save support.

## 1. Player (partial)
FarmVille's farmer was the player's face and hands.
- done: **PlayerSystem** (Game.player) — the action queue: every plow, plant, harvest, fertilize, collect
  and vehicle pass is queued; the farmer walks to each (A* round whatever stands on the farm), works for
  ACTION_SECONDS, and the job happens and is paid for then. Boxed in, they work from where they stand
  (FarmVille's fenced-in farmer). Queue limit, one job per plot/object, coins committed so a queued job
  never fails for money; tapping a queued plot cancels it (ours: FarmVille had no cancel). Queued plots
  are highlighted. Farmer name, farm name, look and position are saved; the queue is not (tests 117-119).
- done: **Farmer3D** — the avatar in overalls and straw hat, built from `look`, walking and working.
  (The 2D fallback world shows the queue's highlights but no farmer.)
- tunable: WALK_SPEED 4.5 tiles/s, ACTION_SECONDS 0.75 (PlayerSystem).
- **missing: customisation** (FarmVille's "Character Customization"): male/female; skin, hair (style and
  colour), eyes, facial hair; clothing slots shirt, bottoms, shoes, hat, costume; owned items in a wardrobe,
  new ones in the market (coins or gems); ribbon "Looking Fresh". `look` and Farmer3D.rebuild are ready
  for it.
- **missing: profile**: naming the farmer and the farm (shown on the sign), a stats page.
- missing: a progress bar over the job in hand; tools in the farmer's hands (hoe, seed bag, scythe).

## 2. Plots and crops (partial)
- done: plow, plant, grow, ripen, wither, unwither, fertilize, harvest, mastery stars, collectibles,
  farmhands, golden/super harvests, vehicles over areas, seasons and weather.
- done: **delete a plot** — the sell tool returns any plot to grass, free; a crop on it is lost after a
  second tap (Game.clear_plot, test 114).
- **missing: delete a crop** without plowing again (confirm), and **re-plow withered** in one step exists.
- missing: crop **watering** (FV2, see 6).
- missing: **seed packages / crop events** (limited-time crops); low priority.

## 3. Animals on the farm vs in homes (partial)
FarmVille: a loose animal is harvested on its own timer (cows milk, chickens eggs, sheep wool) for coins and a
chance of items; once ready it shows a sparkle; tapping it plays a harvest animation. Housed, animals no
longer harvest one by one: the building fills toward its capacity and is harvested as one (all the animals'
produce at once, plus building bonuses: babies in the Horse Stable/Nursery, Mystery Eggs from the Coop,
shared items for neighbours); a building harvests only when "ready" (its own timer); animals in it are
shown in its yard.
- done: homes by kind (housing_system), building fill and collect, babies and grow-ups, yards showing them.
- done: harvesting follows FarmVille — collecting an animal or tree (loose or in its home) pays coins and
  mastery, never XP (XP came once, on buying); a home pays for everyone in it on its own timer, plus its
  bonuses. **Mastery for every producer** (MasterySystem: crops, trees, animals; a home's harvest counts
  each one inside; stars per cycle; mastery sign for any mastered item; test 116).
- **missing (FV2, owner asked): feeding** — animals in pens and homes need feed to produce:
  - each home is a class with its own rules: what it holds, which feed it eats, how much per animal per
    cycle, what it produces, its by-products (manure -> fertilizer, feathers, wool), its upgrades (capacity,
    feed trough size, auto-feeder at top size);
  - **Feed Mill** building: turns crops (bushels or harvested crops) into feeds: chicken feed, cow feed,
    pig feed (slop), horse feed (oats/carrots), sheep/goat feed; upgrades: speed and slots;
  - harvesting a home returns some feed ingredients/by-products (the owner remembered harvest giving feed);
  - unfed animals don't produce (no penalty beyond that; FarmVille never let animals die).
- partial: Pig Pen slop and truffles exist (pig_pen_system) — becomes one case of the general feeding system.

## 4. Strays and lost animals (partial)
FarmVille: a lost animal wanders onto the farm; you can help it or turn it away (it goes to a neighbour); to
keep it you had to care for it within a time limit (the owner remembers 24 hours, feeding it and asking
friends to help); if the time runs out it wanders off.
- done: strays appear and are adopted with one tap (stray_system).
- **missing: the adoption task** — a 24-hour timer shown on the animal; it needs N feedings (feed from the
  Feed Mill or bushels) and N helps; turning it away; running off when time's up. Until the social
  feature, the helps are items found while farming (or gems), like building parts; then friends.

## 5. Buildings (partial; see docs/NEXT.md and the buildings design doc)
- done: buying, construction with materials, sizes/upgrades, limits, FarmVille footprints, crafting.
- next: market tabs, own silhouettes, ready sparkle, broken Barn look; the 5 planned buildings with jobs
  (Greenhouse, Windmill, Juice Press, Spinning Mill, Silo); **Feed Mill** (3) and **Water Well** (6) join them.

## 6. Water (FV2, owner asked: missing)
FarmVille 2: crops need watering after planting; water comes from a Well that refills over time; the Well
upgrades (capacity and refill rate); friends can send water; a few crops/trees need more.
- adapted plan: the Water Well becomes a building (not only decoration): stores water up to its capacity,
  refills per hour, upgrades through sizes with materials; watering a planted plot (tool, or the farmer's
  queue) speeds growth / is needed before it grows (decide in design: FV2 required it); trees watered for
  bonus fruit; sprinklers as a later upgrade. Keep FV1's pace: watering is one tap per plot, vehicles can
  water areas (a water tank vehicle).

## 7. Decorations (broken/bland)
- started: DecorMotion (GPU-animated effects, no script per frame): the fountain's jet and cascade, the
  bonfire's flames and embers, rippling water everywhere, smoke from every chimney; one global wind (set by
  the weather) bends crops, grass, every tree (fruit, decorative, the woods), scarecrows, flower beds,
  hedges (paint3d sway: no extra draw) (test 115). Lamps already glow at night. Orbit effects (orbit3d): a bird circling
  each birdhouse, ducks paddling on every pond (decor and the duck pond yard), the well's bucket bobbing,
  weathervanes swinging with the wind. Still to animate: the Windmill when it's built.
- **missing: animation** on every decoration. FarmVille's decorations moved: fountains spray and ripple,
  windmills turn, bonfires flicker and smoke, lamp posts glow at night, flags and scarecrows sway in wind,
  birdhouses have birds coming and going, ponds ripple with ducks, wishing well bucket bobs, gnomes blink.
  Plan: a DecorMotion component (like BuildingFill) driven by data (data/decor_motion.json): jets
  (particles), spin, sway with wind, flicker, glow at night, ripple shader on water.
- fixed: llamas/alpacas read as poles (thin vertical neck: rig proportions); the arch door was a grey disc
  over the door; fountain water flickered against its stone (z-fighting). Checked: every decoration and every
  building size stays inside its footprint (the long brown strip is the farm slab's edge, by design).
- contact sheet (tools/contact_sheet.tscn) reviewed: animals stood head- or tail-on (read as poles from
  above) — they now settle side-on in FarmVille's three-quarter view; troughs (decor and building yards)
  were solid boxes hiding their water — now hollow (ModelKit.tub); the birdbath's water sat inside its
  bowl; the haystack was an egg sunk in the ground — now a stack; ripe trees hid their fruit inside the
  leaves — now on the canopy's skin; the belted cow's belt was a hairline.

## 8. Market, gifts and inventory (partial)
- done: market by item, barn storage, garden shed bunches, mystery eggs/box, building materials.
- missing: **Gift Box** (gifts received from neighbours and events, placed from there), **market tabs**
  (planned), **limited-time items**, **Farm Cash-only items** shown as such.

## 9. Neighbours (missing; FarmVille's core social loop, single-player here)
FarmVille: neighbours visit (fertilize crops, feed chickens, scare crows, unwither), send gifts and building
materials, answer requests (help raise a barn, adopt a stray), co-op jobs.
- plan: simulated neighbours (NPC farmers with names, avatars and farms of their own, levels rising over
  time): daily visits that do 5 helpful actions, a daily free gift you can claim/send back, requests you
  post (materials, stray help, water) answered within hours, visits to their farms to help them for coins
  and XP. Clearly marked "our touch" where it can't be literal.

## 10. Goals and quests (missing beyond the tutorial)
FarmVille: quest chains from characters ("Goals"), each with 3 tasks and rewards, seasonal chains.
- plan: data-driven quest chains (data/quests.json), quest givers on the left of the screen, tasks counted
  from the same stats ribbons use.

## 11. Core quality (engineering)
- game.gd is ~1,400 lines: plots/crops and objects/placement are still in it; move each into a system
  (PlotSystem, PlacementSystem) like the others, game.gd keeping only shared state and signals.
- objects is a public array mutated by 15 places; route through add/remove so systems and views are told
  (object_by_uid is indexed now and self-checks; signals are still manual).
- every system: rules in the system, numbers as constants or data, player text in strings.csv, tests per
  rule; review each against REVIEW.md as it's touched.

## Order of work
1. Basics and broken: delete plot/crop (2), broken pieces (7), decoration motion (7), loose-vs-housed
   harvest audit (3).
2. Player module (1): avatar model and walk, action queue, customisation and wardrobe, profile.
3. Animal husbandry (3): home classes, Feed Mill and feeds, feeding, by-products; strays' adoption task (4).
4. Water (6): Well building, watering, upgrades.
5. Buildings plan (5) continues alongside: tabs, silhouettes, the 5 planned buildings.
6. Engineering (11) and performance for low-end phones, throughout: every system measured on the showcase
   farm (tools/perf_probe.tscn) and kept inside draw and frame budgets (tests).
Later, with the social feature: neighbours (9), Gift Box (8), quests (10), and friends replacing parts.
Then step 2: make each system better.
