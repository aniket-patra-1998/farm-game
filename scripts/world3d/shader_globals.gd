class_name ShaderGlobals
extends RefCounted
## The one way to set a global shader value (project.godot's [shader_globals]: wetness, snow_cover, dark,
## wind...). It remembers each value, because the engine can only be asked for one in the editor; code that
## needs to know the farm's mood (item pictures are kept only on a clear, dry day) reads `value`. A test
## forbids setting one any other way. The one exception is `crop_clock`, set every frame by Crops3D, which
## nothing reads back.

static var _values := {}


## Sets global `name` to `value` for every shader, and remembers it.
static func set_value(name: StringName, value: Variant) -> void:
	_values[name] = value
	RenderingServer.global_shader_parameter_set(name, value)


## The value `name` was last set to here (`otherwise` when it hasn't been).
static func value(name: StringName, otherwise: Variant = 0.0) -> Variant:
	return _values.get(name, otherwise)


## Forgets every value (a new farm, or a test, starts from a calm day).
static func reset() -> void:
	_values.clear()
