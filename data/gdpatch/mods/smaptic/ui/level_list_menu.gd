extends Control

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const FileTools := preload("../tools/file_tools.gd")
const Log := preload("../log.gd")
const LevelScanner := preload("../tools/level_scanner.gd")
const AlertMenu := preload("../ui/alert_menu.gd")
const ConfirmationMenu := preload("../ui/confirmation_menu.gd")
const VanillaLevelMenu := preload("../ui/vanilla_level_menu.gd")
const CustomLevelCard := preload("../ui/custom_level_card.gd")

const MAP_INDEX := "https://smaptic.github.io/MapIndex"
const LATEST := "https://github.com/theidiotcreature/sMapticMapLoader/releases/latest"
const PANEL_SIZE := Vector2(600, 400)

enum ContextActions {
	BACK,
	PIN,
	INFO,
	CLEAR_SAVE,
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
		panel = SnapticBase.create_panel("Custom Maps", PANEL_SIZE)
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
		_level_list.add_child(CustomLevelCard.new(self, level))

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
