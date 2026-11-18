# The loading and performance build (owner-approved 18 Nov 2026)

Hourly sessions, 20:50 IST 18 Nov to 08:35 IST 19 Nov, make the farm load and run like a big commercial farm game:
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
