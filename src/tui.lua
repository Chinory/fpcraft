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

local tui = {print = print1}

function tui.read(prefix, replaceChar, history, completeFn, default)
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
local sort = table.sort
local sints_tostr = utils.prettySortedInts
local timer = require("timer")
local utils = require("utils")

---@param list any[] after this func it turns into number[]
---@param i integer index of first non-number
---@param v any value of first non-number
---@return string[]|nil
local function remove_strs(list, i, v)
  local strs = {""}
  if type(v) == "string" then
    insert(strs, v)
  end
  for j = i + 1, #list do
    v = list[j]
    local t = type(v)
    if t == "number" then
      list[i] = v
      i = i + 1
    elseif t == "string" then
      insert(strs, v)
    end
  end
  repeat remove(list) until #list < i
  if #list == 1 then return end
  return strs
end

---@param list any[] after this func it should be number[]
local function ensure_nums(list)
  for i, v in ipairs(list) do
    if type(v) ~= "number" then --
      return remove_strs(list, i, v)
    end
  end
end

--- highly optimized, only sort once if list is `number[]`
---@param list any[]
local function into_str(list)
  local strs = ensure_nums(list)
  if #list == 0 then return strs or "" end
  sort(list)
  print(utils.ser(list))
  local nums_str = sints_tostr(list)
  if strs == nil then return nums_str end
  strs[1] = nums_str
  return concat(strs, ',')
end

local reports = {}



local function flush(report)
  reports[report.desc] = nil
  return report.method(report.obj, report.desc .. into_str(report.items))
end

function tui.report(desc, item, age, obj, method)
  local report = reports[desc]
  if report then
    insert(report.items, item)
  else
    ---@class Report
    local t = {
      items = {item}, desc = desc,
      obj = obj, method = method,
      timerFn = flush, timerIv = age,
    }
    reports[desc] = timer.start(t)
  end
end

function tui.completeLua(line)
  local nStartPos = string.find(line, "[a-zA-Z0-9_%.:]+$")
  if nStartPos then line = string.sub(line, nStartPos) end
  if #line > 0 then return textutils.complete(line, ez) end
end

return tui
