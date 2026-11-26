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
| animal | AnimalBehaviour, data/animal_rigs.json `weather` | turns its tail to it and stands about; in a storm keeps close to home; one with a home goes in at its door from hard rain (`shelter_from`) and comes out after; shakes it off when it stops | | sleeps its family's way | |

A fountain, a pour and a warm pool's steam are not weather's business: a spray answers only when its settings
say how (`DecorMotion.SMOKE_THINS`, `EMBERS_DIE`, `STEAM_IN_RAIN`).

## One finish

Everything solid is lit and painted by one rule (`shaders/finish.gdshaderinc`; the owner's pick of 26 Nov from
a sheet of four, option C), so a cow, a coop, a fence and a tree sit in one world:

- **Sun and shade.** The sun's side is warm; the side turned from it is filled with cool sky light; and there
  is less flat all-round light, so a thing has a lit side and a shaded one. A lamp or a fire lights it plainly.
- **Painted.** Broad brushy patches of lighter and darker; each thing leans a little warm or cool by a number
  of its own (from where it stands: two of a kind are never the same colour); darker towards its foot.

| Shader | Draws | Wears |
|---|---|---|
| `master_solid` | animals and buildings made as files | sun and shade, painted |
| `paint3d`, `wall3d` | things built in code: fences, decorations, walls | sun and shade, painted |
| `canopy3d`, `foliage3d`, `frond3d` | trees' leaves | sun and shade, its own lean (leaves keep their pattern) |
| `fruit3d` | fruit on a tree | sun and shade |
| `crop3d`, `bloom3d` | crops and flowers | not yet: thin leaves lit their own way (still to come) |

The patches are worked out for every pixel, so they are a quality's to give (`finish_grain`: off on low). The
rest costs what the engine's own lighting did. A new solid kind includes the file, calls `finish_painted` (or
`finish_lean`) on its colour and sets `AO = FINISH_AMBIENT`. Tests 645, 646.

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

## One star for every building at its biggest

A building at its biggest size wears a gold band, and a gold star floats over its lead: turning, bobbing, with a
soft glow that is stronger at night (the owner, 25 Nov). It is the same star for every building, sized by each
(`r` on its `crown` feature). No building's model has a star in it: the model marks the place (a part named
`star_<radius in hundredths>` at the top of its roof, BuildingDress "crown") and CrownStars draws every star on
the farm in two draws (the stars, their halos), as the ready signs are one. Tests 638, 639.

## Buildings grow by their lead growing and others joining

A bigger size is never one big clunky building (the owner, 25 Nov). A building is a small unit with its own
outline and colour; each size makes its lead unit bigger and richer and adds a smaller one or a prop beside it,
so its top size is a small yard with one clear lead. Built so far:

- The Beehive: a straw hive on its stand (data/building_models.json `skep`: `rings`, `scale`, `cap` for the
  lead's hat; BuildingModel._skep), one at first, three of three sizes at its biggest, the gold band of a
  maxed building on the lead, its star floating over it.
- The Chicken Coop: a red A-frame (low walls under a steep gable) on stub legs; at its biggest the A-frame has
  grown and a little one stands beside it (`hut`: a small house of the building's own kind, BuildingModel._hut).
- The Rabbit Hutch: a long low box under a green lid, its front a wire mesh; at its biggest it is longer and
  taller, with a little hutch beside it.

A body still carries the door, the ramp and the wear, so a home is restyled through its data (`body`, `roof`,
`levels`), with no upper storey stacked on it.

### The five other animal homes (the owner's picks of 26 Nov, two sheets and a clip)

Five homes were one house in five colours, each a storey taller at its biggest. Now each is known by its own
outline and roof colour, and at its biggest its lead stands a storey taller with something beside it and one
thing of its own that moves, lightly, by the shared wind:

| Home | Its outline | At its biggest | What moves |
|---|---|---|---|
| Dairy Farm (`cow_shed`) | a cream barn under a blue two-pitch roof | two storeys, a silo | a weathervane |
| Sheep Pen | a low stone fold under a straw-coloured roof | a second low storey, a lean-to | chimney smoke |
| Goat Pen | a hut on stilts with a ramp, an orange roof | a two-storey tower, a lookout hut | a bird circling |
| Stable | a long row of stalls under a green roof | a hay loft, a cupola | the cupola's weathervane |
| Pig Pen | a round tin ark (`barrel` roof) | a tall ark, a small one beside it | a tin vent spinning |

**A sign at every animal home's gate** (all eight, both sizes): a post with a lantern (its pane glows at night
as the windows do, so the hive, coop and hutch are no longer dark), and a board hanging from its arm with the
animal's own Market picture, swaying in the wind. The model has the post and a mark (`sign_cow`); a picture is
made on the phone, so the farm hangs the board there (GateSign; shaders/sign3d.gdshader): one draw a home,
over its file's own budget.
Tests 647 to 649.

## Still to come (in this order)

1. The other animal homes as kits (Cow Shed, Sheep Pen, Goat Pen, Horse Stable, Pig Pen, Duck Pond), each with
   an outline and colour of its own.
2. Animals with more character (fleece, fur and manes as distinct forms) and lighter: the bone rig shipped in
   place of the stored poses.
3. Unmown grass at the foot of every standing thing, and things set a little into the ground (a new look: a
   sheet first).
4. Heads at the windows while animals shelter, bees into their hives, breath in the cold (docs/WEATHER.md).

## Adding a thing

Build it from the kinds above: `DecorMotion.flame` for a flame, `DecorMotion.spray` with SMOKE or EMBERS,
`DecorModel._glow` for a lamp or coals. If it is a new kind, give the kind one shader that reads the shared
values, add its row to the table, and a test to `tests/suites/world_rules_test.gd`.
