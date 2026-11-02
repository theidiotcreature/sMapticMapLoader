extends Node

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")
const Log := preload("res://gdpatch/mods/smaptic/log.gd")

const RELEASE_URL := "https://api.github.com/repos/theidiotcreature/smapticmaploader/releases/latest"
const TIMEOUT := 5.0
const MAX_BYTES := 1048576

var latest_version : String = ""

signal release_fetched

# ripped a bit of this from multiplayer, thanks mia! (again x2)
func _ready() -> void:
	_fetch(RELEASE_URL, PackedStringArray(["Accept: application/vnd.github+json"]))


# compares versions and runs callable with results as args
func is_mod_outdated(version: String, callback: Callable) -> void:
	callback.call(_is_outdated(version), latest_version)
	return


func _is_outdated(version: String) -> bool:
	return not latest_version.is_empty() and SnapticBase.compare_versions(latest_version, version) > 0


# fetches latest release info from github api and sets latest_version
func _fetch(url: String, headers: PackedStringArray) -> void:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT
	request.body_size_limit = MAX_BYTES
	add_child(request)

	request.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			Log.say("Couldn't fetch %s (result %d, http %d)" % [url, result, code])
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary and data.get("tag_name") is String:
			latest_version = (data["tag_name"] as String).strip_edges()
			Log.say("Latest release is %s" % latest_version)
			release_fetched.emit()
	)

	var err := request.request(url, headers)
	if err != OK:
		Log.say("Can't fetch %s (%s)" % [url, error_string(err)])
		request.queue_free()
