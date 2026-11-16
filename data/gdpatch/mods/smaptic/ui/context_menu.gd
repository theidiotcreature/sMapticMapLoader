extends PopupMenu

const ANIMATION_DURATION := 0.125

var _standard_font_size : int
var _is_closing := false


func _ready() -> void:
	# unhide popup on frame following ui_cancel key pressed to allow anim to play
	popup_hide.connect(_on_popup_hide)


# tried making this a lamda but for some reason the compiler hates this despite deferring the call so .. i guess external function it is then
func _on_popup_hide() -> void:
	show.call_deferred()


func open_at(position: Vector2, focused_item: int = 0) -> void:
	if focused_item >= 0:
		set_focused_item(focused_item)

	# opening animation
	_standard_font_size = get_theme_font_size("font_size")
	add_theme_font_size_override("font_size", 1)
	hide_on_item_selection = false
	popup(Rect2(position, min_size))
	create_tween().tween_property(
		self,
		"theme_override_font_sizes/font_size",
		_standard_font_size,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# misc signal listeners
	id_focused.connect(func(id) -> void:
		AudioManager.play_sound_effect(SFX.Name.MENU_HOVER)
	)
	id_pressed.connect(func(id) -> void:
		AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
		close_menu()
	)
	focus_exited.connect(func() -> void:
		if get_theme_font_size("font_size") > 1:
			AudioManager.play_sound_effect(SFX.Name.MENU_SELECT)
		close_menu()
	)


func close_menu() -> void:
	if _is_closing:
		return
	_is_closing = true
	propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	await create_tween().tween_method((func(size):
		add_theme_font_size_override("font_size", size)
		reset_size()
	), _standard_font_size, 1, ANIMATION_DURATION).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN).finished
	queue_free()
	