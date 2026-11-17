extends PanelContainer

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const ClickButton := preload("res://levels/menu_screen_background/prefabs/click_button/click_button.gd")
const Log := preload("../log.gd")
const LevelListMenu := preload("../ui/level_list_menu.gd")
const ContextMenu := preload("../ui/context_menu.gd")
const AlertMenu := preload("../ui/alert_menu.gd")
const ConfirmationMenu := preload("../ui/confirmation_menu.gd")
const LevelScanner := preload("../tools/level_scanner.gd")

enum ContextActions {
	BACK,
	PIN,
	INFO,
	CLEAR_SAVE,
	DELETE
}


func _init(level : Dictionary) -> void:
	# main card container
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size.y = 64

	var padding := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 12)
	add_child(padding)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	padding.add_child(row)

	row.add_child(_create_level_icon(level, 40))

	# text container
	var details := VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)

	var heading := HBoxContainer.new()
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 8)
	details.add_child(heading)

	var name_label := Label.new()
	name_label.text = str(level.get("name", "Unnamed level"))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	heading.add_child(name_label)

	var metadata_label := Label.new()
	metadata_label.text = "(%s) v%s by %s" % [str(LevelScanner.get_id(level["id"]).to_lower()), str(level.get("version", "Unknown")), format_authors(level)]
	metadata_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
	metadata_label.add_theme_font_size_override("font_size", 12)
	metadata_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	metadata_label.size_flags_vertical = SIZE_SHRINK_CENTER
	metadata_label.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(metadata_label)

	var description_label := Label.new()
	description_label.text = str(level.get("description", "No description provided."))
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875))
	description_label.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_child(description_label)

	# buttons container
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)

	var play_button := ClickButton.new()
	play_button.mouse_entered.connect(AudioManager.play_sound_effect.bind(SFX.Name.MENU_HOVER))
	play_button.text = " Play "
	play_button.size_flags_vertical = SIZE_SHRINK_CENTER
	if LevelScanner.get_id(level["id"]) in LevelLoader.LevelName.keys():
		play_button.pressed.connect(func(): # play button transition effect
			# i HATE create_tween it doesnt do what i want ever
			LevelListMenu.panel.create_tween().tween_property(LevelListMenu.panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.25)
			var loading := AlertMenu.new(LevelListMenu.panel, true, true, 24, Vector2(300, 100)).build("Loading map...")
			loading.button_confirm.visible = false
			await AudioManager.play_sound_effect(SFX.Name.MENU_START).finished
			Log.say("Attempting to load level \"%s\"" % [level["name"]])
			loading.close()
			LevelListMenu.panel.close()
			LevelLoader.load_level(LevelLoader.LevelName.get(LevelScanner.get_id(level["id"])))
		)
	else:
		play_button.disabled = true
		play_button.tooltip_text = "Level ID not registered, restart required"
		LevelListMenu.custom_tab._restart_needed = true
	buttons.add_child(play_button)

	var more_button := Button.new()
	LevelListMenu.panel.style_button(more_button)
	more_button.text = " ⁝ "
	more_button.size_flags_vertical = SIZE_SHRINK_CENTER
	# i legitimately cant tell if this actually has a meaningful improvement on readability but oh well
	var bold_font := FontVariation.new()
	bold_font.base_font = more_button.get_theme_font("font")
	bold_font.variation_embolden = 1.0
	more_button.add_theme_font_override("font", bold_font)
	more_button.pressed.connect(_create_context_menu.bind(more_button, level))
	buttons.add_child(more_button)


# i split this off from being a lamda for readability and lower memory usage
static func _create_context_menu(more_button : Button, level : Dictionary) -> ContextMenu:
	# init and open context menu
	var context_menu := ContextMenu.new()
	context_menu.add_item("Close", ContextActions.BACK)
	# gonna implement pinning & save data clearing in a later release methinks
	# context_menu.add_item("Pin/Unpin", ContextActions.PIN)
	context_menu.add_item("More Info", ContextActions.INFO)
	# context_menu.add_item("Clear Save", ContextActions.CLEAR_SAVE)
	context_menu.add_item("Delete", ContextActions.DELETE)
	context_menu.id_pressed.connect(_on_id_pressed.bind(level))

	LevelListMenu.panel.add_child(context_menu)
	context_menu.open_at(more_button.get_global_position(), ContextActions.BACK)
	return context_menu


static func _on_id_pressed(id : int, level : Dictionary) -> void:
	# listen for selection and respond
	Log.debug("%s action triggered for level \"%s\"" % [ContextActions.keys()[id], str(level["id"])])
	match id:
		ContextActions.BACK:
			pass

		ContextActions.INFO:
			var popup = SnapticBase.create_panel("Details", Vector2(500, 350))
			popup.add_back()

			var info = Label.new()
			# scene path uses a non-breaking space to keep as much of the path on one line as possible
			info.text = "Name: %s\nID: %s\nVersion: %s\nAuthors: %s\nDescription: %s\nScene path: %s\nFile name: %s\nFile size: %s" % [
				str(level.get("name", "Unnamed level")),
				str(level["id"]),
				str(level.get("version", "Unknown")),
				format_authors(level),
				str(level.get("description", "No description provided.")),
				str(level["scene"]),
				str(level["path"]).get_file(),
				format_bytes(FileAccess.open(level["path"], FileAccess.READ).get_length())
			]
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.size_flags_vertical = SIZE_EXPAND_FILL
			info.size_flags_horizontal = SIZE_EXPAND_FILL
			info.add_theme_font_size_override("font_size", 18)
			popup.content.add_child(info)

			var level_icon := _create_level_icon(level, 96, 3)
			level_icon.size_flags_horizontal = SIZE_SHRINK_END
			level_icon.size_flags_vertical = SIZE_SHRINK_BEGIN
			popup.content.add_child(level_icon)

			popup.open()

		ContextActions.DELETE:
			var confirm = ConfirmationMenu.new(LevelListMenu.panel).build("Are you sure you want to delete this map?\n(Cannot be undone!)", "Delete")
			if await confirm.prompt():
				var state = DirAccess.remove_absolute(level["path"])
				if state == OK:
					Log.say("Successfully deleted map \"%s\"" % [level["path"].get_file()])
					LevelListMenu.custom_tab.refresh_levels()
				else:
					Log.error("Failed to delete map \"%s\": %s" % [level["path"].get_file(), error_string(state)])

		# catch all if action isnt defined (if this happens i screwed up)
		_:
			Log.warn("Unimplemented action id %s \"%s\"" % [id, ContextActions.keys()[id]])


static func _create_level_icon(level : Dictionary, icon_size : float, border : int = 2) -> Control:
	# container for icon and border
	var box := Control.new()
	box.custom_minimum_size = Vector2(icon_size, icon_size)
	box.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.size_flags_vertical = SIZE_SHRINK_CENTER

	# get icon texture and shrink to size
	var texture := TextureRect.new()
	texture.texture = LevelScanner.get_icon(level)
	texture.custom_minimum_size = Vector2(icon_size - (border * 2), icon_size - (border * 2))
	texture.offset_top = border
	texture.offset_left = border
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(texture)

	# create beveled border around icon
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(icon_size, icon_size)
	frame.size_flags_horizontal = SIZE_SHRINK_CENTER
	frame.size_flags_vertical = SIZE_SHRINK_CENTER
	box.add_child(frame)
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color(0, 0, 0, 0)
	outline.border_color = Color(0.8, 0.8, 1, 1)
	outline.set_border_width_all(border)
	outline.set_corner_radius_all((border + 1) * 2)
	outline.set_content_margin_all(border)
	outline.corner_detail = 12
	frame.add_theme_stylebox_override("panel", outline)

	return box


static func format_authors(level : Dictionary) -> String:
	# format author array into name list
	var authors = level.get("authors", [])
	if authors is Array:
		var names := PackedStringArray()
		for author in authors:
			names.append(str(author))
		return ", ".join(names) if not names.is_empty() else "Unknown"
	return str(authors) if not str(authors).is_empty() else "Unknown"


static func format_bytes(bytes : int) -> String:
	# shorten size in bytes to 3sf and use appropriate unit
	const UNITS := ["B", "KB", "MB", "GB", "TB"]
	var value := float(bytes)
	var unit_index := 0
	while abs(value) >= 1000.0 and unit_index < UNITS.size() - 1:
		value /= 1000.0
		unit_index += 1
	var decimals := maxi(0, 2 - int(floor(log(abs(value)) / log(10.0)))) if value != 0.0 else 0
	value = snappedf(value, pow(10.0, -decimals))
	return "%s %s" % [str(value), UNITS[unit_index]]
