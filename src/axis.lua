local utils = require("utils")
local turtle = require("turtle")
-- local vector = require("vector")
local concat = table.concat
local loadstring = loadstring
local pcall = pcall

local function new_ax() return {0, 0, 0, 1, 0} end

local axis = {}

local M = {}

function M.save(k)
  local f, r = fs.open("axis/" .. k, 'w')
  if not f then return f, r end
  for id, v in pairs(axis[k]) do
    f.write(id .. ",")
    f.writeLine(concat(v, ","))
  end
  f.close()
  return true
end

function M.load(k)
  local f, r = fs.open("axis/" .. k, 'r')
  if not f then return f, r end
  local ax = axis[k]
  if not ax then
    ax = {}
    axis[k] = ax
  end
  local l = f.readLine()
  while l do
    local c = loadstring("return " .. l)
    if c then
      local b, id, x, y, z, dx, dz = pcall(c)
      if b then ax[id] = {x, y, z, dx, dz} end
    end
    l = f.readLine()
  end
  f.close()
  if not ax[ID] then ax[ID] = new_ax() end
  return true
end

function M.init(k) axis[k] = {[ID] = new_ax()} end

local turnLeft = turtle.turnLeft
function turtle.turnLeft()
  local b, r = turnLeft()
  if b then
    local id = ID
    for _, ax in pairs(axis) do
      local v = ax[id]
      if not v then
        v = new_ax()
        ax[id] = v
      end
      local dx = v[4]
      v[4] = v[5]
      v[5] = -dx
    end
    M.save(id)
  end
  return b, r
end

local turnRight = turtle.turnRight
function turtle.turnRight()
  local b, r = turnRight()
  if b then
    local id = ID
    for _, ax in pairs(axis) do
      local v = ax[id]
      if not v then
        v = new_ax()
        ax[id] = v
      end
      local dz = v[5]
      v[5] = v[4]
      v[4] = -dz
    end
    M.save(id)
  end
  return b, r
end

local forward = turtle.forward
function turtle.forward()
  local b, r = forward()
  if b then
    local id = ID
    for _, ax in pairs(axis) do
      local v = ax[id]
      if not v then
        v = new_ax()
        ax[id] = v
      end
      v[1] = v[1] + v[4]
      v[3] = v[3] + v[5]
    end
    M.save(id)
  end
  return b, r
end

local back = turtle.back
function turtle.back()
  local b, r = back()
  if b then
    local id = ID
    for _, ax in pairs(axis) do
      local v = ax[id]
      if not v then
        v = new_ax()
        ax[id] = v
      end
      v[1] = v[1] - v[4]
      v[3] = v[3] - v[5]
    end
    M.save(id)
  end
  return b, r
end

local up = turtle.up
function turtle.up()
  local b, r = up()
  if b then
    local id = ID
    for _, ax in pairs(axis) do
      local v = ax[id]
      if not v then
        v = new_ax()
        ax[id] = v
      end
      v[2] = v[2] + 1
    end
    M.save(id)
  end
  return b, r
end

local down = turtle.down
function turtle.down()
  local b, r = down()
  if b then
    local id = ID
    for _, ax in pairs(axis) do
      local v = ax[id]
      if not v then
        v = new_ax()
        ax[id] = v
      end
      v[2] = v[2] - 1
    end
    M.save(id)
  end
  return b, r
end

if not M.load(ID) then M.init(ID) end

setmetatable(axis, {__index = M})

return axis
