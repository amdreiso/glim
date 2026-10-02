#!/usr/bin/env lua

require("src.utils")
local lfs = require("lfs")
local cwd = lfs.currentdir()

local VERSION = "0.1"

function CMD_Init()
	local path = cwd .. "/.gm/"
	if FolderExists(path) then
		print("Could not initialize glim.")
		print("path '" .. path .. "' already exists in this directory.")
		return
	end
	os.execute("mkdir -p " .. path)
	os.execute("touch ./.gm/PATH")
	os.execute("touch ./.gm/TARGET")
	os.execute("mkdir -p ./.gm/project")
	print("Glim initialized at '" .. path .. "'")
end

function CMD_Remove()
	local path = cwd .. "/.gm/"
	if FolderExists(path) then
		os.execute("rm -rf " .. path)
		print("Removed successfully.")
		return
	end
	print("No glim file system exists in current directory.")
end

function CMD_Load()
	local file = ".gm/TARGET"
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
		print("  set <path to project>")
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
	os.execute("echo '" .. target .. "' > .gm/TARGET")
	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()
end

function CMD_Sync()
end

function CMD_Status()
end

function ConvertObject(path)
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

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." and lfs.attributes(path, "mode") == "directory" then
			local name = file:gsub("%..*$", "")
			ConvertObject(path..file)
		end
	end
end

function RestoreObject(path)
	local file = io.open(path, "r")
	local content = file:read()
	file:close()
end

RestoreObject("/home/andy/programming/glim/demo/Spaceship.gml")

function ConvertScriptsFolder()
	local path = cwd .. "/.gm/project/scripts/"

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." and lfs.attributes(path, "mode") == "directory" then
			os.execute("mv "..path..file.."/* ../")
		end
	end
end

function CMD_Version()
	print("Glim "..VERSION.."v")
	print("Made by Andrei Scatolin")
end

local commands = {
	{"init", 		CMD_Init, 		"Initializes project in current directory"},
	{"sync", 		CMD_Sync,		"Sync files with project target"},
	{"set", 		CMD_Set, 		"Set project target path"},
	{"status", 		CMD_Status,		"See status"},
	{"remove", 		CMD_Remove,		"Removes .gm folder"},
	{"version", 	CMD_Version,	"Print version"},
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

