class_name HudReveal
extends RefCounted
## Shows the interface as it is needed (docs/PLAYER_EXPERIENCE.md Part 2, our own touch): on a brand-new farm
## the tools and menu buttons data/reveal.json lists wait until a goal needs them (GoalSystem.shows), then appear
## with a short shine (UiFx.shine) and stay. A farm past the Welcome chain sees everything. Asked again whenever
## the goals, the level or the inbox change.

var hud: FarmHud
var buttons := {}   # "tool:<id>" / "menu:<KEY>" -> its Button


func _init(owner: FarmHud) -> void:
	hud = owner


## After the tools and the menu are built.
func build() -> void:
	for id: String in hud.tools.buttons:
		buttons["tool:" + id] = hud.tools.buttons[id]
	for key: String in hud.side.buttons:
		buttons["menu:" + key] = hud.side.buttons[key]
	for s: Signal in [Game.goals_changed, Game.inbox_changed]:
		s.connect(update)
	Game.leveled_up.connect(_on_level)
	hud.tree_exiting.connect(func() -> void:   # (the game's signals outlive a HUD)
		for s: Signal in [Game.goals_changed, Game.inbox_changed]:
			if s.is_connected(update):
				s.disconnect(update)
		if Game.leveled_up.is_connected(_on_level):
			Game.leveled_up.disconnect(_on_level))
	Game.goals.reveal_now()   # (what shows as the HUD opens shows without a shine)
	update()


## Every listed button shown or hidden as the farm stands; one that appears now shines.
func update() -> void:
	var fresh := Game.goals.reveal_now()
	for b: String in buttons:
		var button: Button = buttons[b]
		if not is_instance_valid(button):
			continue
		button.visible = Game.goals.shows(b)
		if fresh.has(b):
			(func() -> void:   # (after the row has made room for it, if it is still there then)
				if is_instance_valid(button):
					UiFx.shine(button)).call_deferred()


func _on_level(_l: int) -> void:
	update()
