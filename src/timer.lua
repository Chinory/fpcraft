local managed = {}

local M = {of = managed}

function M.stop(self)
  local id = self.timerId
  if id then
    os.cancelTimer(id)
    managed[id] = nil
    self.timerId = nil
  end
end

function M.once(self)
  local id = os.startTimer(self.timerIv)
  managed[id] = self
  self.timerId = id
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
