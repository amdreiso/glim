#!/usr/bin/env lua

local lfs = require("lfs")
local cwd = lfs.currentdir()
local gmdir = cwd .. "/.gm/"

-- Utils
local VERSION = "0.2"

local function Input(str)
	io.write(str)
	return io.read()
end

_G.TERM = {
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

function _G.FolderExists(path)
  local ok = os.execute("test -d '" .. path .. "'")
  return ok == true or ok == 0
end

function _G.FileExists(path)
  local ok = os.execute("test -f '" .. path .. "'")
  return ok == true or ok == 0
end

_G.GML_EVENT_ORDER = {} 

function Event(name, id)
	table.insert(GML_EVENT_ORDER, {
		file = name,
		id = id,
		priority = #GML_EVENT_ORDER,
	})
end

function _G.GML_GetFile(filename)
	for _, val in ipairs(GML_EVENT_ORDER) do
		if val.file == filename then
			return val
		end
	end
	return -1
end

function _G.GML_GetID(id)
	for _, val in ipairs(GML_EVENT_ORDER) do
		if val.id == id then
			return val
		end
	end
	return -1
end

-- Every gamemaker event (kinda)
Event("PreCreate_0.gml", 	"@pre_create")
Event("Create_0.gml", 		"@create")
Event("Destroy_0.gml", 		"@destroy")
Event("CleanUp_0.gml", 		"@cleanup")
for i=0, 10 do Event("Alarm_"..i..".gml", "@alarm["..i.."]") end
Event("Step_0.gml", 		"@step")
Event("Step_1.gml", 		"@step_begin")
Event("Step_2.gml", 		"@step_end")
Event("Draw_0.gml", 		"@draw")
Event("Draw_1.gml", 		"@draw_begin")
Event("Draw_2.gml", 		"@draw_end")
Event("Draw_64.gml", 		"@draw_gui")
Event("Draw_65.gml", 		"@draw_gui_begin")
Event("Draw_66.gml", 		"@draw_gui_end")

-- Commands
function WriteProjectConfig(config)
  	local file = io.open(gmdir.."config.lua", "w")
  	file:write("return {\n")
  	for key, value in pairs(config) do
  		file:write("\t" .. key .. " = " .. string.format("%q", value) .. ",\n")
  	end
  	file:write("}\n")
  	file:close()
end

function ReadProjectConfig()
	return dofile(gmdir.."config.lua")
end

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
	print(TERM.bold.."Project Info: "..TERM.reset)
	WriteProjectConfig({
		name 	= Input(" > name: "),
		author 	= Input(" > author: "),
	})
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

function CMD_Status()
	if not FolderExists(gmdir) then
		print("Glim was not initialized in this folder.")
		print("Try: 'glim init'")
		return
	end
	local config = ReadProjectConfig()
	print(TERM.bold.."====================== "..config.name.." ======================"..TERM.reset)
	print(TERM.dim.."made by "..TERM.reset..config.author)
	print("")
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
	print("Converting Object '"..path.."'")
	local dirname = path:match("([^/]+)/?$")
	local newfilename = dirname .. ".gml"
	local newfilepath = cwd .. "/.gm/project/objects/" .. newfilename
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
			filecontent = filecontent .. file.id .. "\n"
			filecontent = filecontent .. content .. "\n"
			f:close()
		else
			print("Could not open file '"..file.path.."'")
		end
	end

	newfile:write(filecontent)
	newfile:close()

	os.execute("rm -r "..path)

	local size = lfs.attributes(newfilepath, "size")
	print(newfilename.." was generated from '"..dirname.."' with "..size.." bytes")
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
	local file = io.open(path, "r")
	local content = file:read("*a")
	file:close()

	local events = {}
	local currentEvent = nil
	local code = {}

	for line in (content .. "\n"):gmatch("(.-)\n") do
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
			code = code.."\n"
			file:write(code)
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
			os.execute("mv "..path..file.."/* "..path)
			os.execute("rm -r "..path..file)
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

function CMD_Reload()
	os.execute("rm -r "..gmdir.."project/objects/*")
	os.execute("rm -r "..gmdir.."project/scripts/*")
	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()
end

local commands = {
	{"init", 		CMD_Init, 		"Initializes glim in current directory"},
	{"remove", 		CMD_Remove,		"Removes .gm folder"},
	{"set", 		CMD_Set, 		"Set GameMaker project path and convert objects and scripts into .gm/project/"},
	{"status", 		CMD_Status,		"See project status"},
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
		if cmd[1] == arg[1] then
			cmd[2]()
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
