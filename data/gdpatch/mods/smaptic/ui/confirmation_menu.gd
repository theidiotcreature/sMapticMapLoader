extends "alert_menu.gd"
class_name ConfirmationMenu

var button_cancel : ClickButton


func _init(base : Control, animation : bool = true, theme_basic : bool = false, font_size : int = 20, min_size : Vector2 = Vector2(300, 200)) -> void:
	# add extra cancel button and reassign back group from confirm to cancel
	super(base, animation, theme_basic, font_size, min_size)
	button_confirm.remove_from_group(BACK_GROUP)

	button_cancel = ClickButton.new()
	button_cancel.mouse_entered.connect(AudioManager.play_sound_effect.bind(SFX.Name.MENU_HOVER))
	button_cancel.pressed.connect(interact.bind(false))
	button_cancel.add_to_group(BACK_GROUP)
	button_confirm.add_sibling(button_cancel)


func build(text : String = "Are you sure?", confirm : String = "Confirm", cancel : String = "Cancel") -> ConfirmationMenu:
	# additional parameter for cancel button text
	button_cancel.text = cancel
	get_parent().style_button(button_cancel)
	return super(text, confirm)


func close() -> void:
	button_cancel.focus_mode = FocusMode.FOCUS_NONE
	super()
