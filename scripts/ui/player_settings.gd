class_name PlayerSettings
extends RefCounted
## The player's own settings on this device (not the farm's save): sound, graphics, the window, the debug
## readout. One file, user://settings.cfg, read and written only here, so each owner (Sound, Quality, Display,
## PerfReadout) keeps its section and no two copies of the loading and saving drift apart.

const PATH := "user://settings.cfg"


## The value of `key` in `section`, or `otherwise` when it was never set.
static func value(section: String, key: String, otherwise: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return otherwise
	return cfg.get_value(section, key, otherwise)


## Keeps `values` ({key: value}) in `section`, leaving every other setting as it was.
static func keep(section: String, values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for key: String in values:
		cfg.set_value(section, key, values[key])
	cfg.save(PATH)
