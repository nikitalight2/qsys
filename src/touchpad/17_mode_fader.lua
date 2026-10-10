-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Fader mode
--
-- A linear touch fader, vertical or horizontal (the Orientation property).
-- The whole pad is the fader: a touch anywhere across the slot works. The
-- value readout shows display units from FaderMin / FaderMax (defaults -100
-- and 10) and Units (default "dB").
--
-- Options: GrabMode "Jump" sets the value where the finger lands and follows
-- it; "Relative" leaves the value where it was and moves it by the finger's
-- travel along the slot. Taper "Linear" maps the travel straight onto the
-- range; "Audio" uses a piecewise curve that puts 0 dB at 75 % of the travel
-- for a -100..10 range (the lower half of the travel covers the quiet end).
-- SnapCenter snaps a touch-driven position to the centre value (the middle
-- of the range) within 3 % of the travel. DialTarget ("CodeName~control")
-- drives a control position-wise and follows it while no finger is down.
--
-- Outputs: FaderPosition (0..1, pin Both), FaderValue (display units, pin
-- Both) and the common set (Touching, X, Y, the pulses, Gesture...).
-- Draws the slot, the fill, the cap, scale ticks with labels and the value.
--
-- Design time (controls, layout) and the runtime `create(E)` live here. The
-- body is one do-block so the built chunk gains no top-level locals.

Modes = Modes or {}

do
  local HINT = "Touch or drag the fader"
  local ECHO_TIME = 1.0             -- seconds a target echo of our own write is ignored
  local SNAP = 0.03                 -- SnapCenter window as a fraction of the travel
  local MAJOR_TICKS, MINOR_PER = 10, 2  -- 11 major ticks, 2 minor ticks between majors
  -- Audio taper: travel position -> normalised range position, piecewise
  -- linear. For -100..10 the knees read -60, -40, -20, 0 and +10 dB.
  local AUDIO_CURVE = {
    { 0, 0 }, { 0.1, 40 / 110 }, { 0.25, 60 / 110 }, { 0.5, 80 / 110 }, { 0.75, 100 / 110 }, { 1, 1 },
  }

  local floor, abs, min, max, ceil = math.floor, math.abs, math.min, math.max, math.ceil
  local sformat = string.format

  -- Decimals for a display range: wide ranges read as integers.
  local function decimalsFor(range)
    range = abs(range)
    if range >= 200 then return 0 end
    if range >= 20 then return 1 end
    return 2
  end

  local function fmtNumber(v, decimals)
    if v ~= v then return "0" end
    local s = sformat("%." .. decimals .. "f", v)
    if s == "-0" or s == "-0.0" or s == "-0.00" then s = s:sub(2) end
    return s
  end

  -- Travel position 0..1 -> normalised range position 0..1 (audio taper).
  local function audioForward(p)
    if p <= 0 then return 0 end
    for i = 2, #AUDIO_CURVE do
      local a, b = AUDIO_CURVE[i - 1], AUDIO_CURVE[i]
      if p <= b[1] then
        return a[2] + (b[2] - a[2]) * (p - a[1]) / (b[1] - a[1])
      end
    end
    return 1
  end

  -- Normalised range position -> travel position (inverse of audioForward).
  local function audioInverse(n)
    if n <= 0 then return 0 end
    for i = 2, #AUDIO_CURVE do
      local a, b = AUDIO_CURVE[i - 1], AUDIO_CURVE[i]
      if n <= b[2] then
        return a[1] + (b[1] - a[1]) * (n - a[2]) / (b[2] - a[2])
      end
    end
    return 1
  end

  Modes["Fader"] = {
    id = "fader",
    pretty = "Fader",
    hint = HINT,

    controls = function(C, props)
      C.add{ Name = "FaderMin", ControlType = "Knob", ControlUnit = "Float", Min = -1000, Max = 1000,
             DefaultValue = -100, PinStyle = "Input", Group = "Fader" }
      C.add{ Name = "FaderMax", ControlType = "Knob", ControlUnit = "Float", Min = -1000, Max = 1000,
             DefaultValue = 10, PinStyle = "Input", Group = "Fader" }
      C.add{ Name = "Units", ControlType = "Text", DefaultValue = "dB", PinStyle = "Input", Group = "Fader" }
      C.add{ Name = "FaderValue", ControlType = "Knob", ControlUnit = "Float", Min = -1000, Max = 1000,
             DefaultValue = -100, PinStyle = "Both", Group = "Fader" }
      C.add{ Name = "FaderPosition", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1,
             DefaultValue = 0, PinStyle = "Both", Group = "Fader" }
      C.add{ Name = "GrabMode", ControlType = "Text", DefaultValue = "Jump", PinStyle = "Input", Group = "Fader",
             Choices = { "Jump", "Relative" } }
      C.add{ Name = "Taper", ControlType = "Text", DefaultValue = "Linear", PinStyle = "Input", Group = "Fader",
             Choices = { "Linear", "Audio" } }
      C.add{ Name = "SnapCenter", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", Group = "Fader" }
      C.add{ Name = "DialTarget", ControlType = "Text", PinStyle = "Input", Group = "Fader" }
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "VALUE")
        L.fader("FaderValue", { ctx.side, ctx.sideY }, { 48, 120 })
        ctx.sideY = ctx.sideY + 128
        L.sideCaption(ctx, "OPTIONS")
        L.sideButton(ctx, "SnapCenter", "SNAP CENTRE")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "F A D E R", 3 * 48 + 2 * ctx.G)
        local cw = floor((iw - 2 * ctx.G) / 3)
        L.cell("FaderMin", ix, iy, cw, 48, { caption = "MIN" })
        L.cell("FaderMax", ix + cw + ctx.G, iy, cw, 48, { caption = "MAX" })
        L.cell("Units", ix + 2 * (cw + ctx.G), iy, cw, 48, { caption = "UNITS" })
        local y2 = iy + 48 + ctx.G
        L.cell("GrabMode", ix, y2, cw, 48, { caption = "GRAB (JUMP / RELATIVE)" })
        L.cell("Taper", ix + cw + ctx.G, y2, cw, 48, { caption = "TAPER (LINEAR / AUDIO)" })
        L.cell("SnapCenter", ix + 2 * (cw + ctx.G), y2, cw, 48, { caption = "SNAP CENTRE", legend = "SNAP" })
        L.cell("DialTarget", ix, y2 + 48 + ctx.G, iw, 48,
               { caption = "TARGET (CODENAME~CONTROL, DRIVEN POSITION-WISE)" })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local props = E.props or {}
      local vertical = tostring(props["Orientation"] or "Vertical") ~= "Horizontal"
      local short = min(W, H)
      local valueSize = U.clamp(floor(short * 0.11), 14, 40)
      local labelSize = U.clamp(floor(short * 0.045), 9, 13)
      local readH = valueSize + 12                  -- the readout band at the top
      local bottom = E.hint and 22 or 10            -- room for the hint line

      -- ---------- geometry ----------
      -- Vertical: travel from y0 (position 0, bottom) up to y1 (position 1).
      -- Horizontal: travel from x0 (position 0, left) to x1 (position 1).
      local g = { vertical = vertical }
      if vertical then
        g.capW = U.clamp(floor(W * 0.36), 32, 120)
        g.capH = U.clamp(floor(g.capW * 0.5), 18, 56)
        g.slot = U.clamp(floor(g.capW * 0.22), 8, 28)
        g.cx = W / 2
        g.y1 = readH + 10 + g.capH / 2
        g.y0 = H - bottom - 8 - g.capH / 2
        if g.y0 - g.y1 < 40 then                    -- a tiny pad: a slim cap
          g.capH = 14
          g.y1 = readH + 4 + 7
          g.y0 = H - bottom - 4 - 7
        end
        g.len = max(1, g.y0 - g.y1)
        g.cy = (g.y0 + g.y1) / 2
        g.x0, g.x1 = g.cx, g.cx
      else
        g.capH = U.clamp(floor(H * 0.36), 32, 120)  -- across the slot
        g.capW = U.clamp(floor(g.capH * 0.5), 18, 56)  -- along the slot
        g.slot = U.clamp(floor(g.capH * 0.22), 8, 28)
        local top, bot = readH + 10, H - bottom
        if bot - top < g.capH + 8 then g.capH = max(14, bot - top - 8) end
        local needed = g.capH + 16 + labelSize
        g.cy = top + g.capH / 2 + max(0, bot - top - needed) / 2
        g.x0 = g.capW / 2 + 12
        g.x1 = W - g.capW / 2 - 12
        g.len = max(1, g.x1 - g.x0)
        g.cx = (g.x0 + g.x1) / 2
        g.y0, g.y1 = g.cy, g.cy
      end

      local self = {
        p = 0,                 -- travel position 0..1
        raw = 0,               -- unsnapped position of the current touch
        lo = -100, hi = 10,    -- display range
        units = "dB",
        relative = false,      -- GrabMode
        audio = false,         -- Taper
        snap = false,          -- SnapCenter
        down = false,
        lx = nil, ly = nil,    -- last finger position (relative moves)
        static = nil,          -- cached slot, ticks and labels
        staticKey = nil,
        target = nil,          -- { ctl, name, wrote = { p, t } }
      }

      -- ---------- value helpers ----------
      local function range()
        local r = self.hi - self.lo
        if abs(r) < 1e-9 then r = 1 end
        return r
      end
      local function normOfPos(p)
        if self.audio then return audioForward(p) end
        return p
      end
      local function posOfNorm(n)
        if self.audio then return audioInverse(n) end
        return n
      end
      local function valueOf(p) return self.lo + normOfPos(U.clamp(p, 0, 1)) * range() end
      local function posOfValue(v)
        local n = (v - self.lo) / range()
        return posOfNorm(U.clamp(n, 0, 1))
      end
      local function decimals() return decimalsFor(range()) end
      local function readout(v)
        local s = fmtNumber(v, decimals())
        if self.units ~= "" then s = s .. " " .. self.units end
        return s
      end
      local function centrePos() return posOfValue((self.lo + self.hi) / 2) end
      local function snapped(p)
        if not self.snap then return p end
        local c = centrePos()
        if abs(p - c) <= SNAP then return c end
        return p
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
        if self.down then return end                     -- a resting finger owns the fader
        local ok, p = pcall(function() return ctl.Position end)
        if not ok or type(p) ~= "number" then return end
        local w = tg.wrote
        if w and abs(w.p - p) < 1e-6 and E.now() - w.t < ECHO_TIME then return end
        p = U.clamp(p, 0, 1)
        if abs(p - self.p) < 1e-9 then return end
        self.p = p
        E.out("FaderPosition", self.p)
        E.out("FaderValue", valueOf(self.p))
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
          E.status("Fader target: use CodeName~control", "warn")
          return
        end
        local comp = (type(Q) == "table" and type(Q.component) == "function") and Q.component(code) or nil
        if not comp then
          E.status("Fader target: no component named " .. code, "warn")
          return
        end
        local ok, ctl = pcall(function() return comp[name] end)
        if not ok or ctl == nil then
          E.status("Fader target: " .. code .. " has no control " .. name, "warn")
          return
        end
        local okp, p = pcall(function() return ctl.Position end)
        if not okp or type(p) ~= "number" then
          E.status("Fader target: " .. spec .. " has no position", "warn")
          return
        end
        local tg = { ctl = ctl, name = spec }
        self.target = tg
        local handler = function(c) targetReport(c) end
        if type(Q) == "table" and type(Q.guard) == "function" then handler = Q.guard("fader target", handler) end
        pcall(function() ctl.EventHandler = handler end)
        -- Start from the target's level.
        self.p = U.clamp(p, 0, 1)
        E.out("FaderPosition", self.p)
        E.out("FaderValue", valueOf(self.p))
        E.status("Fader target OK: " .. spec, "ok")
        E.invalidate()
      end

      -- ---------- position changes ----------
      local function setPos(p)
        p = U.clamp(p, 0, 1)
        if p ~= p then p = 0 end
        if abs(p - self.p) < 1e-12 then return false end
        self.p = p
        E.out("FaderPosition", self.p)
        E.out("FaderValue", valueOf(self.p))
        targetWrite(self.p)
        E.invalidate()
        return true
      end

      local function rangeChanged()
        self.static = nil
        E.out("FaderValue", valueOf(self.p))
        E.invalidate()
      end

      local function readInputs()
        local lo = E.ctl("FaderMin")
        local hi = E.ctl("FaderMax")
        local un = E.ctl("Units")
        local gm = E.ctl("GrabMode")
        local tp = E.ctl("Taper")
        local sn = E.ctl("SnapCenter")
        if lo and type(lo.Value) == "number" then self.lo = lo.Value end
        if hi and type(hi.Value) == "number" then self.hi = hi.Value end
        if un and type(un.String) == "string" then self.units = U.trim(un.String) end
        if gm and type(gm.String) == "string" then self.relative = U.lower(U.trim(gm.String)) == "relative" end
        if tp and type(tp.String) == "string" then self.audio = U.lower(U.trim(tp.String)) == "audio" end
        if sn then self.snap = sn.Boolean and true or false end
      end

      -- travel position of a pad point
      local function posAt(x, y)
        if vertical then return U.clamp((g.y0 - y) / g.len, 0, 1) end
        return U.clamp((x - g.x0) / g.len, 0, 1)
      end
      -- travel delta between two pad points
      local function deltaOf(x, y, lx, ly)
        if vertical then return (ly - y) / g.len end
        return (x - lx) / g.len
      end

      -- ---------- touch ----------
      function self:onTouchStart(x, y, t)
        self.down = true
        self.lx, self.ly = x, y
        if self.relative then
          self.raw = self.p
        else
          self.raw = posAt(x, y)                 -- Jump: the value lands under the finger
          setPos(snapped(self.raw))
        end
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        if self.relative then
          local lx, ly = self.lx or x, self.ly or y
          self.lx, self.ly = x, y
          self.raw = U.clamp(self.raw + deltaOf(x, y, lx, ly), 0, 1)
        else
          self.lx, self.ly = x, y
          self.raw = posAt(x, y)
        end
        setPos(snapped(self.raw))
      end

      function self:onTouchEnd(x, y, t, info)
        self.down = false
        self.lx, self.ly = nil, nil
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        self.down = true
        self.lx, self.ly = x, y                  -- re-anchor: no jump on a resumed drag
        self.raw = self.p
        E.invalidate()
      end

      function self:onLock(locked)
        if locked then
          self.down = false
          self.lx, self.ly = nil, nil
        end
        E.invalidate()
      end

      -- ---------- pins ----------
      function self:onControl(name, index, ctl)
        if name == "FaderValue" then
          local v = tonumber(ctl.Value)
          if v then setPos(posOfValue(v)) end
        elseif name == "FaderPosition" then
          local v = tonumber(ctl.Value)
          if v then setPos(v) end
        elseif name == "FaderMin" or name == "FaderMax" or name == "Units" or name == "Taper" then
          readInputs()
          rangeChanged()
        elseif name == "GrabMode" or name == "SnapCenter" then
          readInputs()
        elseif name == "DialTarget" then
          bindTarget(ctl.String)
        end
      end

      function self:onStart()
        readInputs()
        E.out("FaderPosition", self.p)
        E.out("FaderValue", valueOf(self.p))
        local tg = E.ctl("DialTarget")
        if tg and type(tg.String) == "string" and U.trim(tg.String) ~= "" then
          bindTarget(tg.String)
        end
      end

      -- ---------- drawing ----------
      -- Slot, ticks and labels only change with the range, the units and the
      -- taper: drawn once into a scratch canvas and replayed as one raw
      -- element.
      local function staticRaw()
        local key = tostring(self.lo) .. "|" .. tostring(self.hi) .. "|" .. self.units .. "|" .. tostring(self.audio)
        if self.static and self.staticKey == key then return self.static end
        local s = Svg.new(W, H, { limit = 20000 })
        local n = MAJOR_TICKS * (MINOR_PER + 1)
        local d = max(0, decimals() - 1)
        local slot = g.slot
        if vertical then
          s:rect(g.cx - slot / 2, g.y1 - slot / 2, slot, g.len + slot,
                 { fill = T.well, stroke = T.line, sw = 1, rx = slot / 2 })
          -- ticks on both sides of the cap's lane, labels on the left
          local room = g.cx - g.capW / 2 - 18
          local every = U.clamp(ceil(labelSize * 1.5 / (g.len / MAJOR_TICKS)), 1, MAJOR_TICKS)
          local xl = g.cx - g.capW / 2 - 6
          local xr = g.cx + g.capW / 2 + 6
          for i = 0, n do
            local y = g.y0 - (i / n) * g.len
            local major = (i % (MINOR_PER + 1)) == 0
            local tl = major and 10 or 5
            local col = major and T.muted or T.line
            s:line(xl - tl, y, xl, y, { stroke = col, sw = major and 2 or 1, cap = "round" })
            s:line(xr, y, xr + tl, y, { stroke = col, sw = major and 2 or 1, cap = "round" })
            if major and room >= 28 then
              local m = i // (MINOR_PER + 1)
              if m % every == 0 or m == MAJOR_TICKS then
                s:text(xl - 14, y + labelSize * 0.36, fmtNumber(valueOf(i / n), d),
                       { size = labelSize, fill = T.muted, anchor = "end" })
              end
            end
          end
        else
          s:rect(g.x0 - slot / 2, g.cy - slot / 2, g.len + slot, slot,
                 { fill = T.well, stroke = T.line, sw = 1, rx = slot / 2 })
          local every = U.clamp(ceil(labelSize * 2.8 / (g.len / MAJOR_TICKS)), 1, MAJOR_TICKS)
          local yb = g.cy + g.capH / 2 + 6
          local yt = g.cy - g.capH / 2 - 6
          local room = H - bottom - yb - 14
          for i = 0, n do
            local x = g.x0 + (i / n) * g.len
            local major = (i % (MINOR_PER + 1)) == 0
            local tl = major and 10 or 5
            local col = major and T.muted or T.line
            s:line(x, yb, x, yb + tl, { stroke = col, sw = major and 2 or 1, cap = "round" })
            s:line(x, yt - tl, x, yt, { stroke = col, sw = major and 2 or 1, cap = "round" })
            if major and room >= labelSize then
              local m = i // (MINOR_PER + 1)
              if m % every == 0 or m == MAJOR_TICKS then
                s:text(x, yb + 12 + labelSize, fmtNumber(valueOf(i / n), d),
                       { size = labelSize, fill = T.muted, anchor = "middle" })
              end
            end
          end
        end
        s.parts[1] = s.parts[1] or ""
        self.static = table.concat(s.parts)
        self.staticKey = key
        return self.static
      end

      function self:draw(c)
        c:raw(staticRaw())
        local p = self.p
        local cw, ch, slot = g.capW, g.capH, g.slot
        local stroke = self.down and T.accent or T.line
        local sw = self.down and 2 or 1
        if vertical then
          local yc = g.y0 - p * g.len
          if p > 0.001 then
            c:rect(g.cx - slot / 2 + 2, yc, slot - 4, g.y0 - yc + slot / 2 - 2,
                   { fill = T.accent, opacity = 0.9, rx = (slot - 4) / 2 })
          end
          if self.down then
            c:rect(g.cx - cw / 2 - 4, yc - ch / 2 - 4, cw + 8, ch + 8, { fill = T.accent, opacity = 0.25, rx = 8 })
          end
          c:rect(g.cx - cw / 2, yc - ch / 2, cw, ch, { fill = T.panel, stroke = stroke, sw = sw, rx = 6 })
          c:line(g.cx - cw / 2 + 6, yc, g.cx + cw / 2 - 6, yc, { stroke = T.accent2, sw = 3, cap = "round" })
        else
          local xc = g.x0 + p * g.len
          if p > 0.001 then
            c:rect(g.x0 - slot / 2 + 2, g.cy - slot / 2 + 2, xc - g.x0 + slot / 2 - 2, slot - 4,
                   { fill = T.accent, opacity = 0.9, rx = (slot - 4) / 2 })
          end
          if self.down then
            c:rect(xc - cw / 2 - 4, g.cy - ch / 2 - 4, cw + 8, ch + 8, { fill = T.accent, opacity = 0.25, rx = 8 })
          end
          c:rect(xc - cw / 2, g.cy - ch / 2, cw, ch, { fill = T.panel, stroke = stroke, sw = sw, rx = 6 })
          c:line(xc, g.cy - ch / 2 + 6, xc, g.cy + ch / 2 - 6, { stroke = T.accent2, sw = 3, cap = "round" })
        end
        -- readout
        c:textFit(W / 2, 6 + valueSize * 0.9, W - 16, readout(valueOf(p)),
                  { size = valueSize, fill = T.text, anchor = "middle", weight = "bold" })
        if E.hint and not self.down then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- white-box helpers for tests
      self.readout = readout
      self.valueOf = valueOf
      self.posOfValue = posOfValue
      self.geometry = g

      return self
    end,
  }
end
