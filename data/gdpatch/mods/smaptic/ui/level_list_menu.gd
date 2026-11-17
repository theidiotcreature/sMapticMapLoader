extends Control

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const FileTools := preload("../tools/file_tools.gd")
const Log := preload("../log.gd")
const AlertMenu := preload("../ui/alert_menu.gd")
const ConfirmationMenu := preload("../ui/confirmation_menu.gd")
const CustomLevelTab := preload("../ui/custom_level_tab.gd")
const VanillaLevelTab := preload("../ui/vanilla_level_tab.gd")

const LATEST := "https://github.com/theidiotcreature/sMapticMapLoader/releases/latest"
const PANEL_SIZE := Vector2(600, 400)

static var panel : Panel
static var custom_tab : Control
static var vanilla_tab : Control
static var tab_bar : TabBar
static var update : String = ""
static var _prev_dir : String
static var _boot : bool = true


static func _static_init() -> void:
	# construct panel
	panel = SnapticBase.create_panel("Custom Maps", PANEL_SIZE)
	panel.add_back()
	custom_tab = CustomLevelTab.new()
	panel.content.add_child(custom_tab)
	var vanilla_tab_container : Control = panel.add_tab("Vanilla Maps")
	vanilla_tab = VanillaLevelTab.new()
	vanilla_tab_container.add_child(vanilla_tab)
	tab_bar = panel.content.get_parent().get_tab_bar()
	tab_bar.tab_hovered.connect(func(tab): AudioManager.play_sound_effect(SFX.Name.MENU_HOVER))
	
	var import_button = panel.add_action("Import", _import_level)
	import_button.tooltip_text = "Import a custom map"
	tab_bar.tab_changed.connect(func(tab):
		AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
		import_button.visible = tab == 0
	)


static func open_levels() -> void:
	# refresh content and display panel
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


# allows other classes to check if panel is recieving input
static func is_panel_active() -> bool:
	return is_equal_approx(panel.modulate.a, 1.0) and tab_bar.focus_mode != FocusMode.FOCUS_NONE


# make sure this is implemented dont forget it
static func _import_level() -> void:
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
		FileTools.batch_import_file(paths, false)
		_close_import_dialog(dialog)
	)
	dialog.files_selected.connect(func(paths):
		FileTools.batch_import_file(paths, false)
		_close_import_dialog(dialog)
	)

	# open dialog and retain exclusive focus until closed
	dialog.popup_file_dialog()
	alert.prompt()
	alert.button_confirm.disabled = true
	await dialog.tree_exited
	alert.close()


# emit close signal to allow alert to close and return focus to panel
static func _close_import_dialog(dialog : FileDialog):
	_prev_dir = dialog.current_dir
	dialog.queue_free()
