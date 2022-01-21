local funcs = {
  "t.forward", "t.back", "t.up", "t.down", -- r1b8
  "t.turnLeft", "t.turnRight", -- r1b8
  "t.dig", "t.digUp", "t.digDown", -- [side]  "r1b8
  "t.attack", "t.attackUp", "t.attackDown", -- [side] r1b8
  "t.place", "t.placeUp", "t.placeDown", -- r1b8
  "t.drop", "t.dropUp", "t.dropDown", -- [count] r1b8
  "t.suck", "t.suckUp", "t.suckDown", -- [count] r1b8
  "t.detect", "t.detectUp", "t.detectDown", -- r1
  "t.compare", "t.compareUp", "t.compareDown", -- r1
  "t.inspect", "t.inspectUp", "t.inspectDown", -- r1
  "t.getItemCount", "t.getItemSpace", "t.getItemDetail", -- r0
  "t.getSelectedSlot", "t.select", "t.transferTo", "t.compareTo", -- r0 / r1b8 / r1b8 / r1
  "t.getFuelLevel", "t.refuel", "t.equipLeft", "t.equipRight", "t.craft", -- craft(limit) r1b8
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
}
local file = io.open ('dev/act.txt','w')
for i, n in ipairs(names) do
  local f = funcs[i]
  file:write("" .. n .. "=" .. f .. ", ")
end

file:close()
