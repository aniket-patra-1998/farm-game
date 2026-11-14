class_name PlayerSettings
extends RefCounted
## The player's own settings on this device (not the farm's save): sound, graphics, the window, the debug
## readout. One file, user://settings.cfg, read and written only here, so each owner (Sound, Quality, Display,
## PerfReadout) keeps its section and no two copies of the loading and saving drift apart.

const PATH := "user://settings.cfg"


## The value of `key` in `section`, or `otherwise` when it was never set.
static func value(section: String, key: String, otherwise: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.has_section_key(section, key):
		return otherwise   # (a null default is allowed: ConfigFile alone would call that an error)
	return cfg.get_value(section, key)


## Keeps `values` ({key: value}) in `section`, leaving every other setting as it was (a null value forgets the key).
static func keep(section: String, values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for key: String in values:
		if values[key] == null and not cfg.has_section_key(section, key):
			continue
		cfg.set_value(section, key, values[key])
	cfg.save(PATH)
