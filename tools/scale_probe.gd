extends Node
## Size probe: how tall (in tiles) every model really is, by kind, so sizes can be judged against each other
## (a flower should not stand as tall as a tree). Prints a table; the scale test uses the same numbers.
##   godot --headless --path . res://tools/scale_probe.tscn


func _ready() -> void:
	var by_kind := {}
	for id in Game.item_order:
		var it := Game.item_data(id)
		var k := str(it.get("kind", ""))
		if k in ["crafting", "barn"]:
			k = "building"
		var h := ScaleGuide.height_of(id)
		if h > 0.0:
			if not by_kind.has(k):
				by_kind[k] = []
			by_kind[k].append([h, id])
	for k: String in by_kind:
		var list: Array = by_kind[k]
		list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var med: float = list[list.size() / 2][0]
		print("SCALE %-9s n=%-3d min %.2f (%s)  median %.2f  max %.2f (%s)" % [k, list.size(), list[0][0], list[0][1],
			med, list[-1][0], list[-1][1]])
	if OS.get_cmdline_user_args().has("all"):
		for k: String in by_kind:
			for e: Array in by_kind[k]:
				print("H %s %s %.2f" % [k, e[1], e[0]])
	get_tree().quit()
