extends Node

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const FileTools := preload("res://gdpatch/mods/smaptic/tools/file_tools.gd")
const Log := preload("res://gdpatch/mods/smaptic/log.gd")
const Settings := preload("res://gdpatch/mods/smaptic/ui/settings.gd")
const AlertMenu := preload("res://gdpatch/mods/smaptic/ui/alert_menu.gd")
const LevelListMenu := preload("res://gdpatch/mods/smaptic/ui/level_list_menu.gd")
const VersionChecker := preload("res://gdpatch/mods/smaptic/networking/version_checker.gd")


func _ready() -> void:
	ProjectSettings.set_setting("display/window/subwindows/embed_subwindows", false)
	
	# registers the mod with snapticbase coremod so it appears on the modlist
	var mod := SnapticBase.register("smaptic", get_script().resource_path.get_base_dir())
	Settings.build(mod.id)

	# check current version of mod against latest release and warn if outdated
	VersionChecker.fetch_latest(self, func() -> void:
		VersionChecker.is_mod_outdated(mod.version, func(outdated: bool, new_ver: String) -> void:
			if outdated:
				Log.say("sMaptic is not up to date")
				LevelListMenu.update = new_ver
			else:
				Log.say("sMaptic is up to date")
		)
	)

	# add map button to main menu
	SnapticBase.add_menu_button("Maps", LevelListMenu.open_levels)

	# listen for file drop events
	get_viewport().files_dropped.connect(_on_files_dropped)

	# listen for restart requests
	LevelListMenu.custom_tab.restart_game.connect(_restart)
	# SnapticBase.add_menu_button_below("Restart", _restart, "Options")
		

func _restart():
	# open identical process and close existing process
	await AudioManager.play_sound_effect(SFX.Name.DEATH).finished
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	# why on earth does this crash sometimes bro what
	get_tree().quit()


func _on_files_dropped(files: PackedStringArray) -> void:
	# check is level list is active and pass files from drop event to import handler if so
	if LevelListMenu.is_panel_active():
		FileTools.batch_import_file(files)
	
