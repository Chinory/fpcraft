local util = require("util")
local type = type
local pairs = pairs
local get = rawget
local push = table.insert
local pop = table.remove

local __weak = {__mode = "kv"}

local function weak() return setmetatable({}, __weak) end

local function id(n) return n end
local function unm(n) return -n end
local function npn(n) return n + n end
local function mul(x) return function(n) return n * x end end
local function div(x) return function(n) return n / x end end

local mt = {__tostring = util.ser}

local function new() return setmetatable({}, mt) end

local function sum(src)
  local ref = weak()
  local n = 0
  ref[src] = true
  repeat
    for _, v in pairs(src) do
      if type(v) == "number" then
        n = n + v
      elseif type(v) == "table" and not ref[v] then
        ref[v] = true
        push(ref, v)
      end
    end
    src = pop(ref)
  until src == nil
  return n
end

local function map(ref, fun, src)
  local function f()
    local dst = new()
    ref[src] = dst
    for i, s in pairs(src) do
      if type(s) == "number" then
        dst[i] = fun(s)
      elseif type(s) == "table" then
        src = ref[s]
        if src then
          dst[i] = src
        else
          src = s
          dst[i] = f()
        end
      end
    end
    return dst
  end
  return f()
end

local function add(ref, dst, src)
  if dst == src then return map(ref, npn, src) end
  ref[dst] = dst
  ref[src] = dst
  for i, s in pairs(src) do
    local d = get(dst, i)
    if type(s) == "number" then
      if type(d) == "number" then
        dst[i] = d + s
      elseif type(d) == "table" then
        local n = get(d, "_")
        d._ = type(n) == "number" and n + s or s
      else
        dst[i] = s
      end
    elseif type(s) == "table" then
      if type(d) == "table" then
        dst[i] = ref[s] or add(ref, d, s)
      else
        s = ref[s] or map(ref, id, s)
        if type(d) == "number" then
          local n = get(s, "_")
          s._ = type(n) == "number" and n + d or d
        end
        dst[i] = s
      end
    end
  end
  src = get(dst, "_")
  dst._ = nil
  if next(dst) ~= nil then
    if src ~= nil and src ~= 0 then dst._ = src end
    return dst
  elseif src ~= nil and src ~= 0 then
    return src
  end
end

local function sub(ref, dst, src)
  if dst == src then return nil end
  ref[dst] = dst
  ref[src] = dst
  for i, s in pairs(src) do
    local d = get(dst, i)
    if type(s) == "number" then
      if type(d) == "number" then
        dst[i] = d - s
      elseif type(d) == "table" then
        local n = get(d, "_")
        d._ = type(n) == "number" and n - s or -s
      else
        dst[i] = -s
      end
    elseif type(s) == "table" then
      if type(d) == "table" then
        dst[i] = ref[s] or sub(ref, d, s)
      else
        s = ref[s] or map(ref, unm, s)
        if type(d) == "number" then
          local n = get(s, "_")
          s._ = type(n) == "number" and n + d or d
        end
        dst[i] = s
      end
    end
  end
  src = get(dst, "_")
  dst._ = nil
  if next(dst) ~= nil then
    if src ~= nil and src ~= 0 then dst._ = src end
    return dst
  elseif src ~= nil and src ~= 0 then
    return src
  end
end

local function prune(dst)
  local ref = weak()
  local function f(ds)
    ref[ds] = true
    for i, d in pairs(ds) do
      if d == 0 then
        ds[i] = nil
      elseif type(d) == "table" and not ref[d] then
        ds[i] = f(d)
      end
    end
    if next(ds) ~= nil then return ds end
  end
  return f(dst)
end

local function clone(src)
  local ref = weak()
  local function f()
    local dst = new()
    ref[src] = dst
    for i, s in pairs(src) do
      if type(s) ~= "table" then
        dst[i] = s
      else
        src = ref[s]
        if src then
          dst[i] = src
        else
          src = s
          dst[i] = f()
        end
      end
    end
    return dst
  end
  return f()
end

function mt.__index(t, k)
  local v = new()
  t[k] = v
  return v
end

function mt.__add(self, x)
  if type(x) == "table" then
    return add(weak(), self, x)
  elseif type(x) == "number" then
    local n = get(self, "_")
    self._ = type(n) == "number" and n + x or x
    return self
  else
    error("operand must be Registry or number", 2)
  end
end

function mt.__sub(self, x)
  if type(x) == "table" then
    return sub(weak(), self, x)
  elseif type(x) == "number" then
    local n = get(self, "_")
    self._ = type(n) == "number" and n - x or -x
    return self
  else
    error("operand must be Registry or number", 2)
  end
end

function mt.__unm(self) --
  return map(weak(), unm, self)
end

function mt.__mul(self, x)
  if type(x) ~= "number" then
    error("operand must be number", 2)
  elseif x == 0 then
    return new()
  elseif x == 1 then
    return self
  else
    return map(weak(), mul(x), self)
  end
end

function mt.__div(self, x)
  if type(x) ~= "number" then
    error("operand must be number", 2)
  elseif x == 1 then
    return self
  else
    return map(weak(), div(x), self)
  end
end

return {new=new, clone=clone, sum=sum, prune=prune}
