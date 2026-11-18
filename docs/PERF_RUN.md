# The loading and performance build (owner-approved 18 Nov 2026)

Hourly sessions, 18:55 IST 18 Nov to 02:55 IST 19 Nov, make the farm load and run like a big commercial farm game:
the farm opens fast and whole, and a large, crowded farm stays smooth on a low-end Android phone. The look must
not change (same models, colours and motion; an optimisation that changes how something looks is reported, not
built). Follow CLAUDE.md and docs/POLISH.md's "Safe merging and no overlap". Log: the Claude doc "Farm game: polish
loop log", rows prefixed "Perf:". Measure before and after every step (tools/perf_probe --quality=low
--size=2400x1080 --fill, and showcase opening time under LoadingCover); keep a change only if it measurably helps.

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
