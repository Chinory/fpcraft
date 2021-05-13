return turtle or setmetatable({fake = true}, {
  __mode = "v",
  __index = function(t, k)
    local v = function() print("turtle." .. k .. "()") return true, "fake" end
    t[k] = v
    return v
  end
})
