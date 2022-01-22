local managed = {}

local M = {of = managed}

function M.start(self)
  local id = self.timerId
  if not id then
    id = os.startTimer(self.timerIv)
    managed[id] = self
    self.timerId = id
  end
  return self
end

function M.stop(self)
  local id = self.timerId
  if managed[id] == self then
    os.cancelTimer(id)
    managed[id] = nil
    self.timerId = nil
  end
  return self
end

function M.emit(self)
  local id = self.timerId
  if managed[id] == self then
    os.cancelTimer(id)
    managed[id] = nil
    self.timerId = nil
    self:timerFn()
  end
  return self
end

function M.skip(self)
  local id = self.timerId
  if managed[id] == self then
    os.cancelTimer(id)
    id = os.startTimer(self.timerIv)
    managed[id] = self
    self.timerId = id
  end
  return self
end

local function once(self)
  self:timerFn()
  if self.timerFn then
    local id = os.startTimer(self.timerIv)
    managed[id] = self
    return id
  end
end

function M.main()
  while true do
    local _, id = os.pullEvent("timer")
    local self = managed[id]
    if self then
      managed[id] = nil
      _, self.timerId = pcall(once, self)
    end
  end
end

return M
