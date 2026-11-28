class_name HudIntro
extends RefCounted
## The first screen of a brand-new farm (owner's pick III, 27 Nov: "a letter from the neighbour"): Maple, who gives
## the Welcome goals, asks what to call the farm (a ready name, 🎲 for another), who farms it (the two farmers),
## and where it is (the region, so the seasons are yours: already guessed from the phone, Season.region). One tap
## on Let's go and the Welcome goals begin; closing it keeps the ready choices. Shown once (PlayerSystem.introduced),
## when the first cover has lifted; everything stays changeable in Settings.

const GIVER_KEY := "chain:welcome"   # whose picture asks (the Welcome chain's giver)
const READY_NAMES := ["FARM_NAME_1", "FARM_NAME_2", "FARM_NAME_3", "FARM_NAME_4", "FARM_NAME_5", "FARM_NAME_6",
	"FARM_NAME_7", "FARM_NAME_8", "FARM_NAME_9", "FARM_NAME_10", "FARM_NAME_11", "FARM_NAME_12"]
const WAIT_STEP := 0.2               # seconds between looks for the loading cover

var hud: FarmHud
var _open := false   # showing now (one at a time, whoever asked)


func _init(owner: FarmHud) -> void:
	hud = owner


## Opens the first screen once the loading cover has gone, if this farm has not had it.
func open_when_ready(main: Node) -> void:
	if Game.player.introduced or Game.in_showcase():
		return
	while is_instance_valid(main) and not main.find_children("*", "LoadingCover", true, false).is_empty():   # not-ui
		await main.get_tree().create_timer(WAIT_STEP).timeout
	if not is_instance_valid(main) or Game.player.introduced or Game.in_showcase() or _open:
		return
	_open = true
	if Game.player.farm_name == "":
		Game.player.set_farm_name(ready_name())
	hud.book.open_panel(tr("WELCOME_NEIGHBOUR"), build, BookPanel.Shape.LIST)
	hud.book.visibility_changed.connect(_closed, CONNECT_ONE_SHOT)


func build(content: VBoxContainer) -> void:
	var gap := UiTheme.size("row_gap")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(gap))
	var pic := HudGoals.picture_of(GIVER_KEY, UiTheme.size("inbox_face"))
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pic)
	var say := BookPanel.text(tr("INTRO_SAYS"), UiTheme.BODY)
	say.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	say.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(say)
	content.add_child(head)
	var inner := BookPanel.card()
	var field := LineEdit.new()
	field.name = "FarmName"   # not-ui (a node's name)
	field.text = Game.player.farm_name
	field.placeholder_text = tr("MY_FARM")
	field.max_length = PlayerSystem.NAME_MAX
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.text_submitted.connect(func(_t: String) -> void: field.release_focus())
	field.text_changed.connect(func(t: String) -> void:
		Game.player.set_farm_name(t)
		hud.top.show_name())
	var dice := hud.panel_button(tr("ANOTHER_NAME"))
	dice.pressed.connect(func() -> void:
		field.text = ready_name(field.text)
		Game.player.set_farm_name(field.text)
		hud.top.show_name())
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", int(gap))
	name_row.add_child(field)
	name_row.add_child(dice)
	inner.add_child(BookPanel.row(tr("FARM_NAME"), name_row))
	var farmers: Array = []
	for kind: String in HudSettings.KIND_WORDS:
		var face := Game.player.look.duplicate()
		face["style"] = HudSettings.FARMER_STYLES[kind]
		farmers.append([kind, tr(HudSettings.KIND_WORDS[kind]), PortraitIcon.of(face, UiTheme.size("panel_button_height"))])
	inner.add_child(BookPanel.row(tr("YOUR_FARMER"), BookPanel.choice(farmers, str(Game.player.look["body"]),
		func(kind: String) -> void:
			Game.player.set_kind(kind)
			hud.book.refresh())))
	if Season.enabled():
		var places: Array = []
		for region: String in Season.regions():
			places.append([region, tr(str(Season.data()["regions"][region]["name"]))])
		inner.add_child(BookPanel.row(tr("SEASONS"), BookPanel.choice(places, Season.region(),
			func(region: String) -> void:
				Season.set_region(region)
				hud.book.refresh())))
	content.add_child(BookPanel.card_frame(inner))
	var go := hud.panel_button(tr("LETS_GO"))
	go.name = "LetsGo"   # not-ui (a node's name)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(func() -> void:
		Feedback.moment("tap")
		hud.book.close_panel())
	content.add_child(go)


## Closed (Let's go or ✕): done for good, the plaque shows the name, the Welcome goals take over.
func _closed() -> void:
	if hud.book.visible:
		hud.book.visibility_changed.connect(_closed, CONNECT_ONE_SHOT)
		return
	_open = false
	Game.player.introduced = true
	if Game.player.farm_name == "":
		Game.player.set_farm_name(ready_name())
	Game.queue_save()
	hud.top.show_name()


## One of the ready names, not `but` (the one showing).
func ready_name(but := "") -> String:
	var name := but
	for _try in 8:
		name = tr(READY_NAMES[randi() % READY_NAMES.size()])
		if name != but:
			break
	return name
