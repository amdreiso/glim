#!/usr/bin/env lua

-- How this works:
--
-- Converting:
-- GameMaker Object folder   ->     Object.gml (converts Object folder into one file separated by event ids starting with @)    
-- │                         ->
-- ├─ Create_0.gml           ->                                         @create
-- ├─ Step_0.gml             ->                      // code...
-- ├─ Draw_0.gml             ->                                         @step
-- └─ Draw_64.gml            ->                      // code... and so on
-- 
-- Script -> Removes any \r and trash leftovers, not much to be converted
--
-- Restoring:
-- Restores every object and script back into GameMaker folder format,
-- and creates Object.yy file with updated, and newly created events
-- 
-- GameMaker project exists
-- Glim sets project path
-- Glim generates Converted objects/scripts into ".gm/project/"
-- User does shenanigans with generated objects/scripts
-- Glim Syncs the project, Restoring objects/scripts 

local lfs = require("lfs")
local json = require("dkjson")
local cwd = lfs.currentdir()
local gmdir = cwd .. "/.gm/"

-- Utils
local VERSION = "0.4"

local function Input(str)
	io.write(str)
	return io.read()
end

local function YY_GetEvent(eventID)
	local e = GML_GetID(eventID)

	local default = {
		["$GMEvent"] = "v1",
		["%Name"] = "",
		collisionObjectId = json.null,
		eventNum = 0,
		eventType = 0,
		isDnD = false,
		name = "",
		resourceType = "GMEvent",
		resourceVersion = "2.0"
	}

	default.eventType = e.eventType
	default.eventNum = e.eventNum

	return default
end

local function YY_GetObject(name)
	local default = {
		["$GMObject"] = "",
		["%Name"] = name,
		eventList = {},
		managed = true,
		name = name,
		overriddenProperties = {},
		parent = {
		  name = "obj",
		  path = "folders/obj.yy",
		},
		parentObjectId = json.null,
		persistent = false,
		physicsAngularDamping = 0.1,
		physicsDensity = 0.5,
		physicsFriction = 0.2,
		physicsGroup = 1,
		physicsKinematic = false,
		physicsLinearDamping = 0.1,
		physicsObject = false,
		physicsRestitution = 0.1,
		physicsSensor = false,
		physicsShape = 1,
		physicsShapePoints = {},
		physicsStartAwake = true,
		properties = {},
		resourceType = "GMObject",
		resourceVersion = "2.0",
		solid = false,
		spriteId = json.null,
		spriteMaskId = json.null,
		visible = true,
	}

	--table.insert(default.eventList, YY_GetEvent("@create"))
	--table.insert(default.eventList, YY_GetEvent("@step_begin"))
	--table.insert(default.eventList, YY_GetEvent("@step"))
	--table.insert(default.eventList, YY_GetEvent("@draw"))

	return default
end

TERM = {
	reset = "\27[0m",
	red = "\27[31m",
	green = "\27[32m",
	yellow = "\27[33m",
	blue = "\27[34m",
	magenta = "\27[35m",
	cyan = "\27[36m",
	bold = "\27[1m",
	dim = "\27[2m",
}

function FolderExists(path)
	local ok = os.execute("test -d '" .. path .. "'")
  	return ok == true or ok == 0
end

function FileExists(path)
  	local ok = os.execute("test -f '" .. path .. "'")
  	return ok == true or ok == 0
end

GML_EVENT_ORDER = {} 

function GML_GetFile(filename)
	for _, val in ipairs(GML_EVENT_ORDER) do
		if val.file == filename then
			return val
		end
	end
	return -1
end

function GML_GetID(id)
	for _, val in ipairs(GML_EVENT_ORDER) do
		if val.id == id then
			return val
		end
	end
	return -1
end

local EVENT = {
	CREATE 		= 0,
	DESTROY 	= 1,
	ALARM		= 2,
	STEP 		= 3,
	DRAW		= 8,
	OTHER		= 7,
	CLEAN_UP 	= 12,
	PRE_CREATE 	= 13,
}

local eventFilenameID = {}
eventFilenameID [EVENT.CREATE] 	= "Create"
eventFilenameID [EVENT.DESTROY] = "Destroy"
eventFilenameID [EVENT.ALARM] 	= "Alarm"
eventFilenameID [EVENT.STEP] 	= "Step"
eventFilenameID [EVENT.DRAW] 	= "Draw"
eventFilenameID [EVENT.OTHER] 	= "Other"
eventFilenameID [EVENT.CLEAN_UP] = "CleanUp"

function Event(id, eventType, eventNum)
	local num = eventNum or 0
	local name = eventFilenameID [eventType] .. "_" .. tostring(num) .. ".gml"

	table.insert(GML_EVENT_ORDER, {
		file = name,
		id = id,
		eventType = eventType or 0,
		eventNum = num,
		priority = #GML_EVENT_ORDER,
	})
end

-- Every gamemaker event (kinda)
Event("@create", 						EVENT.CREATE,	0)
Event("@destroy", 						EVENT.DESTROY,	0)
Event("@cleanup", 						EVENT.CLEAN_UP,	0)

for i=0, 11 do Event("@alarm_"..i, 		EVENT.ALARM, i) end

Event("@step", 							EVENT.STEP, 0)
Event("@step_begin",					EVENT.STEP, 1)
Event("@step_end",						EVENT.STEP, 2)

Event("@draw",							EVENT.DRAW, 0)
Event("@draw_gui",						EVENT.DRAW, 64)
Event("@window_resize",					EVENT.DRAW, 65)
Event("@draw_begin",					EVENT.DRAW, 72)
Event("@draw_end",						EVENT.DRAW, 73)
Event("@draw_gui_begin",				EVENT.DRAW, 74)
Event("@draw_gui_end",					EVENT.DRAW, 75)
Event("@pre_draw",						EVENT.DRAW, 76)
Event("@post_draw",						EVENT.DRAW, 77)

Event("@outside_room",					EVENT.OTHER, 0)
Event("@intersect_boundary",			EVENT.OTHER, 1)
Event("@game_start",					EVENT.OTHER, 2)
Event("@game_end",						EVENT.OTHER, 3)
Event("@room_start",					EVENT.OTHER, 4)
Event("@room_end",						EVENT.OTHER, 5)
Event("@animation_end",					EVENT.OTHER, 7)
Event("@path_ended",					EVENT.OTHER, 8)
Event("@animation_update",				EVENT.OTHER, 58)
Event("@animation_event",				EVENT.OTHER, 59)

for i=0, 7 do Event("@outside_view_"..i,	EVENT.OTHER, 40+i) end

for i=0, 7 do Event("@intersect_view_"..i,	EVENT.OTHER, 50+i) end

Event("@async_image_loaded",			EVENT.OTHER, 60)
Event("@async_http",					EVENT.OTHER, 62)
Event("@async_dialog",					EVENT.OTHER, 63)
Event("@async_in_app_purchase",			EVENT.OTHER, 66)
Event("@async_networking",				EVENT.OTHER, 68)
Event("@async_cloud",					EVENT.OTHER, 67)
Event("@async_steam",					EVENT.OTHER, 69)
Event("@async_social",					EVENT.OTHER, 70)
Event("@async_push_notification",		EVENT.OTHER, 71)
Event("@async_save_load",				EVENT.OTHER, 72)
Event("@async_audio_recording",			EVENT.OTHER, 73)
Event("@async_audio_playback",			EVENT.OTHER, 74)
Event("@async_system",					EVENT.OTHER, 75)
Event("@async_audio_playback_ended",	EVENT.OTHER, 80)

-- Commands
function CMD_Init()
	local path = gmdir
	if FolderExists(path) then
		print("Could not initialize glim.")
		print("path '" .. path .. "' already exists in this directory.")
		return
	end
	os.execute("mkdir -p ./.gm/")
	os.execute("touch ./.gm/.TARGET")
	os.execute("mkdir -p ./.gm/project")
	os.execute("mkdir -p ./.gm/.diffs")
	os.execute("mkdir -p ./.gm/.diffs/objects")
	os.execute("mkdir -p ./.gm/.diffs/scripts")

	print("Glim initialized at '" .. path .. "'")
end

function CMD_Remove()
	local path = gmdir
	if FolderExists(path) then
		os.execute("rm -rf " .. path)
		print("Removed glim folder successfully.")
		return
	end
	print("No glim file system exists in current directory.")
end

function CMD_Load()
	if not FolderExists(".gm") then
		print("Glim was not initiliazed")
		return 
	end
	local file = ".gm/.TARGET"
	file = io.open(file, "r")
	local path_sh = file:read("*a"):gsub("%s+$", "")
	file:close()
	
	local obj = path_sh .. "objects"
	local scr = path_sh .. "scripts" 

	os.execute("cp -rf " .. obj .. " .gm/project/")
	os.execute("find " .. ".gm/project/objects" .. " -type f -name '*.yy' -delete")

	os.execute("cp -rf " .. scr .. " .gm/project/")
	os.execute("find " .. ".gm/project/scripts" .. " -type f -name '*.yy' -delete")
end

function CMD_Set()
	if #arg < 2 then
		print("Usage:")
		print("    set <path to project>")
		return
	end
	local path = arg[2]
	local path_sh = path:gsub(" ", "\\ ")
	if not FolderExists(path) then
		print("Path '" .. path .."' does not exist.")
		return
	end
	print("Path '" .. path .."' set as target.")
	local target = cwd .. "/" .. path_sh
	target = target:gsub("//", "/")
	print(target)
	os.execute("echo '" .. target .. "' > .gm/.TARGET")
	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()
	print("Start coding in '.gm/project/' :D")
end

function CMD_Sync()
	CMD_Restore()

	local target  = gmdir..".TARGET"
	local objects = gmdir..".diffs/objects/*"
	local scripts = gmdir..".diffs/scripts/*"

	local file = io.open(target, "r")
	if file then
		local projectPath = file:read("*a"):gsub("\n", "")
		file:close()
		print("Syncing editted files with project '"..projectPath.."'")
		print("Copying objects...")
		os.execute("cp -r "..objects.." "..projectPath.."objects/")
		print("Copying scripts...")
		os.execute("cp -r "..scripts.." "..projectPath.."scripts/")
	end

end

function CMD_Version()
	print("   Glim "..VERSION.."v.")
end

-- Converting and Recovering gamemaker objects and scripts
-- Objects
function ConvertObject(path)
	if not FolderExists(path) then
		return
	end
	local dirname = path:match("([^/]+)/?$")
	local newfilename = dirname .. ".gml"
	local newfilepath = cwd .. "/.gm/project/objects/" .. newfilename
	if FileExists(newfilepath) then
		print(TERM.blue.." [OBJECT] "..TERM.reset..newfilename..TERM.dim.." already exists."..TERM.reset)
		return
	end
	local newfile = io.open(newfilepath, "w")
	local FILES = {}

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			local name = file:gsub("%..*$", "")
			local gmlfile = GML_GetFile(file)
			if gmlfile == -1 then
				print("file '" .. file .."' does not exist in database.")
				return
			end
			local token = {}
			token.name 		= name
			token.path 		= path.."/"..file
			token.priority 	= gmlfile.priority
			token.id 		= gmlfile.id

			table.insert(FILES, token)
		end
	end

	table.sort(FILES, function(a, b)
	  return a.priority < b.priority
	end)

	local filecontent = ""

	for _, file in ipairs(FILES) do
		local f = io.open(file.path, "r")
		if f then
			local content = f:read("*a")
			content = content:gsub("\r", "")
			content = content:gsub("\n+$", "").."\n"
			filecontent = filecontent..file.id.."\n"..content
			f:close()
		else
			print("Could not open file '"..file.path.."'")
		end
	end

	newfile:write(filecontent)
	newfile:close()

	os.execute("rm -r "..path)

	local size = lfs.attributes(newfilepath, "size")
	print(TERM.blue.." [OBJECT] "..TERM.reset..newfilename..TERM.dim.." was generated with "..TERM.bold..size.." bytes"..TERM.reset)
end

function ConvertObjectsFolder()
	local path = cwd .. "/.gm/project/objects/"
	if not FolderExists(path) then
		return
	end

	for file in lfs.dir(path) do
		if  	file ~= "." 
			and file ~= ".." 
			and lfs.attributes(path, "mode") == "directory" then

			local name = file:gsub("%..*$", "")
			ConvertObject(path..file)
		end
	end
end

function RestoreObject(path)
	local filename = path:match("([^/]+)/?$")
	print(TERM.dim.."- Restoring '"..filename..TERM.blue.."' [OBJECT]"..TERM.reset)
	if not FileExists(path) then
		return
	end
	local file = io.open(path, "r")
	local content = file:read("*a")
	file:close()

	local events = {}
	local currentEvent = nil
	local code = {}

	--for line in (content .. "\n"):gmatch("(.-)\n") do
	for line in content:gmatch("([^\n]*)\n?") do
		local event = line:match("^@([%w_]+)%s*$")
		if event then
			if currentEvent then
				events[currentEvent] = table.concat(code, "\n")
			end
			currentEvent = event
			code = {}
		elseif currentEvent then
			table.insert(code, line)
		end
	end
	
	if currentEvent then
		events[currentEvent] = table.concat(code, "\n")
	end

	local foldername = filename:gsub("%.gml$", "")
	local folderpath = cwd.."/.gm/.diffs/objects/"..foldername.."/"
	os.execute("mkdir "..folderpath.." 2>/dev/null")

	for event, code in pairs(events) do
		local id = GML_GetID("@"..event).file
		local file = io.open(folderpath..id, "w")
		if file then
			code = code:gsub("\n+$", "")
			file:write(code, "\n")
			file:close()
		end
	end
end

function RestoreObjectsFolder()
	local path = cwd .. "/.gm/project/objects/"

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			RestoreObject(path..file)
		end
	end
end

-- Scripts
function ConvertScriptsFolder()
	local path = cwd .. "/.gm/project/scripts/"
	if not FolderExists(path) then
		return
	end

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." and lfs.attributes(path, "mode") == "directory" then
			if FolderExists(path..file) then
				os.execute("mv "..path..file.."/* "..path)
				os.execute("rm -r "..path..file)
				print(TERM.red.." [SCRIPT] "..TERM.reset..file..".gml"..TERM.dim.." was moved."..TERM.reset)
			end
		end
	end
end

function RestoreScriptsFolder()
	local path = cwd .. "/.gm/project/scripts/"
	local to = cwd .. "/.gm/.diffs/scripts/"
	if not FolderExists(path) then
		return
	end
	
	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then 
			print(TERM.dim.."- Restoring '"..file..TERM.red.."' [SCRIPT]"..TERM.reset)
			local foldername = file:gsub("%.gml", "")
			
			-- Read content from script file
			local f = io.open(path..file)
			local content = f:read("*a")
			f:close()

			-- Create script folder in diffs/scripts
			os.execute("mkdir "..to..foldername.." 2>/dev/null")
			
			-- Write file inside script folder
			local filepath = to..foldername.."/"..file
			local scr = io.open(filepath, "w")
			if scr then
				scr:write(content)
				scr:close()
			else
				print(TERM.red.."Could not open script '"..filepath.."'")
			end
		end
	end
end

function CMD_Restore()
	print(TERM.bold.."====================== OBJECTS ======================"..TERM.reset)
	RestoreObjectsFolder()
	print(TERM.bold.."====================== SCRIPTS ======================"..TERM.reset)
	RestoreScriptsFolder()
end

function CMD_Clean()
	local objects = gmdir..".diffs/objects/"
	local scripts = gmdir..".diffs/scripts/"
	if FolderExists(objects) then
		os.execute("rm -r "..objects.."* 2>/dev/null")
	end
	if FolderExists(scripts) then
		os.execute("rm -r "..scripts.."* 2>/dev/null")
	end
	print("Cleaned.")
end

function CMD_Reload(flags)
	local rebase = false
	for _, val in pairs(flags) do
		if val == "--rebase" then
			rebase = true
			print("Rebase reload")
		end
	end
	if rebase then
		os.execute("rm -r "..gmdir.."project/objects/*")
		os.execute("rm -r "..gmdir.."project/scripts/*")
	end
	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()

	if not rebase then
		print("\nUse "..TERM.dim.."--rebase"..TERM.reset.." if you want to replace every file with the original GameMaker files")
	end
end

local commands = {
	{"init", 		CMD_Init, 		"Initializes glim in current directory"},
	{"remove", 		CMD_Remove,		"Removes .gm folder"},
	{"set", 		CMD_Set, 		"Set GameMaker project path and convert objects and scripts into .gm/project/", 1},
	{"convert", 	CMD_Restore,	"Converts .gm/project to GameMaker compatible structure in .gm/.diffs/"},
	{"sync", 		CMD_Sync,		"Sync files with project target"},
	{"reload", 		CMD_Reload,		"Reload files from target GameMaker project (erases any progress in .gm/project/)"},
	{"clean", 		CMD_Clean,		"Cleans generated files in .diffs/"},
	{"version", 	CMD_Version,	"See version"},
}

if arg[1] == "__complete" then
    for _, cmd in ipairs(commands) do
        print(cmd[1])
    end
    os.exit(0)
end

function PrintUsage()
	print("Usage:")
	for i=1, #commands do
		print("    " .. TERM.bold .. commands[i][1] .. TERM.reset .. " - " .. TERM.dim .. commands[i][3] .. TERM.reset)
	end
end

function Run() 
	local found = false
	for _, cmd in ipairs(commands) do
		local name 	= cmd[1]
		local fn 	= cmd[2]
		local desc 	= cmd[3]
		local args 	= cmd[4] or 0

		if name == arg[1] then
			local flags = {}
			for i=(2 + args), #arg do
				table.insert(flags, arg[i])
			end
			fn(flags)
			found = true
		end
		if arg[1] == "__complete" then
			for _, cmd in ipairs(commands) do
				print(cmd[1])
			end
			os.exit(0)
		end
	end

	if not found then
		PrintUsage()
	end
end

Run()

