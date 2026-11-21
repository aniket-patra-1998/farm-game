# Building wear and climbing upgrade prices (our own addition, not FarmVille 2009)

Owner, 19 Nov: "More utilities/upgrades should come at the cost of more maintenance." Built after the design
review (Claude Doc "Farm game: a harder late game", section 6 holds the owner's decisions).

## Wear
- **Pace**: a utility building gains a level of wear every 10 days at its first size, 25% faster for each size
  it has grown. Time only, as vehicle rust; nothing wears in a farm's first 14 days. Levels 1 to 5.
- **What it costs** (BuildingDef.wear_kind):
  - a home (animal buildings, orchard, beehive, Gopher Garden, Dog House): 10% fewer coins a collect each level;
  - a crafting building: crafts take 15% longer each level;
  - the Garage: keeps less rust off; fully worn, its vehicles rust as fast as those standing outside;
  - storage (the Barn, the Garden Shed): 5% less room each level. Nothing kept is thrown out; a full one takes
    nothing new. From level 4, 2% of the Barn's feed or the Shed's bunches spoils a day (a phone notice warns
    before a building reaches level 4).
  - At level 5 a building stops: a home gives nothing, a crafting building starts nothing. Nothing is lost.
- **Repair**: coins and the building's own materials (those of its sizes), 4, 10, 18, 28 and 40% of what the
  building and its sizes cost at levels 1 to 5, worked from `farm_price` (below), and 10 minutes up to 4 hours. It works
  as worn as it is until the repair is done, then it is like new. Worn out (level 5) it does not work, and the
  repair does not start it again until it is done (owner, 20 Nov). A finished repair is said once
  (`finish_repairs`, on the farm's half-minute timer, as the vehicles' are).
- **Sign**: the rust sign (RustMarks), one draw for vehicles and buildings; a tap on it offers the repair. A
  building worn out offers its repair on any tap by hand. (Its own picture is a new look: options first.)
  While it is repaired the building keeps the sign, blue, its gear whole and turning and its pips filling as the
  repair goes (`repair_share`), so a repair is never taken for done; a tap says how long is left.
- **The offer** (HudBubble): the name, "Wear 3 of 5", then a tile each for the coins and every material (what the
  farm has of what it needs, a short one marked red), "Takes 1 h" on its own line, and the Repair button. Not one
  line (owner, 20 Nov). A vehicle's offer is laid out the same way.

## Upgrade prices
- A building's next size costs coins as well as materials: half its price at the second size, 1.6 times more
  at each size on.
- Every upgrade the farm already has (each size grown, each crafting star) makes every next upgrade 4% dearer,
  coins and materials (crafting stars: coins).

Switch: `Release.on("wear")`. Numbers: Balance `wear.*`, `upgrade.*`. Rules: `scripts/systems/wear_system.gd`,
`LandSystem.expansion_coins` / `price_climb`; held by `tests/suites/wear_test.gd`. Worked out from the clock
(as rust): kept is the wear gathered when its pace last changed, and when. (A Garage's wear changes its
vehicles' rust pace from the moment each was last settled, not level by level: close enough at these paces.)

## What the bot shows (60 days, every style, two seeds: the Economy audit)
The first readings (repairs under 1% of earnings, coins idle on 75 to 87% of days) were the bot's, not the
game's: it skipped every building, filled its farm with plots, never finished a frame nor bought a star, and
each run started on the day it ran (seasons and weather follow the calendar: one seed read 31% upkeep one day,
4% the next). Fixed (20 Nov), with every run starting on 1 June 2026 and upkeep measured over a run's last third
(wear needs 14 days' grace and 10 days a level to show), repairs take 17 to 25% of a grown farm's earnings in every style.
Repairs and upgrades are worked from `farm_price`: a building's own price, never less than 1.6 days of what
the farm earns (its week's average; Balance `wear.income_days`, `wear.income_week`) nor 2,000. So upkeep and
upgrades follow income (option 3, 20 Nov): a cheap coop on a rich farm costs upkeep in step with that farm,
while a dear building keeps the owner's 40% cap. (Priced from the farm's level first, a crafter, earning less
at the same level, sank 52% of its earnings into repairs.) Idle coins: 0% of days in every style.
