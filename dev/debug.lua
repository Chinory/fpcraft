-- debug api
if turtle == nil then turtle = {
    turnLeft = function () print('turtle.turnLeft'); return true end,
    turnRight = function () print('turtle.turnRight'); return true end,
    forw = function () print('turtle.forw'); return true end,
    up = function () print('turtle.up'); return true end,
    down = function () print('turtle.down'); return true end,
    attack = function () print('turtle.attack'); return true end,
    attackUp = function () print('turtle.attackUp'); return true end,
    attackDown = function () print('turtle.attackDown'); return true end,
    dig = function () print('turtle.dig'); return true end,
    digUp = function () print('turtle.digUp'); return true end,
    digDown = function () print('turtle.digDown'); return true end,
    place = function () print('turtle.place'); return true end,
    placeUp = function () print('turtle.placeUp'); return true end,
    placeDown = function () print('turtle.placeDown'); return true end,
    drop = function () print('turtle.drop'); return true end,
    dropUp = function () print('turtle.dropUp'); return true end,
    dropDown = function () print('turtle.dropDown'); return true end,
    suck = function () print('turtle.suck'); return true end,
    suckUp = function () print('turtle.suckUp'); return true end,
    suckDown = function () print('turtle.suckDown'); return true end,
    detect = function () print('turtle.detect'); return false end,
    detectUp = function () print('turtle.detectUp'); return false end,
    detectDown = function () print('turtle.detectDown'); return false end,
    inspect = function () print('turtle.inspect'); return true, { state={variant="stone"}, name="minecraft:stone", metadata=0 } end,
    inspectUp = function () print('turtle.inspectUp'); return true, { state={variant="stone"}, name="minecraft:stone", metadata=0 } end,
    inspectDown = function () print('turtle.inspectDown'); return true, { state={variant="stone"}, name="minecraft:stone", metadata=0 } end,
    getFuelLevel = function () return 10 end,
} end

local unpack = table.unpack or unpack
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local concatTable = table.concat

local function tsprint (value)
    local visited = {}
    local strings = {}
    local function insertValue (value)
        local vType = type(value)
        if vType == 'table' then
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
                        insert(strings, key)
                        insert(strings, '=')
                        insertValue(value)
                        insert(strings, ",")
                    end
                end
                if strings[#strings] ~= '{' then strings[#strings] = '}'
                else insert(strings, '}') end
                return
            end
        elseif vType == 'number' or vType == 'boolean' then
            insert(strings, tostring(value))
        else
            insert(strings, '"')
            insert(strings, tostring(value))
            insert(strings, '"')
        end
    end
    insertValue(value)
    return concatTable(strings)
end

local function tprint (value)
    return print(tsprint(value))
end

local function cut (n, ...)
    local ret = {}
    for i = 1, n, 1 do table.insert(ret, 1) end
    print(select(-2, ...))
    return ret
end

