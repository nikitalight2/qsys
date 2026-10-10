-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: PTZ Pad mode
--
-- Drag to aim (spec 3.4). The pad is a map of everything the camera can
-- reach: a drag moves the aim like a trackpad (relative, scaled by
-- Sensitivity), so a plain tap moves nothing and a double tap sends the
-- aim home. Outputs: Pan, Tilt (0..1 absolute aim, 0.5 = home), PanSpeed,
-- TiltSpeed (-1..1 while dragging; 1 = one pad width per half second),
-- the direction LEDs, Home (Both), InvertPan / InvertTilt (Both), HFOV and
-- OpticalZoom (the camera's horizontal field of view in degrees and its
-- maximum optical zoom factor: they size the view box drawn on the pad).
-- With a camera set (E.camera) the aim is sent as an absolute position
-- (pan -170..170 deg, tilt -90..90 deg) at most ten times a second while
-- dragging, Zoom +/- drive the camera's zoom, and the Camera View shows
-- the Demo camera's scene.

Modes = Modes or {}

do
  local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
  local sformat = string.format

  local HINT = "Drag to aim. Double tap = home"
  local PAN_SPAN, TILT_SPAN = 340, 180      -- degrees across the pad (Pan 0..1, Tilt 0..1)
  local SPEED_REF = 2.0                     -- pad widths per second that read as speed 1
  local DRAG_START = 12                     -- px: a touch that moves less is a tap (spec 5.4)
  local LED_ON = 0.02                       -- |speed| above which a direction LED lights
  local STALL = 0.15                        -- s without a report: speeds fall to 0
  local HOME_TIME = 0.25                    -- s: the aim glides home
  local CAM_RATE = 0.1                      -- s between absolute positions sent to a camera
  local ZOOM_POLL = 0.2                     -- s between zoom readings while Zoom +/- is held
  local HOME_GUARD = 0.5                    -- s: the trailing edge of a Home pulse is not a second home
  local HOME_ZOOM_READS = { 0.2, 1.0, 2.5 } -- s after a home: the zoom is re-read from the camera

  local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
  end

  Modes["PTZ Pad"] = {
    id = "ptzpad",
    pretty = "PTZ Pad",
    hint = HINT,

    controls = function(C, props)
      C.add{ Name = "Pan", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, DefaultValue = 0.5, PinStyle = "Output" }
      C.add{ Name = "Tilt", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, DefaultValue = 0.5, PinStyle = "Output" }
      C.add{ Name = "PanSpeed", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1, DefaultValue = 0, PinStyle = "Output" }
      C.add{ Name = "TiltSpeed", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1, DefaultValue = 0, PinStyle = "Output" }
      C.add{ Name = "DirLeft", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" }
      C.add{ Name = "DirRight", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" }
      C.add{ Name = "DirUp", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" }
      C.add{ Name = "DirDown", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" }
      C.add{ Name = "Sensitivity", ControlType = "Knob", ControlUnit = "Float", Min = 0.2, Max = 3, DefaultValue = 1, PinStyle = "Input" }
      C.add{ Name = "Home", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both" }
      C.add{ Name = "InvertPan", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" }
      C.add{ Name = "InvertTilt", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" }
      C.add{ Name = "HFOV", ControlType = "Knob", ControlUnit = "Float", Min = 20, Max = 120, DefaultValue = 60, PinStyle = "Input", Group = "Camera" }
      C.add{ Name = "OpticalZoom", ControlType = "Knob", ControlUnit = "Float", Min = 1, Max = 40, DefaultValue = 12, PinStyle = "Input", Group = "Camera" }
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "AIM")
        L.sideButton(ctx, "Home", "HOME")
        L.sideButton(ctx, "InvertPan", "FLIP PAN")
        L.sideButton(ctx, "InvertTilt", "FLIP TILT")
      elseif page == "Setup" then
        local ix, iy = L.section(ctx, "P T Z  P A D", 48)
        L.grid({ "Sensitivity", "HFOV", "OpticalZoom" }, ix, iy, 3, 96, 48)
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local inset = min(10, floor(min(W, H) * 0.04))
      local cw, ch = W - 2 * inset, H - 2 * inset      -- the scene card
      local self = {
        pan = 0.5, tilt = 0.5,          -- the aim
        panSpeed = 0, tiltSpeed = 0,
        down = false, dragging = false,
        fx = 0, fy = 0,                 -- finger
        accX = 0, accY = 0,             -- movement before the drag threshold
        lastT = nil,                    -- time of the last report that moved the aim (or the touch start)
        stall = nil,                    -- timer that zeroes the speeds
        homing = nil,                   -- { x0, y0, t } while the aim glides home
        homeAt = -10,
        homeEdge = false,               -- a Home press (Boolean true) was handled; its release is not a second home
        zoomRead = {},                  -- pending zoom re-reads after a home
        camAt = -10, camPending = false, camTimer = nil,
        camZoom = 0,                    -- zoom position 0..1 read from the camera
        zooming = false, zoomPollAt = 0,
        grid = nil,
      }

      -- ---------- controls ----------
      local function knob(name, default)
        local c = E.ctl(name)
        if c == nil then return default end
        local v = tonumber(c.Value)
        if v == nil then return default end
        return v
      end
      local function toggle(name)
        local c = E.ctl(name)
        return c ~= nil and c.Boolean == true
      end
      local function sensitivity() return clamp(knob("Sensitivity", 1), 0.2, 3) end
      local function hfov() return clamp(knob("HFOV", 60), 20, 120) end
      local function opticalZoom() return clamp(knob("OpticalZoom", 12), 1, 40) end

      local function zoomFactor()
        return 1 + clamp(self.camZoom, 0, 1) * (opticalZoom() - 1)
      end

      local function panDeg() return (self.pan - 0.5) * PAN_SPAN end
      local function tiltDeg() return (self.tilt - 0.5) * TILT_SPAN end

      local function gridRaw()
        if self.grid then return self.grid end
        local scratch = Svg.new(W, H, { limit = 20000 })
        Shapes.gridDots(scratch, T, cw, ch, 24)
        self.grid = '<g transform="translate(' .. Svg.num(inset) .. " " .. Svg.num(inset) .. ')">'
          .. table.concat(scratch.parts) .. "</g>"
        return self.grid
      end

      -- ---------- camera ----------
      local function cam() return E.camera end

      local function readZoom()
        local c = cam()
        if c == nil or type(c.getPosition) ~= "function" then return end
        pcall(c.getPosition, c, function(p, t, z)
          if type(z) == "number" and z ~= self.camZoom then
            self.camZoom = clamp(z, 0, 1)
            E.invalidate()
          end
        end)
      end

      local function sendAim()
        local c = cam()
        self.camAt = E.now()
        self.camPending = false
        if c == nil or type(c.gotoPosition) ~= "function" then return end
        pcall(c.gotoPosition, c, panDeg(), tiltDeg(), nil)
      end

      -- Absolute positions go out at most every CAM_RATE seconds; the last
      -- aim of a burst is always sent.
      local function aimChanged(now)
        if cam() == nil then return end
        local wait = CAM_RATE - (now - self.camAt)
        if wait <= 0 then
          if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
          sendAim()
        elseif not self.camPending then
          self.camPending = true
          self.camTimer = E.after(wait, function()
            self.camTimer = nil
            if self.camPending then sendAim() end
          end)
        end
      end

      local function flushAim()
        if self.camPending then
          if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
          sendAim()
        end
      end

      -- ---------- outputs ----------
      local function outAim()
        E.out("Pan", self.pan)
        E.out("Tilt", self.tilt)
      end

      local function setSpeeds(ps, ts)
        ps, ts = clamp(ps, -1, 1), clamp(ts, -1, 1)
        if abs(ps) < 1e-9 then ps = 0 end
        if abs(ts) < 1e-9 then ts = 0 end
        self.panSpeed, self.tiltSpeed = ps, ts
        E.out("PanSpeed", ps)
        E.out("TiltSpeed", ts)
        E.out("DirLeft", ps < -LED_ON)
        E.out("DirRight", ps > LED_ON)
        E.out("DirUp", ts > LED_ON)
        E.out("DirDown", ts < -LED_ON)
      end

      local function cancelStall()
        if self.stall then self.stall:cancel(); self.stall = nil end
      end

      local function armStall()
        cancelStall()
        self.stall = E.after(STALL, function()
          self.stall = nil
          setSpeeds(0, 0)
          E.invalidate()
        end)
      end

      -- Applies a finger movement (pad px) to the aim.
      local function applyMove(dx, dy, dt)
        local s = sensitivity()
        local sx = toggle("InvertPan") and -1 or 1
        local sy = toggle("InvertTilt") and -1 or 1
        local dpan = sx * dx / cw * s
        local dtilt = -sy * dy / ch * s
        self.pan = clamp(self.pan + dpan, 0, 1)
        self.tilt = clamp(self.tilt + dtilt, 0, 1)
        if dt <= 0 then dt = 1 / 30 end
        setSpeeds(sx * (dx / dt) / (cw * SPEED_REF) * s, -sy * (dy / dt) / (ch * SPEED_REF) * s)
        armStall()
      end

      local function goHome(now, pulseOut)
        self.homeAt = now
        self.homing = { x0 = self.pan, y0 = self.tilt, t = 0 }
        if self.pan == 0.5 and self.tilt == 0.5 then self.homing = nil end
        setSpeeds(0, 0)
        E.setGesture("HOME")
        if pulseOut then E.pulse("Home") end
        local c = cam()
        if c and type(c.home) == "function" then
          if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
          self.camPending = false
          self.camAt = now
          pcall(c.home, c)
          -- Whether the home preset resets the zoom is the camera's business
          -- (the Demo does, a Q-SYS or VISCA home leaves it): re-read it, and
          -- again later for a camera that glides there.
          for i = 1, #HOME_ZOOM_READS do
            if self.zoomRead[i] then self.zoomRead[i]:cancel() end
            self.zoomRead[i] = E.after(HOME_ZOOM_READS[i], function()
              self.zoomRead[i] = nil
              readZoom()
            end)
          end
        end
        if self.homing then E.animate(true) end
        E.invalidate()
      end

      -- ---------- touches ----------
      function self:onTouchStart(x, y, t)
        self.down, self.dragging = true, false
        self.fx, self.fy, self.lastT = x, y, t
        self.accX, self.accY = 0, 0
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        self.fx, self.fy = x, y
        if not self.dragging then
          -- Below the drag threshold nothing moves (a tap moves nothing);
          -- the whole movement so far applies once the drag is certain.
          self.accX, self.accY = self.accX + dx, self.accY + dy
          if sqrt(self.accX * self.accX + self.accY * self.accY) <= DRAG_START then
            return
          end
          self.dragging = true
          dx, dy = self.accX, self.accY
          self.accX, self.accY = 0, 0
        end
        -- The speed is the movement applied now over the time since the last
        -- applied movement (the touch start while accumulating, the last
        -- report before a pause on a resumed drag): no spike at either.
        local dt = self.lastT and (t - self.lastT) or 0
        self.lastT = t
        applyMove(dx, dy, dt)
        outAim()
        aimChanged(t)
        E.invalidate()
      end

      function self:onTouchEnd(x, y, t, info)
        self.down, self.dragging = false, false
        cancelStall()
        setSpeeds(0, 0)
        flushAim()
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        -- The same drag goes on. The engine's next onTouchMove carries the
        -- distance covered while the lift was pending, so the aim catches
        -- up by exactly that; lastT is left at the last applied report so
        -- the speed of that catch-up spans the pause instead of one frame.
        self.down, self.dragging = true, true
        self.fx, self.fy = x, y
        self.accX, self.accY = 0, 0
        E.invalidate()
      end

      function self:onGesture(g)
        if g.type == "double" then goHome(g.t or E.now(), true) end
      end

      function self:onLock(locked)
        if locked then
          self.down, self.dragging = false, false
          cancelStall()
          setSpeeds(0, 0)
          if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
          self.camPending = false
          local c = cam()
          if c and type(c.stop) == "function" then pcall(c.stop, c) end
        end
        E.invalidate()
      end

      -- ---------- controls ----------
      function self:onControl(name, index, ctl)
        local now = E.now()
        if name == "Home" then
          -- A press (Boolean true) homes; its release never homes again,
          -- however long the pin was held (a toggle or a held button wired
          -- to Home). A Trigger's handler may run with Boolean already
          -- false and no press seen: that homes too, unless it is the
          -- trailing edge of a pulse handled moments ago.
          if ctl.Boolean then
            self.homeEdge = true
            goHome(now, false)
          elseif self.homeEdge then
            self.homeEdge = false
          elseif now - self.homeAt >= HOME_GUARD then
            goHome(now, false)
          end
          return
        end
        if name == "InvertPan" or name == "InvertTilt" or name == "Sensitivity"
           or name == "HFOV" or name == "OpticalZoom" then
          E.invalidate()
          return
        end
        local c = cam()
        if c == nil then return end
        if name == "ZoomIn" or name == "ZoomOut" then
          if type(c.onControl) == "function" then pcall(c.onControl, c, name, index, ctl) end
          self.zooming = ctl.Boolean and true or false
          if self.zooming then
            self.zoomPollAt = now
            E.animate(true)
          else
            E.after(ZOOM_POLL, readZoom)
          end
          E.invalidate()
          return
        end
        if type(c.onControl) == "function" then pcall(c.onControl, c, name, index, ctl) end
      end

      function self:tick(dt)
        local busy = false
        if self.homing then
          local h = self.homing
          h.t = h.t + dt
          local k = clamp(h.t / HOME_TIME, 0, 1)
          k = k * (2 - k)                      -- ease out
          self.pan = h.x0 + (0.5 - h.x0) * k
          self.tilt = h.y0 + (0.5 - h.y0) * k
          if k >= 1 then
            self.pan, self.tilt = 0.5, 0.5
            self.homing = nil
          else
            busy = true
          end
          outAim()
          E.invalidate()
        end
        if self.zooming then
          busy = true
          local now = E.now()
          if now - self.zoomPollAt >= ZOOM_POLL - 0.0005 then
            self.zoomPollAt = now
            readZoom()
          end
        end
        if not busy then E.animate(false) end
      end

      function self:onStart()
        outAim()
        setSpeeds(0, 0)
        readZoom()
      end

      -- ---------- drawing ----------
      local function chevron(c, name, x, y, on)
        Shapes.icon(c, name, x, y, 20, on and T.accent2 or T.line)
      end

      function self:draw(c)
        c:rect(inset, inset, cw, ch, { fill = T.panel, stroke = T.line, sw = 1, rx = max(4, floor(inset * 1.2)) })
        c:raw(gridRaw())
        -- home mark at the centre of the scene
        local hx, hy = inset + cw / 2, inset + ch / 2
        c:line(hx - 6, hy, hx + 6, hy, { stroke = T.muted, sw = 1, opacity = 0.7 })
        c:line(hx, hy - 6, hx, hy + 6, { stroke = T.muted, sw = 1, opacity = 0.7 })
        -- the view box: what the camera sees at this aim, HFOV and zoom
        local ax = inset + self.pan * cw
        local ay = inset + (1 - self.tilt) * ch
        local fov = hfov() / zoomFactor()
        local vw = max(8, fov / PAN_SPAN * cw)
        local vh = max(6, fov * 9 / 16 / TILT_SPAN * ch)
        c:rect(ax - vw / 2, ay - vh / 2, vw, vh, { fill = T.accent, opacity = 0.12, rx = 3 })
        c:rect(ax - vw / 2, ay - vh / 2, vw, vh, { fill = "none", stroke = T.accent, sw = 1.5, rx = 3 })
        Shapes.crosshair(c, T, ax, ay, W, H)
        Shapes.dot(c, T, ax, ay, self.down and 7 or 5)
        -- direction chevrons on the card edges
        local pad = inset + 14
        chevron(c, "left", pad, H / 2, self.panSpeed < -LED_ON)
        chevron(c, "right", W - pad, H / 2, self.panSpeed > LED_ON)
        chevron(c, "up", W / 2, pad, self.tiltSpeed > LED_ON)
        chevron(c, "down", W / 2, H - pad, self.tiltSpeed < -LED_ON)
        -- the finger while dragging
        if self.down and self.dragging then
          c:circle(self.fx, self.fy, 4, { fill = T.muted, opacity = 0.6 })
        end
        -- readout
        local txt = sformat("PAN %+d  TILT %+d", floor(panDeg() + 0.5), floor(tiltDeg() + 0.5))
        if cam() then txt = txt .. sformat("  ZOOM x%.1f", zoomFactor()) end
        c:textFit(W / 2, inset + 20, cw - 16, txt, { size = 12, fill = T.text, anchor = "middle", weight = "bold" })
        local flips = (toggle("InvertPan") and "FLIP PAN " or "") .. (toggle("InvertTilt") and "FLIP TILT" or "")
        if flips ~= "" then
          c:textFit(W - inset - 8, inset + 36, cw - 16, flips, { size = 10, fill = T.accent2, anchor = "end" })
        end
        if E.hint and not self.down then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- Camera View (480 x 270): the Demo camera's scene.
      function self:drawCamera(c)
        local cm = cam()
        if cm and type(cm.drawView) == "function" then
          cm:drawView(c)
        else
          c:rect(0, 0, 480, 270, { fill = T.well })
          c:text(240, 140, "No camera view", { size = 14, fill = T.muted, anchor = "middle" })
        end
      end

      return self
    end,
  }
end
