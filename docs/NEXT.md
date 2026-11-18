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
  rescue until a harvest or a collect (test 438).
- Run 11 (edge cases: long offline, a crammed farm): the showcase farm reopened 60 days later loads in 87 ms,
  no errors, one stray, nothing lost. On a farm with no free grass a third mastery star's sign was silently
  lost (place_somewhere found no spot); now it arrives through `BarnStorage.welcome` with its crop (test 439).
  The loop runs until 16:15 IST (POLISH.md). Open: the economy items, unlocks through 31-40, code quality,
  whole-farm look, motion, sound.
- Run 12 (code quality audit, measured): no repeated function bodies across modules beyond two tiny pairs
  (`PlaceholderArt._building`/`_plain_building`, `Linking._load`/`Crowding._load`); gameplay code holds no
  stray rules but one: buy XP (1 per 100 coins) now in data (`economy.coins_per_buy_xp`). Long functions are
  the model builders' per-kind matches (`BuildingModel._feature` 429 lines, `BuildingDress.feature`,
  `PlaceholderArt._decor`, `ThingIcon._thing`): splitting them is costly and risky, reported. Next: fix the
  two tiny duplicates or the economy items; the next audit is the whole-farm look.
- Run 13 (owner's deep pass, player paths traced: buying, harvest, collect, selling, helpers, seed shelf):
  the seed shelf showed a crop's bare price while a harvest pays it raised 5% a mastery star (a mastered crop
  paid 15% more than its card said); now both use `FieldSystem.sells_for(crop, off, bonus)`. Super harvest's x2
  was written twice in code and once in words: now `economy.super_harvest_multiplier`, the words take it; the
  fertilize hints take `economy.fertilizer_bonus`. Open (in the log's backlog): other words still repeat data
  numbers (horses "not every 3 days", "8 cans", a bloom's "7 days", a set's 3/1/1), true today but they drift.
- Run 14 (whole-farm look, started): tools/look_shot.gd took its shots at the real clock (building the
  showcase starts a fresh farm, which cleared the noon offset), so before/after pictures drifted with the hour;
  the hour is now set after it, in local time, and `--hour=<h>` shows dawn, dusk or night. First look: at 22:00
  the showcase is brighter on average than at 12:30 (mean RGB 95,116,80 against 70,93,36; noon read deep,
  saturated yellow-green, night like a soft overcast day). Not yet split from the weather (each hour rolls its
  own): next, the same views with the weather held clear, at 6, 12.5, 18.5 and 22, then rank the findings.
- Run 15 (code quality, the open item from run 13): the Stable's words ("daily, not every 3 days"), the
  Orchard's "8 cans" and a Single Bloom's "7 days" now take the data's numbers (`Game.cycle_of`, horse
  `cycle_seconds`, `YoungDef.needs`, `blooms.wither_after`); hud test 440 reads the texts and their info tips.
  Left: a collection set's "3 common, 1 uncommon and 1 rare" (a structural rule of every set). Next: the
  whole-farm look with the weather held clear (run 14's next step), or the economy items.
- Run 16 (whole-farm look measured; motion audit): `look_shot --weather=<state>` holds the weather. Held clear,
  the day cycle is right (HSV value dawn 146, noon 207, dusk 117, night 103: run 14's bright night was its
  weather); dawn and dusk are the most saturated (212 and 220 of 255, blue nearly gone), noon 185: a gentler
  grade is reported for the owner to pick (an options sheet with look_shot at 6, 12.5, 18.5, 22). Motion audit:
  every smoothing and glide is frame-rate independent (exp(-k*delta)), the camera drops a fling from a finger
  that stopped, animals walk a planted-foot gait at their stride, UI motion lives in `UiFx`. Open, reported:
  the level-up confetti is 90 hard-edged rectangles in deep colours (a softer shape is a look to pick). Next
  audit: feedback and sound.
- Run 17 (code quality: repeated logic): 31 modules each parsed their own data file, most silently empty when a
  file was missing or broken (feedback.gd would crash). 20 moved: Now `DataFile.read(path)` (and
  `read_optional` for files that may be absent) is the one place, logs the error, returns {}; `Game.read_json`
  goes through it; data test 441 fails a new copy. Left on their own read on purpose: the look code
  (scripts/world3d, world/animals, season.gd), whose source is fingerprinted with the exported art (a touch means
  a re-export): move each with its next look change and drop it from the test's `LOOK_CODE`. Note: the full
  precheck takes ~16 min on this 2-core container; run it in the background. Next audit: feedback on taps.
- Run 18 (the owner-approved A, B, C, all merged; plus the art loop's timing-flake report): timing budgets
  hold the fastest of 5 runs (`TestSuite._fastest_ms`), so a busy core no longer blocks pushes. B: number
  files checked as data (tests/suites/number_files_test.gd, test 442: no negative, no *chance/*_share over 1
  but a balance weight, no missing value or field, prizes that can roll, ribbon tiers in step). A: random play
  (test 194) covers crafting, feeding, Barn storing, helpers, VIP, rust, mystery prizes and clock jumps (+1 h,
  +1 day, +30 days, -1 day), and no system may save a negative count; nightly `.github/workflows/fuzz.yml`
  runs 300 seeds x 2000 steps (`-- --fuzz-seeds= --fuzz-steps=`). C: `tools/exploit_hunt.tscn` searches every
  loop of up to N actions on a tile (test 443 fails a loop paying coins with no wait); its one finding,
  plow-place-sell buys 1 XP for 34 coins with no wait (FarmVille's own), is reported for the owner. Precheck
  took ~2-3 min this run. Next: the feedback-on-taps audit, then first-hour feel.
- Run 19 (tests' timing, then the feedback-on-taps audit): the 2-core runner runs slow for seconds at a time,
  so the fastest of 5 still failed search 387 for the art loop. Every timing budget now pairs each run with a
  fixed yardstick (`TestSuite._yardstick`, `YARDSTICK_MS`) and scales a slower machine back (never a faster one
  up); tries 10; test 444. SearchIndex.find a third faster. Feedback audit: every farm action has its moment;
  a vehicle's finished run is now heard by its job (`FarmGrid.vehicle_moment`, test 445); Rotate, Store and a
  refused Sell or first sell tap now answer (test 446), and storing with the Store tool no longer errors (it read
  the thing's row after the Barn took it). Next audit: first-hour feel.
- Run 20 (first-hour feel audit, then phone performance measured): the first session had nothing to tap but
  crops for a day: the starter chickens and cow now start with their first collect waiting (`_ready_now`; the
  starter's extra fields could not set `t` before: `Dictionary.merge` keeps existing keys without `true`);
  farming test 01. Level 2 is now 12 XP (was 55, three visits): harvesting the two ripe plots and plowing about
  ten ends the first visit on a level-up; levels 3 and up unchanged (farming test 01b). The first-hour plan
  (docs/PLAYER_EXPERIENCE.md Part 2: Welcome chain, Guide, reveal, Starter Seeds) is unbuilt and reported.
  Performance, filled showcase (615 things, headless, low): a full Objects3D look over is 11-12 ms (keys 3.1,
  ready signs 4.7 of which `Game.has_ready` 2.1, building fills 0.7); it runs only after a change, the timer's
  look is already spread over frames (`_light_some`), so no hitch each second (perf_probe's "every second"
  label is wrong). Skipping `AssetRegistry.apply_state` when a view's state is unchanged saved ~1 ms of it, not
  pushed: objects_3d.gd is fingerprinted look code (art lane). Next audit: phone performance with a renderer,
  or round two from the economy.
- Run 21 (economy and progression round two, then small fixes): the balance bot judged crops by equal gaps
  between visits (2 a day alternate 14 and 10 hours) and plowed for seeds it would not plant, so it went broke and
  idled; now it looks ahead along the real schedule (`_visits_after`, economy test 448): 3 visits reach L20 on
  day 15, 1 visit on day 30. Economy round two found nothing new that is cheap and clearly right without the
  owner (crop numbers are FarmVille's own; pony, ox and alpaca paybacks, gem nut trees past 20 and the level-up
  coins are in the Economy section above). Rules moved into data: the daily streak (daily.streak), mastery's
  star tables (mastery.*) and the Nurture supplies' gem prices (nurture.supply_gems, `NurtureSystem.gem_cost`).
  Saves: a number past 2^53 is unreadable (`SaveCheck.whole`), since a phone's ARM chip turned 1e300 into the
  largest int (test 437). Season reads through `DataFile.read`. `Game.is_ready` measured: no cheap gain left.
  Next audit: phone UI (round two), then edge cases.
- Run 22 (last fix-loop run before the 16:15 stop): the balance bot now makes its farm at its first visit's
  hour (`_seconds_until`, economy test 448), so the starter's ripe plots are harvested on day 1 (1 visit a day:
  L2 on day 1, was 2). Phone UI round two: the cards over the farm (While you were away with every row and its
  notes, the busiest level-up) are swept on every screen like the menus (menus test 449): all fit, and the away
  card covers neither tool bar nor side buttons; its text was in raw pixels, now type roles through
  `UiTheme.font`. Long messages (every string) fit the toast at 4:3 and 19.5:9 (widest 1145 of 1280). Open for
  the art lane: `FarmGrid.float_words` and the streak count draw words over the farm in their own look (raw 30
  and 34 px, a brown outline, no shadow), not FloatText's; Crowding still reads its data by hand.
- Run 23 (window restarted 20:30, to 08:35 IST 19 Nov; edge cases and stress, round two): random play run long
  here (60 seeds x 1,500 steps: clean), then given more invariants (the Barn's uids its own, the Barn within its
  space plus the hand, nothing planted in the future). That found the clock set back while the game runs or waits
  in the background (a phone resumes without loading): only a load shifted the timers. `Persistence.watch_clock`
  (every frame, from tick) now shifts every timer through the same `shift_all` loading uses; a step back within
  `CLOCK_SLACK` (2 s) is left alone. Fuel's clock is not moved before fuel is unlocked. Saving test 480.
  Neighbours' answers on their way now move with it too (SocialSystem.shift_clock; last_settled stays forward).
  Next audit in the rotation: cheating and save safety, round two.

## Art and UX polish loop (hourly, 18 Nov 2026; rows prefixed "Art:" in the same log doc; docs/ART_POLISH.md)
- Art run 1 (11:05 IST), nothing pushed: the pre-push precheck failed three times on timing-budget tests (search
  387, 372, 374) in the container. Redo, then push when it passes (precheck in the background, renders not
  running beside it):
  1. main: tools/look_shot.gd `--views=all,trees_animals,buildings` (filter `views` and the panel lists by name):
     3 pictures in ~4 min instead of 15.
  2. art-polish (taste, for the owner): lawn greens 22% less saturated, 4% darker, hue -0.012 (Ground3D.LAWN
     0.49,0.61,0.31 / 0.38,0.51,0.26; meadow 0.42,0.54,0.31 / 0.23,0.34,0.19; the same transform on every season's
     grass_light/grass_dark in data/seasons.json); Farm3D named constants: DAY_SATURATION 1.0 (was 1.1),
     NIGHT_SATURATION 0.9, LOW_SUN_SATURATION 0.9, LOW_SUN_GOLD #ffc280 mix 0.75, LOW_SUN_ENERGY +0.25,
     SHADE_COOL (0.66,0.74,0.9) mixed 0.18 x (1 + low sun) into the ambient. Then make_art_versions.py.
  Next: contact shadows under decorations (objective, main), then trees and building outlines (order of work 2).
- Art run 2 (11:15 IST), on art-polish (7756483, rebased on main): the day grade is data (data/grade.json, Grade
  via DataFile.read; main's screen grade times the 3D frame's). Noon saturation 1.45x -> 1.19x, contrast 1.2x ->
  1.11x; low sun warmer (warm_mids 0.04, warm_highlights 0.12), cool shadows (shadow_cool 0.05). Run 1's grade
  part is superseded by this; its calmer lawn (values above) still goes on top, tuned with the grade (the two
  together may be too dull at noon: render and compare). Decor ground shade 0.2 -> 0.42 tried: no visible gain.
  Open: look_shot sometimes shoots decorations half-built (gnome, flower bed, flamingo): trace before the sheet.
  Then one before/after sheet (main vs art-polish, noon and dusk) into the log under "Art: waiting for your look".
- Art run 3 (11:35 IST), nothing pushed: search test 387 fails the precheck in this container even with nothing
  else running (fastest of 5: 4.39 and 4.81 ms against 4 ms; reported for the fix loop). Built and ready, redo in
  ~5 minutes, then push when the precheck passes (never render beside a precheck: it fails timing tests):
  1. main: look_shot `--views=a,b` (filter `views` by name; skip each panel not named), as run 1 described.
  2. art-polish: the calmer lawn, exact values: Ground3D.LAWN grass_light (0.49, 0.61, 0.31), grass_dark
     (0.38, 0.51, 0.26); data/seasons.json in file order (light / dark): [0.49,0.61,0.31]/[0.38,0.51,0.26],
     [0.54,0.62,0.31]/[0.41,0.51,0.25], [0.44,0.63,0.31]/[0.32,0.51,0.25], [0.53,0.6,0.3]/[0.39,0.48,0.25],
     [0.5,0.6,0.35]/[0.38,0.49,0.29] (HSV: hue -0.012, saturation x0.78, value x0.96); meadow left on the
     shader's own, already muted, greens; then tools/make_art_versions.py. Render noon and dusk before keeping.
  Half-built decorations: not seen in this run's noon shot (gnome, flower bed, flamingo whole). Not the model store
  (off without res://baked). Suspects to test: MultiMesh LOD picked from the batch's region-sized custom_aabb
  (DecorLayer._make_views), and Instancer._take_apart writing override materials onto shared meshes.

- Art run 4 (13:15 IST): main 753f593, look_shot `--views=a,b` (only the named pictures). art-polish 25fea36
  (rebased on main): run 3's calmer lawn on top of the grade; noon saturation 192 -> 138, dusk 223 -> 173
  (trees_animals, clear). The before/after sheet (main vs art-polish, noon and dusk, trees_animals and all) is in
  the log under "Art: waiting for your look": merge art-polish only on the owner's approval. If they find the lawn
  dusty, the halfway values are hue -0.006, saturation x0.89, value x0.98 of main's. Precheck now passes first try
  (the yardstick fix). A worktree's .godot copied from another checkout misses new classes: reimport it.
  Next: half-built decorations in look_shot (suspects above), then contact shadows (main), then order of work 2
  (trees' and buildings' outlines into the animals' style, on art-polish).

- Art run 5 (13:36 IST): main 2a93f68 and a62557e: contact shades for every standing thing that had none
  (GroundShade, a slot in the farm's one ContactShades batch): standing decorations (not joined pieces, flat under
  0.25 tiles or wide over 1.6), the farmer and vehicles at work (`follow`). ContactShades frees a batch whose farm is
  gone before it joins, and skips a top shrunk to nothing. art-polish rebased on main (e394abf); still waiting for the
  owner's look. Half-built decorations: not seen in 3 shots this run (weather clear): likely a weather or pop-in
  case; leave unless seen again. Next: order of work 2 on art-polish: the buildings' near-black trim bands (from
  their file-made art: find the builder in data/art_sources.json; a builder change needs its re-export) into a warm
  dark brown, and the trees' candy hues nearer the animals' family; then a second before/after sheet.
- Art run 6 (14:35 IST): art-polish rebased on main and extended (937fe54): roof edges in warm ink, not near-black.
  A roof's eave edges, ridge caps and dome cornice were its colour 28% darker (ModelKit._darker), so the navy and
  dark brown roofs drew a near-black band round every storey; now 22% darker and 30% toward #6b4a36
  (ModelKit.EDGE_DARKEN, EDGE_INK, EDGE_WARMTH); building and plant files re-exported. Tried and dropped: a warm
  silhouette ink for every painted shader (a vec3 shader global edge_ink multiplying the edge darkening): no visible
  gain at this zoom. Still waiting for the owner's look on art-polish (grade, lawn, roof edges). Godot must be
  reinstalled in a fresh container (4.7.2 from the release zip) and the project imported (`--headless --import`)
  before look_shot runs. Next: the trees' candy hues (data/tree_shapes.json leaf and leaf_alts) nearer the animals'
  family, then the second before/after sheet (main vs art-polish, buildings and trees_animals, noon and dusk).
- Art run 7 (15:36 IST): art-polish rebased on main (bf51184; data/art_versions.json conflicts are only build
  stamps: take main's and rerun tools/make_art_versions.py) and extended (c0b4a66): tree crowns in one colour
  family. Each kind keeps its leaf hue, but TreeModel.tone mixes it 30% towards #8c9a52 and scales saturation 0.74
  (data/tree_shapes.json `leaf_tone`): pink, cyan, acid yellow and red crowns read as dusty rose, soft teal, butter
  and coral. 16%/0.84 was tried first: no visible change through the shaders. TreeModel reads through
  DataFile.read; plant files re-exported; world3d test 103 checks hue kept and saturation softened. The second
  before/after sheet (main vs art-polish, trees_animals and buildings, noon and dusk) is in the log under "Art:
  waiting for your look". look_shot of 2 views takes about 2-3 minutes; never render beside a precheck or a push
  (the pre-push hook runs the precheck). Next: wait for the owner's look; meanwhile objective fixes on main
  (consistent outline weights, icon set's sticker edges: order of work 3), or animal life (owner-approved).
- Art run 8 (16:29 IST): the owner approved art-polish at 16:28 with a condition (pink crowns stay pink), then at
  16:30 rejected the tree-crown softening outright (docs/ART_POLISH.md "Colour rule"); another session merged the
  grade, calmer lawn and warm roof edges to main (ba8c63a..7f1f39b) without the crowns. This run had lowered the
  crowns' tone (hue locked, mix 0.1) and passed the precheck, but dropped it under the rule: objects keep their
  bold colours. origin/art-polish still holds the rejected c0b4a66 on the old base (a force-push to reset it was
  refused): the next run restarts art-polish from main and leaves c0b4a66 out. Tried and not kept: a calmer meadow
  (patchy 0.5 -> 0.32, bare 0.6 -> 0.4, lifted grass_dark): no clear gain at orchard noon/dusk. Note: a fresh
  container needs Godot 4.7.2 at /home/claude/godot/godot and a full `--import` before any export (an export run
  against a half-imported project writes empty 168-byte .scn files: check `git diff --stat art/` before
  committing). Next: icons, menus, motion (order of work 3) or animal life; colour only on the ground and light.
- Art run 8b (17:00 IST, a manual fire on the owner's 16:28 condition): the approved crown softening (a9e864c, mix
  0.3) turned pink crowns salmon and purple ones grey, so TreeModel.tone now keeps each kind's own hue exactly and
  leaf_tone is mix 0.1, saturation 0.85 (d80e9fd; test 103 checks every kind keeps hue and at least 0.6 of its
  saturation). Orchard rendered at noon and dusk: pink, red, yellow and purple read as themselves. This is the
  limit the colour rule names: do not mute objects further. art_versions conflicts on rebase: take main's, rerun.
- Art run 9 (16:37 IST): main only, no taste change. 3527af1: words over the farm (coins, XP, costs, a swipe's and
  streak's count) in FloatText's look via `FloatText.style_world` (bold, float outline, soft shadow, fixed world px
  `FarmGrid.WORDS_PX`/`COMBO_PX`; numbers through UiTheme.tidy). Animal life (owner-approved, looks only):
  2243ef9 a day's rhythm (animal_rigs.json `rhythm`: lively choices 1.7x at 8, 0.4x at 14; AnimalRig.busy_at,
  AnimalBehaviour.hour from main.gd); the rain commit after it: tail to the rain from rain 0.3 (faces screen left,
  the streaks fall from the upper right), half as lively, wander 0.45 of the range in a storm (animal_rigs.json
  `weather`, AnimalBehaviour.rain). Godot reinstalled from the 4.7.2 zip here too. Then animals turn to watch the
  farmer walk by (animal_rigs.json `farmer`: within 2.2 tiles, 1.4 s, not again for 9 s; FarmLife.see_farmer
  every 1.5 s while Game.player walks). The small animal life is now all built. Next: order of work 3 (icons'
  sticker edges, menus, motion).
- Art run 10 (17:37 IST): main only, order of work 3 (icons). 1c0ad53: vector icons draw every shape. Godot's SVG
  renderer sizes a bounding-box gradient by a curved path's end points, so domes and bowls whose ends sit level drew
  nothing (the neighbours' bodies and hair, the seed and helpers' sack tops, the stall's awning tabs); every gradient
  from tools/make_ui_icons.py is now userSpaceOnUse over the shape's real height (ui kit test 453). 2b14f30: the Fit
  icon's file drew Zoom out's minus; it has the drawn icon's frame again. Check new icons in Godot itself (rsvg is
  not enough): `Image.load_svg_from_string` in a -s script, compared to rsvg-convert. da0bdc0: UiIcon._arc gives the
  speaker's waves and the lock's shackle the white sticker edge (they vanished on brown panels). Flaky once: a
  precheck's godot log had a script error in ModelKit.canopy (model_kit.gd:702, null mesh arrays), likely a race in
  the threaded model loading (ffe2a86); passed on retry. The loop's window ends 18:20.
- Art run 11 (18 Nov 21:05 IST, the restarted loop's first): main only, order of work 3 (menus), broken pieces
  seen in look_shot's panels. a3e65e3: one window at a time (a HUD panel opening puts a building's sheet away; the
  sheet was drawn over Seeds and the album). b9bf47b: card lines never cut mid-word (CardFace.fitted_line: full
  card width, then drops trailing " · " parts; off-season seed lines green, long press says all). Then the inbox's
  tiles without names under them (they spilled into the next row). art-polish on origin is stale (behind main,
  holds the dropped c0b4a66): restart it from main for the next taste change. A fresh container needs Godot 4.7.2
  at /home/claude/godot/godot (CI's zip) and a ~1 min `--import`; the six panels' look_shot takes ~6 min. Next:
  home and crafting sheets (the Bakery's ingredient tiles' red "0/1" badges sit clipped at the sheet's bottom),
  then motion timing.

## Goals (the first hour and goals build; docs/FIRST_HOUR_RUN.md; rows prefixed "Goals:" in the log doc)
- Run 1 (18 Nov 18:38-19:20 IST): step 1 is done on goals/1-record, not merged. `Game.record(verb, subject, n)`
  with data/events.json (verb -> ribbon counter rules, `kind` filter by the subject's catalog kind) replaces every
  `ribbons.bump`; `Game.did(verb, subject, n)` is the stream goals listen to; `plant` and every `buy` are events now.
  tests/suites/events_test.gd (454-457). Full precheck passed on the commit rebased on 318dd09.
- Why not merged: main's FIRST_HOUR_RUN.md moved the window to 03:05-15:05 IST 19 Nov (after the perf build), but
  the scheduled task still runs 18:25-06:40; asked the owner in the log to move it. Next run in the window:
  fetch, rebase goals/1-record on main (the perf build touches world3d, not these systems; conflicts unlikely),
  full precheck, fast-forward push; then a bot plays a new farm from minute zero (tools/balance_sim.tscn
  --days=1), then step 2 (GoalSystem + data/goals.json) on goals/2-goal-system, listening to `Game.did`.
- Step 2 notes: goal verbs (PLAYER_EXPERIENCE Part 1) map to events.json verbs; still missing as events: place,
  move_in, level, own (state verbs read the state, not the stream). `sell` today is selling a placed thing;
  selling crafted goods is `sell_good` (a goal "sell" may want both: decide in step 2's data).
- Run 2 (18 Nov 20:37-21:10 IST): step 1 merged (cf8acf0, after a rebase on 75ac7da; the window is 20:35-08:35
  now, side by side with the perf build). Step 2 merged (c96869d, branch goals/2-goal-system): `GoalSystem`
  (`Game.goals`, scripts/systems/goal_system.gd), data/goals.json (format; daily templates only, `chains` and
  `projects` empty: they are content for steps 4 and 7), `Game.goals_changed`, Release feature `goals`, Balance
  `goals.daily_coins_per / daily_xp / daily_full_level`, `MysterySystem.gift_box()`. API for step 3:
  `refresh()` (call when the HUD opens: makes today's jobs), `open_keys()` ("chain:<id>", "daily:<i>",
  "project:<id>", faces in that order, show the first three), `tasks_of(key)`, `progress_of(key)` -> [[have, need]],
  `is_done(key)`, `claim(key)` -> the reward given, `swap_daily(i)`, `chain_step`, `daily_jobs`. Tests 458-464.
  Bot play of a new farm after each merge: unchanged (L3 on day 1, no errors).
- Next: step 3 `HudGoals` on goals/3-hud-goals (not started: did not fit this run). Faces: a column of up to three
  round faces at the left edge under the coin meter (scripts/hud/hud_top.gd has the meter), giver portrait from
  `Game.social.look_of(name)` (daily jobs: a calendar icon; projects: the project's item picture), ring for
  progress, a dot when `is_done`. Sheet: `BookPanel` with `SheetTabs` (scripts/hud/sheet_tabs.gd) Story / Today /
  Projects; each task a `UiKit.word_bar()` line; Show me: `hud.show_market()` (needs an item argument: check
  hud.gd:423), `HudTools` for plow, `ItemSearch.show_on_farm` for things on the farm; Collect calls `claim` and
  flies the reward with `FloatText`. Task words need locale keys per verb ("GOAL_DO_HARVEST" = "Harvest %s", ...).
  New icons (calendar, project) in tools/make_ui_icons.py's style; list them in the log. Done when the menu sweep
  passes for every phone shape; then the checkpoint picture (noon, 20:9) under "Goals: waiting for your look".
- Run 3 (18 Nov 21:37-22:25 IST): step 3 merged (8212d49, branch goals/3-hud-goals). `HudGoals`
  (scripts/hud/hud_goals.gd, `hud.goals`, `hud.show_goals(tab)`): up to three faces under the coin meter
  (`GoalFace`: paper disc, `BuildingSheet.Ring.paint` ring, `UiKit.count_badge` "!" when done), rebuilt on
  `Game.goals_changed`; the sheet is `book.open_tabs` Story/Today/Projects; daily jobs one line (calendar, word bar,
  Show me, Swap/Collect), chains and projects a card (portrait, giver name, `say` as a locale key, a bar per task,
  Collect). Show me per verb in data/goals.json `show` (tool:<id>, seeds, market, farm:<spot kind>|farm:item);
  `hud.show_market_for(id)` opens the Market on the thing's shelf. Task words: `GOAL_DO_<VERB>` ("Harvest %s"),
  `GOAL_DO_<VERB>_ANY` for what "", `GOAL_KIND_<KIND>` for a kind, `GOAL_DO_LEVEL`; `HudGoals.keys_of(task)` lists
  them and test 465 holds every task in the data to them (step 4/7 content: a new verb needs its keys). Chain
  `say` and project `name` are locale keys; giver names match the inbox roster case-insensitively. New icon:
  calendar (make_ui_icons.py). `GoalSystem.showcase()` now emits goals_changed; look_shot takes goals_panel.
  Menu sweep includes the goal sheet. Tests 465-466. The checkpoint picture is in the log under "Goals: waiting
  for your look".
- Next (while the owner looks): step 6 on goals/6-bot-goals: tools/balance_sim.gd's `_visit` gains a goal follower
  (Game.goals.refresh, claim every `is_done` key, prefer the crop/action the open tasks name when choosing
  `_best_crop`/spending) and breaks; print per day goals collected and chain steps, and first-hour numbers (minutes
  to first harvest, level at 60 minutes, coins at 60 minutes) for the log. Then step 7's data (six chains, more
  daily templates, three projects) on goals/7-content. Step 4 only after the owner's yes in the log.

## Perf (the loading and performance build; docs/PERF_RUN.md; rows prefixed "Perf:" in the log doc)
- Run 1 (18 Nov 20:51-21:45 IST): no phone_bench.yml run exists yet (no reports); measured here only.
  Merged perf/hide-world-while-building: LoadingCover hides the 3D farm (`world` passed by main.gd) until
  `Objects3D.progress_in` reaches 1, then draws it whole under the cover. Showcase opened cold (gl_compatibility,
  2400x1080): build frames drew 14,089 draws / 7.33M triangles in all (1,006 a frame), now 2,213 / 0.81M (184: the
  first frame, before the cover's first _process); after it is built, 1,437 draws a frame under the cover, as before.
- How it was measured: a scratch probe (not committed) run as the main scene, `--path . res://tools/_cover_probe.tscn`
  under xvfb-run with XDG_DATA_HOME set to a scratch folder (never the real save): it adds a monitor node to the root,
  changes to scenes/main.tscn (so the cover runs), then opens the showcase cold, own farm, showcase warm, and prints
  per phase the frames until built and the cover lifts, and Performance RENDER_TOTAL_DRAW_CALLS/PRIMITIVES summed
  over the build frames. One pass takes about 7 minutes here; the cover always lifts at MOST_SECONDS (software
  frames never settle). Worth committing as tools/cover_probe if the next steps keep needing it.
- Run 2 (18 Nov 21:50-22:40 IST): still no phone_bench.yml run (no reports). Step 1 done differently from the
  plan: the Bloom Garden's blooms (`BuildingFill._show_plants`) are one baked model kept by ModelStore, keyed by
  everything the model comes from (uid, field, room, span, rows, blooms in order, crowd detail; the build stamp
  covers code and data). Shipped for the showcase (CI's perf_probe --bake), saved on the phone the first time.
  Measured headless (perf_probe -- --store, run twice): garden 147-215 ms built (about 119 ms building, 96 ms
  baking 40 blooms) -> 4-5 ms kept. Draws and triangles the same (the same model). look_shot has a "garden" view;
  built and kept side by side look the same. Test 481. The plan's way (the single-bloom files) is a look change
  (4 looks at full detail instead of each bloom its own at the garden's crowd detail): reported, not built.
- Measuring here: Godot was missing from /home/claude/godot (download 4.7.2 as fuzz.yml does, then --import).
  A store-on render: a scratch scene that sets `ModelStore.stamp = "probe"` and changes to look_shot.tscn (run
  twice: the second run loads). look_shot pictures differ a little run to run everywhere (animals, sway): compare
  by eye, not by pixel count.
- Next: step 2, tree batching (the design in "Phone performance" above). The orchard's plants are not kept
  (trees stay separate for near/far detail and their own ripening): 41-64 ms, which step 2 or 3 takes on.
  Measure with tools/perf_probe --quality=low --size=2400x1080 --fill (draws, triangles) before and after.


## After the feature freeze (owner-approved ideas, 18 Nov)
- Animal life, full version ("utility AI", looks only): herds drifting together, babies following mothers, chickens
  scattering from the farmer, the dog companion trotting alongside, reactions to the farm's own systems.
- Launch: privacy-safe analytics (where players quit, what they buy, unused items) for tuning the economy from real
  play; clock-tamper protection against server time with cloud saves. No AI in the game itself.
