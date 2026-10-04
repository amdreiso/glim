#!/usr/bin/env lua

require("src.utils")
require("src.cmd")

local lfs = require("lfs")
local cwd = lfs.currentdir()

local VERSION = "0.1"

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
	print("Restoring '"..filename.."' object")
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

local commands = {
	{"init", 		CMD_Init, 		"Initializes project in current directory"},
	{"sync", 		CMD_Sync,		"Sync files with project target"},
	{"set", 		CMD_Set, 		"Set project target path"},
	{"status", 		CMD_Status,		"See status"},
	{"remove", 		CMD_Remove,		"Removes .gm folder"},
	{"version", 	CMD_Version,	"See version"},
	{"restore", 	RestoreObjectsFolder,	"See version"},
}

function PrintUsage()
	print("Usage:")
	for i=1, #commands do
		print("    " .. commands[i][1] .. " - " .. commands[i][3])
	end
	print("\nAuthor: Andrei Scatolin")
end

function Run() 
	local found = false
	for _, cmd in ipairs(commands) do
		if cmd[1] == arg[1] then
			cmd[2]()
			found = true
		end
	end

	if not found then
		PrintUsage()
	end
end

Run()

