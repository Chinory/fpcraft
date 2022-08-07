local act = require("act")
local stat = require("stat")
local link = require("link")

local Inv = {onUpdate = utils.asEvent({})}

function Inv.scan()
  local st = stat.new()
  for i = 1, 16 do
    local v = act.nvid(i)
    if type(v) == "table" then
      st[v.name][i] = v.count
    end
  end
  return st
end

function Inv.sum(st)
  local t = stat.new()
  for k, v in pairs(st) do
    t[k] = stat.sum(v)
  end
  return t
end

local singleton = setmetatable({}, {__index = Inv})

function Inv.mySum()
  return Inv.sum(singleton[ID])
end


function link.Lnk.InvData(_, id, body)
  singleton[id] = utils.des(body)
end

function Inv.main()
  if not turtle.fake then
    singleton[ID] = Inv.scan()
  end
  while true do
    os.pullEvent("turtle_inventory")
    local new = Inv.scan()
    local old = singleton[ID]
    singleton[ID] = new
    singleton.onUpdate(new, old)
  end
end

return singleton
