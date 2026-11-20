class_name PackSource
extends RefCounted
## Where asset packs come from (AssetPacks): something that can bring a named file to a place on the device.
## The web is one (HttpPackSource), a folder another (FolderPackSource: tests, and trying packs on a desktop).


## Brings the file `name` to `to` (a path on the device), then calls `done` with whether it came.
func fetch(_name: String, _to: String, _done: Callable) -> void:
	pass
