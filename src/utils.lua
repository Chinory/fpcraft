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

local function indexOf(t, x) for i, v in ipairs(t) do if v == x then return i end end end

local mt_Set = {__tostring = function(t) return "{" .. concat(keys(t), ",") .. "}" end}

---- func ----

local function id(val) return val end

local function of(val)
  return function(new)
    if new == nil then return val end
    local old = val
    val = new
    return old
  end
end

local function map(func, list)
  local rets = {}
  for _, x in ipairs(list) do insert(rets, func(x)) end
  return rets
end

local function filter(func, list)
  local rets = {}
  for _, x in ipairs(list) do if func(x) then insert(rets, x) end end
  return rets
end

local function eval(func, ...) return func(...) end

local function quote(func, ...)
  local args = {...}
  if #args == 0 then return func end
  return function() return func(unpack(args)) end
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

local function seq(funcs) for _, f in ipairs(funcs) do f() end end

local function Seq(funcs) return function() return seq(funcs) end end

local function Seq2(a, b)
  return function()
    a()
    b()
  end
end

local function Seq3(a, b, c)
  return function()
    a()
    b()
    c()
  end
end

local function Seq4(a, b, c, d)
  return function()
    a()
    b()
    c()
    d()
  end
end

local function rep(n, func) for _ = 1, n do func() end end

local function Rep(n, func) return function() return rep(n, func) end end

local function Rep2(f)
  return function()
    f()
    f()
  end
end

local function Rep3(f)
  return function()
    f()
    f()
    f()
  end
end

local function Rep4(f)
  return function()
    f()
    f()
    f()
    f()
  end
end

local function cond(list)
  local i = 1
  while i < #list do
    if list[i]() then return list[i + 1]() end
    i = i + 2
  end
  if i == #list then return list[i]() end
end

local function Cond(list) return function() return cond(list) end end

local function try(routine, repair, n)
  local b, s
  for _ = 1, n do
    b, s = routine()
    if b then break end
    repair()
  end
  return b, s
end

local function Try(routine, repair, n) return
    function() return try(routine, repair, n) end end

local function tryi(routine, repair, n)
  local b, s
  for i = 1, n do
    b, s = routine(i)
    if b then break end
    repair(i)
  end
  return b, s
end

local function Tryi(routine, repair, n)
  return function() return tryi(routine, repair, n) end
end

local function fix(routine, repair, n)
  local b, s
  for _ = 1, n do
    b, s = routine()
    if b then break end
    b, s = repair()
    if not b then break end
  end
  return b, s
end

local function Fix(routine, repair, n)
  return function() return fix(routine, repair, n) end
end

local function fixi(routine, repair, n)
  local b, s
  for i = 1, n do
    b, s = routine(i)
    if b then break end
    b, s = repair(i)
    if not b then break end
  end
  return b, s
end

local function Fixi(routine, repair, n)
  return function() return fixi(routine, repair, n) end
end

local function altn(routine, proceed, n)
  if n >= 1 then
    routine()
    for i = 2, n do
      proceed()
      routine()
    end
  end
end

local function Altn(routine, proceed, n)
  return function() return altn(routine, proceed, n) end
end

local function altni(routine, proceed, n)
  if n >= 1 then
    routine(1)
    for i = 2, n do
      proceed(i)
      routine(i)
    end
  end
end

local function Altni(routine, proceed, n)
  return function() return altni(routine, proceed, n) end
end

-- local function Ring(funcs)
--   local i = 1
--   local function exec(...) return funcs[i](...) end
--   local function next(n)
--     i = i + (n or 1)
--     if i > #funcs then i = 1 end
--   end
--   return exec, next
-- end

---- lang ----

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

local function getpre(t)
  local pad, fly, lim = 0, 0, 0
  local m, s, i = 10, 4, 1
  while true do
    local n = #t + 1
    if n > m then n = m end
    while i < n do
      if t[i] == nil then
        pad = pad + 2
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
    if n ~= m then return lim end
    s = s + 1
    m = m * 10
  end
end

local function keystr(k)
  return not KEYWORD[k] and match(k, "^[%a_][%a%d_]*$") or format("[%q]", k)
end

local function ser(any)
  local ref = {}
  local function f(a)
    local t = type(a)
    if t == "number" then
      return tostr(a)
    elseif t == "string" then
      return format("%q", a)
    elseif t == "table" then
      if ref[a] then return end
      ref[a] = true
    elseif t == "boolean" then
      return a and "T" or "F"
    elseif t == "function" then
      return "(_)"
    else
      return
    end
    local s = {"{"}
    local n = getpre(a)
    for i = 1, n do
      s[#s + 1] = a[i] ~= nil and f(a[i]) or "_"
      s[#s + 1] = ","
    end
    for k, v in pairs(a) do
      t = type(k)
      if t == "number" then
        if k > n or k < 1 or k % 1 ~= 0 then
          v = f(v)
          if v then
            s[#s + 1] = "[" .. k .. "]="
            s[#s + 1] = v
            s[#s + 1] = ","
          end
        end
      elseif t == "string" then
        v = f(v)
        if v then
          s[#s + 1] = keystr(k)
          s[#s + 1] = "="
          s[#s + 1] = v
          s[#s + 1] = ","
        end
      elseif t == "table" then
        k = f(k)
        if k then
          v = f(v)
          if v then
            s[#s + 1] = "["
            s[#s + 1] = k
            s[#s + 1] = "]="
            s[#s + 1] = v
            s[#s + 1] = ","
          end
        end
      elseif t == "boolean" then
        v = f(v)
        if v then
          s[#s + 1] = k and "[T]=" or "[F]="
          s[#s + 1] = v
          s[#s + 1] = ","
        end
      end
    end
    if #s == 1 then return "{}" end
    s[#s] = "}"
    return concat(s)
  end
  return f(any)
end

local function des(str)
  local fn = loadstring("local _,T,F=nil,true,false return " .. str, "des")
  if fn then
    local ok, res = pcall(fn)
    if ok then return res end
  end
end

local function prettyInts(ints)
  if #ints == 0 then return "" end
  ints = {unpack(ints)}
  table.sort(ints)
  local res = {}
  local s = remove(ints,1)
  local e
  for _, x in ipairs(ints) do
    if e then
      if x - e == 1 then
        e = x
      else
        insert(res, s .. (e - s == 1 and ',' or '..') .. e)
        s = x
        e = nil
      end
    else
      if x - s == 1 then
        e = x
      else
        insert(res, s)
        s = x
      end
    end
  end
  if e then
    insert(res, s .. (e - s == 1 and ',' or '..') .. e)
  else
    insert(res, s)
  end
  return concat(res,',')
end

---- event ----

local mt_Event = {__call = function(self, ...) for _, f in ipairs(self) do f(...) end end}

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

local function newRing(n, d)
  local t = {[0] = 1}
  for i = 1, n do t[i] = d end
  return setmetatable(t, mt_Ring)
end

---- task queue ----

local mt_TaskQueue = {
  __call = function(self)
    local f = remove(self, 1)
    if f then return f() end
  end
}

---- export ----

local M = {
  -- key row 1 --
  q = quote,
  e = eval,
  r = rep,
  t = try,
  p = partial,
  -- key row 2 --
  a = altn,
  s = seq,
  -- key row 3 --
  c = cond,
  -- table --
  keys = keys,
  shrink = shrink,
  extend = extend,
  assign = assign,
  indexOf = indexOf,
  asSet = function(t) return setmetatable(t, mt_Set) end,
  newRing = newRing,
  -- comp --
  eq = function(r, v) return r == v end,
  ne = function(r, v) return r ~= v end,
  lt = function(r, v) return r < v end,
  gt = function(r, v) return r > v end,
  le = function(r, v) return r <= v end,
  ge = function(r, v) return r >= v end,
  -- func --
  id = id,
  of = of,
  map = map,
  filter = filter,
  eval = eval,
  quote = quote,
  curry = curry,
  partial = partial,
  src = function(func) return function() return func() end end,
  dst = function(func) return function(...) func(...) end end,
  sub = function(func) return function() func() end end,
  nop = function() end,
  -- flow --
  seq = seq,
  Seq = Seq,
  Seq2 = Seq2,
  Seq3 = Seq3,
  Seq4 = Seq4,
  rep = rep,
  Rep = Rep,
  Rep2 = Rep2,
  Rep3 = Rep3,
  Rep4 = Rep4,
  cond = cond,
  Cond = Cond,
  try = try,
  Try = Try,
  tryi = tryi,
  Tryi = Tryi,
  fix = fix,
  Fix = Fix,
  fixi = fixi,
  Fixi = Fixi,
  altn = altn,
  Altn = Altn,
  altni = altni,
  Altni = Altni,
  -- lang --
  T = true,
  F = false,
  ser = ser,
  des = des,
  prettyInts = prettyInts,
  -- event --
  asEvent = function(t) return setmetatable(t, mt_Event) end,
  -- task --
  asTaskQueue = function(t) return setmetatable(t, mt_TaskQueue) end
}

return M
