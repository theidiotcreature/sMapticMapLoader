extends Node

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")

static var store

static func build(id : String) -> void:
	store = SnapticBase.settings(id)
	store.define("ignore_modify", false)
	SnapticBase.add_settings_page(id, func(panel) -> void:
		var page = panel.add_tab("Menu")
		page.add_toggle("Hide Modify Warnings", "ignore_modify")
		_create_description(page, "Hides all warnings related to replacing and deleting maps.")
	)

static func _create_description(page : Control, text : String) -> Label:
	var desc := Label.new()
	desc.text = " " + text
	desc.add_theme_color_override("font_color", Color(0.875, 0.875, 1))
	desc.add_theme_font_size_override("font_size", 18)
	page.add_child(desc)
	return desc