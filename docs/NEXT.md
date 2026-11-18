# Where work stands (handoff for the next session)

Read this, CLAUDE.md, and the design doc "Farm game: buildings, end to end"
(https://claude.ai/artifact/BCxz5VHsfe6G7dSQnHLWsf) before starting. Don't re-read whole files: grep.

## Decided (in the design doc)
FarmVille footprints (with a save migration), FarmVille limits, the 5 planned buildings
(Greenhouse, Windmill, Juice Press, Spinning Mill, Silo) each get a job, materials buyable with gems.

## Done in phase 1
- Sizes are records (`sizes` in buildings.json; BuildingDef: capacity, size_name, size_materials, star_cost).
- `Game.buildings` (scripts/systems/building_system.gd): can_buy / can_expand / can_sell -> Verdict;
  limits (5 Dairy, 3 crafting, 1 of most); buy missing materials with gems. Tests 108-110.

## Done in phase 2 (step 1)
- FarmVille footprints: Coop 3x2, Stable 3x4, Pig Pen 3x4, Bakery/Winery/Spa 4x3, Garden Shed 2x1;
  building_models.json bodies rescaled to keep about the same block in tiles (test 107 passes).
- Save v2 (`SAVE_VERSION 2`, `OLDEST_SAVE_VERSION 1`). `Game.settle_objects()` runs on every load: an
  object that no longer fits moves to the nearest free spot, with message SOME_BUILDINGS_CHANGED_SHAPE_AND
  (appended to absence_note). Test 111 (saving_test.gd) loads a v1 save.
- Known: the 2D placeholder refs (art/refs, drawn by PlaceholderArt into a square diamond) now show the
  3x4 Stable as a long low shed. The 3D model is fine; fix with the phase 3 silhouettes.

## Performance pass (showcase: 175 objects, measured with tools/perf_probe.tscn)
- Draw calls 11,056 -> ~4,000; triangles 2.17M -> 1.58M; CPU 11 -> 7 ms a frame (desktop, headless).
- Painted/patterned parts carry their colour in vertex COLOR and share one white material per shader
  (ModelKit.tinted / tint_arrays; paint3d and wall3d multiply by COLOR), so bake merges a model to a
  draw per shader. Animals are one skinned mesh (Animal3D._skin): part nodes stay as the pose, copied to
  bones; only body and head cast shadows. Animation budget: 16 animals at full rate, then every 2nd-4th
  frame round-robin (Animal3D.animate).
- Game.object_by_uid is a self-checking index (was a scan). Hidden 2D pieces aren't refreshed in 3D.
  Ground3D keeps the meadow's tufts and flowers, writes tufts as one MultiMesh buffer (29 -> 6 ms).
- Tests 112 (draw budgets per model), 113 (uid index). Still to do: shadow quality tiers (2 splits now),
  mesh LOD with a baked-mesh cache (generate_lods is ~12 ms per 15k triangles), first-open time ~0.8 s.

## Next, in order
The full plan is docs/AUDIT.md (every system against FarmVille, and the order of work). Its step 1 comes
first; the buildings items below continue alongside.
1. Market tabs by category (BuildingDef.tab()).
2. Phase 3 of the doc: each building its own silhouette; ready sparkle; broken Barn.
3. The 5 planned buildings, each with a job.

## How to work cheaply
- CI is the compiler: batch changes, push once, wait once (`until gh run list ... grep completed <sha>`).
- Read failures with: gh api .../jobs/<id>/logs | grep -E "  - |checks,|SCRIPT ERROR" | head
- Look at screenshots only when the look changed.

## Branch feel-upgrades (pull request 9, not merged; merging is the owner's call)
- Done: crafting, harvesting and storing buildings as glTF files in one style; VIP on the Barn (docs/VIP.md);
  vehicle rust with its sign and repair bubble (docs/RUST.md); the Barn on 4 by 4 with its badge and a yard
  that grows with VIP; the frame of what a building's next size adds (`BuildingModel._plan`, off for the Barn);
  level-up fireworks (`Fireworks3D`).
- Picked by the owner and in: new looks for the Farmhouse, Log Cabin, Gopher Garden (the burrow hill) and
  Dog House (the bone sign); lighter Barn roofs at VIP 4 to 12.
- Water (docs/WATER.md): the calm, deep look with rain, wind, ice and moonlight; rings; pond life; birds
  that swim and dabble; animals that drink at a trough; a splash where water is tapped.
- Not built: rare-quality crafted goods, rare babies, instant repair with gems (docs/VIP.md, docs/RUST.md);
  the four decor buildings above are still built at run time, not files.
- Not checked: anything on a phone; the economy with VIP on (run the balance bot); a full farm with frames.

## Branch showcase-update (not merged; merging is the owner's call)
- The showcase farm keeps up with the game: every system dresses its own part (`GameSystem.showcase()`: VIP,
  rust and crafting so far), and its card in Settings walks building sizes and the VIP level by hand.
- Still open from the building work: a real phone check, the economy with VIP on (balance bot), a full farm
  with frames, rare-quality crafts, rare babies, instant repair with gems.

## Phone performance (session of 17 Nov 2026): where it stands, and the next step
- Measure as a phone sees it: `xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-method gl_compatibility
  --path . res://tools/perf_probe.tscn -- --quality=low --size=2400x1080 [--tiles=12] [--fill]` (--fill: every
  free tile taken by a few kinds over and over, as players' farms are; ShowcaseFarm.fill).
- Low now drops to models' lighter levels sooner (quality.json low lod_pixels 12). Everything's grass and
  stones (Dressing) is drawn in shared batches by the DecorLayer (`Objects3D._dress`, 2 looks per kind and size).
- Filled farm on low: whole farm 1,787 draws, 890k triangles; a playing view (12 tiles) 1,025 draws, 646k.
  Trees are most of it: 175 trees, 891 draws (about 5 each: one mesh of canopy, foliage, paint and fruit
  surfaces, and one of bark). Animals 276 draws (one each). Decorations, batched: 125 things, 20 draws.
- Next: batch trees (and blooms) through the DecorLayer, as decorations are. The catch is fruit: each tree
  ripens on its own clock (`Objects3D.ripen`, timed copies of the fruit material, `timed_material`), and the
  fruit is a surface inside the canopy mesh. Design to build: when a model is taken apart for batching
  (`Instancer.pieces_of`), split a clocked surface (fruit3d, bloom3d) into its own piece, keeping its levels of
  detail (RenderingServer.mesh_get_surface(...)["lods"] into ArrayMesh.add_surface_from_arrays' lods). Then
  a tree is two batched things: its still parts under its uid, in the look's shared batch; its fruit under a
  second id, in a batch keyed by look and its times rounded to a minute, drawn with the timed material, so a
  row harvested in one sweep shares one. `_ripen_view` re-puts the fruit when the cycle changes. Shake,
  lift (`_show`), drop and outline follow the stand-in as for decorations. Measure with --fill before and after.
- After that: animals (276 draws) as batches, their poses in the shader; the phone budget's limits lowered
  to each new measure (data/perf_budget.json, `_measured`).

## Sound (sound-rain branch, Nov 2026)
- First step for any sound change: `python3 tools/sound_cuts/audit.py` (every file's loudness as a phone or
  laptop speaker plays it, full-range loudness, peak, tone). make_sounds.py / make_generated.py level every file
  by phone loudness per kind (calls, beds, rain, music), cut rumble, round off peaks, cap full-range boom, and
  write data/sound_levels.json; sound_test 106 fails on a file not measured or out of balance, 105 holds the mix
  (background under calls on a clear day; in rain and storms the rain leads, bed and music step back).
- Open: the rain is a light-rain recording; a CC0 heavy-rain one (Freesound 200272, jmbphilmes) would suit storms.

## Flowers (flower-looks, merged 17 Nov)
- The owner found the blooms papery and off the farm's look, and picked the chunky direction from a sheet:
  blades with a body, five stems to a Full Bloom, thick stems, fat leaves, the catalog's colours at full
  strength (`BloomModel`), fatter buds and light at the farm's strength (bloom3d divided by PI).
- Open: the lily is still a thin star; a bed in bud is still mostly stems; not seen on a phone or at dusk.

## Economy (17 Nov 2026): fixed, and open for the owner
- Fixed: decorations give 1 XP per 100 coins like everything (the 5-XP minimum let a buy-and-sell loop pay from
  level 38: coins, gems and VIP without end; economy_test 61 now checks no coin buy can pay for a level); land
  needs its level with gems too (gems skip only the coins).
- VIP's top boost is now x1.5 (owner, 17 Nov); still open: a weekly cap on the points gems buy. The economy pass, in its own
  session with the balance bot: the XP curve after level 20 (now grows 40 a level: L30 on day 37 at three visits, was 34) with unlocks spread
  through 31-40 and a level-up reward that is felt; 8 of the 21 V1 crops never worth planting (bell pepper, corn,
  cotton, pineapple, raspberry, rice, spinach, watermelon: a crop stays ripe as long as it grew, so 24-hour crops
  win), tomato/sugarcane and sunflower/grapes near twins; off-season x1.5 always wins for anyone playing twice a
  day; pony (32-day payback) and chestnut tree (twice the best coin tree); homes earn about twice crops per tile;
  crafting needs about 640 gems (a wall at level 25 on 8-10 free gems a week); before 25 the Mystery Box gives
  about 50 coins a gem against 500-6,000 elsewhere; rust level 1 repair is too cheap to be a decision.
- Also open: rain life (docs/WEATHER.md steps 3-6: puddles, rain creatures, mushrooms, rain rules); tree batching
  (above); building the first hour and goals (docs/PLAYER_EXPERIENCE.md; the owner's five decisions are at its end).

## Animal motion (animal-motion, merged 17 Nov)
- Feet now grip (docs/ART_BIBLE.md, Motion; animals_test 432): ground speed is stride x leg pace in every
  direction, bounds are thrown arcs with a landing, animals turn before they walk, body springs are firmer.
- Not watched in motion yet (measured and tested only): ask for a clip or check on a phone. Animals now walk
  about as fast as they used to up the screen (a cow 0.22 tiles a second), which is twice the old pace across.
- The art tool's own preview walk (tools/animal_art/motion.py `script`) still hops on a sine; only the game changed.

## Feature freeze (owner, 17 Nov 2026): fixing the game
No new features until the game is fixed. Done: landscape only on phones (the portrait screen broke the panels),
the mailbox opens the inbox, Next ready button off (v1.json `next_ready`), hens peck slower and ducks stay tipped
under while feeding, yard animals keep off the walls' stone footing.
Open, from the owner's play on a phone (each a look: show a sheet of options first):
- Inbox button: done, the red-seal envelope (owner picked B).
- The pink ready triangles over everything on the farm: owner asked to turn "the pink triangle" off; the button
  is off, ask whether the marks over animals and trees go too.
- Animals still seen overlapping buildings? (the footing was the measured clash; check a pen close up).
- Yards: done, the lawn inside the fence with a trodden path gate to door (owner picked A).
- Farmer face: done, button eyes and an open smile (owner picked D).
- Ground: done, mown stripes (owner picked C) and no grass clumps (D); ready sign: the pink pin (C).

## Polish loop (hourly runs, 18 Nov 2026; log: the Claude doc "Farm game: polish loop log")
- Run 1 (economy audit): the rescue now also covers a farm with a seed's coins but not the plow's and nothing
  plowed (it was stuck for good). Findings ranked in the log's backlog; next: progression audit or the top item.
- Run 2 (progression): levels past the table (21+) each need 40 XP more than the last (was a flat 1,000), so
  levels no longer speed up as the farm grows. Still open: unlocks spread through 31-40, a level-up reward felt.
- Run 3 (progression audit): 17 of the V1 level-ups 2-40 unlock nothing (reported to the owner in the log).
- Run 4: level reward coins in data (economy.coins_per_level), unlocks_at built on unlock_ids_at; the
  engine-hum test (vehicle_motion test_206) no longer fails when another test left a loop running, so the local
  precheck passes on a 2-core container. Next: an audit of phone UI (every third run) or the economy's open items.
- Run 5 (phone UI, measured with the menu sweep): Move, Sell, search chips, choice pills and switches drew only
  as tall as their words (29 units, under 3 mm on a phone); now every one is at least panel_button_height
  (`UiKit.tappable`) and menus_test checks every button. Open: 40 units is still about 4 mm on a 20:9 phone
  against a 7 mm finger (the shared panel button size: the owner's call). Next run: a full audit (run 6).
- Run 6 (edge cases, clock set back): load already shifted objects' "t" and plots, but crafting slots, pig
  forage, bunch ends, fuel refill, VIP time, rust/repairs, strays, pollination and clear weather waited the
  hour on top (active VIP gained it). Now `GameSystem.shift_clock(seconds)` per system (test 436); a new timer
  in a system adds itself there. Social's last_settled stays forward-only on purpose. Open in edge cases: a full
  Barn and inbox, long offline, a crammed farm. Next: fix the next ready item, or audit cheating (run 9).
- Run 7 (phone UI, panels off the screen): menus_test now fails a panel or sheet that runs off the screen (the
  sheet swept where it rests, after `BuildingSheet.SLIDE`). Found: a full orchard's sheet (every kind inside as
  pictures) was 789 tall on a 720 screen, its head cut off; who lives inside now scrolls past `INSIDE_SHARE`
  of the screen. Local precheck: the search budget test (387) can flake at ~4 ms in a 2-core container; rerun.
- Run 8 (edge cases, a full Barn): a thing from the farm waiting in the inbox (a grown baby, a prize) could
  not be placed while the Barn was full: Place said "Barn full" though it goes straight onto the farm. Now
  `SocialSystem.claim(id, to_place)` holds it one past the Barn's space for the hand; an emptied hand
  (`Placement.cancel`) gives it back to the inbox through `spill_over` (test 19). Open in edge cases: long
  offline (weeks), a crammed farm. Next: audit cheating and save safety (run 9).
- Run 9 (cheating and save safety audit): only the top-level counts were guarded; every saved count map
  (bushels, goods, feed, eggs, collectibles, mastery, supplies, parts...) and five system counts (queen bees,
  truffles, fuel, fuel tanks, daily streak) loaded a negative value as is, a nested value crashed the system's
  load, and a broken Barn entry crashed it. Now `GameSystem.int_map` drops a negative or unreadable entry,
  `SaveCheck.COUNTS` covers the five, and SaveCheck mends "stored" (uids unique with the farm's) (test 437).
  Open: a clock set forward finishes every timer (offline play cannot tell it apart: report, not a fix); the
  save has no checksum, so hand-editing coins up is possible (an owner's call: cheap HMAC, easy to bypass).
- Run 10 (last run; cheating: buy-and-sell loops): selling gives 5% back (gem items 50 coins a gem, and
  gems can't be bought with coins), so no buy-and-sell loop; but the out-of-coins rescue could be farmed:
  spend the 50 on a decoration, reopen, rescued again, for ever. Now `Game.rescued` (saved) holds the next
  rescue until a harvest or a collect (test 438). The loop ended at 08:15 IST; its backlog stays in the log
  doc (open: long offline weeks, a crammed farm, the economy items, unlocks through 31-40, code quality,
  whole-farm look, motion, sound).
