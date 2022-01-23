
local clear = term.clearLine
local getpos = term.getCursorPos
local setpos = term.setCursorPos

local function reset()
  clear()
  local _, y = getpos()
  setpos(1, y)
end

local read0 = read
local write0 = write
local print0 = print

local reading

local function print1(...)
  if reading then
    reset()
    print0(...)
    write0(reading)
  else
    print0(...)
  end
end

local M = {print = print1}

function M.read(prefix, replaceChar, history, completeFn, default)
  reading = prefix
  reset()
  write0(prefix)
  local res = read0(replaceChar, history, completeFn, default)
  reading = nil
  return res
end

local insert = table.insert
local remove = table.remove
local concat = table.concat
local timer = require("timer")
local utils = require("utils")

local function wrapNonNums1(I, i, x)
  local O = {"", x}
  local j = i
  while j < #I do
    j = j + 1
    x = I[j]
    if type(x) == "number" then
      I[i] = I[j]
      i = i + 1
    else
      insert(O, x)
    end
  end
  repeat remove(I) until #I < i
  return O
end

local function wrapNonNums(list)
  for i, x in ipairs(list) do
    if type(x) ~= "number" then --
      return wrapNonNums1(list, i, x)
    end
  end
end

local vars, pre0, post0

local function flush0()
  local body = ""
  local nums = vars
  if #nums ~= 0 then
    local strs = wrapNonNums(nums)
    if #nums ~= 0 then
      table.sort(nums)
      body = utils.prettySortedInts(nums)
      if strs then
        strs[1] = body
        body = concat(strs, ',')
      end
    else
      body = concat(strs, ',', 2)
    end
  end
  print1(pre0 .. body .. post0)
end

local function flush1()
  flush0()
  vars = nil
  pre0 = nil
  post0 = nil
end

local flush = {timerFn = flush1}

function M.report(pre, var, post, age)
  if vars then
    if pre == pre0 and post == post0 then
      insert(vars, var)
      return
    end
    timer.stop(flush)
    flush0()
  end
  vars = {var}
  pre0 = pre
  post0 = post
  flush.timerIv = age
  timer.once(flush)
end

function M.completeLua(line)
  local nStartPos = string.find(line, "[a-zA-Z0-9_%.:]+$")
  if nStartPos then line = string.sub(line, nStartPos) end
  if #line > 0 then return textutils.complete(line, ez) end
end

return M
