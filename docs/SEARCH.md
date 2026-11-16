# Search, everywhere it helps

Status: design for review. Our own touch: FarmVille (2009) had no search. First in the build order.

## What the player gets

- A search field at the top of every menu that lists things: the Market (all shelves at once), Seeds, the Barn's
  storage, the Gift Box and inbox, Collections and Ribbons, a crafting building's recipes, goods and pantry, and
  any home that holds animals, trees or blooms (its contents). Menus that hold a few things don't get one:
  it shows by itself once a menu lists more than `search.from_items` things (data), so a new menu gets it free.
- Instant: results narrow as you type, every letter, no button; the list keeps its card look.
- Forgiving, as the good shops are:
  - word starts match first ("ch" finds Chicken Coop before Peach), then anywhere in a word;
  - one typo allowed in longer words ("tomatoe", "strawbery");
  - more than the name: an item is found by what it is and what it gives (data, not code): "egg" finds
    chickens and coops, "milk" cows, "wool" sheep, "fruit" fruit trees, "flower" blooms and flower crops,
    "fence" every fence, "home" every animal home, a set's name finds its pieces.
- Filter chips under the field, per menu (data): Market "Can buy", "New", "Mastered"; Barn "Animals", "Trees",
  "Decorations"; recipes "Can make". Chips and words combine.
- Recent searches (the last few, per menu, kept on the phone) under the field before you type; a clear (×)
  button in the field; the back gesture clears first, then closes.
- Nothing found: says so in one line and offers the nearest match ("Did you mean Strawberry?") or clearing
  the chips.
- On the farm: from the Barn or a home's contents, "Show on farm" for a placed thing pans the camera to it
  (FarmVille players lose their cows on a big farm too).

## How it is built (one way, used everywhere)

- `SearchIndex` (scripts/ui/search_index.gd, pure, tested): built once per list from its ids and a
  `words_of(id)` callable; each id's words are normalised (lower case, accents and punctuation off) into
  tokens with weights: name 3, alias 2, kind and family 1. `find(query, chips) -> Array[String]` ranks by
  best token match (exact > word start > inside > one typo), then the list's own order; a query of fewer than
  `search.least_letters` letters matches word starts only. Cost held by a test: 5,000 items under 2 ms a key.
- Words of an item: `ItemSearch.words_of(id)`, one function for every menu, read from the catalog (name,
  `kind`, family, `product`, `holds`) and data/search.json (`aliases` per id or family, in locale keys so they
  translate; the chips each menu offers and what each tests). A new catalog item is searchable with no work;
  an alias is a line of data.
- `SearchBar` (kit, scripts/ui/search_bar.gd): the field, clear button, chips and recent row, on the paper
  look; drives any `CardList` (grid or rows) by `set_ids(index.find(...))`, so cards are reused, nothing is
  rebuilt, and the virtual list stays fast. `CardList` gets `searchable(words_of, chips)`; BookPanel tabs share
  one bar across shelves (the Market searches all its shelves and shows which shelf each card is from).
- Phone keyboard: the field stays above the on-screen keyboard (the panel moves up by its height); Enter or
  Done closes the keyboard and keeps the results.
- Text: the field's hint and chip names in locale/strings.csv; numbers in results the usual way.
- Tests: every menu over the threshold has a bar; "egg" finds coops, "strawbery" finds Strawberry, chips
  combine, an empty result offers a match; 5,000 items within budget; menus_test sweeps menus with a query in.

## Build order

1. `SearchIndex` and `ItemSearch` with data/search.json (aliases, chips), with tests.
2. `SearchBar` on `CardList`; the Market (all shelves), Seeds, the Barn, the inbox.
3. Collections, Ribbons, crafting (recipes, goods, pantry), homes' contents; "Show on farm".
</content>
</invoke>
<invoke name="Bash">
<parameter name="command">cd /home/claude/farm-game && python3 - <<'EOF'
p='docs/WEATHER.md'; s=open(p).read()
def rep(a,b):
    global s
    assert a in s,a[:50]; s=s.replace(a,b,1)
rep("""- Lightning Rod (decoration, our own touch): a rod on the farm catches strikes; each catch gives a small reward
  (coins, or a material for crafting). Nothing on the farm is ever destroyed by lightning.""","""- Nothing on the farm is ever struck or destroyed by lightning: it is sky and sound only.""")
rep("""- Frogs come out near puddles and ponds and hop about;""","""- Frogs come out near puddles and ponds and hop about (scenery: a tap does nothing);""")
rep("""We take: rain that matters to
  crops, lightning with something to catch it. We leave: losing crops to lightning (too harsh for a cozy farm).""","""We take: rain that matters to
  crops. We leave: lightning striking the farm (too harsh for a cozy farm), and so no lightning rod.""")
rep("""  `RainLife` (frogs, snails, worms) beside `AmbientLife`, batched, spots chosen by `SpaceFit` on open tiles;
  `Mushrooms` drawn as one batch;""","""  `RainLife` (frogs, snails, worms) beside `AmbientLife`, batched, spots chosen by `SpaceFit` on open tiles;
  `Mushrooms` drawn as one batch;""")
rep("""## Build order

1. Fog fix (depth fog), thunder and the lightning bolt and flash; the rain sound layers.
2. Rules: wither in the wet, monsoon finds, the frogs family; `WeatherSystem` and data/weather.json.
3. Puddles and ripples in the ground and water shaders; rain particles in 3D.
4. Rain life: frogs, snails, worms; animals sheltering; the farmer's umbrella.
5. Afterwards: mushrooms, rainbow, morning mist; Lightning Rod and rain barrel.

## Open questions

- Should tapping a frog do anything (a ribbit and a small chance of a coin), or are they scenery only?
- Lightning Rod's reward: coins, or a new crafting material (and in which recipes)?
- Monsoon region (South Asia): longer, heavier rain spells in its monsoon season, with more frogs and finds?
""","""## Build order

1. Search everywhere it helps (docs/SEARCH.md), before the weather.
2. Fog fix (depth fog), thunder and the lightning bolt and flash; the rain sound layers.
3. Rules: wither in the wet, monsoon finds, the frogs family; `WeatherSystem` and data/weather.json.
4. Puddles and ripples in the ground and water shaders; rain particles in 3D.
5. Rain life: frogs, snails, worms; animals sheltering; the farmer's umbrella.
6. Afterwards: mushrooms, rainbow, morning mist; the rain barrel.

## Decided

- Frogs are scenery: a tap does nothing.
- No lightning rod.
- The South Asia monsoon region's own longer, heavier rains: later, not now.
""")
open(p,'w').write(s)
EOF
git add docs/ && git commit -qm "docs: search everywhere (SEARCH.md), first in the build order; rain decisions (frogs scenery, no rod, monsoon later)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014fNSr1LTa4ZmUtF6K6voar" && git push -q origin main && git log --oneline -1