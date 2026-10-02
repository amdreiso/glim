
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

Event("PreCreate_0.gml", "@pre_create")
Event("Create_0.gml", "@create")
Event("Destroy_0.gml", "@destroy")
Event("CleanUp_0.gml", "@cleanup")

for i=0, 10 do
	Event("Alarm_"..i..".gml", "@alarm["..i.."]")
end

Event("Step_0.gml", "@step")
Event("Step_1.gml", "@step_begin")
Event("Step_2.gml", "@step_end")

Event("Draw_0.gml", "@draw")
Event("Draw_1.gml", "@draw_begin")
Event("Draw_2.gml", "@draw_end")
Event("Draw_64.gml", "@draw_gui")
Event("Draw_65.gml", "@draw_gui_begin")
Event("Draw_66.gml", "@draw_gui_end")

