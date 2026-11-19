# Limited animals

Unique coats of the animals the farm already has: new colours, patterns, and more or less fur, on the same
animal underneath (no wings, no new kinds). FarmVille had limited editions like these. The owner's rules
(19 Nov 2026) are the three below; the numbers are in `data/balance.json` (`limited.*`).

## The rules
1. **Marked limited.** Every such animal has `limited` in the catalog (`data/catalog/animals.json`), and its
   baby too. The Market shows them in a section of their own, each card saying "Limited".
2. **Bought with gems.** A limited animal is sold in the Market for gems only (`gem_cost`): about double an
   ordinary gem animal, by kind (birds and rabbits 20, pigs, sheep and goats 35, cows, horses, llamas and
   alpacas 50). It lives in its family's home and earns one and a half times the family's plain animal.
3. **Found only where one lives.** Once a limited animal lives in a home, that home's finds can turn out to
   be another of it:
   - a **Mystery Baby** from harvesting the home (`NurtureSystem.from_home`),
   - a **Mystery Egg** from the Chicken Coop (`MysterySystem.find_egg`; decided when found, shown when opened),
   - a **birth** (a calf, foal, lamb or piglet: `BuildingSpecials`; the limited animal's own baby, which the
     Nursery raises into it).
   An ordinary find is limited 0.5% of the time, a rare find 5%. Which one: the limited animals living there,
   likelier the more of one. Everything else a home gives is drawn from its other animals
   (`LimitedSystem.ordinary`), so a home full of limited animals does not hand them out.

## Rare finds
A **Rare Mystery Baby** and a **Rare Mystery Egg** are the same finds, rarer: 1 find in 10
(`limited.rare_share`). The rare egg has its own, better prizes (`data/mystery_eggs.json`, "rare").

## The animals
56 limited animals (five for each kind, six cows) and 21 babies (calves, foals, lambs, piglets: the homes
that have births). Goats, llamas, alpacas, birds and rabbits have no baby form in the game.
Their art is made as every animal's is (docs/ASSETS.md): rows in `tools/animal_art/animal_art/limited.py`,
each from one of its family's breeds, with patterns painted by `paint.py` (stripes, stars, dots, patches,
a run of colours, a dip, a belt, a half). A coat that turns colour does it in flat bands, so a file stays
about a megabyte.

## Not in the first release
`data/v1.json` has `"limited": false`: no find is rare and none is limited, and the animals are not on its
list, until the owner turns it on.

## Open
- The animals' own touches (stars that blink, colours that travel, a glint, a coat shake, the show-off) are
  agreed as concept clips and not built.
- Downloading a limited animal's file when it is first needed (the owner's plan for the app's size) is not
  built: today every file ships in the app (about 80 MB for these).
- Limited dogs (five were drawn) wait for dogs to be animals you can buy and house.
- Baby forms for chickens, ducks, geese and rabbits do not exist yet, limited or plain.
