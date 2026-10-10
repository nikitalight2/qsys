-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: camera drivers (Demo, Q-SYS Camera, VISCA over IP)
--
-- Camera.new(E, kind, opts) returns a driver (spec 3.17):
--   drive(panSpeed, tiltSpeed)   -1..1 each; 0, 0 stops (stops go out three times)
--   zoom(speed)                  -1..1; 0 stops; a zoom change sends only zoom
--   stop()                       pan/tilt and zoom stop
--   home()                       the camera's home preset
--   gotoPosition(pan, tilt, z)   pan/tilt in degrees from home, z 0..1 (nil = keep)
--   getPosition(cb)              cb(pan, tilt, zoomPos) or cb(nil) when unknown
--   status()                     text; also written to CameraStatus
--   close()                      stops and releases sockets
--   onControl(name, index, ctl)  helper for modes: ZoomIn/ZoomOut/CameraIP (returns true when handled)
-- The Demo camera adds drawView(canvas) (480 x 270) and position fields.
-- kinds: "demo", "qsys", "visca" (the property texts "Demo (simulated)",
-- "Q-SYS Camera" and "VISCA over IP" are accepted too).
-- Camera.install(E) gives an engine without a factory one (E.cameraFactory).

Camera = Camera or {}

do
  local floor, abs, min, max = math.floor, math.abs, math.min, math.max
  local sbyte, schar, ssub, sfind, lower = string.byte, string.char, string.sub, string.find, string.lower
  local sformat, concat = string.format, table.concat

  local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
  end
  local function num(v, default)
    v = tonumber(v)
    if v == nil or v ~= v then return default end
    return v
  end
  local function sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
  end
  local function round(v) return floor(v + 0.5) end

  -- ---------- shared helpers over the engine ----------
  -- MaxSpeed / ZoomSpeed are Knob Percent 1..100 (framework-owned); 0..1 here.
  local function knobScale(E, name, default)
    local ok, v = pcall(function()
      local c = E.ctl(name)
      if c == nil then return nil end
      return c.Value
    end)
    if ok and type(v) == "number" then return clamp(v / 100, 0.01, 1) end
    return default
  end

  local function ctlString(E, name)
    local ok, s = pcall(function()
      local c = E.ctl(name)
      if c == nil then return nil end
      return c.String
    end)
    if ok and type(s) == "string" then return s end
    return ""
  end

  local function report(E, driver, text, level)
    driver.statusText = text
    driver.statusLevel = level or "ok"
    pcall(E.out, "CameraStatus", text)
  end

  local function kindOf(kind)
    local k = lower(tostring(kind or ""))
    if sfind(k, "demo", 1, true) then return "demo" end
    if sfind(k, "visca", 1, true) then return "visca" end
    if sfind(k, "q-sys", 1, true) or sfind(k, "qsys", 1, true) then return "qsys" end
    return k
  end

  -- Common member functions a driver can inherit.
  local function baseDriver(E, kind)
    local d = { kind = kind, statusText = "", statusLevel = "ok" }
    function d.status(self) return self.statusText end
    function d.onControl(self, name, index, ctl)
      if name == "ZoomIn" or name == "ZoomOut" then
        local on = false
        pcall(function() on = ctl.Boolean and true or false end)
        if name == "ZoomIn" then self:zoom(on and 1 or 0) else self:zoom(on and -1 or 0) end
        return true
      end
      if name == "CameraIP" and type(self.reconnect) == "function" then
        self:reconnect()
        return true
      end
      if name == "MaxSpeed" or name == "ZoomSpeed" then return true end
      return false
    end
    return d
  end

  -- ================================================================ Demo camera
  local DEMO = {
    panMin = -170, panMax = 170, tiltMin = -30, tiltMax = 90,
    panRate = 60, tiltRate = 40, zoomRate = 0.5,      -- per second at full speed
    hfov = 60, maxZoom = 12, tick = 0.05,
  }

  -- The room, in angles (azimuth right, elevation up) and angular sizes.
  local ROOM = {
    horizon = -6,
    window = { az = -42, el = 12, w = 26, h = 18 },
    screen = { az = 0, el = 14, w = 36, h = 20 },
    table = { az = 0, el = -16, w = 64, h = 18 },
    chairs = { { -28, -11 }, { -12, -8 }, { 12, -8 }, { 28, -11 }, { -22, -26 }, { 22, -26 } },
    door = { az = 46, el = 2, w = 12, h = 30 },
  }

  local function newDemo(E, opts)
    local d = baseDriver(E, "demo")
    d.pan, d.tilt, d.zoomPos = 0, 0, 0       -- degrees, degrees, 0..1
    d.panSpeed, d.tiltSpeed, d.zoomSpeed = 0, 0, 0
    d.target = nil
    d.timer = nil
    d.hfov = num(opts and opts.hfov, DEMO.hfov)
    d.maxZoom = num(opts and opts.maxZoom, DEMO.maxZoom)
    d.lastAt = nil

    local function moving()
      return d.panSpeed ~= 0 or d.tiltSpeed ~= 0 or d.zoomSpeed ~= 0 or d.target ~= nil
    end

    local function step(dt)
      if dt <= 0 then return end
      if d.target then
        local t = d.target
        local done = true
        local dp = t.pan - d.pan
        local mp = DEMO.panRate * dt
        if abs(dp) > mp then d.pan = d.pan + sign(dp) * mp; done = false else d.pan = t.pan end
        local dtl = t.tilt - d.tilt
        local mt = DEMO.tiltRate * dt
        if abs(dtl) > mt then d.tilt = d.tilt + sign(dtl) * mt; done = false else d.tilt = t.tilt end
        if t.zoom then
          local dz = t.zoom - d.zoomPos
          local mz = DEMO.zoomRate * dt
          if abs(dz) > mz then d.zoomPos = d.zoomPos + sign(dz) * mz; done = false else d.zoomPos = t.zoom end
        end
        if done then d.target = nil end
      else
        d.pan = d.pan + d.panSpeed * DEMO.panRate * dt
        d.tilt = d.tilt + d.tiltSpeed * DEMO.tiltRate * dt
        d.zoomPos = d.zoomPos + d.zoomSpeed * DEMO.zoomRate * dt
      end
      d.pan = clamp(d.pan, DEMO.panMin, DEMO.panMax)
      d.tilt = clamp(d.tilt, DEMO.tiltMin, DEMO.tiltMax)
      d.zoomPos = clamp(d.zoomPos, 0, 1)
    end

    local function onTick()
      local now = E.now()
      local dt = d.lastAt and (now - d.lastAt) or DEMO.tick
      d.lastAt = now
      if dt < 0 or dt > 2 then dt = DEMO.tick end
      step(dt)
      E.invalidate()
      if not moving() and d.timer then
        d.timer:cancel()
        d.timer = nil
        d.lastAt = nil
      end
    end

    local function ensureTimer()
      if moving() then
        if not d.timer then
          d.lastAt = E.now()
          d.timer = E.every(DEMO.tick, onTick)
        end
      elseif d.timer then
        d.timer:cancel()
        d.timer = nil
        d.lastAt = nil
      end
      E.invalidate()
    end

    function d.drive(self, ps, ts)
      ps, ts = clamp(num(ps, 0), -1, 1), clamp(num(ts, 0), -1, 1)
      local k = knobScale(E, "MaxSpeed", 0.5)
      self.panSpeed, self.tiltSpeed = ps * k, ts * k
      if ps ~= 0 or ts ~= 0 then self.target = nil end
      ensureTimer()
    end
    function d.zoom(self, s)
      s = clamp(num(s, 0), -1, 1)
      self.zoomSpeed = s * knobScale(E, "ZoomSpeed", 0.5)
      if s ~= 0 then self.target = nil end
      ensureTimer()
    end
    function d.stop(self)
      self.panSpeed, self.tiltSpeed, self.zoomSpeed = 0, 0, 0
      self.target = nil
      ensureTimer()
    end
    function d.gotoPosition(self, pan, tilt, z)
      self.panSpeed, self.tiltSpeed, self.zoomSpeed = 0, 0, 0
      self.target = {
        pan = clamp(num(pan, self.pan), DEMO.panMin, DEMO.panMax),
        tilt = clamp(num(tilt, self.tilt), DEMO.tiltMin, DEMO.tiltMax),
        zoom = (z ~= nil) and clamp(num(z, self.zoomPos), 0, 1) or nil,
      }
      ensureTimer()
    end
    function d.home(self) self:gotoPosition(0, 0, 0) end
    function d.getPosition(self, cb)
      if type(cb) == "function" then cb(self.pan, self.tilt, self.zoomPos) end
      return self.pan, self.tilt, self.zoomPos
    end
    function d.zoomFactor(self) return 1 + self.zoomPos * (self.maxZoom - 1) end
    function d.close(self)
      self:stop()
    end
    function d.status(self)
      return sformat("Demo camera: pan %.0f tilt %.0f zoom x%.1f", self.pan, self.tilt, self:zoomFactor())
    end

    -- The meeting room as seen through pan/tilt/zoom (480 x 270 canvas).
    function d.drawView(self, c)
      local T = E.T
      local W, H = 480, 270
      local zf = self:zoomFactor()
      local hfov = self.hfov / zf
      local ppd = W / hfov                       -- px per degree
      local cx, cy = W / 2, H / 2
      local function X(az) return cx + (az - self.pan) * ppd end
      local function Y(el) return cy - (el - self.tilt) * ppd end
      -- walls and floor
      c:rect(0, 0, W, H, { fill = T.well })
      local hy = clamp(Y(ROOM.horizon), -2, H + 2)
      c:rect(0, 0, W, max(0, hy), { fill = T.panel })
      c:rect(0, hy, W, max(0, H - hy), { fill = Svg.lighten(T.well, 0.08) })
      c:line(0, hy, W, hy, { stroke = T.line, sw = 1 })
      -- window (left), door (right)
      local w = ROOM.window
      c:rect(X(w.az - w.w / 2), Y(w.el + w.h / 2), w.w * ppd, w.h * ppd,
        { fill = Svg.mix(T.accent3, T.panel, 0.6), stroke = T.line, sw = 1 })
      c:line(X(w.az), Y(w.el + w.h / 2), X(w.az), Y(w.el - w.h / 2), { stroke = T.line, sw = 1 })
      local dr = ROOM.door
      c:rect(X(dr.az - dr.w / 2), Y(dr.el + dr.h / 2), dr.w * ppd, dr.h * ppd,
        { fill = Svg.lighten(T.panel, -0.06), stroke = T.line, sw = 1 })
      -- screen
      local s = ROOM.screen
      c:rect(X(s.az - s.w / 2), Y(s.el + s.h / 2), s.w * ppd, s.h * ppd,
        { fill = T.bg, stroke = T.muted, sw = 1.5, rx = 2 })
      c:rect(X(s.az - s.w / 2) + 3, Y(s.el + s.h / 2) + 3, max(0, s.w * ppd - 6), max(0, s.h * ppd - 6),
        { fill = T.accent, opacity = 0.25 })
      -- table and chairs
      local t = ROOM.table
      c:ellipse(X(t.az), Y(t.el), t.w * ppd / 2, t.h * ppd / 2,
        { fill = Svg.lighten(T.panel, 0.12), stroke = T.line, sw = 1 })
      for i = 1, #ROOM.chairs do
        local ch = ROOM.chairs[i]
        c:circle(X(ch[1]), Y(ch[2]), 3.2 * ppd / 2, { fill = T.accent2, opacity = 0.85 })
      end
      -- badge and zoom factor
      c:rect(8, 8, 86, 20, { fill = T.danger, rx = 4, opacity = 0.9 })
      c:text(51, 22, "DEMO CAM", { size = 11, fill = T.onAccent, anchor = "middle", weight = "bold" })
      c:text(W - 10, H - 10, sformat("x%.1f", zf), { size = 13, fill = T.text, anchor = "end", weight = "bold" })
      c:text(10, H - 10, sformat("P %.0f  T %.0f", self.pan, self.tilt), { size = 10, fill = T.muted })
    end

    report(E, d, "Demo camera ready", "ok")
    return d
  end

  -- ================================================================ Q-SYS camera
  local QNAMES = {
    left = { "pan.left", "PanLeft", "pan_left", "PanTiltDrive-Lt" },
    right = { "pan.right", "PanRight", "pan_right", "PanTiltDrive-Rt" },
    up = { "tilt.up", "TiltUp", "tilt_up", "PanTiltDrive-Up" },
    down = { "tilt.down", "TiltDown", "tilt_down", "PanTiltDrive-Dn" },
    upleft = { "pan.left.tilt.up", "PanLeftTiltUp", "pan_left_tilt_up", "PanTiltDrive-UL" },
    upright = { "pan.right.tilt.up", "PanRightTiltUp", "pan_right_tilt_up", "PanTiltDrive-UR" },
    downleft = { "pan.left.tilt.down", "PanLeftTiltDown", "pan_left_tilt_down", "PanTiltDrive-DL" },
    downright = { "pan.right.tilt.down", "PanRightTiltDown", "pan_right_tilt_down", "PanTiltDrive-DR" },
    zoomin = { "zoom.in", "ZoomIn", "zoom_in", "CAM_Zoom-Z+" },
    zoomout = { "zoom.out", "ZoomOut", "zoom_out", "CAM_Zoom-Z-" },
    panspeed = { "setup.pan.speed", "PanSpeed", "pan.speed", "setup_pan_speed", "CAM_Pan-Speed" },
    tiltspeed = { "setup.tilt.speed", "TiltSpeed", "tilt.speed", "setup_tilt_speed", "CAM_Tilt-Speed" },
    zoomspeed = { "setup.zoom.speed", "ZoomSpeed", "zoom.speed", "setup_zoom_speed", "CAM_Zoom-Speed" },
    home = { "preset.home.load", "Home", "PtzCenter", "preset_home_load", "PanTiltDrive-Hm", "home" },
    position = { "ptz.preset", "PtzPreset", "ptz_preset", "ptz.position" },
    privacy = { "toggle.privacy", "Privacy", "privacy" },
  }
  local QKEYS = { "left", "right", "up", "down", "upleft", "upright", "downleft", "downright",
                  "zoomin", "zoomout", "panspeed", "tiltspeed", "zoomspeed", "home", "position", "privacy" }
  local DIR_KEYS = { "left", "right", "up", "down", "upleft", "upright", "downleft", "downright" }

  local function openComponent(name)
    if type(name) ~= "string" or name == "" then return nil end
    if type(Q) == "table" and type(Q.component) == "function" then
      return Q.component(name)
    end
    local ok, comp = pcall(Component.New, name)
    if ok and type(comp) == "table" then return comp end
    return nil
  end

  local function probe(comp, candidates)
    for i = 1, #candidates do
      local n = candidates[i]
      local ok, c = pcall(function() return comp[n] end)
      if ok and type(c) == "table" then
        local okr = pcall(function() return c.Boolean end)
        if okr then return c, n end
      end
    end
    return nil, nil
  end

  local function setBool(ctl, v)
    if ctl == nil then return end
    pcall(function() ctl.Boolean = v end)
  end

  local function newQsys(E, opts)
    local d = baseDriver(E, "qsys")
    d.name = tostring(opts and opts.name or "")
    d.comp = nil
    d.ctl, d.names = {}, {}
    d.pressed = {}            -- direction keys currently held
    d.zoomDir = 0
    d.saved = {}              -- speed control key -> Position before the move
    d.posTemplate = nil
    d.bindAt = nil            -- time of the last binding attempt

    -- Opens the component and probes the candidate control names; a camera
    -- that is not there yet is retried on use, at most once per second.
    function d.bind(self)
      self.bindAt = E.now()
      local comp = openComponent(self.name)
      if comp == nil then
        self.comp = nil
        if self.name == "" then
          report(E, self, "Q-SYS Camera: set the Camera Name property", "warn")
        else
          report(E, self, "No camera component named " .. self.name, "error")
        end
        return false
      end
      self.comp = comp
      self.ctl, self.names = {}, {}
      for i = 1, #QKEYS do
        local k = QKEYS[i]
        local c, n = probe(comp, QNAMES[k])
        self.ctl[k], self.names[k] = c, n
      end
      local parts = {}
      if self.ctl.left and self.ctl.right and self.ctl.up and self.ctl.down then parts[#parts + 1] = "pan/tilt" end
      if self.ctl.zoomin and self.ctl.zoomout then parts[#parts + 1] = "zoom" end
      if self.ctl.home then parts[#parts + 1] = "home" end
      if self.ctl.position then parts[#parts + 1] = "position" end
      if #parts == 0 then
        self.comp = nil
        report(E, self, "Camera " .. self.name .. ": no PTZ controls found (needs Script Access)", "error")
        return false
      elseif not self.ctl.position then
        report(E, self, "Camera " .. self.name .. ": " .. concat(parts, ", ") ..
          "; no position control (framing and dial need one)", "warn")
      else
        report(E, self, "Camera " .. self.name .. ": " .. concat(parts, ", "), "ok")
      end
      return true
    end

    local function ensure()
      if d.comp then return true end
      if d.name == "" then return false end
      if d.bindAt and E.now() - d.bindAt < 1 then return false end
      return d:bind()
    end
    function d.reconnect(self) return self:bind() end

    local function speedPos(key, s)
      local c = d.ctl[key]
      if c == nil then return end
      if d.saved[key] == nil then
        local ok, p = pcall(function() return c.Position end)
        d.saved[key] = (ok and type(p) == "number") and p or false
      end
      pcall(function() c.Position = clamp(s, 0, 1) end)
    end

    local function restoreSpeeds()
      for key, p in pairs(d.saved) do
        local c = d.ctl[key]
        if c and type(p) == "number" then pcall(function() c.Position = p end) end
      end
      d.saved = {}
    end

    local function release(times)
      for i = 1, #DIR_KEYS do
        local k = DIR_KEYS[i]
        if d.pressed[k] then
          for _ = 1, times do setBool(d.ctl[k], false) end
          d.pressed[k] = nil
        end
      end
    end

    function d.drive(self, ps, ts)
      if not ensure() then return end
      ps, ts = clamp(num(ps, 0), -1, 1), clamp(num(ts, 0), -1, 1)
      local want = {}
      local h, v = sign(ps), sign(ts)
      if h ~= 0 or v ~= 0 then
        local diag
        if h ~= 0 and v ~= 0 then
          diag = (v > 0 and "up" or "down") .. (h < 0 and "left" or "right")
          if not self.ctl[diag] then diag = nil end
        end
        if diag then
          want[diag] = true
        else
          if h < 0 then want.left = true elseif h > 0 then want.right = true end
          if v > 0 then want.up = true elseif v < 0 then want.down = true end
        end
      end
      if h == 0 and v == 0 then
        -- a stop: every held direction goes false three times
        release(3)
        restoreSpeeds()
        return
      end
      local k = knobScale(E, "MaxSpeed", 0.5)
      speedPos("panspeed", abs(ps) * k)
      speedPos("tiltspeed", abs(ts) * k)
      -- release what is no longer wanted before pressing anything new
      for i = 1, #DIR_KEYS do
        local dk = DIR_KEYS[i]
        if self.pressed[dk] and not want[dk] then
          setBool(self.ctl[dk], false)
          self.pressed[dk] = nil
        end
      end
      for i = 1, #DIR_KEYS do
        local dk = DIR_KEYS[i]
        if want[dk] and not self.pressed[dk] then
          setBool(self.ctl[dk], true)
          self.pressed[dk] = true
        end
      end
    end

    function d.zoom(self, s)
      if not ensure() then return end
      s = clamp(num(s, 0), -1, 1)
      local dir = sign(s)
      if dir ~= 0 then speedPos("zoomspeed", abs(s) * knobScale(E, "ZoomSpeed", 0.5)) end
      if dir ~= 0 and self.zoomDir ~= dir then
        -- the old direction is released before the new one is pressed
        if self.zoomDir > 0 then setBool(self.ctl.zoomin, false)
        elseif self.zoomDir < 0 then setBool(self.ctl.zoomout, false) end
      end
      if dir > 0 then setBool(self.ctl.zoomin, true)
      elseif dir < 0 then setBool(self.ctl.zoomout, true)
      else
        for _ = 1, 3 do
          setBool(self.ctl.zoomin, false)
          setBool(self.ctl.zoomout, false)
        end
        if self.saved.zoomspeed ~= nil then
          local c = self.ctl.zoomspeed
          if c and type(self.saved.zoomspeed) == "number" then
            local p = self.saved.zoomspeed
            pcall(function() c.Position = p end)
          end
          self.saved.zoomspeed = nil
        end
      end
      self.zoomDir = dir
    end

    function d.stop(self)
      if not self.comp then return end
      release(3)
      self:zoom(0)
      restoreSpeeds()
    end

    function d.home(self)
      if not ensure() then return false end
      local c = self.ctl.home
      if c == nil then return false end
      local ok = pcall(function() c:Trigger() end)
      if not ok then
        setBool(c, true)
        setBool(c, false)
      end
      return true
    end

    function d.privacy(self, on)
      if not ensure() then return false end
      local c = self.ctl.privacy
      if c == nil then return false end
      setBool(c, on and true or false)
      return true
    end

    -- ptz.preset is a String of numbers (format undocumented): the first three
    -- are read as pan, tilt and zoom; writes keep the shape of the last read.
    local function parseNumbers(s)
      local out = {}
      for n in string.gmatch(tostring(s or ""), "[-%d%.]+") do
        local v = tonumber(n)
        if v then out[#out + 1] = v end
        if #out >= 8 then break end
      end
      return out
    end

    function d.getPosition(self, cb)
      local c = ensure() and self.ctl.position or nil
      if c == nil then
        if type(cb) == "function" then cb(nil) end
        return nil
      end
      local ok, s = pcall(function() return c.String end)
      local nums = ok and parseNumbers(s) or {}
      if #nums < 2 then
        if type(cb) == "function" then cb(nil) end
        return nil
      end
      self.posTemplate = s
      local z = nums[3]
      if z ~= nil then
        if z > 1 and z <= 100 then z = z / 100 elseif z > 100 then z = z / 16384 end
        z = clamp(z, 0, 1)
      end
      if type(cb) == "function" then cb(nums[1], nums[2], z) end
      return nums[1], nums[2], z
    end

    function d.gotoPosition(self, pan, tilt, z)
      local c = ensure() and self.ctl.position or nil
      if c == nil then return false end
      local vals = { num(pan, 0), num(tilt, 0), z ~= nil and clamp(num(z, 0), 0, 1) or nil }
      local text
      if type(self.posTemplate) == "string" and #parseNumbers(self.posTemplate) >= 2 then
        local i = 0
        text = string.gsub(self.posTemplate, "[-%d%.]+", function(n)
          if tonumber(n) == nil then return n end
          i = i + 1
          if i <= 3 and vals[i] ~= nil then return sformat("%.4f", vals[i]) end
          return n
        end)
      else
        text = sformat("%.4f %.4f", vals[1], vals[2])
        if vals[3] then text = text .. sformat(" %.4f", vals[3]) end
      end
      pcall(function() c.String = text end)
      self.posTemplate = text       -- a later write without zoom keeps the zoom just sent
      return true
    end

    function d.close(self)
      if self.comp then self:stop() end
    end

    d:bind()
    return d
  end

  -- ================================================================ VISCA over IP
  -- Per-brand table: transport, port, Sony header, speed limits, position nibbles and scales.
  -- pos scale: units per degree (16-bit cameras: 0x2200 = 170 degrees).
  local SCALE16 = 0x2200 / 170
  local BRANDS = {
    ["PTZOptics"] = { transport = "tcp", port = 5678, header = false, panMax = 0x18, tiltMax = 0x14 },
    ["Sony"] = { transport = "udp", port = 52381, header = true, panMax = 0x18, tiltMax = 0x17 },
    ["AVer"] = { transport = "udp", port = 52381, header = true, panMax = 0x18, tiltMax = 0x18 },
    ["Lumens"] = { transport = "udp", port = 52381, header = true, panMax = 0x18, tiltMax = 0x18 },
    ["Marshall"] = { transport = "udp", port = 52381, header = true, panMax = 0x18, tiltMax = 0x18 },
    ["BirdDog"] = { transport = "udp", port = 52381, header = true, panMax = 0x15, tiltMax = 0x12 },
    ["Avonic"] = { transport = "udp", port = 52381, header = true, panMax = 0x18, tiltMax = 0x18 },
    ["Generic Sony header"] = { transport = "udp", port = 52381, header = true, panMax = 0x18, tiltMax = 0x18 },
    ["Generic raw TCP"] = { transport = "tcp", port = 5678, header = false, panMax = 0x18, tiltMax = 0x18 },
  }
  local BRAND_DEFAULT = "PTZOptics"
  local ZOOM_MAX = 0x4000
  local INQUIRY_TIMEOUT = 1.0
  local MISSES_FOR_WARNING = 3
  local QUEUE_CAP = 16

  local function be16(n) return schar(floor(n / 256) % 256, n % 256) end
  local function be32(n)
    return schar(floor(n / 16777216) % 256, floor(n / 65536) % 256, floor(n / 256) % 256, n % 256)
  end
  -- Signed value -> n nibbles, each in its own byte (0p 0q 0r 0s).
  local function nibbles(v, n)
    v = round(v)
    local lim = 2 ^ (4 * n)
    local half = lim / 2
    v = clamp(v, -half, half - 1)
    if v < 0 then v = v + lim end
    local out = {}
    for i = n, 1, -1 do
      out[i] = schar(v % 16)
      v = floor(v / 16)
    end
    return concat(out)
  end
  local function unnibbles(s, from, n, signed)
    local v = 0
    for i = 0, n - 1 do
      v = v * 16 + (sbyte(s, from + i) % 16)
    end
    if signed and v >= 2 ^ (4 * n - 1) then v = v - 2 ^ (4 * n) end
    return v
  end

  local function newVisca(E, opts)
    local d = baseDriver(E, "visca")
    local brandName = tostring(opts and opts.brand or BRAND_DEFAULT)
    local brand = BRANDS[brandName]
    if brand == nil then brandName = BRAND_DEFAULT; brand = BRANDS[brandName] end
    d.brand, d.brandName = brand, brandName
    d.ip, d.port = nil, brand.port
    d.sock = nil
    d.seq = 1
    d.sent = 0
    d.lastDrive = nil           -- the last pan/tilt drive payload (dedup)
    d.lastZoom = nil
    d.vv, d.ww = 6, 6           -- last speeds, reused by stops
    d.queue = {}                -- bytes waiting for a TCP connection
    d.buf = ""                  -- TCP reply stream
    d.pending = nil             -- a position inquiry in flight
    d.replies, d.posReplies, d.misses = 0, 0, 0
    d.warnedNoPos = false
    d.pan, d.tilt, d.zoomPos = nil, nil, nil
    d.lastReply = ""

    local function describe()
      local where = (d.ip and d.ip ~= "") and (d.ip .. ":" .. tostring(d.port)) or "(no IP)"
      return sformat("VISCA %s %s %s", brandName, string.upper(brand.transport), where)
    end

    -- ---- replies ----
    local function onReply(p)
      -- p: one VISCA message without the IP header, ending in FF
      local n = #p
      if n < 3 then return end
      d.replies = d.replies + 1
      d.lastReply = p
      local b1, b2 = sbyte(p, 1), sbyte(p, 2)
      if b1 % 16 ~= 0 or floor(b1 / 16) < 8 then return end     -- not y0
      local hi = floor(b2 / 16)
      if hi == 6 then
        report(E, d, describe() .. ": camera error " .. sformat("%02X", sbyte(p, 3) or 0), "warn")
        return
      end
      if hi ~= 5 then return end                                  -- ACK or other
      local pend = d.pending
      if n == 7 then
        -- zoom position 90 50 0p 0q 0r 0s FF
        d.zoomPos = clamp(unnibbles(p, 3, 4, false) / ZOOM_MAX, 0, 1)
        if pend then pend.zoom = d.zoomPos end
      elseif n == 11 or n == 12 or n == 13 then
        local pn = (n == 11) and 4 or 5
        local tn = n - 3 - pn
        local scale = (pn == 4) and SCALE16 or (0x15400 / 170)
        d.pan = unnibbles(p, 3, pn, true) / scale
        d.tilt = unnibbles(p, 3 + pn, tn, true) / scale
        d.posReplies = d.posReplies + 1
        d.misses = 0
        if pend then pend.pan, pend.tilt = d.pan, d.tilt end
      end
      if pend and pend.pan ~= nil and pend.zoom ~= nil then
        d.pending = nil
        if pend.timer then pend.timer:cancel() end
        if d.statusLevel ~= "ok" then report(E, d, describe() .. ": OK", "ok") end
        if type(pend.cb) == "function" then pend.cb(pend.pan, pend.tilt, pend.zoom) end
      end
    end

    local function splitMessages(data)
      local from, len, count = 1, #data, 0
      while from <= len and count < 32 do
        local e = sfind(data, "\255", from, true)
        if not e then break end
        onReply(ssub(data, from, e))
        from = e + 1
        count = count + 1
      end
      return from
    end

    local function onUdp(data)
      if type(data) ~= "string" then return end
      if brand.header and #data >= 8 then data = ssub(data, 9) end
      splitMessages(data)
    end

    local function onTcp(data)
      if type(data) ~= "string" then return end
      d.buf = d.buf .. data
      if #d.buf > 512 then d.buf = ssub(d.buf, -256) end
      local from = splitMessages(d.buf)
      d.buf = ssub(d.buf, from)
    end

    -- ---- transport ----
    local function flushQueue()
      if not (d.sock and d.sock.connected) then return end
      local q = d.queue
      d.queue = {}
      for i = 1, #q do d.sock:send(q[i]) end
    end

    local function readIp()
      local s = ctlString(E, "CameraIP")
      s = s:gsub("^%s+", ""):gsub("%s+$", "")
      local ip, port = s:match("^([^:]+):(%d+)$")
      if ip then return ip, tonumber(port) end
      return s, brand.port
    end

    local function send(payload, inquiry)
      if not d.sock then return false end
      local bytes = payload
      if brand.header then
        bytes = (inquiry and "\1\16" or "\1\0") .. be16(#payload) .. be32(d.seq) .. payload
        d.seq = d.seq + 1
        if d.seq > 0xFFFFFFFF then d.seq = 1 end
      end
      d.sent = d.sent + 1
      if brand.transport == "udp" then
        return d.sock:send(bytes)
      end
      if d.sock.connected then return d.sock:send(bytes) end
      if #d.queue < QUEUE_CAP then d.queue[#d.queue + 1] = bytes end
      return true
    end

    function d.connect(self)
      local ip, port = readIp()
      self.ip, self.port = ip, port or brand.port
      if ip == "" then
        report(E, d, "VISCA " .. brandName .. ": enter the camera IP on the Setup page", "warn")
        return false
      end
      if brand.transport == "udp" then
        self.sock = Q.udp({ ip = ip, port = self.port, onData = function(data) onUdp(data) end })
        if brand.header then
          -- Sony RESET control command; the next sequence number is 1.
          self.sock:send("\2\0\0\1\0\0\0\0\1")
          self.seq = 1
        end
      else
        self.sock = Q.tcp({ ip = ip, port = self.port, onData = function(data) onTcp(data) end,
          onEvent = function(evt)
            if self.sock and self.sock.connected then flushQueue() end
          end })
      end
      report(E, d, describe(), "ok")
      return true
    end

    function d.reconnect(self)
      local ip, port = readIp()
      if self.sock and ip == self.ip and (port or brand.port) == self.port then return end
      if self.sock then self.sock:close() end
      self.sock, self.queue, self.buf = nil, {}, ""
      self.lastDrive, self.lastZoom = nil, nil
      self:connect()
    end

    local function ensure()
      if d.sock == nil then d:connect() end
      return d.sock ~= nil
    end

    -- ---- commands ----
    local function speedByte(s, maxv)
      local v = round(abs(s) * maxv)
      return clamp(v, 1, maxv)
    end

    function d.drive(self, ps, ts)
      if not ensure() then return end
      ps, ts = clamp(num(ps, 0), -1, 1), clamp(num(ts, 0), -1, 1)
      local h, v = sign(ps), sign(ts)
      local k = knobScale(E, "MaxSpeed", 0.5)
      if h == 0 and v == 0 then
        local stop = "\129\1\6\1" .. schar(self.vv, self.ww) .. "\3\3\255"
        for _ = 1, 3 do send(stop) end
        self.lastDrive = nil
        return
      end
      self.vv = speedByte(ps * k, brand.panMax)
      self.ww = speedByte(ts * k, brand.tiltMax)
      local hb = (h < 0) and 1 or ((h > 0) and 2 or 3)
      local vb = (v > 0) and 1 or ((v < 0) and 2 or 3)
      local cmd = "\129\1\6\1" .. schar(self.vv, self.ww, hb, vb) .. "\255"
      if cmd ~= self.lastDrive then
        self.lastDrive = cmd
        send(cmd)
      end
    end

    function d.zoom(self, s)
      if not ensure() then return end
      s = clamp(num(s, 0), -1, 1)
      local dir = sign(s)
      if dir == 0 then
        for _ = 1, 3 do send("\129\1\4\7\0\255") end
        self.lastZoom = nil
        return
      end
      local p = clamp(round(abs(s) * knobScale(E, "ZoomSpeed", 0.5) * 7), 0, 7)
      local cmd = "\129\1\4\7" .. schar((dir > 0 and 0x20 or 0x30) + p) .. "\255"
      if cmd ~= self.lastZoom then
        self.lastZoom = cmd
        send(cmd)
      end
    end

    function d.stop(self)
      self:drive(0, 0)
      self:zoom(0)
    end

    function d.home(self)
      if not ensure() then return end
      self.lastDrive = nil
      send("\129\1\6\4\255")
    end

    function d.gotoPosition(self, pan, tilt, z)
      if not ensure() then return end
      local k = knobScale(E, "MaxSpeed", 0.5)
      local vv = speedByte(k, brand.panMax)
      local ww = speedByte(k, brand.tiltMax)
      local pn, tn = brand.panNibbles or 4, brand.tiltNibbles or 4
      local scale = brand.scale or SCALE16
      local cmd = "\129\1\6\2" .. schar(vv, ww) .. nibbles(num(pan, 0) * scale, pn)
        .. nibbles(num(tilt, 0) * scale, tn) .. "\255"
      self.lastDrive = nil
      send(cmd)
      if z ~= nil then
        send("\129\1\4\71" .. nibbles(clamp(num(z, 0), 0, 1) * ZOOM_MAX, 4) .. "\255")
      end
    end

    function d.getPosition(self, cb)
      if not ensure() then
        if type(cb) == "function" then cb(nil) end
        return
      end
      if self.pending then
        -- one inquiry at a time: the newer caller replaces the older one
        local old = self.pending
        if old.timer then old.timer:cancel() end
        if type(old.cb) == "function" then old.cb(nil) end
      end
      local pend = { cb = cb, pan = nil, tilt = nil, zoom = nil }
      self.pending = pend
      pend.timer = E.after(INQUIRY_TIMEOUT, function()
        if self.pending ~= pend then return end
        self.pending = nil
        self.misses = self.misses + 1
        if self.posReplies == 0 and self.misses >= MISSES_FOR_WARNING and not self.warnedNoPos then
          self.warnedNoPos = true
          report(E, d, describe() .. ": no answer to position inquiries (framing and dial need them)", "warn")
        end
        if type(cb) == "function" then cb(nil) end
      end)
      send("\129\9\6\18\255", true)
      send("\129\9\4\71\255", true)
    end

    function d.status(self)
      return self.statusText
    end

    function d.close(self)
      if self.sock then
        pcall(function() self:stop() end)
        self.sock:close()
        self.sock = nil
      end
      if self.pending and self.pending.timer then self.pending.timer:cancel() end
      self.pending = nil
    end

    d:connect()
    return d
  end

  -- ================================================================ factory
  function Camera.new(E, kind, opts)
    local k = kindOf(kind)
    if k == "demo" then return newDemo(E, opts or {}) end
    if k == "qsys" then return newQsys(E, opts or {}) end
    if k == "visca" then return newVisca(E, opts or {}) end
    return nil
  end

  Camera.kinds = { "demo", "qsys", "visca" }
  Camera.brands = BRANDS

  -- An engine that lacks E.cameraFactory gets one; an engine that has one keeps it.
  function Camera.install(E)
    if type(E) ~= "table" then return false end
    if type(E.cameraFactory) ~= "function" then
      function E.cameraFactory(kind, opts)
        local ok, cam = pcall(Camera.new, E, kind, opts)
        if ok then return cam end
        if type(E.log) == "function" then E.log("Camera: " .. tostring(cam)) end
        return nil
      end
    end
    return true
  end
end
