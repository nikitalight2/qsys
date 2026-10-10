-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Knob mode
--
-- A bounded rotary with a 270 degree sweep (from bottom-left over the top to
-- bottom-right), a value readout in display units, Min / Max labels and an
-- optional direct target. A touch on the ring (the track outside the knob
-- body) sets the value from the touch angle; dragging anywhere then turns
-- the knob relative to the finger's angular movement with acceleration (a
-- fast turn moves up to three times as far as a slow one). Nothing wraps:
-- the position is clamped to 0..1.
--
-- Controls: KnobMin / KnobMax (display range), Units (text), KnobValue
-- (display units, pin Both), KnobPosition (0..1, pin Both), DialTarget
-- ("CodeName~control", driven position-wise and followed when changed
-- elsewhere, a resting finger included).
--
-- Design time (controls, layout) and the runtime `create(E)` live here. The
-- body is one do-block so the built chunk gains no top-level locals.

Modes = Modes or {}

do
  local HINT = "Touch the ring to set, drag to turn"
  local SWEEP = 270                 -- degrees of travel
  local START_ANGLE = 225           -- position 0 (bottom-left, canvas angles: 0 = right, 90 = up)
  local ACCEL_FROM, ACCEL_TO = 180, 720   -- deg/s: gain 1 below, 3 above
  local GAIN_MAX = 3
  local GAIN_HOLD = 0.15            -- seconds the acceleration readout outlives the last move
  local ECHO_TIME = 1.0             -- seconds a target echo of our own write is ignored
  local MAJOR_TICKS, MINOR_PER = 10, 2  -- 11 major ticks, 2 minor ticks between majors

  local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
  local sformat = string.format

  -- Decimals for a display range: wide ranges read as integers.
  local function decimalsFor(range)
    range = abs(range)
    if range >= 100 then return 0 end
    if range >= 10 then return 1 end
    return 2
  end

  -- Rounds half away from zero (string.format alone rounds half to even, so
  -- 50.5 would read "50" and 51.5 "52").
  local function fmtNumber(v, decimals)
    if v ~= v then return "0" end
    local m = 10 ^ decimals
    local r = floor(abs(v) * m + 0.5) / m
    if v < 0 then r = -r end
    local s = sformat("%." .. decimals .. "f", r)
    if s == "-0" or s == "-0.0" or s == "-0.00" then s = s:sub(2) end
    return s
  end

  -- Largest of a few font sizes (down to 9 px) at which str fits maxW.
  local function fitSize(str, size, maxW, weight)
    for _ = 1, 4 do
      if size <= 9 or Font.width(str, size, weight) <= maxW then break end
      size = max(9, floor(size * 0.8))
    end
    return size
  end

  -- Canvas angle (degrees) of a sweep position 0..1.
  local function angleOfPos(p)
    return START_ANGLE - SWEEP * p
  end

  -- Sweep position of a canvas angle; the 90 degree gap at the bottom snaps
  -- to the nearest end.
  local function posOfAngle(a)
    local b = (START_ANGLE - a) % 360
    if b <= SWEEP then return b / SWEEP end
    if b < SWEEP + (360 - SWEEP) / 2 then return 1 end
    return 0
  end

  Modes["Knob"] = {
    id = "knob",
    pretty = "Knob",
    hint = HINT,

    controls = function(C, props)
      C.add{ Name = "KnobMin", ControlType = "Knob", ControlUnit = "Float", Min = -1000, Max = 1000,
             DefaultValue = 0, PinStyle = "Input", Group = "Knob" }
      C.add{ Name = "KnobMax", ControlType = "Knob", ControlUnit = "Float", Min = -1000, Max = 1000,
             DefaultValue = 100, PinStyle = "Input", Group = "Knob" }
      C.add{ Name = "Units", ControlType = "Text", PinStyle = "Input", Group = "Knob" }
      C.add{ Name = "KnobValue", ControlType = "Knob", ControlUnit = "Float", Min = -1000, Max = 1000,
             DefaultValue = 0, PinStyle = "Both", Group = "Knob" }
      C.add{ Name = "KnobPosition", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1,
             DefaultValue = 0, PinStyle = "Both", Group = "Knob" }
      C.add{ Name = "DialTarget", ControlType = "Text", PinStyle = "Input", Group = "Knob" }
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "VALUE")
        L.knob("KnobValue", { ctx.side, ctx.sideY }, { 48, 48 })
        ctx.sideY = ctx.sideY + 56
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "K N O B", 48 + ctx.G + 48)
        local cw = floor((iw - 2 * ctx.G) / 3)
        L.cell("KnobMin", ix, iy, cw, 48, { caption = "MIN" })
        L.cell("KnobMax", ix + cw + ctx.G, iy, cw, 48, { caption = "MAX" })
        L.cell("Units", ix + 2 * (cw + ctx.G), iy, cw, 48, { caption = "UNITS" })
        L.cell("DialTarget", ix, iy + 48 + ctx.G, iw, 48, { caption = "TARGET (CODENAME~CONTROL, DRIVEN POSITION-WISE)" })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      -- The hint line needs about 20 px under the labels; a pad shorter than
      -- 160 px cannot hold it next to a usable knob, so it is dropped there.
      local hintOn = (E.hint and H >= 160) and true or false
      local cx, cy = W / 2, H / 2 - (hintOn and 6 or 0)
      local R = min(W, H) * 0.5 * 0.80          -- outer radius of the track
      local labelSize = max(10, floor(min(14, R * 0.08)))
      local function bandOf(r) return max(12, r * 0.14) end
      -- Fit the track into the free margin: ticks overhang half a band
      -- outside R (top and sides) and the Min / Max labels hang below the
      -- arc ends, above the hint line. The band never grows as R shrinks.
      local lim = min(cx, cy) - 2
      if R + bandOf(R) / 2 > lim then R = lim - bandOf(R) / 2 end
      local room = H - cy - (hintOn and 20 or 2) - labelSize - 8
      local rLabel = room / 0.70711 - bandOf(R) * 0.15
      if R > rLabel then R = rLabel end
      if R < 16 then R = 16 end
      local band = bandOf(R)                    -- track stroke width
      local Rm = R - band / 2                   -- track centre radius
      local Rin = max(6, Rm - band)             -- knob body radius; the ring is outside it
      local Rdead = min(max(10, R * 0.12), Rin * 0.6)   -- no angle inside this radius
      local tickIn, tickMid, tickOut = band * 0.15, band * 0.35, band * 0.5
      local valueSize = max(14, floor(Rin * 0.34))
      local unitSize = max(10, floor(valueSize * 0.5))
      local readW = Rin * 1.7                   -- width the readout and its sub-line fit

      local self = {
        p = 0,                 -- sweep position 0..1
        lo = 0, hi = 100,      -- display range
        units = "",
        down = false,
        lastAngle = nil,       -- canvas angle of the previous report (nil inside the dead centre)
        lastT = nil,
        gain = 1,              -- acceleration gain of the last move (drawn while down)
        gainTimer = nil,       -- resets the gain readout when the finger stops moving
        static = nil,          -- cached track, ticks and labels
        staticKey = nil,
        target = nil,          -- { ctl, name, wrote = { p, t } }
      }

      -- ---------- value helpers ----------
      local function range()
        local r = self.hi - self.lo
        if abs(r) < 1e-9 then r = 1 end
        return r
      end
      local function valueOf(p) return self.lo + p * range() end
      local function posOfValue(v)
        local p = (v - self.lo) / range()
        return U.clamp(p, 0, 1)
      end
      local function decimals() return decimalsFor(range()) end
      local function readout(v)
        local s = fmtNumber(v, decimals())
        if self.units ~= "" then s = s .. " " .. self.units end
        return s
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
        -- Changed elsewhere: followed, a resting finger included (as in Dial);
        -- a drag in progress continues relative to the followed position.
        p = U.clamp(p, 0, 1)
        if abs(p - self.p) < 1e-9 then return end
        self.p = p
        E.out("KnobPosition", self.p)
        E.out("KnobValue", valueOf(self.p))
        E.invalidate()
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
        spec = U.trim(spec)
        if spec == "" then return end
        local code, name = spec:match("^(.-)%s*~%s*(.+)$")
        if not code or code == "" then
          E.status("Knob target: use CodeName~control", "warn")
          return
        end
        local comp = (type(Q) == "table" and type(Q.component) == "function") and Q.component(code) or nil
        if not comp then
          E.status("Knob target: no component named " .. code, "warn")
          return
        end
        local ok, ctl = pcall(function() return comp[name] end)
        if not ok or ctl == nil then
          E.status("Knob target: " .. code .. " has no control " .. name, "warn")
          return
        end
        local okp, p = pcall(function() return ctl.Position end)
        if not okp or type(p) ~= "number" then
          E.status("Knob target: " .. spec .. " has no position", "warn")
          return
        end
        local tg = { ctl = ctl, name = spec }
        self.target = tg
        local handler = function(c) targetReport(c) end
        if type(Q) == "table" and type(Q.guard) == "function" then handler = Q.guard("knob target", handler) end
        pcall(function() ctl.EventHandler = handler end)
        -- Start from the target's level.
        self.p = U.clamp(p, 0, 1)
        E.out("KnobPosition", self.p)
        E.out("KnobValue", valueOf(self.p))
        E.status("Knob target OK: " .. spec, "ok")
        E.invalidate()
      end

      -- ---------- position changes ----------
      local function setPos(p, fromTouch)
        p = U.clamp(p, 0, 1)
        if p ~= p then p = 0 end
        if abs(p - self.p) < 1e-12 then return false end
        self.p = p
        E.out("KnobPosition", self.p)
        E.out("KnobValue", valueOf(self.p))
        targetWrite(self.p)
        E.invalidate()
        return true
      end

      local function rangeChanged()
        self.static = nil
        E.out("KnobValue", valueOf(self.p))
        E.invalidate()
      end

      local function readInputs()
        local lo = E.ctl("KnobMin")
        local hi = E.ctl("KnobMax")
        local un = E.ctl("Units")
        if lo and type(lo.Value) == "number" then self.lo = lo.Value end
        if hi and type(hi.Value) == "number" then self.hi = hi.Value end
        if un then self.units = U.trim(un.String) end
      end

      -- ---------- geometry ----------
      local function angleAt(x, y)
        local dx, dy = x - cx, y - cy
        local d = sqrt(dx * dx + dy * dy)
        if d < Rdead then return nil, d end
        return U.angleDeg(dx, dy), d
      end

      -- ---------- touch ----------
      -- The multiplier readout reflects the current speed: it clears when no
      -- move has arrived for GAIN_HOLD seconds while the finger rests.
      local function setGain(g)
        if self.gainTimer then self.gainTimer:cancel(); self.gainTimer = nil end
        self.gain = g
        if g > 1.05 then
          self.gainTimer = E.after(GAIN_HOLD, function()
            self.gainTimer = nil
            if self.gain ~= 1 then
              self.gain = 1
              E.invalidate()
            end
          end)
        end
      end

      function self:onTouchStart(x, y, t)
        self.down = true
        setGain(1)
        local a, d = angleAt(x, y)
        self.lastAngle, self.lastT = a, t
        if a and d >= Rin then
          setPos(posOfAngle(a), true)          -- a touch on the ring sets
        end
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        local a = angleAt(x, y)
        if a == nil then
          self.lastAngle = nil                 -- the dead centre anchors nothing
          self.lastT = t
          return
        end
        local prev = self.lastAngle
        self.lastAngle = a
        if prev == nil then
          self.lastT = t
          return
        end
        local delta = U.normAngle(prev - a)    -- clockwise turn = positive
        local dt = t - (self.lastT or t)
        self.lastT = t
        if dt < 0.005 then dt = 0.005 end
        local speed = abs(delta) / dt
        local gain = 1 + (GAIN_MAX - 1) * U.clamp((speed - ACCEL_FROM) / (ACCEL_TO - ACCEL_FROM), 0, 1)
        setGain(gain)
        if delta ~= 0 then
          setPos(self.p + delta / SWEEP * gain, true)
        end
      end

      function self:onTouchEnd(x, y, t, info)
        self.down = false
        self.lastAngle, self.lastT = nil, nil
        setGain(1)
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        self.down = true
        self.lastAngle, self.lastT = angleAt(x, y), t
        E.invalidate()
      end

      function self:onLock(locked)
        if locked then
          self.down = false
          self.lastAngle = nil
          setGain(1)
        end
        E.invalidate()
      end

      -- ---------- pins ----------
      function self:onControl(name, index, ctl)
        if name == "KnobValue" then
          local v = tonumber(ctl.Value)
          if v then setPos(posOfValue(v), false) end
        elseif name == "KnobPosition" then
          local v = tonumber(ctl.Value)
          if v then setPos(v, false) end
        elseif name == "KnobMin" or name == "KnobMax" or name == "Units" then
          readInputs()
          rangeChanged()
        elseif name == "DialTarget" then
          bindTarget(ctl.String)
        end
      end

      function self:onStart()
        readInputs()
        E.out("KnobPosition", self.p)
        E.out("KnobValue", valueOf(self.p))
        local tg = E.ctl("DialTarget")
        if tg and type(tg.String) == "string" and U.trim(tg.String) ~= "" then
          bindTarget(tg.String)
        end
      end

      -- ---------- drawing ----------
      -- Track, ticks and the Min / Max labels only change with the range:
      -- drawn once into a scratch canvas and replayed as one raw element.
      local function staticRaw()
        local key = tostring(self.lo) .. "|" .. tostring(self.hi) .. "|" .. self.units
        if self.static and self.staticKey == key then return self.static end
        local s = Svg.new(W, H, { limit = 20000 })
        s:arc(cx, cy, Rm, START_ANGLE, START_ANGLE - SWEEP, { stroke = T.well, sw = band, cap = "round" })
        s:arc(cx, cy, Rm, START_ANGLE, START_ANGLE - SWEEP, { stroke = T.line, sw = 1, opacity = 0.6 })
        local n = MAJOR_TICKS * (MINOR_PER + 1)
        for i = 0, n do
          local a = angleOfPos(i / n)
          local major = (i % (MINOR_PER + 1)) == 0
          local x0, y0 = Svg.polar(cx, cy, R + tickIn, a)
          local x1, y1 = Svg.polar(cx, cy, R + (major and tickOut or tickMid), a)
          s:line(x0, y0, x1, y1, { stroke = major and T.muted or T.line, sw = major and 2 or 1, cap = "round" })
        end
        -- Min / Max labels under the arc ends, kept inside the pad: a label
        -- that would leave the edge slides towards the centre and is fitted
        -- to its half of the width.
        local d = decimals()
        local lx, ly = Svg.polar(cx, cy, R + tickIn, angleOfPos(0))
        local hx = Svg.polar(cx, cy, R + tickIn, angleOfPos(1))
        local ty = ly + labelSize + 6
        local loS, hiS = fmtNumber(self.lo, d), fmtNumber(self.hi, d)
        local x = lx - 4
        local w = Font.width(loS, labelSize)
        if x - w < 2 then x = min(2 + w, cx - 4) end
        s:textFit(x, ty, cx - 6, loS, { size = labelSize, fill = T.muted, anchor = "end" })
        x = hx + 4
        w = Font.width(hiS, labelSize)
        if x + w > W - 2 then x = max(W - 2 - w, cx + 4) end
        s:textFit(x, ty, W - cx - 6, hiS, { size = labelSize, fill = T.muted, anchor = "start" })
        s.parts[1] = s.parts[1] or ""
        self.static = table.concat(s.parts)
        self.staticKey = key
        return self.static
      end

      function self:draw(c)
        c:raw(staticRaw())
        local a = angleOfPos(self.p)
        -- value fill along the track
        if self.p > 0.0005 then
          c:arc(cx, cy, Rm, START_ANGLE, a, { stroke = T.accent, sw = band - 4, cap = "round",
                                               opacity = self.down and 1 or 0.9 })
        end
        -- knob body
        c:circle(cx, cy, Rin, { fill = T.panel, stroke = self.down and T.accent or T.line, sw = self.down and 2 or 1 })
        -- pointer: a line from the body's edge inward and a dot at the rim
        local px0, py0 = Svg.polar(cx, cy, Rin * 0.62, a)
        local px1, py1 = Svg.polar(cx, cy, Rin - 6, a)
        c:line(px0, py0, px1, py1, { stroke = self.down and T.accent2 or T.accent, sw = 3, cap = "round" })
        local dx, dy = Svg.polar(cx, cy, Rm, a)
        if self.down then
          Shapes.dot(c, T, dx, dy, band * 0.45)
        else
          c:circle(dx, dy, band * 0.35, { fill = T.accent2, stroke = T.onAccent, sw = 1 })
        end
        -- readout
        local vs = fmtNumber(valueOf(self.p), decimals())
        local vsize = fitSize(vs, valueSize, readW, "bold")
        c:textFit(cx, cy + valueSize * 0.36, readW, vs,
                  { size = vsize, fill = T.text, anchor = "middle", weight = "bold" })
        local sub = self.units
        if self.down and self.gain > 1.05 then
          sub = sformat("x%.1f", self.gain) .. (sub ~= "" and ("  " .. sub) or "")
        end
        if sub ~= "" then
          c:textFit(cx, cy + valueSize * 0.36 + unitSize + 4, readW, sub,
                    { size = unitSize, fill = T.muted, anchor = "middle" })
        end
        if hintOn and not self.down then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- white-box helpers for tests
      self.readout = readout
      self.valueOf = valueOf
      self.geometry = { cx = cx, cy = cy, R = R, Rm = Rm, Rin = Rin, Rdead = Rdead, band = band,
                        tickOut = tickOut, hintOn = hintOn }
      self.angleOfPos = angleOfPos
      self.posOfAngle = posOfAngle

      return self
    end,
  }
end
