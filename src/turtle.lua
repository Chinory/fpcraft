local function fake(s) return function() return false, s end end
return turtle or setmetatable({fake = true}, {
  __index = function(_, k) return fake("turtle." .. k .. "()") end
})
