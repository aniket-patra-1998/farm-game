class_name PackMaker
extends RefCounted
## Makes asset packs (docs/PACKS.md): for each pack a Godot pack file holding what the importer made of its
## source files, and the manifest the game checks a fetched pack against (AssetPacks). Run by
## tools/make_packs.tscn; the packs and the manifest then go to the address in data/packs.json.

const MANIFEST := "manifest.json"
## Never in a pack: Google Play forbids an app downloading code from anywhere but Play, so packs carry art only
## (models, pictures, sounds) and every script ships in the app.
const CODE := ["gd", "gdc", "cs", "dll", "so", "dex", "jar"]
## A file's remap as an exported game has it: where what was made of it is.
const REMAP := "[remap]\n\nimporter=\"%s\"\ntype=\"%s\"\npath=\"%s\"\n"


## What the importer made of source file `file` (its .import file's remap): {"importer", "type", "path"}, or {}.
static func made_of(file: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(file + ".import") != OK:
		return {}
	var made := {}
	for key: String in ["importer", "type", "path"]:   # not-ui
		made[key] = str(config.get_value("remap", key, ""))
	return made if FileAccess.file_exists(str(made["path"])) else {}


## Makes pack `pack` in folder `out`: `files` maps each res:// path the pack brings to the source file whose made
## form it is (itself, usually). The pack is named by its own hash, so a new make is a new file. Returns its
## manifest entry {"file", "bytes", "sha256"}, or {} when it could not be made.
static func make(pack: String, files: Dictionary, out: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(out)
	var raw := out.path_join(pack + ".pck")
	var packer := PCKPacker.new()
	if packer.pck_start(raw) != OK:
		return {}
	var remaps: Array[String] = []
	for brought: String in files:
		var made := made_of(str(files[brought]))
		if made.is_empty() or is_code(brought) or is_code(str(made["path"])):
			return {}
		var remap := out.path_join("%s.%d.remap" % [pack, remaps.size()])
		var written := FileAccess.open(remap, FileAccess.WRITE)
		written.store_string(REMAP % [made["importer"], made["type"], made["path"]])
		written.close()
		remaps.append(remap)
		if packer.add_file(brought + ".import", remap) != OK or packer.add_file(str(made["path"]), str(made["path"])) != OK:
			return {}
	var flushed := packer.flush()
	for remap in remaps:
		DirAccess.remove_absolute(remap)
	if flushed != OK:
		return {}
	var sha := FileAccess.get_sha256(raw)
	var bytes := FileAccess.open(raw, FileAccess.READ).get_length()
	var file := "%s-%s.pck" % [pack, sha.left(8)]
	DirAccess.rename_absolute(raw, out.path_join(file))
	return {"file": file, "bytes": bytes, "sha256": sha}


## Whether `file` is code (CODE), which never goes in a pack.
static func is_code(file: String) -> bool:
	return CODE.has(file.get_extension().to_lower())


## Makes every pack of `packs` (pack -> the res:// files it brings) into `out`, with the manifest. Returns the
## packs that could not be made. The manifest also says the oldest app its packs work with (`min_app_code`).
static func make_all(packs: Dictionary, out: String, min_app_code := 0) -> Array[String]:
	var manifest := {AssetPacks.MIN_APP: min_app_code}
	var failed: Array[String] = []
	for pack: String in packs:
		var files := {}
		for file: String in packs[pack]:
			files[file] = file
		var entry := make(pack, files, out)
		if entry.is_empty():
			failed.append(pack)
		else:
			manifest[pack] = entry
	var written := FileAccess.open(out.path_join(MANIFEST), FileAccess.WRITE)
	written.store_string(JSON.stringify(manifest, "  "))
	written.close()
	return failed
