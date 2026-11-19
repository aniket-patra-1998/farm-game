class_name TreeSpec
extends RefCounted
## What a tree is (data/tree_shapes.json): its kind's shape (form and sizes), whether it stands within the tree
## height range by itself, and the few numbers the farm shares with every tree (its sway, its bark). The farm asks
## this; the builders that grow a tree (TreeModel) load by path through `builder()` only when a tree's look has to
## be built (a lone tree comes from its file, the woods from ModelStore), so the start does not compile them
## (docs/PERF_RUN.md, the start).

const SWAY := 0.035                # how far a tree bends in the wind (paint3d sway, by height)
const PATH := "res://data/tree_shapes.json"
const BUILDER := "res://scripts/world3d/tree_model.gd"
const BARK := Color("#8a6238")
const UNSET := Color(0, 0, 0, 0)
const META_FAR := &"far_look"   # on a built tree: what its far look needs (trunk height, crown bottom and top, ...)

static var _data := {}


## The shapes' data, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataFile.read(PATH)
		if _data.is_empty():
			_data = {"forms": {}, "families": {}}
	return _data


## Whether a tree of this kind is built to stand within the tree height range by itself (a leafy crown on a trunk
## made long enough: `TreeModel._crown_on_trunk`); palms and bananas are measured and scaled instead (ScaleGuide).
static func stands_by_itself(it: Dictionary) -> bool:
	return str(shape_of(it)["form"]) not in ["palm", "banana"]


## The shape for a tree: its form's sizes with its family's own laid over them.
static func shape_of(it: Dictionary) -> Dictionary:
	var d := data()
	var families: Dictionary = d.get("families", {})
	var own: Dictionary = families.get(str(it.get("family", "")), families.get(str(it.get("id", "")), {}))
	var form := str(own.get("form", "round"))
	var out: Dictionary = ((d.get("forms", {}) as Dictionary).get(form, {}) as Dictionary).duplicate()
	out.merge(own, true)
	out["form"] = form
	return out


## The builders that grow a tree (TreeModel: build_at, far_from), loaded when first asked.
static func builder() -> GDScript:
	return load(BUILDER)
