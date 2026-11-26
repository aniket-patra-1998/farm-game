class_name PaintedBloom
extends Node3D
## One flower on the farm as a painted picture (docs/WORLD.md "Crops are painted pictures"): a flat card facing the
## camera, as a crop's plot is (PaintedCrops), standing on the flower's tile. Three looks, by the farm's clock: in
## bud until it is ready, open while it stands ready, and the open picture gone dry once it has withered.
## Its pictures are recipes (tools/paint_plants.py, art/painted/blooms), made into textures when first shown.

const ART := "res://art/painted/blooms/%s.paint"
const PICTURE := Vector2(256, 330)   # a picture's size, in its own pixels..
const FOOT := Vector2(128, 300)      # ..and where the flower stands in it (tools/paint_plants.py)
const CHECK := 1.0                   # seconds between looks at the clock
const BUD := "bud"
const OPEN := "open"
const DRY := "dry"

static var _materials := {}   # "picture|dried" -> ShaderMaterial, shared by every flower showing it
static var _quad: QuadMesh    # the one card every flower is drawn on

var kind := ""     # its family: rose, tulip..
var heads := 1     # 1, or 3 for a full bloom
var _opens := 0.0  # when it is ready (Game.now)
var _dries := Objects3D.NEVER   # ..and when it has withered
var _card: MeshInstance3D
var _look := ""


## The flower `id` (a bloom's catalog id) standing in the middle of footprint `fp`.
static func create(id: String, fp: Vector2i) -> PaintedBloom:
	var out := PaintedBloom.new()
	out.heads = 3 if id.ends_with("_full_bloom") else 1
	out.kind = id.trim_suffix("_full_bloom").trim_suffix("_bloom")
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = PICTURE * PaintedCrops.tiles_per_pixel()
	var quad := _quad
	out._card = MeshInstance3D.new()
	out._card.mesh = quad
	out._card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.add_child(out._card)
	# The card faces the camera with the flower's foot on the tile's middle, then comes towards the camera until its
	# lower edge is out of the ground: the picture is where it was on screen, and the grass no longer cuts its foot.
	var b := PaintedCrops.facing()
	var off := Vector2(PICTURE.x * 0.5 - FOOT.x, FOOT.y - PICTURE.y * 0.5) * PaintedCrops.tiles_per_pixel()
	var at := Vector3(fp.x * 0.5, 0.0, fp.y * 0.5) + b.x * off.x + b.y * off.y
	var sunk := maxf(b.y.y * quad.size.y * 0.5 - at.y, 0.0)
	out._card.transform = Transform3D(b, at + b.z * sunk / maxf(b.z.y, 0.01))
	out._show(BUD)
	return out


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = CHECK
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)


## Tells the flower its cycle: it opens at `opens` and has withered at `dries` (Game.now; Objects3D.NEVER: never).
func set_cycle(opens: float, dries: float) -> void:
	_opens = opens
	_dries = dries
	refresh()


## The look the clock gives it now.
func look_now() -> String:
	var now := float(Game.now())
	return DRY if now >= _dries else (OPEN if now >= _opens else BUD)


## Shows the look the clock gives it, if that is not what it shows.
func refresh() -> void:
	_show(look_now())


## The look it shows (for tests).
func shown() -> String:
	return _look


func _show(look: String) -> void:
	if look == _look:
		return
	_look = look
	var picture := "%s_%d_%s" % [kind, heads, BUD if look == BUD else OPEN]
	var key := "%s|%s" % [picture, look == DRY]
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = PaintedCrops.SHADER
		var image := PaintedCrops.paint_at(ART % picture)
		mat.set_shader_parameter("picture", ImageTexture.create_from_image(image) if image != null else null)
		mat.set_shader_parameter("card", (_card.mesh as QuadMesh).size)
		mat.set_shader_parameter("dried", 1.0 if look == DRY else 0.0)
		_materials[key] = mat
	_card.material_override = _materials[key]


## Lets go of the shared card and materials (a clean quit; Game.release_statics).
static func release_statics() -> void:
	_materials.clear()
	_quad = null
