extends RefCounted


static func replace() -> void:
	# this is really bad practice but it is needed for log readability
	print("\u001b[1A\u001b[2K\u001b[1A")


static func say(message : String) -> void:
	print(_tag(), message)


static func debug(message : String) -> void:
	print_debug(_tag(), message)


static func warn(message : String) -> void:
	push_warning(_tag() + message)


static func error(message : String) -> void:
	push_error(_tag() + message)


static func _tag() -> String:
	var now := Time.get_unix_time_from_system()

	return "[%s %s.%03d] " % ["smaptic", Time.get_time_string_from_system(false), int(fmod(now, 1.0) * 1000.0)]

