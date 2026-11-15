# Asset architecture

How the game's art (models, animation, materials, pictures, sound) is made, shipped, loaded and drawn. One
design for every kind of asset, so a new or better asset is a new file, never new engine work. It follows what
high-quality mobile and console games do: art is made offline as files, the engine imports it under rules, and
the game only ever asks for an asset by name.

## Rules (the short version)

1. **Looks and smoothness first.** Size is not a constraint up to 250 MB installed; anything that can be made
   ahead of time is made ahead of time, at full quality.
2. **Code never builds art at runtime.** Art is a file. Code places, poses, tints and animates it.
3. **The game asks by name.** Catalog item → asset id → files, through one registry. Nothing else knows a path.
4. **Every asset has a fallback.** A missing or broken asset shows its stand-in, logs once, and CI fails.
5. **Every asset has a budget**, per quality level, checked in CI.

## 1. Authoring: where art comes from

Any tool may make an asset, as long as it writes the interchange format:

| Source | Used for | Writes |
| --- | --- | --- |
| Our builders (`tools/animal_art`, later `tools/building_art`...) | animals, buildings, decor made from rules | glTF 2.0 (`.glb`) |
| Blender, by hand or bought | anything special, heroes, marketing | glTF 2.0 |
| Today's code models (`ModelKit`) | the stand-in until a file exists | exported to glTF by a tool, once |

glTF 2.0 is the interchange: it carries meshes, materials, skeletons, skin weights, animation clips and morph
targets, and Godot imports it natively. Our builders' Python never runs on a phone or in the game.

**Conventions every file follows** (checked by CI, `tools/asset_lint`):
- 1 unit = 1 tile; origin at the footprint's centre on the ground; facing +X.
- Named parts the game needs: `door`, `window_*`, `smoke`, `yard`, `slot_*` (where produce or animals stand).
- Animals: one skeleton per family with standard bone names (`root, hips, spine, neck, head, jaw, tail_*,
  leg_{fl,fr,hl,hr}_{upper,lower,foot}, ear_{l,r}, wing_{l,r}, eye_{l,r}`), so clips are shared by every breed
  of a family (retargeting by name).
- Clips by standard names: `idle, walk, run, graze, eat, peck, hop, waddle, sleep, react, blink, ear_flick,
  wing_flap, display`. Any clip may be missing (see §4).

## 2. Import: rules applied once, when the game is built

Godot's importer turns each `.glb` into a game resource. Per asset type, an import script
(`EditorScenePostImport`, one per type) applies the same rules every time:
- **Levels of detail**: Godot generates them (`meshes/generate_lods`), plus a **shadow mesh**
  (`meshes/create_shadow_meshes`) so shadows cost the low level.
- **Far stand-in (impostor)**: for things seen from the farm's zoomed-out view (trees, buildings, animals), a
  pre-rendered picture from the game's fixed camera angle, drawn as a camera-facing card at far zoom. This is
  how Hay Day/Township-style games keep huge farms cheap: detail costs nothing when it is too small to see.
- **Materials** are replaced by instances of our master materials (§3) by name; textures are compressed for
  phones (ETC2/ASTC) and given mipmaps.
- **Collision/picking** shape from the footprint, not the mesh.
- **Validation**: triangles, bones, textures and size against the type's budget; a failing asset fails the build.

## 3. Materials: a few master shaders, many instances

All assets draw with a handful of **master shaders** (`shaders/master_*.gdshader`): `solid` (painted, baked
light, rim, optional outline), `foliage` (sway, translucency), `water`, `glass`, `glow`. A material is an
instance with parameters (colour, texture set, shine), never a new shader. All of them read the global shader
values (`wetness`, `snow_cover`, `dark`) so weather and night apply to every asset. Textures of a kind share an
atlas or texture array, so a building is one or two draws whatever its detail.

## 4. Animation: clips, blended, with layers; crowds on the GPU

- **Near animals** (on screen and close): a `Skeleton3D` driven by an `AnimationTree` state machine
  (idle ↔ walk ↔ graze...), blended, with **additive layers** on top that code drives: look-at, blink, breathing,
  tail sway, the springs we already have (`AnimalMotion`: lean, lag, squash). `AnimalBehaviour` (the mind) only
  chooses states; it never poses bones.
- **Missing clips fall back** along a chain: `waddle → walk → idle`, `peck → graze → eat → idle`,
  `wing_flap → (skip)`. An animal without ears simply never flicks them.
- **Crowds and far animals**: the clips are baked into **vertex animation textures** (every frame's pose stored
  in a texture, read by the vertex shader), and animals are drawn as `MultiMesh` batches with per-instance
  clip, time and tint. Hundreds of animals cost a few draws and almost no CPU (the technique in GPU Gems 3,
  "Animated crowd rendering").
- **Animation LOD**: close animals update every frame, mid every other, far ones run on the GPU only.

## 5. The registry: one way to ask for an asset

`AssetRegistry` (autoload) maps an asset id to its files and options, from `data/assets.json`, generated from the
catalog plus overrides:

    "cow": {"model": "res://art/animals/cow.glb", "family": "cow", "impostor": true, "budget": "animal"}

`AssetRegistry.instance(id, variant)` returns a ready node (from a shared, already-loaded resource);
`AssetRegistry.batch(id)` returns what a `MultiMesh` needs. Callers never load paths. If the file is missing, the
registry returns today's code-built model (`ModelKit`) as the stand-in, so moving to files can go one asset at a
time and nothing ever breaks.

## 6. Loading: in the background, before it is needed

- A farm's **asset list** (every id on it) is known from the save. The loading screen loads them on worker
  threads (`ResourceLoader.load_threaded_request`) and shows progress; the farm appears whole, nothing pops in.
- The Market and inbox preload what their visible cards need, and whatever is being placed.
- Loaded resources are shared and counted; ones no longer on the farm are let go past a memory budget.

## 7. Budgets per quality level (data/perf_budget.json)

| | low | mid | high |
| --- | --- | --- | --- |
| animal, near (triangles) | 2,500 | 5,000 | 8,000 |
| building, near | 8,000 | 15,000 | 30,000 |
| texture per asset | 256² | 512² | 1024² |
| draws on the showcase | 600 | 900 | 1,400 |

Lower levels use lower LODs sooner (`Quality`), not different assets. CI renders the showcase on every level and
fails a change that breaks a budget.

## 8. Pictures and sound

- **Item pictures** are rendered from the same assets by CI (`tools/bake_icons`), never on a phone.
- **Sound**: recordings (`.ogg`) or recipes baked by CI; the registry maps sound ids the same way.

## 9. Checks in CI

- `asset_lint`: conventions, bone and clip names, budgets, every catalog item has an asset or a stand-in.
- Contact sheet and turntables of every asset; screenshot comparison against the last build.
- The performance probe on the showcase per quality level, against the budgets.

## Order of work

1. Registry with stand-in fallback, master shaders, import scripts with LODs and validation (no visible change).
2. Animals on it: the animal builder writes `.glb` with family skeletons and clips; AnimationTree near, vertex
   animation crowds far; impostors.
3. Background loading and the loading screen's asset list.
4. Buildings, trees, decor and crops moved to files, family by family.
5. Budgets per level enforced in CI; old code-built models kept only as stand-ins.
