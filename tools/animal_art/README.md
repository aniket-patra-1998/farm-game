# Animal art builder

Builds the farm's animals from code, offline. Nothing here ships in the game or runs on the phone; the game is not
wired to it yet (see "Not done"). Godot ignores this folder (`.gdignore`).

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

## Crops and trees

`plants.py` makes crops and trees in the same style at the game's weight: thin creased leaf cards, each its own
green, low-poly fruit, no soft skin. `python3 -m animal_art export ../../art/models` writes them as the game's model
files (`gltf.py`, glTF `.glb`), and `data/assets.json` lists them, so the game draws them in place of its own:

- **A crop** is one file with a part per growth stage (`when_stage_sprout`, `_young`, `_ripe`, `_withered`). The game's
  crop code draws those parts exactly as it draws its own plants (nine to a plot, growing, swaying, tinted by the
  crop's colour), so produce is marked the way its shader expects: vertex alpha 0, the red channel its shade. Sizes
  come from the plants they replace (`SIZE`).
- **A tree** is one file with its `body` and its fruit as `when_ready_true` and `when_ready_false`. Its leaves are lit
  as the crown, not each by its own tilt. Its entry's `sway` bends it in the wind.
- **Adding one**: write a function like `strawberry(stage)` or `apple_tree()` from `card`, `gem`, `ball`, `bar`, add it
  to `CROPS` or `TREES` and to `SIZE`, export, and list it in `data/assets.json`.

## Not done

- **Animals in the game**: no animal file is written yet, and `animal_3d.gd` is not changed. Planned: one file per
  animal (mesh, baked colours, bones and weights) plus its measured joints, loaded behind a switch.
- **Plants**: four crops and one tree so far; the game's other crop forms and trees are still built by its own code.
- **Ear flick, wing flap, turkey tail display**: the models have no separate ears or wings.
- **Weight**: phone-weight meshes average about 4,900 triangles. There is no mesh simplifier here; thinning is by
  grid size only.
- **Flags by name**: waddle (ducks, goose, swan) and hop (rabbit) are told by the animal's name in `rig.py`; they
  should come from the game's rig data.
- **`natural` head-down** in `motion.py` (arc, follow-through, body dip) is an experiment and off by default.
- The seven four-legged templates repeat their body, legs and neck code; a shared base would make a new family
  quicker.
