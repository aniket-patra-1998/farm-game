class_name SpriteBank
extends RefCounted
## Finished art from art/final/ (made by tools/generate_art.ipynb). Each image is drawn so its
## anchor (the ground centre, in image pixels) lands on the object's ground centre on the farm.
## Anything without art keeps its code-drawn placeholder.
##
## Painted art is off while the game's look is settled in code (project setting farm/art/use_painted_art):
## everything is drawn and animated by code until the art is decided.

const SETTING := "farm/art/use_painted_art"
const DEFAULT_DIR := "res://art/final"

static var dir := DEFAULT_DIR  ## where art is read from; tools can point it at a pilot style
static var _loaded := false
static var _sprites := {} # id -> {"tex": Texture2D, "anchor": Vector2, "scale": float}


static var _forced := false  # an explicit folder (tools, tests) is used whatever the setting says


## Reads art from another folder (used to preview pilot styles); always used, whatever the setting.
static func use_dir(path: String) -> void:
	dir = path
	_forced = true
	_loaded = false
	_sprites.clear()


## Back to the game's own art folder and the project setting.
static func use_default() -> void:
	use_dir(DEFAULT_DIR)
	_forced = false


static func _load() -> void:
	_loaded = true
	if not _forced and not bool(ProjectSettings.get_setting(SETTING, false)):
		return
	var path := dir + "/sprites.json"
	if not FileAccess.file_exists(path):
		return
	var meta = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(meta) != TYPE_DICTIONARY:
		return
	for name in meta:
		var id := str(name).split("__")[0] # "cow__0" -> "cow"; the first variant wins
		if _sprites.has(id):
			continue
		var file := dir + "/" + str(name) + ".png"
		if not ResourceLoader.exists(file) and not FileAccess.file_exists(file):
			continue
		var tex: Texture2D = load(file) if ResourceLoader.exists(file) else ImageTexture.create_from_image(
			Image.load_from_file(ProjectSettings.globalize_path(file))
		)
		var a: Array = meta[name]["anchor"]
		_sprites[id] = {
			"tex": tex,
			"anchor": Vector2(float(a[0]), float(a[1])),
			"scale": float(meta[name].get("scale", 0.5))
		}


static func has(id: String) -> bool:
	if not _loaded:
		_load()
	return _sprites.has(id)


## Draws the sprite with its anchor on ground. size_scale shrinks or grows it (1.0 = as made).
static func draw(ci: CanvasItem, id: String, ground: Vector2, size_scale := 1.0) -> void:
	if not has(id):
		return
	var s: Dictionary = _sprites[id]
	var k: float = s["scale"] * size_scale
	var tex: Texture2D = s["tex"]
	var at: Vector2 = ground - (s["anchor"] as Vector2) * k
	ci.draw_texture_rect(tex, Rect2(at, tex.get_size() * k), false)
