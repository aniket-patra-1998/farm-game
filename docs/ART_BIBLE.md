# Art bible

The one look every asset follows, from any source (our builders, Blender, bought or commissioned). The reference
is the new animals made by `tools/animal_art` (branch `animal-art-builder`): soft, cute, painted, readable from
far away. Trees and crops are being remade in the same style. When this page and an asset disagree, the asset is
changed.

## Shape language

- **Soft and round.** Forms are melted together into one skin, never boxes glued onto boxes. No hard corners
  except where the real thing is hard (hooves, horns, beaks, roof edges, tools), and even those are bevelled.
- **Chunky proportions.** Heads and features a little large, legs a little short and sturdy, bodies full. Big
  shapes first, then medium, then a few small ones; never an even spread of detail.
- **Silhouette first.** Every asset must be recognisable as a flat black shape at the farthest zoom (CI's
  silhouette sheet). A cow and a horse differ in outline, not only in colour.
- **Detail where the eye goes**: faces, doors, the thing's signature feature (`BuildingModel.SIGNATURES`). Plain
  elsewhere.

## Faces (animals and anything with a face)

- Measured, not placed: eyes by proportion of the head, seated on its surface (`face.py`); the same rules for
  every animal, so a new breed gets a face for free.
- Large dark eyes with a highlight and lids that blink; small blush; a simple mouth. Friendly, never scary.

## Colour

- **Saturated but warm**, never neon. Each thing has one main colour, one or two accents, and a dark for small
  marks. Farm greens stay behind the objects: objects are always more saturated than the grass under them.
- **Colour comes from vertex colours or small palette textures**, not photo textures. A breed or variant is a
  different row of colours (`docs/ASSETS.md` §10.6), not a different model.
- Ready-to-collect and other game states are shown by shape and motion as well as colour (colour-blind safe).

## Light

- **Painted-in light** (`animal_art/look.py`): soft shadow in creases and near the ground, backs a little lighter,
  undersides a little darker, shadows cool and coloured (never grey or black). Baked into the colours once.
- **Live light on top**: the game's sun and sky light (day, night, weather) light the asset; the master shader
  adds a warm **rim** on the side away from the camera and the weather (`wetness`, `snow_cover`, `dark`).
- **Outline**: a thin dark outline round the silhouette and along inner steps (a leg in front of a body), drawn by
  the master shader, never modelled.
- **Grounding**: every asset sits on a soft contact shade (`ContactShades`); real sun shadows on mid and up.

## Motion

- Alive, never still: idle breathing, blinking, a tail or leaf sway. Movement has weight: lean into turns, lag,
  squash on landing (`AnimalMotion`). Clips are short loops that blend; nothing snaps.
- Interface motion follows the same feel: press in, spring back, pop in (`UiFx`).

## Scale and the camera

- 1 unit = 1 tile. An adult cow is about one tile long; a chicken about a third.
- Assets are made for the game's one view (`docs/ASSETS.md` §10.2): the side facing the camera and the top carry
  the detail; the far side and the underside can be plain.

## Weight (per asset, near level; Godot makes the far levels)

| | triangles | texture |
| --- | --- | --- |
| animal | ≤ 5,000 | palette only |
| tree, crop bed | ≤ 4,000 | palette or 256² |
| decoration | ≤ 2,500 | palette or 256² |
| building | ≤ 15,000 | 512² |

## Review

A new asset is checked on the contact sheet next to its neighbours (same family, same scale), on the farm at the
closest and farthest zoom, by day, night, rain and snow. It ships when it reads as part of the same world.
