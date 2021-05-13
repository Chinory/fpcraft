local u = require("utils")
local t = require("turtle")

local M = {}

-- local movf, movu, movd = t.forward, t.up, t.down
-- local digf, digu, digd = t.dig, t.digUp, t.digDown

function M.rusf()
  while true do
    local b, r = M.movf()
    if b then return b, r end
    if r == "Movement obstructed" then
      b, r = M.digf()
      if not b then return b, r end
    end
  end
end

function M.rusu()
  while true do
    local b, r = M.movu()
    if b then return b, r end
    if r == "Movement obstructed" then
      b, r = M.digu()
      if not b then return b, r end
    end
  end
end

function M.rusd()
  while true do
    local b, r = M.movd()
    if b then return b, r end
    if r == "Movement obstructed" then
      b, r = M.digd()
      if not b then return b, r end
    end
  end
end

function M.cube(work, tun1, tun2, depth, width, updown, floors)
  local tun = tun1
  local turn = function() return tun() end
  local revt = function() tun = tun == tun1 and tun2 or tun1 end
  local line = u.Altn(work, M.rusf, depth)
  local flat = u.Altn(line, u.Seq4(turn, M.rusf, turn, revt), width)
  return u.altn(flat, u.Seq3(turn, turn, updown), floors)
end

function M.dig3lu(depth, width, floors)
  return M.cube(u.Seq2(M.digd, M.digu), M.tunl, --
  M.tunr, depth, width, u.Rep3(M.rusu), floors)
end

function M.dig3ru(depth, width, floors)
  return M.cube(u.Seq2(M.digd, M.digu), M.tunr, --
  M.tunl, depth, width, u.Rep3(M.rusu), floors)
end

function M.dig3ld(depth, width, floors)
  return M.cube(u.Seq2(M.digu, M.digd), M.tunl, --
  M.tunr, depth, width, u.Rep3(M.rusd), floors)
end

function M.dig3rd(depth, width, floors)
  return M.cube(u.Seq2(M.digu, M.digd), M.tunr, --
  M.tunl, depth, width, u.Rep3(M.rusd), floors)
end

local funcs = {
  t.forward, t.back, t.up, t.down, -- r1b8
  t.turnLeft, t.turnRight, -- r1b8
  t.dig, t.digUp, t.digDown, -- [side]  r1b8
  t.attack, t.attackUp, t.attackDown, -- [side] r1b8
  t.place, t.placeUp, t.placeDown, -- r1b8
  t.drop, t.dropUp, t.dropDown, -- [count] r1b8
  t.suck, t.suckUp, t.suckDown, -- [count] r1b8
  t.detect, t.detectUp, t.detectDown, -- r1
  t.compare, t.compareUp, t.compareDown, -- r1
  t.inspect, t.inspectUp, t.inspectDown, -- r1
  t.getItemCount, t.getItemSpace, t.getItemDetail, -- r0
  t.getSelectedSlot, t.select, t.transferTo, t.compareTo, -- r0 / r1b8 / r1b8 / r1
  t.getFuelLevel, t.refuel, t.equipLeft, t.equipRight, t.craft, -- craft(limit) r1b8
  M.rusf, M.rusu, M.rusd, M.dig3
}

local names = {
  "movf", "movb", "movu", "movd", --
  "tunl", "tunr", --
  "digf", "digu", "digd", --
  "atkf", "atku", "atkd", --
  "plcf", "plcu", "plcd", --
  "drpf", "drpu", "drpd", --
  "sukf", "suku", "sukd", --
  "detf", "detu", "detd", --
  "cmpf", "cmpu", "cmpd", --
  "insf", "insu", "insd", --
  "nvic", "nvis", "nvid", --
  "nvgs", "nvss", "nvtt", "nvct", --
  "gefu", "refu", "eqpl", "eqpr", "crft", --
  "rusf", "rusu", "rusd", "dig3"
}

for i, n in ipairs(names) do
  local f = funcs[i]
  M[n] = f
  names[n] = i
  -- _G[n] = f
end

M.funcs = funcs
M.names = names

return M
