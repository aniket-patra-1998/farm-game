class_name IconDevelop
extends RefCounted
## Develops an item's picture from two renders of it, one on black and one on white (ItemIcons draws both), the
## way a studio pulls a clean cut-out: where the two agree the model is solid, where they differ it lets the
## background through, by exactly that much. So every picture comes out with true see-through edges on any
## phone's renderer (no grey square behind it, whatever the GPU does with a viewport's transparency), smooth
## edges (both renders are drawn at SUPER times the size and shrunk), and a soft shadow under the item, baked
## in (a sticker lifted off the card; our own look). The work is done a few rows a frame (`step`), so making
## pictures never stalls a frame.

const SUPER := 2              # renders are drawn this many times the picture's size, then shrunk (smooth edges)
const ROWS_PER_STEP := 16     # rows of a picture developed per call of `step` (a small piece of a frame)
const SHADOW_ALPHA := 0.38    # the baked shadow's darkness under a solid item
const SHADOW_DROP := 0.045    # how far below the item it falls, as a share of the picture
const SHADOW_SOFT := 10       # how soft: the shadow is shrunk this many times and grown back (a cheap blur)
const SHADOW_COLOUR := Color(0.16, 0.1, 0.05)

var id := ""
var keep := false
var shadow := true
var done := false
var picture: Image

var _black: PackedByteArray
var _white: PackedByteArray
var _out: PackedByteArray
var _shade: PackedByteArray
var _raw: Array = []   # the two renders still to bring to size (black, then white)
var _side := 0
var _row := 0


## Starts developing `id` from its two renders, shrunk to `side` pixels.
func _init(item_id: String, black: Image, white: Image, side: int, keep_it: bool, with_shadow: bool) -> void:
	id = item_id
	keep = keep_it
	shadow = with_shadow
	_side = side
	_raw = [black, white]   # (brought to size in `step`, one a call: never a whole picture's work in one frame)
	_out = PackedByteArray()
	_out.resize(side * side * 4)
	_shade = PackedByteArray()
	_shade.resize(side * side * 4)


## Develops the next rows; true once the picture is ready (`picture`).
func step() -> bool:
	if done:
		return true
	if not _raw.is_empty():
		var img: Image = _raw.pop_front()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != _side:
			# An exact halving averages each 2x2 block (bilinear at half size): the supersampled edge, smooth.
			img.resize(_side, _side, Image.INTERPOLATE_BILINEAR)
		if _raw.size() == 1:
			_black = img.get_data()
		else:
			_white = img.get_data()
		return false
	var end := mini(_row + ROWS_PER_STEP, _side)
	for p in range(_row * _side * 4, end * _side * 4, 4):
		var alpha := clampi(255 - (int(_white[p + 1]) - int(_black[p + 1])), 0, 255)
		if alpha == 0:
			continue
		var f := 255.0 / alpha
		_out[p] = mini(int(_black[p] * f), 255)
		_out[p + 1] = mini(int(_black[p + 1] * f), 255)
		_out[p + 2] = mini(int(_black[p + 2] * f), 255)
		_out[p + 3] = alpha
		_shade[p] = SHADOW_COLOUR.r8   # (an empty pixel stays black: near the shadow's colour, so no fringe)
		_shade[p + 1] = SHADOW_COLOUR.g8
		_shade[p + 2] = SHADOW_COLOUR.b8
		_shade[p + 3] = int(alpha * SHADOW_ALPHA)
	_row = end
	if _row >= _side:
		picture = _finished()
		done = true
	return done


## The cut-out on its soft shadow.
func _finished() -> Image:
	var item := Image.create_from_data(_side, _side, false, Image.FORMAT_RGBA8, _out)
	if not shadow:
		return item
	var shade := Image.create_from_data(_side, _side, false, Image.FORMAT_RGBA8, _shade)
	var small := maxi(_side / SHADOW_SOFT, 4)
	shade.resize(small, small, Image.INTERPOLATE_BILINEAR)
	shade.resize(_side, _side, Image.INTERPOLATE_CUBIC)
	var out := Image.create(_side, _side, false, Image.FORMAT_RGBA8)
	var drop := int(_side * SHADOW_DROP)
	out.blit_rect(shade, Rect2i(0, 0, _side, _side - drop), Vector2i(0, drop))
	out.blend_rect(item, Rect2i(0, 0, _side, _side), Vector2i.ZERO)
	return out
