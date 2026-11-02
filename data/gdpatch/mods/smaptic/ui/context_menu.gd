extends PopupMenu

func _ready() -> void:
	# unhide popup on frame following ui_cancel key pressed to allow anim to play
	popup_hide.connect(_on_popup_hide)

# tried making this a lamda but for some reason the compiler hates this despite deferring the call so .. i guess external function it is then
func _on_popup_hide() -> void:
	show.call_deferred()
	