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
  building and its sizes cost at levels 1 to 5 (the owner's cap: 40%), and 10 minutes up to 4 hours. It works
  as worn as it is until the repair is done, then it is like new.
- **Sign**: the rust sign (RustMarks), one draw for vehicles and buildings; a tap on it offers the repair. A
  building worn out offers its repair on any tap by hand. (Its own picture is a new look: options first.)

## Upgrade prices
- A building's next size costs coins as well as materials: half its price at the second size, 1.6 times more
  at each size on.
- Every upgrade the farm already has (each size grown, each crafting star) makes every next upgrade 4% dearer,
  coins and materials (crafting stars: coins).

Switch: `Release.on("wear")`. Numbers: Balance `wear.*`, `upgrade.*`. Rules: `scripts/systems/wear_system.gd`,
`LandSystem.expansion_coins` / `price_climb`; held by `tests/suites/wear_test.gd`. Worked out from the clock
(as rust): kept is the wear gathered when its pace last changed, and when. (A Garage's wear changes its
vehicles' rust pace from the moment each was last settled, not level by level: close enough at these paces.)

## What the bot shows (45 days, builder style)
Six repairs (14,400 coins) and two upgrades: well under 1% of what the farm earned. With repairs capped at 40%
of a building's price, wear is upkeep to do, not a coin sink: buildings cost 5,000 to 12,000 while a late farm
earns about 90,000 a day.
