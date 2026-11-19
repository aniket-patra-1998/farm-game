class_name FolderPackSource
extends PackSource
## Asset packs from a folder (tests, and trying packs on a desktop before they are on the web).

var folder: String


func _init(from: String) -> void:
	folder = from


func fetch(name: String, to: String, done: Callable) -> void:
	done.call(DirAccess.copy_absolute(folder.path_join(name), to) == OK)
