local cids = {
  air = core.CONTENT_AIR,
  bars = core.get_content_id("xpanes:bar"),
  bones = core.get_content_id("bones:bones"),
}

local stair = {}
core.register_on_mods_loaded(function()
  for node,def in pairs(core.registered_nodes) do
    if node:find("^stairs:stair_") then
      stair[core.get_content_id(node)] = true
    end
  end
end)

local vs = vector.subtract
local mf = math.floor

local bone_loot = dungeonsplus.dependencies.bonemeal and function(pos)
  local pcgr = PcgRandom(core.hash_node_position(pos))
  local meta = core.get_meta(pos)
  local inv = meta:get_inventory()

  inv:set_size("main",8*4)
  for i = 1, 8*4 do
    if pcgr:next(1,100) < 25 then
      inv:set_stack("main",i,ItemStack("bonemeal:bone"))
    end
  end

  local bones_formspec =
    "size[8,9]" ..
    "list[current_name;main;0,0.3;8,4;]" ..
    "list[current_player;main;0,4.85;8,1;]" ..
    "list[current_player;main;0,6.08;8,3;8]" ..
    "listring[current_name;main]" ..
    "listring[current_player;main]" ..
    default.get_hotbar_bg(0,4.85)
  meta:set_string("formspec",bones_formspec)
  meta:set_string("owner","")
end or function(pos)
  local pcgr = PcgRandom(core.hash_node_position(pos))
  local meta = core.get_meta(pos)
  local inv = meta:get_inventory()

  inv:set_size("main",8*4)

  local bones_formspec =
    "size[8,9]" ..
    "list[current_name;main;0,0.3;8,4;]" ..
    "list[current_player;main;0,4.85;8,1;]" ..
    "list[current_player;main;0,6.08;8,3;8]" ..
    "listring[current_name;main]" ..
    "listring[current_player;main]" ..
    default.get_hotbar_bg(0,4.85)
  meta:set_string("formspec",bones_formspec)
  meta:set_string("owner","")
end

return {
  name = "Jail",
  surfaces = {
    "floor",
    "wall",
  },
  weight = 5,
  conditions = {
    room = {
      function(room)
        local size = vs(room.max,room.min)
        return size.x < 6 or size.z < 6
      end,
    },
    mods = {
      function(mod,path)
        return mod == "default" and path
      end,
      function(mod,path)
        return mod == "xpanes" and path
      end,
      function(mod,path)
        return mod == "bones" and path
      end,
    },
  },
  generate = function(data)
    local room = data.room
    local vm = data.vm
    local va = data.va
    local ystride = data.va.ystride
    local zstride = data.va.zstride
    local pos = data.va:indexp(room.min)
    local vdata = data.vdata
    local vparam2 = data.vparam2
    local pcgr = PcgRandom(pos)

    -- Note x/z air gaps of the room's outer walls
    -- Also note bare spots on the floor where bones will be placed
    local bone_zone = {}
    local gaps = {}
    local size = vs(room.max,room.min)
    local xmin = 0
    local xmax = size.x
    local ymin = 0
    local yfloor = 1
    local ymax = size.y - 1
    local zmin = 0
    local zmax = size.z
    for x = xmin, xmax do
      for y = ymin, ymax do
        for z = zmin, zmax do
          local npos = pos + x + y * ystride + z * zstride
          if y == ymin and vdata[npos] == cids.air then
            return false -- do not generate jails in rooms with gaps in the floor
          elseif x == xmin or x == xmax or z == zmin or z == zmax then
            if stair[vdata[npos]] then
              return false -- do not generate jails against stairs
            elseif vdata[npos] == cids.air then
              table.insert(gaps,npos)
            end
          elseif y == yfloor and vdata[npos] == cids.air then
            table.insert(bone_zone,npos)
          end
        end
      end
    end

    -- Place bars on gaps
    for _,gap in ipairs(gaps) do
      vdata[gap] = cids.bars
    end

    -- Place bones somewhere in the room if possible
    if #bone_zone > 0 then
      local bpos = pcgr:next(1,#bone_zone)
      vdata[bone_zone[bpos]] = cids.bones
      vparam2[bpos] = pcgr:next(0,3)
      bone_loot(va:position(bone_zone[bpos]))
    end

    return true
  end,
}