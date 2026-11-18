class_name DecorationDef
extends PlaceableDef
## Scenery. (FarmVille gave at least 5 XP for any bought decoration; with sales back at 5% and level rewards that
## grow, cheap paths bought and sold made coins and gems without end, so here a decoration's XP is the rule for
## everything: ItemDef.buy_xp, 1 per economy.coins_per_buy_xp coins.)

const STARTER_SCENERY := ["farmhouse", "mailbox", "farm_stand"]  ## drawn by id, not shape
const OPENS := {"mailbox": "inbox"}   ## a tap on these opens a panel of the interface (FarmHud.show_panel)


## The panel a tap on it opens ("" for none): the mailbox opens the inbox.
func opens() -> String:
	return OPENS.get(id, "")


## Whether its pieces join their neighbours (see Linking): they turn themselves, so the player doesn't.
func joins() -> bool:
	return not Linking.group_of_shape(str(data.get("shape", ""))).is_empty()


func can_rotate() -> bool:
	return super.can_rotate() and not joins()


func can_sell() -> bool:
	return id != "farmhouse"


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if str(data.get("shape", "")) == "" and not STARTER_SCENERY.has(id):
		out.append(_err("needs a shape to draw until it has final art"))
	return out
