class_name PanelText
extends Label
## A line of panel text (`BookPanel.text`). It wraps only where it has a width to fill. Set beside other things in
## a row (a horizontal box or a flow) without being told to expand, it has no width of its own: a wrapping label
## there is squeezed to nothing and breaks after every letter ("5 slots" or "Pays" running down the side of a
## card, the card grown tall around it). There it stays on one line instead. Checked once it is in place, after
## the code that made it has set it up (so a line given `SIZE_EXPAND_FILL` after joining its row still wraps).


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_settle.call_deferred()


func _settle() -> void:
	if autowrap_mode != TextServer.AUTOWRAP_OFF and squeezed(self):
		autowrap_mode = TextServer.AUTOWRAP_OFF


## Whether `c` sits in a row with no width of its own: a horizontal box or a flow, not expanding, no set width.
static func squeezed(c: Control) -> bool:
	var p := c.get_parent()
	var in_row := (p is BoxContainer and not (p as BoxContainer).vertical) or p is FlowContainer
	return in_row and (c.size_flags_horizontal & Control.SIZE_EXPAND) == 0 and c.custom_minimum_size.x <= 0.0
