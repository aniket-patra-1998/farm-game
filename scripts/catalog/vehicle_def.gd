class_name VehicleDef
extends PlaceableDef
## Works an area of plots per tap. FarmVille's sizes as Garage upgrades are bought.

const SIZES := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4)]


func job() -> String:
	return str(data["job"])


func fuel_per_plot() -> int:
	return int(data.get("fuel_per_plot", 1))


## Model size against the Tractor's 1.0.
func size() -> float:
	return float(data.get("size", 1.0))


## 0 (light) to 1 (heavy): drives, settles and raises dust accordingly (VehicleMotion).
func weight() -> float:
	return clampf(float(data.get("weight", 0.5)), 0.0, 1.0)


func max_upgrades() -> int:
	return (data["upgrade_parts"] as Array).size()


func area(upgrades: int) -> Vector2i:
	return SIZES[clampi(upgrades, 0, SIZES.size() - 1)]


## Vehicle Parts for the next upgrade, or -1 when fully upgraded.
func upgrade_cost(upgrades: int) -> int:
	var costs: Array = data["upgrade_parts"]
	return int(costs[upgrades]) if upgrades < costs.size() else -1


func upgrade_level_needed(upgrades: int) -> int:
	var lvls: Array = data["upgrade_levels"]
	return int(lvls[upgrades]) if upgrades < lvls.size() else 0


func can_rotate() -> bool:
	return true


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if size() < 0.5 or size() > 2.0:
		out.append(_err("size %.2f is outside 0.5 to 2" % size()))
	if float(data.get("weight", 0.5)) < 0.0 or float(data.get("weight", 0.5)) > 1.0:
		out.append(_err("weight is 0 to 1"))
	if (data["upgrade_parts"] as Array).size() != (data["upgrade_levels"] as Array).size():
		out.append(_err("upgrade_parts and upgrade_levels need the same length"))
	if max_upgrades() > SIZES.size() - 1:
		out.append(_err("more upgrades than sizes (%d max)" % (SIZES.size() - 1)))
	for m in data.get("build_materials", {}):
		if not catalog.material_ids().has(m):
			out.append(_err("chassis uses unknown material %s" % m))
	return out
