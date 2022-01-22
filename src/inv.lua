local act = require("act")
local stat = require("stat")
local link = require("link")

local function scan()
  local st = stat.new()
  for i = 1, 16 do
    local v = act.nvid(i)
    if v then st[v.name][i] = v.count end
  end
  return st
end

local function sum(st)
  local t = stat.new()
  for k, v in pairs(st) do t[k] = v / 1 end
  return t
end

local M = { --
  sum = sum,
  scan = scan,
  onUpdate = utils.asEvent({})
}

function M.mySum() return sum(M._) end

function link.Msg.InvData(self, id, body, dist, ksrx)
  M[id] = body
  -- self:log("InvData", id, body)
  self:heard(id, dist, ksrx)
end

function M.main()
  if not turtle.fake then M._ = scan() end
  while true do
    os.pullEvent("turtle_inventory")
    local new = scan()
    local old = M._
    M._ = new
    M.onUpdate(new, old)
  end
end

return M
