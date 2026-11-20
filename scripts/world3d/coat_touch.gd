class_name CoatTouch
extends RefCounted
## A limited animal's own touch (docs/LIMITED.md; the catalog's `touch`): what its coat does that no other does.
##
## The colour touches are worked out for each point by the shared material's shader
## (shaders/coat_touch.gdshaderinc) from what the file says of the point (tools/animal_art export.py
## `_touch_points`): stars blink, a rainbow's colours turn, a sunset's sway, a glint runs over gold, embers
## flicker. `dress` turns the touch on for an animal's mesh. A long coat's shake is two of the file's own moves
## blended in turn (`shake_weights`), with a little fluff let go (`shed`); when it shakes is its mind's
## (AnimalBehaviour.shakes). Every limited animal also shows off when tapped (AnimalBehaviour.showy).

const MODES := {"stars": 1, "rainbow": 2, "sunset": 3, "glint": 4, "embers": 5}   # the shader's `touch` for each
const SHAKE := "shake"
const SHAKE_A := "shake_a"       # not-ui (the file's two shake moves: export.py _shake_moves)
const SHAKE_B := "shake_b"       # not-ui
const SHAKE_SWINGS := 5.5        # how many times the coat swings in one shake
const FLUFF := 8                 # tufts a shake lets go
const FLUFF_SIZE := 0.05         # a tuft's size, of the animal's own
const FLUFF_LIFE := 1.2          # seconds a tuft drifts before it is gone
const FLUFF_FALL := 0.35         # how fast it starts down (tiles a second)
const FLUFF_DRIFT := 0.15        # and sideways, at most
const FLUFF_LIGHT := 0.18        # how much lighter than the coat a tuft is

static var _materials := {}      # touch and coat colour -> the material for them (shared by every animal of them)


## The touch of an item (its catalog data): "" for none.
static func of(it: Dictionary) -> String:
	return str(it.get("touch", ""))


## Turns the item's colour touch on for its mesh `mi`: the mesh's own material with the touch set, one for every
## animal of that touch and coat colour. Nothing for an animal with no colour touch.
static func dress(mi: MeshInstance3D, it: Dictionary) -> void:
	var mode := int(MODES.get(of(it), 0))
	var base := mi.mesh.surface_get_material(0) as ShaderMaterial if mi.mesh.get_surface_count() > 0 else null
	if mode == 0 or base == null:
		return
	var coat := Color(str(it.get("color", "#ffffff")))
	var key := "%d %s" % [mode, coat.to_html(false)]
	if not _materials.has(key):
		var touched := base.duplicate() as ShaderMaterial
		touched.set_shader_parameter(&"touch", mode)
		touched.set_shader_parameter(&"touch_colour", Vector3(coat.r, coat.g, coat.b))   # (as the file's colours are)
		_materials[key] = touched
	mi.set_surface_override_material(0, _materials[key])


## How much of each shake move shows `through` a shake (0..1; AnimalPose.shake): x for SHAKE_A, y for SHAKE_B.
## Together they are a twist running down the animal that swells and dies away; nothing at 0 and at 1.
static func shake_weights(through: float) -> Vector2:
	var swell := sin(clampf(through, 0.0, 1.0) * PI)
	var beat := TAU * SHAKE_SWINGS * through
	return Vector2(sin(beat), cos(beat)) * swell


## A shake lets go a few tufts of the coat: they start round the animal's back (`at` its feet, `r` its half
## sizes, in `puffs`' own space), fall, drift and fade. `coat` is the coat's colour.
static func shed(puffs: DustPuffs, at: Vector3, r: Vector3, coat: Color) -> void:
	var tuft := coat.lightened(FLUFF_LIGHT)
	for k in FLUFF:
		var from := at + Vector3(randf_range(-0.7, 0.7) * r.x, randf_range(1.0, 1.9) * r.y, randf_range(-0.7, 0.7) * r.z)
		var going := Vector3(randf_range(-1.0, 1.0) * FLUFF_DRIFT, -FLUFF_FALL, randf_range(-1.0, 1.0) * FLUFF_DRIFT)
		puffs.emit(from, going, FLUFF_SIZE * maxf(r.x, r.z) * 2.0, FLUFF_LIFE * randf_range(0.7, 1.0), tuft, 1.0)
