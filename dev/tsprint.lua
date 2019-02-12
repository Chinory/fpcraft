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

local function tsprint (value)
    local visited = {}
    local strings = {}
    local setter = {}
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
                    local kType == type(key)
                    if kType ~= 'number' or math.floor(key) ~= key or key < 1 or key > maxIndex then
                        if kType == 'string' and match(key, '^[%a_][%w_]*$') then
                            insert(strings, key)
                        elseif kType == 'table' and visited[table] then
                            
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
                return
            end
        elseif vType == 'number' or vType == 'boolean' then
            insert(strings, tostring(value))
        elseif vType == 'string' then
            insert(strings, strvalue(value))
        else
            insert(strings, '"')
            insert(strings, tostring(value))
            insert(strings, '"')
        end
    end
    insertValue(value)
    return joinTable(strings)
end