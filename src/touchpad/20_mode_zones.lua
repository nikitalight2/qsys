-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Zone Select mode
--
-- A set of named zones (a room plan, a seating map, a row of displays) drawn
-- on the pad. Tap toggles a zone; a drag that starts on a zone paints the
-- opposite of that zone's state across every zone it crosses; a closed lasso
-- drawn on empty space selects the zones whose centres it encloses; a long
-- press solos a zone; a double tap on empty space clears everything.
-- Exclusive turns the set into a radio group (one zone at a time).
-- Edit mode: drag a zone to move it, its bottom-right corner to resize it,
-- empty space to redraw the last touched zone; it switches off after 5 min
-- untouched and prints the layout. The layout lives in ZoneLayout as a JSON
-- list of {x, y, w, h} in 0..1 pad units; blank means the Columns grid.
--
-- Design time (controls, pages, layout) and the runtime `create(E)` live here.

Modes = Modes or {}

do
local HINT = "Tap, drag or circle zones"
local HINT_EDIT = "Edit: drag to move, corner to resize"
local MAX_ZONES = 32
local MIN_SIZE = 0.04           -- smallest zone side, pad units
local DRAG_START = 12           -- px: the engine's tap / drag boundary
local LASSO_MAX = 160           -- points kept on a lasso trail
local LASSO_TEST_MAX = 64       -- points used for the geometry tests
local LASSO_CLOSE = 0.10        -- end within this fraction of the diagonal from the start
local LASSO_MIN_PTS = 6
local LASSO_AREA = 0.02         -- of the pad area
local COMMIT_DELAY = 1.5        -- an inferred lift stays retractable this long (spec 5.3)
local EDIT_TIMEOUT = 300        -- s: edit mode switches off after this long untouched
local TRIGGER_DEBOUNCE = 0.5    -- s: a trigger's trailing edge does not act twice
local PAINT_STEP = 8            -- px between samples along a painting move
local PAINT_MAX = 16            -- samples per move at most

-- Zones property at design time (props[name] = {Value}) or at run time (E.props[name] = value).
local function zoneCount(props)
  local p = props and props["Zones"]
  if type(p) == "table" then p = p.Value end
  local v = math.floor((tonumber(p) or 8) + 0.5)
  if v < 1 then v = 1 elseif v > MAX_ZONES then v = MAX_ZONES end
  return v
end

Modes["Zone Select"] = {
  id = "zones",
  pretty = "Zone Select",
  hint = HINT,

  controls = function(C, props)
    local n = zoneCount(props)
    C.add{ Name = "ZoneName", Count = n, ControlType = "Text", PinStyle = "Input", Group = "Zones" }
    C.add{ Name = "ZoneSelected", Count = n, ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both", Group = "Zones" }
    C.add{ Name = "SelectAll", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Group = "Zones", Legend = "ALL" }
    C.add{ Name = "ClearAll", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Group = "Zones", Legend = "NONE" }
    C.add{ Name = "SelectedList", ControlType = "Text", PinStyle = "Output", Group = "Zones" }
    C.add{ Name = "Edit", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", Group = "Zones", Legend = "EDIT" }
    C.add{ Name = "ShowBackground", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", Group = "Zones",
           DefaultValue = true, Legend = "BACKGROUND" }
    C.add{ Name = "ZoneLayout", ControlType = "Text", PinStyle = "Both", Group = "Zones" }
    C.add{ Name = "Exclusive", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", Group = "Zones", Legend = "EXCLUSIVE" }
    C.add{ Name = "Columns", ControlType = "Knob", ControlUnit = "Integer", Min = 1, Max = 8, DefaultValue = 4,
           PinStyle = "Input", Group = "Zones" }
  end,

  -- pages: nil, so the framework adds the Names page (spec section 4).

  layout = function(L, page, props, ctx)
    if page == "Pad" then
      L.padDisplay(ctx)
      L.gesture(ctx)
      L.hint(ctx, HINT)
      L.sideCaption(ctx, "ZONES")
      L.sideButton(ctx, "SelectAll", "ALL")
      L.sideButton(ctx, "ClearAll", "NONE")
      L.sideCaption(ctx, "OPTIONS")
      L.sideButton(ctx, "Exclusive", "EXCLUSIVE")
      L.sideButton(ctx, "ShowBackground", "BACKGROUND")
      L.sideCaption(ctx, "LAYOUT")
      L.sideButton(ctx, "Edit", "EDIT")
      L.sideCaption(ctx, "SELECTED")
      L.readout("SelectedList", { ctx.side, ctx.sideY }, { ctx.sideW, 48 }, { fontSize = 9 })
      ctx.sideY = ctx.sideY + 56
    elseif page == "Setup" then
      local ix, iy, iw = L.section(ctx, "Z O N E S", 150)
      L.caption("COLUMNS", { ix, iy }, { 56, 10 })
      L.knob("Columns", { ix + 12, iy + 12 }, { 32, 32 }, { color = Nikita.Purple })
      L.label("Columns of the default grid, used while\nZone Layout is blank.", { ix + 64, iy + 12 }, { iw - 64, 28 })
      L.caption("ZONE LAYOUT: JSON LIST OF {x, y, w, h} IN 0..1 PAD UNITS", { ix, iy + 52 }, { iw, 10 }, "Left")
      L.text("ZoneLayout", { ix, iy + 64 }, { iw, 56 }, { fontSize = 9 })
      L.label("Blank = the grid. Edit mode writes the layout here when a zone changes.", { ix, iy + 126 }, { iw, 14 })
    elseif page == "Names" then
      L.grid(L.keys("ZoneName"), ctx.x, ctx.y, 4, 176, 40)
    end
  end,

  padColour = function(T)
    return T.bg
  end,

  create = function(E)
    local W, H, T = E.W, E.H, E.T
    local DIAG = math.sqrt(W * W + H * H)
    local N = zoneCount(E.props)
    local FAMILY = E.props["Font"]
    local inset = math.min(10, math.floor(math.min(W, H) * 0.04))
    local self = {
      zones = {},        -- [i] = { x, y, w, h } in 0..1 pad units
      names = {},        -- [i] = ZoneName string (trimmed)
      sel = {},          -- [i] = boolean
      custom = false,    -- a ZoneLayout is in force (Columns no longer applies)
      cols = 4,
      edit = false, exclusive = false, background = true,
      last = nil,        -- last touched zone (edit target)
      touch = nil,       -- live touch record
      parked = nil,      -- touch record of an inferred lift that may be resumed
      pending = nil,     -- { touch, handle }: a lasso waiting for its commit
      editTimer = nil, editDirty = false,
      cache = {},        -- [i] = { key, svg } rendered tile fragments
      grid = nil,        -- cached dotted grid
      actAt = -1,        -- last trigger action time (debounce)
    }

    -- ---------- helpers ----------
    local function labelOf(i)
      local n = self.names[i]
      if n == nil or n == "" then return "Zone " .. i end
      return n
    end

    local function ctlBool(name, index)
      local c = E.ctl(name, index)
      return c ~= nil and c.Boolean == true
    end

    local function gridZones()
      local cols = math.min(self.cols, N)
      local rows = math.ceil(N / cols)
      local m, g = 0.03, 0.02
      local mb = m + (E.hint and (20 / H) or 0)
      local w = (1 - 2 * m - (cols - 1) * g) / cols
      local h = (1 - m - mb - (rows - 1) * g) / rows
      for i = 1, N do
        local c, r = (i - 1) % cols, (i - 1) // cols
        self.zones[i] = { x = m + c * (w + g), y = m + r * (h + g), w = w, h = h }
      end
    end

    -- Applies a ZoneLayout text; blank restores the grid. Returns false on bad JSON.
    local function applyLayout(text)
      text = U.trim(tostring(text or ""))
      if text == "" then
        self.custom = false
        gridZones()
        return true
      end
      local list = E.json.decode(text)
      if type(list) ~= "table" then return false end
      gridZones()
      local n = 0
      for i = 1, N do
        local z = list[i]
        if type(z) == "table" then
          local x, y, w, h = tonumber(z.x), tonumber(z.y), tonumber(z.w), tonumber(z.h)
          if x and y and w and h then
            w, h = U.clamp(w, MIN_SIZE, 1), U.clamp(h, MIN_SIZE, 1)
            x, y = U.clamp(x, 0, 1 - w), U.clamp(y, 0, 1 - h)
            self.zones[i] = { x = x, y = y, w = w, h = h }
            n = n + 1
          end
        end
      end
      self.custom = n > 0
      return true
    end

    local function layoutJson()
      local list = {}
      for i = 1, N do
        local z = self.zones[i]
        list[i] = { x = U.round(z.x, 3), y = U.round(z.y, 3), w = U.round(z.w, 3), h = U.round(z.h, 3) }
      end
      return E.json.encode(list)
    end

    local function inZone(i, x, y)
      local z = self.zones[i]
      local zx, zy = z.x * W, z.y * H
      return x >= zx and x <= zx + z.w * W and y >= zy and y <= zy + z.h * H
    end

    -- Topmost zone under a pad point, or nil. In edit mode the picked zone
    -- is on top (it is also drawn last).
    local function zoneAt(x, y)
      if self.edit and self.last and inZone(self.last, x, y) then return self.last end
      for i = N, 1, -1 do
        if inZone(i, x, y) then return i end
      end
      return nil
    end

    local function handleSize(w, h)
      return U.clamp(math.min(w, h) * 0.3, 14, 32)
    end

    local function cornerHit(i, x, y)
      local z = self.zones[i]
      local w, h = z.w * W, z.h * H
      local hs = handleSize(w, h)
      return x >= z.x * W + w - hs and y >= z.y * H + h - hs
    end

    -- ---------- selection ----------
    local function publish()
      local parts, k = {}, 0
      for i = 1, N do
        if self.sel[i] then
          k = k + 1
          parts[k] = labelOf(i)
        end
      end
      E.out("SelectedList", table.concat(parts, ", "))
    end

    local function setZone(i, on)
      on = on and true or false
      if self.sel[i] == on then return false end
      self.sel[i] = on
      E.out("ZoneSelected", on, i)
      return true
    end

    local function clearOthers(keep)
      for i = 1, N do
        if i ~= keep then setZone(i, false) end
      end
    end

    local function selectOnly(i)
      clearOthers(i)
      setZone(i, true)
    end

    local function toggle(i)
      local on = not self.sel[i]
      if on and self.exclusive then clearOthers(i) end
      setZone(i, on)
      publish()
      E.setGesture(labelOf(i) .. (on and " ON" or " OFF"))
      E.invalidate()
    end

    local function clearAll(text)
      for i = 1, N do setZone(i, false) end
      publish()
      E.setGesture(text or "ALL CLEARED")
      E.invalidate()
    end

    local function selectAll()
      if self.exclusive then
        E.setGesture("EXCLUSIVE: ONE ZONE AT A TIME")
        return
      end
      for i = 1, N do setZone(i, true) end
      publish()
      E.setGesture("ALL SELECTED")
      E.invalidate()
    end

    local function setExclusive(on)
      self.exclusive = on and true or false
      if self.exclusive then
        local keep = nil
        for i = 1, N do
          if self.sel[i] then
            if keep then setZone(i, false) else keep = i end
          end
        end
        publish()
      end
      E.invalidate()
    end

    -- A trigger acts on its rising edge; a handler that runs with the value
    -- already false acts too unless it just did.
    local function fired(ctl)
      local now = E.now()
      if ctl.Boolean or now - self.actAt > TRIGGER_DEBOUNCE then
        self.actAt = now
        return true
      end
      return false
    end

    -- ---------- edit mode ----------
    local function armEdit()
      if self.editTimer then self.editTimer:cancel() end
      self.editTimer = E.after(EDIT_TIMEOUT, function()
        self.editTimer = nil
        if not self.edit then return end
        E.out("Edit", false)
        self.setEdit(false, "EDIT OFF: 5 MIN UNTOUCHED")
      end)
    end

    function self.setEdit(on, why)
      on = on and true or false
      if self.edit == on then return end
      self.edit = on
      self.touch = nil
      self.parked = nil
      if on then
        self.editDirty = false
        armEdit()
        E.setGesture("EDIT ON")
      else
        if self.editTimer then
          self.editTimer:cancel()
          self.editTimer = nil
        end
        local js = layoutJson()
        if self.editDirty then
          self.custom = true
          E.out("ZoneLayout", js)
        end
        E.log("Zone layout: " .. js)
        E.setGesture(why or "EDIT OFF")
      end
      E.invalidate()
    end

    -- ---------- lasso ----------
    local function addPoint(tc, x, y)
      if U.dist(tc.lx, tc.ly, x, y) < (tc.step or math.max(4, DIAG * 0.008)) then return end
      if tc.n >= LASSO_MAX then
        -- Trail full: keep every other point so the path still ends at the finger.
        local pts, half = tc.pts, 0
        for k = 1, tc.n, 2 do
          half = half + 1
          pts[2 * half - 1], pts[2 * half] = pts[2 * k - 1], pts[2 * k]
        end
        for k = 2 * half + 1, 2 * tc.n do pts[k] = nil end
        tc.n = half
        tc.step = (tc.step or math.max(4, DIAG * 0.008)) * 2
      end
      tc.n = tc.n + 1
      tc.pts[2 * tc.n - 1], tc.pts[2 * tc.n] = x, y
      tc.lx, tc.ly = x, y
    end

    -- Closed path (end near the start, at least 6 points, area over 2 % of
    -- the pad): selects the zones whose centres it encloses.
    local function commitLasso(tc)
      local pts, n = tc.pts, tc.n
      if n < LASSO_MIN_PTS then return false end
      if U.dist(pts[1], pts[2], pts[2 * n - 1], pts[2 * n]) > LASSO_CLOSE * DIAG then return false end
      local poly = pts
      if n > LASSO_TEST_MAX then
        -- Decimate for the geometry tests; the first point is kept.
        poly = {}
        local step = n / LASSO_TEST_MAX
        for k = 0, LASSO_TEST_MAX - 1 do
          local i = math.floor(k * step) + 1
          poly[2 * k + 1], poly[2 * k + 2] = pts[2 * i - 1], pts[2 * i]
        end
      end
      if U.polyArea(poly) < LASSO_AREA * W * H then return false end
      local hits = 0
      for i = 1, N do
        local z = self.zones[i]
        if U.pointInPoly((z.x + z.w / 2) * W, (z.y + z.h / 2) * H, poly) then
          hits = hits + 1
          if self.exclusive then
            if hits == 1 then selectOnly(i) end
          else
            setZone(i, true)
          end
        end
      end
      publish()
      E.setGesture("LASSO: " .. hits .. (hits == 1 and " ZONE" or " ZONES"))
      E.invalidate()
      return true
    end

    local function flushPending()
      local p = self.pending
      if not p then return end
      self.pending = nil
      if p.handle then p.handle:cancel() end
      commitLasso(p.touch)
    end

    -- ---------- painting ----------
    local function paintAt(tc, x, y)
      local i = zoneAt(x, y)
      if not i then return end
      if self.exclusive then
        if not self.sel[i] then
          selectOnly(i)
          tc.changed = true
          tc.count = 1
        end
        return
      end
      if tc.painted[i] then return end
      tc.painted[i] = true
      if setZone(i, tc.target) then
        tc.changed = true
        tc.count = tc.count + 1
      end
    end

    local function paintSegment(tc, x, y)
      local d = U.dist(tc.px, tc.py, x, y)
      local steps = math.min(PAINT_MAX, math.max(1, math.ceil(d / PAINT_STEP)))
      for s = 1, steps do
        local f = s / steps
        paintAt(tc, tc.px + (x - tc.px) * f, tc.py + (y - tc.py) * f)
      end
    end

    -- ---------- edit geometry ----------
    local function editMove(tc, x, y)
      local z, z0 = self.zones[tc.zone], tc.z0
      if tc.kind == "move" then
        z.x = U.clamp(z0.x + (x - tc.x0) / W, 0, 1 - z.w)
        z.y = U.clamp(z0.y + (y - tc.y0) / H, 0, 1 - z.h)
      elseif tc.kind == "resize" then
        z.w = U.clamp(z0.w + (x - tc.x0) / W, MIN_SIZE, 1 - z.x)
        z.h = U.clamp(z0.h + (y - tc.y0) / H, MIN_SIZE, 1 - z.y)
      elseif tc.kind == "redraw" then
        local x0, x1 = math.min(tc.x0, x) / W, math.max(tc.x0, x) / W
        local y0, y1 = math.min(tc.y0, y) / H, math.max(tc.y0, y) / H
        z.w = U.clamp(x1 - x0, MIN_SIZE, 1)
        z.h = U.clamp(y1 - y0, MIN_SIZE, 1)
        z.x = U.clamp(x0, 0, 1 - z.w)
        z.y = U.clamp(y0, 0, 1 - z.h)
      else
        return
      end
      tc.changed = true
    end

    local EDIT_VERB = { move = "MOVED ", resize = "RESIZED ", redraw = "REDREW " }

    -- ---------- touch events ----------
    function self:onTouchStart(x, y, t)
      self.parked = nil
      flushPending()
      local i = zoneAt(x, y)
      local tc = { x0 = x, y0 = y, px = x, py = y, zone = i, dragging = false, kind = "none",
                   painted = {}, changed = false, count = 0 }
      if self.edit then
        if i then
          self.last = i
          tc.kind = cornerHit(i, x, y) and "resize" or "move"
        elseif self.last then
          tc.zone = self.last
          tc.kind = "redraw"
        end
        if tc.zone then
          local z = self.zones[tc.zone]
          tc.z0 = { x = z.x, y = z.y, w = z.w, h = z.h }
        end
      elseif i then
        tc.kind = "paint"
      else
        tc.kind = "lasso"
        tc.pts, tc.n, tc.lx, tc.ly = { x, y }, 1, x, y
      end
      self.touch = tc
      E.invalidate()
    end

    function self:onTouchMove(x, y, t, dx, dy)
      local tc = self.touch
      if not tc then return end
      if not tc.dragging and U.dist(tc.x0, tc.y0, x, y) >= DRAG_START then
        tc.dragging = true
        if tc.kind == "paint" then
          tc.target = not self.sel[tc.zone]
          paintAt(tc, tc.x0, tc.y0)
        end
      end
      if tc.kind == "lasso" then
        addPoint(tc, x, y)
      elseif tc.dragging then
        if tc.kind == "paint" then
          paintSegment(tc, x, y)
        else
          editMove(tc, x, y)
        end
      end
      tc.px, tc.py = x, y
      E.invalidate()
    end

    function self:onTouchEnd(x, y, t, info)
      local tc = self.touch
      self.touch = nil
      if not tc then return end
      if info.aborted then
        E.invalidate()
        return
      end
      if tc.kind == "lasso" then
        if tc.dragging then
          addPoint(tc, x, y)
          if info.inferred then
            self.parked = tc
            self.pending = { touch = tc }
            self.pending.handle = E.after(COMMIT_DELAY, function()
              local p = self.pending
              self.pending = nil
              self.parked = nil
              if p then
                if not commitLasso(p.touch) then E.invalidate() end
              end
            end)
          else
            commitLasso(tc)
          end
        end
      elseif tc.kind == "paint" then
        if tc.changed then
          publish()
          if self.exclusive then
            E.setGesture(labelOf(zoneAt(x, y) or tc.zone) .. " ON")
          else
            E.setGesture("PAINTED " .. tc.count .. (tc.target and " ON" or " OFF"))
          end
        end
        if info.inferred and tc.dragging then self.parked = tc end
      elseif self.edit then
        if tc.changed then
          self.editDirty = true
          self.custom = true
          E.out("ZoneLayout", layoutJson())
          E.setGesture((EDIT_VERB[tc.kind] or "") .. labelOf(tc.zone))
        end
        if info.inferred and tc.dragging then self.parked = tc end
        armEdit()
      end
      E.invalidate()
    end

    -- An inferred lift taken back: the same drag goes on.
    function self:onTouchResume(x, y, t)
      local tc = self.parked
      self.parked = nil
      local p = self.pending
      if p then
        self.pending = nil
        if p.handle then p.handle:cancel() end
        tc = tc or p.touch
      end
      if tc then
        self.touch = tc
        if tc.kind == "lasso" then addPoint(tc, x, y) end
      end
      E.invalidate()
    end

    function self:onGesture(g)
      local i = zoneAt(g.x, g.y)
      if g.type == "tap" then
        if self.edit then
          if i then
            self.last = i
            E.setGesture(labelOf(i) .. " PICKED")
            E.invalidate()
          end
          armEdit()
        elseif i then
          toggle(i)
        end
      elseif g.type == "double" then
        if self.edit then return end
        if i then
          -- The two taps toggled twice; a double tap on a zone toggles it once.
          toggle(i)
        else
          clearAll("DOUBLE TAP: ALL CLEARED")
        end
      elseif g.type == "long" then
        if self.edit or not i then return end
        selectOnly(i)
        publish()
        E.setGesture("SOLO " .. labelOf(i))
        E.invalidate()
      end
    end

    function self:onLock(locked)
      if locked then
        self.touch = nil
        self.parked = nil
        local p = self.pending
        self.pending = nil
        if p and p.handle then p.handle:cancel() end
      end
      E.invalidate()
    end

    -- ---------- control pins ----------
    function self:onControl(name, index, ctl)
      if name == "ZoneSelected" then
        if index < 1 or index > N then return end
        local on = ctl.Boolean and true or false
        if on and self.exclusive then clearOthers(index) end
        self.sel[index] = on
        publish()
      elseif name == "ZoneName" then
        if index < 1 or index > N then return end
        self.names[index] = U.trim(tostring(ctl.String or ""))
        publish()
      elseif name == "SelectAll" then
        if fired(ctl) then selectAll() end
        return
      elseif name == "ClearAll" then
        if fired(ctl) then clearAll("ALL CLEARED") end
        return
      elseif name == "Edit" then
        self.setEdit(ctl.Boolean)
        return
      elseif name == "ShowBackground" then
        self.background = ctl.Boolean and true or false
      elseif name == "Exclusive" then
        setExclusive(ctl.Boolean)
        return
      elseif name == "ZoneLayout" then
        if not applyLayout(ctl.String) then
          E.status("Zone Layout: not a JSON list of {x, y, w, h}", "warn")
        end
      elseif name == "Columns" then
        self.cols = U.clamp(math.floor((tonumber(ctl.Value) or 4) + 0.5), 1, 8)
        if not self.custom then gridZones() end
      else
        return
      end
      E.invalidate()
    end

    -- ---------- drawing ----------
    local function gridRaw()
      if self.grid then return self.grid end
      local scratch = Svg.new(W, H, { limit = 20000, family = FAMILY })
      Shapes.gridDots(scratch, T, W - 2 * inset, H - 2 * inset, 24)
      self.grid = '<g transform="translate(' .. Svg.num(inset) .. " " .. Svg.num(inset) .. ')">'
        .. table.concat(scratch.parts) .. "</g>"
      return self.grid
    end

    -- A zone tile is rendered once per (state, geometry, name) and replayed.
    -- At most TILE_RENDERS tiles are re-rendered per frame: a stale tile keeps
    -- its old fragment for one frame and the mode asks for another frame.
    local TILE_RENDERS = 10
    local renders, stale = 0, false

    local function tileFrag(i)
      local z = self.zones[i]
      local on = self.sel[i] and true or false
      local mode = self.edit and ((self.last == i) and "e" or "E") or "-"
      local key = (on and "1" or "0") .. mode .. z.x .. "," .. z.y .. "," .. z.w .. "," .. z.h .. "|" .. labelOf(i)
      local e = self.cache[i]
      if e and e.key == key then return e.svg end
      if e and renders >= TILE_RENDERS then
        stale = true
        return e.svg
      end
      renders = renders + 1
      local x, y, w, h = z.x * W, z.y * H, z.w * W, z.h * H
      local s = Svg.new(W, H, { limit = 6000, family = FAMILY })
      local size = U.clamp(math.floor(math.min(h * 0.38, w * 0.18)), 9, 16)
      local picked = self.edit and self.last == i
      Shapes.tile(s, T, x, y, w, h, labelOf(i),
        { on = on, radius = math.min(10, h / 4), size = size, picked = picked,
          accent = picked and T.accent2 or nil })
      if self.edit then
        local hs = handleSize(w, h)
        s:rect(x + w - hs, y + h - hs, hs - 2, hs - 2,
          { fill = picked and T.accent2 or T.muted, opacity = 0.85, rx = 2 })
        s:text(x + w - hs / 2 - 1, y + h - hs / 2 + 3, tostring(i),
          { size = 9, fill = T.onAccent, anchor = "middle", weight = "bold" })
      end
      local svg = table.concat(s.parts)
      self.cache[i] = { key = key, svg = svg }
      return svg
    end

    function self:draw(c)
      renders, stale = 0, false
      if self.background then
        c:rect(inset, inset, W - 2 * inset, H - 2 * inset,
          { fill = T.panel, stroke = T.line, sw = 1, rx = math.max(4, math.floor(inset * 1.2)) })
        c:raw(gridRaw())
      end
      local top = self.edit and self.last or nil
      for i = 1, N do
        if i ~= top then c:raw(tileFrag(i)) end
      end
      if top then c:raw(tileFrag(top)) end
      local tc = self.touch
      local pendingTrail = false
      if not tc and self.pending then
        tc = self.pending.touch
        pendingTrail = true
      end
      if tc and tc.kind == "lasso" and tc.n >= 2 then
        c:polyline(tc.pts, { stroke = T.accent, sw = 2, opacity = 0.9, cap = "round",
                             dash = pendingTrail and "6 5" or nil })
        c:circle(tc.pts[1], tc.pts[2], 5, { fill = T.accent, opacity = 0.8 })
      end
      if self.edit then
        c:text(W - 10, 18, "EDIT", { size = 12, fill = T.accent2, anchor = "end", weight = "bold" })
      end
      if E.hint and not self.touch then
        Shapes.hint(c, T, self.edit and HINT_EDIT or HINT, W, H)
      end
      if stale then E.invalidate() end     -- the rest of the tiles on the next frame
    end

    -- ---------- start-up state ----------
    for i = 1, N do
      local nm = E.ctl("ZoneName", i)
      self.names[i] = nm and U.trim(tostring(nm.String or "")) or ""
      self.sel[i] = ctlBool("ZoneSelected", i)
    end
    local colsCtl = E.ctl("Columns")
    self.cols = U.clamp(math.floor((colsCtl and tonumber(colsCtl.Value) or 4) + 0.5), 1, 8)
    self.background = ctlBool("ShowBackground")
    self.exclusive = ctlBool("Exclusive")
    local layoutCtl = E.ctl("ZoneLayout")
    if not applyLayout(layoutCtl and layoutCtl.String or "") then gridZones() end

    function self:onStart()
      if self.exclusive then setExclusive(true) end
      publish()
      if ctlBool("Edit") then self.setEdit(true) end
    end

    return self
  end,
}
end
