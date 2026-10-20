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
-- Restores every object/script back into GameMaker folder format,
-- and creates Object.yy file with updated, and newly created events
-- 
-- GameMaker project exists
-- Glim sets project path as PATH
-- Glim generates Converted objects/scripts into ".gm/project/"
-- User does shenanigans with generated objects/scripts
-- Glim Syncs the project, Restoring objects/scripts into PATH 

local lfs 	= require("lfs")
local json 	= require("dkjson")
local cwd 	= lfs.currentdir()
local gmdir = cwd.."/.gm/"

local VERSION = "0.7"
local FILE = {
	TARGET = ".TARGET",
	CONFIG = "config.json",
}

local projectConfig = {
	name = "unnamed",
	objectFolderName = "Objects",
	scriptFolderName = "Scripts",
}

local TERM = {
	reset 	= "\27[0m",
	red 	= "\27[31m",
	green 	= "\27[32m",
	yellow 	= "\27[33m",
	blue 	= "\27[34m",
	magenta = "\27[35m",
	cyan 	= "\27[36m",
	bold 	= "\27[1m",
	dim 	= "\27[2m",
}

local Template = {}
function Template:GetObject()
	return [[{
  "$GMObject":"",
  "%Name":"object_name",
  "eventList":[],
  "managed":true,
  "name":"object_name",
  "overriddenProperties":[],
  "parent":{
    "name":"obj",
    "path":"folders/obj.yy"
  },
  "parentObjectId":null,
  "persistent":false,
  "physicsAngularDamping":0.1,
  "physicsDensity":0.5,
  "physicsFriction":0.2,
  "physicsGroup":1,
  "physicsKinematic":false,
  "physicsLinearDamping":0.1,
  "physicsObject":false,
  "physicsRestitution":0.1,
  "physicsSensor":false,
  "physicsShape":1,
  "physicsShapePoints":[],
  "physicsStartAwake":true,
  "properties":[],
  "resourceType":"GMObject",
  "resourceVersion":"2.0",
  "solid":false,
  "spriteId":null,
  "spriteMaskId":null,
  "visible":true
}]]
end

function Template:GetScript()
	return [[{
  "$GMScript":"v1",
  "%Name":"script_name",
  "isCompatibility":false,
  "isDnD":false,
  "name":"script_name",
  "parent":{
    "name":"scr",
    "path":"folders/scr.yy"
  },
  "resourceType":"GMScript",
  "resourceVersion":"2.0"
}]]
end

function Input(str)
	io.write(TERM.bold..str..TERM.reset)
	return io.read()
end

function Path(path)
	path = path:gsub("\n",  "")
    path = path:gsub("%./", "/")
    path = path:gsub("/+",  "/")
    return path
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function FolderExists(path)
	local ok = os.execute("test -d '" .. path .. "'")
  	return ok == true or ok == 0
end

function FileExists(path)
  	local ok = os.execute("test -f '" .. path .. "'")
  	return ok == true or ok == 0
end

function YY_GetEvent(eventID)
	eventID = "@"..eventID
	local e = GML_GetID(eventID)

	local default = {
		["$GMEvent"] 		= "v1",
		["%Name"] 			= "",
		collisionObjectId 	= json.null,
		eventNum 			= 0,
		eventType 			= 0,
		isDnD 				= false,
		name 				= "",
		resourceType 		= "GMEvent",
		resourceVersion 	= "2.0"
	}

	default.eventType = e.eventType
	default.eventNum  = e.eventNum

	return default
end

function ParseProperties(source)
	local p = {}

	local tokens = {
		["true"] = true,
		["false"] = false,
	}

	for line in source:gmatch("[^\n]+") do
		local l = line
		l = l:gsub(" ", "")
		l = l:gsub("\n", "")
		l = l:gsub(";", "")
		local key, val = l:match("([^,]+)=([^,]+)")
		local result = val
		if tokens[val] ~= nil then
			result = tokens[val]
		end
		p[key] = result
	end

	return p
end

function YY_GetObject(name, events, properties)
	local default = {
		["%Name"] 		= name,
		name 			= name,
		eventList 		= {},
		parentObjectId 	= json.null,
		spriteId 		= json.null,
		spriteMaskId 	= json.null
	}

	for i=1, #events do
		if events[i] == "properties" then 
			goto gooner
		end
		table.insert(default.eventList, YY_GetEvent(events[i]))
		::gooner::
	end

	local parent = properties.parent

	local n = parent
	local folder = "objects/"..n.."/"..n..".yy"
	default.parentObjectId = {
		name = n,
		path = folder,
	}

	if parent == "-1" then
		default.parentObjectId = json.null
	end

	return default
end

local GML_EVENT_ORDER = {}

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
	CREATE 		= {type = 0,  name = "Create"},
	DESTROY 	= {type = 1,  name = "Destroy"},
	ALARM		= {type = 2,  name = "Alarm"},
	STEP 		= {type = 3,  name = "Step"},
	DRAW		= {type = 8,  name = "Draw"},
	OTHER		= {type = 7,  name = "Other"},
	CLEAN_UP 	= {type = 12, name = "CleanUp"},
}

function Event(id, event, eventNum)
	local num = eventNum or 0
	local name = event.name .. "_" .. tostring(num) .. ".gml"

	table.insert(GML_EVENT_ORDER, {
		file = name,
		id = id,
		eventType = event.type or 0,
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

Event("@outside_room",						EVENT.OTHER, 0)
Event("@intersect_boundary",				EVENT.OTHER, 1)
Event("@game_start",						EVENT.OTHER, 2)
Event("@game_end",							EVENT.OTHER, 3)
Event("@room_start",						EVENT.OTHER, 4)
Event("@room_end",							EVENT.OTHER, 5)
Event("@animation_end",						EVENT.OTHER, 7)
Event("@path_ended",						EVENT.OTHER, 8)
Event("@animation_update",					EVENT.OTHER, 58)
Event("@animation_event",					EVENT.OTHER, 59)
for i=0, 7 do Event("@outside_view_"..i,	EVENT.OTHER, 40+i) end
for i=0, 7 do Event("@intersect_view_"..i,	EVENT.OTHER, 50+i) end
Event("@async_image_loaded",				EVENT.OTHER, 60)
Event("@async_http",						EVENT.OTHER, 62)
Event("@async_dialog",						EVENT.OTHER, 63)
Event("@async_in_app_purchase",				EVENT.OTHER, 66)
Event("@async_networking",					EVENT.OTHER, 68)
Event("@async_cloud",						EVENT.OTHER, 67)
Event("@async_steam",						EVENT.OTHER, 69)
Event("@async_social",						EVENT.OTHER, 70)
Event("@async_push_notification",			EVENT.OTHER, 71)
Event("@async_save_load",					EVENT.OTHER, 72)
Event("@async_audio_recording",				EVENT.OTHER, 73)
Event("@async_audio_playback",				EVENT.OTHER, 74)
Event("@async_system",						EVENT.OTHER, 75)
Event("@async_audio_playback_ended",		EVENT.OTHER, 80)

-- Commands
function WriteConfigFile(config)
	local path = Path(gmdir .. "/" .. FILE.CONFIG)
	local content = json.encode(config, {indent=true})
	io.open(path, "w"):write(content):close()
	print(content)
end

function ReadConfigFile()
	local path = Path(gmdir .. "/" .. FILE.CONFIG)
	if not FileExists(path) then return end
	
	local file = io.open(path, "r")
	local content = file:read("*a")
	projectConfig = json.decode(content)
	file:close()
end

ReadConfigFile()

function GlimNotFound()
	print(TERM.red.."Glim has not been initialized in this directory."..TERM.reset)
	print("Initialize it by running "..TERM.bold.."'glim init'"..TERM.reset)
end

function AskTheQuestions()
	WriteConfigFile {
		name = Input("Project Name: "),
		objectFolderName = Input("Objects Folder Name (in GameMaker): "),
		scriptFolderName = Input("Scripts Folder Name (in GameMaker): ")
	}
end

function CMD_Config()
	AskTheQuestions()
end

function CMD_Init()
	local path = gmdir
	if FolderExists(path) then
		print("Could not initialize glim.")
		print("path '" .. path .. "' already exists in this directory.")
		return
	end

	os.execute("mkdir -p ./.gm/")
	os.execute("touch ./.gm/"..FILE.TARGET)
	os.execute("mkdir -p ./.gm/project")
	os.execute("mkdir -p ./.gm/.diffs")
	os.execute("mkdir -p ./.gm/.diffs/objects")
	os.execute("mkdir -p ./.gm/.diffs/scripts")

	AskTheQuestions()
	
	print("Glim initialized at '" .. path .. "'")
end

function CMD_Remove()
	local path = gmdir
	if FolderExists(path) then
		os.execute("rm -rf " .. path)
		print("Removed glim folder successfully.")
		return
	end
	GlimNotFound();
end

function CMD_Load()
	if not FolderExists(".gm") then
		GlimNotFound()
		return 
	end

	local file = Path(".gm/"..FILE.TARGET)
	file = io.open(file, "r")
	local path_sh = file:read("*a"):gsub("%s+$", "")
	file:close()

	local obj = path_sh .. "objects" -- Original project objects folder
	local scr = path_sh .. "scripts" -- Original project scripts folder

	if FolderExists(obj) then
		os.execute("cp -rf " .. obj .. " .gm/project/")
		os.execute("find " .. ".gm/project/objects" .. " -type f -name '*.yy' -delete")
	end

	if FolderExists(scr) then
		os.execute("cp -rf " .. scr .. " .gm/project/")
		os.execute("find " .. ".gm/project/scripts" .. " -type f -name '*.yy' -delete")
	end
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

	local target = cwd .. "/" .. path_sh
	target = Path(target:gsub("//", "/"))

	print("Path '" .. TERM.dim .. target .. TERM.reset .. "' set as target.")

	os.execute("echo '" .. target .. "' > .gm/"..FILE.TARGET)

	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()
	print(TERM.magenta.."\nStart coding in '.gm/project/' :D"..TERM.reset)
end

function CMD_Sync()
	CMD_Restore()

	local target  = gmdir..FILE.TARGET
	local objects = gmdir..".diffs/objects/*"
	local scripts = gmdir..".diffs/scripts/*"

	local file = io.open(target, "r")
	if file then
		local projectPath = file:read("*a"):gsub("\n", "")
		file:close()

		print("Syncing editted files with project '"..projectPath.."'")

		print("Copying objects...")
		os.execute("cp -r "..objects.." "..projectPath.."objects/ 2>/dev/null")

		print("Copying scripts...")
		os.execute("cp -r "..scripts.." "..projectPath.."scripts/ 2>/dev/null")
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
	local newfilename = dirname..".gml"
	local newfilepath = Path(gmdir .. "/project/objects/" .. newfilename)
	if FileExists(newfilepath) then
		print(TERM.blue.." [OBJECT] "..TERM.reset..newfilename..TERM.dim.." already exists."..TERM.reset)
		os.execute("rm -r "..path)
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
			content = content:gsub("\r", "") -- CR
			--content = content:gsub("\n+$", "") .. "\n"
			filecontent = filecontent .. file.id .. "\n" .. content
			f:close()
		else
			print("Could not open file '"..file.path.."'")
		end
	end

	local properties = "@properties\nparent = -1;\n"

	local file = io.open(gmdir..FILE.TARGET, "r")
	local target = file:read("*l")
	file:close()

	local yy = io.open(Path(target.."/objects/"..dirname.."/"..dirname..".yy"), "r")
	local yycontent = yy:read("*a")
	yy:close()

	local yytable = json.decode(yycontent)
	if yytable.parentObjectId then
		properties = "@properties\nparent = "..yytable.parentObjectId.name..";\n"
	end

	properties = properties.."persistent = "..tostring(yytable.persistent)..";\n"
	properties = properties.."visible = "..tostring(yytable.visible)..";\n"
	properties = properties.."solid = "..tostring(yytable.solid)..";\n"
	properties = properties.."\n"

	filecontent = properties .. filecontent
	newfile:write(filecontent)
	newfile:close()

	os.execute("rm -r "..path)

	local size = lfs.attributes(newfilepath, "size")
	print(TERM.blue.." [OBJECT] "..TERM.reset..newfilename..TERM.dim.." was generated with "..TERM.bold..size.." bytes"..TERM.reset)
end

function ConvertObjectsFolder()
	local path = Path(cwd .. "/.gm/project/objects/")
	if not FolderExists(path) then
		print(TERM.red.."Folder 'objects' doesn't exist")
		return
	end

	for file in lfs.dir(path) do
		if  	file ~= "." 
			and file ~= ".."
			and lfs.attributes(path..file, "mode") == "directory" then

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

	local eventIds = {}
	local events = {}
	local currentEvent = nil
	local code = {}

	for line in content:gmatch("([^\n]*)\n?") do
		local event = line:match("^@([%w_]+)%s*$")
		if event then
			if currentEvent then
				events[currentEvent] = table.concat(code, "\n")
			end
			currentEvent = event
			code = {}

			table.insert(eventIds, event)

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

	local properties = {
		parent = -1,
	}

	for event, code in pairs(events) do
		if event == "properties" then
			properties = ParseProperties(code)
			goto gooner
		end

		local id = GML_GetID("@"..event).file
		local file = io.open(folderpath..id, "w")
		if file then
			file:write(code, "\n")
			file:close()
		end

		::gooner::
	end

	local targetfile = io.open(cwd.."/.gm/"..FILE.TARGET, "r")
	local targetpath = targetfile:read("*a")
	targetfile:close()

	local yyfilename = filename:gsub(".gml", ".yy")
	local yyfilepath = Path(targetpath.."/objects/"..foldername.."/"..yyfilename)
	local yyfile = io.open(yyfilepath, "r")
	local yycontent = yyfile:read("*a")
	yyfile:close()

	local newobj = YY_GetObject(foldername, eventIds, properties)
	local originalobj = json.decode(yycontent)

	for key, val in pairs(newobj) do
		originalobj[key] = val
	end

	--print(yycontent)
	--print(json.encode(originalobj, { indent = true, }))

	local file = io.open(yyfilepath, "w")
	file:write(json.encode(originalobj, { indent = true, }))
	file:close()
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
	local path = Path(cwd .. "/.gm/project/scripts/")
	if not FolderExists(path) then
		print(TERM.dim.."Folder 'scripts' not found."..TERM.reset)
		return
	end

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." and lfs.attributes(path..file, "mode") == "directory" then
			os.execute("mv "..path..file.."/* "..path)
			os.execute("sed -i 's/\r$//' "..path..file..".gml")
			os.execute("rm -r "..path..file)
			print(TERM.red.." [SCRIPT] "..TERM.reset..file..".gml"..TERM.dim.." was moved."..TERM.reset)
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
		end
	end

	if rebase then
		os.execute("rm -r "..gmdir.."project/objects/* 2>/dev/null")
		os.execute("rm -r "..gmdir.."project/scripts/* 2>/dev/null")
	end

	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()

	if not rebase then
		print("\nUse "..TERM.dim.."--rebase"..TERM.reset.." if you want to replace every file with the original GameMaker project files")
	end
end

function CMD_Status()

end

function CMD_Create()
	if #arg < 2 then
		print("Usage: glim create <obj/scr>")
		return
	end

	if arg[2] ~= "obj" and arg[2] ~= "scr" then
		print("Usage: glim create <obj/scr>")
		return
	end

	local asset 			= arg[2] == "obj" and "Object" or "Script"
	local folder 			= arg[2] == "obj" and "objects" or "scripts"
	local template 			= arg[2] == "obj" and Template:GetObject() or Template:GetScript()
	local folderNameConfig 	= arg[2] == "obj" and projectConfig.objectFolderName or projectConfig.scriptFolderName

	local name = Input("  filename: ")

	local path = Path(cwd.."/"..projectConfig.name..".yyp")
	local pathShell = path:gsub(" ", "\\ ")
	os.execute("cp "..pathShell.." "..pathShell..".backup")

	local file = io.open(path, "r")
	local content = file:read("*a")
	file:close()

	local t = json.decode(content, 1, json.null)

	local Folders = t.Folders
	local folders = {}
	local folderIndexValue = 0

	for val, key in pairs(Folders) do
		local fpath = key.folderPath
		local fullpath = key.folderPath
		fpath = fpath:gsub("folders/", "")
		fpath = fpath:gsub(".yy", "")

		if string.starts(fpath, arg[2]) then
			folderIndexValue = folderIndexValue + 1

			print(TERM.yellow.." [FOLDER] "..TERM.red.."["..folderIndexValue.."] "..TERM.reset..fpath)
			folders[folderIndexValue] = { name = key.name, path = fullpath}
		end
	end

	local where = Input("Where do you want your Object in: ")
	assert(type(tonumber(where)) == "number", "Folder index must be a number.")

	local folderid = tonumber(where)
	assert(folderid > 0 and folderid < #folders, "Folder index outside boundaries.")

	print("Selected folder: '"..folders[folderid].path.."'")

	local foldername = folders[folderid].name
	local folderpath = folders[folderid].path

	-- Changing template parent folder
	local templateTable = json.decode(template, 1, json.null)
	templateTable.parent.name = foldername
	templateTable.parent.path = folderpath

	template = json.encode(templateTable, {indent = true})

	local objectResourcePath = folder.."/"..name.."/"..name..".yy" 
	table.insert(t.resources, {
		id = {
			name = name,
			path = objectResourcePath,
		}
	})

	local result = json.encode(t, {indent = true})
	io.open(path, "w"):write(result):close()
	
	template = template:gsub("object_name", name)
	template = template:gsub("script_name", name)

	local assetfolder = cwd.."/"..folder.."/"..name
	os.execute("mkdir -p "..assetfolder.." 2>/dev/null")

	local script = Path(assetfolder.."/"..name..".gml")
	local yy = Path(assetfolder.."/"..name..".yy")
	local file = io.open(yy, "w")
	file:write(template)
	file:close()

	if arg[2] == "scr" then
		local file = io.open(script, "w")
		file:write(string.format([[function %s() {
	
}]], name))
	end

	print(asset.." '"..name.."'".." was created.")
end

function CMD_List()
	local objects = 0
	local scripts = 0

	for file in lfs.dir(gmdir.."project/objects/") do
		if file ~= "." and file ~= ".." then 
			print(TERM.blue.."[OBJECT]"..TERM.reset.." - "..file)
			objects = objects + 1
		end
	end

	for file in lfs.dir(gmdir.."project/scripts/") do
		if file ~= "." and file ~= ".." then 
			print(TERM.red.."[SCRIPT]"..TERM.reset.." - "..file)
			scripts = scripts + 1
		end
	end

	print("")
	print(TERM.bold.." - Objects: "..TERM.reset..tostring(objects))
	print(TERM.bold.." - Scripts: "..TERM.reset..tostring(scripts))
end

local commands = {
	{ "init", 		CMD_Init, 		"Initializes glim in current directory." },
	{ "remove", 	CMD_Remove,		"Removes .gm folder." },
	{ "set", 		CMD_Set, 		"Set GameMaker project path and convert objects and scripts into .gm/project/", 1 },
	{ "convert", 	CMD_Restore,	"Converts .gm/project to GameMaker compatible structure in .gm/.diffs/" },
	{ "sync", 		CMD_Sync,		"Sync files with project target." },
	{ "reload", 	CMD_Reload,		"Reload files from target GameMaker project. FLAGS: --rebase" },
	{ "status", 	CMD_Status,		"Prints status of current project." },
	{ "create", 	CMD_Create,		"Create objects/scripts from command line." },
	{ "list", 		CMD_List,		"List project files." },
	{ "clean", 		CMD_Clean,		"Cleans generated files in .diffs/" },
	{ "config", 	CMD_Config,		"Creates a new config.json." },
	{ "version", 	CMD_Version,	"See version." },
}

if arg[1] == "__complete" then
    for _, cmd in ipairs(commands) do
        print(cmd[1])
    end
    os.exit(0)
end

function PrintUsage()
	print("Usage:")

	local printUsageGap = 0 
	for i=1, #commands do
		local l = commands[i][1]:len()
		if l > printUsageGap then
			printUsageGap = l
		end
	end

	for i=1, #commands do
		local name = commands[i][1]
		local size = printUsageGap - name:len()
		name = name .. string.rep(" ", size)
		print("    " .. TERM.bold .. name .. TERM.reset .. " - " .. TERM.dim .. commands[i][3] .. TERM.reset)
	end
end

function Run() 
	local found = false
	for _, cmd in ipairs(commands) do
		local name = cmd[1]
		local fn   = cmd[2]
		local desc = cmd[3]
		local args = cmd[4] or 0

		if name == arg[1] then
			local flags = {}
			for i=(2 + args), #arg do
				table.insert(flags, arg[i])
			end
			fn(flags)
			found = true
		end
	end

	if not found then
		PrintUsage()
	end
end

Run()

