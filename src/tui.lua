local tui = {}

local clear = term.clearLine
local getpos = term.getCursorPos
local setpos = term.setCursorPos
local raw_read = read
local raw_write = write
local raw_print = print
local insert = table.insert
local concat = table.concat
local sort = table.sort
local timer_start = require("timer").start
local util = require("util")
local sints_tostr = util.prettySortedInts
local push = util.push
local pop = util.pop
local remove = util.remove
--------------------------------//

---@type string[]
local reads = {[0]=0}
local readn = 0
tui.reading = reads --`const`

local function raw_reset()
  clear()
  local _, y = getpos()
  setpos(1, y)
end

tui.write = raw_write

function tui.reset()
  raw_reset()
  local reading = reads[1]
  if reading ~= nil then
    raw_write(reading)
  end
end

function tui.print(...)
  local reading = reads[1]
  if reading ~= nil then
    raw_reset()
    raw_print(...)
    raw_write(reading)
  else
    raw_print(...)
  end
end

---@param prefix string
---@param replaceChar string
---@param history string[]
---@param completeFn function
---@param default string
function tui.read(prefix, replaceChar, history, completeFn, default)
  push(reads, prefix)
  if reads[2] ~= nil then
    os.pullEvent("tui_read_" .. (readn + reads[0]))
  end
  raw_reset()
  raw_write(prefix)
  local input = raw_read(replaceChar, history, completeFn, default)
  remove(reads, 1)
  readn = readn + 1
  if reads[1] ~= nil then
    os.queueEvent("tui_read_" .. (readn + 1))
  end
  return input
end
--------------------------------//

---@param list any[] after this func it turns into number[]
---@param j integer index of first non-number
---@param v any value of first non-number
---@return string[]|nil
local function remove_strs(list, j, v)
  local strs = {""}
  local i = j
  repeat
    local t = type(v)
    if t == "number" then
      list[i] = v
      i = i + 1
    elseif t == "string" then
      insert(strs, v)
    end
    j = j + 1
    v = list[j]
  until v == nil
  while i < j do
    j = j - 1
    list[j] = nil
  end
  if strs[2] == nil then return end
  return strs
end

---@param list any[] after this func it should be number[]
local function ensure_nums(list)
  for j, v in ipairs(list) do
    if type(v) ~= "number" then --
      return remove_strs(list, j, v)
    end
  end
end

--- highly optimized, only sort once if list is `number[]`
---@param list any[]
local function into_str(list)
  local strs = ensure_nums(list)
  if list[1] == nil then
    if strs == nil then return "" end
    return concat(strs, ',')
  end
  sort(list)
  local nums_str = sints_tostr(list)
  if strs == nil then return nums_str end
  strs[1] = nums_str
  return concat(strs, ',')
end

---@type table<string,Report>
local reports = {}
tui.reporting = reports

---@param self Report
local function conclude(self)
  reports[self.desc] = nil
  return self.method(self.obj, self.desc .. into_str(self.items))
end

---@param desc string for interpreting and distinguishing reports
---@param item string|number try to shorten, for example, use ranges instead of integer lists.
---@param age number seconds to conclude
---@param method function callback
---@param obj table self
function tui.report(desc, item, age, method, obj)
  local old = reports[desc]
  if old ~= nil then
    insert(old.items, item)
    return
  end
  ---@class Report
  local self = {
    desc = desc, items = {item},
    method = method, obj = obj,
    timerFn = conclude, timerIv = age,
  }
  reports[desc] = self
  timer_start(self)
end
--------------------------------//

function tui.completeLua(line)
  local nStartPos = string.find(line, "[a-zA-Z0-9_%.:]+$")
  if nStartPos then line = string.sub(line, nStartPos) end
  if #line > 0 then return textutils.complete(line, ez) end
end

return tui
