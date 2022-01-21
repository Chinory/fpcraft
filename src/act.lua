local t = require("turtle")
local M = {
movf=t.forward, movb=t.back, movu=t.up, movd=t.down,
tunl=t.turnLeft, tunr=t.turnRight,
digf=t.dig, digu=t.digUp, digd=t.digDown,
atkf=t.attack, atku=t.attackUp, atkd=t.attackDown,
plcf=t.place, plcu=t.placeUp, plcd=t.placeDown,
drpf=t.drop, drpu=t.dropUp, drpd=t.dropDown,
sukf=t.suck, suku=t.suckUp, sukd=t.suckDown,
detf=t.detect, detu=t.detectUp, detd=t.detectDown,
cmpf=t.compare, cmpu=t.compareUp, cmpd=t.compareDown,
insf=t.inspect, insu=t.inspectUp, insd=t.inspectDown,
nvic=t.getItemCount, nvis=t.getItemSpace, nvid=t.getItemDetail,
nvgs=t.getSelectedSlot, nvss=t.select,
nvtt=t.transferTo, nvct=t.compareTo,
gefu=t.getFuelLevel, refu=t.refuel,
eqpl=t.equipLeft, eqpr=t.equipRight,
crft=t.craft }

local MVOB = "Movement obstructed"

function M.rusf()
  while true do
    local b, r = M.movf()
    if b then return b, r end
    if r == MVOB then
      b, r = M.digf()
      if not b then return b, r end
    end
  end
end

function M.rusu()
  while true do
    local b, r = M.movu()
    if b then return b, r end
    if r == MVOB then
      b, r = M.digu()
      if not b then return b, r end
    end
  end
end

function M.rusd()
  while true do
    local b, r = M.movd()
    if b then return b, r end
    if r == MVOB then
      b, r = M.digd()
      if not b then return b, r end
    end
  end
end

local u = require("utils")

function M.cube(work, tun1, tun2, depth, width, updown, height)
  local turn, switch = u.TPV(tun1, tun1, tun2)
  local line = u.ABA(depth, work, M.rusf)
  local flat = u.ABA(width, line, u.Do4(turn, M.rusf, turn, switch))
  local cube = u.ABA(height, flat, u.Do3(turn, turn, updown))
  return cube()
end

function M.dig3lu(depth, width, height)
  return M.cube(u.Do2(M.digd, M.digu), M.tunl, M.tunr, depth, width, u.Re3(M.rusu), height)
end

function M.dig3ru(depth, width, height)
  return M.cube(u.Do2(M.digd, M.digu), M.tunr, M.tunl, depth, width, u.Re3(M.rusu), height)
end

function M.dig3ld(depth, width, height)
  return M.cube(u.Do2(M.digu, M.digd), M.tunl, M.tunr, depth, width, u.Re3(M.rusd), height)
end

function M.dig3rd(depth, width, height)
  return M.cube(u.Do2(M.digu, M.digd), M.tunr, M.tunl, depth, width, u.Re3(M.rusd), height)
end

u.setMetaKVList(M, "names", "funcs") -- define: M.names, M.funcs

return M
