local managed = {}

local function stop(self)
  local id = self.timerId
  if id ~= nil then
    os.cancelTimer(id)
    managed[id] = nil
    self.timerId = nil
  end
end

local function start(self)
  local id = os.startTimer(self.timerIv)
  managed[id] = self
  self.timerId = id
end

local M = {of = managed}

function M.stop(self)
  stop(self)
  return self
end

function M.start(self)
  stop(self)
  start(self)
  return self
end

function M.ensure(self)
  if self.timerId == nil then
    start(self)
  end
  return self
end

function M.main()
  while true do
    local _, id = os.pullEvent("timer")
    local self = managed[id]
    if self then
      managed[id] = nil
      self:timerFn() --foreign
    end
  end
end

return M
