# The wow build (owner-approved 19 Nov 2026, 12:27: "the game is missing a lot of wow factor")

Hourly sessions, 12:35 IST 19 Nov to 00:35 IST 20 Nov, make the moments a player remembers: the first seconds,
the thing done a thousand times (harvest), the big rewards, a farm that answers every touch, and light and sound
that make it beautiful. Follow CLAUDE.md, docs/POLISH.md (owner's taste: soft, warm, weighty, restrained; picked
looks are kept) and its "Safe merging and no overlap"; the phone performance build runs beside you (rows
"Perf:"): every effect is cheap on a low-end phone (shaders and pooled particles, no per-frame script per thing,
a costly look is a Quality field; hold data/perf_budget.json). Log: the Claude doc "Farm game: polish loop log",
rows prefixed "Wow:".

## How a wow item goes in (new looks wait for the owner's eye)
Each item is built as a working prototype on its own branch `wow/<item>`. When it is good, upload into the log
under "Wow: waiting for your look" a few frames of it in motion (or 2-3 variants side by side: calmer / richer),
noon and dusk, 20:9, and describe it in two lines. Merge to main only after the owner picks (in the log or
chat). While one waits, build the next. Refinements of what exists (timing, a sound layer, a missing
contact) merge directly, as docs/ART_POLISH.md allows. Survey first: what exists already (ambient_life.gd has
butterflies, fireflies and birds; night_glow.gd; the level-up is fireworks only and stays so) is refined, not rebuilt.

## The items, in order (biggest felt gain first)
0. Icons: the owner picked option C (19 Nov 12:26): a soft still gold glow behind money and rewards (coin, gem,
   star, ribbons, a reward to collect) and a soft blue-white glow behind something new waiting (a letter, a new
   item); every other icon plain. One shared glow image drawn behind, never animated. Picked: build and merge.
1. Harvest juice: the produce pops out of the plot, arcs and flies to its counter in a short sparkling trail; a
   sweep over many plots chains, each pop a note higher, with a small "x8" combo float at the end. Restrained,
   never a slot machine. Same for collecting from animals, trees and buildings.
2. The opening: when the loading cover lifts, a 2-3 s camera glide settles onto the farm (from a little higher
   and wider), the light warming in; skippable by a tap; only the first open of a session.
3. Building and project moments: a placed building rises out of a little scaffold with a dust puff and a wooden
   landing thud; a finished project (the orchard, the rare coop, the rebuilt tractor) gets its reveal: the camera
   glides to it, a burst of leaves or sparkles, a short fanfare, then back.
4. A farm that answers every touch: a tapped animal squashes, makes its sound and shows a small heart or note; a
   tapped tree shakes its leaves; a building's door or chimney puffs. Cheap, once per tap.
5. Light and sky: drifting cloud shadows over the farm, chimney smoke, warm lit windows at dusk, a golden-hour
   sun with longer softer shadows, a soft rainbow after rain (lighter, as the owner parked it).
6. (Last, owner 19 Nov 16:42: after everything else, with the Kenney CC0 packs the owner will attach.) Sound bed: day and night music variants, a soft farm ambience that changes when zoomed in (animals near you
   heard more), and the reward sounds tuned as one family with the new wooden tap.
Owner's picks: harvest juice RICHER (19 Nov 16:11). Declined: haptic patterns ("keep the game simple but
awesome"): no new vibration work; prefer fewer, stronger moments over many small ones.
Only report (never build): a new feature (e.g. a farm postcard to share, visitors), a change to a picked look.
Each run also adds ONE new wow idea of its own, ranked by gain for effort, to the log's "Reported, not built".
