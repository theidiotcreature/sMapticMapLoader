extends Node

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const LevelScanner := preload("../tools/level_scanner.gd")

static var store : RefCounted


static func build(id : String) -> void:
	store = SnapticBase.settings(id)
	store.define("ignore_modify", false)
	store.define("starting_level", "mirraxis")
	_set_starting_level.call_deferred(store.get_string("starting_level"))

	SnapticBase.add_settings_page(id, func(panel) -> void:
		var page = panel.add_tab("Settings")
		page.add_toggle("Hide Modify Warnings", "ignore_modify")
		_create_description(page, "Hides all warnings related to replacing and deleting maps.")
		var level_dropdown : OptionButton = page.add_choice("Starting Level", "starting_level", LevelScanner.active_ids)
		level_dropdown.item_selected.connect(func(id) -> void:
			_set_starting_level(LevelScanner.active_ids[id])
		)
		_create_description(page, "Map that opens when \"Play\" is pressed on the main menu.")
	)


static func _create_description(page : Control, text : String) -> Label:
	var desc := Label.new()
	desc.text = " " + text
	desc.add_theme_color_override("font_color", Color(0.875, 0.875, 1))
	desc.add_theme_font_size_override("font_size", 18)
	page.add_child(desc)
	return desc


static func _set_starting_level(level : String = "mirraxis") -> void:
	Global.get_game().starting_level = LevelLoader.LevelName[level.to_upper()]
