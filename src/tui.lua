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

local M = {
  print = print1,
  read = function(prefix, replaceChar, history, completeFn, default)
    reading = prefix
    reset()
    write0(prefix)
    local res = read0(replaceChar, history, completeFn, default)
    reading = nil
    return res
  end
}

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

local reports = {}

local function flush(self)
  reports[self.s] = nil
  local its = ""
  if #self ~= 0 then
    local strs = wrapNonNums(self)
    if #self ~= 0 then
      table.sort(self)
      its = utils.prettySortedInts(self)
      if strs then
        strs[1] = its
        its = concat(strs, ',')
      end
    else
      its = concat(strs, ',', 2)
    end
  end
  return print1(self.s .. its)
end

function M.report(s, it, age)
  local report = reports[s]
  if report then
    insert(report, it)
  else
    reports[s] = timer.once({it, s = s, timerIv = age, timerFn = flush})
  end
end

function M.completeLua(line)
  local nStartPos = string.find(line, "[a-zA-Z0-9_%.:]+$")
  if nStartPos then line = string.sub(line, nStartPos) end
  if #line > 0 then return textutils.complete(line, ez) end
end

return M
