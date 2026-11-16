class_name IconStyle
extends SubViewport
## The pictures' flat sticker look (our own look, docs/UI.md): every finished picture (IconDevelop's cut-out) is
## drawn once through shaders/icon_flat.gdshader on the GPU (two tones, lines where tones meet, a dark outline
## and a white edge) before it is shown and kept, so the cards, sheets and the Barn all show it and nothing costs
## anything while playing. One picture a turn: `take` gives it, two frames later `finished` hands it back.

const SHADER := preload("res://shaders/icon_flat.gdshader")
const WAIT_FRAMES := 2   # frames from asking for a draw to its image being ready to read

var _rect: TextureRect
var _job: IconDevelop
var _wait := 0


func _init() -> void:
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rect = TextureRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_rect.material = mat
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_rect)


## Whether a picture is being styled.
func busy() -> bool:
	return _job != null


## Whether the picture of `id` is being styled now.
func holds(id: String) -> bool:
	return _job != null and _job.id == id


## Starts styling `job`'s picture.
func take(job: IconDevelop) -> void:
	_job = job
	size = job.picture.get_size()
	_rect.size = Vector2(size)
	_rect.texture = ImageTexture.create_from_image(job.picture)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	_wait = WAIT_FRAMES


## The job whose picture is styled now (its `picture` replaced), or null while still drawing.
func finished() -> IconDevelop:
	if _job == null:
		return null
	_wait -= 1
	if _wait > 0:
		return null
	var image := get_texture().get_image()
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		_job.picture = image
	var job := _job
	_job = null
	return job
