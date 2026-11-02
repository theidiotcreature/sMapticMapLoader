extends Control

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const FileTools := preload("res://gdpatch/mods/smaptic/tools/file_tools.gd")
const FocusTools := preload("res://gdpatch/mods/smaptic/tools/focus_tools.gd")
const Log := preload("res://gdpatch/mods/smaptic/log.gd")
const LevelScanner := preload("res://gdpatch/mods/smaptic/tools/level_scanner.gd")
const ContextMenu := preload("res://gdpatch/mods/smaptic/ui/context_menu.gd")
const AlertMenu := preload("res://gdpatch/mods/smaptic/ui/alert_menu.gd")
const ConfirmationMenu := preload("res://gdpatch/mods/smaptic/ui/confirmation_menu.gd")
const VanillaLevelMenu := preload("res://gdpatch/mods/smaptic/ui/vanilla_level_menu.gd")
const PlayButton := preload("res://levels/menu_screen_background/prefabs/click_button/click_button.gd")

const MAP_INDEX := "https://smaptic.github.io/mapindex"
const LATEST := "https://github.com/repos/theidiotcreature/smapticmaploader/releases/latest"

enum ContextActions {
	BACK,
	PIN,
	INFO,
	DELETE
}

var panel : Panel
var vanilla_tab : MarginContainer
var update : String = ""
var _tab_bar : TabBar
var _level_list : VBoxContainer
var _header : BoxContainer
var _status : Label
var _refresh_button : Button
var _import_button : Button
var _prev_dir : String
var _focus_modes : Dictionary
var _restart_needed : bool = false
var _loaded_packs : Dictionary = {}
var _boot : bool = true

signal restart_game
signal dialog_closed


func _init():
	# load existing packs into memory
	load_packs(LevelScanner.scan_level_directory())


func open_levels() -> void:
	# construct panel if it hasn't been yet
	if !panel:
		panel = SnapticBase.create_panel("Custom Maps", Vector2(600, 400))
		vanilla_tab = panel.add_tab("Vanilla Maps")
		vanilla_tab.add_child(VanillaLevelMenu.new())
		_tab_bar = vanilla_tab.get_parent().get_tab_bar()
		_tab_bar.tab_changed.connect(func(tab): 
			AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
			_refresh_button.visible = tab == 0
			_import_button.visible = tab == 0
		)
		_tab_bar.tab_hovered.connect(func(tab): AudioManager.play_sound_effect(SFX.Name.MENU_HOVER))
		panel.add_back()
		panel.process_mode = Node.PROCESS_MODE_PAUSABLE

		# base layout for custom levels panel
		var layout := VBoxContainer.new()
		layout.size_flags_horizontal = SIZE_EXPAND_FILL
		layout.add_theme_constant_override("separation", 8)
		panel.content.add_child(layout)

		_header = BoxContainer.new()
		layout.add_child(_header)

		add_spacer(_header, true)
		
		_status = Label.new() 
		_status.size_flags_horizontal = SIZE_EXPAND_FILL
		_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_header.add_child(_status)
		
		var index_button = LinkButton.new()
		index_button.uri = MAP_INDEX
		index_button.text = "Browse Map Index"
		index_button.focus_mode = FocusMode.FOCUS_ALL
		index_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		index_button.add_theme_color_override("font_focus_color", Color(0.875, 0.875, 1, 1))
		index_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 1, 1))
		index_button.add_theme_color_override("font_pressed_color", Color(0.5, 0.5, 0.75, 1))
		index_button.add_theme_color_override("font_hover_pressed_color", Color(0.5, 0.5, 0.75, 1))
		index_button.pressed.connect(AudioManager.play_sound_effect.bind(SFX.Name.MENU_SELECT))
		index_button.mouse_entered.connect(AudioManager.play_sound_effect.bind(SFX.Name.MENU_HOVER))
		index_button.tooltip_text = MAP_INDEX
		index_button.size_flags_horizontal = SIZE_SHRINK_CENTER
		_header.add_child(index_button)

		add_spacer(_header, true)

		var separator := HSeparator.new()
		separator.add_theme_stylebox_override("separator", (func() -> StyleBoxLine: 
			var line := StyleBoxLine.new()
			line.color = Color.WHITE
			line.thickness = 2
			line.horizontal = true
			return line)
			.call()
		)
		separator.size_flags_horizontal = SIZE_EXPAND_FILL
		layout.add_child(separator)

		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		_level_list = VBoxContainer.new()
		_level_list.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.add_child(_level_list)
		layout.add_child(scroll)

		# actions for panel footer
		_import_button = panel.add_action("Import", _import_level)
		_import_button.tooltip_text = "Import a custom map"
		# refresh button is kinda useless ??? dunno if i want it or not
		# _refresh_button = panel.add_action("Refresh", refresh_levels)
		# _refresh_button.tooltip_text = "Refresh maps list"
		_refresh_button = Button.new()

	# refresh content and display panel
	refresh_levels()
	panel.open()

	# prompt user to update if a new version is available
	if update != "":
		var update_notice := ConfirmationMenu.new(panel, false, true, 20, Vector2(500, 200)).build("A new version of sMaptic is available! (v%s)\nPlease download the latest release." % [update], "Download", "Later")
		update_notice.header.visible = true
		update_notice.header.text = "- UPDATE AVAILABLE -"
		update_notice.header.add_theme_color_override("font_color", Color(1, 0.75, 0.5))
		if await update_notice.prompt():
			OS.shell_open(LATEST)

	# map malicious content warning
	if _boot:
		var alert := AlertMenu.new(panel, false, true, 20, Vector2(500, 200))
		alert.build("Custom maps may contain scripts that can run ANY code! Always check that you are installing something safe, regardless of where you download from.")
		alert.header.visible = true
		alert.prompt()
		_boot = false


# quick func for adding spacers to containers
static func add_spacer(base : Control, vertical : bool = false) -> void:
	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_SHRINK_CENTER if vertical else SIZE_EXPAND_FILL
	spacer.size_flags_vertical = SIZE_EXPAND_FILL if vertical else SIZE_SHRINK_CENTER
	base.add_child(spacer)


# allows other classes to check if panel is recieving input
func is_panel_active() -> bool:
	return is_equal_approx(panel.modulate.a, 1.0) and _tab_bar.focus_mode != FocusMode.FOCUS_NONE

	
func refresh_levels() -> void:
	Log.say("Refreshing levels...")
	_refresh_button.disabled = true
	var vbox : VBoxContainer = panel.content.get_child(0)

	# free restart prompt to avoid duplicates
	_restart_needed = false
	if vbox.get_children().size() >= 4:
		vbox.get_child(3).queue_free()

	# free children of level list to avoid duplicates (if wrapper is necessary for some reason idk it crashes w/o it)
	if _level_list.get_child_count() > 0:
		for child in _level_list.get_children():
			child.queue_free()

	# scan levels folder for custom levels & update status text (if list is empty, panel re-shuffles to center status text)
	var level_data = LevelScanner.scan_level_directory()
	if level_data.is_empty():
		vbox.get_child(1).visible = false
		vbox.get_child(2).size_flags_vertical = SIZE_SHRINK_BEGIN
		_header.vertical = true
		_header.size_flags_vertical = SIZE_EXPAND_FILL
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status.text = "No custom maps found \n\nDownload maps at the link below, then\ndrag and drop the map file or click the\nimport button to add them here!\n"
	else:
		vbox.get_child(1).visible = true
		vbox.get_child(2).size_flags_vertical = SIZE_EXPAND_FILL
		_header.vertical = false
		_header.size_flags_vertical = SIZE_SHRINK_BEGIN
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_status.text = "Custom maps found: " + str(level_data.size())

	# load any new packs
	if _loaded_packs.values().has(false):
		load_packs(level_data)

	# create card for each folder with level data
	for level in level_data:
		_level_list.add_child(_create_level_card(level))
	
	# artifical wait (disabled for now but might want in future)
	# await panel.content.get_tree().create_timer(0.125).timeout

	# prompt restart if required
	if _restart_needed == true:
		vbox.add_child((func() -> HBoxContainer:
			var prompt := HBoxContainer.new()
			prompt.add_child((func() -> Label:
				var message := Label.new()
				message.text = "Restart required for list changes to take effect: "
				message.size_flags_horizontal = SIZE_EXPAND_FILL
				return message
			).call())
			prompt.add_child((func() -> Button:
				var button := Button.new()
				button.text = "Restart"
				button.pressed.connect(func():
					emit_signal("restart_game")
				)
				return button
			).call())
			return prompt
		).call())

	LevelScanner.set_active_ids(level_data)
	_refresh_button.disabled = false


func load_packs(data : Array) -> void:
	# iterate through valid level files and load them into res://
	var loaded_count := 0
	for level in data:
		var path = level["path"]
		if _loaded_packs[path]:
			continue
		if path.is_empty() or not FileAccess.file_exists(path):
			Log.warn("Skipping unavailable map resource pack \"%s\"" % [path])
			continue
		if not ProjectSettings.load_resource_pack(path):
			Log.warn("Failed to load map resource pack \"%s\"" % [path])
			continue
		_loaded_packs[path] = true
		loaded_count += 1
		# overwriting "tried to seek before PCK file header" error bcs im pretty sure its not supposed to be called
		Log.replace()
	Log.say("Loaded %s map resource packs" % [loaded_count])


# updates list of loaded packs when map is imported or updated so on next refresh it will be loaded
func map_imported(path : String) -> void:
	if path != "":
		_loaded_packs[path] = false


func _create_level_icon(level : Dictionary, icon_size : float, border : int = 2) -> Control:
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


func _create_level_card(level : Dictionary) -> PanelContainer:
	# main card container
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 64
	
	var padding := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 12)
	card.add_child(padding)

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
	heading.add_theme_constant_override("separation", 8)
	details.add_child(heading)

	var name_label := Label.new()
	name_label.text = str(level.get("name", "Unnamed level"))
	name_label.add_theme_font_size_override("font_size", 18)
	heading.add_child(name_label)

	var metadata_label := Label.new()
	metadata_label.text = "(%s) v%s by %s" % [str(LevelScanner.get_id(level["id"]).to_lower()), str(level.get("version", "Unknown")), format_authors(level)]
	metadata_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metadata_label.add_theme_font_size_override("font_size", 12)
	metadata_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	metadata_label.size_flags_vertical = SIZE_SHRINK_CENTER
	metadata_label.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(metadata_label)

	var description_label := Label.new()
	description_label.text = str(level.get("description", "No description provided."))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875))
	details.add_child(description_label)

	# buttons container
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)

	var play_button := PlayButton.new()
	play_button.mouse_entered.connect(AudioManager.play_sound_effect.bind(SFX.Name.MENU_HOVER))
	play_button.text = " Play "
	play_button.size_flags_vertical = SIZE_SHRINK_CENTER
	if LevelScanner.get_id(level["id"]) in LevelLoader.LevelName.keys():
		play_button.pressed.connect(func(): # play button transition effect
			# i HATE create_tween it doesnt do what i want ever
			panel.create_tween().tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.25)
			var loading := AlertMenu.new(panel, true, true, 24, Vector2(300, 100)).build("Loading map...")
			loading.button_confirm.visible = false
			await AudioManager.play_sound_effect(SFX.Name.MENU_START).finished
			Log.say("Attempting to load level \"%s\"" % [level["name"]])
			loading.close()
			panel.close()
			LevelLoader.load_level(LevelLoader.LevelName.get(LevelScanner.get_id(level["id"])))
		)
	else:
		play_button.disabled = true
		play_button.tooltip_text = "Level ID not registered, restart required"
		_restart_needed = true
	buttons.add_child(play_button)

	var more_button := Button.new()
	panel.style_button(more_button)
	more_button.text = " ⁝ "
	more_button.size_flags_vertical = SIZE_SHRINK_CENTER
	# i legitimately cant tell if this actually has a meaningful improvement on readability but oh well
	var bold_font := FontVariation.new()
	bold_font.base_font = more_button.get_theme_font("font")
	bold_font.variation_embolden = 1.0
	more_button.add_theme_font_override("font", bold_font)
	more_button.pressed.connect(_create_context_menu.bind(more_button, level))
	buttons.add_child(more_button)

	return card
	

# i split this off from being a lamda for readability and lower memory usage
func _create_context_menu(more_button : Button, level : Dictionary) -> void:
	# init context menu
	var context_menu := ContextMenu.new()
	context_menu.add_item("Close", ContextActions.BACK)
	# gonna implement pinning & renaming in a later release methinks
	# context_menu.add_item("Pin/Unpin", ContextActions.PIN)
	context_menu.add_item("More Info", ContextActions.INFO)
	context_menu.add_item("Delete", ContextActions.DELETE)
	panel.add_child(context_menu)
	context_menu.set_focused_item(ContextActions.BACK)

	# play entry anim
	var standard_font_size := context_menu.get_theme_font_size("font_size")
	context_menu.add_theme_font_size_override("font_size", 1)
	context_menu.hide_on_item_selection = false
	context_menu.popup(Rect2(more_button.get_global_position(), context_menu.min_size))
	context_menu.create_tween().tween_property(context_menu, "theme_override_font_sizes/font_size", standard_font_size, 0.125).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# listen for selection and respond
	context_menu.id_pressed.connect(func(id):
		Log.debug("%s action triggered for level \"%s\"" % [ContextActions.keys()[id], str(level["id"])])
		AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
		_close_context_menu(context_menu, standard_font_size)
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
				var confirm = ConfirmationMenu.new(panel).build("Are you sure you want to delete this map?\n(Cannot be undone!)", "Delete")
				if await confirm.prompt():
					var state = DirAccess.remove_absolute(level["path"])
					if state == OK: 
						Log.say("Successfully deleted map \"%s\"" % [level["path"].get_file()])
						refresh_levels()
					else:
						Log.error("Failed to delete map \"%s\": %s" % [level["path"].get_file(), error_string(state)])

			# catch all if action isnt defined (if this happens i screwed up)
			_:
				Log.warn("Unimplemented action id %s \"%s\"" % [id, ContextActions.keys()[id]])
	)

	# misc signal listeners
	context_menu.id_focused.connect(func(id):
		AudioManager.play_sound_effect(SFX.Name.MENU_HOVER)
	)
	context_menu.focus_exited.connect(func():
		if context_menu.get_theme_font_size("font_size") > 1:
			AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
		_close_context_menu(context_menu, standard_font_size)
	)
	context_menu.closed.connect(func():
		AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
	)


func _close_context_menu(menu : PopupMenu, font_size : int = menu.get_theme_font_size("font_size")) -> void:
	# play exit anim and free node
	menu.propagate_call("set_mouse_filter", [MOUSE_FILTER_IGNORE])
	await menu.create_tween().tween_method((func(size): 
		menu.add_theme_font_size_override("font_size", size)
		menu.reset_size()
	), font_size, 1, 0.125).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN).finished
	menu.queue_free()


func format_authors(level : Dictionary) -> String:
	# format author array into name list
	var authors = level.get("authors", [])
	if authors is Array:
		var names := PackedStringArray()
		for author in authors:
			names.append(str(author))
		return ", ".join(names) if not names.is_empty() else "Unknown"
	return str(authors) if not str(authors).is_empty() else "Unknown"


func format_bytes(bytes: int) -> String:
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


# make sure this is implemented dont forget it
func _import_level() -> void:
	# dialog setup
	var dialog := FileDialog.new()
	panel.add_child(dialog)
	dialog.transient = true
	dialog.exclusive = true
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dialog.mode_overrides_title = false
	dialog.title = "Import Custom Map"
	dialog.clear_filters()
	dialog.filters = ["*.zip ; ZIP Archive"]
	if _prev_dir:
		dialog.current_dir = _prev_dir
	else:
		dialog.current_dir = OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")
	var alert = AlertMenu.new(panel).build("File dialog is open in another window.")

	# listeners for dialog signals
	dialog.canceled.connect(func():
		alert.message.text = "Map import cancelled."
		_close_import_dialog(dialog)
	)
	dialog.file_selected.connect(func(path):
		var paths = PackedStringArray([path])
		FileTools.batch_import_file(paths, self, false)
		_close_import_dialog(dialog)
	)
	dialog.files_selected.connect(func(paths):
		FileTools.batch_import_file(paths, self, false)
		_close_import_dialog(dialog)
	)

	# open dialog and retain exclusive focus until closed
	dialog.popup_file_dialog()
	alert.prompt()
	alert.button_confirm.disabled = true
	await dialog_closed
	alert.close()


# emit close signal to allow alert to close and return focus to panel
func _close_import_dialog(dialog : FileDialog):
	_prev_dir = dialog.current_dir
	dialog_closed.emit()
