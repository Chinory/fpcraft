local managed = setmetatable({}, {__mode = "v"})

local Timer = {}

function Timer.start(self)
  local id = self.timerID
  if id == nil then
    id = os.startTimer(self.interval)
    managed[id] = self
    self.timerID = id
  end
  return self
end

function Timer.stop(self)
  local id = self.timerID
  if managed[id] == self then
    os.cancelTimer(id)
    managed[id] = nil
    self.timerID = nil
  end
  return self
end

function Timer.emit(self)
  local id = self.timerID
  if managed[id] == self then
    os.cancelTimer(id)
    managed[id] = nil
    self.timerID = nil
    self:ontimer()
  end
  return self
end

function Timer.skip(self)
  local id = self.timerID
  if managed[id] == self then
    os.cancelTimer(id)
    id = os.startTimer(self.interval)
    managed[id] = self
    self.timerID = id
  end
  return self
end

local mt = {__index = Timer}

local M = {}

function M.new(obj) return setmetatable(obj, mt) end

function M.start(obj) return Timer.start(setmetatable(obj, mt)) end

function M.main()
  while true do
    local _, id = os.pullEvent("timer")
    local self = managed[id]
    if self then
      self.timerID = nil
      managed[id] = nil
      self:ontimer()
      -- if self:ontimer() then
      --   id = os.startTimer(self.interval)
      --   managed[id] = self
      --   self.timerID = id
      -- end
    end
  end
end

return M
