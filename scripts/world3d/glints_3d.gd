class_name Glints3D
extends MultiMeshInstance3D
## The glints in the field (our own touch): a ripe plot that holds a find twinkles, in the colour of how rare
## the find is, so luck is something to look for and look forward to before the harvest, not a note after it.
## What a plot holds was decided when it was planted (FieldSystem `_hold_luck`, `held_rarity`). One quad per
## glinting plot in one MultiMesh (shaders/glint3d.gdshader): one draw for all of them.
## Farm3D says which plots changed (`update`); between changes a clock looks only when the next held plot is due
## to ripen or wither, like the crops' own.

const SIZE := 0.5             # the glint's width in tiles
const ABOVE := 0.85           # how far over the bed it hangs: clear of the tallest crop, so none hides it
const CHECK := 1.0            # seconds between looks at the clock

var _held := {}               # plot index -> {from, to, color}: plots that hold a find, and when they are ripe
var _shown: Array = []        # the plots glinting now
var _due := -1                # the soonest time (Game.now) that set changes on its own; -1: never


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/glint3d.gdshader")
	material.render_priority = 1
	material_override = material
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true
	multimesh.mesh = quad
	var clock := Timer.new()
	clock.wait_time = CHECK
	clock.autostart = true
	clock.timeout.connect(_on_clock)
	add_child(clock)
	update()


## Brings the glints up to date for the plots that changed (`indices`; none given: every plot).
func update(indices: Array = []) -> void:
	if indices.is_empty():
		# (every plot: only the few that hold something are looked at further)
		_held.clear()
		indices = []
		for i in Game.plots.size():
			if (Game.plots[i] as Dictionary).has("held"):
				indices.append(i)
	for i: int in indices:
		_held.erase(i)
		if i >= Game.plots.size():
			continue
		var rarity := Game.field.held_rarity(i)
		if rarity == "":
			continue
		var p: Dictionary = Game.plots[i]
		var crop: Dictionary = Game.crops.get(str(p.get("crop", "")), {})
		if crop.is_empty():
			continue
		var ripe_at := int(p["planted_at"]) + int(crop["grow_seconds"])
		_held[i] = {"from": ripe_at, "to": Game.field.withers_at(i, ripe_at, crop),
			"color": Feedback.rarity(rarity)["color"]}
	_lay()


## The plots glinting right now (for tests and the curious).
func shown() -> Array:
	return _shown


## The colour of a plot's glint (its find's rarity); white for a plot that holds none.
func color_of(i: int) -> Color:
	return _held[i]["color"] if _held.has(i) else Color.WHITE


func _on_clock() -> void:
	if _due >= 0 and Game.now() >= _due:
		_lay()


## Shows a glint over each held plot that is ripe now, and notes when that next changes.
func _lay() -> void:
	var now := Game.now()
	var ripe: Array = []
	_due = -1
	for i: int in _held:
		var h: Dictionary = _held[i]
		if now >= int(h["from"]) and now < int(h["to"]):
			ripe.append(i)
		var next := int(h["from"]) if now < int(h["from"]) else (int(h["to"]) if now < int(h["to"]) else -1)
		if next >= 0 and (_due < 0 or next < _due):
			_due = next
	ripe.sort()
	if ripe == _shown:
		return
	_shown = ripe
	multimesh.instance_count = ripe.size()
	for k in ripe.size():
		var i: int = ripe[k]
		var at := Vector3(GameState.col_of(i) + 0.5, Plots3D.HEIGHT + ABOVE, GameState.row_of(i) + 0.5)
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, at))
		multimesh.set_instance_color(k, _held[i]["color"])
		multimesh.set_instance_custom_data(k, Color(fposmod(i * 0.618, 1.0), 0, 0, 0))
