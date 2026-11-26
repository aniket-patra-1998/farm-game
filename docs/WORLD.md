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
| leaf, crop, flower | crown3d, painted3d, ... | | sways | | |
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
| `crown3d`, `frond3d` | trees' leaves | sun and shade, its own lean (a crown's tones are painted in its vertices) |
| `fruit3d` | fruit on a tree | sun and shade |
| `painted3d` | crops and flowers (painted cards) | the whole card lit alike, as a crown is |

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

At its grandest a home goes up, its plot being what it is (the owner, 26 Nov: "they don't look grand
enough"): a third storey on the Dairy Farm, Sheep Pen, goat tower and Nursery (an `upper` on an `upper`), a
little tower on the Stable (a cupola's `scale`), a silo beside the Pig Pen's ark.

**A sign at every animal home's gate** (all eight, both sizes): a post with a lantern (its pane glows at night
as the windows do, so the hive, coop and hutch are no longer dark), and a board hanging from its arm with the
animal's own Market picture, swaying in the wind. The model has the post and a mark (`sign_cow`); a picture is
made on the phone, so the farm hangs the board there (GateSign; shaders/sign3d.gdshader): one draw a home,
over its file's own budget.
Tests 647 to 649.

## A tree is one painted crown

Owner, 26 Nov: trees as the classic farm games paint them. A leafy tree is one rounded crown of its kind's width and
height (`TreeModel._crown`), with a few broad swells of its own, never separate balls. It is shingled all over in
leaf sprays (`_sprayed`): each a fan of five pointed leaves lapping over the spray below. The paint is five flat
tones of the kind's leaf colour (`TreeModel.tones`), lighter where the sun falls and at every tip, none near black.

- One mesh and one draw (`crown3d.gdshader`), with no see-through cards. Nothing shades it a second time: the tones
  are the shading, so the shader lights the whole crown nearly alike and takes no shadows.
- Sprays are made only on the side the camera sees. So a lone tree is never turned on the farm
  (`Objects3D._tree_turn` only sizes it); each look already stands its own way round.
- Palms and bananas keep their fronds. A willow's hanging masses are sprayed the same way, leaves pointing down.
- A limited variety's colours lie over the crown in patches; its touch and the wind go through the crown's shader as
  before (`ModelKit.sway_all`, `touch_all`).
- Fruit on a leafy crown is small and many (`CROWN_FRUIT`), sitting on the crown's skin.

## Crops are painted pictures

Owner, 26 Nov: crops as the classic farm games paint them, and a simpler way than modelling each plant. The camera
never turns, so a flat picture facing it is the plant.

- `tools/paint_plants.py` paints every crop as a recipe of shapes (SVG text, `art/painted/crops/<name>.paint`): no
  black outlines, flat tones, light from the upper left, the tree crowns' greens. `--check` is in the pre-push check.
- Four looks to a crop: the sprouts every crop shares, its plants part grown, ripe, and the ripe picture gone dry.
- `PaintedCrops` turns a recipe into a texture on the device the first time it is shown, and draws one card to a
  plot, one draw to a picture. A card stands on its bed's nearest corner, so it covers its own bed and sits behind
  whatever stands in front of the plot.
- `painted3d.gdshader` lights the whole card alike, as a tree's crown is, so it dims at night and darkens in rain;
  it bends in the wind from its foot.
- Flowers are painted the same way (`PaintedBloom`, `art/painted/blooms`): one card to a flower, in bud until it
  is ready, open while it stands ready, and the open picture gone dry once withered; single and full bloom.
- Market pictures are painted too: a crop's is what it gives, gathered (`<crop>_harvest`), a flower's is it open
  (`IconMaker.model`). A harvested plot's card springs up and is gone (`PaintedCrops.pop`).
- A made picture is kept on the device (`user://painted`, under its recipe's own mark), so only the first run
  paints it.
- A plot is planted close: a row more each way than it strictly holds, the plants lapping over each other and
  the bed's edge, so a ripe field shows hardly any soil (owner, 27 Nov); a half-grown plot's plants are `YOUNG` of
  ripe ones.
- There are no modelled crops or flowers any more (27 Nov): the Bloom Garden's beds, the bouquet, the height guide
  and the art reference tool show the same cards. `CropClock` keeps the farm's clock (the shaders' `crop_clock`,
  which a tree's fruit grows by) and says which look a plot shows (`stage_of`, `next_change`, `mastered`).

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
