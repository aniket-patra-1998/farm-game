# The loading and performance build (owner-approved 18 Nov 2026)

Hourly sessions, 20:50 IST 18 Nov to 20:35 IST 19 Nov (extended by the owner at 08:31; it runs alone from 08:35), make the farm load and run like a big commercial farm game:
the farm opens fast and whole, and a large, crowded farm stays smooth on a low-end Android phone. The look must
not change (same models, colours and motion; an optimisation that changes how something looks is reported, not
built). Follow CLAUDE.md and docs/POLISH.md's "Safe merging and no overlap". Log: the Claude doc "Farm game: polish
loop log", rows prefixed "Perf:". Measure before and after every step, with what this container CAN measure
truthfully (it draws in software: wall-clock time and fps here mean nothing for a phone): draw calls and triangles
(tools/perf_probe --quality=low --size=2400x1080 --fill, whole farm and playing zoom), CPU time to build the
showcase cold and warm (headless), the number of distinct materials and shaders a farm draws with, memory. Keep a
change only if these improve and the look is the same. When phone_bench.yml has reports (the run summaries, or
the log doc), they decide: read them first and fix what they show.

## Why we are slower than Hay Day or FarmVille (the diagnosis, 18 Nov)
They draw pre-made pictures or prefabs from shared atlases in a few batched draws, with few, precompiled shaders.
We build many things in code at load (trees, blooms, decorations, buildings from boxes), adjust every copy, use
many custom shaders, make ~1,000 draws a frame on a filled farm (trees ~5 each, animals 1 each, unbatched), and run a
script per animal per frame. Already done: threaded file loading, a loading cover that waits for the whole farm
and builds at full speed under it (Game.farm_opened, Objects3D.COVERED_BUDGET_MS).

## Steps, in order (easy gains first)
1. The Bloom Garden's 103 ms build (blooms made in code): draw them from the exported bloom files, shared.
2. Tree batching: the design in docs/NEXT.md "Phone performance" (a tree = its still parts in the look's shared
   batch + its fruit in a batch keyed by ripening time; shake, lift, drop and outline follow the stand-in).
3. Bake what is still built in code at load (trees' and decorations' stand-ins, orchard and garden plants) into
   exported files (docs/ASSETS.md), so loading never builds geometry.
4. Shaders: count the shader variants a farm uses; merge near-duplicates into shared ones where the look is the
   same; warm every one up under the loading cover (one hidden draw each).
5. Animals as batches with their poses in the shader (docs/NEXT.md), only where the look and motion stay the same;
   their per-frame scripts thinned (only animals on screen think; animation budget already round-robins).
6. Lower the phone budget's limits (data/perf_budget.json) to each new measure, so it never slips back.
Only report, never build: a change to how anything looks, far-zoom picture stand-ins (impostors), a new feature.

## Rules
- One step per branch (`perf/<step>`), tests where a rule is involved, data-driven, applied to every similar module.
- Merge only a finished step that measurably helps: fetch, rebase on main, full precheck, fast-forward push, never
  force, never a merge commit; a half-done step stays on its branch with a handoff in docs/NEXT.md ("Perf").
- Re-export art when a builder changes (data/art_sources.json); never render beside a precheck or push.
- Frugal: read only what you need; no sub-agents; no model change; never send pictures.

## Phone measurements (the only measure that counts; 18 Nov)
The cloud container has no GPU and draws in software (~0.7 s a frame): it cannot judge loading or smoothness on a
phone, and shader compiling, likely the biggest phone cost, does not show there at all. So every claim is measured
on real phones:
- LoadBenchmark (scripts/debug/load_benchmark.gd): the showcase opened cold, your own farm, the showcase warm, then
  5 s of play at the playing zoom; built and whole times, long frames (first draws, shaders), frame times, draws.
  One "BENCH {json}" log line and user://load_benchmark.json. Runs by itself in the benchmark APK (export feature
  "benchmark", app "Farm Game (benchmark)", installs beside the test build), or from Settings > Testing >
  Measure loading (the report is copied to the clipboard).
- .github/workflows/phone_bench.yml: Firebase Test Lab installs the benchmark APK from the "Latest phone build"
  release on real phones (nightly at 02:10 IST and by hand; by default one low-end phone, a Galaxy A05s (Snapdragon 680, Adreno 610), so the free 5 runs a day go further) and puts each phone's report in the run's summary.
  Setup once: a Firebase project (free Spark plan: 5 physical-device runs a day), a service account with the
  roles Firebase Test Lab Admin and Storage Object Viewer, its JSON key as the repo secret FIREBASE_SA_KEY, the project id
  as the repo variable FIREBASE_PROJECT; optionally FTL_DEVICES (each run prints the phones available).

## Phone-driven from 18 Nov 23:00 (owner: "real wins, not proposals")
Real phones now work (Firebase project farm-game-20372; the Spark plan allows 5 physical-phone runs a day, so
by default one phone a run: a Galaxy A05s, low-end, Adreno 610). From now on:
- Every run starts from the newest phone report (`gh api repos/aniket-patra-1998/farm-game/actions/workflows/phone_bench.yml/runs`,
  then the run's artifact "phone-bench-reports"). Its biggest cost is the next thing worked on, whatever the step list says.
- After merging a change that should move a phone number, start one phone run (`gh api -X POST
  repos/aniket-patra-1998/farm-game/actions/workflows/phone_bench.yml/dispatches -f ref=main`) once the phone build
  (apk.yml) for that commit is published, and log the before and after phone numbers. At most one phone run per hour
  and 4 a day (count today's runs first); the nightly run is the fifth.
- A run merges a real, measured win or leaves a precise handoff: never only a proposal.
- Where the wins are, biggest first, to be confirmed by the phone report:
  1. First-draw stalls (long_frames, longest_ms): shaders compiled the first time something is drawn. Warm every
     material and shader variant the farm uses under the loading cover (one hidden draw each, or the renderer's
     pipeline cache); fewer variants (merge near-duplicates where the look is the same).
  2. Loading (built_ms, whole_ms): the APK is ~205 MB and art/ ~174 MB. Find what is loaded at start and how big:
     oversized textures (resize to what the phone shows, VRAM-compressed ETC2/ASTC), meshes with more triangles
     than a phone sees, files loaded but not needed for the first screen (load them later, threaded).
  3. Frame time while playing (avg_ms, p95_ms, draws): batching (MultiMesh through Instancer) of trees, crops,
     animals, fences and decorations; per-frame scripts thinned; anything off screen not processed.
  4. The quality the phone gets: Quality's existing levels picked for the device by a short measured test at first
     start (never a new look; the levels exist). Report it before building if it would change the default phone look.
- Finding (18 Nov 23:10): Test Lab skips the Galaxy A13 (Exynos 850, Mali-G52, Android 14) and the Galaxy A10 as
  "incompatible" while the Pixel 6 and the Galaxy A05s run. The A10 is 32-bit only (we ship arm64 only); the A13 is
  arm64, so the likely cause is the Vulkan level the Mobile renderer's manifest requires, which would hide the game
  on the Play Store from many low-end Mali phones. The workflow now prints each skipped phone's details: confirm the
  cause, then fix it (the manifest's Vulkan feature not required, with the Compatibility renderer as the fallback on
  phones without it) and prove it by running on the A13. This is a top item: a phone that cannot install the game
  is worse than a slow one.
- Settled (19 Nov, owner): the A10 and A13 run 32-bit Android; every Android export now ships 32-bit and 64-bit ARM
  (test 535), so they install. A phone always plays in landscape (Display.ORIENTATION, held after the start).

## Order of work from 19 Nov 08:35 (owner: keep the performance build going)
1. Why the app dies in the foreground on the phone during the benchmark (runs 7 and 8): a crash would hit players
   too. Read the logcat's last lines before "has died" (signal, OOM, ANR); switch the benchmark to Test Lab's
   game-loop type if Robo is what ends it, so the benchmark runs every phase to its end.
2. The start: 8.3-9.3 s on the Galaxy A05s before the first screen (~5.5 s before Game is made: the engine and
   compiling ~50k lines of script; ~1 s data and save; ~2.2 s main._ready). Split it with the start marks, then cut
   the biggest part, nothing seen changed.
   If compiling is the big part (expected): compile less before the first screen. Today the main scene and Game
   pull in nearly every script at once (the whole HUD, every panel, every world3d builder, every system). Split
   them: the first screen needs the farm, the camera, the top bar and the systems that run a farm; panels,
   sheets, the Market, crafting, collections, the showcase's dressing, debug and benchmark tools and similar are
   loaded by path when first opened (or on a worker thread right after the farm appears), never named as a type
   from the start-up scripts. Measure lines compiled before the first screen (and the "scripts" mark) before and
   after; target well under half. Merge it in safe slices (one area at a time, tests passing), not one big bang.
   Slim it too (owner, 19 Nov 08:41: "do we need 50k lines?"). Measured: 49.7k lines in the game's scripts, of which
   37.6k are code (5k comments, 7k blank; tests and tools, 19k more, never ship). By area: world3d 14.9k (the 3D
   models built in code), systems 5.8k, the top-level scripts 4.9k, hud 3.7k, ui 3.3k, world 2.1k, autoload 1.4k.
   Scripts already ship as compressed binary tokens (script_export_mode=2). Where the phone compiles less:
   a. Code only needed to MAKE art that is already exported as files (art builders, docs/ASSETS.md) does not belong
      in what a phone compiles at start: the game loads the files; the builders stay in the repo for the export
      tools. Find each world3d builder the game still names at run time only to build a look that has a file.
   b. Dead code: functions and scripts nothing calls (a script lists every caller; tests do not count as callers).
   c. Logic repeated across similar modules, merged (docs/AUDIT.md's rule). Features turned off by docs/V1.md are
      never deleted (CLAUDE.md): they are loaded only when on.
   Log the line count before the first screen at each merge. Nothing a player sees may change.
3. Loading and play measured on the phone once the benchmark finishes, then the biggest of those.
Phone runs: the Galaxy A05s by default; the Galaxy A13 again now that 32-bit ships (4b84c6b) to confirm it runs.
- 19 Nov 08:45: the first phone run of the build with 32-bit ARM (4b84c6b, on the Galaxy A13) failed in Test
  Lab's validation ("Matrix failed during validation"), before any phone ran. Find why first (the matrix's
  invalid-matrix details: `gcloud firebase test android run` with `--format=json`, or the REST API's
  testMatrices.get on the matrix id: e.g. a malformed APK, quota, or the device/version pair), since it may mean
  the 32-bit build broke the APK; then run the A05s and the A13 on it.
- 19 Nov 09:40 (perf run 13): that failure was TEST_QUOTA_EXCEEDED (5 phone runs a day, used on 18 Nov Pacific
  time), not the APK; phone runs again after 13:30 IST. Item 1: the app quits or dies at ~250 s, then Robo
  relaunches it and the relaunch's start-only report hid the finished one; phone_bench now keeps the done (else
  longest) report and prints how each process ended (cc3134d). Item 2, slice 1: the HUD's panels and the building
  sheet load by path, 37.6k -> 34.1k lines compiled before the first screen (NEXT.md, Perf run 13).
- 19 Nov 10:40 (perf run 14): slices 2 and 3 of the start (2D art and 2D animals loaded by path; AnimalGait):
  34.1k -> 31.8k lines before the first screen (tools/start_lines.py counts them). No phone run yet (quota).
- 19 Nov 11:40 (perf run 15): slice 4 of the start (the debug tools by path, StartMarks): 31.8k -> 31.4k lines.
- 19 Nov 12:10 (perf run 16): slice 5 of the start (the pictures' renderer, scripts/ui/icon_maker.gd, loaded by path a
  frame after the first screen; ItemIcons is the lookup): 31.5k -> 30.7k lines (main had grown to 31,546).
- 19 Nov 13:20 (perf run 17): slice 6 of the start (the moment cards by path: the level-up, a mystery's reveal and
  the away card are made when first needed; the level-up in its own empty layer where it stood): 30,741 -> 30,352
  lines before the first screen; headless scripts - engine median 1,666 -> 1,636 ms, hud mark 2,171 -> 2,133 ms.
- 19 Nov 14:05 (perf run 18): the phone run of 13:31 (A05s, 4054e3f) finished the benchmark (item 1 settled: it quits
  by itself after "done"). Startup 16.5 s cold, 7.5 s relaunched; own farm whole 31.7 s (the cover's 30 s cap: the
  A05s never draws under 40 ms); play 94.9 ms a frame. Merged: the cover also lifts on a slow phone's steady pace.
  Item 3 (play, ~10 fps on the A05s) is next.
- 19 Nov 15:10 (perf run 19): the phone run of 14:31 (657a40b) confirmed the cover fix (own farm whole 31.7 -> 7.7 s)
  but played at 256.5 ms a frame on mid: AutoQuality ignored every frame over 250 ms, so the A05s was never stepped
  down. Merged eb810f7: a steady run of slow frames counts, and a window that slow goes to the last rung.

- 19 Nov 17:20 (perf run 21): the phone's play frame is GPU-bound. The play phase now reports medians of the
  farm view's render CPU and GPU time (69ecce5); the phone run of 17:08 IST (A05s) played on low at 124.2 ms a frame
  (p95 257.8: the phase began on mid) with GPU 93.6 ms, render CPU 3.4 ms, 380 draws, 215k triangles (medians).
  So draws are not the wall; the GPU is (vertex or pixel work). The benchmark's new "gpu" phase (after play) hides
  each owner's meshes and halves the 3D resolution, and says how much GPU time each takes away: the next phone run
  says whom to cut.

- 19 Nov 18:10 (perf run 22): no phone run possible until the nightly (today's 4 used). Slice 7 of the start: what a
  building is (BuildingSpec: its description, the ground it takes, its yard's spots, its parts' names) apart from
  the builders (BuildingModel, BuildingDress), which load by path only when a look must be built (a look kept by
  ModelStore never needs them). 30,591 -> 28,526 lines before the first screen; headless, 7 alternating pairs:
  scripts - engine median 1,482 -> 1,197 ms, hud mark 1,894 -> 1,810 ms (headless keeps no looks, so there the
  builders compile during "world" instead: +148 ms). The 248 exported building files come out byte-identical.
- 19 Nov 19:10 (perf run 23): still no phone run (today's 4 used; the nightly is next). Slice 8 of the start: what a
  crop form is (CropFormSpec: which crop is which form, each form's numbers, the shared look) apart from the
  builders (CropForms), which load by path (CropFormSpec.builder()) only when a crop's look must be built (a crop
  drawn from its exported file never needs them; the pictures are made after the first screen). 28,618 -> 27,782
  lines before the first screen; headless, 16 alternating runs each: scripts - engine median 2,102 -> 2,052 ms, hud
  mark 3,070 -> 2,956 ms (this container ran slower than run 22's). The 105 exported plant files carry the same
  meshes (every surface's arrays compared).
- 19 Nov 19:30 (perf run 23): slice 9 of the start: the decorations' builders (DecorModel) load by path
  (Objects3D.decor_model()) only when a look must be built (looks are kept by ModelStore); a mystery young, built
  fresh as it grows, has its own small builder (YoungModel) and the decorations' colours their own place
  (DecorPaint). 27,782 -> 26,947 lines before the first screen.
- 19 Nov 20:00 (perf run 24): no phone run possible (today's 4 used; the nightly is next). Slice 10 of the start:
  what a tree is (TreeSpec: its shape, whether it stands by itself, its sway, bark and far-look key) apart from the
  builders (TreeModel), which load by path (TreeSpec.builder()) only when a tree's look must be built (a lone tree
  comes from its file, the woods from ModelStore). 27,066 -> 26,613 lines before the first screen. The 105 exported
  plant files carry the same meshes (every surface's arrays hashed before and after).

## Owner approvals (19 Nov 15:21): frame rate on slow phones
Measured on the Galaxy A05s: playing the showcase at zoom 1.6 runs ~95 ms a frame on low (386 draws, 218k
triangles) and ~256 ms on mid (541 draws, 498k triangles). The owner approved both, so they are built now (they
are no longer "report only"):
1. Simpler distant objects: trees, buildings, decorations and animals far from the camera drawn with simpler
   models (LODs) or flat picture stand-ins (impostors) at far zoom; at the playing zoom nothing visible changes.
   Target on low: under 150 draws and 100k triangles at the playing zoom on the showcase.
2. Lower 3D resolution on low quality only: the 3D world renders at ~70% (Quality field, e.g. scale_3d 0.7, FSR or
   bilinear) and is scaled up; the interface stays at full sharpness. Mid and high unchanged.
Measure each on the phone (play avg_ms, p95, draws, triangles) before and after.

## Animations: is there a lighter way? (owner's question, 20 Nov; measured before anything is changed)
- Phone (nightly run of 20 Nov, A05s, low, main 8035eb1): play 96.2 ms a frame, GPU 94.2 ms, render CPU 3.3 ms, 380
  draws, 215k triangles. GPU by owner: Ground3D 47.4, Animal3D 23.7, Objects3D 20.7, the rest within the noise (about
  10 ms either way); 40.1 ms is left with the 3D resolution halved, so over half the frame is pixels.
- The same view on a computer (a temporary probe, not kept): 22 of the showcase's 112 animals are in view, all made
  as files, 16 shapes and about 3,560 vertices each; they are 75k of the view's 215k triangles (35%) and 30 of its
  draws. Posing one costs the CPU about 15 microseconds: all 22 are 0.3 to 0.5 ms of the 4.2 ms every script on the
  farm takes a frame. So the scripts are not the cost: tidying the posing code would not be felt.
- What is cheap already: trees, crops, water, flames, butterflies and falling leaves move in their shaders or as
  batches; their scripts are inside that 4.2 ms.
- Not known yet: how much of the animals' ~24 ms is animating them (their shapes should be blended again on the GPU each
  time one is posed) and how much is drawing 75k triangles. The benchmark's `gpu` phase now reports
  `animals_posing` (GPU ms that go away while the animals stand still, still drawn): the next phone run says.
  If it is small, the gain is in the animals' triangle count (simpler levels nearer the camera), not in how they
  are animated; if it is large, posing fewer animals a frame or moving the always-on motions into the shader pays.

## The tree polish made the farm lag (owner, 20 Nov, after PRs 18 to 21 were merged): found and fixed
Measured on a computer at the phone benchmark's playing view, showcase farm, low quality, 900 frames at a time:
- Scripts, a frame: 8.8 ms before the merges with no frame over 33 ms; 45 ms after, with 200 to 300 of 900 frames
  over 33 ms and single frames of 250 to 300 ms. Cause: `TreeLife.crown_of` asked a tree's height with
  `ScaleGuide.height_of`, which builds the tree's whole model to measure it, for every falling leaf and fruit (a
  leaf every few seconds, dozens in a gust). Now it asks the farm (`Objects3D.height_of`: the box each view
  already keeps). After: 8.7 ms, no frame over 33 ms. `trees_test` 606 holds it.
- Triangles in view: 215k before the merges, 286k after. A tree's fruit is kept out of its simpler levels (it turned
  into gems), so every ripe tree drew all of it at full roundness: about 2,470 triangles a tree, more than the rest
  of the tree at that distance. Now fruit round the back of the crown is not made (the camera does not turn), a
  fruit is 8 by 5 and a cherry 6 by 3: 242k in view, the trees 75k of it (119k before the fix). `trees_test` 607
  holds it. Still about 30k over what the trees drew before the polish: fruit with levels of its own (a coarse far
  level made by hand, not by the simplifier) is the next step if a phone run says the trees still cost more.
- Lesson kept as a rule here: a thing that happens every frame or every few seconds must never call
  `ScaleGuide.height_of` or `model_of` (they build a model); and a new moving thing is measured over a long
  stretch (average and frames over 33 ms), not by a median, before it is pushed.


## The thorough check, and what it fixed (owner, 21–22 Nov: "fix all the issues, we keep circling back")
The report: "Farm game performance check, 21 Nov 2026" (https://claude.ai/artifact/S8uvmDQePTUpfwN3gt65jE). What
was found and done:
- **The check that was missing.** `tools/session_probe` plays the real game through `ScenePlayer` (still, pan,
  zoom, every panel, placing, limited animals, a harvest, rain, storm, snow, fog, night, an hour) on a new farm, a
  30-day farm, the showcase and a full farm, and names what each long frame went to (PerfReadout parts). CI and
  the pre-push check hold it to `data/perf_targets.json` (`--targets`, scaled by TestSuite's yardstick). The phone
  benchmark plays the same scenes (`scenes`, `filled_scenes`) and reports in parts (BENCH_PART lines: a phone's log
  cuts a line at about 4 KB).
- **Placing froze a full farm** (104 ms PC, ~1 s A05s): every change looked at all 614 things. `Game.changed_uids`
  says what a change touched; Objects3D builds that and its neighbours, wear settles those; occupancy is not
  rebuilt when it holds; the ground's shade is painted on a worker and only the grass it reaches is laid again; the
  ten-second safety look, ready and rust signs no longer walk the farm in one frame. Strays, bunches, hives,
  finds, the shed, the Barn and mastery signs say which thing changed. Now ~25 ms at most on a PC (test 613).
- **A new farm's first seconds stalled** 3–5 times up to 100 ms: sounds were made one a frame on the main thread.
  Now on a worker (test 617).
- **Panning into a crowd** posed 200 animals in one frame (242 ms): at most `Animal3D.POSES_MOST` a frame now.
- **"Script time" was misread**: TIME_PROCESS is the worst frame of each second. `FrameClock` times this frame's
  scripts; AutoQuality and the benchmark read it (test 615).
- **Low-end phones start on low** (`low_end_gpus`, `low_end_memory_mb` in quality.json; test 614), and the
  benchmark holds one level throughout (`AutoQuality.paused`).
- **The ground's 41 ms on the A05s** is split by part in the benchmark (Ground3D/Meadow, Lawn, Tufts, Flowers) so
  the fix goes where the time is. Still open, with the app's size (351 MB) and opening times.
- **A level gained or the day turning froze a full farm for 8 s** (PC; far longer on a phone): making the day's
  jobs looked at every recipe ten times a call (Catalog.recipes_of) and asked every ingredient of every item. Now
  46 ms (test 622). The catalog's recipes are sorted by building once; in_release is remembered.
- **The first rain froze the A05s for 2.3 s** (its streaks and splashes drawn the first time): the weather is drawn
  once, faintly, under the first loading cover.
- **The A05s, 22 Nov, low from the start**: 102 ms a frame (GPU 101, scripts 28, render CPU 5). The ground's
  shading is 38 ms of it (drawn plain and unlit instead); its painted look saves 237 ms. The benchmark now tries
  the ground's shader part by part (unlit, no grain, no shade map) to say which part costs.
- **The first rain froze the A05s 1.2 s twice** even so: rain brings haze, and turning the scene's fog on makes the
  GPU build every material's fog variant at once. Fog is on, at no density, for a few frames under the first
  loading cover (Farm3D.FOG_WARM_FRAMES).
- **The ground's shade and wear (17 of 102 ms on the A05s)** are painted into the lawn's still look in a light
  second pass (ground_bake.gdshader `with_shade` over `base`), painted again after each change; the old painting
  stays on screen until the new one is ready. The lighting (30 ms) is what remains of the ground's cost.
