-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Joystick mode
--
-- A virtual joystick: the stick sits where the finger is, measured from the
-- centre of the pad and scaled by the base radius (the rim is full travel).
-- Outputs JoyX / JoyY (-1..1), Magnitude (0..1) and the four direction LEDs
-- (eight-way sectors). Deadzone and Curve shape the response, InvertPan /
-- InvertTilt flip the axes, Sticky keeps the stick where it is left, Home
-- re-centres it (and homes the camera). Without Sticky the stick springs
-- back over 0.15 s through tick(). A camera driver (E.camera) is driven at
-- the stick's output; the Demo camera's scene is drawn on the Camera View.
-- Safety: a stuck Panel Touch is released after 30 s without movement.

Modes = Modes or {}

do
  local floor, sqrt, abs, min, max = math.floor, math.sqrt, math.abs, math.min, math.max
  local sformat = string.format

  local HINT = "Drag the stick. Double tap: home"
  local SPRING_TIME = 0.15                -- s, the spring-back animation
  local STUCK_TIME = 30                   -- s, a resting finger under a stuck Panel Touch
  local SECTOR = 0.383                    -- cos 67.5 deg: eight-way direction sectors
  local CURVES = { "Linear", "Squared", "Cubed" }

  local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
  end

  Modes["Joystick"] = {
    id = "joystick",
    pretty = "Joystick",
    hint = HINT,

    controls = function(C, props)
      C.add({ Name = "JoyX", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1,
              DefaultValue = 0, PinStyle = "Output" })
      C.add({ Name = "JoyY", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1,
              DefaultValue = 0, PinStyle = "Output" })
      C.add({ Name = "Magnitude", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1,
              DefaultValue = 0, PinStyle = "Output" })
      C.add({ Name = "DirLeft", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" })
      C.add({ Name = "DirRight", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" })
      C.add({ Name = "DirUp", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" })
      C.add({ Name = "DirDown", ControlType = "Indicator", IndicatorType = "Led", PinStyle = "Output" })
      C.add({ Name = "Deadzone", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 0.5,
              DefaultValue = 0.08, PinStyle = "Input" })
      C.add({ Name = "Curve", ControlType = "Text", DefaultValue = "Linear", PinStyle = "Input",
              Choices = { "Linear", "Squared", "Cubed" } })
      C.add({ Name = "Sticky", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input" })
      C.add({ Name = "Home", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both" })
      C.add({ Name = "InvertPan", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" })
      C.add({ Name = "InvertTilt", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" })
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "JOYSTICK")
        L.sideButton(ctx, "Home", "HOME")
        L.sideButton(ctx, "Sticky", "STICKY")
        L.sideButton(ctx, "InvertPan", "INVERT PAN")
        L.sideButton(ctx, "InvertTilt", "INVERT TILT")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "J O Y S T I C K", 112)
        L.caption("DEADZONE", { ix, iy }, { 56, 10 })
        L.knob("Deadzone", { ix + 12, iy + 12 }, { 32, 32 }, { color = Nikita.Purple })
        L.caption("CURVE", { ix + 68, iy }, { 96, 10 }, "Left")
        L.combo("Curve", { ix + 68, iy + 14 }, { 96, 22 })
        L.toggle("Sticky", "STICKY", { ix + 176, iy + 12 }, { 60, 28 })
        L.trigger("Home", "HOME", { ix + 244, iy + 12 }, { 60, 28 })
        L.toggle("InvertPan", "INVERT PAN", { ix, iy + 52 }, { 96, 28 })
        L.toggle("InvertTilt", "INVERT TILT", { ix + 104, iy + 52 }, { 96, 28 })
        L.label("Deadzone: travel ignored around the centre. Curve: Linear, Squared or Cubed response.\nSticky keeps the stick where it is left; off, it springs back on release.",
                { ix, iy + 86 }, { iw, 26 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local cx, cy = W / 2, H / 2
      local inset = clamp(floor(min(W, H) * 0.06), 8, 28)
      local R = min(W, H) / 2 - inset              -- base radius: full travel
      local KNOB = clamp(floor(R * 0.16), 8, 28)
      local self = {
        px = 0, py = 0,              -- stick position in -1..1 (y up), unit disc
        down = false,
        lastMoveAt = 0,
        spring = nil,                -- { x0, y0, t } while springing back
        jx = 0, jy = 0, mag = 0,     -- the published outputs
        leds = { false, false, false, false },   -- left, right, up, down
        driveX = nil, driveY = nil,  -- last camera drive sent
        base = nil,                  -- cached static drawing
      }

      -- ---------- controls ----------
      local function knob(name, default, lo, hi)
        local c = E.ctl(name)
        if c == nil then return default end
        local v = c.Value
        if type(v) ~= "number" then return default end
        return clamp(v, lo, hi)
      end
      local function flag(name)
        local c = E.ctl(name)
        return c ~= nil and c.Boolean == true
      end
      local function curveName()
        local c = E.ctl("Curve")
        local s = c and c.String or "Linear"
        for i = 1, #CURVES do
          if s == CURVES[i] then return s end
        end
        return "Linear"
      end

      -- ---------- the response: deadzone, curve, inverts, LEDs ----------
      local function shaped()
        local m = sqrt(self.px * self.px + self.py * self.py)
        if m > 1 then m = 1 end
        local dz = knob("Deadzone", 0.08, 0, 0.5)
        local ux, uy = 0, 0
        if m > 0 then ux, uy = self.px / m, self.py / m end
        local out = 0
        if m > dz then
          out = (m - dz) / (1 - dz)
          local curve = curveName()
          if curve == "Squared" then out = out * out
          elseif curve == "Cubed" then out = out * out * out end
        end
        if flag("InvertPan") then ux = -ux end
        if flag("InvertTilt") then uy = -uy end
        return ux * out, uy * out, out, ux, uy
      end

      local function drive(jx, jy)
        local cam = E.camera
        if not cam or type(cam.drive) ~= "function" then return end
        if jx == self.driveX and jy == self.driveY then return end
        self.driveX, self.driveY = jx, jy
        cam:drive(jx, jy)
      end

      local function publish()
        local jx, jy, mag, ux, uy = shaped()
        self.jx, self.jy, self.mag = jx, jy, mag
        local active = mag > 0
        local leds = self.leds
        leds[1] = active and ux < -SECTOR
        leds[2] = active and ux > SECTOR
        leds[3] = active and uy > SECTOR
        leds[4] = active and uy < -SECTOR
        E.out("JoyX", jx)
        E.out("JoyY", jy)
        E.out("Magnitude", mag)
        E.out("DirLeft", leds[1])
        E.out("DirRight", leds[2])
        E.out("DirUp", leds[3])
        E.out("DirDown", leds[4])
        drive(jx, jy)
      end

      local function updateAnim()
        E.animate(self.down or self.spring ~= nil)
      end

      -- Finger (pad px) -> stick position on the unit disc.
      local function setStick(x, y)
        local dx, dy = (x - cx) / R, (cy - y) / R
        local m = sqrt(dx * dx + dy * dy)
        if m > 1 then dx, dy = dx / m, dy / m end
        self.px, self.py = dx, dy
        self.spring = nil
        publish()
        E.invalidate()
      end

      -- The stick springs back to the centre over SPRING_TIME (via tick);
      -- the camera stops at once.
      local function release()
        if self.px == 0 and self.py == 0 then
          self.spring = nil
          updateAnim()
          return
        end
        drive(0, 0)
        self.spring = { x0 = self.px, y0 = self.py, t = 0 }
        updateAnim()
        E.invalidate()
      end

      local function centre()
        self.px, self.py = 0, 0
        self.spring = nil
        publish()
        updateAnim()
        E.invalidate()
      end

      local function home(fromPad)
        centre()
        local cam = E.camera
        if cam and type(cam.home) == "function" then cam:home() end
        if fromPad then
          E.pulse("Home")
          E.setGesture("HOME")
        end
      end

      -- ---------- touches ----------
      function self:onTouchStart(x, y, t)
        self.down = true
        self.lastMoveAt = t
        setStick(x, y)
        updateAnim()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        self.lastMoveAt = t
        setStick(x, y)
      end

      function self:onTouchResume(x, y, t)
        self:onTouchStart(x, y, t)
      end

      function self:onTouchEnd(x, y, t, info)
        self.down = false
        if info and info.aborted then
          centre()
        elseif flag("Sticky") then
          updateAnim()
          E.invalidate()
        else
          release()
        end
      end

      function self:onGesture(g)
        if g.type == "double" then home(true) end
      end

      function self:onLock(locked)
        if locked then
          self.down = false
          centre()
        end
        E.invalidate()
      end

      -- ---------- pins ----------
      function self:onControl(name, index, ctl)
        if name == "Home" then
          if ctl.Boolean then home(false) end
        elseif name == "Sticky" then
          if not ctl.Boolean and not self.down then release() end
        elseif name == "InvertPan" or name == "InvertTilt" or name == "Deadzone" or name == "Curve" then
          publish()
          E.invalidate()
        else
          local cam = E.camera
          if cam and type(cam.onControl) == "function" then
            cam:onControl(name, index, ctl)
            if name == "MaxSpeed" and ((self.driveX or 0) ~= 0 or (self.driveY or 0) ~= 0) then
              -- the new speed applies to the drive in progress
              self.driveX, self.driveY = nil, nil
              drive(self.jx, self.jy)
            end
          end
        end
      end

      -- ---------- animation and the stuck guard ----------
      function self:tick(dt)
        local s = self.spring
        if s then
          s.t = s.t + dt
          local k = s.t / SPRING_TIME
          if k >= 1 then
            self.px, self.py, self.spring = 0, 0, nil
          else
            local e = 1 - (1 - k) * (1 - k)        -- ease out
            self.px, self.py = s.x0 * (1 - e), s.y0 * (1 - e)
          end
          publish()
          E.invalidate()
        end
        if self.down and E.now() - self.lastMoveAt > STUCK_TIME then
          self.down = false
          E.dbg("joystick: released a stuck touch")
          release()
        end
        updateAnim()
      end

      -- ---------- drawing ----------
      -- The base never changes: drawn once and replayed as one raw element.
      local function baseRaw()
        if self.base then return self.base end
        local c = Svg.new(W, H, { limit = 20000 })
        c:circle(cx, cy, R + 4, { fill = T.panel, stroke = T.line, sw = 1 })
        c:circle(cx, cy, R, { fill = T.well, stroke = T.line, sw = 1 })
        c:circle(cx, cy, R * 0.5, { fill = "none", stroke = T.line, sw = 1, opacity = 0.6 })
        c:line(cx - R, cy, cx + R, cy, { stroke = T.line, sw = 1, opacity = 0.7 })
        c:line(cx, cy - R, cx, cy + R, { stroke = T.line, sw = 1, opacity = 0.7 })
        local s = clamp(floor(R * 0.12), 10, 22)
        local d = R - s * 0.7
        Shapes.icon(c, "chevronLeft", cx - d, cy, s, T.muted)
        Shapes.icon(c, "chevronRight", cx + d, cy, s, T.muted)
        Shapes.icon(c, "up", cx, cy - d, s, T.muted)
        Shapes.icon(c, "down", cx, cy + d, s, T.muted)
        self.base = table.concat(c.parts)
        self.chevron = { s = s, d = d }
        return self.base
      end

      function self:draw(c)
        c:raw(baseRaw())
        local dz = knob("Deadzone", 0.08, 0, 0.5)
        if dz > 0 then
          c:circle(cx, cy, R * dz, { fill = "none", stroke = T.accent3, sw = 1, dash = { 3, 3 }, opacity = 0.8 })
        end
        local ch = self.chevron
        local leds = self.leds
        if leds[1] then Shapes.icon(c, "chevronLeft", cx - ch.d, cy, ch.s, T.accent) end
        if leds[2] then Shapes.icon(c, "chevronRight", cx + ch.d, cy, ch.s, T.accent) end
        if leds[3] then Shapes.icon(c, "up", cx, cy - ch.d, ch.s, T.accent) end
        if leds[4] then Shapes.icon(c, "down", cx, cy + ch.d, ch.s, T.accent) end
        local kx, ky = cx + self.px * R, cy - self.py * R
        if self.px ~= 0 or self.py ~= 0 then
          c:line(cx, cy, kx, ky, { stroke = T.accent, sw = 4, opacity = 0.5, cap = "round" })
        end
        if self.down then
          Shapes.dot(c, T, kx, ky, KNOB)
        else
          c:circle(kx, ky, KNOB, { fill = T.accent, stroke = T.onAccent, sw = 1, opacity = 0.85 })
        end
        c:text(cx, 20, sformat("X %+.2f   Y %+.2f", self.jx, self.jy),
          { size = 12, fill = T.muted, anchor = "middle" })
        if E.hint and not self.down then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- Camera View (Demo camera): the simulated scene.
      function self:drawCamera(c)
        local cam = E.camera
        if cam and type(cam.drawView) == "function" then cam:drawView(c) end
      end

      function self:onStart()
        publish()
      end

      return self
    end,
  }
end
