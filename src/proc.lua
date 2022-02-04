-- local utils = require("utils")
-- local tui = require("tui")
local unpack = table.unpack
local tui = require("tui")
local managed = {}

local M = {max = 0, n = 0}

function M.add(co)
  local id = M.max + 1
  local task = { co = co }
  M.max = id
  managed[id] = task
  M.n = M.n + 1
  return task
end

function M.create(f)
  local id = M.max + 1
  local task = { co = coroutine.create(f) }
  M.max = id
  managed[id] = task
  M.n = M.n + 1
  return task
end

function M.kill(id)
  local co = managed[id]
  if co then
    managed[id] = nil
    M.n = M.n - 1
    return co
  end
end

function M.main()
  local evdata = {}
  while true do
    for id, task in pairs(managed) do
      if task.ev == nil or task.ev == evdata[1] then
        local ok, ev = coroutine.resume(task.co, unpack(evdata)) --foreign
        if not ok then
          tui.print("\19 " .. ev)
          managed[id] = nil
          M.n = M.n - 1
        elseif coroutine.status(task.co) == "dead" then
          managed[id] = nil
          M.n = M.n - 1
        else
          task.ev = ev
        end
      end
    end
    for id, task in pairs(managed) do
      if coroutine.status(task.co) == "dead" then
        managed[id] = nil
        M.n = M.n - 1
      end
    end
    evdata = {os.pullEventRaw()}
    -- tui.print(utils.ser(evdata))
  end
end

setmetatable(M, {__index = managed})

return M
