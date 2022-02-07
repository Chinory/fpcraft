local insert = table.insert
local remove = table.remove
local unpack = table.unpack
local tui = require("tui")

local M = {max = 0}

function M.create(f)
  local id = M.max + 1
  local task = {id, coroutine.create(f)}
  M.max = id
  insert(M, task)
  return id
end

function M.remove(id)
  for i, task in ipairs(M) do
    if task[1] == id then
      return remove(M, i)
    end
  end
end

function M.main()
  local argv = {}
  while true do
    for _, task in ipairs(M) do
      if task[3] == nil or task[3] == argv[1] then
        local ok, res = coroutine.resume(task[2], unpack(argv))
        task[3] = res
        if not ok then
          tui.print("\19 " .. res)
        end
      end
    end
    for i = #M, 1, -1 do
      if coroutine.status(M[i][2]) == 'dead' then
        remove(M, i)
      end
    end
    argv = {os.pullEventRaw()}
  end
end

return M
