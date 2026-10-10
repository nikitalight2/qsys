-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: harness fixture (a tiny plugin that exercises every fake API)
--
-- Not shipped. The offline harness loads this file to test itself before the
-- real plugin exists. It has the four design-time functions and a runtime
-- section that binds a Color Picker the way spec sections 12.2 to 12.6
-- describe, draws an icon through the Legend JSON, pulses a trigger, posts
-- over HTTP, sends UDP and TCP, writes a file under media/ or design/ and
-- keeps every handler inside pcall. It is also a worked example of the
-- patterns the engine uses.

PluginInfo = {
  Name = "Nikita Visual Arts~Harness Fixture",
  Version = "0.1.0",
  BuildVersion = "0.1.0.0",
  Id = "f1e0a3b2-7c6d-4e5f-8a9b-0c1d2e3f4a5b",
  Author = "Nikita Visual Arts – nikitavisual.art",
  Description = "Offline harness fixture. Nikita Visual Arts – nikitavisual.art",
  ShowDebug = false,
}

MODE_NAMES = { "XY Pad", "Zone Select" }

function GetPrettyName(props)
  return "Fixture: " .. tostring(props["Mode"].Value)
end

function GetProperties()
  return {
    { Name = "Mode", Type = "enum", Choices = MODE_NAMES, Value = "XY Pad" },
    { Name = "Pad Width", Type = "integer", Min = 120, Max = 1600, Value = 500 },
    { Name = "Pad Height", Type = "integer", Min = 120, Max = 1200, Value = 500 },
    { Name = "Color Picker", Type = "string", Value = "" },
    { Name = "Zones", Type = "integer", Min = 1, Max = 4, Value = 2 },
    { Name = "Debug Print", Type = "enum", Choices = { "None", "All" }, Value = "None" },
  }
end

function RectifyProperties(props)
  -- Zones only matter in Zone Select; hide the property elsewhere.
  props["Zones"].IsHidden = props["Mode"].Value ~= "Zone Select"
  return props
end

function GetPages(props)
  return { { name = "Pad" }, { name = "Setup" } }
end

function GetControls(props)
  local zones = props["Zones"].Value
  return {
    { Name = "Status", ControlType = "Indicator", IndicatorType = "Status", PinStyle = "Output", UserPin = true },
    { Name = "Display", ControlType = "Button", ButtonType = "Momentary" },
    { Name = "Picker", ControlType = "Text", PinStyle = "Input", UserPin = true },
    { Name = "Refresh", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", UserPin = true },
    { Name = "PanelTouch", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", UserPin = true },
    { Name = "ReleaseTime", ControlType = "Knob", ControlUnit = "Seconds", Min = 0.1, Max = 1.0, DefaultValue = 0.25, PinStyle = "Input", UserPin = true },
    { Name = "Touching", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output", UserPin = true },
    { Name = "X", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, PinStyle = "Output", UserPin = true },
    { Name = "Y", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, PinStyle = "Output", UserPin = true },
    { Name = "Tap", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both", UserPin = true },
    { Name = "Gesture", ControlType = "Indicator", IndicatorType = "Text", PinStyle = "Output", UserPin = true },
    { Name = "Level", ControlType = "Knob", ControlUnit = "dB", Min = -100, Max = 10, DefaultValue = 0, PinStyle = "Both", UserPin = true },
    { Name = "Counter", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = 1000, PinStyle = "Output", UserPin = true },
    { Name = "ZoneSelected", ControlType = "Button", ButtonType = "Toggle", Count = zones, PinStyle = "Both", UserPin = true },
    { Name = "ZoneName", ControlType = "Text", Count = zones, PinStyle = "Input", UserPin = true },
    { Name = "SelectedList", ControlType = "Indicator", IndicatorType = "Text", PinStyle = "Output", UserPin = true },
    { Name = "Net", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", UserPin = true },
    { Name = "Post", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", UserPin = true },
    { Name = "Save", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", UserPin = true },
    { Name = "Crash", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", UserPin = true },
  }
end

function GetControlLayout(props)
  local W, H = 760, 560
  local padW, padH = props["Pad Width"].Value, props["Pad Height"].Value
  local zones = props["Zones"].Value
  local pages = GetPages(props)
  local page = pages[props["page_index"].Value].name
  local layout, graphics = {}, {}
  local M, HEADER = 16, 48

  table.insert(graphics, { Type = "GroupBox", Fill = { 23, 21, 28 }, StrokeWidth = 0, Position = { 0, 0 }, Size = { W, H } })
  table.insert(graphics, { Type = "Label", Text = "Nikita Visual Arts - nikitavisual.art", FontSize = 13, FontStyle = "Bold",
                           HTextAlign = "Left", Color = { 244, 242, 247 }, Position = { M, 12 }, Size = { 320, 20 } })
  table.insert(graphics, { Type = "Label", Text = GetPrettyName(props), FontSize = 13, HTextAlign = "Right",
                           Color = { 244, 242, 247 }, Position = { W - 300 - M - 24, 12 }, Size = { 300, 20 } })
  layout["Status"] = { Style = "Led", Position = { W - M - 16, 16 }, Size = { 16, 16 } }

  local function place(name, style, x, y, w, h, extra)
    local e = { Style = style, Position = { x, y }, Size = { w, h } }
    if extra then for k, v in pairs(extra) do e[k] = v end end
    layout[name] = e
  end

  if page == "Pad" then
    local scale = math.min(1, 480 / math.max(padW, padH))
    place("Display", "Button", M, HEADER + M, math.floor(padW * scale), math.floor(padH * scale),
          { ButtonStyle = "Momentary", ButtonVisualStyle = "Flat", IsReadOnly = true, Legend = "", Color = "#FFFFFF", OffColor = "#FFFFFF" })
    local x = M + math.floor(padW * scale) + M
    place("Gesture", "Text", x, HEADER + M, 200, 24, { PrettyName = "Outputs~Gesture" })
    place("X", "Knob", x, HEADER + M + 32, 48, 48, { PrettyName = "Outputs~X" })
    place("Y", "Knob", x + 56, HEADER + M + 32, 48, 48, { PrettyName = "Outputs~Y" })
    place("Touching", "Led", x + 112, HEADER + M + 48, 16, 16, { PrettyName = "Outputs~Touching" })
    place("Tap", "Button", x, HEADER + M + 88, 64, 24, { ButtonStyle = "Trigger", Legend = "Tap", PrettyName = "Outputs~Tap" })
    place("Counter", "Text", x, HEADER + M + 120, 64, 24, { PrettyName = "Outputs~Counter" })
  else
    local y = HEADER + M
    place("Picker", "Text", M, y, 200, 24, { PrettyName = "Setup~Picker" })
    place("Refresh", "Button", M + 208, y, 64, 24, { ButtonStyle = "Trigger", Legend = "Refresh" })
    place("PanelTouch", "Button", M + 280, y, 96, 24, { ButtonStyle = "Toggle", Legend = "Panel Touch" })
    place("ReleaseTime", "Knob", M, y + 32, 48, 48)
    place("Level", "Fader", M + 64, y + 32, 32, 120)
    for i = 1, zones do
      local sfx = zones == 1 and "" or (" " .. i)
      place("ZoneSelected" .. sfx, "Button", M + 120, y + 32 + (i - 1) * 28, 64, 24, { ButtonStyle = "Toggle", Legend = "Zone " .. i })
      place("ZoneName" .. sfx, "Text", M + 192, y + 32 + (i - 1) * 28, 120, 24)
    end
    place("SelectedList", "Text", M + 120, y + 160, 192, 24)
    place("Net", "Button", M, y + 200, 64, 24, { ButtonStyle = "Trigger", Legend = "Net" })
    place("Post", "Button", M + 72, y + 200, 64, 24, { ButtonStyle = "Trigger", Legend = "Post" })
    place("Save", "Button", M + 144, y + 200, 64, 24, { ButtonStyle = "Trigger", Legend = "Save" })
    place("Crash", "Button", M + 216, y + 200, 64, 24, { ButtonStyle = "Trigger", Legend = "Crash" })
  end
  return layout, graphics
end

-- ====================================================================
-- Runtime
-- ====================================================================
if Controls then
  local E = {}
  local zones = Properties["Zones"].Value
  local W = Properties["Pad Width"].Value
  local H = Properties["Pad Height"].Value
  local debugAll = Properties["Debug Print"].Value == "All"

  local json
  do
    local ok, mod = pcall(require, "rapidjson")
    if ok then json = mod end
  end

  -- Q-SYS quirk: Count = 1 arrives as a single control, not a one-element array.
  local function arr(c, n) return n == 1 and { c } or c end
  local ZoneSelected = arr(Controls.ZoneSelected, zones)
  local ZoneName = arr(Controls.ZoneName, zones)

  local function setStatus(v, s)
    Controls.Status.Value = v
    Controls.Status.String = s
  end

  -- Every handler runs inside pcall; an error is shown on Status and the plugin keeps going.
  local function guard(label, fn)
    return function(...)
      local ok, err = pcall(fn, ...)
      if not ok then
        local first = tostring(err):match("^[^\n]*")
        setStatus(2, "Recovered from an error: " .. first)
        print("ERROR " .. label .. ": " .. tostring(err))
      end
    end
  end

  Controls.Display.IsDisabled = true
  print(string.format("Fixture %s – harness self-test plugin", PluginInfo.Version))
  assert(Crypto.Base64Decode(Crypto.Base64Encode("round trip")) == "round trip")

  -- ---------- own-write guard (spec 5.6 / 12.6) ----------
  local own = {}
  local function keyFor(v)
    if type(v) == "boolean" then return "Boolean" end
    if type(v) == "string" then return "String" end
    return "Value"
  end
  local function out(ctl, v)
    local k = keyFor(v)
    if ctl[k] == v then return end
    own[ctl] = { v = v, t = Timer.Now() }
    ctl[k] = v
  end
  local function isEcho(ctl)
    local o = own[ctl]
    if not o then return false end
    return ctl[keyFor(o.v)] == o.v and Timer.Now() - o.t < 0.2
  end
  local function pulse(ctl)
    own[ctl] = { v = true, t = Timer.Now() }
    ctl.Boolean = true
    own[ctl] = { v = false, t = Timer.Now() }
    ctl.Boolean = false
  end
  function E.text(s) out(Controls.Gesture, s) end

  -- ---------- picker binding (spec 12.2 / 12.4) ----------
  local picker = { comp = nil, x = nil, y = nil, name = "", xname = "", yname = "" }
  local XC = { "saturation", "hsv_s", "hsv.s", "hsv s", "sat" }
  local YC = { "value", "hsv_v", "hsv.v", "hsv v", "val", "bright" }
  local function matches(name, list)
    local n = name:lower()
    for _, c in ipairs(list) do
      if n == c or n:find(c, 1, true) then return true end
    end
    return false
  end

  local function bind()
    local name = Controls.Picker.String
    if name == "" then name = Properties["Color Picker"].Value end
    if name == "" then
      local count = 0
      for _, c in ipairs(Component.GetComponents()) do
        if c.Type == "color_picker" then
          count = count + 1
          if count == 1 then name = c.Name end
        end
      end
      if count > 1 then setStatus(1, count .. " Color Pickers in the design: name one") return end
    end
    if name == "" then setStatus(2, "No Color Picker in the design") return end
    local ok, comp = pcall(Component.New, name)
    if not ok or comp == nil then setStatus(2, "No picker named " .. name) return end
    local list = Component.GetControls(name)
    local xname, yname
    for _, c in ipairs(list) do
      if debugAll then print("picker control: " .. tostring(c.Name)) end
      local n = tostring(c.Name)
      if not xname and matches(n, XC) then xname = n end
    end
    for _, c in ipairs(list) do
      local n = tostring(c.Name)
      if not yname and n ~= xname and not n:lower():find("hue", 1, true) and matches(n, YC) then yname = n end
    end
    if not xname or not yname then setStatus(2, name .. " is not a Color Picker") return end
    picker.comp, picker.name, picker.xname, picker.yname = comp, name, xname, yname
    picker.x, picker.y = comp[xname], comp[yname]
    picker.x.EventHandler = guard("picker x", function() E.report("x") end)
    picker.y.EventHandler = guard("picker y", function() E.report("y") end)
    local surface = comp["color_picker_surface"]
    if surface then surface.EventHandler = guard("surface", function() E.report("surface") end) end
    setStatus(0, "OK - " .. name .. " (" .. xname .. ", " .. yname .. ")")
  end

  -- ---------- touch state ----------
  local T = { down = false, last = 0, t0 = 0, x0 = 0, y0 = 0, x = 0, y = 0, moved = 0, parkUntil = -1, panel = false,
              landingAt = nil, lx = 0, ly = 0, echoX = 0, echoY = 0 }
  local dirty, lastSvg, frames = true, "", 0

  function E.invalidate() dirty = true end

  local function press(x, y)
    T.landingAt = nil
    T.down = true
    T.x0, T.y0, T.moved, T.t0 = x, y, 0, Timer.Now()
    T.x, T.y = x, y
    out(Controls.Touching, true)
    E.text("PRESS")
    out(Controls.X, x / W)
    out(Controls.Y, 1 - y / H)
    E.invalidate()
  end

  function E.report(axis)
    if not picker.x then return end
    local u, v = picker.x.Position, picker.y.Position
    -- The echo of our own park write (if the platform fires it) is expected once
    -- per axis, for 0.5 s; anything else is a finger.
    if Timer.Now() >= T.parkUntil then T.echoX, T.echoY = 0, 0 end
    if axis == "x" and T.echoX > 0 and u == 0 then
      T.echoX = T.echoX - 1
      if debugAll then print("park echo ignored") end
      return
    end
    if axis == "y" and T.echoY > 0 and v == 0 then
      T.echoY = T.echoY - 1
      if debugAll then print("park echo ignored") end
      return
    end
    if debugAll then print(string.format("report u=%.4f v=%.4f t=%.3f", u, v, Timer.Now())) end
    local cal = System.IsEmulating and { 0, 0, 4 / 7, 1 } or { 0, 0, 1, 1 }
    local px = (u - cal[1]) / cal[3]
    local py = (v - cal[2]) / cal[4]
    if px < -0.02 or px > 1.02 or py < -0.02 or py > 1.02 then return end
    local x, y = px * W, (1 - py) * H
    T.last = Timer.Now()
    if not T.down then
      -- LANDING (spec 5.3): the two axes arrive as two reports; the first one still
      -- carries the other axis's old value, so wait for the second (or 0.1 s).
      if T.landingAt == nil then
        T.landingAt, T.lx, T.ly = T.last, x, y
        return
      end
      press(x, y)
      return
    end
    local d = math.sqrt((x - T.x0) ^ 2 + (y - T.y0) ^ 2)
    if d > T.moved then T.moved = d end
    T.x, T.y = x, y
    out(Controls.X, px)
    out(Controls.Y, py)
    E.invalidate()
  end

  function E.lift()
    if not T.down then return end
    T.down = false
    out(Controls.Touching, false)
    local dur = Timer.Now() - T.t0
    if T.moved < 12 and dur < 0.35 then
      pulse(Controls.Tap)
      E.text("TAP")
    else
      E.text("RELEASE")
    end
    -- Park 0.3 s after a confirmed lift, never while a finger is down; ignore the echo.
    Timer.CallAfter(guard("park", function()
      if T.down or not picker.x then return end
      T.parkUntil = Timer.Now() + 0.5
      T.echoX, T.echoY = 1, 1
      picker.x.Position = 0
      picker.y.Position = 0
      T.echoX, T.echoY = 0, 0        -- the fake echoes synchronously; a Core may not echo at all
    end), 0.3)
    E.invalidate()
  end

  -- ---------- drawing (spec 12.1: Legend JSON with base64 SVG) ----------
  function E.draw()
    local parts = {}
    parts[#parts + 1] = string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">', W, H, W, H)
    parts[#parts + 1] = string.format('<rect x="0" y="0" width="%d" height="%d" rx="18" fill="#17151C"/>', W, H)
    if T.down then
      parts[#parts + 1] = string.format('<circle cx="%.1f" cy="%.1f" r="14" fill="#C513E8"/>', T.x, T.y)
    end
    parts[#parts + 1] = string.format('<text x="%d" y="%d" fill="#A79FB3" font-family="Roboto" font-size="12" text-anchor="middle">%s</text>',
                                      W // 2, H - 12, Controls.Gesture.String)
    parts[#parts + 1] = "</svg>"
    local svg = table.concat(parts)
    if svg == lastSvg then return end
    lastSvg = svg
    frames = frames + 1
    local legend = { DrawChrome = false, IconData = Crypto.Base64Encode(svg) }
    if json then
      Controls.Display.Legend = json.encode(legend)
    else
      Controls.Display.Legend = '{"DrawChrome":false,"IconData":"' .. legend.IconData .. '"}'
    end
  end

  -- ---------- timers (module level so they are never collected) ----------
  Timers = {}
  Timers.frame = Timer.New()
  Timers.frame.EventHandler = guard("frame", function()
    if dirty then
      dirty = false
      E.draw()
    end
  end)
  Timers.frame:Start(0.05)

  Timers.silence = Timer.New()
  Timers.silence.EventHandler = guard("silence", function()
    if T.landingAt and Timer.Now() - T.landingAt > 0.1 then press(T.lx, T.ly) end
    if not T.down then return end
    local idle = Timer.Now() - T.last
    if T.panel then
      if idle > 30 then E.lift() end        -- stuck guard
    elseif idle > Controls.ReleaseTime.Value then
      E.lift()
    end
  end)
  Timers.silence:Start(0.05)

  Timers.counter = Timer.New()
  Timers.counter.EventHandler = guard("counter", function(t)
    if t ~= Timers.counter then error("timer handler did not receive its timer") end
    out(Controls.Counter, Controls.Counter.Value + 1)
  end)
  Timers.counter:Start(1.0)

  -- ---------- control handlers ----------
  Controls.PanelTouch.EventHandler = guard("PanelTouch", function(ctl)
    T.panel = true
    if not ctl.Boolean then E.lift() end
  end)

  Controls.Refresh.EventHandler = guard("Refresh", function(ctl)
    if ctl.Boolean then bind() end
  end)

  Controls.Picker.EventHandler = guard("Picker", function() bind() end)

  Controls.Tap.EventHandler = guard("Tap", function(ctl)
    if isEcho(ctl) then print("echo ignored: Tap") return end
    if ctl.Boolean then E.text("TAP IN") end
  end)

  Controls.Level.EventHandler = guard("Level", function(ctl)
    if isEcho(ctl) then print("echo ignored: Level") return end
    E.text(string.format("LEVEL %.1f", ctl.Value))
    E.invalidate()
  end)

  local function updateSelected()
    local list = {}
    for i = 1, zones do
      if ZoneSelected[i].Boolean then list[#list + 1] = tostring(i) end
    end
    out(Controls.SelectedList, table.concat(list, ","))
  end
  for i = 1, zones do
    ZoneSelected[i].EventHandler = guard("ZoneSelected", function() updateSelected() end)
    ZoneName[i].EventHandler = guard("ZoneName", function(ctl) E.text("ZONE " .. i .. " " .. ctl.String) end)
  end

  -- Sockets: module level, never local (Q-SYS collects local sockets).
  Sockets = {}
  Controls.Net.EventHandler = guard("Net", function(ctl)
    if not ctl.Boolean then return end
    local udp = UdpSocket.New()
    udp.EventHandler = function(sock, packet)
      E.text("UDP " .. #packet.Data .. " " .. packet.Address)
    end
    udp:Open()
    udp:Send("10.0.0.5", 52381, "\x81\x01\x04\x07\x02\xFF")
    Sockets.udp = udp

    local tcp = TcpSocket.New()
    tcp.ReconnectTimeout = 0
    tcp.ReadTimeout = 5
    tcp.EventHandler = guard("tcp", function(sock, evt, err)
      if evt == TcpSocket.Events.Connected then
        sock:Write("hello\r\n")
      elseif evt == TcpSocket.Events.Data then
        local line = sock:ReadLine(TcpSocket.EOL.CrLf)
        local n = 0
        while line and n < 100 do
          n = n + 1
          E.text("TCP " .. line)
          line = sock:ReadLine(TcpSocket.EOL.CrLf)
        end
      elseif evt == TcpSocket.Events.Closed then
        E.text("TCP CLOSED")
      elseif evt == TcpSocket.Events.Error then
        E.text("TCP ERROR " .. tostring(err))
      end
    end)
    tcp:Connect("10.0.0.6", 5678)
    Sockets.tcp = tcp
  end)

  Controls.Post.EventHandler = guard("Post", function(ctl)
    if not ctl.Boolean then return end
    local body = { name = "fixture", zones = zones, time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time()) }
    HttpClient.Upload{
      Url = "https://example.invalid/hook",
      Method = "POST",
      Headers = { ["Content-Type"] = "application/json" },
      Data = json and json.encode(body) or "{}",
      Timeout = 10,
      EventHandler = guard("http", function(tbl, code, data, err)
        E.text("HTTP " .. tostring(code) .. (err and (" " .. tostring(err)) or ""))
      end),
    }
  end)

  Controls.Save.EventHandler = guard("Save", function(ctl)
    if not ctl.Boolean then return end
    local base = System.IsEmulating and "design" or "media"
    dir.create(base .. "/Fixture")
    local path = base .. "/Fixture/log.csv"
    local f = io.open(path, "a")
    if not f then E.text("NOT SAVED") return end
    f:write(os.date("%Y-%m-%d %H:%M:%S") .. ",fixture\n")
    f:close()
    local n = 0
    local r = io.open(path, "r")
    if r then
      for _ in r:lines() do
        n = n + 1
        if n > 10000 then break end
      end
      r:close()
    end
    Log.Message("fixture saved " .. n)
    E.text("SAVED " .. n)
  end)

  Controls.Crash.EventHandler = guard("Crash", function(ctl)
    if ctl.Boolean then error("deliberate fixture error") end
  end)

  bind()
  E.text("READY")
end
