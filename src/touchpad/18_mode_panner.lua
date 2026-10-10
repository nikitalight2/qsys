-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Panner mode
--
-- A two-dimensional panner over a speaker layout chosen by the `Speakers`
-- property (Stereo, LCR, Quad, 5.1, 7.1). The finger places the source in
-- the room: a touch jumps there, a drag follows, a double tap returns it to
-- the centre. Outputs: PanX and PanY (-1..1, x right, y forward), Pan (-1..1,
-- a stereo pan such as the Mic Mixer's MicPan: it equals PanX) and one
-- SpeakerGain per speaker in dB from a constant-power law on the distance
-- between the source and each speaker (a gaussian kernel whose width grows
-- with `Divergence`, normalised so the squared weights sum to one; weights
-- are clamped at 1e-4, so -80 dB is the floor). The LFE channel of 5.1 and
-- 7.1 has no position and stays at 0 dB. PanX, PanY and Pan are pins in both
-- directions: writing one moves the source and recomputes the gains.
--
-- The pad draws the room, every speaker with a glow that follows its gain,
-- the gain readouts and the source dot with two guide lines.
--
-- Design time (controls, layout) and the runtime `create(E)` live here. The
-- body is one do-block so the built chunk gains no top-level locals.

Modes = Modes or {}

do
  local HINT = "Drag to pan, double tap to centre"
  local FLOOR_W = 1e-4                      -- weight floor: 20*log10(1e-4) = -80 dB
  local SIGMA0, SIGMA1 = 0.25, 2.75         -- kernel width (room units) at Divergence 0 and 1

  local floor, abs, sqrt, min, max, exp, log = math.floor, math.abs, math.sqrt, math.min, math.max, math.exp, math.log
  local sformat = string.format

  -- Speaker layouts: { label, x, y } in room units (x right, y forward, the
  -- corners are +-1); an entry without a position is the LFE channel.
  local LAYOUTS = {
    ["Stereo"] = { { "L", -1, 1 }, { "R", 1, 1 } },
    ["LCR"]    = { { "L", -1, 1 }, { "C", 0, 1 }, { "R", 1, 1 } },
    ["Quad"]   = { { "L", -1, 1 }, { "R", 1, 1 }, { "Ls", -1, -1 }, { "Rs", 1, -1 } },
    ["5.1"]    = { { "L", -1, 1 }, { "C", 0, 1 }, { "R", 1, 1 }, { "Ls", -1, -0.35 }, { "Rs", 1, -0.35 }, { "LFE" } },
    ["7.1"]    = { { "L", -1, 1 }, { "C", 0, 1 }, { "R", 1, 1 }, { "Lss", -1, 0 }, { "Rss", 1, 0 },
                   { "Lrs", -0.7, -1 }, { "Rrs", 0.7, -1 }, { "LFE" } },
  }
  local LAYOUT_NAMES = { "Stereo", "LCR", "Quad", "5.1", "7.1" }

  -- The Speakers property at design time ({ Value = }) or at run time (plain).
  local function speakersOf(props)
    local v = type(props) == "table" and props["Speakers"] or nil
    if type(v) == "table" then v = v.Value end
    if type(v) ~= "string" or LAYOUTS[v] == nil then v = "Stereo" end
    return v
  end

  local function labelsOf(name)
    local parts = {}
    for i, s in ipairs(LAYOUTS[name]) do parts[i] = s[1] end
    return table.concat(parts, ", ")
  end

  -- Constant-power weights (0..1) of a source at (x, y) into `out`.
  local function computeWeights(layout, x, y, div, out)
    local sigma = SIGMA0 + (SIGMA1 - SIGMA0) * U.clamp(div, 0, 1)
    local inv = 1 / (sigma * sigma)
    local sum, placed = 0, 0
    for i = 1, #layout do
      local s = layout[i]
      if s[2] then
        local dx, dy = x - s[2], y - s[3]
        local r = exp(-(dx * dx + dy * dy) * inv)
        out[i] = r
        sum = sum + r * r
        placed = placed + 1
      else
        out[i] = -1
      end
    end
    local norm = (sum > 0) and (1 / sqrt(sum)) or nil
    for i = 1, #layout do
      local r = out[i]
      if r < 0 then
        out[i] = 1                            -- LFE: full level, not positional
      else
        local w = norm and (r * norm) or (1 / sqrt(max(1, placed)))
        if w < FLOOR_W then w = FLOOR_W end
        if w > 1 then w = 1 end
        out[i] = w
      end
    end
    return out
  end

  local function toDb(w)
    local db = 20 * log(w, 10)
    db = floor(db * 100 + 0.5) / 100
    if db < -80 then db = -80 end
    if db > 0 then db = 0 end
    return db
  end

  local function fmtDb(db)
    local s = sformat("%.1f", db)
    if s == "-0.0" then s = "0.0" end
    return s
  end

  local function fmtPan(v)
    local s = sformat("%+.2f", v)
    if s == "-0.00" then s = "+0.00" end
    return s
  end

  Modes["Panner"] = {
    id = "panner",
    pretty = "Panner",
    hint = HINT,

    controls = function(C, props)
      local n = #LAYOUTS[speakersOf(props)]
      C.add{ Name = "PanX", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1,
             DefaultValue = 0, PinStyle = "Both", Group = "Panner" }
      C.add{ Name = "PanY", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1,
             DefaultValue = 0, PinStyle = "Both", Group = "Panner" }
      C.add{ Name = "Pan", ControlType = "Knob", ControlUnit = "Float", Min = -1, Max = 1,
             DefaultValue = 0, PinStyle = "Both", Group = "Panner" }
      C.add{ Name = "SpeakerGain", Count = n, ControlType = "Knob", ControlUnit = "dB", Min = -80, Max = 0,
             DefaultValue = 0, PinStyle = "Output", Group = "Panner" }
      C.add{ Name = "Divergence", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1,
             DefaultValue = 0.5, PinStyle = "Input", Group = "Panner" }
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "PAN (STEREO)")
        L.knob("Pan", { ctx.side, ctx.sideY }, { 48, 48 })
        ctx.sideY = ctx.sideY + 56
        L.sideCaption(ctx, "DIVERGENCE")
        L.knob("Divergence", { ctx.side, ctx.sideY }, { 48, 48 }, { color = Nikita.Purple })
        ctx.sideY = ctx.sideY + 56
      elseif page == "Setup" then
        local name = speakersOf(props)
        local ix, iy, iw = L.section(ctx, "P A N N E R", 48 + ctx.G + 30)
        local cw = floor((iw - 3 * ctx.G) / 4)
        L.cell("Divergence", ix, iy, cw, 48, { caption = "DIVERGENCE" })
        L.cell("PanX", ix + cw + ctx.G, iy, cw, 48, { caption = "PAN X" })
        L.cell("PanY", ix + 2 * (cw + ctx.G), iy, cw, 48, { caption = "PAN Y" })
        L.cell("Pan", ix + 3 * (cw + ctx.G), iy, cw, 48, { caption = "PAN" })
        L.label(sformat("Speakers (%s): %s. Gains follow a constant-power law on the\ndistance to each speaker; Divergence widens the spread.",
                        name, labelsOf(name)), { ix, iy + 48 + ctx.G }, { iw, 28 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local layoutName = speakersOf(E.props)
      local layout = LAYOUTS[layoutName]
      local n = #layout

      -- ---------- geometry ----------
      local inset = min(10, floor(min(W, H) * 0.04))
      local rx, ry = inset, inset
      local rw = W - 2 * inset
      local rh = H - 2 * inset - (E.hint and 16 or 0)
      local m = max(22, floor(min(rw, rh) * 0.11))        -- speaker inset from the room edge
      local ax, ay, aw, ah = rx + m, ry + m, rw - 2 * m, rh - 2 * m
      if aw < 10 then aw = 10 end
      if ah < 10 then ah = 10 end
      local sr = max(6, floor(m * 0.28))                   -- speaker body radius
      local glowR = m * 0.95                               -- extra glow radius at full gain
      local labelSize = max(9, min(14, floor(m * 0.45)))
      local gainSize = max(8, labelSize - 2)
      local roomRadius = max(4, floor(inset * 1.2))

      local function toPad(x, y)
        return ax + (x + 1) / 2 * aw, ay + (1 - y) / 2 * ah
      end
      local function toRoom(px, py)
        local x = (px - ax) / aw * 2 - 1
        local y = 1 - (py - ay) / ah * 2
        return U.clamp(x, -1, 1), U.clamp(y, -1, 1)
      end

      -- Pad positions of the speakers (the LFE sits at the bottom centre).
      local spk = {}
      for i = 1, n do
        local s = layout[i]
        if s[2] then
          local px, py = toPad(s[2], s[3])
          spk[i] = { label = s[1], x = s[2], y = s[3], px = px, py = py, above = s[3] < 0 }
        else
          spk[i] = { label = s[1], lfe = true, px = rx + rw / 2, py = ry + rh - m * 0.5, above = true }
        end
      end

      local self = {
        x = 0, y = 0,            -- source in room units
        div = 0.5,
        down = false,
        w = {},                  -- weights 0..1 per speaker
        db = {},                 -- dB per speaker
        static = nil,
      }
      self.layoutName = layoutName
      self.geometry = { rx = rx, ry = ry, rw = rw, rh = rh, ax = ax, ay = ay, aw = aw, ah = ah, m = m, sr = sr }
      self.toPad = toPad
      self.toRoom = toRoom
      self.speakers = spk

      -- ---------- gains and outputs ----------
      local function updateGains()
        computeWeights(layout, self.x, self.y, self.div, self.w)
        for i = 1, n do
          local db = toDb(self.w[i])
          self.db[i] = db
          E.out("SpeakerGain", db, i)
        end
      end

      local function writePan()
        E.out("PanX", self.x)
        E.out("PanY", self.y)
        E.out("Pan", self.x)
      end

      local function setSource(x, y)
        x = U.clamp(tonumber(x) or 0, -1, 1)
        y = U.clamp(tonumber(y) or 0, -1, 1)
        if x ~= x then x = 0 end
        if y ~= y then y = 0 end
        if abs(x - self.x) < 1e-12 and abs(y - self.y) < 1e-12 then return false end
        self.x, self.y = x, y
        writePan()
        updateGains()
        E.invalidate()
        return true
      end

      local function readDivergence()
        local ctl = E.ctl("Divergence")
        if ctl and type(ctl.Value) == "number" then self.div = U.clamp(ctl.Value, 0, 1) end
      end

      -- ---------- touch ----------
      function self:onTouchStart(x, y, t)
        self.down = true
        setSource(toRoom(x, y))
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        setSource(toRoom(x, y))
      end

      function self:onTouchEnd(x, y, t, info)
        self.down = false
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        self.down = true
        setSource(toRoom(x, y))
        E.invalidate()
      end

      function self:onGesture(g)
        if g.type == "double" then
          setSource(0, 0)
          E.setGesture("Centre")
          E.invalidate()
        end
      end

      function self:onLock(locked)
        if locked then self.down = false end
        E.invalidate()
      end

      -- ---------- pins ----------
      function self:onControl(name, index, ctl)
        if name == "PanX" or name == "Pan" then
          local v = tonumber(ctl.Value)
          if v then setSource(v, self.y) end
        elseif name == "PanY" then
          local v = tonumber(ctl.Value)
          if v then setSource(self.x, v) end
        elseif name == "Divergence" then
          readDivergence()
          updateGains()
          E.invalidate()
        end
      end

      function self:onStart()
        readDivergence()
        writePan()
        updateGains()
      end

      -- ---------- drawing ----------
      -- The room, its centre lines and the speaker labels never change:
      -- drawn once into a scratch canvas and replayed as one raw element.
      local function staticRaw()
        if self.static then return self.static end
        local s = Svg.new(W, H, { limit = 20000 })
        s:rect(rx, ry, rw, rh, { fill = T.panel, stroke = T.line, sw = 1, rx = roomRadius })
        local cx, cy = toPad(0, 0)
        s:line(ax, cy, ax + aw, cy, { stroke = T.line, sw = 1, opacity = 0.7, dash = "3 5" })
        s:line(cx, ay, cx, ay + ah, { stroke = T.line, sw = 1, opacity = 0.7, dash = "3 5" })
        s:rect(ax, ay, aw, ah, { fill = "none", stroke = T.line, sw = 1, opacity = 0.5, rx = 3 })
        for i = 1, n do
          local p = spk[i]
          local ty = p.above and (p.py - sr - gainSize - 6) or (p.py + sr + labelSize + 2)
          s:text(p.px, ty, p.label, { size = labelSize, fill = T.text, anchor = "middle", weight = "bold" })
        end
        s.parts[1] = s.parts[1] or ""
        self.static = table.concat(s.parts)
        return self.static
      end

      function self:draw(c)
        c:gradient("pglow", "radial", { { 0, T.accent, 0.85 }, { 0.55, T.accent, 0.3 }, { 1, T.accent, 0 } })
        c:raw(staticRaw())
        -- speakers: glow, body and gain readout
        for i = 1, n do
          local p = spk[i]
          local w = self.w[i] or 0
          if p.lfe then
            c:rect(p.px - sr, p.py - sr, 2 * sr, 2 * sr, { fill = T.well, stroke = T.muted, sw = 1, rx = 3 })
          else
            c:circle(p.px, p.py, sr + glowR * w, { fill = "url(#pglow)", opacity = 0.2 + 0.8 * w })
            c:circle(p.px, p.py, sr, { fill = Svg.mix(T.panel, T.accent, 0.15 + 0.85 * w),
                                       stroke = (w > 0.5) and T.onAccent or T.muted, sw = 1 })
          end
          local gy = p.above and (p.py - sr - 4) or (p.py + sr + labelSize + gainSize + 4)
          c:text(p.px, gy, fmtDb(self.db[i] or -80), { size = gainSize, fill = T.muted, anchor = "middle" })
        end
        -- the source: guide lines across the inner area and the dot
        local sx, sy = toPad(self.x, self.y)
        c:line(ax, sy, ax + aw, sy, { stroke = T.accent, sw = 1, opacity = 0.35 })
        c:line(sx, ay, sx, ay + ah, { stroke = T.accent, sw = 1, opacity = 0.35 })
        if self.down then
          Shapes.dot(c, T, sx, sy, 9)
        else
          c:circle(sx, sy, 11, { fill = "none", stroke = T.accent, sw = 1.5, opacity = 0.6 })
          c:circle(sx, sy, 5, { fill = T.accent2, stroke = T.onAccent, sw = 1 })
        end
        -- position readout in the room's top corner opposite the finger
        local rtx = (self.x < 0) and (rx + rw - 6) or (rx + 6)
        c:text(rtx, ry + gainSize + 4, fmtPan(self.x) .. " / " .. fmtPan(self.y),
               { size = gainSize, fill = T.muted, anchor = (self.x < 0) and "end" or "start" })
        if E.hint and not self.down then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- white-box helpers for tests
      self.computeWeights = function(x, y, div)
        return computeWeights(layout, x, y, div, {})
      end
      self.fmtDb = fmtDb
      self.fmtPan = fmtPan

      return self
    end,
  }

  Modes["Panner"].layouts = LAYOUTS
  Modes["Panner"].layoutNames = LAYOUT_NAMES
end
