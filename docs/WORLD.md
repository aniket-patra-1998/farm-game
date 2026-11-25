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

A fountain, a pour and a warm pool's steam are not weather's business: a spray answers only when its settings
say how (`DecorMotion.SMOKE_THINS`, `EMBERS_DIE`, `STEAM_IN_RAIN`).

## Weight

A thing has weight when the ground answers it. The grass darkens round the foot of buildings, under trees and
vehicles and wears where feet go (Ground3D's shade map); a standing decoration and every animal has a soft
shade right under it (GroundShade, ContactShades: one draw for all). That shade is all but black, so it
darkens wet earth and night grass by the same share as a sunlit lawn, and is drawn stronger at night, when no
cast shadow holds a thing down.

## Still to come (in this order)

1. Animals answer the weather (the kind "living"): shelter in rain, a shaken coat after, breath in the cold.
2. Cloth and loose things (flags, a scarecrow's rags, hay): heavy and dark when wet, lifted by the wind.
3. Unmown grass at the foot of every standing thing, and things set a little into the ground.
4. Sizes: animals smaller on the open farm, much smaller in a yard; bees half their size.
5. Buildings as kits: one small unit a building, a lead that grows at each level, companions and props added.
6. Animals lighter: the bone rig shipped in place of the stored poses.

## Adding a thing

Build it from the kinds above: `DecorMotion.flame` for a flame, `DecorMotion.spray` with SMOKE or EMBERS,
`DecorModel._glow` for a lamp or coals. If it is a new kind, give the kind one shader that reads the shared
values, add its row to the table, and a test to `tests/suites/world_rules_test.gd`.
