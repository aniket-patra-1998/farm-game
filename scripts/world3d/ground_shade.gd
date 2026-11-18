class_name GroundShade
extends Node3D
## The soft contact shade on the grass under a standing thing that is not an animal (a gnome, a lamp, a hay
## bale): the same shade animals have (ContactShades, one draw for all of them), so a decoration is grounded
## like its neighbours instead of looking stuck on. It lies under the box `fit` gives it, follows the thing's
## visibility (in hand: gone) and gives its slot back when the thing leaves the farm.
## Flat things (paths, beds) and large ones (whose tile already shades the grass, Ground3D) get none: `fits`.

const SPREAD := 1.5           # the shade reaches this far past the thing's footprint (the falloff hides its rim)
const LIFT := 0.012           # just above the grass, as an animal's (Animal3D.CONTACT_LIFT)
const STRENGTH := 1.0         # of the shade's own darkness (contact3d's strength), as an animal's on the ground
const MIN_TALL := 0.25        # tiles: anything lower is flat on the ground and casts no contact shade
const MAX_SIDE := 1.6         # tiles: anything wider has its tile shaded already

var _shades: ContactShades
var _slot := -1
var _size := Vector2.ONE


## Whether a thing whose box (in its holder's space) is `box` gets a contact shade.
static func fits(box: AABB) -> bool:
	return box.size.y >= MIN_TALL and maxf(box.size.x, box.size.z) <= MAX_SIDE


## A shade for the thing whose box (in the space of the node it will be added to) is `box`.
static func under(box: AABB) -> GroundShade:
	var shade := GroundShade.new()
	shade.position = Vector3(box.get_center().x, LIFT, box.get_center().z)
	shade._size = Vector2(box.size.x, box.size.z) * SPREAD
	return shade


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY, NOTIFICATION_VISIBILITY_CHANGED:
			_push()
		NOTIFICATION_EXIT_TREE:
			if _shades != null and is_instance_valid(_shades):
				_shades.give_back(_slot)
			_shades = null
			_slot = -1


func _push() -> void:
	if not is_inside_tree():
		return
	if _shades == null:
		_shades = ContactShades.of(self)
		_slot = _shades.take()
	var basis := Basis.from_scale(Vector3(_size.x, 1.0, _size.y))
	_shades.put(_slot, Transform3D(basis, global_position), STRENGTH if is_visible_in_tree() else 0.0)
