extends "request.gd"

const SnapticBase := preload("res://gdpatch/mods/snapticbase/mod.gd")

const RELEASE_URL := "https://api.github.com/repos/theidiotcreature/sMapticMapLoader/releases/latest"

static var latest_version : String = ""

# ripped a bit of this from multiplayer, thanks mia! (again x2)
static func fetch_latest(parent : Node, callback: Callable) -> void:
	# fetches latest release info from github api and sets latest_version
	_fetch(parent, RELEASE_URL, PackedStringArray(["Accept: application/vnd.github+json"]), func(body: PackedByteArray) -> void:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary and data.get("tag_name") is String:
			latest_version = (data["tag_name"] as String).strip_edges()
			Log.say("Latest release is %s" % latest_version)
			callback.call()
		else:
			Log.say("Couldn't parse latest release information from %s" % RELEASE_URL)
	)


static func is_mod_outdated(version : String, callback : Callable) -> void:
	# compares versions and runs callable with results as args
	callback.call((not latest_version.is_empty() and SnapticBase.compare_versions(latest_version, version) > 0), latest_version)
	return
