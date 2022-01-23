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

local function extend(list, more)
  for _, x in ipairs(more) do
    insert(list, x)
  end
  return list
end

local function assign(dst, src)
  for k, v in ipairs(src) do dst[k] = v end
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
        return curried(extend({unpack(args0)}, shrink({...}, argn - #args0)))
      end
    else
      return function(...)
        local args1 = {...}
        if #args1 == 0 then return func(unpack(args0)) end
        return func(unpack(extend({unpack(args0)}, args1)))
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

local function cond(it) -- it: If Then
  local i = 1
  while i < #it do
    if it[i]() then
      return it[i + 1]()
    end
    i = i + 2
  end
  if i == #it then
    return it[i]()
  end
end

---- export ----

local function nop() end

local M = {
  T = true, F = false, nop = nop,
  id = function(val) return val end,
  of = function(val) return function(new)
    if new == nil then return val end
    local old = val val = new return old
  end end,
  find = function(t, x) for i, v in ipairs(t) do if v == x then return i end end end,
  keys = keys, shrink = shrink, extend = extend, assign = assign,
  map = map, filter = filter, curry = curry, quote = quote, partial = partial,
  Src = function(f) return function() return f() end end,
  Dst = function(f) return function(...) f(...) end end,
  Isl = function(f) return function() f() end end,
  If = function(...) local it = {...} return function() return cond(it) end end,
  Do = function(...) local fn = {...} return function() for _, f in ipairs(fn) do f() end end end,
  Do2 = function(a,b) return function() a() b() end end,
  Do3 = function(a,b,c) return function() a() b() c() end end,
  Do4 = function(a,b,c,d) return function() a() b() c() d() end end,
  For = function(n, f) return function(...) for _ = 1, n do f(...) end end end,
  Re2 = function(f) return function() f() f() end end,
  Re3 = function(f) return function() f() f() f() end end,
  Re4 = function(f) return function() f() f() f() f() end end,
  While = function(x, f) return function(...) while (x()) do f(...) end end end,
  ABA = function(n, a, b) if n >= 1 then return function() a() for _ = 2, n do b() a() end end else return a end end,
  TPV = function(f, a, b) return function() return f() end, function() if f == a then f = b else f = a end end end, -- three-port valve
  TPVp = function(f, a, b) return function(...) return f(...) end, function() if f == a then f = b else f = a end end end,
  TPVx = function(f, a, b) return function() return f() end, function(x) if x then f = x elseif f == a then f = b else f = a end end end,
  TPVpx = function(f, a, b) return function(...) return f(...) end, function(x) if x then f = x elseif f == a then f = b else f = a end end end,
  Get = function(t, k) return function() return t[k] end end,
  Set = function(t, k) return function(v) t[k] = v end end,
  Eq = function(x, y) return function(...) return x(...) == y(...) end end,
  Ne = function(x, y) return function(...) return x(...) ~= y(...) end end,
  Lt = function(x, y) return function(...) return x(...) < y(...) end end,
  Gt = function(x, y) return function(...) return x(...) > y(...) end end,
  Le = function(x, y) return function(...) return x(...) <= y(...) end end,
  Ge = function(x, y) return function(...) return x(...) >= y(...) end end,
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

function M.prettyList(list)
  local nums = {}
  local strs = {""}
  for _, x in ipairs(list) do
    if type(x) == "number" then
      insert(nums, x)
    else
      insert(strs, x)
    end
  end
  if #nums > 0 then
    table.sort(nums)
    if #strs > 1 then
      strs[1] = M.prettySortedInts(nums)
      return concat(strs, ',')
    end
    return M.prettySortedInts(nums)
  end
  return concat(strs, ',', 2)
end

function M.prettySortedInts(I)
  local O = {}
  local s, e
  local function flush()
    if e - s == 1 then
      insert(O, s)
      insert(O, e)
    else
      insert(O, s .. '~' .. e)
    end
  end
  local function clear()
    if s then
      if e then
        flush()
        e = nil
      else
        insert(O, s)
      end
      s = nil
    end
  end
  for _, x in ipairs(I) do
    if type(x) ~= "number" then
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
        insert(O, s)
        s = x
      end
    else
      s = x
    end
  end
  clear()
  return concat(O, ',')
end

local lti1 = function(a, b) return a[1] < b[1] end

function M.setMetaKVList(t, keyListName, valueListName)
  local kv = {}
  for k, v in pairs(t) do
    insert(kv, {k, v})
  end
  table.sort(kv, lti1)
  local ks = {}
  local vs = {}
  for _, p in ipairs(kv) do
    insert(ks, p[1])
    insert(vs, p[2])
  end
  return setmetatable(t, {__index = {[keyListName] = ks, [valueListName] = vs}})
end

return M
