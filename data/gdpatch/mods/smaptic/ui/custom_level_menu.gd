extends VBoxContainer

const Log := preload("../log.gd")
const LevelListMenu := preload("../ui/level_list_menu.gd")
const CustomLevelCard := preload("../ui/custom_level_card.gd")
const LevelScanner := preload("../tools/level_scanner.gd")

const MAP_INDEX := "https://smaptic.github.io/MapIndex"

var _level_list : VBoxContainer
var _header : BoxContainer
var _status : Label
var _restart_needed : bool = false
var _loaded_packs : Dictionary = {}

signal restart_game


func _init() -> void:

	# load existing packs into memory
	load_packs(LevelScanner.scan_level_directory())

	# base layout for custom levels panel
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_header = BoxContainer.new()
	add_child(_header)

	_status = Label.new()
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_child(_status)

	var index_button := LinkButton.new()
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

	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _make_separator_stylebox())
	separator.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_level_list = VBoxContainer.new()
	_level_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_level_list)
	add_child(scroll)
	refresh_levels()


static func _make_separator_stylebox() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = Color.WHITE
	line.thickness = 2
	line.horizontal = true
	return line


func refresh_levels() -> void:
	Log.say("Refreshing levels...")

	# free restart prompt to avoid duplicates
	_restart_needed = false
	if get_children().size() >= 4:
		get_child(3).queue_free()

	# free children of level list to avoid duplicates (if wrapper is necessary for some reason idk it crashes w/o it)
	if _level_list.get_child_count() > 0:
		for child in _level_list.get_children():
			child.queue_free()

	# scan levels folder for custom levels & update status text (if list is empty, panel re-shuffles to center status text)
	var level_data = LevelScanner.scan_level_directory()
	if level_data.is_empty():
		get_child(1).visible = false
		get_child(2).size_flags_vertical = SIZE_SHRINK_BEGIN
		_header.vertical = true
		_header.alignment = BoxContainer.ALIGNMENT_CENTER
		_header.size_flags_vertical = SIZE_EXPAND_FILL
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status.text = "No custom maps found \n\nDownload maps at the link below, then\ndrag and drop the map file or click the\nimport button to add them here!\n"
	else:
		get_child(1).visible = true
		get_child(2).size_flags_vertical = SIZE_EXPAND_FILL
		_header.vertical = false
		_header.alignment = BoxContainer.ALIGNMENT_BEGIN
		_header.size_flags_vertical = SIZE_SHRINK_BEGIN
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_status.text = "Custom maps found: " + str(level_data.size())

	# load any new packs
	if _loaded_packs.values().has(false):
		load_packs(level_data)

	# create card for each folder with level data
	for level in level_data:
		_level_list.add_child(CustomLevelCard.new(level))

	# artificial wait (disabled for now but might want in future)
	# await get_tree().create_timer(0.125).timeout

	# prompt restart if required
	if _restart_needed == true:
		add_child((func() -> HBoxContainer:
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


# updates list of loaded packs when map is imported or updated so on next refresh it will be loaded
func map_imported(path : String) -> void:
	if path != "":
		_loaded_packs[path] = false


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