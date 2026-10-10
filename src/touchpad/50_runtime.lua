-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: runtime (Q adapters, engine, picker binding, gestures, frames, modes)
--
-- `Q` is the only table that knows Q-SYS names (spec sections 6, 12 and 14).
-- The engine after `if Controls then` talks to Q, to the pure modules (U,
-- Font, Svg, Shapes) and to the mode instance returned by
-- Modes[mode].create(E). Every handler runs inside a guard: an error shows
-- "Recovered from an error: ..." on Status and the next touch still works.
--
-- Mode instance methods (all optional except draw): onTouchStart(x, y, t),
-- onTouchMove(x, y, t, dx, dy), onTouchEnd(x, y, t, info), onTouchResume(x, y, t),
-- onGesture(g), draw(canvas), onControl(name, index, ctl), tick(dt),
-- onLock(locked), onStart(); drawCamera(canvas) is a hook for the Camera View.
-- Every onTouchStart is followed by exactly one onTouchEnd: a touch the
-- engine has to abandon (lock, rebind, calibration, a clock step) ends with
-- info.aborted = true (info.reason names the cause) and no gesture.

Q = Q or {}
NikitaTimers = NikitaTimers or {}     -- timer objects live here so they are never collected

-- The concatenated plugin shares one main-function scope, which Lua caps at 200
-- active locals; the adapters and the engine therefore run in their own functions.
(function()
local floor, sqrt, abs, min, max = math.floor, math.sqrt, math.abs, math.min, math.max
local sfind, ssub, smatch, lower, sformat = string.find, string.sub, string.match, string.lower, string.format
local sbyte, sgsub = string.byte, string.gsub
local concat = table.concat

-- ================================================================ Q adapters

-- The engine replaces this with its error guard so that every callback a
-- Q adapter fires later (HTTP replies, socket data) is protected too.
function Q.guard(label, fn) return fn end

-- ---------- time ----------
local CLOCK = { useTimer = nil, value = 0 }

-- Probes Timer.Now once; without a numeric answer an engine-owned clock
-- advanced by a 0.02 s timer takes over (spec 14.5).
function Q.probeClock()
  if CLOCK.useTimer ~= nil then return CLOCK.useTimer end
  local ok, t = pcall(function() return Timer.Now() end)
  CLOCK.useTimer = ok and type(t) == "number"
  if not CLOCK.useTimer then
    local okT, timer = pcall(Timer.New)
    if okT and timer then
      NikitaTimers.clock = timer
      timer.EventHandler = function() CLOCK.value = CLOCK.value + 0.02 end
      pcall(function() timer:Start(0.02) end)
    end
  end
  return CLOCK.useTimer
end

function Q.now()
  if CLOCK.useTimer == nil then Q.probeClock() end
  if CLOCK.useTimer then
    local ok, t = pcall(Timer.Now)
    if ok and type(t) == "number" then return t end
  end
  return CLOCK.value
end

-- One-shot timer; handle:cancel() stops a pending call.
function Q.after(seconds, fn)
  local h = { active = true }
  function h.cancel(self) self.active = false end
  seconds = tonumber(seconds) or 0
  if seconds < 0 then seconds = 0 end
  Timer.CallAfter(function()
    if h.active then
      h.active = false
      fn()
    end
  end, seconds)
  return h
end

-- Repeating timer; handle:cancel() stops it and releases the object.
function Q.every(seconds, fn)
  local t = Timer.New()
  local h = { active = true, timer = t }
  t.EventHandler = function()
    if h.active then fn() end
  end
  NikitaTimers[t] = h
  function h.cancel(self)
    if self.active then
      self.active = false
      pcall(function() t:Stop() end)
      NikitaTimers[t] = nil
    end
  end
  t:Start(seconds)
  return h
end

-- ---------- icon on a button (spec 12.1, 14.6) ----------
-- The drawing buttons stay disabled (touches pass through to the picker).
function Q.disable(ctl)
  pcall(function() ctl.IsDisabled = true end)
end

function Q.setIcon(ctl, svg, channel)
  local data = Q.base64(svg)
  if channel == "Style" then
    ctl.Style = '{"DrawChrome":false,"IconData":"' .. data .. '","Legend":""}'
  else
    ctl.Legend = '{"DrawChrome":false,"IconData":"' .. data .. '"}'
  end
  Q.disable(ctl)
end

function Q.clearIcon(ctl, channel)
  if channel == "Style" then
    ctl.Style = '{"DrawChrome":false,"Legend":""}'
  else
    ctl.Legend = '{"DrawChrome":false}'
  end
  Q.disable(ctl)
end

-- A trigger pulses by going true then false (spec 12.6).
function Q.pulse(ctl)
  ctl.Boolean = true
  ctl.Boolean = false
end

-- ---------- components (spec 12.4, 14.2) ----------
local LIST_CAP = 2048

-- Component.GetControls entries ({Name = ...}) in pcall; {} when unavailable.
-- `cap` bounds the entries copied (a 64 x 64 mixer lists thousands).
function Q.controlList(name, cap)
  local out = {}
  local ok, list = pcall(Component.GetControls, name)
  if not ok or type(list) ~= "table" then return out end
  for i = 1, min(#list, cap or LIST_CAP) do
    local e = list[i]
    if type(e) == "table" then out[#out + 1] = e end
  end
  return out
end

-- Component.New in pcall; nil when missing (not ok, nil, an empty table or
-- a component without readable controls).
function Q.component(name)
  if type(name) ~= "string" or name == "" then return nil end
  local ok, comp = pcall(Component.New, name)
  if not ok or comp == nil then return nil end
  local okn, empty = pcall(function() return next(comp) == nil end)
  if okn and empty then
    if #Q.controlList(name, 1) == 0 then return nil end
  end
  return comp
end

-- Named components as { {Name =, Type =}, ... }.
function Q.components()
  local out = {}
  local ok, list = pcall(Component.GetComponents)
  if not ok or type(list) ~= "table" then return out end
  for i = 1, min(#list, LIST_CAP) do
    local c = list[i]
    if type(c) == "table" and c.Name ~= nil then
      out[#out + 1] = { Name = tostring(c.Name), Type = tostring(c.Type or "") }
    end
  end
  return out
end

function Q.isPickerType(t)
  local l = lower(tostring(t or ""))
  if l == "color_picker" then return true end
  return sfind(l, "color", 1, true) ~= nil and sfind(l, "pick", 1, true) ~= nil
end

-- Axis discovery (spec 14.1): enumerate, else probe literals, else the hex output.
local PICKER_CAP = 64          -- a Color Picker exposes about ten controls
local X_WORDS = { "saturation", "sat" }
local X_EXACT = { "hsv.s", "hsv_s" }
local Y_WORDS = { "value", "val", "bright" }
local Y_EXACT = { "hsv.v", "hsv_v" }
local X_PROBE = { "hsv.saturation", "saturation", "hsv_saturation", "Saturation", "hsv.s", "hsv_s" }
local Y_PROBE = { "hsv.value", "value", "hsv_value", "Value", "hsv.v", "hsv_v" }
local HEX_WORDS = { "output", "color", "hex" }

-- Index of the first lower-cased name containing a word (word order wins),
-- else equal to an exact form; skip(i) rejects an index.
local function firstMatch(lowers, words, exact, skip)
  for w = 1, #words do
    local word = words[w]
    for i = 1, #lowers do
      if not skip(i) and sfind(lowers[i], word, 1, true) then return i end
    end
  end
  for e = 1, #exact do
    local form = exact[e]
    for i = 1, #lowers do
      if not skip(i) and lowers[i] == form then return i end
    end
  end
  return nil
end

local function readableControl(comp, n)
  local ok, c = pcall(function() return comp[n] end)
  if not ok or c == nil then return nil end
  local okp = pcall(function() return c.Position end)
  if not okp then return nil end
  return c
end

-- Returns { x =, y =, xName =, yName =, surface =, names = } or, through the
-- colour output, { hex =, hexName =, coarse = true, names = }; on failure
-- nil, "no axes", names (the control names seen, for the Status text).
function Q.pickerAxes(comp, name)
  local list = Q.controlList(name, PICKER_CAP)
  local names, lowers = {}, {}
  for i = 1, #list do
    if list[i].Name ~= nil then
      local n = tostring(list[i].Name)
      names[#names + 1] = n
      lowers[#lowers + 1] = lower(n)
    end
  end
  local xName, yName, x, y
  if #names > 0 then
    local xi = firstMatch(lowers, X_WORDS, X_EXACT, function() return false end)
    local yi = firstMatch(lowers, Y_WORDS, Y_EXACT, function(i)
      return i == xi or sfind(lowers[i], "hue", 1, true) ~= nil
    end)
    if xi then xName = names[xi]; x = readableControl(comp, xName) end
    if yi then yName = names[yi]; y = readableControl(comp, yName) end
  end
  if not (x and y) then
    x, y, xName, yName = nil, nil, nil, nil
    for i = 1, #X_PROBE do
      local c = readableControl(comp, X_PROBE[i])
      if c then x, xName = c, X_PROBE[i]; break end
    end
    for i = 1, #Y_PROBE do
      if Y_PROBE[i] ~= xName then
        local c = readableControl(comp, Y_PROBE[i])
        if c then y, yName = c, Y_PROBE[i]; break end
      end
    end
  end
  if x and y then
    local axes = { x = x, y = y, xName = xName, yName = yName, names = names }
    axes.surface = readableControl(comp, "color_picker_surface")
    return axes
  end
  for i = 1, #names do
    local l = lowers[i]
    local hit = false
    for w = 1, #HEX_WORDS do
      if sfind(l, HEX_WORDS[w], 1, true) then hit = true end
    end
    if hit then
      local n = names[i]
      local ok, c = pcall(function() return comp[n] end)
      if ok and c ~= nil then
        local oks, str = pcall(function() return c.String end)
        if oks and type(str) == "string" and smatch(str, "^#%x%x%x%x%x%x$") then
          return { hex = c, hexName = n, coarse = true, names = names }
        end
      end
    end
  end
  return nil, "no axes", names
end

-- "#rrggbb" -> hue (0..360), saturation (0..1), value (0..1); nil on bad input.
function Q.hexToHsv(hex)
  local r, g, b = U.hexToRgb(hex)
  if not r then return nil end
  r, g, b = r / 255, g / 255, b / 255
  local mx, mn = max(r, g, b), min(r, g, b)
  local d = mx - mn
  local s = (mx > 0) and d / mx or 0
  local h = 0
  if d > 0 then
    if mx == r then h = ((g - b) / d) % 6
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h * 60
  end
  return h, s, mx
end

-- Park value: Position 0 on both axes (spec 12.3). Returns true when written.
function Q.parkPicker(axes)
  if not axes or axes.coarse then return false end
  local ok = pcall(function()
    axes.x.Position = 0
    axes.y.Position = 0
  end)
  return ok
end

-- ---------- system, files, http, sockets, misc ----------
function Q.isEmulating()
  local ok, v = pcall(function() return System.IsEmulating end)
  return ok and v == true
end

function Q.fileBase()
  if Q.isEmulating() then return "design" end
  return "media"
end

function Q.readFile(path)
  local ok, data, err = pcall(function()
    local f, e = io.open(path, "rb")
    if not f then return nil, e end
    local d = f:read("a")
    f:close()
    return d
  end)
  if not ok then return nil, tostring(data) end
  return data, err
end

function Q.writeFile(path, data, append)
  local ok, res, err = pcall(function()
    local f, e = io.open(path, append and "ab" or "wb")
    if not f then return nil, e end
    f:write(data)
    f:close()
    return true
  end)
  if not ok then return nil, tostring(res) end
  return res, err
end

function Q.mkdir(path)
  local ok, res = pcall(function() return dir.create(path) end)
  return ok and res ~= nil and res ~= false
end

-- cb(code, data, err); the reply handler runs inside the engine's guard.
function Q.httpPost(url, body, headers, cb)
  local safe = Q.guard("http", function(code, data, e)
    if cb then cb(code, data, e) end
  end)
  local ok, err = pcall(function()
    HttpClient.Upload({
      Url = url, Method = "POST", Data = body or "", Timeout = 10,
      Headers = headers or { ["Content-Type"] = "application/json" },
      EventHandler = function(_, code, data, e) safe(code, data, e) end,
    })
  end)
  if not ok then safe(0, "", tostring(err)) end
  return ok, err
end

-- opts: ip, port (defaults for send), localPort, onData(data, address, port)
function Q.udp(opts)
  opts = opts or {}
  local sock = UdpSocket.New()
  local h = { sock = sock, open = true, onData = opts.onData, ip = opts.ip, port = opts.port }
  sock.EventHandler = Q.guard("udp", function(_, packet)
    if h.onData and type(packet) == "table" then h.onData(packet.Data, packet.Address, packet.Port) end
  end)
  pcall(function()
    if opts.localPort then sock:Open(nil, opts.localPort) else sock:Open() end
  end)
  function h.send(self, bytes, ip, port)
    if not self.open then return false end
    local ok = pcall(function() sock:Send(ip or self.ip, port or self.port, bytes) end)
    return ok
  end
  function h.close(self)
    if self.open then
      self.open = false
      pcall(function() sock:Close() end)
    end
  end
  return h
end

-- opts: ip, port, onData(data), onEvent(evt, err), readTimeout, reconnect
function Q.tcp(opts)
  opts = opts or {}
  local sock = TcpSocket.New()
  local h = { sock = sock, connected = false, onData = opts.onData, onEvent = opts.onEvent }
  pcall(function()
    sock.ReadTimeout = opts.readTimeout or 0
    sock.ReconnectTimeout = opts.reconnect or 5
  end)
  sock.EventHandler = Q.guard("tcp", function(_, evt, err)
    local E = TcpSocket.Events or {}
    if evt == E.Connected then h.connected = true
    elseif evt == E.Closed or evt == E.Error or evt == E.Timeout then h.connected = false end
    if evt == E.Data and h.onData then
      local ok, data = pcall(function() return sock:Read(sock.BufferLength) end)
      if ok and data then h.onData(data) end
    end
    if h.onEvent then h.onEvent(evt, err) end
  end)
  function h.connect(self, ip, port)
    self.ip, self.port = ip or self.ip or opts.ip, port or self.port or opts.port
    local ok = pcall(function() sock:Connect(self.ip, self.port) end)
    return ok
  end
  function h.send(self, bytes)
    if not self.connected then return false end
    local ok = pcall(function() sock:Write(bytes) end)
    return ok
  end
  function h.close(self)
    self.connected = false
    pcall(function() sock:Disconnect() end)
  end
  if opts.ip and opts.port then h:connect(opts.ip, opts.port) end
  return h
end

function Q.date(fmt, t) return os.date(fmt, t) end
function Q.time() return os.time() end
function Q.print(...) print(...) end

-- Without Crypto.Base64Encode a frame must still fit the budget: the
-- fallback runs string.gsub over 3-byte groups with a table replacement, so
-- the loop stays in C. A group not seen before costs one Lua call (the
-- table's __index), which builds it from two 12-bit halves that are
-- themselves filled on demand; groups are cached, and the cache restarts
-- past B64_CACHE_CAP entries.
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_CACHE_CAP = 8192
local b64At, b64Pair, b64Cache, b64CacheSize = nil, nil, nil, 0
local b64Mt

local function b64PairOf(t, i)
  local r = b64At[i >> 6] .. b64At[i & 63]
  rawset(t, i, r)
  return r
end

local function b64Triple(t, k)
  local a, b, c = sbyte(k, 1, 3)
  local r = b64Pair[(a << 4) | (b >> 4)] .. b64Pair[((b & 15) << 8) | c]
  if b64CacheSize < B64_CACHE_CAP then
    b64CacheSize = b64CacheSize + 1
    rawset(t, k, r)
  else
    b64CacheSize = 0
    b64Cache = setmetatable({}, b64Mt)
  end
  return r
end
b64Mt = { __index = b64Triple }

local function pureBase64(s)
  if not b64At then
    b64At = {}
    for i = 0, 63 do b64At[i] = ssub(B64_CHARS, i + 1, i + 1) end
    b64Pair = setmetatable({}, { __index = b64PairOf })
    b64Cache = setmetatable({}, b64Mt)
  end
  local n = #s
  local full = n - n % 3
  local head = sgsub(ssub(s, 1, full), "...", b64Cache)
  if full == n then return head end
  return head .. U.base64(ssub(s, full + 1))
end

function Q.base64(s)
  s = tostring(s or "")
  if type(Crypto) == "table" and type(Crypto.Base64Encode) == "function" then
    local ok, r = pcall(Crypto.Base64Encode, s)
    if ok and type(r) == "string" then return r end
  end
  return pureBase64(s)
end

-- ---------- JSON (spec 12.7: guarded requires, pure-Lua fallback) ----------
local JSON = { lib = nil, probed = false }

local function jsonLib()
  if not JSON.probed then
    JSON.probed = true
    local ok, lib = pcall(require, "rapidjson")
    if not (ok and type(lib) == "table") then ok, lib = pcall(require, "json") end
    if ok and type(lib) == "table" and type(lib.encode) == "function" and type(lib.decode) == "function" then
      JSON.lib = lib
    end
  end
  return JSON.lib
end

local JSON_UNESC = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }

-- Small pure-Lua decoder (objects, arrays, strings, numbers, true/false/null).
-- null becomes nil. Returns value or nil, err.
local function jsonDecode(s)
  if type(s) ~= "string" then return nil, "not a string" end
  local n = #s
  local pos = 1
  local function skip() pos = sfind(s, "[^ \t\r\n]", pos) or (n + 1) end
  local function str()
    local parts = {}
    local i = pos + 1
    for _ = 1, n + 1 do
      local a = sfind(s, '["\\]', i)
      if not a then break end
      if a > i then parts[#parts + 1] = ssub(s, i, a - 1) end
      if ssub(s, a, a) == '"' then
        pos = a + 1
        return concat(parts)
      end
      local e = ssub(s, a + 1, a + 1)
      if e == "u" then
        local cp = tonumber(ssub(s, a + 2, a + 5), 16)
        if not cp then error("bad escape") end
        parts[#parts + 1] = utf8.char(cp)
        i = a + 6
      else
        local m = JSON_UNESC[e]
        if not m then error("bad escape") end
        parts[#parts + 1] = m
        i = a + 2
      end
    end
    error("unterminated string")
  end
  local value
  value = function(depth)
    if depth > 64 then error("too deep") end
    skip()
    local c = ssub(s, pos, pos)
    if c == "{" then
      pos = pos + 1
      local obj = {}
      skip()
      if ssub(s, pos, pos) == "}" then pos = pos + 1; return obj end
      for _ = 1, n do
        skip()
        if ssub(s, pos, pos) ~= '"' then error("expected a key") end
        local k = str()
        skip()
        if ssub(s, pos, pos) ~= ":" then error("expected ':'") end
        pos = pos + 1
        obj[k] = value(depth + 1)
        skip()
        local d = ssub(s, pos, pos)
        pos = pos + 1
        if d == "}" then return obj end
        if d ~= "," then error("expected ',' or '}'") end
      end
      error("runaway object")
    elseif c == "[" then
      pos = pos + 1
      local arr, count = {}, 0
      skip()
      if ssub(s, pos, pos) == "]" then pos = pos + 1; return arr end
      for _ = 1, n do
        count = count + 1
        arr[count] = value(depth + 1)
        skip()
        local d = ssub(s, pos, pos)
        pos = pos + 1
        if d == "]" then return arr end
        if d ~= "," then error("expected ',' or ']'") end
      end
      error("runaway array")
    elseif c == '"' then
      return str()
    elseif ssub(s, pos, pos + 3) == "true" then pos = pos + 4; return true
    elseif ssub(s, pos, pos + 4) == "false" then pos = pos + 5; return false
    elseif ssub(s, pos, pos + 3) == "null" then pos = pos + 4; return nil
    end
    local num = smatch(s, "^-?%d+%.?%d*[eE][-+]?%d+", pos) or smatch(s, "^-?%d+%.?%d*", pos)
    if not num then error("unexpected character at " .. pos) end
    pos = pos + #num
    return tonumber(num)
  end
  local ok, res = pcall(value, 0)
  if not ok then return nil, tostring(res) end
  skip()
  if pos <= n then return nil, "trailing characters" end
  return res
end
Q.jsonDecodePure = jsonDecode

function Q.json(tbl)
  local lib = jsonLib()
  if lib then
    local ok, s = pcall(lib.encode, tbl)
    if ok and type(s) == "string" then return s end
  end
  return U.jsonEncode(tbl)
end

function Q.unjson(s)
  local lib = jsonLib()
  if lib then
    local ok, v, err = pcall(lib.decode, s)
    if ok and v ~= nil then return v end
    if ok then return nil, err end
  end
  return jsonDecode(s)
end

end)()

-- ================================================================ Engine
if Controls then (function()
  local floor, sqrt, abs, min, max = math.floor, math.sqrt, math.abs, math.min, math.max
  local sfind, ssub, smatch, lower, sformat = string.find, string.sub, string.match, string.lower, string.format
  local concat = table.concat
  local BRAND_DASH = "\226\128\147"
  print(sformat("%s Touch Pad %s %s %s", BrandName, tostring(PluginInfo.Version), BRAND_DASH, BrandSite))

  -- ---------- gesture thresholds (spec 5.4, 14.7) ----------
  local TAP_MOVE, TAP_TIME = 12, 0.35
  local DOUBLE_TIME, DOUBLE_DIST = 0.4, 40
  local DRAG_START = 12
  local SWIPE_TIME, SWIPE_RATIO, SWIPE_FRACTION = 0.6, 1.5, 0.2
  local LANDING_WAIT = 0.12            -- the other axis is waited for this long
  local PANEL_LEAD, PANEL_BUFFER = 0.15, 0.1
  local RESUME_WINDOW = 1.5
  local PARK_DELAY, PARK_ECHO = 0.3, 1.0
  local STUCK = 30
  local ECHO_TIME = 0.2
  local CALIB_TIMEOUT = 60
  local ARM_DELAY = 0.1
  local LIFT_SHIFT = 6                 -- px: a report this close after an inferred tap is the finger peeling off
  local DRAW_RETRY = 1.0               -- s between frames while the mode's draw keeps failing
  local ERR_TEXT, ERR_TRACE, ERR_PRINT_EVERY = 160, 4000, 5.0
  local CAL_LINES, CAL_CHARS = 16, 2048

  -- ---------- properties ----------
  local props = {}
  do
    local ok, list = pcall(GetProperties)
    if ok and type(list) == "table" then
      for i = 1, #list do
        local p = list[i]
        if type(p) == "table" and p.Name ~= nil then props[p.Name] = p.Value end
      end
    end
    pcall(function()
      for name in pairs(props) do
        local p = Properties[name]
        if type(p) == "table" and p.Value ~= nil then props[name] = p.Value end
      end
      for k, p in pairs(Properties) do
        if props[k] == nil and type(p) == "table" then props[k] = p.Value end
      end
    end)
  end

  local function propInt(name, default, lo, hi)
    local v = tonumber(props[name]) or default
    v = floor(v + 0.5)
    if v < lo then v = lo end
    if v > hi then v = hi end
    return v
  end

  local MODE = (type(props["Mode"]) == "string" and props["Mode"] ~= "") and props["Mode"] or "XY Pad"
  local W = propInt("Pad Width", 500, 120, 1600)
  local H = propInt("Pad Height", 500, 120, 1200)
  local DIAG = sqrt(W * W + H * H)
  local FPS = propInt("Max Frame Rate", 20, 5, 60)
  local FRAME = 1 / FPS
  local TICK = min(0.05, FRAME)
  local ICON_CHANNEL = (props["Icon Channel"] == "Style") and "Style" or "Legend"
  local DEBUG = tostring(props["Debug Print"] or "None")
  local dbgGestures = (DEBUG == "Gestures" or DEBUG == "All")
  local dbgAll = (DEBUG == "All")
  local SWAP, FLIPX, FLIPY = props["Swap Axes"] == true, props["Flip X"] == true, props["Flip Y"] == true
  local BACKGROUND = tostring(props["Background"] or "Solid")
  local RADIUS = propInt("Corner Radius", 18, 0, 40)
  local FONT = U.trim(props["Font"])
  if FONT == "" then FONT = "Roboto" end
  local SHOW_HINTS = props["Show Hints"] ~= false
  local EMULATING = Q.isEmulating()
  local CAMERA_KIND = tostring(props["Camera Control"] or "None")
  if not (CAMERA_MODES and CAMERA_MODES[MODE]) then CAMERA_KIND = "None" end

  -- ---------- theme ----------
  local function resolveTheme()
    local name = props["Theme"]
    local T = U.deepcopy(THEMES[name] or THEMES["Nikita"])
    if name == "Custom" then
      local bg, accent, text = props["Background Color"], props["Accent Color"], props["Text Color"]
      if U.isHex(bg) then
        T.bg = bg:upper()
        T.panel = Svg.lighten(bg, 0.06)
        T.well = Svg.lighten(bg, -0.05)
        T.line = Svg.lighten(bg, 0.14)
        local r, g, b = U.hexToRgb(bg)
        T.padRGB = { r, g, b }
      end
      if U.isHex(accent) then
        T.accent = accent:upper()
        T.accent2 = Svg.lighten(accent, 0.25)
        T.accent3 = Svg.lighten(accent, -0.2)
      end
      if U.isHex(text) then
        T.text = text:upper()
        T.muted = Svg.mix(text, T.bg, 0.4)
      end
    end
    return T
  end
  local T = resolveTheme()

  -- ---------- control metadata (counts, groups, choices) ----------
  local META = {}
  do
    local ok, _, meta = pcall(Framework.buildControls, Properties)
    if ok and type(meta) == "table" then META = meta end
  end

  local CTLS = {}      -- name -> array-normalised control list
  local function ctlsOf(name)
    local hit = CTLS[name]
    if hit then return hit end
    local c = Controls[name]
    local out
    if c == nil then
      out = {}
    else
      local m = META[name]
      if m then
        if m.count == 1 then out = { c } else out = c end
      else
        local ok, first = pcall(function() return c[1] end)
        if ok and first ~= nil then out = c else out = { c } end
      end
    end
    CTLS[name] = out
    return out
  end
  local function ctlOf(name, index)
    if index == nil then
      local m = META[name]
      if m and m.count > 1 then return ctlsOf(name)[1] end
      return Controls[name]
    end
    return ctlsOf(name)[index]
  end

  -- ---------- status and the error guard ----------
  local LEVELS = { ok = 0, warn = 1, error = 2 }
  local status = { text = "", level = "ok", okText = "OK - Ready" }
  local errorCount = 0

  local function setStatus(text, level)
    level = LEVELS[level] and level or "ok"
    if status.written and text == status.text and level == status.level then return end
    status.text, status.level, status.written = text, level, true
    pcall(function()
      Controls.Status.Value = LEVELS[level]
      Controls.Status.String = text
    end)
  end

  -- An error is reported once on Status (first line, capped) and printed
  -- with its trace; the same error again only bumps a counter, and its trace
  -- is printed at most every ERR_PRINT_EVERY seconds (spec 5.7).
  local lastErr = { first = nil, label = nil, at = -100, n = 0 }

  local function recovered(label, err)
    errorCount = errorCount + 1
    local msg = tostring(err)
    local first = smatch(msg, "^[^\n]*") or msg
    if #first > ERR_TEXT then first = U.truncateChars(first, ERR_TEXT - 3) .. "..." end
    local now = Q.now()
    if first == lastErr.first and label == lastErr.label then
      lastErr.n = lastErr.n + 1
    else
      lastErr.first, lastErr.label, lastErr.n, lastErr.at = first, label, 1, -100
    end
    if now - lastErr.at >= ERR_PRINT_EVERY then
      lastErr.at = now
      if #msg > ERR_TRACE then msg = ssub(msg, 1, ERR_TRACE) .. " ..." end
      local tag = (lastErr.n > 1) and sformat(" (x%d)", lastErr.n) or ""
      Q.print("Touch Pad: error in " .. tostring(label) .. tag .. ": " .. msg)
    end
    if lastErr.n > 1 then
      setStatus(sformat("Recovered from an error (x%d): %s", lastErr.n, first), "error")
    else
      setStatus("Recovered from an error: " .. first, "error")
    end
  end

  local function traceback(e)
    if type(debug) == "table" and type(debug.traceback) == "function" then
      return debug.traceback(tostring(e), 2)
    end
    return tostring(e)
  end

  -- Runs fn(...) now; an error is reported and swallowed. Returns ok.
  local function protect(label, fn, ...)
    local ok, err = xpcall(fn, traceback, ...)
    if not ok then recovered(label, err) end
    return ok
  end

  local function guard(label, fn)
    return function(...) return protect(label, fn, ...) end
  end
  Q.guard = guard

  local function dbg(...)
    if dbgGestures then Q.print(...) end
  end

  -- ---------- own-write guard (spec 5.6, 12.6) ----------
  local own = setmetatable({}, { __mode = "k" })

  local function keyFor(v)
    local tv = type(v)
    if tv == "boolean" then return "Boolean" end
    if tv == "string" then return "String" end
    return "Value"
  end

  -- Clamps a number to the control's declared range so the echo compares equal.
  local function fitValue(name, v)
    local m = META[name]
    local d = m and m.def
    if type(v) ~= "number" or not d then return v end
    if v ~= v then return 0 end
    if d.ControlType == "Knob" then
      if d.ControlUnit == "Integer" then v = floor(v + 0.5) end
      if d.Min and v < d.Min then v = d.Min end
      if d.Max and v > d.Max then v = d.Max end
    elseif d.ControlType == "Button" or (d.ControlType == "Indicator" and d.IndicatorType == "Led") then
      return v > 0.5
    end
    return v
  end

  local function writeCtl(name, ctl, v)
    v = fitValue(name, v)
    local k = keyFor(v)
    local cur = ctl[k]
    if cur == v then return false end
    own[ctl] = { key = k, value = v, t = Q.now() }
    ctl[k] = v
    return true
  end

  local function isEcho(ctl)
    local o = own[ctl]
    if not o then return false end
    if Q.now() - o.t >= ECHO_TIME then
      own[ctl] = nil
      return false
    end
    if o.pulse then return true end
    return ctl[o.key] == o.value
  end

  local function pulseCtl(ctl)
    own[ctl] = { pulse = true, t = Q.now() }
    Q.pulse(ctl)
  end

  local function out(name, v, index)
    local ctl = ctlOf(name, index)
    if ctl == nil then return false end
    return writeCtl(name, ctl, v)
  end

  local function pulse(name, index)
    local ctl = ctlOf(name, index)
    if ctl == nil then return false end
    pulseCtl(ctl)
    return true
  end

  local function setGesture(text)
    out("Gesture", string.upper(tostring(text or "")))
  end

  -- ---------- geometry and calibration (spec 5.2, 13.1) ----------
  local DEFAULT_CAL = EMULATING and { 0, 0, 4 / 7, 1 } or { 0, 0, 1, 1 }
  local cal = { P = nil, D = nil }

  -- Only the first CAL_LINES lines of the first CAL_CHARS characters are
  -- read, so a large paste into the text box costs nothing.
  local function parseCalibration(text)
    cal.P, cal.D = nil, nil
    text = tostring(text or "")
    if #text > CAL_CHARS then text = ssub(text, 1, CAL_CHARS) end
    local pos, len = 1, #text
    for _ = 1, CAL_LINES do
      if pos > len then break end
      local e = sfind(text, "\n", pos, true)
      local line = ssub(text, pos, (e or (len + 1)) - 1)
      pos = (e or len) + 1
      local tag, a, b, c, d = smatch(U.trim(line), "^([PDpd])%s+([-%d.]+)%s+([-%d.]+)%s+([-%d.]+)%s+([-%d.]+)")
      if tag then
        a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
        if a and b and c and d and abs(c) > 0.01 and abs(d) > 0.01 then
          cal[string.upper(tag)] = { a, b, c, d }
        end
      end
    end
  end

  local function currentCal()
    if EMULATING then return cal.D or DEFAULT_CAL end
    return cal.P or DEFAULT_CAL
  end

  -- Raw picker (u, v) -> pad px (y down). Returns x, y, inside, px, py.
  local function toPad(u, v)
    if SWAP then u, v = v, u end
    if FLIPX then u = 1 - u end
    if FLIPY then v = 1 - v end
    local c = currentCal()
    local px = (u - c[1]) / c[3]
    local py = (v - c[2]) / c[4]
    local inside = px >= -0.02 and px <= 1.02 and py >= -0.02 and py <= 1.02
    local x = U.clamp(px, 0, 1) * W
    local y = (1 - U.clamp(py, 0, 1)) * H
    return x, y, inside, px, py
  end

  -- ---------- engine API for modes ----------
  local E = {}
  E.W, E.H, E.T, E.props = W, H, T, props
  E.font = Font
  E.hint = SHOW_HINTS
  E.camera = nil
  function E.ctl(name, index) return ctlOf(name, index) end
  function E.ctls(name) return ctlsOf(name) end
  function E.out(name, value, index) return out(name, value, index) end
  function E.pulse(name, index) return pulse(name, index) end
  function E.setGesture(text) setGesture(text) end
  function E.now() return Q.now() end
  function E.after(s, fn) return Q.after(s, guard("after", fn)) end
  function E.every(s, fn) return Q.every(s, guard("every", fn)) end
  function E.log(...) Q.print(...) end
  function E.dbg(...) dbg(...) end
  function E.status(text, level) setStatus(tostring(text or ""), level or "ok") end
  E.file = {
    base = function() return Q.fileBase() end,
    read = function(path) return Q.readFile(path) end,
    write = function(path, data) return Q.writeFile(path, data, false) end,
    append = function(path, data) return Q.writeFile(path, data, true) end,
    mkdir = function(path) return Q.mkdir(path) end,
  }
  E.http = { post = function(url, body, headers, cb) return Q.httpPost(url, body, headers, cb) end }
  E.json = { encode = function(v) return Q.json(v) end, decode = function(s) return Q.unjson(s) end }
  -- The camera module (30_camera.lua) registers the global Camera; until
  -- then the factory returns nil and E.camera stays nil.
  function E.cameraFactory(kind, opts)
    if type(Camera) ~= "table" or type(Camera.new) ~= "function" then return nil end
    local ok, cam = pcall(Camera.new, E, kind, opts)
    if ok then return cam end
    recovered("camera", cam)
    return nil
  end

  -- ---------- mode instance ----------
  local modeTable = Modes and Modes[MODE] or nil
  local inst = nil
  if modeTable and type(modeTable.create) == "function" then
    local ok, res = xpcall(modeTable.create, traceback, E)
    if ok and type(res) == "table" then inst = res else recovered("create", ok and "create returned no instance" or res) end
  end
  if inst == nil then
    inst = {
      draw = function(_, c)
        c:textFit(W / 2, H / 2, W - 24, MODE .. " is not available", { size = 14, fill = T.muted, anchor = "middle" })
      end,
    }
  end

  -- White-box handle for the offline harness and for later modules.
  TouchPad = { E = E, inst = inst, mode = MODE, cal = cal }

  local function call(name, ...)
    local fn = inst[name]
    if type(fn) ~= "function" then return false end
    return protect(name, fn, inst, ...)
  end

  -- ---------- state ----------
  local IDLE, LANDING, DOWN, OUTSIDE = "idle", "landing", "down", "outside"
  local S = {
    armed = false,
    state = IDLE,
    touch = nil,                 -- the live touch record
    landing = nil,               -- { x, y, inside, t }
    knownU = 0, knownV = 0,      -- raw picker values at the last processed report
    rawU = 0, rawV = 0,          -- raw picker values of the latest report
    reportAt = -1,               -- time of the latest accepted report
    pending = false, flush = nil,
    paused = nil,                -- an inferred lift waiting for a resume
    panelWired = false, panelDown = false, armedAt = nil, buffer = nil,
    rearm = false,               -- a stuck release under a resting finger: its next report presses again
    shift = nil,                 -- { x, y, at }: an inferred tap whose lift-off shift may still arrive
    parkHandle = nil, parkAt = -1, parkWanted = false,
    wrote = {},                  -- last value written per axis { value, t } (spec 14.3)
    lastTap = nil,
    locked = false,
    calib = nil,
    lastTick = nil,
    animating = false, animAt = 0,
  }
  TouchPad.state = S
  local picker = nil             -- Q.pickerAxes result
  local dirty, drawing = false, false
  local lastSvg, lastFrameAt, frameTimer = nil, -1, nil
  local drawRetryAt = -1         -- no frame before this while the mode's draw fails
  local truncReported = false
  local cameraDirty = false

  local function releaseTime()
    local ok, v = pcall(function() return Controls.ReleaseTime.Value end)
    if ok and type(v) == "number" then return U.clamp(v, 0.1, 1.0) end
    return 0.25
  end
  local function longPressTime()
    local ok, v = pcall(function() return Controls.LongPressTime.Value end)
    if ok and type(v) == "number" then return U.clamp(v, 0.3, 3) end
    return 0.6
  end

  -- ---------- drawing (spec 5.5) ----------
  local function render()
    local c = Svg.new(W, H, { family = FONT })
    Shapes.padFrame(c, T, W, H, RADIUS, BACKGROUND)
    local ok = call("draw", c)
    if S.calib then
      Shapes.targets(c, T, W, H)
      local step = (S.calib.stage == 1) and "Tap the top-left target" or "Now tap the bottom-right target"
      c:textFit(W / 2, 24, W - 24, "Calibration: " .. step, { size = 13, fill = T.accent, anchor = "middle", weight = "bold" })
    end
    if S.locked then Shapes.lockOverlay(c, T, W, H) end
    local svg = c:finish()
    if c.truncated and not truncReported then
      truncReported = true
      setStatus("Drawing too large: some elements were dropped", "warn")
    end
    return svg, ok
  end

  local function renderCamera()
    if type(inst.drawCamera) ~= "function" or Controls.CameraView == nil then return end
    local c = Svg.new(480, 270, { family = FONT })
    if protect("drawCamera", inst.drawCamera, inst, c) then
      local svg = c:finish()
      if svg ~= S.lastCameraSvg then
        S.lastCameraSvg = svg
        Q.setIcon(Controls.CameraView, svg, ICON_CHANNEL)
      end
    end
  end

  local function drawNow()
    dirty = false
    drawing = true
    lastFrameAt = Q.now()
    local svg, ok = render()
    if svg ~= lastSvg then
      lastSvg = svg
      Q.setIcon(Controls.Display, svg, ICON_CHANNEL)
    end
    if cameraDirty then
      cameraDirty = false
      renderCamera()
    end
    drawing = false
    if not ok then
      -- A draw that fails must not loop through its own invalidations:
      -- the next frame waits DRAW_RETRY (an animating mode included).
      dirty = false
      drawRetryAt = lastFrameAt + DRAW_RETRY
    end
  end

  local function scheduleFrame()
    if frameTimer then return end
    local now = Q.now()
    local wait = FRAME - (now - lastFrameAt)
    if drawRetryAt - now > wait then wait = drawRetryAt - now end
    if wait <= 0.0005 then
      drawNow()
      return
    end
    frameTimer = Q.after(wait, guard("frame", function()
      frameTimer = nil
      if dirty then drawNow() end
    end))
  end

  local invalidations = 0

  function E.invalidate()
    invalidations = invalidations + 1
    dirty = true
    cameraDirty = true
    if not drawing then scheduleFrame() end
  end

  -- Calls a mode method; when it did not ask for a frame itself, the engine does.
  local function callDraw(name, ...)
    local n = invalidations
    local ok = call(name, ...)
    if invalidations == n then E.invalidate() end
    return ok
  end

  function E.animate(on)
    on = on and true or false
    if on and not S.animating then S.animAt = Q.now() end
    S.animating = on
  end

  -- ---------- park and echo ----------
  local function cancelPark()
    if S.parkHandle then
      S.parkHandle:cancel()
      S.parkHandle = nil
    end
  end

  local function park()
    S.parkHandle = nil
    if S.state ~= IDLE or S.paused or not picker or picker.coarse then return end
    local now = Q.now()
    S.parkAt = now
    S.wrote.x = { value = 0, t = now }
    S.wrote.y = { value = 0, t = now }
    S.knownU, S.knownV = 0, 0
    Q.parkPicker(picker)
    if dbgAll then Q.print(sformat("park t=%.3f", now)) end
  end

  -- Called once a lift is certain: the picker is parked PARK_DELAY later.
  -- While Panel Touch still reports the finger down (the stuck guard, a
  -- lock or a rebind under a finger) the park waits for the release instead;
  -- tick() takes it from S.parkWanted (spec 5.3: never under a finger).
  local function confirmLift()
    if S.panelWired and S.panelDown then
      S.parkWanted = true
      return
    end
    S.parkWanted = false
    cancelPark()
    S.parkHandle = Q.after(PARK_DELAY, guard("park", park))
  end

  -- ---------- outputs ----------
  local function liveOutputs(touch)
    out("X", U.clamp(touch.x / W, 0, 1))
    out("Y", U.clamp(1 - touch.y / H, 0, 1))
    if touch.dragging then
      out("DragDistance", U.clamp(U.dist(touch.x0, touch.y0, touch.x, touch.y) / DIAG, 0, 2))
      out("DragAngle", U.angleDeg(touch.x - touch.x0, touch.y - touch.y0))
    end
  end

  -- ---------- calibration (spec 5.2) ----------
  local function calibrationText()
    local lines = {}
    if cal.P then lines[#lines + 1] = sformat("P %.4f %.4f %.4f %.4f", cal.P[1], cal.P[2], cal.P[3], cal.P[4]) end
    if cal.D then lines[#lines + 1] = sformat("D %.4f %.4f %.4f %.4f", cal.D[1], cal.D[2], cal.D[3], cal.D[4]) end
    return concat(lines, "\n")
  end

  local function endCalibration(text, level)
    S.calib = nil
    out("Calibrate", false)
    if text then setStatus(text, level) end
    E.invalidate()
  end

  -- Pad fraction of a raw (flipped) picker point through the current calibration.
  local function calibFraction(u, v)
    local c = currentCal()
    return (u - c[1]) / c[3], (v - c[2]) / c[4]
  end

  -- A tap during calibration: raw (u, v) of the touch start, pad fraction expected.
  local function calibrationTap(u, v)
    local s = S.calib
    s.at = Q.now()
    local px, py = calibFraction(u, v)
    local tx, ty = 0.12, 0.88          -- target 1: top-left (py up)
    if s.stage == 2 then tx, ty = 0.88, 0.12 end
    if abs(px - tx) > 0.35 or abs(py - ty) > 0.35 then
      setStatus(sformat("Calibration: tap closer to target %d", s.stage), "warn")
      return
    end
    s.points[s.stage] = { u = u, v = v }
    if s.stage == 1 then
      s.stage = 2
      setStatus("Calibration: now tap the bottom-right target", "ok")
      E.invalidate()
      return
    end
    local p1, p2 = s.points[1], s.points[2]
    local w = (p2.u - p1.u) / 0.76
    local h = (p1.v - p2.v) / 0.76
    if abs(w) < 0.05 or abs(h) < 0.05 then
      endCalibration("Calibration failed: the two taps are too close", "error")
      return
    end
    local x0 = p1.u - 0.12 * w
    local y0 = p2.v - 0.12 * h
    local tag = EMULATING and "D" or "P"
    cal[tag] = { x0, y0, w, h }
    local text = calibrationText()
    out("Calibration", text)
    endCalibration(sformat("Calibrated: %s %.4f %.4f %.4f %.4f", tag, x0, y0, w, h), "ok")
    dbg("calibration " .. text)
  end

  -- ---------- touch records ----------
  local function flipped(u, v)
    if SWAP then u, v = v, u end
    if FLIPX then u = 1 - u end
    if FLIPY then v = 1 - v end
    return u, v
  end

  local function restoreStatusIfClean(touch)
    if status.level == "error" and touch.errors0 == errorCount and U.startsWith(status.text, "Recovered") then
      setStatus(status.okText, "ok")
    end
  end

  local function press(x, y, t, inside, u, v)
    S.landing, S.armedAt, S.buffer, S.shift, S.rearm = nil, nil, nil, nil, false
    S.parkWanted = false
    if not inside and not S.calib then
      S.state = OUTSIDE
      S.reportAt = t
      dbg(sformat("touch outside the pad at %.1f, %.1f ignored", x, y))
      return
    end
    cancelPark()
    S.state = DOWN
    local fu, fv = flipped(u, v)
    S.touch = { x0 = x, y0 = y, t0 = t, x = x, y = y, t = t, moved = 0, dragging = false, longFired = false,
                releasePulsed = false, resumed = false, errors0 = errorCount, lastMoveAt = t, u0 = fu, v0 = fv,
                calib = S.calib ~= nil }
    S.reportAt = t
    dbg(sformat("touch start %.1f %.1f t=%.3f", x, y, t))
    if S.touch.calib then
      E.invalidate()
      return
    end
    out("Touching", true)
    liveOutputs(S.touch)
    pulse("Press")
    callDraw("onTouchStart", x, y, t)
  end

  local function move(x, y, t)
    local touch = S.touch
    local dx, dy = x - touch.x, y - touch.y
    S.reportAt = t
    if dx == 0 and dy == 0 then return end
    touch.x, touch.y, touch.t, touch.lastMoveAt = x, y, t, t
    local d = U.dist(touch.x0, touch.y0, x, y)
    if d > touch.moved then touch.moved = d end
    if touch.calib then return end
    if not touch.dragging and touch.moved > DRAG_START then
      touch.dragging = true
      setGesture("DRAG")
    end
    liveOutputs(touch)
    callDraw("onTouchMove", x, y, t, dx, dy)
  end

  local function swipeOf(touch, x, y, duration)
    local dx, dy = x - touch.x0, y - touch.y0
    local dist = sqrt(dx * dx + dy * dy)
    if duration > SWIPE_TIME or dist < SWIPE_FRACTION * DIAG then return nil, dist end
    local ax, ay = abs(dx), abs(dy)
    if ax >= SWIPE_RATIO * ay then
      return (dx > 0) and "right" or "left", dist
    elseif ay >= SWIPE_RATIO * ax then
      return (dy > 0) and "down" or "up", dist
    end
    return nil, dist
  end

  local SWIPE_PIN = { left = "SwipeLeft", right = "SwipeRight", up = "SwipeUp", down = "SwipeDown" }

  -- A calibration tap is forwarded to the calibration tool.
  local function liftCalibration(touch, silent)
    if S.calib and touch.moved < 40 and not silent then calibrationTap(touch.u0, touch.v0) end
    confirmLift()
    E.invalidate()
  end

  local function lift(t, inferred, silent)
    local touch = S.touch
    S.state = IDLE
    S.touch = nil
    if not touch then return end
    out("Touching", false)
    if touch.calib then return liftCalibration(touch, silent) end
    if silent then
      E.invalidate()
      return
    end
    local x, y = touch.x, touch.y
    local duration = t - touch.t0
    local swipe, distance = swipeOf(touch, x, y, duration)
    local tap = (not touch.longFired) and touch.moved < TAP_MOVE and duration < TAP_TIME
    if tap then swipe = nil end
    if touch.resumed then
      -- A drag resumed after an inferred lift was classified at that lift.
      swipe, tap = nil, false
    end
    local info = { inferred = inferred, duration = duration, distance = distance, swipe = swipe, tap = tap,
                   resumed = touch.resumed }
    dbg(sformat("touch end %.1f %.1f dur=%.3f dist=%.1f tap=%s swipe=%s inferred=%s", x, y, duration, distance,
                tostring(tap), tostring(swipe), tostring(inferred)))
    liveOutputs(touch)
    local n0 = invalidations
    call("onTouchEnd", x, y, t, info)
    if not touch.releasePulsed then
      touch.releasePulsed = true
      pulse("Release")
    end
    if swipe then
      pulse(SWIPE_PIN[swipe])
      setGesture("SWIPE " .. swipe)
      dbg("gesture swipe " .. swipe)
      call("onGesture", { type = "swipe", dir = swipe, x = x, y = y, t = t, distance = distance, duration = duration })
    elseif tap then
      pulse("Tap")
      setGesture("TAP")
      dbg(sformat("gesture tap %.1f %.1f", x, y))
      call("onGesture", { type = "tap", x = x, y = y, t = t })
      local last = S.lastTap
      if last and (touch.t0 - last.t) <= DOUBLE_TIME and U.dist(last.x, last.y, x, y) <= DOUBLE_DIST then
        S.lastTap = nil
        pulse("DoubleTap")
        setGesture("DOUBLE TAP")
        dbg(sformat("gesture double %.1f %.1f", x, y))
        call("onGesture", { type = "double", x = x, y = y, t = t })
      else
        S.lastTap = { x = x, y = y, t = t }
      end
    end
    restoreStatusIfClean(touch)
    if inferred and touch.dragging then
      -- The lift may be taken back by a report near this spot (spec 5.3).
      S.paused = { touch = touch, x = x, y = y, at = t }
    else
      if inferred then
        -- The finger peeling off may still report a few px of shift.
        S.shift = { x = x, y = y, at = t }
      end
      confirmLift()
    end
    if invalidations == n0 then E.invalidate() end
  end

  local function resume(x, y, t)
    local p = S.paused
    S.paused = nil
    local touch = p.touch
    touch.resumed = true
    S.touch = touch
    S.state = DOWN
    S.reportAt = t
    out("Touching", true)
    dbg(sformat("touch resume %.1f %.1f t=%.3f", x, y, t))
    callDraw("onTouchResume", x, y, t)
    move(x, y, t)
  end

  local function endPaused()
    if S.paused then
      S.paused = nil
      confirmLift()
    end
  end

  -- Ends a touch the lift path cannot finish (lock, rebind, calibration,
  -- a clock step): the mode gets onTouchEnd with info.aborted, Release is
  -- pulsed when Press was (not when silent: Lock pulses nothing, spec 5.6),
  -- a pending report is dropped and the park follows once the finger is up.
  local function cancelTouch(reason, silent)
    local touch, wasDown = S.touch, (S.state == DOWN)
    local hadPaused = S.paused ~= nil
    S.touch, S.paused, S.landing, S.armedAt, S.buffer, S.shift = nil, nil, nil, nil, nil, nil
    S.rearm, S.pending = false, false
    if S.flush then
      S.flush:cancel()
      S.flush = nil
    end
    S.state = IDLE
    if touch and wasDown then
      out("Touching", false)
      if not touch.calib then
        local t = Q.now()
        local info = { aborted = true, reason = reason, inferred = false, duration = t - touch.t0,
                       distance = U.dist(touch.x0, touch.y0, touch.x, touch.y), swipe = nil, tap = false,
                       resumed = touch.resumed }
        dbg(sformat("touch cancelled (%s) %.1f %.1f", tostring(reason), touch.x, touch.y))
        call("onTouchEnd", touch.x, touch.y, t, info)
        if not silent and not touch.releasePulsed then
          touch.releasePulsed = true
          pulse("Release")
        end
      end
      E.invalidate()
    end
    if (touch and wasDown) or hadPaused then S.parkWanted = true end
  end

  -- A complete report (both axes, or the pairing window over) decides
  -- between resuming a paused drag, swallowing a lift-off shift and a press.
  local function land(r)
    S.landing = nil
    if S.state == LANDING then S.state = IDLE end
    local x, y, t = r.x, r.y, r.t
    if S.paused then
      local p = S.paused
      local near = max(60, 0.12 * DIAG)
      if t - p.at <= RESUME_WINDOW and U.dist(p.x, p.y, x, y) <= near then
        resume(x, y, t)
        return
      end
      endPaused()
    end
    local sh = S.shift
    if sh then
      S.shift = nil
      if not S.panelWired and t - sh.at <= 2 * releaseTime() and U.dist(sh.x, sh.y, x, y) <= LIFT_SHIFT then
        dbg(sformat("lift-off shift %.1f %.1f ignored", x, y))
        S.reportAt = t
        confirmLift()
        return
      end
    end
    press(x, y, t, r.inside, r.u, r.v)
  end

  -- One picker report, after echo filtering and deferral (spec 5.3, 14.7).
  local function process(u, v, t)
    local changedU, changedV = u ~= S.knownU, v ~= S.knownV
    S.knownU, S.knownV = u, v
    if S.locked then
      S.reportAt = t
      return
    end
    local x, y, inside = toPad(u, v)
    if dbgAll then Q.print(sformat("report u=%.4f v=%.4f -> %.1f %.1f %s t=%.3f", u, v, x, y, inside and "in" or "out", t)) end
    if S.state == DOWN then
      move(x, y, t)
      return
    end
    if S.state == OUTSIDE then
      S.reportAt = t
      return
    end
    local r = { x = x, y = y, t = t, inside = inside, u = u, v = v, cu = changedU, cv = changedV }
    if S.state == LANDING then
      land(r)                         -- the other axis of a landing arrived
      return
    end
    if S.panelWired then
      -- Panel Touch owns press and release: a report lands only with a recent
      -- down (or after a stuck release under a resting finger); otherwise it
      -- waits in the buffer for a down that follows it.
      local armed = S.rearm or (S.armedAt ~= nil and t - S.armedAt <= PANEL_LEAD)
      if not armed then
        local b = S.buffer
        if b and t - b.t <= PANEL_BUFFER then
          r.cu, r.cv = r.cu or b.cu, r.cv or b.cv
        end
        S.buffer = r
        return
      end
      S.rearm = false
    end
    if changedU and changedV then
      land(r)
      return
    end
    S.state = LANDING
    S.landing = r
  end

  local function flush()
    S.flush = nil
    if not S.pending then return end
    S.pending = false
    process(S.rawU, S.rawV, S.reportTime or Q.now())
  end

  local function readAxes()
    if not picker then return nil end
    if picker.coarse then
      local ok, str = pcall(function() return picker.hex.String end)
      if not ok then return nil end
      local _, s, v = Q.hexToHsv(str)
      if s == nil then return nil end
      return s, v
    end
    local ok, u, v = pcall(function() return picker.x.Position, picker.y.Position end)
    if not ok or type(u) ~= "number" or type(v) ~= "number" then return nil end
    return u, v
  end

  local function isWriteEcho(axis, value)
    local w = S.wrote[axis]
    if not w then return false end
    local now = Q.now()
    if now - w.t > PARK_ECHO then
      S.wrote[axis] = nil
      return false
    end
    return abs(value - w.value) < 1e-6
  end

  -- The axis EventHandlers land here (synchronously); the report is processed
  -- on the next engine turn so the two axes of one touch arrive together.
  local function onReport(axis)
    if not S.armed then return end
    local u, v = readAxes()
    if u == nil then return end
    if axis == "x" and isWriteEcho("x", u) then
      if dbgAll then Q.print("park echo ignored (x)") end
      return
    elseif axis == "y" and isWriteEcho("y", v) then
      if dbgAll then Q.print("park echo ignored (y)") end
      return
    elseif axis == "surface" and isWriteEcho("x", u) and isWriteEcho("y", v) then
      return
    end
    S.rawU, S.rawV = u, v
    S.reportTime = Q.now()
    S.pending = true
    if not S.flush then S.flush = Q.after(0, guard("report", flush)) end
  end

  -- ---------- calibration (spec 5.2) ----------
  local function startCalibration()
    cancelTouch("calibrate", false)     -- a live touch ends first; its start is not a target tap
    S.calib = { stage = 1, at = Q.now(), points = {} }
    setStatus("Calibration: tap the top-left target", "ok")
    E.invalidate()
  end

  -- Leaving calibration while a calibration touch is down drops that touch:
  -- the rest of the contact is ignored as a touch outside the pad.
  local function leaveCalibration()
    if S.touch and S.touch.calib and S.state == DOWN then
      S.touch = nil
      S.state = OUTSIDE
      S.reportAt = Q.now()
    end
  end

  -- ---------- picker binding (spec 5.1, 12.2, 14.1, 14.2) ----------
  local function unbind()
    if not picker then return end
    pcall(function()
      if picker.x then picker.x.EventHandler = nil end
      if picker.y then picker.y.EventHandler = nil end
      if picker.surface then picker.surface.EventHandler = nil end
      if picker.hex then picker.hex.EventHandler = nil end
    end)
    picker = nil
  end

  local function namesText(names)
    local shown = {}
    for i = 1, min(#names, 12) do shown[i] = names[i] end
    if #names > 12 then shown[#shown + 1] = "..." end
    return concat(shown, ", ")
  end

  local function bind()
    unbind()
    cancelTouch("rebind", false)
    local name = U.trim(Controls.Picker.String)
    if name == "" then name = U.trim(props["Color Picker"]) end
    local comps = Q.components()
    local listed, pickers = nil, {}
    for i = 1, #comps do
      local c = comps[i]
      if c.Name == name then listed = c end
      if Q.isPickerType(c.Type) then pickers[#pickers + 1] = c end
    end
    if name == "" then
      if #pickers == 1 then
        name, listed = pickers[1].Name, pickers[1]
      elseif #pickers == 0 then
        setStatus("No Color Picker in the design: add one and set its Script Access to All", "error")
        return false
      else
        setStatus(#pickers .. " Color Pickers in the design: name one in the Color Picker property", "warn")
        return false
      end
    end
    if listed and not Q.isPickerType(listed.Type) then
      -- Known and not a picker: its (possibly huge) control list is not scanned.
      setStatus(name .. " is not a Color Picker", "error")
      return false
    end
    local comp = Q.component(name)
    if not comp then
      if listed then setStatus("Set the picker's Script Access to All: " .. name, "error")
      else setStatus("No picker named " .. name, "error") end
      return false
    end
    local axes, _, names = Q.pickerAxes(comp, name)
    names = axes and axes.names or names or {}
    if dbgAll then
      Q.print("picker " .. name .. " controls: " .. concat(names, ", "))
    end
    if not axes then
      if #names > 0 then
        setStatus(name .. " has no recognised axis controls (controls: " .. namesText(names) .. ")", "error")
      elseif listed then
        setStatus("Set the picker's Script Access to All: " .. name, "error")
      else
        setStatus(name .. " is not a Color Picker", "error")
      end
      return false
    end
    picker = axes
    picker.name = name
    S.wrote = {}
    if axes.coarse then
      axes.hex.EventHandler = guard("picker hex", function() onReport("surface") end)
      status.okText = "OK - Picker bound through its colour output (coarse): " .. name .. " / " .. axes.hexName
      setStatus(status.okText, "warn")
    else
      axes.x.EventHandler = guard("picker x", function() onReport("x") end)
      axes.y.EventHandler = guard("picker y", function() onReport("y") end)
      if axes.surface then
        axes.surface.EventHandler = guard("picker surface", function() onReport("surface") end)
      end
      status.okText = "OK - Ready. Picker OK: " .. axes.xName .. " / " .. axes.yName
      setStatus(status.okText, "ok")
      local u, v = readAxes()
      if u then S.knownU, S.knownV = u, v end
    end
    return true
  end

  -- ---------- control handlers ----------
  local function onPanelTouch(ctl)
    S.panelWired = true
    local now = Q.now()
    if S.pending then flush() end       -- a report of the same turn lands before the edge
    if ctl.Boolean then
      S.panelDown = true
      S.rearm = false
      if S.state == DOWN or S.state == LANDING then return end
      endPaused()
      local b = S.buffer
      S.buffer = nil
      if b and now - b.t <= PANEL_BUFFER then
        if b.cu and b.cv then
          land(b)
        else
          -- One axis so far (Designer sends them apart): wait for the other.
          b.t = now
          S.state = LANDING
          S.landing = b
        end
      else
        S.armedAt = now
      end
    else
      S.panelDown = false
      S.armedAt, S.buffer, S.rearm = nil, nil, false
      if S.state == LANDING and S.landing then land(S.landing) end
      if S.state == DOWN then
        lift(now, false, false)
      elseif S.state == OUTSIDE or S.state == LANDING then
        S.state = IDLE
        S.landing = nil
        confirmLift()
      elseif S.parkWanted then
        confirmLift()
      end
    end
  end

  local function onLock(ctl)
    local locked = ctl.Boolean and true or false
    if locked == S.locked then return end
    S.locked = locked
    if locked then
      cancelTouch("lock", true)
      setGesture("LOCKED")
    end
    dbg("lock " .. tostring(locked))
    call("onLock", locked)
    E.invalidate()
  end

  local function onCalibrate(ctl)
    if ctl.Boolean then
      if not S.calib then startCalibration() end
    elseif S.calib then
      leaveCalibration()
      endCalibration("Calibration cancelled", "ok")
      setStatus(status.okText, "ok")
    end
  end

  local function onCalibration(ctl)
    parseCalibration(ctl.String)
    dbg("calibration text applied")
  end

  -- Any event on the Refresh trigger rescans (a Trigger's handler may run
  -- with Boolean already false); the trailing edge of a pulse just handled
  -- does not scan twice.
  local function onRefresh(ctl)
    local now = Q.now()
    if not ctl.Boolean and S.refreshAt and now - S.refreshAt < 1 then return end
    S.refreshAt = now
    bind()
  end

  local function onControlChange(name, index, ctl)
    if not S.armed then return end
    if isEcho(ctl) then return end
    if name == "PanelTouch" then return onPanelTouch(ctl) end
    if name == "Lock" then return onLock(ctl) end
    if name == "Calibrate" then return onCalibrate(ctl) end
    if name == "Calibration" then return onCalibration(ctl) end
    if name == "Refresh" then return onRefresh(ctl) end
    if name == "Picker" then return bind() end
    if name == "ReleaseTime" or name == "LongPressTime" then return end
    call("onControl", name, index, ctl)
  end

  local SKIP_HANDLER = { Display = true, CameraView = true, Status = true, PickerLayout = true, Gesture = true }

  local function installHandlers()
    for name, m in pairs(META) do
      local def = m.def or {}
      local skip = SKIP_HANDLER[name] or (def.PinStyle == "Output")
      if not skip then
        local list = ctlsOf(name)
        for i = 1, #list do
          local ctl = list[i]
          local idx = i
          pcall(function()
            ctl.EventHandler = guard("ctl " .. name, function(c) onControlChange(name, idx, c) end)
          end)
        end
      end
      if m.choices and type(m.choices) == "table" then
        local list = ctlsOf(name)
        local choices = {}
        for i = 1, #m.choices do choices[i] = tostring(m.choices[i]) end
        for i = 1, #list do pcall(function() list[i].Choices = choices end) end
      end
    end
  end

  -- ---------- the engine tick (spec 5.3 timeouts, 5.5 animation) ----------
  local function tick()
    local now = Q.now()
    local dt = S.lastTick and (now - S.lastTick) or TICK
    S.lastTick = now
    if dt < 0 or dt > 5 then
      -- A clock step: drop the gesture state rather than mis-time it.
      cancelTouch("clock", false)
      S.lastTap = nil
      return
    end
    if S.pending then flush() end
    if S.state == LANDING and S.landing and now - S.landing.t >= LANDING_WAIT then
      land(S.landing)
    end
    if S.armedAt and now - S.armedAt > PANEL_LEAD then S.armedAt = nil end
    if S.state == DOWN and S.touch then
      local touch = S.touch
      if S.panelWired and S.panelDown then
        if not touch.longFired and not touch.calib and touch.moved < TAP_MOVE and now - touch.t0 >= longPressTime() then
          touch.longFired = true
          pulse("LongPress")
          setGesture("LONG PRESS")
          dbg(sformat("gesture long %.1f %.1f", touch.x, touch.y))
          call("onGesture", { type = "long", x = touch.x, y = touch.y, t = now })
        end
        if now - touch.lastMoveAt > STUCK then
          dbg("stuck guard released the touch")
          lift(now, false, false)
          S.rearm = true               -- the finger is still there: its next report presses again
        end
      elseif now - S.reportAt > releaseTime() then
        lift(S.reportAt, true, false)
      elseif now - touch.lastMoveAt > STUCK then
        dbg("stuck guard released the touch")
        lift(now, false, false)
      end
    elseif S.state == OUTSIDE then
      if (S.panelWired and not S.panelDown) or (not S.panelWired and now - S.reportAt > releaseTime()) then
        S.state = IDLE
        confirmLift()
      elseif now - S.reportAt > STUCK then
        S.state = IDLE
        confirmLift()
      end
    end
    if S.paused and now - S.paused.at > RESUME_WINDOW then endPaused() end
    if S.shift and now - S.shift.at > 2 * releaseTime() then S.shift = nil end
    if S.parkWanted and S.state == IDLE and not S.paused then
      if (S.panelWired and not S.panelDown) or (not S.panelWired and now - S.reportAt > releaseTime()) then
        confirmLift()
      end
    end
    if S.calib and now - S.calib.at > CALIB_TIMEOUT then
      leaveCalibration()
      endCalibration("Calibration cancelled: no taps for 60 s", "warn")
    end
    if S.animating and type(inst.tick) == "function" and now - S.animAt >= FRAME - 0.0005 then
      local adt = now - S.animAt
      S.animAt = now
      call("tick", adt)
    end
    if dirty and not frameTimer then scheduleFrame() end
  end

  -- ---------- start ----------
  Q.probeClock()
  Q.disable(Controls.Display)
  if Controls.CameraView then Q.disable(Controls.CameraView) end
  installHandlers()
  pcall(function() Controls.PickerLayout.String = Framework.pickerText(W, H) end)
  protect("calibration", function() parseCalibration(Controls.Calibration.String) end)
  S.locked = Controls.Lock.Boolean and true or false
  if Controls.PanelTouch.Boolean then S.panelWired, S.panelDown = true, true end
  out("Touching", false)
  out("X", 0)
  out("Y", 0)
  out("DragDistance", 0)
  out("DragAngle", 0)
  setGesture((modeTable and modeTable.hint) or "")
  if CAMERA_KIND ~= "None" then
    E.camera = E.cameraFactory(CAMERA_KIND, { name = props["Camera Name"], brand = props["VISCA Brand"] })
  end
  protect("bind", bind)
  if not modeTable then
    setStatus("Mode " .. MODE .. " is not available in this build", "warn")
  end
  NikitaTimers.tick = Q.every(TICK, guard("tick", tick))
  Q.after(ARM_DELAY, guard("arm", function()
    S.armed = true
    if picker then
      local u, v = readAxes()
      if u then S.knownU, S.knownV = u, v end
    end
  end))
  call("onStart")
  protect("frame", E.invalidate)
end)() end
