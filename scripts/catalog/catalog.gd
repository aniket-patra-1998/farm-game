class_name Catalog
extends RefCounted
## Every item in the game, loaded from data/catalog/. The layout is category (one file) →
## family (variants that share defaults) → variant (one item). Field types, defaults and the class
## tree live in data/catalog/schema.json; each class in scripts/catalog/ adds its own rules.
##
## Defaults stack: schema field default → file defaults → family defaults → the entry itself.
## Entries with "status": "planned" are catalogued but not loaded into the game.

const DIR := "res://data/catalog"
const NEVER_IN_MARKET := 99
const FREE_IN_MARKET := ["orchard", "nursery_barn"]  ## free in FarmVille too

## The class for each schema class name. Add a line here with every new class.
static func new_def(cls: String) -> ItemDef:
	match cls:
		"Crop": return CropDef.new()
		"Material": return MaterialDef.new()
		"Tree": return TreeDef.new()
		"Animal": return AnimalDef.new()
		"Building": return BuildingDef.new()
		"Barn": return BarnDef.new()
		"Crafting": return CraftingDef.new()
		"Recipe": return RecipeDef.new()
		"Vehicle": return VehicleDef.new()
		"Decoration": return DecorationDef.new()
	push_error("Catalog: no class for %s" % cls)
	return ItemDef.new()


var schema := {}
var defs := {}                       ## id -> ItemDef, in-game items only
var order: Array[String] = []        ## in-game ids in catalog order
var planned := {}                    ## id -> entry dictionary
var families := {}                   ## family id -> {"id", "name", "doc", "category", "ids": [...]}
var errors: Array[String] = []


static func load_default() -> Catalog:
	var c := Catalog.new()
	c.load_dir(DIR)
	return c


func load_dir(dir: String) -> void:
	schema = _read(dir + "/schema.json")
	var files: Dictionary = schema.get("files", {})
	for category in files:
		_load_file(dir + "/" + category + ".json", category, str(files[category]))
	for id in order:
		for e in defs[id].validate(self):
			errors.append(e)


func get_def(id: String) -> ItemDef:
	return defs.get(id, null)


## In-game items of one class or kind, in catalog order.
func of_kind(kind: String) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id in order:
		if defs[id].kind == kind:
			out.append(defs[id])
	return out


## Recipes made in one crafting building, by star then catalog order.
func recipes_of(building_id: String) -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for star in range(1, 11):
		for d in of_kind("recipe"):
			if (d as RecipeDef).building() == building_id and (d as RecipeDef).star() == star:
				out.append(d as RecipeDef)
	return out


func material_ids() -> Array[String]:
	var out: Array[String] = []
	for d in of_kind("material"):
		out.append(d.id)
	return out


## Buildings that can hold this item.
func homes_of(item_id: String) -> Array[String]:
	var out: Array[String] = []
	var it := get_def(item_id)
	for b in of_kind("building"):
		if (b as BuildingDef).accepts(item_id, it.kind if it else ""):
			out.append(b.id)
	return out


## A class's lifecycle (stages, art pattern, fill), from the nearest class that defines one.
func lifecycle_of(cls: String) -> Dictionary:
	var c := cls
	while c != "":
		if schema["classes"][c].has("lifecycle"):
			return schema["classes"][c]["lifecycle"]
		c = str(schema["classes"][c].get("extends", ""))
	return {"stages": ["placed"], "pattern": "{id}", "fill": 0.7}


## The schema class an item was built from.
func class_of(id: String) -> String:
	var d := get_def(id)
	return str(d.data.get("_class", "")) if d else ""


## Every art id an item needs, by its class's lifecycle.
func art_ids_of(id: String) -> Array[String]:
	var d := get_def(id)
	return d.art_ids(lifecycle_of(class_of(id))) if d else []


## Every field of a class, its parents' first.
func fields_of(cls: String) -> Dictionary:
	var classes: Dictionary = schema["classes"]
	var chain: Array[String] = []
	var c := cls
	while c != "":
		chain.push_front(c)
		c = str(classes[c].get("extends", ""))
	var out := {}
	for k in chain:
		out.merge(classes[k]["fields"], true)
	return out


func _load_file(path: String, category: String, file_cls: String) -> void:
	var f := _read(path)
	if f.is_empty():
		errors.append("%s: missing or not valid JSON" % path)
		return
	var file_defaults: Dictionary = f.get("defaults", {})
	for fam in f.get("families", []):
		var fam_id := str(fam.get("id", ""))
		var record := {"id": fam_id, "name": fam.get("name", fam_id), "doc": fam.get("doc", ""), "category": category, "ids": []}
		families[fam_id] = record
		for v in fam.get("variants", []):
			var cls := file_cls
			var k := str(v.get("kind", ""))
			if k != "" and schema.get("kind_classes", {}).has(k):
				cls = str(schema["kind_classes"][k])
			var entry := _build(cls, file_defaults, fam.get("defaults", {}), v)
			entry["family"] = fam_id
			entry["category"] = category
			entry["_class"] = cls
			var id := str(entry.get("id", ""))
			record["ids"].append(id)
			if defs.has(id) or planned.has(id):
				errors.append("%s: duplicate id" % id)
				continue
			if entry.get("status", "in_game") == "planned":
				planned[id] = entry
				continue
			for e in _check_types(cls, entry):
				errors.append(e)
			var d := new_def(cls)
			d.setup(entry)
			defs[id] = d
			order.append(id)


## Stacks the defaults and sets kind from the class.
func _build(cls: String, file_defaults: Dictionary, fam_defaults: Dictionary, entry: Dictionary) -> Dictionary:
	var out := {}
	var fields := fields_of(cls)
	for name in fields:
		if fields[name].has("default"):
			out[name] = fields[name]["default"]
	var c := cls
	while c != "" and not schema["classes"][c].has("kind"):
		c = str(schema["classes"][c].get("extends", ""))
	if c != "":
		out["kind"] = schema["classes"][c]["kind"]
	out.merge(file_defaults, true)
	out.merge(fam_defaults, true)
	out.merge(entry, true)
	return out


func _check_types(cls: String, entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var fields := fields_of(cls)
	var id := str(entry.get("id", "?"))
	for name in fields:
		var spec: Dictionary = fields[name]
		if spec.get("required", false) and not entry.has(name):
			out.append("%s: missing required field %s" % [id, name])
	for name in entry:
		if name.begins_with("_"):
			continue
		if not fields.has(name):
			out.append("%s: unknown field %s (add it to schema.json, or fix the spelling)" % [id, name])
			continue
		var problem := _type_problem(fields[name], entry[name])
		if problem != "":
			out.append("%s: %s %s" % [id, name, problem])
	return out


func _type_problem(spec: Dictionary, v) -> String:
	var t := str(spec.get("type", "string"))
	match t:
		"string":
			return "" if typeof(v) == TYPE_STRING else "should be text"
		"int", "number":
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				return "should be a number"
			if t == "int" and float(v) != floor(float(v)):
				return "should be a whole number"
			return "" if float(v) >= 0 else "can't be negative"
		"bool":
			return "" if typeof(v) == TYPE_BOOL else "should be true or false"
		"color":
			return "" if typeof(v) == TYPE_STRING and Color.html_is_valid(v) else "should be a colour like #a8743f"
		"enum":
			return "" if (spec.get("values", []) as Array).has(v) else "should be one of %s" % [spec.get("values", [])]
		"map<int>":
			if typeof(v) != TYPE_DICTIONARY:
				return "should be a map of names to numbers"
			for k in v:
				if typeof(v[k]) != TYPE_INT and typeof(v[k]) != TYPE_FLOAT:
					return "should map names to numbers"
			return ""
		"list<string>", "list<int>":
			if typeof(v) != TYPE_ARRAY:
				return "should be a list"
			for x in v:
				if t == "list<string>" and typeof(x) != TYPE_STRING:
					return "should be a list of text"
				if t == "list<int>" and typeof(x) != TYPE_INT and typeof(x) != TYPE_FLOAT:
					return "should be a list of numbers"
			return ""
		"materials", "map":
			return "" if typeof(v) == TYPE_DICTIONARY else "should be an object"
	return ""


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
