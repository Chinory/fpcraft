local M = {reading = nil}

local read = read
local write = write
local print = print
local clear = term.clearLine
local getpos = term.getCursorPos
local setpos = term.setCursorPos

local function reset()
  clear()
  local _, y = getpos()
  setpos(1, y)
end

function M.print(...)
  if M.reading then
    reset()
    print(...)
    write(M.reading)
  else
    print(...)
  end
end

function M.write(...)
  if M.reading then
    reset()
    print(...)
    write(M.reading)
  else
    write(...)
  end
end

function M.read(prefix, replaceChar, history, completeFn, default)
  M.reading = prefix
  reset()
  write(prefix)
  local res = read(replaceChar, history, completeFn, default)
  M.reading = nil
  return res
end

function M.lua_complete(line)
  local nStartPos = string.find(line, "[a-zA-Z0-9_%.:]+$")
  if nStartPos then line = string.sub(line, nStartPos) end
  if #line > 0 then return textutils.complete(line, ez) end
end

return M
