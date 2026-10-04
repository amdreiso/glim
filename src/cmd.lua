
local lfs = require("lfs")
local cwd = lfs.currentdir()

function _G.CMD_Init()
	local path = cwd .. "/.gm/"
	if FolderExists(path) then
		print("Could not initialize glim.")
		print("path '" .. path .. "' already exists in this directory.")
		return
	end
	os.execute("mkdir -p " .. path)
	os.execute("touch ./.gm/.TARGET")
	os.execute("mkdir -p ./.gm/project")
	os.execute("mkdir -p ./.gm/.diffs")
	os.execute("mkdir -p ./.gm/.diffs/objects")
	os.execute("mkdir -p ./.gm/.diffs/scripts")
	print("Glim initialized at '" .. path .. "'")
end

function _G.CMD_Remove()
	local path = cwd .. "/.gm/"
	if FolderExists(path) then
		os.execute("rm -rf " .. path)
		print("Removed successfully.")
		return
	end
	print("No glim file system exists in current directory.")
end

function _G.CMD_Load()
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

function _G.CMD_Set()
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
	os.execute("echo '" .. target .. "' > .gm/.TARGET")
	CMD_Load()
	ConvertObjectsFolder()
	ConvertScriptsFolder()
end

function _G.CMD_Sync()
end

function _G.CMD_Status()
end

function _G.CMD_Version()
	print("Glim "..VERSION.."v")
	print("Made by Andrei Scatolin")
end

function _G.CMD_Restore()
end

