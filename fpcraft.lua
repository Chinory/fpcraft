dofile('./debug.lua')

-- knowledge & settings
local config = {
    retryTimeout = 0.5,
    fuels = {
        { name = "forestry:charcoal", once = 1 },
        { name = "minecraft:coal", damage = 1, once = 1 }
    },
    protected = {
        ["ComputerCraft:CC-Turtle"] = true
    },
    unbreakable = {
        ["minecraft:bedrock"] = true
    }
}

-- native imports
local unpack = table.unpack or unpack
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local joinTable = table.concat
local remove = table.remove
local match = string.match
local gsub = string.gsub
local function strvalue (str)
    return '"' .. gsub(gsub(str, '\\', '\\\\'), '"', '\\"') .. '"'
end
local luaKeywords = {
    [ "and" ] = true,
    [ "break" ] = true,
    [ "do" ] = true,
    [ "else" ] = true,
    [ "elseif" ] = true,
    [ "end" ] = true,
    [ "false" ] = true,
    [ "for" ] = true,
    [ "function" ] = true,
    [ "if" ] = true,
    [ "in" ] = true,
    [ "local" ] = true,
    [ "nil" ] = true,
    [ "not" ] = true,
    [ "or" ] = true,
    [ "repeat" ] = true,
    [ "return" ] = true,
    [ "then" ] = true,
    [ "true" ] = true,
    [ "until" ] = true,
    [ "while" ] = true,
}
local function tsprint (value)
    local visited = {}
    local strings = {}
    local function insertValue (value)
        if type(value) == 'table' then
            if visited[value] then 
                insert(strings, '{...}')
            else 
                visited[value] = true
                insert(strings, '{')
                local maxIndex = 0
                for index, value in ipairs(value) do
                    insertValue(value)
                    insert(strings, ",")
                    maxIndex = index
                end
                for key, value in pairs(value) do
                    if type(key) ~= 'number' or math.floor(key) ~= key or key < 1 or key > maxIndex then
                        if type(key) == 'string' and not luaKeywords[key] and match(key, '^[%a_][%w_]*$') then
                            insert(strings, key)
                        else
                            insert(strings, '[')
                            insertValue(key)
                            insert(strings, ']')
                        end
                        insert(strings, '=')
                        insertValue(value)
                        insert(strings, ",")
                    end
                end
                if strings[#strings] ~= '{' then strings[#strings] = '}'
                else insert(strings, '}') end
            end
        elseif type(value) == 'number' or type(value) == 'boolean' then
            insert(strings, tostring(value))
        else
            insert(strings, strvalue(tostring(value)))
        end
    end
    insertValue(value)
    return joinTable(strings)
end

local function tprint (value)
    return print(tsprint(value))
end

-- fp tools
local function noop () end
local function getNoop () return noop end
local function getZero () return 0 end
local function getNil () return nil end
local function isNil (value) return value == nil end
local function notNil (value) return value ~= nil end

local _id = {}
for i = 1, 16, 1 do
    _id[i] = function () return i end
end

local function id (value) 
    if _id[value] then return _id[value] 
    else return function () return value end end
end

local function map (func, list)
    local function _map (list)
        local result = {}
        for _, x in ipairs(list) do
            insert(result, func(x))
        end
        return result
    end
    if list ~= nil then return _map(list)
    else return _map end
end

local function filter (func, list)
    local function _filter (list)
        local result = {}
        for _, x in ipairs(list) do
            if func(x) then insert(result, x) end
        end
        return result
    end
    if list ~= nil then return _filter(list)
    else return _filter end
end

local filterNotNil = filter(notNil)

local function once (func) return function () func() end end
local function twice (func) return function () func() func() end end
local function thrice (func) return function () func() func() func() end end
local function fourtimes (func) return function () func() func() func() func() end end

local function x (times)
    if times > 0 then
        return function (...)
            local funcs = {...}
            return function ()
                for n = 1, times, 1 do
                    for _, func in ipairs(funcs) do func() end
                end
            end
        end
    else return getNoop end
end

local function x1 (...)
    local funcs = {...}
    return function ()
        for _, func in ipairs(funcs) do func() end
    end
end

local function x2 (...)
    local funcs = {...}
    return function ()
        for _, func in ipairs(funcs) do func() end
        for _, func in ipairs(funcs) do func() end
    end
end

local function x3 (...)
    local funcs = {...}
    return function ()
        for _, func in ipairs(funcs) do func() end
        for _, func in ipairs(funcs) do func() end
        for _, func in ipairs(funcs) do func() end
    end
end

local function x4 (...)
    local funcs = {...}
    return function ()
        for _, func in ipairs(funcs) do func() end
        for _, func in ipairs(funcs) do func() end
        for _, func in ipairs(funcs) do func() end
        for _, func in ipairs(funcs) do func() end
    end
end

local function altern (delimiter) 
    return function (times)
        if times > 0 then
            return function (func)
                return function ()
                    func()
                    for n = 2, times, 1 do
                        delimiter()
                        func()
                    end     
                end
            end
        else return getNoop end
    end
end

local function cut (n, X)
    while #X > n do remove(X) end
    return X
end

local function concat (A, B)
    local AB = {unpack(A)}
    for _, b in ipairs(B) do insert(AB, b) end
    return AB
end

local function curry (argn, func)
    local function getter (args) 
        if #args < argn then 
            return function (...) 
                return getter(concat(args, cut(argn - #args, {...}))) 
            end 
        else 
            return function (...) 
                if select('#', ...) == 0 then return func(unpack(args)) 
                else return func(unpack(concat(args, {...}))) end 
            end
        end
    end
    return getter({})
end

-- Inventory management
local function findItem (item)
    if type(item) == 'table' then
        if item.name then
            if item.damage then
                return function ()
                    do
                        local data = turtle.getItemDetail()
                        if data 
                            and data.name == item.name
                            and data.damage == item.damage 
                        then return turtle.getSelectedSlot() end
                    end
                    for i = 1, 16, 1 do
                        local data = turtle.getItemDetail(i)
                        if data 
                            and data.name == item.name
                            and data.damage == item.damage 
                        then return i end
                    end
                    return nil
                end
            else
                return function ()
                    do
                        local data = turtle.getItemDetail()
                        if data 
                            and data.name == item.name
                        then return turtle.getSelectedSlot() end
                    end
                    for i = 1, 16, 1 do
                        local data = turtle.getItemDetail(i)
                        if data 
                            and data.name == item.name
                        then return i end
                    end
                    return nil
                end
            end
        else
            return nil
        end
    elseif type(item) == 'string' then
        return function ()
            do
                local data = turtle.getItemDetail(i)
                if data 
                    and data.name == item
                then return turtle.getSelectedSlot() end
            end
            for i = 1, 16, 1 do
                local data = turtle.getItemDetail(i)
                if data 
                    and data.name == item
                then return i end
            end
            return nil
        end
    elseif type(item) == 'number' then
        if math.floor(item) == item and item > 0 and item < 17 then
            return id(item)
        else
            return nil
        end
    else
        return nil
    end
end

local function selectItem (item)
    local findItem = findItem(item)
    if findItem then
        return function ()
            local slot = findItem()
            if slot then return turtle.select(slot) end
            print('blocked at select(' .. tsprint(item) .. '): need supply')
            repeat os.pullEvent('turtle_inventory')
                slot = findItem()
            until slot
            return turtle.select(slot)
        end
    else return nil end
end

local _parseFuelConfigs = map(function (fuelConfig)
    local find = findItem(fuelConfig)
    if find then 
        return { find = find, once = fuelConfig.once or 1, config = fuelConfig }
    else return nil end
end)

local function _refuel (fuels)
    for _, fuel in ipairs(fuels) do
        local slot = fuel.find()
        if slot and turtle.select(slot) then 
            local success, info = turtle.refuel(fuel.once)
            if success then return true
            else print('refuel(' .. tsprint(fuel.config) .. ') at #' .. slot .. ' failed: ' .. info) end
        end
    end
    return false
end

local function forceRefuel ()
    local fuels = filterNotNil(_parseFuelConfigs(config.fuels))
    if not _refuel(fuels) then
        print('blocked at useFuel: need fuel supply: ' .. tsprint(config.fuels))
        repeat os.pullEvent('turtle_inventory')
        until _refuel(fuels)
    end
end

local useFuel = turtle.getFuelLevel() == 'unlimited' and noop or function ()
    if turtle.getFuelLevel() ~= 'unlimited' and turtle.getFuelLevel() < 1 then
        return forceRefuel()
    end
end

-- direction keyword defination
local function front () end
local function left () end
local function right () end
local function rear () end
local function above () end
local function below () end

-- basic action wraps
local turned = 0
local _lazyTurn = true
local _turn = {
    [left] = function ()
        if _lazyTurn then
            turned = turned - 1
            return true
        else
            return turtle.turnLeft()
        end
    end,
    [right] = function ()
        if _lazyTurn then
            turned = turned + 1
            return true
        else
            return turtle.turnRight()
        end
    end,
    [rear] = function ()
        if _lazyTurn then
            turned = turned + 2
            return true
        else
            if turtle.turnRight() then
                if turtle.turnRight() then
                    return true
                else 
                    turtle.turnLeft()
                    return false
                end
            end
            return false
        end
    end,
}
local function turn (direction)
    return _turn[direction];
end
local function getTurned ()
    return turned
end
local function flushTurn ()
    if turned == 0 then return true end
    local n = turned
    if n > 0 then
        while n > 3 do n = n - 3 end
        if n == 1 then 
            turtle.turnRight()
        elseif n == 2 then 
            turtle.turnRight()
            turtle.turnRight()
        else
            turtle.turnLeft()
        end
    else
        while n < -3 do n = n + 3 end
        if n == -1 then 
            turtle.turnLeft()
        elseif n == -2 then 
            turtle.turnLeft()
            turtle.turnLeft()
        else
            turtle.turnRight()
        end
    end
    turned = 0
    return true
end
local function lazyTurn (enable)
    _lazyTurn = enable
end

local _move = {
    [front] = function () flushTurn(); useFuel(); return turtle.forward() end,
    [above] = function () useFuel(); return turtle.up() end,
    [below] = function () useFuel(); return turtle.down() end,
    [rear] = function () flushTurn(); useFuel(); return turtle.back() end,
}
local function move (direction)
    return _move[direction];
end

local _attack = {
    [front] = function () flushTurn(); return turtle.attack() end,
    [above] = function () return turtle.attackUp() end,
    [below] = function () return turtle.attackDown() end,
}
local function attack (direction)
    return _attack[direction];
end

local _dig = {
    [front] = function () flushTurn(); return turtle.dig() end,
    [above] = function () return turtle.digUp() end,
    [below] = function () return turtle.digDown() end,
}
local function dig (direction)
    return _dig[direction];
end

local _place = {
    [front] = function () flushTurn(); return turtle.place() end,
    [above] = function () return turtle.placeUp() end,
    [below] = function () return turtle.placeDown() end,
}
local function place (direction)
    return _place[direction];
end

local _drop = {
    [front] = function () flushTurn(); return turtle.drop() end,
    [above] = function () return turtle.dropUp() end,
    [below] = function () return turtle.dropDown() end,
}
local function drop (direction)
    return _drop[direction];
end

local _suck = {
    [front] = function () flushTurn(); return turtle.suck() end,
    [above] = function () return turtle.suckUp() end,
    [below] = function () return turtle.suckDown() end,
}
local function suck (direction)
    return _suck[direction];
end

local _detect = {
    [front] = function () flushTurn(); return turtle.detect() end,
    [above] = function () return turtle.detectUp() end,
    [below] = function () return turtle.detectDown() end,
}
local function detect (direction)
    return _detect[direction];
end

local _inspect = {
    [front] = function () flushTurn(); return turtle.inspect() end,
    [above] = function () return turtle.inspectUp() end,
    [below] = function () return turtle.inspectDown() end,
}
local function inspect (direction)
    return _inspect[direction];
end

local _compare = {
    [front] = function () flushTurn(); return turtle.compare() end,
    [above] = function () return turtle.compareUp() end,
    [below] = function () return turtle.compareDown() end,
}
local function compare (direction)
    return _compare[direction];
end

local function shouldNotDig (direction)
    local inspect = inspect(direction)
    return function ()
        local success, data = inspect()
        if success and config.protected[data.name] then return true end
        return false
    end
end

local function canNotDig (direction)
    local inspect = inspect(direction)
    return function ()
        local success, data = inspect()
        if success and config.unbreakable[data.name] then return true end
        return false
    end
end

local function getSleep (seconds)
    return function () 
        return sleep(seconds)
    end
end

---- smart movement
local function go (direction, distance)
    if direction == rear then
        local function _go (distance)
            if not (distance > 0) then return getZero end
            return function ()
                local i = 0
                do local move = move(rear)
                    while i < distance do
                        if move() then i = i + 1
                        else break end
                    end
                end
                if i < distance then
                    turn(rear)()
                    return go(front, distance - i)()
                else 
                    return 0 
                end
            end
        end
        if distance == nil then return _go
        else return _go(distance) end
    else
        local move = move(direction)
        if move == nil then return nil end
        local dig = dig(direction)
        local detect = detect(direction)
        local attack = attack(direction)
        local canNotDig = canNotDig(direction)
        local shouldNotDig = shouldNotDig(direction)
        local function _go (distance)
            if not (distance > 0) then return getZero end
            return function ()
                for i = 1, distance, 1 do
                    while not move() do
                        if detect() then
                            if canNotDig() then return distance - i + 1 end
                            repeat while shouldNotDig() do sleep(config.retryTimeout) end
                            until not detect() or dig()
                        else
                            while attack() do sleep(0.5) end
                        end
                    end
                end
                return 0
            end
        end
        if distance == nil then return _go
        else return _go(distance) end
    end
end

local function fix (item, direction)
    local selectItem = selectItem(item)
    if selectItem == nil then return nil end
    local function _fix (direction)
        local compare = compare(direction)
        if compare == nil then return nil end
        local dig = dig(direction)
        local place = place(direction)
        return function () 
            if selectItem() then
                if compare() then return true end
                dig()
                return place()
            end
            return false
        end
    end
    if direction == nil then return _fix
    else return _fix(direction) end
end

-- Common usage of smart movement
local forw   = go(front)
local up     = go(above)
local down   = go(below)
local back   = go(rear)

local forw1  = forw(1)
local up1    = up(1)
local down1  = down(1)
local back1  = back(1)

-- basic exports
rawset(_G, 'config', config)

rawset(_G, 'tsprint', tsprint)
rawset(_G, 'tprint', tprint)

rawset(_G, 'noop', noop)
rawset(_G, 'getNoop', getNoop)
rawset(_G, 'getZero', getZero)
rawset(_G, 'getNil', getNil)
rawset(_G, 'isNil', isNil)
rawset(_G, 'notNil', notNil)

rawset(_G, 'id', id)
rawset(_G, 'map', map)
rawset(_G, 'filter', filter)
rawset(_G, 'filterNotNil', filterNotNil)

rawset(_G, 'once', once)
rawset(_G, 'twice', twice)
rawset(_G, 'thrice', thrice)
rawset(_G, 'fourtimes', fourtimes)
rawset(_G, 'x', x)
rawset(_G, 'x1', x1)
rawset(_G, 'x2', x2)
rawset(_G, 'x3', x3)
rawset(_G, 'x4', x4)
rawset(_G, 'altern', altern)
rawset(_G, 'curry', curry)

rawset(_G, 'front', front)
rawset(_G, 'left', left)
rawset(_G, 'right', right)
rawset(_G, 'rear', rear)
rawset(_G, 'above', above)
rawset(_G, 'below', below)

rawset(_G, 'findItem', findItem)
rawset(_G, 'selectItem', selectItem)
rawset(_G, 'forceRefuel', forceRefuel)
rawset(_G, 'useFuel', useFuel)

rawset(_G, 'turn', turn)
rawset(_G, 'getTurned', getTurned)
rawset(_G, 'flushTurn', flushTurn)
rawset(_G, 'lazyTurn', lazyTurn)

rawset(_G, 'move', move)
rawset(_G, 'attack', attack)
rawset(_G, 'dig', dig)
rawset(_G, 'place', place)
rawset(_G, 'drop', drop)
rawset(_G, 'suck', suck)
rawset(_G, 'detect', detect)
rawset(_G, 'inspect', inspect)
rawset(_G, 'compare', compare)

rawset(_G, 'canNotDig', canNotDig)
rawset(_G, 'getSleep', getSleep)
rawset(_G, 'shouldNotDig', shouldNotDig)

rawset(_G, 'go', go)
rawset(_G, 'fix', fix)

rawset(_G, 'forw', forw)
rawset(_G, 'up', up)
rawset(_G, 'down', down)
rawset(_G, 'back', back)

rawset(_G, 'forw1', forw1)
rawset(_G, 'up1', up1)
rawset(_G, 'down1', down1)
rawset(_G, 'back1', back1)

-- shortcuts
rawset(_G, 'fi', findItem)
rawset(_G, 'si', selectItem)
rawset(_G, 'gfl', turtle.getFuelLevel)
rawset(_G, 'gid', turtle.getItemDetail)

rawset(_G, 'tl', turn(left))
rawset(_G, 'tr', turn(right))
rawset(_G, 'tb', turn(rear))
rawset(_G, 'gt', getTurned)
rawset(_G, 'ft', flushTurn)
rawset(_G, 'lzt', lazyTurn)

rawset(_G, 'mf', move(front))
rawset(_G, 'mb', move(rear))
rawset(_G, 'mu', move(above))
rawset(_G, 'md', move(below))

rawset(_G, 'af', attack(front))
rawset(_G, 'au', attack(above))
rawset(_G, 'ad', attack(below))

rawset(_G, 'df', dig(front))
rawset(_G, 'du', dig(above))
rawset(_G, 'dd', dig(below))
rawset(_G, 'dud', x1(du,dd))

rawset(_G, 'pf', place(front))
rawset(_G, 'pu', place(above))
rawset(_G, 'pd', place(below))

rawset(_G, 'dropf', drop(front))
rawset(_G, 'dropu', drop(above))
rawset(_G, 'dropd', drop(below))

rawset(_G, 'suckf', suck(front))
rawset(_G, 'sucku', suck(above))
rawset(_G, 'suckd', suck(below))

rawset(_G, 'cmpf', compare(front))
rawset(_G, 'cmpu', compare(above))
rawset(_G, 'cmpd', compare(below))




-- Compound action
rawset(_G, 'wall', curry(4, function (updown, height, work, length)
    local rod = altern(forw1)(length)(work)
    local nextRod = x1(turn(rear), updown(1))
    local board = altern(nextRod)(height)(rod)
    return board()
end))

rawset(_G, 'board', curry(4, function (leftright, width, length, work)
    local turnH = function () return turn(leftright)() end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local girder = x1(turnH, altern(forw1)(width)(work), revH, turnH)
    local board = altern(forw1)(length)(girder)
    return board()
end))

rawset(_G, 'block', curry(6, function (leftright, width, length, updown, height, work)
    local turnH = function () return turn(leftright)() end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local girder = x1(turnH, altern(forw1)(width)(work), revH, turnH)
    local board = altern(forw1)(length)(girder)
    local nextBoard = x1(turnH, turnH, revH, updown(1))
    local block = altern(nextBoard)(height)(board)
    return block()
end))

rawset(_G, 'dig3', curry(5, function (leftright, width, length, updown, floors)
    local work = x1(dig(above),dig(below))
    local turnH = function () return turn(leftright)() end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local girder = x1(turnH, altern(forw1)(width)(work), revH, turnH)
    local board = altern(forw1)(length)(girder)
    local nextBoard = x1(turnH, turnH, revH, updown(3))
    local block = altern(nextBoard)(floors)(board)
    return block()
end))

rawset(_G, 'fence', curry(6, function (leftright, width, length, updown, height, work)
    local turnH = function () return turn(leftright)() end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local border = x2(x(length-1)(work,forw1),turnH,x(width-1)(work,forw1),turnH)
    local fence = altern(updown(1))(height)(border)
    return fence()
end))

rawset(_G, 'box', curry(6, function (leftright, width, length, updown, height, work)
    local updown1 = updown(1)
    local turnH = function () return turn(leftright)() end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local girder = x1(turnH, altern(forw1)(width)(work),revH,turnH)
    local board = altern(forw1)(length)(girder)
    local border = x2(x(length-1)(work,forw1),turnH,x(width-1)(work,forw1),turnH)
    local fence = altern(updown1)(height-2)(border)
    local box = x1(board,turnH,turnH,revH,updown1,fence,updown1,board)
    return box()
end))

rawset(_G, 'building', curry(7, function (leftright, width, length, updown, height, work, floors)
    local updown1 = updown(1)
    local turnH = function () return turn(leftright)() end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local girder = x1(turnH, altern(forw1)(width)(work), revH, turnH)
    local board = altern(forw1)(length)(girder)
    local border = x2(x(length-1)(work,forw1),turnH,x(width-1)(work,forw1),turnH)
    local fence = altern(updown1)(height-2)(border)
    local box = x1(board,turnH,turnH,revH,updown(1),fence,updown1,board)
    local nextBox = x1(turnH,turnH,revH,updown1)
    local building = altern(nextBox)(floors)(box)
    return building()
end))

rawset(_G, 'aisle', curry(7, function (leftright, width, updown, height, workDown, workUp, length)
    local turnH = function () return turn(leftright)() end
    local turnV = function () return updown(height)() end
    local work; if (updown == up) then work = workDown else work = workUp end
    local revH = function () if leftright == left then leftright = right else leftright = left end end
    local revV = function () if (updown == up) then updown = down; work = workUp else updown = up; work = workDown end end
    local dowork = function () return work() end
    local column = x1(dowork,turnV,revV,dowork)
    local wall = altern(forw1)(length)(column)
    local nextWall = x1(turnH,forw1,turnH,revH)
    local aisle = altern(nextWall)(width)(wall)
    return aisle()
end))


