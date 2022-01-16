local type = type
local pairs = pairs
local ipairs = ipairs
local tostr = tostring
local match = string.match
local format = string.format
local remove = table.remove
local unpack = table.unpack
local insert = table.insert
local concat = table.concat

---- table ----

local function shrink(list, size)
  while #list > size do remove(list) end
  return list
end

local function extend(A, B)
  local AB = {unpack(A)}
  for _, b in ipairs(B) do insert(AB, b) end
  return AB
end

local function assign(dst, src)
  for k, v in pairs(src) do dst[k] = v end
  return dst
end

local function keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  return ks
end

---- func ----

local function map(func, list)
  local res = {}
  for _, x in ipairs(list) do
    insert(res, func(x))
  end
  return res
end

local function filter(func, list)
  local res = {}
  for _, x in ipairs(list) do
    if func(x) then insert(res, x) end
  end
  return res
end

local function curry(argn, func)
  local function curried(args0)
    if #args0 < argn then
      return function(...)
        return curried(extend(args0, shrink({...}, argn - #args0)))
      end
    else
      return function(...)
        local args1 = {...}
        if #args1 == 0 then return func(unpack(args0)) end
        return func(unpack(extend(args0, args1)))
      end
    end
  end
  return curried({})
end

local function quote(func, ...)
  local args = {...}
  if #args == 0 then return func end
  return function() return func(unpack(args)) end
end

local function partial(func, ...)
  local args0 = {...}
  return function(...)
    local args1 = {...}
    local args = {unpack(args0)}
    local i = 1
    for j = 1, #args do
      if args[j] == "_" then
        args[j] = args1[i]
        i = i + 1
      end
    end
    for k = i, #args1 do args[k] = args1[k] end
    return func(unpack(args))
  end
end

---- flow ----

local function cond(tups)
  local i = 1
  while i < #tups do
    if tups[i]() then
      return tups[i + 1]()
    end
    i = i + 2
  end
  if i == #tups then
    return tups[i]()
  end
end

---- export ----

local M = {
  -- table --
  find = function(t, x) for i, v in ipairs(t) do if v == x then return i end end end,
  keys = keys,
  shrink = shrink,
  extend = extend,
  assign = assign,
  -- func --
  id = function(val) return val end,
  of = function(val) return function(new)
    if new == nil then return val end
    local old = val val = new return old
  end end,
  map = map,
  filter = filter,
  curry = curry,
  quote = quote,
  partial = partial,
  Src = function(f) return function() return f() end end,
  Dst = function(f) return function(...) f(...) end end,
  Isl = function(f) return function() f() end end,
  nop = function() end,
  -- flow --
  If = function(...) local tups = {...} return cond(tups) end,
  Do = function(...) local fn = {...} return function(...) for _, f in ipairs(fn) do f(...) end end end,
  For = function(n, f) return function(...) for _ = 1, n do f(...) end end end,
  While = function(x, f) return function(...) while (x()) do f(...) end end end,
  ABA = function(n, a, b) if n >= 1 then a() for _ = 2, n do b() a() end end end,
  -- lang --
  Get = function(t, k) return function() return t[k] end end,
  Set = function(t, k) return function(v) t[k] = v end end,
  Eq = function(x, y) return function(...) return x(...) == y(...) end end,
  Ne = function(x, y) return function(...) return x(...) ~= y(...) end end,
  Lt = function(x, y) return function(...) return x(...) < y(...) end end,
  Gt = function(x, y) return function(...) return x(...) > y(...) end end,
  Le = function(x, y) return function(...) return x(...) <= y(...) end end,
  Ge = function(x, y) return function(...) return x(...) >= y(...) end end,
  T = true,
  F = false,
}

---- ring list ----

local Ring = {}

function Ring.sort(t)
  local i = t[0]
  if i + i < #t then
    for _ = 2, i do insert(t, remove(t, 1)) end
  else
    for _ = i, #t do insert(t, 1, remove(t)) end
  end
  t[0] = 1
  return t
end

function Ring.write(t, v)
  local i = t[0]
  t[i] = v
  i = i + 1
  if i > #t then i = 1 end
  t[0] = i
  return t
end

local mt_Ring = {__index = Ring}

function M.newRing(n, d)
  local t = {[0] = 1}
  for i = 1, n do t[i] = d end
  return setmetatable(t, mt_Ring)
end

---- Set ----

local mt_Set = {
  __tostring = function(t)
    return "{" .. concat(keys(t), ",") .. "}"
  end
}

function M.asSet(t)
  return setmetatable(t, mt_Set)
end

---- event dispatcher ----

local mt_Event = {
  __call = function(self, ...)
    for _, f in ipairs(self) do f(...) end
  end
}

function M.asEvent(t)
  return setmetatable(t, mt_Event)
end

---- task queue ----

local mt_TaskQueue = {
  __call = function(self)
    local f = remove(self, 1)
    if f then return f() end
  end
}

function M.asTaskQueue(t)
  return setmetatable(t, mt_TaskQueue)
end

---- Lua-lang ----

local KEYWORD = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true
}

local function keystr(k)
  return not KEYWORD[k] and match(k, "^[%a_][%a%d_]*$") or format("[%q]", k)
end

local function serOptArrLen(t)
  local pad, fly, lim = 0, 0, 0
  local m, s, i = 10, 4, 1
  while true do
    local n = #t + 1
    if n > m then n = m end
    while i < n do
      if t[i] == nil then
        pad = pad + 2 --assert(_==nil)
      else
        fly = fly + s
      end
      if fly > pad then
        fly = 0
        pad = 0
        lim = i
      end
      i = i + 1
    end
    if n ~= m then
      return lim
    end
    s = s + 1
    m = m * 10
  end
end

local sert

local function sera(r,a)
  local t = type(a)
  if t == "number" then
    return tostr(a)
  elseif t == "string" then
    return format("%q", a)
  elseif t == "table" then
    if not r[a] then
      r[a] = true
      return sert(r,a)
    end
  elseif t == "boolean" then
    return a and "T" or "F"
  elseif t == "function" then
    return "(_)"
  end
end

sert = function(r,a)
  local o = {"{"}
  local n = serOptArrLen(a)
  for i = 1, n do
    o[#o+1]=(a[i]~=nil and sera(r,a[i]) or "_") o[#o+1]= ","
  end
  for k, v in pairs(a) do
    local t = type(k)
    if t == "number" then
      if k > n or k < 1 or k % 1 ~= 0 then
        v = sera(r,v)
        if v then
          o[#o+1]=("[" .. k .. "]=") o[#o+1]=v o[#o+1]=","
        end
      end
    elseif t == "string" then
      v = sera(r,v)
      if v then
        o[#o+1]=keystr(k) o[#o+1]="=" o[#o+1]=v o[#o+1]=","
      end
    elseif t == "table" then
      k = sert(r,k)
      if k then
        v = sera(r,v)
        if v then
          o[#o+1]="[" o[#o+1]=k o[#o+1]="]=" o[#o+1]=v o[#o+1]=","
        end
      end
    elseif t == "boolean" then
      v = sera(r,v)
      if v then
        o[#o+1]=(k and "[T]=" or "[F]=") o[#o+1]=v o[#o+1]=","
      end
    end
  end
  if #o == 1 then return "{}" end
  o[#o] = "}"
  return concat(o)
end

function M.ser(any)
  return sera({},any)
end

function M.des(str)
  local fn = loadstring("local _,T,F=nil,true,false return " .. str, "des")
  if fn then
    local ok, res = pcall(fn)
    if ok then return res end
  end
end

function M.prettySortedInts(i)
  local o = {}
  local s, e
  local function flush()
    if e - s == 1 then
      insert(o, s)
      insert(o, e)
    else
      insert(o, s .. '..' .. e)
    end
  end
  local function clear()
    if s then
      if e then
        flush()
        e = nil
      else
        insert(o, s)
      end
      s = nil
    end
  end
  for _, x in ipairs(i) do
    if not x then
      clear()
    elseif e then
      if x - e == 1 then
        e = x
      else
        flush()
        s = x
        e = nil
      end
    elseif s then
      if x - s == 1 then
        e = x
      else
        insert(o, s)
        s = x
      end
    else
      s = x
    end
  end
  clear()
  return concat(o, ',')
end

return M
