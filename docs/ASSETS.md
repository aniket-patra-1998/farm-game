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
- Named parts the game needs: `door` / `door_left` (direct children of the root: they swing open on collect),
  `window_*` (where animals look out; the part's scale sizes the head), `yard`, `slot_*`.
- Named parts that move (`DecorMotion.start`): a part named for an effect (`smoke_*`, `steam_*`, `jet_*`,
  `pour_*`, `grain_*`, `sparkle_*`: `DecorMotion.EFFECTS`) starts that effect where it stands; `spin_<speed>_*` turns about
  its own upright (the speed in hundredths of a radian a second). The file holds the part and its name, never the effect.
- States: a part named `when_<state>_<value>` shows only in that state (§10.4). States that come and go (ready,
  at work, how full) are switched on the model that stands. A building's level and its construction stage are
  a file each (`{level}` and `{stage}` in its paths in data/assets.json), so only what stands is loaded.
- Which kinds may come from files today: buildings, trees, plain decorations and blooms
  (`Objects3D.FILE_KINDS`). Animals, vehicles, young ones and joining fences and hedges get their file path
  with their own step, as they need more than a model (clips, implements, joins).
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
- **Materials**: every plain material becomes an instance of the master material (§3) with its colour and
  texture (`AssetRegistry.master_for`, as the asset is drawn); a ShaderMaterial the artist chose is kept.
  Textures are compressed for phones (ETC2/ASTC) and given mipmaps.
- **Collision/picking** shape from the footprint, not the mesh.
- **Validation**: triangles, bones, textures and size against the type's budget; a failing asset fails the build.

## 3. Materials: a few master shaders, many instances

All assets draw with a handful of **master shaders** (`shaders/master_*.gdshader`): `solid` (painted, baked
light, rim, optional outline), `foliage` (sway, translucency), `water`, `glass`, `glow`. A material is an
instance with parameters (colour, texture set, shine), never a new shader. All of them read the global shader
values (`wetness`, `snow_cover`, `dark`) so weather and night apply to every asset. Textures of a kind share an
atlas or texture array, so a building is one or two draws whatever its detail.

Today: `master_solid` is the master every plain material in a file becomes (`AssetRegistry.master_for`). A
builder names its materials `paint` or `wall` (`ModelKit.FILE_PAINT`, `FILE_WALL`); those get the parameters
that read each part's shine or surface pattern from its vertex alpha (`alpha_holds`; the patterns are
shaders/surface_patterns.gdshaderinc, shared with the builders' own wall shader). Glass, pools of light, the
shade at a building's foot and water are the kit's single shared materials, put back by the names the file
gives them (`kit_glass`, `kit_glow`, `kit_shade`, `kit_water`, `kit_pond`, `kit_shine`: `ModelKit.adopt`). A crafting building is 6 to
8 draws: walls, paint and glass, the light pools, the shade, its storage look and its animated parts.

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

`AssetRegistry` (scripts/world3d/asset_registry.gd) maps an asset id to its file and budget, from
`data/assets.json` (budgets per kind live there too):

    "cow": {"model": "res://art/animals/cow.glb", "family": "cow", "impostor": true, "budget": "animal"}

`AssetRegistry.instance(id, state)` returns a ready node in that state (from a shared, already-loaded
resource); `Objects3D` and `ItemIcons` ask it first. (Batches for `MultiMesh` crowds come with the animals.) Callers never load paths. If the file is missing, the
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

- `tests/suites/assets_test.gd`: every listed asset loads and fits its triangle and draw budgets and its
  footprint; a real glTF fixture (tests/fixtures, made by tools/make_asset_fixture.gd) goes through Godot's
  import (shadow meshes) and the registry's rules; states, named parts, kept materials and the stand-in
  fallback work. (Bone and clip names come with the animals.)
- Contact sheet and turntables of every asset; screenshot comparison against the last build.
- The performance probe on the showcase per quality level, against the budgets.

## 10. Contracts the rest depends on

These decide whether the system holds up for years. Each is fixed once and checked in CI.

1. **Art direction bible** (`docs/ART_BIBLE.md`: the new animals' style, with reference sheets): shape language, proportions per family,
   palette, how light and colour are painted, line and outline, how cute vs real, how readable at the farthest
   zoom (silhouette test). Every asset, from any source, is reviewed against it. Without it, assets from our
   builders, Blender and bought packs never look like one game.
2. **The camera contract**: orthographic, turned 45° and tilted 30° down (`IsoProjection.PITCH`: tiles are
   twice as wide as tall, the 2:1 view of FarmVille), looking toward the farm's back corner; zoom from about
   `CLOSEST_TILES` (3.5) tiles across to `FURTHEST_OUT` past the whole farm; never rotated. Impostors, item pictures and the bible's readability rules are made for exactly this
   view; if the camera ever rotates, impostors need several angles, so the contract is written down.
3. **The lighting model**: a real-time sun (elevation 9°–58° over the day, `Farm3D.SUN_*`, the moon at night), a
   soft fill from the other side and a coloured ambient (day, night, weather move them, `Farm3D`), soft ambient occlusion
   baked into each asset's colours (never lightmaps: things on a farm move), contact shades under everything,
   real shadows from the sun on mid and up. The master shaders implement it; assets never bring their own lights.
4. **Asset states**: every way a thing changes on the farm is one mechanism, named in the file: building levels
   and construction stages (named child nodes `level_2`, `stage_1`...), ready, withered, empty or full, door
   open, seasons and snow (master material parameters), and animal clips. The game sets a state by name; an asset
   without that state ignores it.
5. **Gameplay is not art**: footprint, picking shape, slots and attach points come from the catalog; the art must
   fit inside its footprint (checked), and saves never name an art file. Replacing all the art never touches a
   save or a rule.
6. **Variation without new files**: tint, pattern and wear per placed thing are per-instance shader values; a new
   breed colour is a row of numbers, not a model.
7. **One world**: the 2D world is retired when the registry lands; keeping it would double every asset.

## 11. Production realities

- **Store size**: an Android App Bundle's base module may be up to 500 MB compressed (4 GB a device in all;
  developer.android.com/guide/app-bundle/faq, checked November 2026), so
  the 250 MB target ships as one module with no asset packs.
- **Repository**: generated files are not committed; CI builds them from their sources (builder code, `.blend`
  files) and caches them by the sources' hash. Hand-made binary sources (`.blend`, bought packs) live in Git LFS.
  Every builder is deterministic: the same source gives the same file.
- **Provenance**: the registry records each asset's source and licence (made here, bought, commissioned).
- **Shader warm-up**: the loading screen draws every master material with every mesh format once, off screen,
  so the first time a thing appears never hitches (Godot's ubershaders cover most of it; this removes the rest).
- **Effects, interface, sound** follow the same rules: particles and effects are assets with budgets; the
  interface's pictures, fonts and nine-slices are one atlas; music and ambience are recordings, loudness-matched.
- **Real phones decide**: CI measures CPU and draw calls but not a phone's GPU, heat or battery. A low and a mid
  reference phone run the showcase after each big change (the in-game readout, Settings > Testing); their numbers
  set the budgets in §7, and the frame rate held after 10 minutes is the number that counts.
- **Godot gaps we fill ourselves**: far impostors and vertex-animation crowds are not built into Godot; both are
  well-known techniques we write once (a baker tool and two shaders). An `AnimationTree` per animal costs CPU on a
  phone, so only near animals get one; mid animals play plain clips; far ones run on the GPU.
- **Moving over safely**: one family at a time, behind a switch, each with a before-and-after screenshot and
  performance comparison; the stand-in stays until the file version wins on both.

## Order of work

1. The contracts (§10: art bible, camera, lighting, states), then the registry with stand-in fallback, master
   shaders, import scripts with LODs and validation (no visible change).
2. Animals on it: the animal builder writes `.glb` with family skeletons and clips; AnimationTree near, vertex
   animation crowds far; impostors.
3. Background loading and the loading screen's asset list.
4. Buildings, trees, decor and crops moved to files, family by family.
5. Budgets per level enforced in CI; old code-built models kept only as stand-ins.
