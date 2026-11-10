extends RefCounted

const Log := preload("../log.gd")
const LevelScanner := preload("../tools/level_scanner.gd")
const AlertMenu := preload("../ui/alert_menu.gd")
const ConfirmationMenu := preload("../ui/confirmation_menu.gd")
const LevelListMenu := preload("../ui/level_list_menu.gd")

const REMOVE_WHITELIST : Array = ["user://custom_levels"]

static func file_size(path : String) -> int:
	return FileAccess.open(path, FileAccess.READ).get_length()


static func batch_import_file(paths : PackedStringArray, menu : LevelListMenu, new_alert : bool = true) -> void:
	var alert := AlertMenu.new(menu.panel, new_alert)

	# iterate, validate and transfer dropped filepaths
	Log.say("Importing %s file(s)..." % [paths.size()])
	var results : Array = []
	var imported_levels : Array
	for from in paths:
		# perform validation checks
		imported_levels.append(LevelScanner.scan_file(from, true))
	
	# sort list by version (or filename as fallback) in descending natural order
	imported_levels.sort_custom(func(a, b) -> bool:
		if a.has("version") and b.has("version") and a["version"].naturalnocasecmp_to(b["version"]) != 0:
			return a["version"].naturalnocasecmp_to(b["version"]) > 0
		else:
			return a["path"].get_file().naturalnocasecmp_to(b["path"].get_file()) > 0
	)

	# check if imported levels have duplicate IDs, remove later instances
	var seen : Array
	imported_levels = imported_levels.filter(func(item) -> bool: 
		if item["id"] in seen:
			Log.warn("Multiple imported maps share an ID, import cancelled for file \"%s\" with ID \"%s\"" % [item["path"].get_file(), item["id"]])
			results.append("failed")
			return false
		else:
			seen.append(item["id"])
			return true
	)

	# check against existing level ids, prompt user if duplicate found
	var existing_levels : Array = LevelScanner.scan_level_directory()
	var temp_levels : Array
	for level in imported_levels:
		var match : int = existing_levels.map(func(item) -> String: return item["id"]).find(level["id"])
		if match > -1:
			alert.close()
			alert = ConfirmationMenu.new(menu.panel, new_alert, false, 16).build("Imported map \"%s\" shares an ID with an existing map!\nReplace it?" % [level["path"].get_file()], "Replace")
			new_alert = false
			if await alert.prompt():
				temp_levels.append(level)
				remove_file(existing_levels[match]["path"])
			else:
				Log.say("Imported map shares an ID with an existing map, import cancelled for file \"%s\" with ID \"%s\"" % [level["path"].get_file(), level["id"]])
			alert = AlertMenu.new(menu.panel, false)
		else:
			temp_levels.append(level)
	imported_levels = temp_levels

	# import all remaining levels
	for level_data in imported_levels:
		var result = "failed"
		if not level_data.is_empty():
			var to = import_file(level_data["path"])
			if to != "failed":
				menu.map_imported(to)
			result = to
		results.append(result)

	# refresh if any imports succeeded
	if results.any(func(item) -> bool: return item != "failed"):
		menu.refresh_levels()
	var imports : int = results.size()

	# create alert menu and display result message
	alert.build("Map import result unknown. Check GDPatch/output.log for more details.")
	if imports == 0:
		alert.message.text = "Map import cancelled."
	elif imports == 1:
		if results[0] != "failed":
			alert.message.text = "Map imported!"
		else:
			alert.message.text = "Import failed. Check GDPatch/output.log for more details."
	else:
		if not "failed" in results:
			alert.message.text = "%s maps imported!" % [imports]
		else:
			alert.message.text = "One or more imports failed. Check GDPatch/output.log for more details.\nSuccessful imports: %s" % [results.filter(func(item) -> bool: return item != "failed").size()]
	alert.prompt()


static func import_file(from : String, to : String = "user://custom_levels".path_join(from.get_file())) -> String:
	# attempt to copy file
	var state : Error
	if FileAccess.file_exists(from) and from.get_extension() in ["zip"]:
		Log.debug("Attempting to import file \"%s\"" % [from.get_file()])

		# check for duplicate filenames, add identifier
		var name_matches = 0
		while true:
			if (name_matches == 0 and FileAccess.file_exists(to)) or (name_matches > 0 and FileAccess.file_exists(to.get_basename() + " (%s).zip" % [name_matches + 1])):
				name_matches += 1
			else:
				state = DirAccess.copy_absolute(from, to) if name_matches == 0 else DirAccess.copy_absolute(from, to.get_basename() + " (%s).zip" % [name_matches + 1])
				break

	# failure state
	else:
		# Log.warn("Imported file \"%s\" is not a valid file format (.zip, folder)" % [from.get_file()])
		Log.warn("Imported file \"%s\" is not a valid file format (.zip)" % [from.get_file()])
		state = Error.ERR_FILE_UNRECOGNIZED

	# strip file
	
	# respond to return value
	if state == OK:
		Log.say("Imported file \"%s\"" % [from.get_file()])
		return to
	else:
		Log.error("Failed to import file \"%s\": %s" % [from.get_file(), error_string(state)])
		return "failed"


# UNUSED 
# thanks mia! (again)
static func _folder_zip_recursive(from : String, to : String, packer : ZIPPacker) -> Error:
	# create the destination folder if it doesn't exist
	var err := packer.add_directory(to)
	if err != OK:
		return err

	# source folder access check
	var dir := DirAccess.open(from)
	if dir == null:
		return DirAccess.get_open_error()

	# iterate through subfolders depth first
	for sub in dir.get_directories():
		err = _folder_zip_recursive(from.path_join(sub), to.path_join(sub), packer)
		if err != OK:
			return err

	# copy files breadth first
	for file in dir.get_files():
		var err_list = []
		err_list.append(packer.start_file(to.path_join(file)))
		err_list.append(packer.write_file(FileAccess.get_file_as_bytes(from.path_join(file))))
		err_list.append(packer.close_file())
		for error in err_list:
			if error != OK:
				Log.warn("Failed to copy file \"%s\"" % [file])
				return error

	return OK


static func remove_file(path : String) -> void:
	# attempt to delete folder/file
	var state : Error = DirAccess.get_open_error()
	if REMOVE_WHITELIST.filter(func(item) -> bool: return item in path).size() > 0:
		if FileAccess.file_exists(path) and path.get_file() != "active_ids.json":
			Log.debug("Attempting to remove file \"%s\"" % [path.get_file()])
			state = DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			Log.debug("Attempting to remove folder \"%s\"" % [path.get_file()])
			state = _folder_delete_recursive(path)
		else:
			Log.warn("Selected file \"%s\" cannot be found or is not eligible for removal" % [path.get_file()])
			state = Error.ERR_FILE_CANT_OPEN

		# respond to return value
		if state == OK:
			Log.say("Removed file/folder \"%s\"" % [path.get_file()])
		else:
			Log.error("Failed to remove file/folder \"%s\": %s" % [path.get_file(), error_string(state)])
	else:
		Log.error("File/folder \"%s\" requested for removal is not within whitelisted directories: %s" % [path.get_file(), REMOVE_WHITELIST])


static func _folder_delete_recursive(path : String) -> Error:
	# folder access check
	var dir := DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()

	# iterate through subfolders depth first
	for sub in dir.get_directories():
		var err = _folder_delete_recursive(path.path_join(sub))
		if err != OK:
			return err

	# delete files breadth first
	for file in dir.get_files():
		var err = DirAccess.remove_absolute(path.path_join(file))
		if err != OK:
			Log.warn("Failed to delete file \"%s\": %s" % [file, error_string(err)])
			return err

	# delete the folder itself
	return DirAccess.remove_absolute(path)
