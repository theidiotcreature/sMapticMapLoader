extends RefCounted

const Toml := preload("res://gdpatch/mods/snapticbase/toml.gd")
const FileTools := preload("../tools/file_tools.gd")
const Log := preload("../log.gd")

const LEVELS_PATH = "user://custom_levels"
const ID_FILE = "active_ids.json"
const DEFAULT_ICON_PATH := "res://gdpatch/mods/smaptic/assets/default_icon.png"


# UNUSED
static func get_active_ids() -> Dictionary:
	# get the list of map ids from active_ids.json
	var full_path = LEVELS_PATH.path_join(ID_FILE)
	if FileAccess.file_exists(full_path) or DirAccess.open(full_path).store_string(""):
		return JSON.parse_string(FileAccess.get_file_as_string(full_path))
	else:
		Log.error("Could not create or find file \"%s\" at path \"%s\"" % [ID_FILE, LEVELS_PATH])
		return {}


static func set_active_ids(level_data : Array) -> void:
	# overwrite the active_ids.json file with currently installed map ids and paths
	var id_dict : Dictionary = {}
	for level in level_data:
		id_dict[get_id(level["id"])] = level["scene"]
	var json_content : String = JSON.stringify(id_dict)
	var full_path := LEVELS_PATH.path_join(ID_FILE)
	if FileAccess.file_exists(full_path) or FileAccess.open(full_path, FileAccess.WRITE).store_string(""):
		FileAccess.open(full_path, FileAccess.WRITE).store_string(json_content)
	else:
		Log.error("Could not create or find file \"%s\" at path \"%s\"" % [ID_FILE, LEVELS_PATH])


static func get_id(id : String):
	return "CL_%s" % [id.to_upper()]


# i have never used any form of file access in gdscript before but it WORKS yay i hope this is safe
static func scan_level_directory(path : String = LEVELS_PATH, validation : bool = false) -> Array:
	# ensure level dir exists, if not create it
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		Log.error("Could not create or find directory \"%s\"" % [path])
		return []

	# read level .zip file and store json data in an array
	var array : Array = []
	for file in DirAccess.get_files_at(path):
		if file.get_extension() == "zip":
			var data : Dictionary = scan_file(path.path_join(file), validation)
			if data != {}:
				array.append(data)
			else:
				Log.warn("File \"%s\" did not pass validation. Removing..." % [file])
				FileTools.remove_file(path.path_join(file))
		elif file == "active_ids.json":
			pass
		else:
			Log.warn("File \"%s\" is not a valid format (.zip). Removing..." % [file])
			FileTools.remove_file(path.path_join(file))

	# remove sub-directories
	for dir in DirAccess.get_directories_at(path):
		Log.warn("Folder \"%s\" is not a valid format (.zip). Removing..." % [dir])
		FileTools.remove_file(path.path_join(dir))

	return array

static func scan_file(at : String, validation : bool = false) -> Dictionary:
	var level_data : Dictionary
	var file_name : String = at.get_file()

	# scan zip file
	if FileAccess.file_exists(at) and at.get_file().get_extension() == "zip":
		var reader := ZIPReader.new()
		if reader.open(at) != OK:
			Log.warn("Failed to open file \"%s\"" % [file_name])
			return level_data

		# validation checks
		level_data = (func() -> Dictionary:
			var files : Array = reader.get_files()

			# is there exactly 1 level.json file
			var json : Array = files.filter(func(path) -> bool: return path.get_file() == "level.json")
			if json.size() < 1:
				Log.warn("No level.json found in file \"%s\"" % [file_name])
				return {}
			elif json.size() > 1:
				Log.warn("Multiple level.json files found in file \"%s\"" % [file_name])
				return {}
			
			# does ID exist in level.json
			var temp_data : Dictionary = JSON.parse_string(reader.read_file(json[0]).get_string_from_ascii())
			if not temp_data.keys().has("id"):
				Log.warn("No ID found in level.json for file \"%s\"" % [file_name])
				return {}

			# is ID lower_snake_case
			if temp_data["id"].to_lower() != temp_data["id"]:
				Log.warn("ID is not lower_snake_case for file \"%s\"" % [file_name])
				return {}

			# is level.json in the correct directory
			if not json[0] == "custom_levels".path_join(temp_data["id"]).path_join("level.json"):
				Log.warn("Path of level.json is not \"res://custom_levels/%s/level.json\" for file \"%s\"" % [temp_data["id"], file_name])
				return {}

			# does scene remap matching ID exist in same directory as level.json
			if not json[0].get_base_dir().path_join(temp_data["id"] + ".tscn.remap") in files:
				Log.warn("No scene remap matching ID found for file \"%s\"" % [file_name])
				return {}

			# does scene remap point to real file
			if not Toml.parse(reader.read_file(json[0].get_base_dir().path_join(temp_data["id"] + ".tscn.remap")).get_string_from_ascii())["remap"]["path"] in files.map(func(item) -> String: return "res://" + item):
				Log.warn("No scene binary matching remap found for file \"%s\"" % [file_name])
				return {}
			
			# successful validation
			temp_data["path"] = at
			temp_data["scene"] = "res://" + json[0].get_base_dir().path_join(temp_data["id"] + ".tscn")
			return temp_data
		).call()
		reader.close()
	else:
		# Log.warn("File at \"%s\" is not a valid file format (.zip, folder)" % [at])
		Log.warn("File \"%s\" is not a valid file format (.zip)" % [file_name])
	
	return level_data


static func get_default_icon() -> Texture2D:
	# load default icon from mod assets or fallback to blank texture
	var image := Image.new()
	var icon_data := FileAccess.get_file_as_bytes(DEFAULT_ICON_PATH)
	if icon_data.is_empty() or image.load_png_from_buffer(icon_data) != OK:
		Log.error("Could not load default icon at \"%s\"" % [DEFAULT_ICON_PATH])
		return ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	return ImageTexture.create_from_image(image)


static func get_icon(level_data : Dictionary) -> Texture2D:
	var default_icon := get_default_icon()

	# check if level_data is complete
	if not level_data.has("path") or not level_data.has("scene"):
		Log.warn("Level data is incomplete for file with ID \"%s\"" % [level_data.get("id", "unknown")])
		return default_icon

	# check if level file exists and read it
	var zip_path := str(level_data["path"])
	if not FileAccess.file_exists(zip_path):
		Log.warn("Could not find level file \"%s\"" % [zip_path.get_file()])
		return default_icon
	var reader := ZIPReader.new()
	if zip_path.get_extension() == "zip" and reader.open(zip_path) != OK:
		Log.warn("Failed to open level file \"%s\"" % [zip_path.get_file()])
		return default_icon

	# check if icon.png.import exists in zip file (not an issue if it doesn't, just use default icon instead)
	var icon_import_path : String = level_data["scene"].trim_prefix("res://").get_base_dir().path_join("icon.png.import")
	var files := reader.get_files()
	if icon_import_path not in files:
		Log.debug("Could not find icon.png.import in file \"%s\"" % [zip_path.get_file()])
		reader.close()
		return default_icon
	
	# parse icon.png.import as toml and check for remap path
	var icon_import_text := reader.read_file(icon_import_path).get_string_from_ascii()
	icon_import_text = icon_import_text.substr(0, icon_import_text.find("\nmetadata="))
	var icon_import_data := Toml.parse(icon_import_text)
	if not icon_import_data.has("remap") or not icon_import_data["remap"].has("path"):
		Log.warn("Could not find icon.ctex remap in file \"%s\"" % [zip_path.get_file()])
		reader.close()
		return default_icon

	# check if remap path exists in zip file
	var icon_resource_path := str(icon_import_data["remap"]["path"])
	icon_resource_path = icon_resource_path.trim_prefix("res://")
	if icon_resource_path.get_extension() != "ctex" or icon_resource_path not in files:
		Log.warn("Could not find icon.ctex remap in file \"%s\"" % [zip_path.get_file()])
		reader.close()
		return default_icon

	# read icon resource from zip file
	var icon_data := reader.read_file(icon_resource_path)
	reader.close()
	if icon_data.is_empty():
		Log.warn("Could not retrieve data from icon resource \"%s\" in file \"%s\"" % [icon_resource_path, zip_path.get_file()])
		return default_icon

	# resource loader for some reason cannot load from a buffer so i gotta write a temp file for it first
	# theres probably a better way to do this so ill check for a future release
	# each temp is unique namewise so no conflicts should occur fingers crossed
	var temp_path := "user://custom_levels/icon_%s.ctex" % [zip_path.hash()]
	DirAccess.make_dir_recursive_absolute("user://custom_levels")
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		Log.warn("Could not write temporary icon resource for file \"%s\"" % [zip_path.get_file()])
		return default_icon
	temp_file.store_buffer(icon_data)
	temp_file.close()
	var icon := ResourceLoader.load(temp_path) as Texture2D
	DirAccess.remove_absolute(temp_path)
	if icon != null:
		return icon
	Log.warn("Could not load icon resource \"%s\" from file \"%s\"" % [icon_resource_path, zip_path.get_file()])
	return default_icon

		