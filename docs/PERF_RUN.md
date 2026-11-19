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
