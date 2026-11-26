# Animal art builder

Builds the farm's animals from code, offline. Nothing here ships in the game or runs on the phone; what it exports
("Into the game") does. Godot ignores this folder (`.gdignore`).

    pip install -r requirements.txt
    python3 -m animal_art list
    python3 -m animal_art sheet  cows.png  "cow,brown cow,pink cow|bull,ox"
    python3 -m animal_art poses  poses.png "cow,horse,red chicken,turtle"
    python3 -m animal_art clip   farm.gif  "cow,horse,pig,sheep"
    python3 -m unittest discover -s tests

The player's farmer is made here too (`farmer.py`): `python3 -m animal_art farmer ../../art/models/farmer` writes one
file per hair style. It uses the same skin, drawings and painted light, with its own shapes, face and moves.

## How an animal is made

1. **Template** (`families/`): a family is one function that turns a row of settings (build, legs, ears, tail, coat,
   pattern) into a list of soft shapes, a few hard parts (horns, beak, feet) and the face's options. A breed is a row.
2. **Skin** (`shapes.py`, `skin.py`): the shapes melt into one field, which is meshed, relaxed, coloured by the nearest
   shape, and refined along colour borders.
3. **Face** (`head.py`, `face.py`, `decal.py`): the head is measured, and eyes, blush and mouth are placed by
   proportion and seated on its surface. No coordinates per animal.
4. **Light** (`look.py`): shadow in creases and near the ground, lighter backs, baked into the colour once.
5. **Joints and weights** (`rig.py`): feet, knees, hips, neck, head, nose and tail are measured from the finished
   model, and every point is given the parts it follows. No joint list per animal.
6. **Motion** (`motion.py`): the game's own maths (`scripts/world3d/animal_3d.gd`, `AnimalArt`, `AnimalBehaviour`),
   copied so previews show what the game would do.
7. **Previews** (`render.py`, `preview.py`): a small software renderer with the intended look (two-tone light, rim,
   outline, ground shadow). In the game these belong to one shader and the existing contact shades.

`registry.py` names every animal: the game's 73 (`GAME`) and extras that are built but not in the game (`PARKED`).
`build.py` ties the steps together; `lightest()` finds the lightest mesh that still holds together.

## Adding animals

- **A breed**: add a row to the family's table (for example `COWS` in `families/cow.py`). Its baby follows from the
  family's rule in `registry.py`.
- **A bird kind**: add a row to `BIRDS` in `families/bird.py`.
- **A limited coat** (the game's limited animals, docs/LIMITED.md): add a row to its family's table in `limited.py`,
  made from one of the family's breeds. A pattern is asked for with `paint=dict(kind=...)` and curls with `tufts=1`
  (`paint.py`: stripes, stars, dots, patches, rainbow, dip, band, half); the registry gives it its baby by the
  family's rule. A coat that turns colour does it in flat bands (`paint._steps`), or its file is five times the size.
- **A family**: write a template in `families/`. Two things are asked of it: its first shape is the body, and the
  head's shapes are marked `head=True`. Mark a part only when the animation must know it (`part="stub"`: a leg that
  slides under a shell). Then register it in `registry.py`.

## Into the game

    python3 -m animal_art export ../../art/models/animals "chicken"

writes `art/models/animals/chicken.glb` (a limited animal's file goes to `art/models/limited/` beside it): the mesh with its colours and painted light, the bones it hangs on, and its moves
(`export.py`: the walk cycle in 8 frames, head down, look left and right, blink, tail, breath), each made by this
package's own motion and stored as where each bone goes (`export._rigged`), never as a copy of the mesh: 17 copies
were nine tenths of a file. A part that moves on its own (an eye, an ear, a wing, a fan) has bones of its own;
only a long coat's shake is still stored point by point. Listed in `data/assets.json` (`"budget": "animal"`),
the game draws it instead of the code-built animal and asks for each move from the pose it already works out
(`Animal3D._pose_file`; `AnimalBones` adds the moves up bone by bone). Moves the file doesn't have are simply
not shown.

One command makes every animal's file again and brings the game's lists in step (run it after any change to this
package, or after adding a row):

    bash tools/remake_animals.sh path/to/godot

It exports every game animal, writes the data of any limited coat that has none yet (`tools/make_limited.py`),
imports the files, and makes the art versions, the art manifest, the catalog document and the strides again.
An animal whose builder did not change comes out byte for byte the same.

**Eyes on dark faces**: an eye whose face is dark (`face.DARK_FACE`) gets a pale rim in place of its dark
outline and an amber iris (`decal.PALE_RIM`, `AMBER`), or it is lost from the farm's distance. It is decided for
each eye by the colour under it, so an animal with one eye in a dark patch has one light eye.

## Not done

- **Weight**: phone-weight meshes average about 4,900 triangles. There is no mesh simplifier here; thinning is by
  grid size only.
- **Flags by name**: waddle (ducks, goose, swan) and hop (rabbit) are told by the animal's name in `rig.py`; they
  should come from the game's rig data.
- **`natural` head-down** in `motion.py` (arc, follow-through, body dip) is an experiment and off by default.
- The seven four-legged templates repeat their body, legs and neck code; a shared base would make a new family
  quicker.
