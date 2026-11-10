extends Control
class_name AlertMenu

const ClickButton := preload("res://levels/menu_screen_background/prefabs/click_button/click_button.gd")
const LevelListMenu := preload("../ui/level_list_menu.gd")
const FocusTools := preload("../tools/focus_tools.gd")

const THEME := "res://ui/_shared/themes/menu_screen_theme.tres"
const BACK_GROUP := &"back_button"

var panel : Container
var background : ColorRect
var message : Label
var header : Label
var button_confirm : ClickButton
var _focus_modes := {}

signal confirmed(is_confirmed : bool)

func _init(base : Control, new_menu : bool = true, theme_basic : bool = false, font_size : int = 20, min_size : Vector2 = Vector2(300, 200)) -> void:
	set_anchors_preset(LayoutPreset.PRESET_FULL_RECT)
	theme = load(THEME)
	mouse_filter = MOUSE_FILTER_STOP

	# background
	background = ColorRect.new()
	if new_menu:
		background.color = Color(0.1, 0.1, 0.1, 0)
		create_tween().tween_property(background, "color", Color(0.1, 0.1, 0.1, 0.5), 0.125).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		background.color = Color(0.1, 0.1, 0.1, 0.5)
	background.set_anchors_preset(LayoutPreset.PRESET_FULL_RECT)
	add_child(background)

	# main container
	var center = CenterContainer.new()
	center.set_anchors_preset(LayoutPreset.PRESET_FULL_RECT)
	add_child(center)

	if theme_basic:
		panel = PanelContainer.new()
	else:
		panel = TabContainer.new()
		panel.tabs_visible = false
	if new_menu:
		panel.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.125).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		create_tween().tween_method((func(size):
			panel.custom_minimum_size = size
			panel.reset_size()
		), min_size * 0.8, min_size, 0.125).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		panel.custom_minimum_size = min_size
	center.add_child(panel)

	var padding = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(padding)

	var contents = VBoxContainer.new()
	padding.add_child(contents)

	# container contents
	header = Label.new()
	header.text = "- WARNING -"
	header.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	header.visible = false
	header.size_flags_vertical = SIZE_SHRINK_BEGIN
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 22)
	var header_font := FontVariation.new()
	header_font.base_font = header.get_theme_font("font")
	header_font.variation_embolden = 1.0
	header.add_theme_font_override("font", header_font)
	contents.add_child(header)

	message = Label.new()
	message.size_flags_vertical = SIZE_EXPAND_FILL
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if new_menu:
		message.add_theme_font_size_override("font_size", font_size * 0.8)
		create_tween().tween_property(message, "theme_override_font_sizes/font_size", font_size, 0.125).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		message.add_theme_font_size_override("font_size", font_size)
	contents.add_child(message)

	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = SIZE_SHRINK_CENTER
	button_container.add_theme_constant_override("separation", 4)
	contents.add_child(button_container)

	button_confirm = ClickButton.new()
	button_confirm.mouse_entered.connect(AudioManager.play_sound_effect.bind(SFX.Name.MENU_HOVER))
	button_confirm.pressed.connect(interact)
	button_confirm.add_to_group(BACK_GROUP)
	button_container.add_child(button_confirm)

	# disable base menu focus
	if new_menu:
		FocusTools.save_focus_modes(base, _focus_modes)
		base.propagate_call("set_focus_mode", [FocusMode.FOCUS_NONE])
	base.add_sibling(self)


func build(text : String = "Notification", confirm : String = " OK ") -> AlertMenu:
	# extra initalisation and text setting
	message.text = text
	button_confirm.text = confirm
	get_parent().style_button(button_confirm)
	z_index = 4
	return self


func prompt(close : bool = true) -> bool:
	# await response signal before continuing
	var result = await confirmed
	if close: 
		close()
	return result


func close() -> void:
	# restore base menu focus and free alert
	FocusTools.set_focus_modes(_focus_modes)
	button_confirm.focus_mode = FocusMode.FOCUS_NONE
	get_viewport().gui_release_focus()
	queue_free()
	return


func interact(is_confirmed : bool = true) -> void:
	# emit confirmation signal that prompt listens for (boolean is used for dual-button alerts)
	confirmed.emit(is_confirmed)
	AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
