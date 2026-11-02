extends RefCounted


static func save_focus_modes(this : Control, modes : Dictionary) -> void:
	# recursively save focus modes
	modes[this] = this.focus_mode
	if this is TabContainer:
		var tab_bar = this.get_tab_bar()
		modes[tab_bar] = tab_bar.focus_mode
	for child in this.get_children():
		if child is Control:
			save_focus_modes(child, modes)


static func set_focus_modes(focus_modes : Dictionary):
	# set focus modes based on output from save_focus_modes
	for control in focus_modes:
		if is_instance_valid(control):
			control.focus_mode = focus_modes[control]
