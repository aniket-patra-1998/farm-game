# FarmVille reference (what we copy from, and where it comes from)

Target: the full 2011 game. Looks come from the screenshots the project owner shared (measured below); data from
public fan pages. Nothing here is Zynga artwork; it is facts, measurements and notes.

## Sources
- Crops, 2011 table (110 crops: seed cost, harvest coins, hours, XP): avemariasongs.org/games/FarmVille/FV-crops.htm
- 2009 economy and mechanics (profit per day, plough 15 coins and 1 XP, tractor up to 4x plough speed, hay bale 100 coins
  for 5 XP): adamnash.blog/2009/08/23/the-personal-economics-of-farmville-part-2/
- Trees, 2011 yields (40 trees: coins per harvest, growing days; orchard holds 20 trees, harvested every 2 days, cost
  9 bricks + 10 nails + 10 boards; super orchard 60 cash, double trees, daily): avemariasongs.org/games/FarmVille/FV-trees.htm
- Buildings, 2011 list (animal buildings, craft buildings with at most 3 of bakery/winery/spa, greenhouse in 3 levels with
  1/4/8 seed trays, storage: tool shed, red barn, garage, storage cellar 1250 items, raffle booth): avemariasongs.org/games/FarmVille/FV-buildings.htm
- Single items (cost, XP, growth stages, mastery): farmville.fandom.com/wiki/<Item> (pages open only through a search result).
- Not found: tile footprints (building sizes in squares), art specs. Fan pages do not carry them; screenshots do.

## Measured palette (dominant colours sampled from the shared screenshots)
| Thing | Colour |
|---|---|
| Grass, the big flat field | #3f8026 to #479b46 (mid saturated green, a little yellow) |
| Grass, darker tone / shadow | #2d6a1f, #29621e |
| Foliage, dark | #1d5625, #223a2d |
| Foliage, light / spring | #7dbd57, #a1bc72 |
| Barn roof | #6f321a (deep brown-red), nearly black in shadow |
| Barn wall | deep red, around #7a2a20 to #8a3524 |
| White trim | #f3f5f6 |
| Hay and straw | #b8b67d to #c8b24a |
| Soil, ploughed | #594823 to #725e4a |
| Interface wood | #7a4f2c, cream #fbefd2 (already in data/ui_theme.json) |

## Structure notes (from the screenshots)
- Fields are big and dense: whole blocks of one crop, dark soil visible only between rows.
- Orchards: one kind per row, straight lines, evenly spaced; mixed kinds beside each other in blocks.
- Fences are white, thick and continuous; hedges are tall, double height, used as walls around fields.
- Animals stand in tight herds and rows by the barn; buildings face the viewer on a lawn with a few props.
- Vehicles are chunky, about two tiles, muddy tyres, white cab roofs, several liveries.

## Gaps against the 2011 game (to plan, not yet built)
Orchard as one building (20 trees), tool shed, storage cellar, craft shop, trading post, raffle booth, aviary, zoo, pet run,
wildlife, second farm, greenhouse levels (1/4/8 trays), vehicle liveries.
