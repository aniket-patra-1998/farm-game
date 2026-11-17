# Player experience: goals, the first hour, a beautiful farm, a fair economy

Status: design for review (nothing built). A milestone of its own: no new systems while it runs; everything
here is built from what the game already has. Our own touch where marked (FarmVille had quests from 2010 on,
told by its characters; this follows that and modern farm games).

The aim, in one line: a new player becomes attached to their farm in the first hour, always knows what to do
next, sees it grow more beautiful, and has a reason to come back tomorrow and next week.

The four parts, in the order to build them:
1. **Goals**: short jobs, story chains and long projects, one system.
2. **The first hour**: the tutorial becomes the first goals; the game shows itself a piece at a time.
3. **A beautiful farm**: the farm judged as a whole picture, at the zoom players use.
4. **A fair economy**: the balance bot plays like real players (spends, follows goals, takes breaks), and the
   numbers are tuned to clear targets.

---

## Part 1. Goals

### What the player sees
- **Today's jobs** (FarmVille's daily quests, our own shape): three small jobs a day ("Harvest 10 Strawberries",
  "Collect from 3 animals", "Make 1 Pumpkin Bread"), picked for what this farm can do now, about 10 to 15 minutes
  in all. A new three at local midnight; doing all three gives a bonus (a Mystery Box, a gem on some days). A job
  can be swapped once a day for another.
- **Story chains** (FarmVille's quests): told by the six neighbours who already write to the inbox (Maple, Barley,
  Clover, Hazel, Rusty, Poppy), each a person with a voice and a part of the farm they care about. A chain is 3 to
  6 steps; each step is 1 to 3 tasks. A chain teaches one thing (Rusty: vehicles; Clover: flowers and bees; Hazel:
  crafting; Barley: animals; Maple: the orchard; Poppy: decorating). Finishing one gives a reward worth having
  (an item to place, a building at a discount, a rare breed) and opens the next.
- **Farm projects** (our own touch): a few long goals of 1 to 4 weeks that change the farm where you can see them:
  rebuild the broken old Tractor (parked rusted on the starter farm; RUST.md's look), plant an orchard of 9 trees of 3 kinds, raise a
  full coop of rare breeds, build the Bakery and master three recipes, a flower garden with a Bloom Garden full.
  Each has stages (a stage is a step), and its reward stands on the farm (a sign, a statue, a ribbon on the
  building).
- **Where it shows**: a column of up to three round goal faces at the left edge under the coin meter (the giver's
  portrait, a ring for progress, a dot when done). A tap opens the goal sheet (the one sheet look: paper, tabs:
  **Story**, **Today**, **Projects**). Each task is a `word_bar` ("Harvest Strawberries 6 / 10") with **Show me**:
  it opens the Market on the item, picks the right tool, or takes the view to the place on the farm
  (`FarmGrid.spots_of`, as search's Show on farm does). Done goals are collected with one tap: the reward flies to
  its meter, a short sound, the next goal slides in with its giver's line.
- **Never in the way**: at most three faces; a goal never blocks play; nothing needs gems; nothing is lost by
  ignoring a goal; text is one line per task, the giver's words one or two short lines.

### How goals are written (data, not code)
`data/goals.json`, every word in locale (keys), checked by tests:

```json
{
  "chains": [
    {"id": "barley_first_coop", "giver": "barley", "after": ["welcome"], "level": 3,
     "steps": [
       {"say": "GOAL_BARLEY_COOP_1", "tasks": [{"do": "buy", "what": "chicken", "n": 2}],
        "reward": {"coins": 150, "xp": 20}},
       {"say": "GOAL_BARLEY_COOP_2", "tasks": [{"do": "collect", "what": "chicken", "n": 4}],
        "reward": {"xp": 30, "item": "hay_bale"}},
       {"say": "GOAL_BARLEY_COOP_3", "tasks": [{"do": "build", "what": "chicken_coop"},
                                              {"do": "move_in", "what": "chicken", "n": 2}],
        "reward": {"coins": 400, "xp": 60, "unlock_chain": "barley_eggs"}}]}
  ],
  "daily": {"count": 3, "swap": 1, "bonus": {"box": "mystery_box", "gems_every": 3},
            "templates": [
              {"do": "harvest", "what": "@crop_unlocked", "n": [6, 20], "weight": 3},
              {"do": "collect", "what": "@animal_owned", "n": [3, 8], "weight": 2},
              {"do": "craft", "what": "@recipe_known", "n": [1, 2], "weight": 1, "level": 8}]},
  "projects": [
    {"id": "old_barn", "level": 2, "stages": [
       {"tasks": [{"do": "find", "what": "nails", "n": 5}, {"do": "find", "what": "boards", "n": 5}]},
       {"tasks": [{"do": "repair", "what": "barn"}]}],
     "reward": {"xp": 150, "place": "barn_sign"}}
  ]
}
```

- **Verbs** (`do`): plow, plant, harvest, fertilize, collect, feed, buy, place, move_in, build, upgrade, repair,
  expand, craft, sell, find, master, raise, help, earn, level (a state: reached), own (a state: you have N now).
  Each is one event the game already counts.
- **What** (`what`): an item id, a family ("berry"), a kind ("tree"), or a pick for daily jobs (`@crop_unlocked`,
  `@animal_owned`, `@recipe_known`, `@building_owned`). Every id is checked against the catalog and
  `Release.has`.
- **Counting** starts when a goal is taken (things done before don't count, as FarmVille), except state verbs
  (level, own), which are true or not now. Away time counts: vehicles, helpers and harvests done while away are
  events like any other.

### How it is built
- **One event stream.** Today 38 counters are kept for ribbons (`Game.ribbons.bump("harvests", 1)`) without saying
  what was harvested. They become one call, `Game.record(verb, subject, n)`: it keeps the ribbon counters as now
  and tells `did(verb, subject, n)`. Goals listen to it; so can anything later (analytics, collections). A test
  holds every verb in goals.json to a `record` call in the code, and every `record` to a verb.
- **`GoalSystem`** (`Game.goals`, a GameSystem): the chains open, taken and done; progress per task; today's jobs
  and the day they were made; projects and their stage. Saves only that. Picks today's jobs from the templates,
  seeded by the date and the farm (the same day gives the same jobs), only what this farm can do now, sized by
  level. Rewards through the paths that exist (coins, XP, gems, the Gift Box for items, `unlock_chain`).
- **`HudGoals`** (the faces and the sheet), on the kit: `UiKit.word_bar`, `BookPanel`, `FloatText` for the giver's
  line over the farm, `UiFx` for the slide-in. Show me through `hud.show_market(id)`, `HudTools.pick(tool)` and
  `ItemSearch.show_on_farm`.
- **Release switch** `goals` in data/v1.json; Balance `goals.*` for daily sizes, the bonus and reward scales.

### Tests
- Every goal's verbs, ids and locale keys exist; every chain is reachable on the level path (its `after` chains
  open before its level); no goal needs a gem or something not in the release.
- Doing the tasks completes them, rewards arrive once, a saved goal loads where it was.
- Today's jobs: the same for the same day and farm; never something the farm can't do; the swap works once.
- The balance bot (Part 4) follows the goals and finishes the first five chains by the days planned.

### Content for the first release
- **Welcome** (the tutorial, Part 2): 8 steps.
- **Six neighbour chains of 3 to 6 steps each** (about 25 steps), unlocked from level 2 to 12.
- **Daily templates**: about 15.
- **Three projects**: the orchard, rebuilding the broken Tractor, the coop of rare breeds.

All of it is written as data, so more is writing, not code.

---

## Part 2. The first hour

### What is there now
Three tutorial steps (harvest the ready plots, plow, plant), then nothing points anywhere. Every button is on
screen from the start. The fastest early crop is Strawberries (4 hours), so after planting there is nothing to
wait for in the first session but the plants.

### What it should feel like (minute by minute, about 60 minutes)
| minutes | what happens | what it teaches |
|---|---|---|
| 0-2 | The farm opens on a small, pretty starter farm (Part 3): a house, the broken Barn, a few trees, ripe crops. Maple says hello in floating words. Harvest the ripe plots (a hand points). | tap to harvest, coins and XP fly |
| 2-5 | Plow two plots, plant Strawberries; Maple gives **Starter Seeds** for one plot that ripen in 3 minutes (our own touch, the first session only, not sold) so the loop closes at once. | plow, plant, wait |
| 5-10 | The starter seeds ripen: harvest, **level 2**. Barley gives a free chicken: place it, collect its first egg (ready at once). | animals, placing, collecting |
| 10-20 | Buy an Apple Tree in the Market (Maple's step; the Market button appears now, lit). Tree has fruit ready the first time. | the Market, trees |
| 20-30 | The broken Tractor project opens: materials come from harvests; a guaranteed first find from a harvest shows Collections. | finds, projects |
| 30-45 | Level 3: **Today's jobs** appear. A second chicken, a coop to aim for (Barley's chain). | daily jobs, goals |
| 45-60 | Plant a crop that ripens overnight (the game says which: "ready when you wake"). The faces show tomorrow's goals. | coming back |

### Principles
- **One new thing at a time**, each brought by a goal; nothing unlocks without a goal or a word pointing to it.
- **Show the interface as it is needed** (progressive reveal, our own touch): on a new farm only the tools in use
  and the Market show; the menu's buttons (Collections, Ribbons, Neighbours, Settings) appear as the goal that
  needs them arrives, with a short shine. A returning player (saved farm past the Welcome chain) sees everything.
  Data: `data/reveal.json` (button -> the goal or level that shows it).
- **A guide that points, not a wall of text** (`Guide`, kit): a bobbing hand at the tool, the plot or the card
  that is next, the rest of the screen dimmed a little only while a step needs one particular tap. It follows the
  goal's Show me; it never blocks a tap elsewhere for more than that step.
- **Every action pays back at once**: the feel layer exists (sounds, floating numbers, the coin roll); the first
  hour gets the best of it (the first level-up, the first find and the first collection piece are moments).
- **Always a next step**: the goal faces always hold at least one goal the player can do now, with coins in hand.
  A test plays the first hour (Part 4's bot following goals) and fails on a dead end.

### How it is built
- The tutorial (`Game.Tutorial`, three steps) becomes the Welcome chain in goals.json; `tutorial_step` stays for
  old saves (they skip Welcome).
- Starter Seeds: a crop entry with `starter: true` (3 minutes, one plot, given once by Welcome), never sold.
- `Guide` (scripts/ui/guide.gd): targets a Control by name or a farm spot; `HudReveal` hides and shows HUD buttons
  from data/reveal.json.
- The starter farm layout is data (`data/starter_farm.json`: what stands where on a new farm), drawn in Part 3.
- First-hour numbers kept on the phone (time to first harvest, first purchase, level 2, 3 and 5, the step where
  a player stopped) in `user://` and shown in the debug readout; later an analytics service can read the same.

### Measured by
- A bot run of the first hour: level 3 by minute 30-40, the Welcome chain done, never a dead end.
- The first-hour numbers from real players once testers play (later).

---

## Part 3. A beautiful farm

### How it is judged
Not model by model: the farm as one picture, at the zoom players use, at four times of day, on three farms:
- **A new farm** (minute 0): what the first impression is.
- **A week-old farm**: a few homes, an orchard row, fences, a path, some decorations.
- **The showcase**: everything.

`tests/shots.gd` gets these as fixed camera shots (the Screenshots workflow already draws on every push), and each
workstream below is done when its shots are better side by side with the last ones, and the perf budget holds.

### Workstreams
1. **The starter farm** (with Part 2): a layout that looks loved from minute 0: the house with a little garden
   (flowers, a bench, a mailbox), the broken old Tractor with parts stacked by it, two or three fruit trees, a path from
   the road to the house, a fence along one side, a few ripe plots. Data in `data/starter_farm.json`.
2. **The land around the farm**: today the meadow and woods ring the farm; it should read as countryside with a
   few clear features: a road with the mailbox and a gate, a stream or pond beyond the edge, tree clusters of
   mixed kinds and heights, rocks and wildflowers at clump edges, farmland of neighbours far off (patchwork
   fields, a distant barn): cheap batched pieces through `Instancer`, baked once (`ModelStore`).
3. **Trees**: each kind its own silhouette family (round, tall, spreading, weeping, conical) and colour, sizes
   varied within a kind, crowns that move a little in wind; orchards that read as rows (Crowding already makes a
   packed grove one mass); fruit visible when ready.
4. **Flowers and decorations together**: flower beds as compositions (a border, heights from back to front), a
   decoration dressed by where it stands (grass and stones round it, `DecorLayer` already has the looks).
5. **Buildings in their place**: a yard apron of worn earth or gravel under each home, a bush or two and props by
   the door (a bucket, hay) through `BuildingFill`; contact shade; paths that worn tiles join (the wear map
   exists).
6. **Scale and silhouette**: one check of every thing's size against the farmer, a cow and a tile
   (`ScaleGuide`), so nothing is a giant or a toy; readable at the default zoom.
7. **Life**: smoke from chimneys, birds landing on fences, butterflies over flowers by day, fireflies at night
   (most exist: tune them so a still farm always has something moving); the farm's sound bed (birdsong by day,
   crickets at night, the rain).
8. **Light and colour**: one palette check against docs/ART_BIBLE.md per time of day; warm mornings, soft noon,
   golden evening, blue night with lit windows.

### Built under the rules already there
Art made offline as files where it is new (docs/ASSETS.md); anything repeated through `Instancer`; costly looks
behind `Quality`; draws held by data/perf_budget.json.

---

## Part 4. A fair economy

### The questions to answer
1. Does the player always have something worth buying, and never too much money with nothing to spend on?
2. Does building a building feel like an achievement, not a chore of materials?
3. Does feeding add choice without punishing a break?
4. Is crafting worth it against selling crops?
5. Are gems useful without being needed?
6. Is there still something to chase after level 20?

### Targets (written as numbers the bot checks)
- **Something to buy**: at every visit there are 1 to 3 things in the Market the player wants (the next home,
  an upgrade, a tree for the orchard) costing 1 to 3 visits of income; idle coins stay under about 5 visits of
  income (today the bot sits on 100-300k).
- **Levels**: keep the pace (level 20 in about 2 weeks at three visits a day, 4 weeks at one); level 30 by about
  week 6 (three a day).
- **Feeding**: a player who never feeds loses at most 30% of animal income and nothing else; after a week away
  nothing has died or been lost (as FarmVille); feed is a choice, not a daily chore.
- **Crafting**: a recipe's goods are worth at least 30% more than selling its ingredients, and it pays back its
  building in about a week of normal crafting.
- **Gems**: a free player earns a few a week (level-ups, ribbons, goals, the daily bonus); everything gems buy can
  be earned or waited for; nothing in goals needs them.
- **After level 20**: building upgrades, mastery to three stars, collections, rare breeds, projects and chains
  keep giving goals to at least level 40 (the unlocks past 20 checked from the catalog and data/v1.json).

### The bot learns to play like people
`tools/balance_sim` today harvests, replants, plows and buys land, trees, animals and one building a visit. It
gets **player styles** (`--style=`):
- **builder**: homes, upgrades and land first.
- **decorator**: spends a share on decorations and fences.
- **crafter**: builds the Bakery early and crafts.
- **goal follower**: does what the goal faces say.
- **casual**: one visit a day, skips some days.

And **breaks**, the days it doesn't come (`--away=3,7`). It prints, per day:
- level, coins earned and spent, and idle coins;
- what it owns, and the share of the Market it could afford;
- goals done;
- feed used, and what feeding gained or lost.

### What gets tuned
Land and building prices against income by level; materials per building; crafting prices; feed amounts and the
hungry penalty; the gem sources; the unlock order. Every change goes through Balance (`data/balance.json`) and is
tried in the bot first (docs/BALANCE.md shows how).

### Tests that hold it
- Prices rise with the level they unlock at.
- Every unlock is affordable within a set number of days at the casual pace.
- The goal follower is never stuck.
- Idle coins stay under the target in every style.
- A week away loses nothing.

---

## Order of work and size

| step | what | depends on |
|---|---|---|
| 1 | `Game.record` and the event stream (replaces `ribbons.bump`), with tests | - |
| 2 | `GoalSystem` and data/goals.json format, tests | 1 |
| 3 | `HudGoals`: faces, the sheet, Show me, rewards | 2 |
| 4 | The Welcome chain, Starter Seeds, `Guide`, `HudReveal` (Part 2) | 3 |
| 5 | The starter farm layout and the land around it (Part 3, workstreams 1-2) | - (any time) |
| 6 | Bot styles and breaks (Part 4), first measurements | 1 |
| 7 | The six neighbour chains, daily templates, three projects (content) | 3, 6 |
| 8 | Economy tuning to the targets | 6, 7 |
| 9 | Beauty workstreams 3-8 | 5 |

## Decisions (owner, 17 Nov 2026)
1. **Starter Seeds** (one plot that grows in 3 minutes, the first session only): yes.
2. **Show the interface as it is needed** (buttons appear as goals bring them): yes.
3. **Neighbours as quest givers** (the six from the inbox, each with their own chain and part of the farm): yes.
4. **Daily jobs' bonus**: a Mystery Box every day and a gem every third day: right for now (the economy pass may
   revisit it).
5. **Farm projects**: the orchard, rebuilding the broken Tractor, and the coop of rare breeds (not the old Barn).
