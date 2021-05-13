local M = {}

local Vector = {
  add = function(r, o) return M.new(r.x + o.x, r.y + o.y, r.z + o.z) end,
  sub = function(r, o) return M.new(r.x - o.x, r.y - o.y, r.z - o.z) end,
  mul = function(r, m) return M.new(r.x * m, r.y * m, r.z * m) end,
  div = function(r, m) return M.new(r.x / m, r.y / m, r.z / m) end,
  unm = function(r) return M.new(-r.x, -r.y, -r.z) end,
  dot = function(r, o) return r.x * o.x + r.y * o.y + r.z * o.z end,
  cross = function(r, o)
    return M.new( --
    r.y * o.z - r.z * o.y, --
    r.z * o.x - r.x * o.z, --
    r.x * o.y - r.y * o.x)
  end,
  length = function(r) return math.sqrt(r.x * r.x + r.y * r.y + r.z * r.z) end,
  normalize = function(r) return r:mul(1 / r:length()) end,
  -- @param d tolerance
  round = function(r, d)
    d = d or 1.0
    return M.new( --
    math.floor((r.x + d * 0.5) / d) * d, math.floor((r.y + d * 0.5) / d) * d,
    math.floor((r.z + d * 0.5) / d) * d)
  end
}

local mt = {
  __index = Vector,
  __add = Vector.add,
  __sub = Vector.sub,
  __mul = Vector.mul,
  __div = Vector.div,
  __unm = Vector.unm,
  __tostring = function(r) return "{" .. r.x .. "," .. r.y .. "," .. r.z .. "}" end
}

function M.new(x, y, z)
  local v = {x = x, y = y, z = z}
  setmetatable(v, mt)
  return v
end

function M.as(t)
  setmetatable(t, mt)
  return t
end

function M.from(a)
	local v = {x = a[1], y = a[2], z = a[3]}
	setmetatable(v, mt)
  return v
end

return M
