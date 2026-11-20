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
- Run 24 (22:20; cheating and save safety, round two): every daily limit and daily pick (today's goal jobs,
  neighbours' helps and gifts, the fuel find, the market stall) turned on any change of day, so a clock set to
  yesterday and back gave the day anew each time. `Game.day_turned(day)` turns only forward (the daily gift
  already did); `Game.day_moved_back` moves the day markers back with a clock that ran two days or more ahead
  and is put right (each system's shift_clock), so an honest fix of a wrong clock does not lock the day's limits
  until the clock catches up. A damaged goal save: a chain's or project's step past its end is dropped, a short
  collected list filled with false. Goals tests 483-484 (481 is perf's). Next audit: code quality, round two (the goal system
  and the HUD goals are new code since round one).
- Run 25 (23:20; code quality, round two): a harvest's bushel float said 1 + the stars after the harvest,
  uncapped, while the stall had taken 1 + the stars before it up to its cap (near a full stall: "+4", kept 1);
  `CraftingSystem.roll_bushel` returns the count it added and the harvest reports that (crafting test 485).
  Into data: mastery.fertilized_points, collections' duplicate_damping and trade-in levels repeating after data's
  last (finds test 486). The goal system and HUD goals were left to the goals build (its lane). Seen once: a
  pre-push precheck failed on dummy-renderer RID errors in the godot log, passing before and after (a 3D test
  flake). Next audit: whole-farm look (mostly the art lane; check numbers only), then motion, feedback.
- Run 26 (00:20; whole-farm look, numbers side): the showcase showed only VIP, rust, crafting and goals. Now
  11 more systems dress their part (`showcase()`): a stray; every other growing or ripe crop fertilized; crops,
  trees and animals at every star count (mastered too); a Queen Bee; a pen's truffles ready; the Barn half full;
  collections and ribbons at every stage; feed stock; fuel unlocked and full (it was locked: placed vehicles had
  none) with vehicles at every upgrade; crafting goods and bushels; a Mystery Egg of each colour (test 421). The
  shed's pots and half-found finds were left out: drawn on the farm, they push test 338 past the 2.3M triangle
  budget the showcase sits at (reported for the perf loop). Test 333's flake fixed (planted_at, not the clock).
  Next audit: motion and animation (numbers side), then feedback.
- Run 27 (01:20; motion and feedback, numbers side, then code quality): motion is clean in the fix lane (every
  walker clamps or carries its delta: AnimalMotion, VehicleRun, PlayerSystem.advance); feedback is clean (every
  moment, hum and float in data/feedback.json is used and every call names one; every action is answered).
  Fixed: nine hand-written weighted picks (Mystery Box, eggs, finds, babies, nurture, strays, collectibles, daily
  parts, neighbours' gifts) now share `RollSystem.weighted_index(rng, weights)`: a weight of 0 never picked, an
  empty list gives -1 (test 512 also fails any new copy in systems/ or social/). Number-file validation (test 442)
  now covers goals, reveal and search. Note: this container's clone had no core.hooksPath set until mid-run, so
  4d05045 reached main with a 122-character line (precheck red about 6 minutes); fixed in 01338f7. Set the hook
  path before the first push. Next audit: economy round three (the open items all need the owner's taste).
- Run 28 (02:21; economy round three, then edge cases): the exploit hunter (length 5) finds no free loop; the
  goals bot (30 days, 3 visits) keeps the level pace (20 on day 15) but sits on ~1M coins by day 30 (the known
  "something to buy" design item, PLAYER_EXPERIENCE Part 4). Fixed: recipe mastery markup into data
  (`recipes.markup_per_mastery_star`, test 520); `Game.place_somewhere` and a stray's arrival pick through
  `free_spot_for` (BuildingSystem's rule), so a sold Orchard's trees no longer land against a building, and still
  land when only crowded spots are left (test 521). This container had no Godot (reinstalled 4.7.2 from the CI
  URL) and a shallow, stale clone (`git fetch --unshallow`). Next audit: player progression round three.

- Run 29 (03:20-04:10 IST 19 Nov, phone UI round three): the top bar at its widest (the longest name in the
  widest letter, 987M coins, 99,999 gems, a high level) fits every screen; a longer name only came from a
  hand-edited save and ran the plaque over the coins and the star, so a name is cut to `PlayerSystem.NAME_MAX` by
  `fit_name` on set and load (test 525). A tapped thing's bubble at a screen corner went off the screen; it now
  keeps inside `HudBubble.EDGE` and shows below a thing at the top (test 353). Next audit: edge cases and stress,
  round three (or the next phone UI gaps: FloatText words at the edges are the art lane's float_words item).
- Run 30 (04:21-05:10 IST 19 Nov, edge cases and stress, round three: a full Barn and inbox, batch actions):
  Accept all with the Barn full said only "2 claimed", so things left in the inbox looked stuck; it now says what
  still waits and why (`SocialSystem.help_all_words`: room in the Barn, tomorrow's helps), and with the
  neighbours switched off still takes the farm's own things (social test 527). A Farmhand that collected and fed
  sent two messages, the second replacing the first on screen (the coins went unsaid); now one (feeds test 168).
  Checked clean: the inbox limit never drops the farm's own things (they bypass it), answers due on a full inbox
  wait, settle's mail is skipped not doubled. Note: test number 526 is used twice (world3d and ui_kit), harmless.
  Next audit: cheating and save safety, round three.
- Runs 31-33 (05:20-08:00 IST 19 Nov, cheating and save safety, round three): a save field of the wrong kind
  (nothing, a word or a list where a number or a map goes) stopped the load halfway and a new farm was saved over
  the player's; `SaveCheck.match_shape` drops it against `Persistence.snapshot`, an unusable save is kept aside as
  `.unusable` (saving test 532; held as a patch while main was red, merged run 33). Spoiling every second-level
  entry (1,464 loads) and every object field (1,604): the farm always loads; HarvestDrops' pity and a thing's
  "inside" now load as counts through `GameSystem.int_map` (tests 533, 534; a bad "inside" broke every count);
  GoalSystem.load_from's goal_daily (int()/bool() of a damaged entry, lines 135-143) is the goals loop's,
  reported. Code quality round three and whole-farm look round three (numbers side): clean. Next audit: motion
  and animation (numbers side), then feedback and sound. The loop ends at 08:40 IST 19 Nov.
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
- Art run 12 (18 Nov 22:05 IST): main only, broken pieces in panels. f86937f: cards in a row stand level (CardFace
  keeps room for NAME_LINES where the card has it: the album's rings under one-line names stood lower; seeds and
  market unchanged as their cards have no spare room) and count tiles' "×1" kept off the rounded edge (UiKit
  count_tile, home sheets and inbox). Test in 354. The precheck's ModelKit/dummy-mesh race (model_kit.gd:1094,
  "Parameter m is null") still fails about one run in three; the retry passes. Main moves every few minutes now:
  budget three rebase+precheck rounds (~4 min each). Next: the ribbons card with a bar still stands higher than
  its row (less spare room); the Bakery's ingredient badges at the scroll's bottom; then motion timing.
- Art run 13 (18 Nov 23:06 IST): main only, type roles. f47630f: every BookPanel.text/info size is a UiTheme role
  (73 bare 16/17/18/20 became BODY or HEADING, the step each already snapped to: nothing moves); the crafting
  strip's soft mastery line is BODY like the Goods strip's note. ui_kit test 491 fails a bare number. Found and
  reported: at 2400x1080 (a phone's shape) BODY 15 and HEADING 18 draw the same px (both clamp to MIN_FONT 14
  after scale x text_share), so a panel's name, body and soft note are one size: the type scale has no hierarchy
  on a phone. Measured: the mastery line's width is the same at 15 and 18. A fix (a floor per role, or a smaller
  text_share step for BODY) changes every panel on a phone: the owner picks. Fresh container: Godot 4.7.2 from
  CI's zip, `--import` ~3 min; look_shot of one panel ~6-8 min. Next: the ribbon card with a bar; motion timing.
- Art run 14 (19 Nov 00:05 IST): main only. 6d63cda: one motion language for springing back. UiFx.settle (one
  soft TRANS_BACK overshoot, SETTLE_TIME 0.32 s) replaces every TRANS_ELASTIC wobble (Objects3D tap, grow_in, drop;
  FarmPiece arrive and bounce; the HUD counters); UiFx.pulse swells a counter 1.12 and replaces a running pulse
  (coins no longer stack tweens). UiFx._fresh_tween's get_meta(.., null) logged an error on every first press: fixed.
  ui_kit test 510 fails any TRANS_ELASTIC. The doors' TRANS_BOUNCE (BuildingFill.celebrate, a door clapping shut)
  is kept on purpose. cbaf38b: a card with a bar keeps a badge's room like a name's two lines, so the ribbon "on
  its way" stands level with its row (hud test 354). Reported for the goals loop: the goal faces cover an open
  panel's left edge (Collections' note loses its first letter). Next: reveal_card's and toasts' bare timings into
  UiFx (reveal_card is goals' step 4: wait until it merges), then icons' visual size in one set.
- Art run 15 (19 Nov 01:05 IST): main only, order of work 3 (one icon set). 97d3d81: drawn icons (UiIcon, PortraitIcon,
  ThingIcon) paint in two passes (UiIcon._painted: every shape's white sticker edge, then outlines and fills; _line and
  _dot take no edge), so a part laid on another no longer cuts a white band across it (each neighbour's hat, cap and
  fringe had a white stripe, the collar a white V, collection items white rings inside). Subclasses paint in _paint.
  Then words fade away at one pace (FloatText.FADE_TIME 0.4 s: the toast, a button's name bubble, a swipe's count;
  FarmHud.TOAST_SECONDS). tools/icon_sheet.tscn renders the whole set in ~1 min: use it for icon work. A shallow
  clone's old local main looked diverged from origin (it was not on origin's 50-commit window): kept as a local
  branch, main reset to origin/main. Next: icons' visual size in one set (the cursor, plus and note read small
  beside the coin and barn at 96 px), reveal_card's bare timings once goals' step 4 settles.
- Art run 16 (19 Nov 02:05 IST): main only, one icon set. f0b6a44: icons in one visual size. tools/make_ui_icons.py
  measures each vector icon's drawn box (outline(), placed() for transforms, bounds() with the white edge) and fits
  one smaller than FIT (112 of 128) to it, at most FIT_GROW 1.15x, centred, through the file's viewBox (view());
  bigger ones untouched. Grew: seeds, fertilizer, ready pin (~10-15%); hoe, tag, coin, gem, basket, neighbours,
  fit, search, gardener re-centred and a few % larger. Drawn note and lock grow 1.12 (UiIcon.GROW). ui_kit test
  513 (every SVG's longest side >= 0.84 of its canvas); test 453's shirt pixel moved to (40, 96). Seen once: the
  pre-push precheck failed test 338 (triangles 2302157 vs 2300000 on the heaviest farm), passed on the retry:
  flaky draw budget (perf loop's lane). The cursor still reads light (a thin outline shape, by design); plus and
  cross are marks sized by their buttons, left. Next: reveal_card's bare timings (goals' step 4 merged), then
  panels' spacing grid.
- Art run 17 (19 Nov 03:05 IST): main only. 1218311: celebration cards in the one motion language (RevealCard's
  shakes eased 0.26 s rocks with a 0.14 s breath, burst 0.14 s, prize through UiFx.settle, every time a named
  constant; the level-up card opens with UiFx.open and its number swells once with UiFx.pulse, no looping pulse).
  ui_kit test 523. 9271146: inbox names in one column (a line with no thing keeps the count tile's room; hud test
  524). b539463: panels space on one grid of 4 (UiTheme sizes hud_gap 8, row_gap 12, section_gap 16 replace bare
  10/12/14 separations, now scaled with the interface; hud_goals.gd left to the goals loop). Left: the cards'
  inner separation 6 (hud_buildings, away_card rows, hud_bubble) is off the grid (4 or 8 changes card heights:
  render the home sheets first). Fresh container: Godot 4.7.2 zip, `--import` ~1 min; look_shot of two panels
  ~3.5 min. Next: the 6s onto the grid, then the level-up confetti look stays reported (a look to pick).
- Art run 18 (19 Nov 04:05 IST): main only, one panel style. 2ceb9ff: the last bare panel gaps on the grid (cards'
  inner 6s and 8s in hud_buildings, hud_feed, away_card rows, a bubble's buttons, BookPanel.info's row, level-up
  unlocks, the placing bar's 16) take UiTheme hud_gap / section_gap, scaled; ui_kit test 526 fails a bare gap over 4
  (hud_goals.gd left to the goals loop). A fresh container's local main can be an old shallow tip ("unrelated
  histories"): `git fetch --deepen=200` and `checkout -B main origin/main` (its tip is on origin). The pre-push hook
  runs the full precheck (~7 min): give `git push` a 20 min timeout. Seen in the home sheet render: each tile's
  "x1" sits over its tree picture's right edge (the count tile's corner); check against the picked look before
  moving it. Next: that badge, then the lawn's dark blotches at noon (order of work 1, taste: art-polish).
- Art runs 19-20 (19 Nov 05:35, 06:06 IST): main only. ef8c5e6: count tiles' "x1" in the tile's bottom corner
  (ui_kit test 528; run 19's patch, held while main was red). 70291ce: the phone type scale keeps its hierarchy
  (UiTheme.TYPE_FLOOR_STEP: each step above body 2 units over the one below where the floor lifts it; test 342).
  8a2242f: card grids grow to the tallest face (CardFace.needed_height, no text measured so hud test 374's scroll
  budget holds); a seed card's stars and price ran into the card below at 2400x1080. Render panels at phone shape:
  `xvfb-run -s "-screen 0 2400x1080x24" godot --rendering-method gl_compatibility --resolution 2400x1080 ...
  look_shot.tscn -- --views=seeds_panel,home_panel`. Next: the other card grids at phone shape (Market, Barn,
  Collections) and the lawn's dark blotches at noon (taste: art-polish).
- Art run 21 (19 Nov 07:06 IST): main only, broken pieces at phone shape. 8aba68d: card shelves stand level with
  mastery stars (CardFace keeps the stars' room as it keeps a name's two lines; the Market's Trees zigzagged between
  starred and unstarred trees; hud test 354). look_shot also takes market_panel and barn_panel. 6e4375d: item pictures
  frame a scaled model by its real height (ItemIcons._set_up passed model.transform to ScaleGuide._top, which applies
  it again: a decor_scale'd model, the mailbox in the Barn, drew a third of its neighbours' size). Collections at
  2400x1080 looked fine. A fresh container's first setup step can abort before `git config core.hooksPath`: set it
  first, or the push skips the precheck (8aba68d went up so; the precheck run on it after passed, 456 tests).
  Next: the Barn sheet's "x1" and "Place" under each name (a count tile elsewhere: check against the picked look),
  then the lawn's dark blotches at noon (taste: art-polish).
- Art run 22 (19 Nov 08:05 IST, the loop's last): main only. 51e502f: stored things' and goods' cards show how
  many in the picture's bottom corner, as count tiles do (CardFace face "count", ink on a paper outline): the Barn's
  sheet and the Goods tab drop their "x1" line (picture, name, Place). Godot was missing in this container
  (reinstalled 4.7.2 from the release zip). Open for a later look pass: the lawn's dark blotches at noon (taste:
  art-polish, which still holds the rejected c0b4a66 on a stale base).
- Panel motion (19 Nov, one-off session, art/panel-motion; docs/ART_POLISH.md "Panel motion"): every surface opens
  and closes through UiFx (open / open_with / close; tabs: crossfade), hidden only after its close motion. "Is it
  up?" is now `book.is_open()` / `sheet.is_open()` / `UiFx.is_open(x)`, never `.visible` (a closing one is still
  drawn); tests wait with TestSuite._motion_ends(host). The motion has its own frame clock (UiFx._tick_all, one
  listener; a frame counts at most 1/30 s). Frames checked at 20:9 and 4:3 with --fixed-fps 60 (a scratch -s script
  that saves root's image each frame_post_draw). Not touched: the helpers' flower (its own bloom), the toast and
  floating words (already fade). Open: the level-up card still names its own colours (WOOD, SUN), not the kit's.

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
  (`GoalFace`: paper disc, `ProgressRing.paint` ring, `UiKit.count_badge` "!" when done), rebuilt on
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
- Run 4 (18 Nov 22:36-23:15 IST; no owner verdict on the checkpoint yet, so step 4 waits): step 6 merged (b22e464,
  goals/6-bot-goals): tools/balance_sim `--style=plain|goals|casual`, `--away=3,7`, `--first-hour`; per day coins
  spent, goals collected, jobs left, chain steps, feed used. The bot plays a given farm (`sim.game`), so tests drive
  it (483). Then a step-2 rule fix the bot found (b344b9f, goals/2-doable-jobs): harvest jobs pick `@crop_quick`
  (ripens within Balance `goals.daily_crop_hours`), collect/feed templates are `per_owned` (`GoalSystem.per_day_of`,
  `goals.daily_play_hours`); test 484. Numbers (seed 1): first hour: first harvest at minute 0, L2 at minute 1, then
  L2 and 2 coins from minute 1 to 60, nothing bought, 3 jobs done (2 starter plots ripe; every coin goes into 4-hour
  crops: the gap step 4's Starter Seeds and Welcome chain fill; Part 2 wants L3 by minute 30-40). 14 days: goals
  L10 day 5, L15 day 9, 43 goals; casual (1 visit, away days 3 and 7) L10 day 13, 27 goals; plain L15 day 10.
- Still open for step 7's data (seen in the bot, not fixed): a job to plant or harvest can't be done when every plot
  is growing a long crop (the bot fills the farm; idle 0) and some days a "collect from chicken" stays 0 / n with
  chickens on the farm (check whether a chicken collected the evening before is ready again within the day; maybe
  per_day_of should count only the ones ready today). Next: step 7's data on goals/7-content (six chains, about 15
  daily templates, three projects; each new verb needs its GOAL_DO_* keys, test 465), then the bot completing every
  chain (`chain` column). Step 4 only after the owner's yes in the log.
- Run 5 (18 Nov 23:36 - 19 Nov 00:10 IST; owner approved the checkpoint 23:32): step 4's first half on goals/4-welcome
  (2497ce3), not
  merged (step 4 is not finished: the reveals are still to do). Built: the Welcome chain (data/goals.json chain
  `welcome`, giver Maple, `new_farm: true`, 8 steps: harvest 2, plow 2 + plant 2 Strawberries -> Starter Seeds,
  plant + harvest them -> Barley's chicken (ready), collect a chicken, buy an Apple Tree (comes ready) + pick it,
  plow + plant 4, level 3 -> today's jobs, plant Wheat "ready when you wake"). GoalSystem: `new_farm_chains()`
  opened by reset (a brand-new farm); load_from marks them done on a farm saved without them (old saves skip
  Welcome); reward `seeds` (gift seeds, `seeds_of`/`take_seed`, saved "goal_seeds"), `place` + `ready` (the gift
  comes ready: BarnStorage.place_from_storage), a task's `ready` (the thing it counts as bought comes ready:
  `take_ready`, ShopSystem.buy_and_place); daily.level 3 (jobs wait for level 3); `welcome_say()`.
  Game: `can_plant(id)` (unlocked or gift seeds held: FieldSystem.plant, the Seeds shelf, Show me), a new farm's
  `tutorial_step` is DONE when goals run (the Welcome chain teaches; `tutorial_text()` falls back to the open
  Welcome step's line, the HUD refreshes it on goals_changed; old farms mid-tutorial keep it). Starter Seeds:
  crops.json `starter_seeds` (`starter: true`, 3 minutes, unlock 99, free; schema field), only on the Seeds shelf
  while held. Locale `GOAL_SAY_*` (strings_lint prefix), `GOAL_GOT_SEEDS`. Bot: plants with `can_plant`, keeps
  coins for a goal's buy (`_keep`), places inbox gifts (`_place_gifts`). Tests 500-503 (tests/suites/welcome_test.gd).
  Bot first hour (seed 1): Welcome done by minute 8 (8 chain steps), L2 at 1, L3 at 8, first purchase (Apple Tree)
  at 6, then 52 idle minutes with today's jobs open and 14 coins (every plot growing; the bot plays a minute's
  worth of taps at once, so its minutes run far ahead of a player's: Part 2's L3 at 30-40 is a player's pace).
- Not done in run 5 (next, on goals/4-welcome, then merge): `HudReveal` + data/reveal.json (button -> the goal or
  level that shows it; on a new farm only the tools in use and the Market; Collections, Ribbons, Neighbours,
  Settings appear with a short shine as a goal needs them; a farm past Welcome sees everything) and the bot test
  that every Part 2 row happens (the Tractor project's row needs step 7's project data). Starter Seeds have no
  crop_forms.json entry (adding one re-exports every plant file: art churn beside the perf build), so they draw
  as the catalog's berry shape, not as Strawberries: a look question for the owner (reported). The `Guide`
  hand (Part 2 principles) is not in step 4's list: reported, not built.
- Rebasing goals/4-welcome: its commit also carries this run-5 note in docs/NEXT.md (an older copy); on a
  conflict keep main's NEXT.md. art/models (105 plant files) and data/art_sources.json come from
  tools/export_plants.tscn: on a conflict take main's, then export again and run tools/make_art_versions.py.
- Run 6 (19 Nov 00:36-01:20 IST): step 4 merged (9645306; branch goals/4-welcome rebased on main, then pushed
  to main). Reveals: data/reveal.json (`after`: ["welcome"]; `buttons`: "tool:<HudTools id>" / "menu:<HudSide
  key>" -> {verbs, level, inbox}); `GoalSystem.shows(button)`, `reveal_now()` (the ones appearing now, kept in
  `revealed`, saved "goal_revealed"), `past_welcome()`; a button not listed (Select, Harvest) always shows; goals
  off, a farm past Welcome, an old save and the showcase see everything. `HudReveal` (hud.reveals) hides/shows
  `hud.tools.buttons` and `hud.side.buttons` on goals_changed, leveled_up, inbox_changed; a newly shown one gets
  `UiFx.shine` (glow + pulse). Fixed on the way: HudSide looked for "NEIGHBOURS" (the entry is "INBOX"), so the
  inbox's count badge and mail timer were never built (locale NEIGHBOURS removed: unused). Bot: `play_first_hour`
  returns `chain_minutes` (chain -> minute of each step); test 503 holds Part 2's order (harvest in 0-2, every
  Welcome step, first purchase = the Apple Tree step, L3 in the hour); 504-505 the reveals.
- Then (dc17c1e, goals/4-starter-keeps): Starter Seeds never wither (CropDef.STARTER_WINDOW): the 2-day bot
  planted them, came back hours later to withered seeds and the Welcome chain stuck forever at step 3.
- Bot numbers (seed 1): first hour: Welcome steps at minutes [0, 1, 5, 6, 7, 7, 7, 8], L2 at 1, L3 at 8, Apple
  Tree at 6, then 52 idle minutes, 14 coins, today's jobs open (the dead end step 7's Tractor project and Barley's
  chain fill). 5 days (3 visits a day): L10 day 5, but Welcome stays at step 5 from day 3 on: the day bot plows the
  whole farm and an Apple Tree finds no free tile (`_goal_buy` returns with no spot). A player can clear plots
  with Sell, but nothing says so: reported. Bot fix idea: `_goal_buy` sells one empty plot when nothing fits.
- Step 4's Part 2 rows not yet covered (step 7 content): 20-30 the broken Tractor project with a guaranteed first
  find that shows Collections; 30-45 a second chicken and Barley's coop chain. Add them to test 503 with step 7.
- Next: step 7 on goals/7-content: projects `tractor` (opens at level 2 or after Welcome step 5; stages of
  harvest-sourced materials; its first find guaranteed: needs a GoalSystem rule or a drops pity hook, the spec
  does not say which: decide in data, e.g. a task reward `find`), orchard, rare coop; six neighbour chains (Barley
  first: second chicken, the coop); about 15 daily templates; every new verb needs GOAL_DO_* keys (test 465) and
  reveal.json verbs if it needs a hidden button (collections: find). Then the bot completes every chain.
- Run 7 (19 Nov 01:36-02:25 IST): step 7 mostly built on goals/7-content (14ca49d, 975b328), pushed, NOT merged
  (the Tractor project is still to do). Full precheck passed on it (rebased on 01fe97f). Built: six neighbour chains
  (21 steps, levels 3-12, two lines: barley_coop -> poppy_decor -> hazel_baker; maple_orchard -> clover_bees ->
  rusty_tractor; test 513 holds 3-6 steps, one chain per neighbour, at most two open at once, every reward in the
  release); 16 daily templates (new: harvest any, collect @tree_owned / animal, fertilize, earn, gift, pollinate,
  vehicle_work, start_craft, sell_good; a template's `needs` (id or kind) waits until the farm has one; test 514);
  projects `orchard` (own 3 Apple, 3 Plum, 3 Lemon -> Fountain) and `rare_coop` (own a coop, collect 20 chicken,
  open_egg 3 -> Brown Chicken), names GOAL_PROJECT_* (strings_lint prefix). Choices made where the spec is silent:
  `own` not `build` for the coop (a building with no materials never records "build": only finishing a frame does);
  Clover's bees are her chain's reward (a Beehive needs materials the bot never gathers); Rusty's first step is
  harvest 40 (a full farm has no grass to plow); Hazel's chain is the baker's crops (crafting buildings unlock at 25).
- Bot (tools/balance_sim): buys a kind's cheapest thing (`_goal_item`), clears an empty plot when nothing fits or for
  a vehicle run (`_clear_a_plot`), collects blooms, sends vehicles (`_goal_vehicles`), opens Mystery Eggs a goal asks
  for; prints chains and projects done. Every chain done by day 19 (seeds 1-3, 21 days, 3 visits): test 515 (~15 s).
  The rare coop stops at "open 3 Mystery Eggs": the bot never moves hens into the coop (eggs come from there?):
  check, then teach the bot. First hour unchanged (Welcome by minute 8; Barley's chain opens at L3).
- Next: the Tractor project on goals/7-content (Part 2's 20-30 minute row): a rusted Tractor parked on the starter
  farm (RUST.md's look exists), opens at level 2 or after Welcome step 5, stages of harvest-sourced materials, its
  first find guaranteed (decide in data: e.g. a stage reward `find`), repaired at the end (a `repair` event for a
  vehicle); add its row to test 503; then rebase, full precheck, fast-forward push (step 7 done).
- Seen: world3d test 338 (showcase draw budget) is flaky: the same commit gave 2,296,113 / 2,296,793 / 2,302,157
  triangles in three runs (budget 2,300,000): the showcase is not deterministic and sits at the edge (perf lane).
- Run 8 (19 Nov 02:36-03:10 IST): step 7 merged (af66343; goals/7-content rebased: 3 commits). The broken Tractor
  project (data/goals.json `tractor`, level 2): stages harvest 6 + find 1 (`sure`), harvest 40, harvest 120 + plow
  60, harvest 300; stage rewards `parts` (Vehicle Parts via DailySystem.add_part; `HudGoals.reward_words` names
  them, GOAL_GOT_PARTS), the Tractor itself at the end. A `find` task with `sure: true` guarantees a find to the
  first harvest that turns up none while it is open (FindsSystem.sure() at FieldSystem.harvest, not at planting, so
  a crop already growing counts; GoalSystem.take_sure_find, once per goal key, saved "goal_sure_spent"); its open
  find task brings out Collections (reveal.json verbs). Rusty's step 3 is `own` tractor (the rebuilt one counts).
  Bot: `_place_named` takes a goal-named thing out of the Barn (clears a plot if needed); first hour reports
  `first_find` and `project_open`. Tests 522 (new), 503 (project open by minute 30), 364 (spends the sure find
  first). Numbers: first hour (seeds 1-3) Welcome by minute 8, project open at 0-1, first find at minute 5; 21 days
  (seed 1, drops on): every chain, the orchard and the Tractor done; the rare coop stops at "open 3 Mystery Eggs".
- Choices made where the spec is silent (reported in the log): no rusted Tractor stands on the starter farm (that
  is step 5's starter-farm layout, Part 3, a new look: a sheet of options first), so rebuilding hands over a new
  Tractor at the end; the stage sizes (6/40/120/300 harvests) aim at 1-3 weeks of play.
- Seen, not fixed: the 2-day bot (--days=2) leaves Welcome on its last step (plant 1 Wheat) because every plot
  holds a long crop when it is asked; the rare coop's Mystery Eggs (the bot never moves hens into the coop).
- Next: steps 5, 8, 9 "only if time allows". Step 8 (economy tuning to Part 4's targets, data only, goals/8-economy)
  is the one that fits the rules unattended: run the bot styles (plain, goals, casual, --away) against Part 4's
  targets, tune data/balance.json and goals rewards, log before/after. Step 5 and 9 are new looks: a sheet of
  options for the owner first (CLAUDE.md), nothing wired before a pick.
- Run 9 (19 Nov 03:36-04:20 IST): step 6's last Part 4 pieces merged (c4311b5, goals/6-builder-market):
  `--style=builder` (follows goals, then `_buy_wants`: the Market's progress buys it can afford, cheapest first,
  BUILDER_BUYS 3 a visit, frames with materials skipped) and the Market measure: per day `idle_v` (coins / that
  day's income per visit) and `want` (`market_wants(per_visit)`: homes, buildings, trees, animals, vehicles, the
  next land costing 1-3 visits; not decor, seeds, materials), a `market:` summary line, gems earned a week. Test 525.
  This container had no Godot (4.7.2 from the CI URL into /home/claude/godot) and no gdlint (pypi is blocked here;
  precheck's own line check runs instead).
- Step 8 measured (seed 1, 42 days) against Part 4: levels on pace (goals L20 day 13, L30 day 30; casual L20 day
  29; builder L20 day 11); gems 5-10 a week (target "a few"); something to buy on 85-90% of days (casual 50%);
  idle coins over 5 visits of income on 76-83% of days in EVERY style, the builder too: it buys every progress
  thing by about level 15-20 and then sits at 15-25 visits (683k on day 40; only the Garage, a materials frame,
  left). So data tuning of prices alone cannot meet "idle under 5 visits": past level ~20 the Market has no
  repeatable coin sink at 1-3 visits of income (~35k a visit). Reported in the log (a design call: new sinks or
  less income at high levels; FarmVille's own prices stand). Step 8 stays open until the owner picks.
- Next: with no owner pick, the rest of step 8 that the spec does decide: the feeding target (a never-feed bot
  loses at most 30% of animal income: add `--no-feed` and compare collect income), crafting's 30% markup over
  ingredients (a check over data/catalog/recipes.json) and "a week away loses nothing" (`--away=2,3,4,5,6,7,8`).
- Run 10 (19 Nov 04:36-05:25 IST): step 8's feeding and away targets merged (f5f2f8c5, goals/8-feed-away).
  `--no-feed` (the bot never feeds); every run prints `animals:` (animal coins as a share of the plain price,
  `animal_share()`, and `away_lost`: animals, trees, buildings gone across an away stretch). Measured (goals, 28
  days, seeds 1-3): feeders reach x1.07-1.18, a never-feeder x(1 - hunger_penalty); at 0.3 it lost 33-38% (target
  at most 30%), so feeds.hunger_penalty is 0.15 now (worst 28%; level pace unchanged). A week away (days 8-14)
  loses nothing. Crafting: every good sells for 1.5x+ its ingredients (sell_markup 1.5; target 1.3x). Tests 529
  (goals), 530 (crafting). First hour after the merge (seeds 1-2): Welcome by minute 8, first find at 5.
- Step 8 still open: idle coins over 5 visits past level ~15 (the owner's call, reported in run 9); crafting's
  "pays back its building in about a week" is not measured (the bot never crafts: a crafter style would be
  next, after the Bakery unlocks at 25). Steps 5 and 9 are new looks (sheet of options first).
- Run 11 (19 Nov 05:36-06:20 IST): merged as one commit (see `git log`): (1) **CI Tests on main had failed at gdlint
  since at least 22:18 UTC 18 Nov** (the tests never ran in CI): `hud_goals.gd` `var get :=` does not parse in
  gdlint 4 (now `claim`), `goals_test.gd:14,16` mixed tabs and a space. Local precheck cannot see these (no gdlint
  here: pypi blocked; its own line check passes): watch the next CI run. (2) **Test 483 failed on main** (the first
  hour stood still: 53 of 60 minutes idle at 55 coins, no first find): today's jobs asked a 55-coin farm to plant
  8 Eggplant (320 coins); now a job to plant or harvest a named crop asks no more plots than the coins plow and sow
  (`GoalSystem.affordable_plots`, test 462), and the bot pays the plowing in its crop choice on grass and keeps
  coins for a goal's buy only once it holds them (`_kept`). (3) `--style=crafter`: follows goals; a level before the
  Bakery unlocks it grows only Bakery crops; builds the Bakery with coins at L25 (clearing harvested plots for its
  3x3); each visit finishes crafts, sells goods, starts the best-paying unlocked recipe (up to STALL_BUY_MOST
  missing bushels bought at the stall); `crafting:` line: cost, goods, coins, stall spend, payback days against
  CRAFT_PAYBACK_DAYS 7, bushels held. Test 531. Full precheck 455 tests, 0 failed.
- Measured (seed 1, 35 days, crafter, before the job fix): Bakery built day 20 (L25); crafting **jams**: every
  harvest of any crop drops bushels (20%, +1 per mastery star), the stall holds 100 and only crafting empties it. On
  the build day it filled with grapes and ghost chili (no Bakery recipe uses them); growing only recipe crops, one
  crop fills it (86 carrots or 98 wheat) and the other inputs never get in: 0-4 goods in 15 days, payback 287 days to
  never (target about 7). Reported for the owner (a crafting rule, outside goals): only crops some owned building
  uses drop bushels; or a full stall swaps out the most-held crop; or a throw-away button.
- Next: after the owner's pick on the stall, re-measure the crafter's payback; first hour bot again with today's jobs.
- Run 12 (19 Nov 06:35-07:05 IST): **main green again** (8af35a8, goals/9-new-farm-hour). CI's Tests ran at
  last (gdlint fixed in run 11) and failed only test 483. Cause: `Game.reset_game` (`_new_game`) sets
  `debug_time_offset = 0`, so the bot's and the tests' "move the clock to the first visit's hour, then reset" did
  nothing: the first visit fell at the hour the run started (early morning IST the first hour's strawberries
  withered before the 13:00 visit). `BalanceSim.new_farm()` resets, then sets the clock back to the last time it
  read the first visit's hour and lets `Persistence.watch_clock` move every timer; the bot's `_ready` and tests
  483, 503, 515, 529 use it (483 checks the hour). Checked under TZ Asia/Kolkata, America/New_York, Asia/Tokyo.
- First hour now (seeds 1-2): Welcome done by minute 8, then 52 idle minutes at 2 coins (every plot planted,
  open goals need coins or ripe crops). Reported for the owner (pacing against Part 2's minutes: leave, pace
  Welcome, or an overnight-crop last step). Not built: it changes step 4's content the spec does not decide.
- Next (the window ends 08:35; the 07:35 run is the last full one): nothing decided is left in this lane. Waiting on
  the owner: the stall jam (step 8 crafting), idle coins past level 15 (step 8), the first-hour pacing; steps 5
  and 9 are new looks (a sheet first). A last run can re-measure after any owner pick, else write the summary.
- Run 13 (19 Nov 07:35-08:20 IST): goals/7-rare-coop-2 (41292f2, test 540): the goal bot fills each egg-laying coop,
  collects it and opens the Mystery Eggs it finds; pushed, NOT merged (needs rebase on main and a full precheck).
  Reported: the rare coop's last stage (open 3 Mystery Eggs) takes about a month at FarmVille's egg odds.
- Final (19 Nov 08:36 IST): the build's window is over; summary row in the log. Open, all the owner's call: the
  bushel stall jam (crafting's payback), idle coins past level 15, the first hour's idle minutes after Welcome, the
  rare coop's pace, the Guide hand, Starter Seeds' look; steps 5 and 9 need a sheet of options first. The scheduled
  task could not switch itself off from a run (needs the owner's approval): disable it by hand.

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
- Run 3 (18 Nov 22:50-23:25 IST): first phone runs (phone_bench.yml runs 3-4): still no report. The Galaxy A10 and
  the A13 were both skipped, "Incompatible Architecture": their Android is 32-bit and every preset exports arm64
  only (export_presets.cfg armeabi-v7a=false), so such budget phones cannot install the game at all (reported for the
  owner). The Pixel 6 ran ~70 s and logged no BENCH line: the Robo crawler stops when it finds nothing to tap, likely
  before the benchmark's three phases (up to 90 s each) and play are done. Merged a987841: a Robo script that only
  waits five minutes (`DELAYED_MESSAGE_POSTED` actions, --timeout 7m); unverified (the day's 4 phone runs are used),
  the 02:10 nightly tests it: if it says the script is invalid, the wait action's name is the thing to check.
  Merged 26d488a: perf_probe prints "PERF materials=.. shaders=..". Filled showcase on low (--fill, whole farm):
  1,822 draws, 884k triangles, 155 materials, 30 shaders (crop3d 69 materials, fruit3d 11, orbit3d 11, paint3d 10).
- Tree batching started on perf/tree-batching (not merged, 9daee48 + art_versions): `Instancer.split_clocked`
  takes a model's fruit/bloom surfaces into their own pieces, keeping materials and LODs (test 495). Still to do,
  in order: in `Objects3D._build`, a lone tree from its file (`uses_file`) goes the decorations' way: pieces_of a
  key of id + file look + ready/withered state, taking only the visible state's parts (AssetRegistry.apply_state
  hides the others, `_take_apart` does not skip hidden nodes); the still pieces through `_batch` (look key), the
  fruit put under a second DecorLayer id (as `dressing_id`) in a look keyed by the look and its times, with
  `material` = `timed_material(base, times)`; `_ripen_view` re-puts the fruit instead of `ripen(node)` when the
  stand-in has PIECES; the tree's own turn already goes through holder*node transforms. Then crowded (code-built)
  trees the same way, the tests that read a tree's timed materials updated, and render whole farm and play zoom
  before/after at 1x (watch LOD: a MultiMesh picks one level for its whole region, a tree alone picks its own).
- The phone build's first-draw stalls (PERF_RUN's win 1): there is no shader warm-up anywhere. Godot 4.7's export
  shader baker (preset option `shader_baker/enabled`) would ship compiled shaders, but it may need a non-headless
  export with a rendering device (CI exports headless): check on the next run before relying on it.

- Run 4 (18 Nov 23:51 - 19 Nov 00:40 IST): still no phone report. phone_bench runs 1-5 (all 18 Nov, 17:12-17:37
  UTC) have no BENCH line; run 5 (Galaxy A05s, before the Robo wait script a987841 and before the log lines were
  printed) ended after 25 s of test time. The Spark plan's 5 phone runs a day were all used on 18 Nov, so the 02:10
  IST nightly (20:40 UTC, the same day in UTC and Pacific time) may be refused for quota: if it is, the next phone
  run that can work is after the quota day turns (likely 08:00 UTC = 13:30 IST, if it is Pacific midnight). No
  phone run started this run (it would most likely hit the same quota, and the nightly already takes the newest APK).
  Merged c26c513/32efcb3: LoadBenchmark prints the report so far after every phase ("done": false until the end;
  phone_bench takes the last BENCH line), so a run cut short still gives numbers. Merged 78c24fb (test 454 no longer
  hangs on build speed) and 6a27e82 (AssetRegistry.threaded: no worker-thread loads without a screen; the headless
  stand-in renderer's mesh store is not thread-safe, which left engine errors in ~1 precheck in 2 for every loop;
  phones unchanged). Prechecks before: 2 of 4 failed (test 454, RID errors); after: 5 of 5 passed. Note: headless
  probes (perf_probe -- --store) now load files serially, so their cold times are not comparable with run 2's.
- APK findings (the 8046621 benchmark APK, 205 MB): libgodot 77.6 MB, .godot/imported 112 MB of which 91 MB are 327
  model scenes (.scn from .glb), ctex 11.7 MB, music 9.4 MB, baked icons 21 MB. The glb files carry no textures and
  no normal maps, yet 903 of 982 meshes carry tangents; the biggest scenes are the animals and farmers with blend
  shapes (grey_chicken: 8,489 vertices, 10,604 triangles, 16 blend shapes, 2.2 MB). Next for loading (win 2), once a
  phone report says loading is the cost: measure what the generated LODs and the tangents add per scene (re-import
  one with meshes/generate_lods off and compare size) and the animals' blend-shape cost; dropping tangents needs the
  exporter (art builders) not to write them: that is the art lane, report it.
- Next run: read the nightly's report first (if it ran). If the A05s again gives no BENCH line, the log lines now
  printed say whether the app started, crashed, or was killed.

- Run 5 (19 Nov 00:50 - 01:40 IST): still no phone report (no phone_bench run since run 5 of 18 Nov; the 02:10 nightly
  comes after this run). Worked on win 1 (first-draw shader stalls), which only a phone measures. Found: Godot 4.7's
  export shader baker (`shader_baker/enabled`) is skipped without a word in a headless export (tried here: an
  --export-pack with it on stored nothing new), because it needs the editor running the Mobile renderer on Vulkan
  ("The editor is currently using a different renderer..."). Merged 5e5880f (perf/shader-baker): the baker on in all
  three Android presets; apk.yml installs mesa-vulkan-drivers (lavapipe) and exports the debug and benchmark APKs
  under xvfb with `--rendering-driver vulkan --rendering-method mobile`, falling back to the old headless export if
  that fails (so the phone build never breaks); it also uploads farm-game-benchmark-plain.apk (headless, unbaked)
  and the step summary says how many files only the baked APK has. phone_bench.yml has an input `apk` (default
  farm-game-benchmark.apk, the baked one; farm-game-benchmark-plain.apk for the comparison).
- Checked in CI (apk.yml run 228, 53cbb0b): the baked export ran (lavapipe, "Vulkan 1.4.335 - Forward Mobile",
  "Baking shaders (202 steps)", 18 s an export, the whole step 78 s). The baked APK holds 72 compiled shaders in
  assets/.godot/shader_cache (40 SceneForwardMobileShaderRD: the farm's materials; sky, canvas, tonemap, copy,
  shadow, skeleton...), 210.8 MB against 205.3 MB plain (+5.4 MB); every other file is the same (the main scene
  is stored under the baker's export folder). The debug APK is baked too. Not run on a phone yet: no phone run
  started (the free plan's 5 runs for 18 Nov were all used); the 02:10 nightly takes the baked benchmark APK.
- Next run: 1) if a later apk.yml run fell back (no "Baking shaders" in its export step), its log says why (no
  Vulkan device, renderer mismatch, timeout 20 min). Also seen in the baked export's log, harmless so far: "Failed
  loading resource: res://locale/strings.csv" (the APKs hold the same translation files) and "p_name.is_empty()".
  2) Read the nightly's report (if quota allowed). 3) When quota allows, two phone runs an hour apart: `-f inputs[apk]=farm-game-benchmark-plain.apk` and then the default; compare long_frames and longest_ms
  per phase (and built_ms: baked shaders may also shorten loading). Keep the baker only if the phone says it helps
  (and the look is the same: it compiles the same shaders).

- Run 6 (19 Nov 01:51 - 02:40 IST): still no phone report (phone_bench's last runs are 18 Nov's five; no run started:
  the free plan's quota for that day is used, the 02:10 nightly is the next). apk.yml 231 baked its shaders (the
  baker works in CI). Worked on loading, measured headless. Found: opening the showcase spent ~218 ms of CPU in
  `Animal3D.file_stride` (68 kinds, ~3 ms each: `surface_get_blend_shape_arrays` unpacks all 16 moves of a file,
  ~2.7 ms; the reach loop and the second instance are small). Merged f181f3e (perf/animal-strides): the strides
  are kept in data/animal_strides.json, each with its file's fingerprint (ArtVersion.file_of); a kind whose file
  changed is measured as before, so a stale table only costs time, never a wrong walk. Written by
  tools/animal_strides.tscn (headless); test 513 fails when one is stale (CLAUDE.md lists it beside the other art
  regenerations; make_art_versions keeps it out of the look fingerprint). Showcase opened headless (perf_probe):
  settle 4.13 s -> 3.67 s (medians), worst frame 186-231 ms -> 117-127 ms; build_ms unchanged (~1.06 s; the
  animals come after it).
- Checked (APK size, win 2): the 88 MB of imported scenes are 69.5 MB animals (73 files), 12.3 MB farmers, 9.1 MB
  buildings; an animal is mostly its 16 blend shapes (grey_chicken: 8,489 vertices x 17). Re-imported with
  generate_lods off or create_shadow_meshes off: the same size (blend-shape meshes get no LODs); ensure_tangents
  off made the chicken bigger (2.22 -> 2.69 MB). No import-setting win there; fewer vertices or moves is the art
  lane (reported).
- Seen for frame time (win 3): the showcase's 112 animals are ~524k triangles at full detail (~4.7k each) at every
  zoom, since meshes with blend shapes get no LODs. A coarser far version is a look change: reported, not built.
- Next run: read the nightly's report first. If none, still on loading: profile the rest of the settle (3.7 s
  headless) the same way (time the per-kind and per-object work under Objects3D/Animal3D build; `file_length`
  instances each animal file again, ~0.2 ms a kind, small).

- Run 7 (19 Nov 02:51 - 03:40 IST): the 02:10 nightly phone run never fired (no phone_bench run after 18 Nov 17:37
  UTC by 21:44 UTC: GitHub dropped or delayed the schedule), so one phone run was started by hand at 21:45 UTC on
  the baked benchmark APK of 21:31 UTC (it may be refused for the free plan's daily quota). Profiled the showcase's
  settle headless (perf_probe -- --store, timers in Objects3D._rebuild, BuildingFill, Animal3D: scratch, not
  committed): of ~2.7 s, ~1.0 s is ShowcaseFarm.build (the showcase's own layout, not a player's farm), ~0.75 s
  Objects3D building, the rest the other layers over ~40 frames. In the building: BuildingFill.create ~280 ms
  (orchard 45 ms: its trees, not kept; garage 29 ms: code-built vehicles; animal templates 117 ms for 85 kinds,
  ~1.4 ms each, mostly loading their files; window heads 29 ms). Merged ddf6fc9: BuildingFill.head_triangles cuts
  a window head judging each corner once and writing in place: 29 -> 13 ms, the same triangles in the same order
  (test 523), so the look is the same.
- Flaky budget: world3d test 338 (the heaviest farm's triangles) measures 2.295-2.302M against a 2.3M limit, run to
  run (animals moving); one precheck in three or so fails on it since goals step 7. Not raised (the budget must not
  slip): the next perf run should make the count steady (a fixed time or pose for the measure) or find the
  triangles goals step 7 added.
- First phone number (phone_bench run 6, 21:45 UTC, Galaxy A05s, Adreno 610, Android 15, baked APK of 21:31 UTC):
  `"startup_ms": 8193`, then nothing. The engine took 8.2 s from start to LoadBenchmark._run (autoloads and the
  main scene), and ~4 s later Test Lab's Robo crawler closed the app (its surfaces removed at 13:54:00, `am`
  commands after it): the Robo wait script (a987841) does not hold the app open, so no phase is measured yet.
  The artifact zip cannot be downloaded from this container (its blob host is refused by the egress proxy):
  read the numbers in the run's log (`gh run view <id> --log | grep BENCH`).
- Here (headless, desktop CPU): from start to the first script after the autoloads ~1.9-2.1 s, main.tscn's load
  ~0.16-0.19 s (a scratch `-s` SceneTree script printing Time.get_ticks_msec() at _initialize). So the start is
  mostly the autoloads' setup (Game and its systems, the catalog and data files, Sound, Feedback...).
- Next run, in order: 1) the start (8.2 s on the phone, the biggest number there is): time each autoload's
  _ready / _init (project.godot's autoload list; a scratch probe, or LoadTrace marks committed so the phone shows
  them) and move what the first screen does not need off the start (loaded later, threaded) without changing
  anything seen. 2) Keep the phone run going past the start: Test Lab's game-loop test type (`--type game-loop`,
  an intent filter for com.google.intent.action.TEST_LOOP in the benchmark export's manifest, the app finishing
  itself when the report is done) waits for the app instead of crawling it; or check why the Robo script's wait
  is ignored (robo_wait.json is uploaded; its actions.json in the results bucket shows what Robo did). Until then
  each phone run only gives startup_ms. 3) Loading after the start: the animal templates (85 kinds x ~1.4 ms:
  AssetRegistry.instance of each file, _build_contact) and the garage's code-built vehicles (a kept model through
  ModelStore as the garden's blooms are).

- Run 8 (19 Nov 03:51 - 04:40 IST): no new phone report (phone_bench's newest is still run 6). Measured the start
  headless (Time.get_ticks_usec marks in Game._init/_ready, main._ready; scratch, then committed as marks): from the
  engine's start to Game._init ~2.1-2.3 s, and almost all of it is loading res://autoload/game.gd, i.e. Godot
  compiling game.gd and every script it pulls in (~50k lines; --verbose shows the load of game.gd from 0.16 s to
  2.3 s; an empty project reaches its first script at 0.1 s). Then Game._init -> _ready ~0.19-0.24 s (the other
  autoloads, main.tscn's load), the data and the save 0.07 s, main._ready ~0.19 s. Loading every script alone in a
  shuffled order gives no single outlier (building_fill 72 ms, farm_3d, building_stock, main ~25-35 ms each): the
  cost is the amount of code. Merged a1390d5 (perf/start-marks): LoadBenchmark.start_mark notes "scripts" (Game
  made), "game" (data and save loaded), "main_made", "main_built"; the BENCH line has them as "start" (test 526).
  Merged with it: test 338 seeds Game.rng (BUDGET_SEED) so the budget farm is the same every time (2,297,577 each
  run; unseeded 2,297,055-2,300,259 against 2.3M, the flaky precheck); phone_bench prints Robo's own log lines, the
  system's lines about the app's process ending, and the start of actions.json.
- No phone run started: 18 Nov (UTC and Pacific) already has 6 phone runs; the next is allowed after 00:00 UTC
  (05:30 IST). apk.yml must have published a1390d5 or later first.
- Next run, in order: 1) after 05:30 IST start one phone run (default baked APK); read `startup_ms` against
  `start.scripts`: if most of the 8.2 s is before "scripts", it is script compiling on the phone; the levers are
  then fewer scripts compiled before the first screen (the main scene references the whole HUD and every world3d
  builder: a lighter first scene or scripts loaded by path later, without changing anything seen) — measure each
  with the same marks here first. If most is after "scripts", time Game._ready and main._ready parts on the phone.
  2) Read the new Robo lines in that run's log to see why the app is closed ~4 s after the start; if Robo ends
  the app, Test Lab's game-loop type (needs an intent filter, so a gradle build for the benchmark preset) is the
  way. 3) Loading after the start as in run 7's list (animal templates, garage vehicles).

- Run 9 (19 Nov 04:50 - 05:40 IST) measured class-naming costs and guessed ~1.0 s of the start was classes parsed
  again by every script naming them (its compile_probe stayed a project patch, never merged). Run 10 disproved it:
  ModelKit padded with 2,100 more lines (named by 26 scripts) moved the headless start only +50 ms, one compile's
  worth, not 26. The start's compiling is the ~50k lines once (~36 us a line here); compile_probe is dropped.
- Phone runs 7 (23:59 UTC, APK of d5fabd8) and 8 (01:58 UTC nightly, APK of 8aba68d), A05s, Robo: startup_ms
  8276 / 9313; start: scripts 4973 / 5634, game 5863 / 6918, main_made 5866 / 6924, main_built 8045 / 9089. So
  ~5-5.6 s to Game made (engine setup + compiling, unsplit), ~0.9-1.3 s for the data and save (headless 0.22 s),
  ~2.2 s in main._ready (headless ~0.1-0.2 s: ~11x, more than the compiling's ~4.5x, so likely GPU work). The app
  dies in the foreground during Robo's wait (run 7: "has died: fg TOP"; run 8: "app died, no saved state" about
  a minute before the relaunch that printed the line): the benchmark never finished a phase on the phone yet.
- Runs 10-11 built finer start marks but could not push (main red at test 483, the goals lane; fixed on main by
  8af35a8). Run 12 (19 Nov 07:51 - 08:40 IST) merged them: autoload/start_clock.gd is the first autoload (names no
  script; an Engine meta) so "engine" splits the engine's setup from the compiling; Game marks "made" (systems),
  "ready" (Sound and Feedback made), "catalog", "data"; main marks "world" (after _use_3d) and "hud". Test 526
  checks all 11 in order. Headless (run 10): engine 104, scripts 1945, made 1946, catalog 2160, data 2163, game
  2166 ms.
- Next run: 1) read the phone run started after this merge: `start.engine` against `start.scripts`. If "engine" is
  most of the ~5.5 s, it is the engine's own setup on the phone (the ~210 MB APK, Vulkan, the baked shader cache):
  look at what loads before the first autoload (project settings, boot splash, the .pck, the shader cache); if
  compiling is, the lever is fewer lines compiled before the first screen (scripts loaded by path after the first
  frame, nothing seen changed). 2) If "world" holds most of main's 2.2 s, time _use_3d's parts. 3) Why the app
  dies in the foreground during the wait: Test Lab's game-loop type, or a smaller logcat window.
- Run 13 (19 Nov 08:50 - 09:40 IST). Phone (A05s, fbc450b, 03:00 UTC run): engine 1241, scripts 4953 (so ~3.7 s
  compiling), ready 5664, data 5818, main_made 5833, world 7859, hud 7966, startup 8171 ms. The 08:45 "failed during
  validation" (A13) was TEST_QUOTA_EXCEEDED (the Spark plan's 5 a day, all used on 18 Nov Pacific time), not the
  32-bit APK: the next phone run can start after 08:00 UTC = 13:30 IST.
  Why the app "dies": Robo's 240 s wait ends, the app is gone by ~250-310 s (it quits when the benchmark is done, or
  dies), then Robo presses HOME and relaunches it, and the relaunch prints a start-only report that was the log's
  last BENCH line. Merged cc3134d: phone_bench keeps the done line, else the longest, lists every BENCH line by
  process and prints each reporting process's last lines (quit, crash or killed). The next phone run says which.
  The start, slice 1 (perf/panels-later): FarmHud loads its nine panels (Market, crafting, buildings, Barn, feed,
  books, inbox, settings, seeds) and BuildingSheet by path, on first use (and one a frame after the first screen,
  `_load_panels`), never naming their classes; BuildingSheet.Ring is ProgressRing (scripts/ui), so CardFace and the
  goal faces no longer pull in the sheet (which named FarmHud and so every panel). Lines compiled before the first
  screen: 37,644 -> 34,083 (before Game made: 35,596 -> 31,967). Headless from text, autoloads + main.tscn loaded,
  7 alternating pairs: median 1,883 -> 1,635 ms. Test 545. Panels rendered before/after (home, goals, seeds): same.
  How lines were counted: a scratch script (not committed) walks autoloads + main scene over class names (outside
  strings and comments), preload()s and scene resources; worth a tools/ script if later slices need it.
- Next run: 1) after 13:30 IST start a phone run on the newest APK (A05s): `start.scripts - start.engine` against
  3.7 s, and whether the benchmark reached "done". 2) Next slices of the start, biggest first by lines only the
  first screen does not need (the same counting): world3d builders whose look ships as a file (PERF_RUN 2a);
  WorldFx -> PlaceholderArt (1,664 lines, named from Game's own deps); ItemIcons/ThingIcon (shop pictures, first
  needed when a menu opens); HudGoals' goal sheet; debug tools (LoadBenchmark, LoadTrace, ShowcaseFarm named by
  game.gd).
- Run 14 (19 Nov 09:50 - 10:40 IST). No new phone report (none since run 13; the quota frees at 13:30 IST). The
  container had no Godot: fetched CI's 4.7.2 zip to /home/claude/godot/godot (~35 s import). Two more slices of the
  start, each measured with tools/start_lines.py (new: the run-13 counting, committed; `--drop=A,B` says what a
  slice would save before it is built, `-v` the biggest scripts and what pulls each in) and the start marks
  (headless, `--quit-after 1` with a scratch print of LoadBenchmark.start_marks() after the "hud" mark, 7
  alternating pairs):
  467e12e: FarmGrid loads PlaceholderArt by path (FarmGrid.art(), and a frame after the grid is made); SLAB is
  FarmGrid's. 34,083 -> 32,430 lines; scripts - engine median 1,666 -> 1,581 ms. a7f98b1: AnimalGait (the gait
  numbers, foot_offset, joint) out of AnimalArt, which the 3D animals and AnimalRig named only for that; the 2D
  animals' drawing loads by path (FarmGrid.animal_art()). 32,430 -> 31,802; 1,600 -> 1,554 ms. Test 546. The 2D
  farm (use_3d off) rendered before/after at 1x: differences within its own animation's run-to-run noise.
- Next run: 1) after 13:30 IST, once the "Latest phone build" has a7f98b1 or later, start one phone run (A05s;
  the A13 too if quota allows) and read start.scripts - start.engine against run 13's 3.7 s, and whether the
  benchmark reached "done". 2) Further slices, by `tools/start_lines.py --drop=`: ItemIcons ~0.9k (it pulls
  BuildingModel and Objects3D in from the UI side, but the 3D world names them too, so check what drops; named in
  18 files), the debug tools ~0.4k (LoadBenchmark's start marks would move to StartClock-sized code; LoadTrace,
  ShowcaseFarm from game.gd), HudGoals' goal sheet ~0.4k. What is left (~31.8k) is mostly the 3D farm the first
  screen draws, so "well under half" will not come from slicing alone: the phone run says whether compiling is
  still the big part.
- Run 15 (19 Nov 10:51 - 11:40 IST). No new phone report (quota frees at 13:30 IST; last run 03:02 UTC). Godot
  fetched again to /home/claude/godot/godot. Slice 4 of the start (perf/debug-later): the start marks its steps
  through StartMarks (autoload/start_clock.gd's class: `mark`, `marks`, `benchmark_wanted`), main loads
  LoadBenchmark by path only in the benchmark build, and Game opens the showcase (ShowcaseFarm) and the load trace
  (LoadTrace, debug builds only: Game.trace_begin / Game.trace) by path. Lines compiled before the first screen
  31,802 -> 31,403 (tools/start_lines.py); headless scripts - engine, 7 alternating pairs: median 1,425 -> 1,414 ms
  (within noise; ~400 lines is ~15 ms here). Test 547. Nothing seen changes (no drawing code touched).
- Next run: 1) after 13:30 IST, once the "Latest phone build" has this commit or later, start one phone run (A05s)
  and log start.scripts - start.engine against run 13's 3.7 s, and whether the benchmark reached "done"; then the
  A13 if quota allows. 2) ItemIcons (~0.9k lines, `--drop=ItemIcons`): named by ui_icon, ui_kit, hud, game,
  card_list, level_up_popup and the panels; it pulls GoodsModel, UiModels, AssetRegistry in from the UI side.
  Not a plain by-path move: the top bar's UiIcon draws its rendered picture through ItemIcons.of / is_made at
  the first screen, and hud.gd starts the renderer. The slice is a split: a small lookup (of, is_made, sized:
  the baked res://baked/icons and user://icons files) that the start names, and the maker (rendering models
  into pictures: item_icons' render code, GoodsModel, UiModels, AssetRegistry's picture parts) loaded by path
  only when a picture is missing. Measure the split with `--drop=` on the maker's classes first (BuildingModel
  and Objects3D stay: the 3D farm names them). About 30-40 minutes with tests; start it early in a run. 3) Past that, the ~31k left is mostly the 3D farm itself: let the phone say whether
  compiling is still the big part before slicing further.

- Run 16 (19 Nov 11:50 - 12:40 IST). No new phone report (quota frees at 13:30 IST; last run 03:02 UTC). Godot
  fetched again to /home/claude/godot/godot. Slice 5 of the start (perf/icons-later): ItemIcons is now only the
  lookup the first screen needs (of, sized, side, is_made, the shipped and kept files, the key, the waiting queue);
  the renderer (slots, studio lights, develop, style, save, the models it pictures: `model`) moved to
  scripts/ui/icon_maker.gd, no class name, loaded by path when ItemIcons.start runs, which FarmHud now calls a frame
  after the first screen (_load_panels' first step). ItemIcons._model stays as a wrapper (tests, tools). Lines
  compiled before the first screen 31,546 -> 30,741 (tools/start_lines.py; main had grown from 31,403 with UiFx);
  headless, 7 alternating pairs (scratch print of StartMarks.marks() after "hud"): scripts - engine median
  1,515 -> 1,416 ms, hud mark 1,942 -> 1,843 ms. Test 551. tools/make_art_versions.py lists icon_maker.gd as studio
  and look code, so the studio fingerprint changed once (every picture's key: CI's bake_icons makes them again for
  the phone build; a device's user://icons cache remakes once). Icons rendered before/after at 1x (cow, cow shed,
  ui:coin identical to the pixel; the apple tree and a crop differ only as much as two runs of the old code do).
- Next run: 1) after 13:30 IST, once the "Latest phone build" has this commit or later, start one phone run (A05s)
  and log start.scripts - start.engine against run 13's 3.7 s, and whether the benchmark reached "done"; then the
  A13 if quota allows. 2) `tools/start_lines.py -v` for what is left (~30.7k, mostly the 3D farm the first screen
  draws): candidates HudGoals' goal sheet (~0.4k), then let the phone say whether compiling is still the big part
  before slicing further.

- Run 17 (19 Nov 12:51 - 13:41 IST). No new phone report before 13:30 IST (last 03:02 UTC). Godot fetched again to
  /home/claude/godot/godot (local main had diverged in a shallow clone: unshallowed, fast-forwarded). Slice 6 of the
  start (517a910): FarmHud makes the level-up (LevelUpPopup, at the first level up, in `_level_slot`, an empty
  full-screen layer where it stood, so it layers as before; `level_popup()`), a mystery's reveal and the away card
  by path (REVEAL_SCRIPT, AWAY_SCRIPT, LEVEL_SCRIPT, also compiled one a frame after the first screen in
  `_load_panels`). Lines compiled before the first screen 30,741 -> 30,352; headless, 7 alternating pairs: scripts -
  engine median 1,666 -> 1,636 ms, hud mark 2,171 -> 2,133 ms. Level-up rendered before/after at 1x: same card;
  the unlock pictures fill in from the container's icon cache, so compare a warm-cache run. Test 552.
  Looked at, not built: ScaleGuide builds a model of each item to measure its height when the showcase opens
  (17 items, ~86 ms headless): a generated data/ table of factors (like animal_strides) would skip it, but adds a
  regenerate rule; only worth it if the phone's showcase_cold says so.
- Next run: 1) read the phone run started at ~13:30 IST (A05s, the "Latest phone build" of 517a910 or 06d09aa:
  the job log's BENCH line says the commit): start.scripts - start.engine against run 13's 3.7 s, start total
  against 8,171 ms, and whether the benchmark reached "done" (if not, how each process ended). 2) Its biggest cost
  next; if compiling is still the big part, `tools/start_lines.py -v`: HudGoals' goal sheet (~0.2k), HudReveal is
  needed at start; the rest is the 3D farm the first screen draws.

- Run 18 (19 Nov 13:51 - 14:40 IST). Godot fetched again to /home/claude/godot/godot (the container was fresh;
  local main had diverged: worked from origin/main detached). The phone run of 13:31 IST (A05s, build of 4054e3f,
  run 44484136679) reached "done" for the first time (order of work item 1 settled: after "done" the app quits by
  itself; "has died" is that quit). Cold first launch, quality mid: hud at 15.5 s, startup 16.5 s (engine 3.8 s,
  scripts by 6.9 s, world 15.0 s); own farm first whole at 76.7 s. Relaunch (quality low, AutoQuality stepped
  down): startup 7.5 s (engine 1.2, scripts by 4.2, world 7.2). Showcase cold built 54 s / whole 85 s, warm 23 /
  46 s; own farm built 4.9 s, whole 31.7 s, longest frame 790 ms; play (showcase, zoom 1.6) 94.9 ms a frame,
  p95 101, 386 draws, 218k triangles.
  Merged: the loading cover lifts on a slow phone's steady pace too (LoadingCover.settled_frame: under 40 ms, or
  under 150 ms within 25% of the frame before; 8 in a row). The A05s never drew a frame under 40 ms, so every farm
  opening waited the cover's 30 s cap (own farm: built 4.9 s, whole 31.7 s). Expected on the phone: own farm whole
  ~5-6 s. Test 554. Nothing drawn changes (the same farm, shown sooner); the container draws under 40 ms, so its
  own openings are unchanged.
- Next run: 1) read the phone run started after this merge (A05s): own_farm.whole_ms against 31,731,
  showcase_warm.whole_ms against 46,441, own_farm_first.ms_since_start against 76,666. 2) Then the play frame:
  94.9 ms on the A05s at mid. Measure headless CPU per frame on the showcase at the playing zoom
  (tools/perf_probe.tscn -- --quality=mid --size=2400x1080 --tiles=12) to tell CPU from GPU: if the CPU part is
  small, the phone is GPU-bound at 2040x918 with MSAA 2x and shadows (Quality: changing mid's defaults changes the
  look: report, do not build); if large, the per-frame scripts (perf_probe's _processing list) are next.
  Also: AutoQuality steps the phone to low within the first session (the relaunch reported "low").
  Measured after the merge (headless, perf_probe -- --quality=mid --size=2400x1080 --tiles=12): the showcase's
  CPU frame 6.9 ms here (225 things, 769 mesh nodes, 2,357 nodes); shadow casters at full detail: Objects3D 512k
  triangles, BuildingFill 153k, DecorLayer 130k, LinkLayer 35k. Container-to-A05s CPU is roughly 4-5x, so ~30 ms
  of the phone's 95 ms is likely scripts and the rest the GPU (2040x918, MSAA 2x, a 2048 shadow map over 70 m).
  The renderer probe (xvfb, gl_compatibility, same view) then said: 890 visible draws, 602k visible triangles,
  only 66k shadow triangles (the "casts" list above is full detail, before LOD): the shadow pass is not the big
  part. The candidates are the visible triangles at mid's lod_pixels 2.0 (BuildingFill, DecorLayer, Animal3D:
  which meshes lack coarser LODs, a model's own LOD, nothing seen changes at the playing zoom) and draws (Instancer
  batching of the 156 BuildingFill and 89 DecorLayer meshes). Check against the phone's play view (zoom 1.6: 386
  draws, 218k triangles) before choosing; each needs a 1x before/after.

- Run 19 (19 Nov 14:50 - 15:40 IST). Godot fetched again (fresh container; local main had diverged: kept as the
  local branch local-old-main, main reset to origin/main). The phone run of 14:31 IST (A05s, build of 657a40b, run
  44492663510) reached "done". Run 18's cover fix confirmed: own_farm whole 31,731 -> 7,695 ms, showcase_warm whole
  46,441 -> 27,311, own_farm_first 76,666 -> 48,453 ms after start; startup 20.8 s cold (16.5 before: cold launches
  vary), relaunch 7.4 s. Play got slower: 94.9 -> 256.5 ms a frame (541 draws, 498k triangles; 386 / 218k before).
  Cause: run 18's process had been stepped down to low by AutoQuality before playing (its relaunch said "low");
  this one stayed on mid (relaunch "mid"). AutoQuality skipped every frame over max_frame_ms (250) as a hitch, and
  the A05s on mid draws ~256 ms a frame, steady, so the slowest phones were never stepped down.
  Merged (eb810f7): a steady run of frames over max_frame_ms (slow_run 8 in a row, each within steady_ratio 0.25
  of the one before) is the phone's pace and counts; a window whose median is over max_frame_ms goes straight to
  the ladder's last rung (low capped at 30). Lone hitches, resumes and first draws' uneven stalls still count for
  nothing. No level's look changes. Test 555; precheck 470 tests, 0 failed.
- Phone run of 15:31 IST (A05s, build of 822d40f, run 44501767398) confirms it: play 256.5 -> 128.6 ms a frame,
  play.quality "low", max_fps 30 (stepped during the play phase: p95 259.6, so part of the 5 s was still mid; draws
  and triangles are the phase's max, from the mid part); the relaunch starts on low (was mid): startup 7.6 s,
  own_farm_first 16.2 -> 14.8 s. Cold start 16.5 s (20.8 last run); own farm whole 7.5 s, showcase warm 27.1 s.
- Next run: 1) the play frame on low (~95 ms on the A05s, ~10 fps): run 18's candidates (visible triangles:
  BuildingFill, DecorLayer, Animal3D coarser LODs; Instancer batching of the 156 BuildingFill and 89 DecorLayer
  meshes), each with a 1x before/after; measure with perf_probe/the renderer probe at --quality=low. The next
  phone run's play should be fully on low (the benchmark process now steps before play only if enough counted
  frames come first: its relaunch is on low, so run the next on a fresh install as Test Lab does; play.quality
  says). 2) The cold start (16.5-20.8 s) and the showcase cold (47 s built) after that.

- Run 20 (19 Nov 15:51 - 16:45 IST). Godot fetched again; local main had diverged again (worked on a branch from
  origin/main instead). No new phone run since 15:31 (3 used today, Pacific day; one more allowed).
  Measured (perf_probe at --quality=low --size=2400x1080 --tiles=12, xvfb gl_compatibility): 486 visible draws,
  323k visible triangles. Merged 7b607bd: perf_probe's "PERF visible <owner>" lines (each owner's meshes hidden a
  few frames): Animal3D 54 draws / 144k triangles, Objects3D 240 / 85k, DecorLayer 118 / 44k, Farmer3D 1 / 15k,
  LinkLayer 45 / 8k, Ground3D and Plots3D 8k each. With low's lod_pixels forced to 1000, Objects3D falls to 10k
  (its LODs work), Animal3D only to 106k: the animal files' coarsest LODs stop high (cow 5,087 -> 2,543 -> 1,789;
  chicken 6,062 -> 3,030 -> 1,484; alpaca 3,545 -> 441), as the importer makes them for meshes with blend shapes.
  Merged (perf/farmer-lods): Farmer3D.tinted kept no LODs (rebuilt from surface_get_arrays), so the farmer drew
  15.2k triangles at every zoom; Farmer3D.surface_lods carries them: 7.6k at the playing view on low and mid, close
  up unchanged; rendered before/after at the phone's size: the same. Test 570. Visible on low 323k -> 318k. (Animal3D._skin, the code-built
  animals, is not used where a file exists: every animal on the showcase is a file.)
- Next run: 1) the phone run of this build (after its apk.yml release): play avg/p95/draws/triangles on low.
  2) Animals are 45% of the visible triangles on low: coarser animal LODs, nothing seen changed at the playing
  zoom. Options: the animal files' import (per-mesh LOD options in the .glb.import, e.g. a larger normal merge
  angle) or the animal export (tools/animal_art) writing a coarser level; check each kind's coarsest level and a
  1x before/after on low and mid at the playing zoom. 3) Draws: Objects3D 240 visible draws (buildings' parts)
  and DecorLayer 118: Instancer batching where the parts repeat.

- Run 21 (19 Nov 16:52 - 17:42 IST). Godot fetched again; local main had diverged again (worked detached on
  origin/main). Merged 69ecce5: the benchmark's play phase reports medians (`play.split`) of the farm view's render
  CPU and GPU time (RenderingServer measured render time), TIME_PROCESS, TIME_PHYSICS_PROCESS, draws, triangles,
  and `quality_start`. Test 571. Phone run of 17:08 IST (A05s, build of 69ecce5, run 44516615914, done): play
  124.2 ms a frame on low (began on mid: p95 257.8; medians 380 draws, 215k triangles), render GPU 93.6 ms, render
  CPU 3.4 ms, script_ms 121.2 (TIME_PROCESS on the phone is about the whole frame: it likely includes the wait on
  the GPU, so read it as not a script cost until shown otherwise), physics 0.2. So the phone is GPU-bound on low
  (0.7 scale, no shadows, no MSAA): draw batching will not move the frame much; vertex or pixel work will.
  Startup 16.5-ish cold as before; own farm built 8.9 s, showcase cold built 48.4 s, warm 27.5 s.
  Then (perf/gpu-sweep, merged if its precheck passed: check `git log`): a "gpu" phase after play hides each
  owner's meshes (LoadBenchmark.owner_of, the rule perf_probe shares) for GPU_FRAMES and reports the GPU ms each
  takes away, plus `half_scale` (GPU ms with the 3D resolution halved: a big drop means pixels, little means
  vertices or draws). Test 572.
  Looked at, not built: coarser animal LODs from the import. The per-mesh import key is the glTF mesh's name
  ("cow_cow", not "cow": `_subresources={"meshes":{"cow_cow":{...}}}` works, "generate/lods": 2 drops them);
  lods/normal_merge_angle 180 changes nothing (cow still 2,543 -> 1,789). The cause is the vertex colours: 3,103
  distinct colours on 3,624 vertices (3,044 positions; the UVs add no seams), so colour seams lock the simplifier.
  A coarser level needs the animal export (tools/animal_art) to write fewer colour seams or its own far level.
- Next run: 1) read the next phone run (the nightly at 02:10 IST, or one started after 13:30 IST on 20 Nov when the
  quota resets; today's 4 are used): `gpu` (each owner's GPU ms, half_scale against all). 2) Cut the biggest:
  if half_scale is far below all, the pixels (which shaders are dearest per pixel: ground, water, grass, decor
  alpha; a cheaper low-quality path is a look change on low only: report first unless it is the approved
  scale_3d); if not, the owner with the most GPU ms (animals: blend shapes and their triangles, the export's far
  level above). Each with a 1x before/after.

- Run 22 (19 Nov 17:51 - 18:41 IST). Godot fetched again (/home/claude/godot/godot); local main had diverged again
  (shallow clone: `git checkout -B main origin/main`). No phone run: today's 4 are used (Pacific day); the nightly at
  02:10 IST is the next. Merged 5c3a621 (perf/building-spec), slice 7 of the start: BuildingSpec
  (scripts/world3d/building_spec.gd: spec, fill_of, sizes_of, taken, troughs, yard_spot, look_of, trough_at and the
  part names WINDOWS, DOOR, SLIDE, PLAN, FOOT_OUT, WOOD, HAY) is what the farm names; BuildingModel and BuildingDress
  load by path through `BuildingSpec.model()` (Objects3D.building_look, the site, DecorModel's farmhouse), so a look
  ModelStore keeps never compiles them. BuildingModel keeps aliases and delegates (spec, sizes_of) for the tests and
  tools. 30,591 -> 28,526 lines (tools/start_lines.py); headless 7 alternating pairs (scratch print of
  StartMarks.marks() after "hud"): scripts - engine median 1,482 -> 1,197 ms, hud 1,894 -> 1,810 ms; headless keeps no
  looks, so there "world" grows 114 -> 262 ms (the builders compile there instead). export_buildings: 248 files
  byte-identical; tools/make_art_versions.py lists building_spec.gd among the buildings' builders. Test 577.
- Next run: 1) the nightly phone run (02:10 IST) or the first after 13:30 IST on 20 Nov: its `gpu` phase (each
  owner's GPU ms, half_scale) and the start (scripts mark against run 21's). 2) Cut the biggest GPU owner as run 21
  says. 3) While no phone run is possible, more start slices, sized with `--drop`: CropForms (-811 lines: CropModels
  names it to build a crop's look; crops are kept by ModelStore too, so the same spec/builder split), DecorModel
  (-814: Objects3D's decor looks go through Instancer.copy_of), Animal3D (-978).
- Run 23 (19 Nov 18:54 - 19:45 IST). Godot fetched again; local main had diverged again (kept as the local branch
  local-main-backup-1119, then `git checkout -B main origin/main`). No phone run: today's 4 are used (since 13:30
  IST); the nightly at 02:10 IST is the next. Merged two start slices:
  - dbb6c2d (perf/crop-spec), slice 8: CropFormSpec (scripts/world3d/crop_form_spec.gd: form_of, look, is_plot, spec,
    forms, crops, builder()) is what CropModels and Crops3D name; CropForms (the builders) loads by path via
    `CropFormSpec.builder()` and keeps delegates for the tools. 28,618 -> 27,782 lines; headless 16 alternating runs:
    scripts - engine median 2,102 -> 2,052 ms, hud 3,070 -> 2,956 ms. The 105 plant files' meshes compared equal
    surface by surface (the exporter's .scn bytes differ run to run, so compare meshes, not bytes). Test 583.
  - perf/decor-by-path, slice 9: DecorModel loads by path (`Objects3D.decor_model()`, only in _decor_built, a
    ModelStore miss); YoungModel.build (a mystery young, built fresh as it grows) and DecorPaint (WOOD, DARK_WOOD,
    STONE, WHITE, HAY, LEAF; DecorModel's consts alias them, LinkModels' hedge uses LEAF) are what the start names.
    27,782 -> 26,947 lines. Test 582. Code moved as it was (test 582 checks the colours alike).
  - The plants exporter must be rerun when scale_guide.gd changes (it is a plants source): run it, `git checkout
    art/` (keep the committed files), then `python3 tools/make_art_versions.py` so the versions hash those files.
- Next run: 1) the nightly phone run's report (02:10 IST): its `gpu` phase (each owner's GPU ms, half_scale) and the
  start marks against run 21's (scripts mark 6,782 ms on the A05s). 2) Cut the biggest GPU owner it names. 3) While
  no phone run is possible, more start slices sized with `--drop`: Animal3D (~-1k: named by scale_guide.gd and
  the farm's animal layer), TreeModel (481), BuildingFill (918, autoload game names it).
- Run 24 (19 Nov 19:51 - 20:40 IST). Godot 4.7.2 fetched again; local main had diverged (unrelated history), so
  the run worked from a detached origin/main. No phone run: today's 4 are used; the nightly at 02:10 IST is next.
  Slice 10 (perf/tree-spec): TreeSpec (scripts/world3d/tree_spec.gd: data, shape_of, stands_by_itself, SWAY, BARK,
  UNSET, META_FAR, builder()) is what objects_3d, scale_guide and building_fill name; TreeModel loads by path via
  `TreeSpec.builder()` and keeps aliases and delegates (shape_of, stands_by_itself) for the tools and tests.
  27,066 -> 26,613 lines (tools/start_lines.py). Plants re-exported: all 105 files' meshes hash equal (scratch dumper
  of every surface's arrays), committed art kept, art_sources/art_versions regenerated (tree_spec.gd is a plants
  source). Test 584. Note: test 582 exists twice (farming_test and world3d_test) from two runs pushing at once.
- Next run: 1) the nightly phone run's report (02:10 IST): its `gpu` phase and the start marks against run 21's.
  2) Cut the biggest GPU owner it names. 3) More start slices sized with `--drop`: Animal3D (~-1k), BuildingFill
  (~-1.1k, but it builds the fills of the first screen's buildings, so a path load saves nothing unless fills wait
  until after the first screen).

## Wow (the wow build; docs/WOW_RUN.md; rows prefixed "Wow:" in the log doc)
- Run 1 (19 Nov 12:36-13:30 IST): item 0, the icon glow (owner's pick C), built and merged from wow/icon-glow.
  UiTheme.glow(kind, fresh, px) is the one rule (data/ui_theme.json "glow": gold kinds, spread, least_px; colours
  glow_gold, glow_new); UiIcon draws one shared still image behind (UiIcon.draw_glow, also the XP bar's star);
  HudSide marks a menu picture `fresh` while its dot or count shows (Market, Collections, Inbox). Test 553;
  tools/ui_sheet.tscn shows the menu plain and glowing (renders in 3 s: use it for UI looks, look_shot takes ~9 min).
- Run 2 (19 Nov 13:37-14:40 IST): item 1, harvest juice, built on wow/harvest-juice (not merged: a new look, frames
  in the log under "Wow: waiting for your look", calmer and richer). FxLayer.produce: the crop's picture pops out
  of the plot (overshoot), hangs a beat and arcs to the coin counter, shrinking, a soft spark trail behind it (a
  CPUParticles2D per flyer, world-space, the shared glow image); a pool of FxLayer.PRODUCE_POOL (6) reused, no new
  node per harvest. Numbers in data/balance.json feel.produce; the trail only where Quality fx_trails (off on low).
  FarmGrid._sweep_end: when the farmer has no more of that work queued and the run reached feel.combo_min (5),
  the count pops once bigger (SWEEP_PX) over the last plot with sparkles ("x8"); the every-5 shout skips the
  number the end says (_ends_sweep). Plow, plant, fertilize and harvest sweeps all end so. Test 560.
  tools/juice_shot.tscn renders a real sweep frame by frame (--fixed-fps 30; --produce=<json> tries a variant;
  ~10 min for 8 plots here, 6 plots is enough).
- Next: when the owner picks, set feel.produce to the pick (calmer: px 96, no trail; richer, the branch default: px 120, trail, 18
  sparks of 22 px), rebase wow/harvest-juice, precheck, push. Then the same for collecting (animals, trees,
  buildings: _show_collect has no _run streak yet and no product picture; the product is a name in the catalog,
  so the flyer would be the building's or animal's own picture, or a coin only). While it waits: item 2, the
  opening glide.
- Run 3 (19 Nov 14:35-15:20 IST): run 2 was still at work when run 3 read the log (its rows came at 14:40, its push
  at 14:42), so run 3 rebuilt item 1 by mistake; that duplicate was never pushed (kept only as a local branch).
  Run 2's section under "Wow: waiting for your look" had no frames, so run 3 rendered its branch (tools/juice_shot.tscn,
  6 plots, --fixed-fps 30, ~4 min each: richer at noon, calmer --produce={"px":96,"trail":false} at dusk) and
  uploaded one sheet there. Lesson: before restarting an item, `git ls-remote origin 'refs/heads/wow/*'` and the
  log's last 15 minutes; a run that started under an hour ago may still be working.
- Next: the owner's pick of harvest juice (richer/calmer, or bigger/brighter), then as run 2 says. While it waits,
  item 2, the opening glide. What exists: LoadingCover (scripts/ui/loading_cover.gd, put up from main.gd 146/156;
  it lifts in _process once settled_frame says the frames are steady) and FarmCamera (scripts/world/farm_camera.gd:
  snap(world, zoom), go_to(world, least_zoom) eases at GO_EASE and gives up after GO_LONGEST; any touch ends a
  journey). The glide: as the cover lifts, snap a little higher and wider (zoom out ~0.8x), then ease to the saved
  view over 2-3 s (a longer journey than GO_LONGEST: a duration argument or its own tween), the light warming in
  (a ShaderGlobals tint from cool to normal); the first open of a session only; a tap skips it (the touch already
  ends a journey). Build on wow/opening-glide; it is a new look, so frames go to the owner first.
- Godot is not kept between runs: fetch 4.7.2 (apk.yml's URL) into /home/claude/godot and --import once (~3 min).
  The pre-push precheck can fail on timing-budget tests under load (card list 374): rerun, don't push around it.
- Run 4 (19 Nov 15:35-16:10 IST): no owner pick yet for harvest juice (stays on wow/harvest-juice). Item 2, the
  opening glide, built on wow/opening-glide (not merged: a new look, frames in the log under "Wow: waiting for your
  look"). LoadingCover emits `lifting` as it starts to fade; main connects it for the session's first cover only
  (OpeningGlide.wanted: not played yet, not the loading benchmark), so the showcase and a return home open plain.
  OpeningGlide.play: FarmCamera.glide_from(start, zoom, seconds) eases (smoothstep) from a view feel.opening_zoom_from
  (0.86) wider, never past the furthest zoom out, and feel.opening_lift (0.16 of the screen) further up the farm,
  down to the farm's resting view (FarmCamera.resting_position: the fit view kept inside the edges, else the
  spring-back jolted it at the end; at 0.82/0.22 the land's far edge showed in the corners, a sliver still does
  in the first frames). The light warms in: Farm3D.opening_cool takes feel.opening_dim (0.3) off saturation and 0.35 of that off brightness, easing out. Any tap ends it on the farm's
  view and is used up (_input); a drag or pinch takes over. 2.6 s (feel.opening_seconds; 0 turns it off). Test 565.
  tools/opening_shot.tscn renders it at 1200x540 in steps (--hour, --steps; ~4 min). Pushed after a full precheck
  (5.5 min). Local main had stale commits from an old polish-loop clone; kept as local branch main-stale-local.
- Next: the owner's picks (harvest juice; the opening glide: as is, calmer = shorter and less lift, or richer =
  longer with more warm-in); merge a pick by rebasing its branch on main, precheck, fast-forward push. While they
  wait: item 3, building and project moments (a placed building rises out of a scaffold with a dust puff and a
  thud; a finished project's reveal). Survey first: Feedback moments for placing, BuildingSystem, FxLayer.
- Run 5 (19 Nov 16:36-17:20 IST): the owner picked harvest juice RICHER (16:11): wow/harvest-juice rebased on
  main (conflicts: quality.json's _doc, NEXT.md, art_versions regenerated) and merged (ae40bd3; feel.produce stays
  the branch default, the richer one). Then, as the owner asked, collecting the same way, merged (ce1530f, branch
  wow/collect-juice): _show_collect flies the thing's own picture (ItemIcons.of(obj id), when made) through
  FxLayer.produce, climbs a note a collect (FarmGrid._run_at: _run for a point, not a plot) and a round ends on its
  count over the last thing (_sweep_end_at; _show_collect returns where it showed, INF when gone). Test 561.
  tools/juice_shot.tscn --collect renders a round (the new farm has 3 animals, so no "x5" in it; ~1 min).
  Open: the flyer is the animal or tree itself, not its product (milk, eggs, apples have no icons yet).
- Next: the opening glide still waits for the owner's pick (wow/opening-glide). Item 3, building and project
  moments, not started: survey Feedback "place"/"build" moments, BuildingSystem (finished construction and
  projects), FxLayer/WorldFx; a new look, so frames to the owner first. Local main of an old clone: kept as branch
  local-main-old-1636.
- Run 6 (19 Nov 17:36-18:00 IST): no pick yet for the opening glide. Item 3 built on wow/build-reveal (not merged:
  a new look, frames in the log under "Wow: waiting for your look"). The placing half already existed (Objects3D.drop_in:
  falls in, squash, dust, thud) and was kept. The finish: main._reveal on Game.building_upgraded level 1 (not an
  upgrade, not with a panel open) calls FarmCamera.visit(at, zoom, hold): go_to there, at least feel.reveal.zoom (2.0)
  times the resting zoom, hold feel.reveal.hold_seconds (2.6; 0 turns it off), then back to where the view was at its
  zoom; begin_drag, zoom_by or snap end the visit (no way back). Farm3D._transformed adds a dust burst when grand (the
  scaffold comes down). Test 580 (hud_test). tools/juice_shot.tscn --build=<id> renders it (frame placed, view moved
  aside, finished; ~1.5 min). Doubt: a building by the farm's edge cannot be centred (the edge limits hold the view).
  Not done: the project reveals (orchard, rare coop, a repaired vehicle): reuse FarmCamera.visit when those finish.
- Next: the owner's picks (opening glide; build reveal: as is, calmer = no zoom 1.8 s, richer = closer 3.2 s). Item 4
  (touch answers): animal sounds wait for the sound packs (item 6); a tree's leaf shake and a building's chimney puff
  can go first. Local main in this clone is still an old polish-loop tip (left alone; work detached on origin/main).
- Run 7 (19 Nov 18:37-19:15 IST): no picks yet (opening glide, build reveal). Item 4, touch answers, built on
  wow/touch-answers (not merged: a new look, a sheet in the log under "Wow: waiting for your look", calmer and
  richer, noon and dusk). The tap already bounced things, turned an animal's head and played its voice (FarmGrid._poke,
  Farm3D._poked); now Objects3D.touch_answer(o) says "sway" for a tree, "puff" for a finished building: bounce()
  sways a tree from its trunk instead of squashing it (_sway, rotation z in fading swings) and answer_touch lets
  leaves go round its crown or a puff rise from the roof, through one pooled DustPuffs (_touch). Numbers and tints in
  Balance feel.touch (calmer, the branch default: 8 degrees, 9 leaves of 0.15, 4 puffs of 0.3; richer: 12, 14 of 0.2,
  6 of 0.38). Test 582 (buildings_test; the build reveal's branch also took 580: renumber whichever merges second).
  tools/juice_shot.tscn --touch [--feel=<json>] renders a tree then a building tapped (~1.2 min). Doubt: the leaves
  are soft round flecks (dust3d shader), faint on noon grass. Found: a tree added while the farm shows keeps a
  footing-only box (reported for the fix lane); answer_touch measures what is drawn instead (_seen_box).
- Next: the owner's picks (opening glide, build reveal, touch answers): rebase the picked branch on main, precheck,
  fast-forward push. Then item 4's animal half (a small heart or note over a tapped animal; its sound waits for the
  sound packs, item 6), or item 5, light and sky (cloud shadows, warm windows at dusk; chimney smoke exists in
  decor_motion.gd and BuildingDress). Local main in this clone was an unrelated old history: reset to origin/main,
  the old tip kept as local branch old-local-main.

- Run 8 (19 Nov 19:37-20:10 IST): no picks yet (opening glide, build reveal, touch answers). Item 4's animal half,
  touch hearts, built on wow/touch-hearts (0348626; not merged: a new look, a sheet in the log under "Wow: waiting
  for your look", calmer and richer, noon and dusk). A loud tap on an animal with nothing to collect or give it
  (FarmGrid._act_on_object's last path) emits FarmGrid.petted; Farm3D._petted asks Objects3D.animal_top (over its
  back where it stands now) and WorldFx.hearts draws there: pooled WorldFx.Heart nodes (HEART_POOL 6, a curve
  polygon with a cream rim), tween-driven, hidden when done. Balance feel.heart (calmer, the branch default: count 1,
  px 22; richer: count 3, px 26; rise 28 and drift 44 keep it clear of the name over the animal). Test 584
  (hud_test). tools/juice_shot.tscn --pet [--heart=<json>] renders a tap (~45 s). Doubt: the fading heart's last
  frames touch the end of the name line. Collect and feed keep their own moments (no heart).
- Next: the owner's picks (opening glide, build reveal, touch answers, touch hearts): rebase the picked branch on
  main, precheck, fast-forward push. Test numbers: main now has 580-583, so build reveal's 580 and touch
  answers' 582 take new numbers when they merge (touch hearts is 584). Then item 5, light and sky (cloud
  shadows; warm windows at dusk: survey night_glow.gd; chimney smoke exists in decor_motion.gd and
  BuildingDress). Item 6 waits for the owner's packs. Local main of this clone was an unrelated old history: kept
  as local branch local-main-stale-1118.

- Run 9 (19 Nov 20:36-21:10 IST): no picks yet (opening glide, build reveal, touch answers, touch hearts). Item 5's
  first piece, cloud shadows, built on wow/cloud-shadows (923781d; not merged: a new look, a sheet in the log under
  "Wow: waiting for your look": as built and before at noon, richer at noon, both at dusk). The 2D farm had
  CloudShadows; the 3D farm had none. shaders/cloud_shade.gdshaderinc: cloud_light(xz, TIME), a few warped sines in
  world space (CLOUD_DRIFT, CLOUD_SCALE), read by ground3d, crop3d and master_solid (so grass, crops and models
  share one cloud); the global cloud_shade is set by main from the 2D shadows' strength through
  FarmMain.cloud_shade: none below Balance feel.cloud_shade_from (0.5: clear and overcast stay crisp, so
  ItemIcons, which now counts cloud_shade among its MOODS, can still keep pictures), up to feel.cloud_shade (0.22;
  richer 0.32, calmer 0.15); Quality cloud_shadows off on low. Test 590 (world3d_test). Changing crop3d re-exports
  the 105 plant files (tools/export_plants.tscn; the precheck says so). Render: look_shot --weather=partly_cloudy
  --quality=mid --views=all (~75 s a shot). Doubt: water is not shaded.
- Next: the owner's picks (five branches wait); rebase the picked one on main, precheck, fast-forward push (test
  numbers: build reveal 580 and touch answers 582 renumber; touch hearts' 584 is now taken on main too; cloud
  shadows is 590). Then the rest of item 5: warm lit windows at dusk (survey night_glow.gd, BuildingDress), a
  golden-hour sun, a soft rainbow after rain. Local main of this clone was an unrelated old history: kept as
  local branch stale-main-backup.

- Run 10 (19 Nov 21:36-22:10 IST): no picks yet (opening glide, build reveal, touch answers, touch hearts, cloud
  shadows). Item 5 surveyed: warm lit windows at night already exist (ModelKit.glass, set_window_glow from main) and
  so does the golden hour (Farm3D.set_daylight: a low warm sun, longer shadows; grade low_sun_warmth), so neither was
  rebuilt. The soft rainbow after rain was built on wow/rainbow (not merged: a new look, a sheet in the log under
  "Wow: waiting for your look": before and as built at noon, richer at noon, as built at dusk). WeatherLayer eases
  its own `wet` as SurfaceWeather does; static WeatherLayer.rainbow_strength(wet, rain, cover, dark, rule) (none
  while it rains, under cloud past max_cover or at night past max_dark; fades as the farm dries) drives one
  full-screen ColorRect with shaders/rainbow.gdshader (blend_add, colours washed by `saturation`), hidden when 0.
  Numbers in data/weather.json "rainbow" (as built: strength 0.2, saturation 0.7; richer 0.28, 0.85, width 0.085;
  calmer 0.14), Quality `rainbow` off on low. Test 591 (weather_events_test). Render: look_shot --weather=clear
  --after-rain [--rainbow=<json>] [--hour=17.4] --views=all (about 1 min). Full precheck passed on the branch
  (492 tests). Doubt: it is drawn over the whole farm (animals, trees), not behind it.
- Next: the owner's picks (six branches wait); rebase the picked one on main, precheck, fast-forward push (test
  numbers: build reveal 580 and touch answers 582 renumber; touch hearts 584 too; cloud shadows 590; rainbow 591;
  cloud shadows and rainbow both add a Quality field to data/quality.json: a small conflict). Items 0-5 are all
  built; item 6 (sound bed) waits for the owner's Kenney packs. The build's window ends at 00:40 IST, 20 Nov.
  This clone needed Godot downloaded (4.7.2, to /home/claude/godot); its stale local main was kept as local
  branch local-main-stale-backup.

- Run 11 (19 Nov 22:35-23:20 IST): no picks yet (six branches wait). Item 3's project half surveyed: the orchard,
  the rare coop and every building finished from a frame already go through Game.building_upgraded(uid, 1), so the
  build reveal (wow/build-reveal) covers them once picked. What had no moment was the starter Barn's repair: merged
  to main (d7f0c59) as a missing contact: Objects3D._step counts a broken Barn as a site, so repair_barn swells it in
  mended (grow_in: sparkles, dust, level_up_soft), and the Barn panel closes on the repair (hud_barn) so it is seen.
  Test 595 (world3d_test). tools/juice_shot.tscn --repair renders it (~70 s). Checked at 1x: the tarp roof gives
  way to the mended Barn swelling past its size. Not done: a vehicle's finished rust repair (RustSystem settles
  lazily, there is no "repair done" event yet); the build reveal's camera visit for the Barn repair (hook it in
  main._reveal's branch when build reveal merges: a Game signal for a finished repair, or emit from repair_barn).
  A local branch wow/project-reveal (build reveal rebased, nothing added) was not pushed.
- Next: the owner's picks; rebase the picked branch on main, precheck, fast-forward push. Test numbers on main now
  run to 595 (main took 590-594 for wear), so cloud shadows' 590 and the rainbow's 591 renumber too, as do build
  reveal 580, touch answers 582, touch hearts 584. The pre-push hook re-runs the 7.5 min precheck, so main can move
  meanwhile: a rejected push is fetch, rebase, regenerate art_versions, check again. The window ends 00:40 IST.

- Run 12 (19 Nov 23:35-23:58 IST): no picks yet. Run 11's open end built as a missing contact (reuses the mended
  Barn's swell, so merged without a pick): a vehicle's finished rust repair. RustSystem.finish_repairs (on Game's
  30 s stray_timer) closes finished repairs, which settled lazily, says each once (RUST_REPAIR_DONE) and calls
  objects_updated; Objects3D: a vehicle in for repair is built again (shows_of writes REPAIRING after its rust)
  and counts 0 in _step, so out of the workshop it is a step up and grow_in plays (sparkles, grand sound).
  Test 598 (rust_test). Render: tools/juice_shot.tscn -- --mended [--every=2] (~40 s); checked at 1x: the tractor
  swells red out of its rusted paint. Not done: a worn building's finished repair (WearSystem settles lazily the
  same way; apply the same finish_repairs + _step rule for the AUDIT "every similar module" rule), and a repair
  that finished while the game was closed (no moment on the first sync). The build window ends 00:40 IST.

## After the feature freeze (owner-approved ideas, 18 Nov)
- Animal life, full version ("utility AI", looks only): herds drifting together, babies following mothers, chickens
  scattering from the farmer, the dog companion trotting alongside, reactions to the farm's own systems.
- Launch: privacy-safe analytics (where players quit, what they buy, unused items) for tuning the economy from real
  play; clock-tamper protection against server time with cloud saves. No AI in the game itself.

## 19 Nov, late: gentler start, rare coop, late-game design
- Merged: young-farm daily seed help (Game._help_young_farm, Balance economy.young_farm_*), Welcome's last step
  pays 170, rare coop gives its 2 Mystery Eggs (goal reward "eggs"). Tests 585, 586.
- Waiting on the owner: the late-game design (climbing upgrade prices + building wear, Claude Doc
  "Farm game: a harder late game"). Build nothing of it before the six questions there are answered.
- 19 Nov, later: building wear and climbing upgrade prices built (docs/WEAR.md, tests 587-594). The bot's
  measure: wear is upkeep, not a coin sink (repairs under 1% of earnings with the owner's 40% cap). The idle
  coin pile is still open: asked the owner how sinks should scale with income.
- 20 Nov: the Economy audit (tools/audit.sh, .github/workflows/audit.yml, data/sim_targets.json) checks every bot
  style on two seeds; the bot was fixed to play like a player (it had never bought a building). Open: the
  plain style's want_days_pct (something to buy costing 1 to 3 visits) misses on some seeds: a pacing gap in
  the Market's middle levels, for the next economy pass.
- 20 Nov, later: pinning the bot's date (1 Nov 2026) made two flaky goal tests fail every time, and showed why
  they flaked: a daily "send gifts" job no player can do (the game has no way to send a gift: template
  removed until it has one), a "collect 3 chickens" job picked the morning they were all collected (per_day_of
  now counts only what will be ready today), and the young-farm help too small for a day's jobs after a day
  away (8 plots to 12).
- 20 Nov: the audit's new craft_payback_days target found crafting broken: eggs and carrots filled the stall's
  100 bushels and the Bakery waited a year for wheat (payback 370 to 460 days). crafting.bushel_kind_cap (20 of
  one kind) and recipes.sell_markup 1.5 to 2.0: 25 days. Still over the 14-day target: one slot and three
  visits a day allow about 3 crafts a day; options are for the owner (markup, Bakery price, a second slot).
