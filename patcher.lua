--[[

HUGE thanks to xNasuni (aka. Miami, lastingsunset) for helping with the Lua for sMaptic.
I have very little experience with Lua and could not have done this without their expertise.
If you see this, be sure to support their other projects!
https://transgirls.win/
https://github.com/xNasuni

]]


-- function for checking if a script exists
local function script_path(base)
	for _, file in ipairs(GDPatch.get_pack().files) do
		if file == base .. ".gdc" or file == base .. ".gd" then
			return file
		end
	end
end

-- create a list of {"id", path"} lists
local levels = {}
local appdata = os.getenv("APPDATA")
if appdata then
	local file = io.open(appdata .. "/Godot/app_userdata/snaptic/custom_levels/active_ids.json", "rb")
	if file then
		local json = file:read("a")
		file:close()
		for key, value in json:gmatch('"([^"\\]+)"%s*:%s*"([^"\\]*)"') do
			table.insert(levels, {key, value})
		end
	end
end

-- if no custom levels are found or level_loader.gd(c) doesn't exist then exit early
local path = script_path("autoloads/level_loader/level_loader")
if #levels == 0 or not path then
	print("[smaptic] No active ids were found or able to be patched -")
	return
else
	print("[smaptic] Patching " .. #levels .. " active IDs... -")
end

-- patch level_loader.gd LevelName enum and LEVEL_PATHS dictionary to include active ids
GDPatch.patch_script_as_text(path, function(_, src)
	local enum, paths = "", ""
	for _, level in ipairs(levels) do
		if not src:find("%f[%w_]" .. level[1] .. "%f[^%w_]") then
			enum = enum .. "\n\t" .. level[1] .. ","
			paths = paths .. ('\n\tLevelName.%s: "%s",'):format(level[1], level[2])
		end
	end

	src = src:gsub("(enum%s+LevelName%s*{)", function(open)
		return open .. enum
	end, 1)
	src = src:gsub("(const%s+LEVEL_PATHS[^=]*=%s*{)", function(open)
		return open .. paths
	end, 1)
	return src
end)

-- patch starting level to avoid offsetting to incorrect level id
local game_path = script_path("game/game")
if game_path then
	GDPatch.patch_script_as_text(game_path, function(_, src)
		return (
			src:gsub("(func%s+_ready%s*%([^)]*%)[^\n]*\n)", function(head)
				return head .. "\tstarting_level = LevelLoader.LevelName.MIRRAXIS\n"
			end, 1)
		)
	end)
else
	print("[snapticbase] game script not found in pack, couldn't force starting level -")
end 