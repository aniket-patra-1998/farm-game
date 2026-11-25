# The world's rules

The owner, 25 Nov 2026: "The idea is to make a collective world, not do work piece by piece." A fire that
burns on in a storm, an animal that stands on the grass as if on glass, a lamp lit at noon: each is a thing
that was made alone. This file is the short list of rules every thing on the farm obeys, and where each rule
lives, so a new thing gets its behaviour by being of a kind, never by its own code.

## How a rule reaches everything

The farm keeps a few values that every shader can read (project.godot `[shader_globals]`): `rain` (how hard
it rains now), `wetness` and `snow_cover` (what the weather has left on things), `wind`, and `dark` (how far
into the night it is). SurfaceWeather, Farm3D and the day cycle set them once a frame. A kind of thing answers
by reading them in its shader: no script runs for each thing, and nothing can be forgotten.

## Kinds, and how each answers

| Kind | Where | Rain | Wind | Night | Snow |
|---|---|---|---|---|---|
| surface (every model) | paint3d, wall3d, ... | darker and glossier (`wetness`) | | | whitens what faces up |
| fire | flame3d | beaten down to its coals (`QUENCH_FROM` to `QUENCH_FULL`), unless `sheltered` | leans | | burns |
| a fire's coals | lamp3d `fire` | dulled (`COALS_LEFT`) | | | |
| a fire's embers | spray3d `weather` 2 | none | | | |
| a fire's steam | spray3d `weather` 3 | there only while it rains | carried | | |
| smoke | spray3d `weather` 1 | thinner, beaten down | carried | | |
| lamp | lamp3d | | | lit as it falls (`LIT_FROM` to `LIT_FULL`) | |
| window | ModelKit.glass, glow3d | | | lit | |
| water | water3d | rings | | moonlit | ices over |
| leaf, crop, flower | canopy3d, crop3d, ... | | sways | | |
| the shade under a thing | contact3d | | | stronger (`NIGHT_MORE`) | |
| animal | AnimalBehaviour, data/animal_rigs.json `weather` | turns its tail to it and stands about; in a storm keeps close to home; shakes it off when it stops | | sleeps its family's way | |

A fountain, a pour and a warm pool's steam are not weather's business: a spray answers only when its settings
say how (`DecorMotion.SMOKE_THINS`, `EMBERS_DIE`, `STEAM_IN_RAIN`).

## Weight

A thing has weight when the ground answers it. The grass darkens round the foot of buildings, under trees and
vehicles and wears where feet go (Ground3D's shade map); a standing decoration and every animal has a soft
shade right under it (GroundShade, ContactShades: one draw for all). That shade is all but black, so it
darkens wet earth and night grass by the same share as a sunlit lawn, and is drawn stronger at night, when no
cast shadow holds a thing down.

## Size

Size tells what matters (data/scale_guide.json): buildings and trees stand over the animals, so an animal at
large is drawn a little smaller than its file (`animals.default`), a bee much smaller (`ids`), and in a
building's yard smaller again (`yard`): the building is its home, not a prop beside giants. Its stride, its
shade and where its "z z z" rises all follow its size (ScaleGuide.animal_scale, yard_scale; Animal3D.create).

## Still to come (in this order)

1. Buildings as kits: one small unit a building, a lead that grows at each level, companions and props added
   (the owner's pick, 25 Nov; concept sheets: hive, coop, hutch).
2. Animals with more character (fleece, fur and manes as distinct forms) and lighter: the bone rig shipped in
   place of the stored poses.
3. Unmown grass at the foot of every standing thing, and things set a little into the ground (a new look: a
   sheet first).
4. Animals in a yard go in when it rains (heads at the windows), breath in the cold (docs/WEATHER.md).

## Adding a thing

Build it from the kinds above: `DecorMotion.flame` for a flame, `DecorMotion.spray` with SMOKE or EMBERS,
`DecorModel._glow` for a lamp or coals. If it is a new kind, give the kind one shader that reads the shared
values, add its row to the table, and a test to `tests/suites/world_rules_test.gd`.
