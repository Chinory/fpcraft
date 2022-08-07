local tui = require("tui")
local utils = require("utils")
local timer = require("timer")
local proc = require("proc")
local enc = string.char
local dec = string.byte
local sub = string.sub
local gmatch = string.gmatch
local unpack = table.unpack
local insert = table.insert
local remove = table.remove
local concat = table.concat
local random = math.random
local floor = math.floor
local bxor = bit32.bxor

------- Clock ----------------------------------

local gtime = os.time
local clock = os.clock
local epoch0 = os.epoch
local EPOCH = 1659705738556
local function epoch() return epoch0("utc") - EPOCH end

------- Crypto ------------------------------

local CRC = {}
for i = 0, 255 do
  local x = i
  for _ = 1, 8 do
    if x % 2 == 0 then
      x = x / 2
    else
      x = bxor(x / 2, 0xEDB88320)
    end
  end
  CRC[i + 1] = x
end

local function crc(sum, b) --
  return bxor(sum / 256, CRC[bxor(sum % 256, b) + 1])
end

local function crc32n_str(sum, str)
  for p = 1, #str do sum = crc(sum, dec(str, p)) end
  return sum
end

local function crc32n_buf(sum, buf)
  for i = 1, #buf do sum = crc(sum, buf[i]) end
  return sum
end

local function crc32n0_cww(a, b, c)
  return crc(crc(crc(crc(CRC[a + 1], b / 256), b % 256), c / 256), c % 256)
end

local function rc4_new(key)
  local ks = {0, 0, 0, 1, 2, 3, 4, 5, 6}
  for i = 7, 255 do ks[i + 3] = i end
  local j, len = 0, #key
  for i = 0, 255 do
    j = (j + ks[i + 3] + dec(key, i % len + 1)) % 256
    ks[i + 3], ks[j + 3] = ks[j + 3], ks[i + 3]
  end
  return ks
end

local function rc4_load(str) return {dec(str, 1, 258)} end

local function rc4_save(ks) return enc(unpack(ks)) end

local function rc4_crypt(ks, buf)
  local x, y = ks[1], ks[2]
  local a, b
  for i = 1, #buf do
    x = (x + 1) % 256
    a = ks[x + 3]
    y = (y + a) % 256
    b = ks[y + 3]
    ks[y + 3], ks[x + 3] = a, b
    buf[i] = bxor(ks[(a + b) % 256 + 3], buf[i])
  end
  ks[1], ks[2] = x, y
  return buf
end

local function rc4_crypt_str(ks, str)
  return enc(unpack(rc4_crypt(ks, {dec(str, 1, #str)})))
end

local function rc4_crypt_str2num(ks, str, i, j)
  local num = 0
  local x, y = ks[1], ks[2]
  local a, b
  for p = i, j do
    x = (x + 1) % 256
    a = ks[x + 3]
    y = (y + a) % 256
    b = ks[y + 3]
    ks[y + 3], ks[x + 3] = a, b
    num = num * 256 + bxor(ks[(a + b) % 256 + 3], dec(str, p))
  end
  ks[1], ks[2] = x, y
  return num
end

local function rc4_crypt_byte(ks, byte)
  local x = (ks[1] + 1) % 256
  local a = ks[x + 3]
  local y = (ks[2] + a) % 256
  local b = ks[y + 3]
  ks[1], ks[2], ks[y + 3], ks[x + 3] = x, y, a, b
  return bxor(ks[(a + b) % 256 + 3], byte)
end

------- Convert ---------------------------------

local function u32dec(s,i,j)
  local a, b, c, d = dec(s, i, j)
  return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
end

local function u32enc(x)
  local d = x % 256
  x = (x - d) / 256
  local c = x % 256
  x = (x - c) / 256
  local b = x % 256
  x = (x - b) / 256
  return enc(x % 256, b, c, d)
end

local function u16dec(s,i,j)
  local a, b = dec(s, i, j)
  return a * 0x100 + b
end

local function u16enc(x)
  local b = x % 256
  x = (x - b) / 256
  return enc(x % 256, b)
end

------- Random ----------------------------------

local function nonce32() return floor(random() * 0xFFFFFFFF) end

local function randstr3()
  local x = random(0, 0xFFFFFF)
  local c = x % 256
  x = (x - c) / 256
  local b = x % 256
  x = (x - b) / 256
  return enc(x % 256, b, c)
end

------- Identity --------------------------------

local function token32(id) return id % 256 * 0x1000000 + random(0, 0xFFFFFF) end

------- Constants -----------------------------

local WEP_DTG = 0x10

local WEP_LNK = 0x20

local PLAIN1 = 0x30

------- Base ------------------------------------

local managed = setmetatable({}, {__mode = "v"})

local function wep_pkg(mode, name, ks, cls, ch, rch, body)
  local a, d, c, b
  a = crc32n0_cww(cls, ch, rch)
  if body then a = crc32n_str(a, body) end
  d = a % 256
  a = (a - d) / 256
  c = a % 256
  a = (a - c) / 256
  b = a % 256
  a = (a - b) / 256
  local cmac = enc(unpack(rc4_crypt(ks, {a, b, c, d, cls})))
  body = body and rc4_crypt_str(ks, body) or ""
  return enc(mode + #name) .. name .. cmac .. body
end

local function pub_pkg(name, cls, body)
  return enc(PLAIN1 + #name) .. name .. enc(cls) .. (body or '')
end

------- Prototype ----------------------------------

local mt_Msg = {
  __newindex = function(t, k, v)
    local i = #t + 1
    rawset(t, k, i)
    rawset(t, i, v)
  end,
  __tostring = function(t)
    local list = {}
    for i, v in ipairs(t) do list[i] = v.name end
    return "{" .. concat(list, ",") .. "}"
  end
}

local Lnk = setmetatable({}, mt_Msg)
local Dtg = setmetatable({}, mt_Msg)
local Pub  = setmetatable({}, mt_Msg)
local Net = {lnk = Lnk, dtg = Dtg, pub = Pub, chid = utils.id, idch = utils.id, reportAge = 0.25}

local mt_Net = {
  __index = Net,
  __tostring = function(self) return "Net{" .. self.name .. "}" end,
  __call = function(self, ...) return self:tel(...) end
}

function Net.post(self, ch, cls, body)
  local rch = self.mych
  local ks = rc4_new(self.key)
  local pkg = wep_pkg(WEP_DTG, self.name, ks, cls, ch, rch, body)
  self.hws(ch, rch, pkg)
end

function Net.send(self, id, cls, body)
  local tch = self.idch(id)
  local mch = self.mych
  local kss = self.kstx[id]
  if not kss then return end
  local ks = rc4_load(kss)
  local pkg = wep_pkg(WEP_LNK, self.name, ks, cls, tch, mch, body)
  self.kstx[id] = rc4_save(ks)
  self.hws(tch, mch, pkg)
end

function Net.sendAll(self, cls, body)
  local mch = self.mych
  local kstx = self.kstx
  local hws = self.hws
  for id, kss in pairs(kstx) do
    local tch = self.idch(id)
    local ks = rc4_load(kss)
    local pkg = wep_pkg(WEP_LNK, self.name, ks, cls, tch, mch, body)
    kstx[id] = rc4_save(ks)
    hws(tch, mch, pkg)
  end
end

function Net.sendEach(self, cls, Body)
  local mch = self.mych
  local kstx = self.kstx
  local hws = self.hws
  for id, kss in pairs(kstx) do
    local body = Body(id)
    local tch = self.idch(id)
    local ks = rc4_load(kss)
    local pkg = wep_pkg(WEP_LNK, self.name, ks, cls, tch, mch, body)
    kstx[id] = rc4_save(ks)
    hws(tch, mch, pkg)
  end
end

------- ConnReq Sender -------------------------------------

local function lnrq_tmo(self)
  local tbl = self.net.lnrq
  local key = self.tkpubl
  if tbl[key] == self then
    tbl[key] = nil
    self.net:log("Conn End " .. self.time)
  end
end

-- @param tmo_ms default 9000, max 65535
function Net.connect(self, ch, tmo_ms)
  ch = ch or 65535
  tmo_ms = tmo_ms or 9000

  local tkpubl = token32(self.id)
  while self.lnrq[tkpubl] do tkpubl = tkpubl + 1 end

  local now = floor(gtime() * 1000)
  self.lnrq[tkpubl] = timer.start({
    timerFn = lnrq_tmo,
    timerIv = tmo_ms / 1000,
    net = self,
    ch = ch,
    tkpubl = tkpubl,
    clock = clock(),
    time = now
  })

  self:post(ch, self.dtg.ConnReq, u32enc(tkpubl) .. u32enc(epoch()) .. u16enc(tmo_ms))
  self:log("Conn Start " .. now)
  return tkpubl
end

------- ConnReq Handler -------------------------------------

local function lnrs_tmo(self)
  local tbl = self.net.lnrs
  local key = self.id
  if tbl[key] == self then
    tbl[key] = nil
    self.net:log("Conn From " .. self.id .. " Expr")
  end
end

function Dtg.ConnReq(self, id, body)
  if #body ~= 10 then return end

  local peer = self.peer[id]
  if peer == false then return end

  local time = u32dec(body, 5, 8)
  local duration = epoch() - time
  if duration < 0 then return end

  local tmo_ms = u16dec(body, 9, 10)
  local rem_ms = tmo_ms - duration
  if rem_ms < 0 then return end

  local old = self.lnrs[id]
  if old then
    if old.accepted ~= nil or old.time >= time then return end
    timer.stop(old)
  end

  local rem_s = rem_ms / 1000
  self.lnrs[id] = timer.start({
    timerFn = lnrs_tmo,
    timerIv = rem_s,
    net = self,
    id = id,
    time = time,
    expire = clock() + rem_s,
    tkpubl = u32dec(body, 1, 4)
  })

  if peer then
    self:accept(id)
  else
    self:report("Conn From @", id, 1)
  end
end


------- ConnAcpt Sender --------------------------------------

function Net.accept(self, id)
  local res = self.lnrs[id]
  if not res then return end

  if not res.accepted then
    timer.stop(res)
    local now = clock()
    local rtt = (res.expire - now) * 2
    res.timerIv = rtt
    res.expire = now + rtt
    res.tkpriv = token32(self.id)
    res.accepted = true
    timer.start(res)
  end

  self:post(self.idch(id), self.dtg.ConnAcpt, u32enc(res.tkpubl) .. u32enc(res.tkpriv))
end

------- ConnAcpt Handler -------------------------------------

function Dtg.ConnAcpt(self, id, body, dist)
  if #body ~= 8 then return end
  if self.seen[id] then return end

  local tkpubl = u32dec(body, 1, 4)
  local lnrq = self.lnrq[tkpubl]
  if not lnrq then return end

  local tch = self.idch(id)
  local mch = self.mych
  local res = u32enc(nonce32()) .. sub(body, 5, 8)
  local ks0 = rc4_new(self.key)
  local pkg = wep_pkg(WEP_DTG, self.name, ks0, self.dtg.ConnEstb, tch, mch, res)
  local kss = rc4_save(ks0)
  self.ksrx[id] = kss
  self.kstx[id] = kss
  self.seen[id] = clock()
  self.dist[id] = dist

  self.hws(tch, mch, pkg)

  self:report("Conn Acpt @", id, 1)

  return self:onConnected(id)
end

------- ConnEstb Handler ----------------------------------

function Dtg.ConnEstb(self, id, body, dist, ksrx)
  if #body < 8 or #body > 262 then return end
  local res = self.lnrs[id]
  if not res or not res.accepted then return end

  local tkpriv = u32dec(body, 5, 8)
  if tkpriv ~= res.tkpriv then return end

  timer.stop(res)
  self.lnrs[id] = nil

  local kss = rc4_save(ksrx)
  self.ksrx[id] = kss
  self.kstx[id] = kss
  self.seen[id] = clock()
  self.dist[id] = dist

  self:report("Conn Estb @", id, 1)

  return self:onConnected(id)
end

------- ConnClose Sender -------------------------------------

function Net.kill(self, id)
  self.kstx[id] = nil
  self.ksrx[id] = nil
  self.seen[id] = nil
  self.dist[id] = nil
  self.watcher[id] = nil
  self.watchee[id] = nil
end

local function byebye(self, id, kss)
  local ks = rc4_load(kss)
  local tch = self.idch(id)
  local mch = self.mych
  local pkg = wep_pkg(WEP_LNK, self.name, ks, self.lnk.ConnClose, tch, mch)
  self.hws(tch, mch, pkg)
end

function Net.close(self, id)
  local kss = self.kstx[id]
  self:kill(id)
  if kss then byebye(self, id, kss) end
end

function Net.closeAll(self)
  local kstx = self.kstx
  self.kstx = {}
  for id, kss in pairs(kstx) do
    self:kill(id)
    byebye(self, id, kss)
  end
end

------- ConnClose Handler ------------------------------------


function Lnk.ConnClose(self, id)
  self:report("Conn Close @", id, 1)
  self:kill(id)
end

------- ConnAlive Sender -----------------------------------

function Net.hint(self, id)
  self:send(id, self.lnk.ConnAlive, randstr3())
end

function Net.claim(self)
  self:sendEach(self.lnk.ConnAlive, randstr3)
end


------- Ack Sender ----------------------------------

local function waiter_timer(t)

end

function Net.wait(self, id, cmac)
  timer.ensure(self.waiter)
  local _, ok = os.pullEvent(cmac) -- unsafe perf trick
  return ok
end

function Net.ack(self, id, cmac)
  self:send(id, self.lnk.Ack, cmac)
end

------- Ack Handler ----------------------------------

function Lnk.Ack(self, id, cmac)
  os.queueEvent(cmac)
end

------- ConnAlive Handler ----------------------------------

function Lnk.ConnAlive() end

------- ConnCheck Sender -----------------------------------

function Net.check(self, id)
  self:send(id, self.lnk.ConnCheck)
end

------- ConnCheck Handler ----------------------------------

function Lnk.ConnCheck(self, id)
  self:hint(id)
end

------- Command Sender ------------------------------------

local function sendCmd(self, code, ids)
  local cnt = self.cmdcnt + 1
  local usedCode =  sub(code,-1) == ')' and 'return ' .. code or code -- function tricks
  local body = u16enc(cnt) .. usedCode
  for _, id in ipairs(ids) do --
    self:send(id, self.lnk.CmdReq, body)
  end
  self.cmdcnt = cnt
  self.cmdhist[cnt] = code
  return cnt
end

Net.sendCmd = sendCmd

function Net.cmd(self, code, ids)
  if ids == nil then
    ids = utils.keys(self.seen)
  elseif type(ids) == "number" then
    ids = {ids}
  elseif type(ids) ~= "table" then
    return nil, "bad ids type"
  end
  return sendCmd(self, code, ids)
end

-- Remote Term
function Net.tel(self, ...)
  local ids = {...}
  if #ids == 0 then
    ids = utils.keys(self.seen)
  end
  table.sort(ids)
  local prefix = '\24' .. utils.prettySortedInts(ids) .. ">"
  while true do
    local code = tui.read(prefix, nil, self.cmdhist, tui.completeLua)
    if code == "" then break end
    sendCmd(self, code, ids)
  end
end

-- SSH toy
function Net.ssh(self, ...)
  local ids = {...}
  if #ids == 0 then
    ids = utils.keys(self.seen)
  end
  local prefix
  if #ids == 1 then
    prefix = '\18' .. ids[1] .. '>'
    self:watchCat(ids[1])
  else
    table.sort(ids)
    prefix = '\18' .. utils.prettySortedInts(ids) .. '>'
    self:watch(unpack(ids))
  end
  while true do
    local code = tui.read(prefix, nil, self.cmdhist, tui.completeLua)
    if code == "" then break end
    sendCmd(self, code, ids)
  end
  self:unwatch(unpack(ids))
end

------- Command Handler -----------------------------------

local function createCmdTask(self, id, cid, code)
  return proc.create(function()
    local fn, rex = loadstring(code)
    local status, result
    if fn then
      ez.l = self
      local res = {pcall(setfenv(fn, ez))}
      ez.l = nil
      if remove(res, 1) then
        status = '\1'
        result = utils.ser(res)
      else
        status = '\2'
        result = res[1] or '?'
      end
    else
      status = '\3'
      result = rex
    end
    self:send(id, self.lnk.CmdRes, u16enc(cid) .. status .. result)
  end)
end

function Lnk.CmdReq(self, id, body)
  if #body < 2 then return end
  local cid = u16dec(body, 1, 2)
  local code = sub(body, 3)
  createCmdTask(self, id, cid, code)
  -- os.queueEvent()
  self:send(id, self.lnk.CmdAck, u16enc(cid))
end

function Lnk.CmdAck(self, id, body)
  if #body ~= 2 then return end
  local cid = u16dec(body,1,2)
  self.cmdack[id] = cid
end

local CMDRES_ST = {"OK","Err","Bad"}

function Lnk.CmdRes(self, id, body)
  if #body < 3 then return end
  local cid = u16dec(body, 1, 2)
  local status = CMDRES_ST[dec(body,3,3)] or "Unk"
  local result = sub(body, 4)
  self:report('$'..cid..' '..status..' '..result.." @", id)
end


------- Log Sender ------------------------------------

function Net.log(self, log)
  local t = self.logs
  if #t > 15 then remove(t, 1) end
  log = tostring(log)
  insert(t, log)
  for id in pairs(self.watcher) do
    self:send(id, self.lnk.LogData, log)
  end
  if self.showlog then
    tui.print('\7'..self.id..' '..log)
  end
end

function Net.report(self, s, it, age)
  tui.report(s, it, age or self.reportAge, self, self.log)
end

local function printLogs(self, id)
  local pre = '\7'..id..' '
  for _, log in ipairs(self.logs) do
    tui.print(pre..log)
  end
end

function Net.cat(self, id)
  if id == nil then
    printLogs(self, self.id)
  elseif id == self.id then
    printLogs(self, id)
  else
    self:send(id, self.lnk.LogCat)
  end
end

function Net.watch(self, ...)
  local watchee = self.watchee
  local msg = self.lnk.LogWatch
  for _, id in ipairs({...}) do
    local n = watchee[id]
    if n == nil then
      watchee[id] = 1
      self:send(id, msg)
    else
      watchee[id] = n + 1
    end
  end
end

function Net.watchCat(self, id)
  local watchee = self.watchee
  watchee[id] = (watchee[id] or 0) + 1
  self:send(id, self.lnk.LogWatchCat)
end

function Net.unwatch(self, ...)
  local watchee = self.watchee
  local msg = self.lnk.LogUnwatch
  for _, id in ipairs({...}) do
    local n = watchee[id]
    if n then
      if n > 1 then
        watchee[id] = n - 1
      else
        watchee[id] = nil
        self:send(id, msg)
      end
    end
  end
end

function Net.unwatchAll(self)
  local watchee = self.watchee
  local msg = self.lnk.LogUnwatch
  for id in pairs(watchee) do
    watchee[id] = nil
    self:send(id, msg)
  end
end

------- Log Handler -----------------------------------

function Lnk.LogData(self, id, body)
  local pre = '\25'..id..' '
  for log in gmatch(body, '[^\0]+') do
    tui.print(pre..log)
  end
end

function Lnk.LogCat(self, id)
  self:send(id, self.lnk.LogData, concat(self.logs, '\0'))
end

function Lnk.LogWatch(self, id)
  self.watcher[id] = true
end

function Lnk.LogWatchCat(self, id)
  self.watcher[id] = true
  self:send(id, self.lnk.LogData, concat(self.logs, '\0'))
end

function Lnk.LogUnwatch(self, id)
  self.watcher[id] = nil
end

------- Ping Sender ------------------------------------

function Net.public(self, id, cls, body)
  local pkg = pub_pkg(self.name, cls, body)
  self.hws(self.idch(id), self.mych, pkg)
end

function Net.ping(self, id, body)
  self:public(id, self.pub.Ping, body)
end

function Pub.Ping(self, id, body)
  self:log('Ping @'..id..' '..body)
  self:public(id, self.pub.Pong, body)
end

function Pub.Pong(self, id, body)
  self:log('Pong @'..id..' '..body)
end

----------------- Exports ----------------------------------

local function checker_timer(t)
  local now = clock()
  local self = t.net
  for id, time in pairs(self.seen) do
    time = now - time
    if time > t.closeTime then
      self:report("Conn Lost @", id)
      self:close(id)
    elseif time > t.checkTime then
      self:check(id)
    end
  end
  timer.start(t)
end

-- local function finder_timer(t)
--   local self = t.net
--   for _, id in ipairs(t.ids) do
--     if not self.seen[id] and id ~= self.id then self:connect(id) end
--   end
--   timer.start(t)
-- end

local function FakeTransmit(name) --
  return function(...)
    error('fake transmit from ' .. name .. ' ' .. utils.ser({...}), 2)
  end
end

local M = {Net = Net, Lnk = Lnk, Dtg = Dtg, Pub = Pub, of = managed}

function M.cloneMsg(self)
  return setmetatable(utils.assign({}, self), mt_Msg)
end

function M.newNet(name, key, hw)
  if managed[name] then return nil, "Net existed" end
  if hw == nil then
    hw = peripheral.find("modem", peripheral.wrap)
  elseif type(hw) == "string" then
    hw = peripheral.wrap(hw)
  end
  local hws
  if type(hw) == "table" then
    hws = hw.transmit
    if type(hws) ~= "function" then --
      hws = FakeTransmit(name)
      hw = {fake = true}
    end
  else
    hws = FakeTransmit(name)
    hw = {fake = true}
  end
  -- create the net object
  local self = {
    -- core:hardware
    hw = hw,
    hws = hws,
    -- core:crypt
    kstx = {},
    ksrx = {},
    -- core:net
    lnrq = {},
    lnrs = {},
    -- config
    name = name,
    key = key,
    id = ID,
    onConnected = utils.asEvent({}),
    -- peers
    peer = {}, -- `nil`:manul, `false`:block, `*`:auto accept
    seen = {},
    dist = {},
    -- logs
    logs = {},
    showlog = false,
    watcher = {},
    watchee = {},
    -- command
    cmdcnt = 0,
    cmdack = {},
    cmdhist = {},
    -- fast access
    mych = Net.idch(ID)
  }
  self.checker = timer.start({
    timerFn = checker_timer,
    timerIv = 2,
    checkTime = 6,
    closeTime = 12,
    net = self
  })
  self.waiter = {
    timerFn = waiter_timer,
    timerIv = 0.05, --1 tick
    net = self
  }
  -- self.finder = timer.start({
  --   timerFn = finder_timer,
  --   timerIv = 10,
  --   ids = {},
  --   net = self
  -- })
  setmetatable(self, mt_Net)
  managed[name] = self
  return self
end

local function recvConn(handle, net, id, body)
  local ok, err = pcall(handle, net, id, body)
  if not ok then
    net:close(id)
    net:log("\19 Msg@" .. id .. " " .. body .. " " .. err)
  end
end

-- [(m*16+n):1][name:n][crypt([sum(cls,lch,rch,body):4][cls:1][body])]
local function receive()
  local lch, rch, pkg, dist, net, m, n
  while true do
    _, _, lch, rch, pkg, dist = os.pullEvent("modem_message")
    if type(pkg) == "string" then
      m = dec(pkg, 1)
      n = m % 16
      net = managed[sub(pkg, 2, n + 1)]
      if net then
        m = m - n
        n = n + 2
        break
      end
    end
    pkg = nil
  end
  local id = net.chid(rch)
  local ks, msg
  if m == WEP_LNK then
    ks = net.ksrx[id] -- kss
    if not ks then return end
    ks = rc4_load(ks)
    msg = net.lnk
  elseif m == WEP_DTG then
    ks = rc4_new(net.key)
    msg = net.dtg
  elseif m == PLAIN1 then
    if #pkg < n then return end
    local handle = net.pub[dec(pkg, n)]
    if not handle then return end
    return pcall(handle, net, id, sub(pkg, n + 1))
  else
    return
  end
  local ci = n + 4
  local len = #pkg - ci
  if len < 0 then return end
  local sum = rc4_crypt_str2num(ks, pkg, n, n + 3)
  local cls = rc4_crypt_byte(ks, dec(pkg, ci))
  local handle = msg[cls]
  if not handle then return end
  local body = rc4_crypt(ks, {dec(pkg, ci + 1, #pkg)})
  if crc32n_buf(crc32n0_cww(cls, lch, rch), body) == sum then
    if m == WEP_LNK then
      net.seen[id] = clock()
      net.dist[id] = dist
      net.ksrx[id] = rc4_save(ks)
      return recvConn(handle, net, id, enc(unpack(body)))
    end
    return pcall(handle, net, id, enc(unpack(body)), dist, ks)
  end
end

function M.main() while true do receive() end end

return M
