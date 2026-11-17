extends Control

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
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
static var _boot : bool = true


static func _static_init() -> void:
	# construct panel
	panel = SnapticBase.create_panel("Custom Maps", PANEL_SIZE)
	panel.add_back()
	tab_bar = panel.content.get_parent().get_tab_bar()
	tab_bar.tab_hovered.connect(func(tab) -> void: 
		AudioManager.play_sound_effect(SFX.Name.MENU_HOVER)
	)
	tab_bar.tab_changed.connect(func(tab) -> void:
		AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
	)
	custom_tab = CustomLevelTab.new()
	panel.content.add_child(custom_tab)
	_add_tab("Vanilla Maps", VanillaLevelTab.new())


static func _add_tab(title : String, contents : Control) -> void:
	var tab_container : Control = panel.add_tab(title)
	tab_container.add_child(contents)


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
	return is_equal_approx(panel.modulate.a, 1.0) and tab_bar.focus_mode != FocusMode.FOCUS_NONE and tab_bar.current_tab == 0
