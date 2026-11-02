extends Node

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const FileTools := preload("res://gdpatch/mods/smaptic/tools/file_tools.gd")
const Log := preload("res://gdpatch/mods/smaptic/log.gd")
const AlertMenu := preload("res://gdpatch/mods/smaptic/ui/alert_menu.gd")
const LevelListMenu := preload("res://gdpatch/mods/smaptic/ui/level_list_menu.gd")
const VersionChecker := preload("res://gdpatch/mods/smaptic/networking/version_checker.gd")

var menu : LevelListMenu
var version_checker : VersionChecker

func _ready() -> void:
	ProjectSettings.set_setting("display/window/subwindows/embed_subwindows", false)
	
	# registers the mod with snapticbase coremod so it appears on the modlist
	var mod =SnapticBase.register("smaptic", get_script().resource_path.get_base_dir())

	# check current version of mod against latest release and warn if outdated
	version_checker = VersionChecker.new()
	add_child(version_checker)
	version_checker.release_fetched.connect(func() -> void:
		version_checker.is_mod_outdated(mod.version, func(outdated: bool, new_ver: String) -> void:
			if outdated:
				Log.say("sMaptic is not up to date")
				menu.update = new_ver
			else:
				Log.say("sMaptic is up to date")
		)
	)

	# add map button to main menu
	menu = LevelListMenu.new()
	SnapticBase.add_menu_button("Maps", menu.open_levels)

	# listen for file drop events
	get_viewport().files_dropped.connect(_on_files_dropped)

	# listen for restart requests
	menu.restart_game.connect(_restart)
	# SnapticBase.add_menu_button_below("Restart", _restart, "Options")
		

func _restart():
	# open identical process and close existing process
	await AudioManager.play_sound_effect(SFX.Name.DEATH).finished
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	# why on earth does this crash sometimes bro what
	get_tree().quit()


func _on_files_dropped(files: PackedStringArray) -> void:
	# check is level list is active and pass files from drop event to import handler if so
	if menu.is_panel_active():
		FileTools.batch_import_file(files, menu)
	
