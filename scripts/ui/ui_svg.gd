class_name UiSvg
extends RefCounted
## The interface's icons drawn as vector files (art/icons/ui/<kind>.svg, made by tools/make_ui_icons.py; our own
## look: soft gradients, an ink outline, a white sticker edge): each is drawn once at the size it is shown (and
## for the screen's density), so it is crisp at any size, then kept. `of` gives null for a kind with no file.

const DIR := "res://art/icons/ui/"
const LEAST := 32        # the smallest drawing; sizes go up in powers of two, so an icon swelling in a pulse
                         # never draws itself again for every size it passes (mipmaps take it down smoothly)
const OVERSAMPLE := 1.5  # drawn this much larger than shown, then smoothed down (mipmaps)

static var _cache := {}  # "kind:px" -> ImageTexture
static var _source := {} # kind -> the file's text ("" when it has none)


## Whether `kind` has a vector file.
static func has(kind: String) -> bool:
	return _text(kind) != ""


## Icon `kind` drawn `px` pixels across (or null when it has no file).
static func of(kind: String, px: float) -> Texture2D:
	var text := _text(kind)
	if text == "":
		return null
	var side := maxi(LEAST, nearest_po2(int(ceil(px * OVERSAMPLE))))
	var key := "%s:%d" % [kind, side]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	if img.load_svg_from_string(text, side / 128.0) != OK:
		_source[kind] = ""
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _text(kind: String) -> String:
	if not _source.has(kind):
		var path := DIR + kind + ".svg"
		_source[kind] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return _source[kind]
