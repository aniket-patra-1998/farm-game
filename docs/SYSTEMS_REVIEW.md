# Systems review: what to make better, more interactive, state of the art

One row per system, judged on four things: **rules** (matches FarmVille), **feel** (motion, sound, haptics,
feedback), **life** (the world reacts, shows state), **scale** (data-driven, cheap on a low-end phone).
Marks: strong / ok / thin / missing. Written Nov 2026 from the code, docs/AUDIT.md and docs/POLISH.md.

## The world you see

| System | Rules | Feel | Life | Scale | Best next upgrade |
|---|---|---|---|---|---|
| Plots and crops (FieldSystem, Crops3D) | strong | ok | ok | strong | Planting/plowing trails the farmer's tool; crops sway with wind (done) but ripe crops should shimmer and "call" (a soft pulse) so ready plots read from afar; harvest streak (chain-tap combo) with rising pitch. |
| Farmer (PlayerSystem, Farmer3D) | strong | ok | ok | ok | Tool-specific animations (hoe, seed toss, scythe, bucket), idle fidgets, footstep dust, look-at the thing being worked; avatar customisation (missing). |
| Animals (Animal3D, AnimalMotion, minds) | ok | strong | strong | ok | Off-screen throttling (done for homes, do for free animals); animal needs shown above the head (hungry, happy) via one shared bubble layer; petting, following, sleeping at night. |
| Animal homes (BuildingFill) | ok | ok | strong | ok | Interior tour: tap shows residents' names and ready timers; babies in Nursery; feed troughs that empty and refill. |
| Trees and orchards | ok | ok | strong | strong | Fruit appear one by one as ripe, picked fruit falls; seasonal blossom/autumn colour from the calendar. |
| Buildings (BuildingModel, sizes) | ok | ok | ok | strong | Detail kit (ridge, fascia, lanterns, downspouts, planting, props) from one "dress" spec; per-size character at mid levels; Barn/Farmhouse/Garage/Shed sizes. |
| Contents of holders (BuildingStock, new) | ok | thin | ok | strong | Add Feed Mill (bushels), Storage Cellar, Silo, Nursery babies as stock kinds; one data line each. |
| Decorations | thin | thin | thin | ok | Biggest visual gap: each decor model is simple. Give decor a state machine (idle, tapped, night) and animated parts (fountain spray, windmill, flags exist) via DecorMotion; props kit shared with buildings. |
| Ground, light, weather, day cycle | ok | ok | strong | ok | Seasons (snow, autumn, spring) on the real calendar; puddles and wet-ground sheen after rain; check colour at every hour. |
| Ambient life (AmbientLife) | ok | ok | strong | strong | Add water-side life (frogs, dragonflies), chimney smoke drifting with wind, leaves falling from big trees. |

## Feedback and interface

| System | State | Best next upgrade |
|---|---|---|
| Feedback layer | Tap bounce, drop-in, grow-in (new), harvest pop, dust, sparkle | One `Feedback` service (kind -> motion + fx + sound + haptic + floating number) so every system calls `Feedback.play("collect", at)`, and new systems get polish for free. Today each call site wires its own pieces. |
| Sound | strong recipes, voices | Ambient bed by time/weather (crickets, birdsong, rain), spatial pan/volume by camera distance, per-surface footsteps. |
| HUD (hud.gd, 1,839 lines) | works, big | Split into panels (TopBar, Toolbar, Market, Barn, Book...) each its own scene/class; animate counters (count-up coins/XP), pulse the button that has something new, one-handed reach layout for phones. |
| Tutorial and onboarding | ok | Spotlight the real UI element with a pointing hand; skippable; contextual tips once per feature. |
| Notifications | thin | "Ready" badges over buildings and on the toolbar; local notifications when crops ripen (Android). |
| Camera | strong | Double-tap to focus, "go to next ready thing" button, smooth follow when the farmer works. |

## Rules and progression

| System | State | Best next upgrade |
|---|---|---|
| Economy (market, coins, gems, XP) | ok | Market tabs, limited-time items, gem-only items marked; a daily "offer" board. |
| Crafting (bakery, winery, spa) | strong | Order queue visuals (items bubbling, steam), recipe levels with mastery stars. |
| Vehicles and fuel | ok | Biplane instant-grow; vehicles visibly work the field in a line, trails of dust, fuel gauge on the vehicle. |
| Nurture (mystery young, bulbs) | ok | Bulbs/flower food (missing), baby animals growing visibly day by day. |
| Strays, daily, collectibles, ribbons, mastery | ok | Goals: quest chains (data/quests.json) are the biggest missing progression system; they give the player a reason to open the game. |
| Neighbours (simulated) | missing | NPC neighbours with daily visits, gifts and requests (parts/gems stand in until online). |
| Water, Feed Mill, dogs, pens, cellar | missing | Listed in docs/AUDIT.md; each is one system plus a stock/fill entry now that the layers exist. |
| Seasons and events | missing | Weekly themed items and seasonal events run from the calendar and data. |

## Engineering

| Area | State | Next |
|---|---|---|
| game.gd (1,350 lines) | plots split out; placement and selling remain | PlacementSystem. |
| hud.gd (1,839 lines) | too big | split as above; test each panel opens/closes. |
| 2D world | still loaded as a fallback | remove or lazy-load when 3D is on, to save memory and startup. |
| Tests | 130 suites of rules | automatic look tests: render every item in every state at day/night and compare; add a perf budget test (draw calls, ms per frame). |
| Save | safe (temp, backup, batched) | schema version + migrations for future changes. |
| Perf | yards, glow pools, merged meshes | measure on a real low-end Android; set budgets (draw calls, tris, animals). |

## Suggested order
1. **Feedback service** (one place for all polish) then route existing call sites through it.
2. **Decor and building detail kit** (props, states, animation), the biggest look-and-feel gap.
3. **Goals/quests**, the missing reason to play.
4. **Ready/needs indicators** (badges over things, bubbles above animals).
5. **HUD split and animated counters.**
6. **Seasons, ambient sound, water.**
7. Feed Mill, Nursery babies, cellar, dogs (each now cheap).
