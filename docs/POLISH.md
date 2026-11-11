# Polish: what the game lacks against how builder games are made

The art is kept (it is a good base). What is missing is the layer on top of it that makes a farm feel finished.
Each gap below is a general system, not a fix for one item, so it improves every object at once.

Sources that could be checked: a developer's post-mortem
([PocketGamer.biz](https://www.pocketgamer.biz/behind-the-scenes-how-the-little-details-in-game-development-can-make-the-biggest-impact))
says to add small environmental effects for a living world, to playtest for moments where nothing interesting
happens and fill them, and to make scenery tappable; a juice guide
([itch.io](https://itch.io/blog/1059831/making-a-game-feel-juicy-with-simple-effects)) lists squash and stretch,
particles, layered randomised sound, easing, and idle and reactive animation. Everything else here is general
practice in mobile builders as I know it, not something I could confirm from a source.

| # | Gap | What builders do | Here | Status |
|---|-----|------------------|------|--------|
| 1 | Ground dressing | grass tufts, flowers, stones round every object, so nothing sits on bare grass | none | **done**: `Dressing` (data/dressing.json), every building, decoration and vehicle; trees get their own base |
| 2 | Foliage and form | many small lit planes, sun/shade colour shift, rough outline | smooth same-colour balls | **done** for trees (faceted clumps, yellow-green sun, blue-green shade, roots) |
| 3 | Size hierarchy | each kind its own scale (chicken, goat, cow, horse) | all about one size | **done**: `scale` per animal family, 0.7 to 1.12 |
| 4 | Colour and light | saturated palette, warm light, lifted shadows, night that stays readable | desaturated, murky dusk and night | **tuned** (saturation, ambient, moonlight); needs a look at every hour |
| 5 | Silhouette variety | each building recognisable by shape alone | similar block and gable | **partly**: two-storey top sizes; mid sizes still alike |
| 6 | Idle motion everywhere | flags, smoke, windmills, birds, butterflies, hanging things swinging | smoke, water, wind in plants | **open**: flags and awnings static, no ambient creatures |
| 7 | State read at a glance | ready glow, bubbles with icons, full flags, produce piling | bubbles, count signs | **partly**: full pennant, bigger piles; ready glow open |
| 8 | Action feedback | squash and stretch, particles, floating numbers, layered sound | squash on collect, some sound | **open**: coin and XP pop-ups, harvest particles, dust on plow and place |
| 9 | Night | lit windows, lamps, fireflies, glow pools | windows glow, light pools on the ground | **partly**: lamps, fireflies open |
| 10 | Crops | dense, full beds, size by growth, rows | five plants per plot, bigger | **tuned**; no per-crop detail yet |
| 11 | Terrain variety | paths, worn ground near doors, patches, water edges | wear map, tufts | **open**: paths, doorstep wear, borders |
| 12 | Tests for looks | contact sheets and state sheets compared as pictures | sheets exist | **open**: no automatic check; only a person looks |

Next, in the order that adds most: 8 (action feedback), 6 (idle motion and ambient life), 11 (paths and ground),
5 (more shape difference at each size), 4 (a look at every hour of the day).
