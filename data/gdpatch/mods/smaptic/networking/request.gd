extends Node

const Log := preload("res://gdpatch/mods/smaptic/log.gd")

const TIMEOUT := 5.0
const MAX_BYTES := 1048576

func _fetch(url: String, headers: PackedStringArray, callback: Callable) -> void:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT
	request.body_size_limit = MAX_BYTES
	add_child(request)

	request.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			Log.say("Couldn't fetch %s (result %d, http %d)" % [url, result, code])
			return
		callback.call(body)
	)

	var err := request.request(url, headers)
	if err != OK:
		Log.say("Can't fetch %s (%s)" % [url, error_string(err)])
		request.queue_free()