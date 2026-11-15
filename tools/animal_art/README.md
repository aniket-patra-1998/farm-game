# Animal art builder

Builds the farm's animals from code, offline. Nothing here ships in the game or runs on the phone; what it exports
("Into the game") does. Godot ignores this folder (`.gdignore`).

    pip install -r requirements.txt
    python3 -m animal_art list
    python3 -m animal_art sheet  cows.png  "cow,brown cow,pink cow|bull,ox"
    python3 -m animal_art poses  poses.png "cow,horse,red chicken,turtle"
    python3 -m animal_art clip   farm.gif  "cow,horse,pig,sheep"
    python3 -m unittest discover -s tests

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
- **A family**: write a template in `families/`. Two things are asked of it: its first shape is the body, and the
  head's shapes are marked `head=True`. Mark a part only when the animation must know it (`part="stub"`: a leg that
  slides under a shell). Then register it in `registry.py`.

## Into the game

    python3 -m animal_art export ../../art/models/animals "chicken"

writes `art/models/animals/chicken.glb`: the mesh at rest with its colours and painted light, and its moves as
blend shapes (`export.py`: the walk cycle in 12 frames, head down, look left and right, blink, tail, breath),
each made by this package's own motion. Listed in `data/assets.json` (`"budget": "animal"`), the game draws it
instead of the code-built animal and sets the blend shapes from the pose it already works out
(`Animal3D._pose_file`). Moves the file doesn't have are simply not shown.

## Not done

- **Weight**: phone-weight meshes average about 4,900 triangles. There is no mesh simplifier here; thinning is by
  grid size only.
- **Flags by name**: waddle (ducks, goose, swan) and hop (rabbit) are told by the animal's name in `rig.py`; they
  should come from the game's rig data.
- **`natural` head-down** in `motion.py` (arc, follow-through, body dip) is an experiment and off by default.
- The seven four-legged templates repeat their body, legs and neck code; a shared base would make a new family
  quicker.
