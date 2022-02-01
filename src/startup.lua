-- Lua
_G.utils = require("utils")

-- CraftOS
_G.ID = os.getComputerID()
_G.tui = require("tui")
_G.proc = require("proc")
_G.turtle = require("turtle")
_G.axis = require("axis")
_G.inv = require("inv")
_G.act = require("act")
_G.link = require("link")
_G.timer = require("timer")

-- Debug
_G.ez = setmetatable({}, {__index = _G})
ez.ps = function(...) tui.print(tostring(...)) end
ez.pv = function(...) tui.print(utils.ser(...)) end
ez.read = tui.read
ez.write = tui.write
ez.print = tui.print
utils.assign(ez, act)
utils.assign(ez, utils)


-- local insert = table.insert


-- Local Term
local function term_main(exitable)
  local history = {}
  local prefix = '\7' .. ID .. ">"
  while true do
    local str = tui.read(prefix, nil, history, tui.completeLua)
    if str == "" then
      if exitable then break end
    else
      table.insert(history, str)
      if #history > 31 then for _ = 1, 12 do table.remove(history) end end
      if string.sub(str,-1) == ')' then str = 'return ' .. str end -- function tricks
      local code = loadstring(str)
      if code then
        local res = {pcall(setfenv(code, ez))}
        local ok = table.remove(res, 1)
        local t = math.floor(os.time() * 10)
        if ok then
          tui.print("@" .. ID .. " " .. t .. " OK " .. utils.ser(res))
        else
          tui.print("@" .. ID .. " " .. t .. " ERR " .. res[1])
        end
      end
    end
  end
end


-- -- Kill Protect
-- killable = nil
-- local shutdown = os.shutdown
-- local function main_kill()
--   os.pullEventRaw("terminate")
--   if not killable then shutdown() end
-- end

-- Net Instance
local net = link.newNet("a3", "a")
local peer = {}
for i = 1, 32 do
  peer[i] = true
end
net.peer = peer

function ez.reboot()
  net:closeAll()
  os.reboot()
end

function ez.reboots()
  net:sendCmd("os.reboot()", utils.keys(net.seen))
  os.reboot()
end

if net.hw.open then
  net.hw.open(net.idch(ID))
  net.hw.open(65535)
end

-- proc.create(main_kill)
proc.create(link.main)
proc.create(timer.main)

if turtle.fake then
  net.showlog = true
  proc.create(term_main)
  ez.l = net
  tui.print("fxcraft Client 1.0")
else
  proc.create(inv.main)
  proc.create(function()
    local s = ""
    while true do
      term.clear()
      term.setCursorPos(1, 1)
      tui.print("fxcraft Server 1.0")
      tui.print(s)
      s = ""
      local name = tui.read("> UserName: ")
      local key = tui.read("> Password: ", "*")
      local ln = link.of[name]
      if ln and ln.key == key then
        ez.l = ln
        ln.showlog = true
        ln.logs:sort()
        for _, l in ipairs(ln.logs) do
          tui.print('\7'..l)
        end
        term_main(true)
        ln.showlog = false
      else
        os.sleep(3)
        s = " Wrong username or password"
      end
    end
  end)
  -- JOIN link AND inv
  table.insert(net.onConnected, function(self, id) --
    return self:send(id, self.msg.InvData, utils.ser(inv.mySum()))
  end)
  table.insert(inv.onUpdate, function()
    local t = inv.mySum()
    return net:sendAll(net.msg.InvData, utils.ser(t))
  end)
  -- table.insert(lnk.finder.ids, 1)
end

return proc.main()
