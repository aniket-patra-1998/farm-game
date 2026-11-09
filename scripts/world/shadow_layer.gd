class_name ShadowLayer
extends Node2D
## Soft contact shadows under every object, on the ground and beneath the objects themselves, so things
## sit on the farm instead of floating over it. Light comes from the upper left, as in the art.

var grid: FarmGrid


func _draw() -> void:
	var lifted := int(grid.placing.get("uid", -1))
	for o in Game.objects:
		if int(o["uid"]) == lifted:
			continue
		var kind := Game.kind_of(o)
		if ObjectLayer.motion_of(o) in ["animal", "bird"]:
			continue  # animals carry their own shadow as they wander
		if kind in ["path", "fence"] or str(Game.item_data(o["id"]).get("shape", "")) in ["path", "fence", "wall", "hedge"]:
			continue
		var fp := Game.footprint(o["id"])
		var g := grid.corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
		var c := (g[0] + g[2]) / 2.0
		var big := maxf(fp.x, fp.y)
		var tall := kind in ["building", "barn", "crafting", "tree"]
		var off := Vector2(FarmGrid.TILE_W * 0.1, FarmGrid.TILE_H * 0.08) * big * (1.0 if tall else 0.4)
		var rx := FarmGrid.TILE_W * 0.5 * big * (0.95 if tall else 0.38)
		var ry := FarmGrid.TILE_H * 0.5 * big * (0.95 if tall else 0.38)
		for k in 3:
			var s := 1.0 - k * 0.18
			_ellipse(c + off, rx * s, ry * s, Color(0.05, 0.09, 0.03, 0.09 + k * 0.03))


func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	draw_colored_polygon(pts, col)
