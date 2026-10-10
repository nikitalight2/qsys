-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Dial mode
--
-- An endless jog wheel (spec 3.6). The wheel turns with the finger's angle
-- around the pad centre; the inner 30 % of the wheel is a dead centre that
-- does nothing, and the first 8 degrees of every new touch are settling and
-- move nothing. A clockwise turn raises DialValue (0..1, pin Both), bounded
-- at both ends; `Turns` is how many full turns cover the range. `Detents`
-- notches per turn each pulse StepUp or StepDown once as the wheel clicks
-- past them (the step pulses keep coming at the ends of the range: the
-- wheel is endless, only the level is bounded). `DialTarget` names a control
-- ("CodeName~control") that is driven position-wise and followed when it
-- changes elsewhere, even while a finger rests on the wheel; DialValue
-- written from outside is followed the same way. With a camera set the
-- level is the camera's zoom position: a turn sends it as a zoom position
-- (a camera whose position is unknown gets zoom speed bursts instead), the
-- wheel shows the zoom factor read back from the camera, and Zoom +/-
-- changes made elsewhere are followed by the level.
--
-- Design time (controls, layout) and the runtime `create(E)` live here. The
-- body is one do-block so the built chunk gains no top-level locals.

Modes = Modes or {}

do
  local HINT = "Turn the wheel. The centre does nothing"
  local DEAD_FRACTION = 0.30        -- inner part of the wheel that does nothing
  local SETTLE_DEG = 8              -- degrees of a new touch that move nothing
  local MAX_STEPS = 8               -- step pulses per report at most (bounded loop)
  local MAX_MARKS = 72              -- notches drawn at most
  local IDLE_MARKS = 12             -- notches drawn when Detents = 0
  local ECHO_TIME = 1.0             -- s a target echo of our own write is ignored
  local CAM_RATE = 0.1              -- s between zoom positions sent to a camera
  local CAM_READ = 0.2              -- s between zoom readings while the camera moves
  local CAM_SETTLE = 4.0            -- s of readings after the last send at most
  local ZOOM_BURST = 0.25           -- s a speed burst lasts for a camera without position
  local STEP_TEXT_TIME = 0.6        -- s the step readout stays on the pad

  local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
  local sformat = string.format

  local function sign(v)
    if v < 0 then return -1 elseif v > 0 then return 1 end
    return 0
  end

  Modes["Dial"] = {
    id = "dial",
    pretty = "Dial",
    hint = HINT,

    controls = function(C, props)
      C.add{ Name = "DialValue", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1,
             DefaultValue = 0, PinStyle = "Both", Group = "Dial" }
      C.add{ Name = "StepUp", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output", Group = "Dial" }
      C.add{ Name = "StepDown", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output", Group = "Dial" }
      C.add{ Name = "Turns", ControlType = "Knob", ControlUnit = "Float", Min = 0.5, Max = 10,
             DefaultValue = 2, PinStyle = "Input", Group = "Dial" }
      C.add{ Name = "Detents", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = 72,
             DefaultValue = 24, PinStyle = "Input", Group = "Dial" }
      C.add{ Name = "DialTarget", ControlType = "Text", PinStyle = "Input", Group = "Dial" }
      if C.camera ~= nil and C.camera ~= "None" then
        -- Sizes the zoom factor readout: 1 + zoom position x (OpticalZoom - 1).
        C.add{ Name = "OpticalZoom", ControlType = "Knob", ControlUnit = "Float", Min = 1, Max = 40,
               DefaultValue = 12, PinStyle = "Input", Group = "Camera" }
      end
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "LEVEL")
        L.knob("DialValue", { ctx.side, ctx.sideY }, { 48, 48 })
        ctx.sideY = ctx.sideY + 56
      elseif page == "Setup" then
        local withCam = L.metaOf("OpticalZoom") ~= nil
        local ix, iy, iw = L.section(ctx, "D I A L", 48 + ctx.G + 48)
        local names = { "Turns", "Detents" }
        if withCam then names[#names + 1] = "OpticalZoom" end
        local cols = #names
        local cw = floor((iw - (cols - 1) * ctx.G) / cols)
        L.grid(names, ix, iy, cols, cw, 48)
        L.cell("DialTarget", ix, iy + 48 + ctx.G, iw, 48,
               { caption = "TARGET (CODENAME~CONTROL, DRIVEN POSITION-WISE)" })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local cx, cy = W / 2, H / 2 - (E.hint and 6 or 0)
      local R = min(W, H) * 0.5 * 0.80          -- wheel radius
      local Rdead = R * DEAD_FRACTION           -- dead centre radius
      local Rtrack = R + 9                      -- level arc radius (outside the wheel)
      local trackW = max(4, min(8, R * 0.05))
      local markIn, markOut = R * 0.80, R * 0.95
      local valueSize = max(14, floor(Rdead * 0.55))
      local subSize = max(9, floor(valueSize * 0.42))

      local self = {
        v = 0,                  -- the level 0..1 (DialValue)
        wheel = 0,              -- wheel rotation drawn, clockwise degrees (0..360)
        down = false,
        settled = false,        -- the first SETTLE_DEG of a touch are over
        acc = 0,                -- settling accumulator (degrees)
        lastAngle = nil,        -- canvas angle of the previous report (nil in the dead centre)
        fx = 0, fy = 0,         -- finger
        detentAcc = 0,          -- clockwise degrees since the detent phase was reset
        lastStep = 0,           -- +1 / -1 of the last step pulse (drawn briefly)
        stepAt = -10,
        target = nil,           -- { ctl, name, wrote = { p, t } }
        -- camera
        camZoom = 0,            -- zoom position read back (0..1)
        camPan = nil, camTilt = nil,
        camAt = -10, camPending = false, camTimer = nil,
        marks = nil, marksKey = nil,   -- cached notches (rotated as a group per frame)
        camWatch = 0,           -- E.now() until which readings keep coming
        camReadAt = -10,
        following = false,      -- Zoom +/- held: the level follows the camera
        burst = nil,            -- timer ending a zoom speed burst
        lastDir = 0,
      }

      -- ---------- controls ----------
      local function knob(name, default)
        local c = E.ctl(name)
        if c == nil then return default end
        local n = tonumber(c.Value)
        if n == nil then return default end
        return n
      end
      local function turns() return U.clamp(knob("Turns", 2), 0.5, 10) end
      local function detents() return floor(U.clamp(knob("Detents", 24), 0, 72) + 0.5) end
      local function opticalZoom() return U.clamp(knob("OpticalZoom", 12), 1, 40) end

      -- ---------- camera ----------
      local function cam() return E.camera end

      local function zoomFactor()
        return 1 + U.clamp(self.camZoom, 0, 1) * (opticalZoom() - 1)
      end

      local setValue   -- forward

      local function readZoom()
        local c = cam()
        if c == nil or type(c.getPosition) ~= "function" then return end
        self.camReadAt = E.now()
        pcall(c.getPosition, c, function(p, t, z)
          if type(p) == "number" and type(t) == "number" then
            self.camPan, self.camTilt = p, t
          end
          if type(z) ~= "number" then return end
          z = U.clamp(z, 0, 1)
          if abs(z - self.camZoom) > 1e-9 then
            self.camZoom = z
            E.invalidate()
          end
          if self.following then setValue(z, "camera") end
        end)
      end

      -- Keeps readings coming for a while (the camera ramps to the position).
      local function watchCamera(seconds)
        if cam() == nil then return end
        local until_ = E.now() + seconds
        if until_ > self.camWatch then self.camWatch = until_ end
        E.animate(true)
      end

      local function endBurst()
        self.burst = nil
        local c = cam()
        if c and type(c.zoom) == "function" then pcall(c.zoom, c, 0) end
      end

      local function sendZoom()
        local c = cam()
        self.camAt = E.now()
        self.camPending = false
        if c == nil then return end
        if self.camPan ~= nil and type(c.gotoPosition) == "function" then
          pcall(c.gotoPosition, c, self.camPan, self.camTilt, self.v)
        elseif type(c.zoom) == "function" and self.lastDir ~= 0 then
          -- No position known: a short zoom speed burst in the turn's direction.
          pcall(c.zoom, c, self.lastDir)
          if self.burst then self.burst:cancel() end
          self.burst = E.after(ZOOM_BURST, endBurst)
        end
        watchCamera(CAM_SETTLE)
      end

      -- Zoom positions go out at most every CAM_RATE seconds; the last level
      -- of a burst is always sent.
      local function zoomChanged(now)
        if cam() == nil then return end
        local wait = CAM_RATE - (now - self.camAt)
        if wait <= 0 then
          if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
          sendZoom()
        elseif not self.camPending then
          self.camPending = true
          self.camTimer = E.after(wait, function()
            self.camTimer = nil
            if self.camPending then sendZoom() end
          end)
        end
      end

      local function flushZoom()
        if self.camPending then
          if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
          sendZoom()
        end
      end

      -- ---------- the direct target ----------
      local function targetWrite(p)
        local tg = self.target
        if not tg then return end
        tg.wrote = { p = p, t = E.now() }
        pcall(function() tg.ctl.Position = p end)
      end

      local function targetReport(ctl)
        local tg = self.target
        if not tg or ctl ~= tg.ctl then return end
        local ok, p = pcall(function() return ctl.Position end)
        if not ok or type(p) ~= "number" then return end
        local w = tg.wrote
        if w and abs(w.p - p) < 1e-6 and E.now() - w.t < ECHO_TIME then return end
        -- Changed elsewhere: followed, a resting finger included.
        setValue(U.clamp(p, 0, 1), "target")
      end

      local function unbindTarget()
        local tg = self.target
        if tg then
          pcall(function() tg.ctl.EventHandler = nil end)
          self.target = nil
        end
      end

      local function bindTarget(spec)
        unbindTarget()
        spec = U.trim(tostring(spec or ""))
        if spec == "" then return end
        local code, name = spec:match("^(.-)%s*~%s*(.+)$")
        if not code or code == "" then
          E.status("Dial target: use CodeName~control", "warn")
          return
        end
        local comp = (type(Q) == "table" and type(Q.component) == "function") and Q.component(code) or nil
        if not comp then
          E.status("Dial target: no component named " .. code, "warn")
          return
        end
        local ok, ctl = pcall(function() return comp[name] end)
        if not ok or ctl == nil then
          E.status("Dial target: " .. code .. " has no control " .. name, "warn")
          return
        end
        local okp, p = pcall(function() return ctl.Position end)
        if not okp or type(p) ~= "number" then
          E.status("Dial target: " .. spec .. " has no position", "warn")
          return
        end
        local tg = { ctl = ctl, name = spec }
        self.target = tg
        local handler = function(c) targetReport(c) end
        if type(Q) == "table" and type(Q.guard) == "function" then handler = Q.guard("dial target", handler) end
        pcall(function() ctl.EventHandler = handler end)
        -- Start from the target's level.
        setValue(U.clamp(p, 0, 1), "target")
        E.status("Dial target OK: " .. spec, "ok")
        E.invalidate()
      end

      -- ---------- the level ----------
      -- source: "touch" | "pin" | "target" | "camera". Every source but the
      -- camera drives the camera; every source but the target drives the target.
      setValue = function(v, source)
        v = U.clamp(v, 0, 1)
        if v ~= v then v = 0 end
        -- Sums of small angle steps leave residue: the ends read exactly 0 and 1.
        if v < 1e-9 then v = 0 elseif v > 1 - 1e-9 then v = 1 end
        if abs(v - self.v) < 1e-12 then return false end
        self.lastDir = sign(v - self.v)
        self.v = v
        E.out("DialValue", v)
        if source ~= "target" then targetWrite(v) end
        if source ~= "camera" then zoomChanged(E.now()) end
        E.invalidate()
        return true
      end

      -- Applies a clockwise turn of `delta` degrees: the wheel, the level and
      -- the detent pulses.
      local function turn(delta, now)
        if delta == 0 then return end
        self.wheel = (self.wheel + delta) % 360
        setValue(self.v + delta / (turns() * 360), "touch")
        local n = detents()
        if n > 0 then
          local step = 360 / n
          local before = floor((self.detentAcc + step / 2) / step)
          self.detentAcc = self.detentAcc + delta
          local after = floor((self.detentAcc + step / 2) / step)
          local diff = after - before
          if diff ~= 0 then
            local count = min(abs(diff), MAX_STEPS)
            local name = diff > 0 and "StepUp" or "StepDown"
            for _ = 1, count do E.pulse(name) end
            self.lastStep = sign(diff)
            self.stepAt = now
            E.setGesture(diff > 0 and "STEP UP" or "STEP DOWN")
            E.animate(true)                  -- tick clears the step cue
          end
        end
        E.invalidate()
      end

      -- ---------- geometry ----------
      -- Canvas angle of a pad point (0 = right, 90 = up); nil in the dead centre.
      local function angleAt(x, y)
        local dx, dy = x - cx, y - cy
        local d = sqrt(dx * dx + dy * dy)
        if d < Rdead then return nil, d end
        return U.angleDeg(dx, dy), d
      end

      -- ---------- touches ----------
      function self:onTouchStart(x, y, t)
        self.down = true
        self.settled, self.acc = false, 0
        self.fx, self.fy = x, y
        self.lastAngle = angleAt(x, y)
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        self.fx, self.fy = x, y
        local a = angleAt(x, y)
        if a == nil then
          self.lastAngle = nil                 -- the dead centre anchors nothing
          E.invalidate()
          return
        end
        local prev = self.lastAngle
        self.lastAngle = a
        if prev == nil then
          E.invalidate()
          return
        end
        local delta = U.normAngle(prev - a)    -- clockwise = positive
        if not self.settled then
          self.acc = self.acc + delta
          if abs(self.acc) <= SETTLE_DEG then
            E.invalidate()
            return
          end
          self.settled = true
          delta = self.acc - sign(self.acc) * SETTLE_DEG
          self.acc = 0
        end
        turn(delta, t)
      end

      function self:onTouchEnd(x, y, t, info)
        self.down = false
        self.lastAngle = nil
        flushZoom()
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        -- The same touch goes on: no second settling.
        self.down = true
        self.fx, self.fy = x, y
        self.lastAngle = angleAt(x, y)
        E.invalidate()
      end

      function self:onLock(locked)
        if locked then
          self.down = false
          self.lastAngle = nil
          flushZoom()
        end
        E.invalidate()
      end

      -- ---------- pins ----------
      function self:onControl(name, index, ctl)
        if name == "DialValue" then
          local v = tonumber(ctl.Value)
          if v then setValue(v, "pin") end
          return
        end
        if name == "Detents" then
          self.detentAcc = 0
          E.invalidate()
          return
        end
        if name == "Turns" or name == "OpticalZoom" then
          E.invalidate()
          return
        end
        if name == "DialTarget" then
          bindTarget(ctl.String)
          return
        end
        local c = cam()
        if c == nil then return end
        if name == "ZoomIn" or name == "ZoomOut" then
          if type(c.onControl) == "function" then pcall(c.onControl, c, name, index, ctl) end
          self.following = ctl.Boolean and true or false
          if self.following then
            -- Zoom +/- is a different source: a pending dial send would fight it.
            if self.camTimer then self.camTimer:cancel(); self.camTimer = nil end
            self.camPending = false
            if self.burst then self.burst:cancel(); self.burst = nil end
            readZoom()
            watchCamera(CAM_SETTLE)
          else
            -- One last reading once the camera has stopped.
            E.after(CAM_READ, function()
              self.following = true
              readZoom()
              self.following = false
            end)
          end
          E.invalidate()
          return
        end
        if type(c.onControl) == "function" then pcall(c.onControl, c, name, index, ctl) end
      end

      function self:tick(dt)
        local now = E.now()
        local busy = false
        if cam() and (self.following or now < self.camWatch) then
          busy = true
          if now - self.camReadAt >= CAM_READ - 0.0005 then readZoom() end
        end
        if now - self.stepAt < STEP_TEXT_TIME then
          busy = true
        elseif self.lastStep ~= 0 then
          self.lastStep = 0
          E.invalidate()
        end
        if not busy then E.animate(false) end
      end

      function self:onStart()
        E.out("DialValue", self.v)
        local tg = E.ctl("DialTarget")
        if tg and type(tg.String) == "string" and U.trim(tg.String) ~= "" then
          bindTarget(tg.String)
        end
        -- With a camera the level starts at the camera's zoom position so the
        -- first turn does not jump the zoom.
        if cam() and not self.target then
          self.following = true
          readZoom()
          self.following = false
        end
      end

      -- ---------- drawing ----------
      -- The notches only change with Detents: drawn once at rotation 0 into a
      -- scratch canvas and replayed inside a rotated group every frame.
      local function marksRaw(n)
        local marks = n > 0 and min(n, MAX_MARKS) or IDLE_MARKS
        if self.marks and self.marksKey == marks then return self.marks end
        local s = Svg.new(W, H, { limit = 20000 })
        local strong = n > 0
        -- one path for the plain notches, one line for the index notch
        local d = {}
        for i = 1, marks - 1 do
          local a = 90 - i * 360 / marks
          local x0, y0 = Svg.polar(cx, cy, markIn, a)
          local x1, y1 = Svg.polar(cx, cy, markOut, a)
          d[#d + 1] = "M" .. Svg.num(x0) .. " " .. Svg.num(y0) .. "L" .. Svg.num(x1) .. " " .. Svg.num(y1)
        end
        if #d > 0 then
          s:path(table.concat(d), { stroke = strong and T.muted or T.line, sw = strong and 2 or 1,
                                    cap = "round", opacity = strong and 0.9 or 0.7 })
        end
        local x0, y0 = Svg.polar(cx, cy, markIn, 90)
        local x1, y1 = Svg.polar(cx, cy, markOut, 90)
        s:line(x0, y0, x1, y1, { stroke = T.accent2, sw = 3, cap = "round" })
        s.parts[1] = s.parts[1] or ""
        self.marks = table.concat(s.parts)
        self.marksKey = marks
        return self.marks
      end

      function self:draw(c)
        local now = E.now()
        -- level track around the wheel
        c:circle(cx, cy, Rtrack, { fill = "none", stroke = T.well, sw = trackW })
        if self.v > 0.0005 then
          local sweep = min(359.9, 360 * self.v)
          c:arc(cx, cy, Rtrack, 90, 90 - sweep, { stroke = T.accent, sw = trackW, cap = "round" })
        end
        -- the wheel
        c:circle(cx, cy, R, { fill = T.panel, stroke = self.down and T.accent or T.line, sw = self.down and 2 or 1 })
        -- the notches, turned with the wheel (SVG rotate is clockwise, y down)
        c:raw('<g transform="rotate(' .. Svg.num(self.wheel) .. " " .. Svg.num(cx) .. " " .. Svg.num(cy) .. ')">'
              .. marksRaw(detents()) .. "</g>")
        -- the dead centre
        c:circle(cx, cy, Rdead, { fill = T.well, stroke = T.line, sw = 1 })
        -- the finger on the wheel
        if self.down and self.lastAngle ~= nil then
          local d = sqrt((self.fx - cx) ^ 2 + (self.fy - cy) ^ 2)
          local fxp, fyp = Svg.polar(cx, cy, U.clamp(d, Rdead + 8, R - 8), self.lastAngle)
          Shapes.dot(c, T, fxp, fyp, max(6, min(10, R * 0.06)))
        end
        -- readout: the level, then the zoom factor or the last step
        local pct = floor(self.v * 100 + 0.5)
        c:textFit(cx, cy + valueSize * 0.36, Rdead * 1.8, sformat("%d%%", pct),
                  { size = valueSize, fill = T.text, anchor = "middle", weight = "bold" })
        local sub
        if cam() then
          sub = sformat("ZOOM x%.1f", zoomFactor())
        elseif self.lastStep ~= 0 and now - self.stepAt < STEP_TEXT_TIME then
          sub = self.lastStep > 0 and "STEP +" or "STEP -"
        end
        if sub then
          c:textFit(cx, cy + valueSize * 0.36 + subSize + 3, Rdead * 1.8, sub,
                    { size = subSize, fill = cam() and T.muted or T.accent2, anchor = "middle" })
        end
        -- step cue on the rim while a step is fresh
        if self.lastStep ~= 0 and now - self.stepAt < STEP_TEXT_TIME then
          local ax, ay = Svg.polar(cx, cy, Rtrack + trackW + 10, 90)
          Shapes.icon(c, self.lastStep > 0 and "plus" or "minus", ax, ay, 14, T.accent2)
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

      -- white-box helpers for tests
      self.geometry = { cx = cx, cy = cy, R = R, Rdead = Rdead, Rtrack = Rtrack }
      self.zoomFactor = zoomFactor

      return self
    end,
  }
end
