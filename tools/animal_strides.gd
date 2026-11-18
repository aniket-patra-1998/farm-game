extends Node
## Writes data/animal_strides.json: every file-made animal's stride (Animal3D.measure_stride) with the
## fingerprint of the file it was measured from (data/art_versions.json), so a farm opening never reads every
## move of every animal file to work them out (~3 ms a kind). Run after changing animal art or how a stride is
## measured (test 513 says when):
##   godot --headless --path . res://tools/animal_strides.tscn


func _ready() -> void:
	var strides := {}
	for id: String in Animal3D.stride_kinds():
		strides[id] = {"file": ArtVersion.file_of(id), "stride": Animal3D.measure_stride(id)}
	var out := {
		"_doc": "Written by tools/animal_strides (do not edit): each file-made animal's stride, the ground one"
			+ " cycle of its walk covers in tiles at full size (Animal3D.file_stride), and the fingerprint of the file"
			+ " it was measured from. A kind whose file has changed since is measured as the farm opens instead.",
		"strides": strides,
	}
	var f := FileAccess.open(Animal3D.STRIDES, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true, true) + "\n")
	f.close()
	print("animal_strides: %d kinds" % strides.size())   # not-ui (a tool's log line)
	get_tree().quit()
