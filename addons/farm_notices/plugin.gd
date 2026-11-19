@tool
extends EditorPlugin
## Adds the phone-notifications library (built by CI from android/plugins/farm_notices into bin/) to the Android
## gradle export; without the file (a computer's export, or before CI built it) the export is unchanged.

var _export: FarmNoticesExport


func _enter_tree() -> void:
	_export = FarmNoticesExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class FarmNoticesExport extends EditorExportPlugin:
	const AAR := "farm_notices/bin/farm_notices-release.aar"   # not-ui (relative to res://addons)

	func _get_name() -> String:
		return "FarmNotices"   # not-ui

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if FileAccess.file_exists("res://addons/" + AAR):
			return PackedStringArray([AAR])
		return PackedStringArray()
