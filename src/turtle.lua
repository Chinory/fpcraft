local function fake(s) return function() error(s) end end
return turtle or setmetatable({fake = true}, {
  __index = function(_, k) return fake("fake turtle." .. k .. "()") end
})
