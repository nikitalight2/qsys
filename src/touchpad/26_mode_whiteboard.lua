-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Whiteboard mode
--
-- Freehand drawing for annotation. One finger draws strokes in the pen
-- colour (`PenColor`: Accent, White, Black, Red, Green, Blue) and width
-- (`PenWidth` 1..8); a touch without movement draws a dot. `Eraser` turns the
-- finger into an eraser that removes every stroke it crosses. `Undo` removes
-- the last stroke, `ClearBoard` empties the board, `Strokes` carries the
-- stroke count, and `Snapshot` writes the board as `<base>/Whiteboard/
-- <time>.svg` (design/ in Emulate, media/ on a Core) and names the file on
-- `LastFile`.
--
-- Stroke engine (shared design with Sign-In): coordinates sit on a 0.5 px
-- grid, points closer than 1 px are skipped, raw points are simplified
-- (Ramer-Douglas-Peucker) in chunks of 24 while the finger moves so no single
-- handler simplifies a long stroke at once, a stroke keeps at most 400 points
-- (halved when it grows past that), the board keeps at most 60 strokes (the
-- oldest is dropped) and at most 2400 points (the oldest strokes are halved),
-- so the SVG stays far under the canvas limit.
--
-- Rendering budget: a finished stroke is one cached element string replayed
-- through c:raw; the live stroke is rendered chunk by chunk as it is
-- simplified, plus its raw tail each frame; a stroke that just ended reuses
-- its chunk elements, and strokes whose cached rendering is out of date (just
-- ended, or halved by the board cap) are re-rendered one per frame on later
-- frames, never in the dispatch that changed them.
--
-- The whole body sits in a `do` block: the built plugin is one chunk with a
-- 200-local limit, so only Modes["Whiteboard"] is defined at the top level.

Modes = Modes or {}

do
  local HINT = "Draw with one finger"
  local ERASE_HINT = "Eraser: drag across a stroke to remove it"
  local COLOR_NAMES = { "Accent", "White", "Black", "Red", "Green", "Blue" }
  -- Pen colours are content the user picks, not theme: White must be white.
  -- Accent follows the theme (T.accent).
  local COLOR_HEX = { white = "#FFFFFF", black = "#000000", red = "#E53935", green = "#43A047", blue = "#1E88E5" }
  local MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH = 1, 8, 3
  local MAX_STROKES = 60          -- strokes on the board (the oldest is dropped)
  local MAX_POINTS = 400          -- kept points per stroke
  local MAX_TOTAL = 2400          -- kept points on the whole board
  local CHUNK = 24                -- raw points simplified at a time
  local SIMPLIFY_TOL = 0.8        -- px
  local MIN_STEP = 1.0            -- px between raw points
  local DOT_MOVE = 2.5            -- px: a touch that moved less is a dot
  local TRIGGER_GUARD = 0.5       -- s: the trailing edge of a pulse just handled is not a second press
  local RESUME_WINDOW = 1.6       -- s: a stroke ended by an inferred lift can be continued
  local TOAST = 1.5               -- s: "Saved" / "Not saved" on the pad
  local REFRESH_AFTER = 0.06      -- s: between lazy re-renders
  local STROKE_SVG_LIMIT = 12000  -- one stroke of 400 points needs about 5000 characters

  local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
  local concat = table.concat

  -- ---------- geometry helpers ----------

  -- Squared distance from P to the segment AB.
  local function segDist2(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = 0
    if l2 > 0 then
      t = ((px - ax) * dx + (py - ay) * dy) / l2
      if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local qx, qy = ax + t * dx - px, ay + t * dy - py
    return qx * qx + qy * qy
  end

  local function cross(ax, ay, bx, by, cx, cy)
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
  end

  -- True when the segments AB and CD cross properly.
  local function segmentsCross(ax, ay, bx, by, cx, cy, dx, dy)
    local d1 = cross(cx, cy, dx, dy, ax, ay)
    local d2 = cross(cx, cy, dx, dy, bx, by)
    local d3 = cross(ax, ay, bx, by, cx, cy)
    local d4 = cross(ax, ay, bx, by, dx, dy)
    return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))
  end

  -- ---------- stroke engine ----------

  -- Coordinates are kept on a 0.5 px grid: a finger does not need more, and
  -- the canvas formats far fewer distinct numbers (its number cache holds
  -- 4096 entries; a full board would thrash it).
  local function q2(v)
    return floor(v * 2 + 0.5) / 2
  end

  local function newStroke(x, y, color, width)
    x, y = q2(x), q2(y)
    return { pts = { x, y }, raw = { x, y }, color = color, width = width, moved = 0,
             minX = x, minY = y, maxX = x, maxY = y, dot = false,
             svg = nil,             -- finished: cached element string
             stale = false, staleAt = 0,   -- finished: svg shows the right shape but wants a re-render
             keptParts = nil }      -- live: rendered chunks of the kept points
  end

  local function pointCount(s)
    return #s.pts // 2
  end

  -- Keeps the first, the last and every second interior point. A cached
  -- rendering stays (same shape, more points) and is refreshed lazily.
  local function decimate(s, now)
    local pts = s.pts
    local n = #pts // 2
    if n <= 2 then return end
    local out = { pts[1], pts[2] }
    for i = 2, n - 1, 2 do
      out[#out + 1] = pts[2 * i - 1]
      out[#out + 1] = pts[2 * i]
    end
    out[#out + 1] = pts[2 * n - 1]
    out[#out + 1] = pts[2 * n]
    s.pts = out
    s.keptParts = nil
    if s.svg then s.stale, s.staleAt = true, now end
  end

  -- Simplifies the raw tail into the kept points; onFlush(s, chunk) gets the
  -- simplified chunk (its first point is the last kept point before it, so
  -- the joined polyline is contiguous).
  local function flushRaw(s, onFlush, now)
    local raw = s.raw
    local n = #raw // 2
    if n <= 1 then return end
    local simp = U.simplify(raw, SIMPLIFY_TOL)
    local pts = s.pts
    for i = 3, #simp do pts[#pts + 1] = simp[i] end
    s.raw = { simp[#simp - 1], simp[#simp] }
    if onFlush then onFlush(s, simp) end
    if #pts // 2 > MAX_POINTS then decimate(s, now) end
  end

  local function addPoint(s, x, y, onFlush, now)
    x, y = q2(x), q2(y)
    local raw = s.raw
    local n = #raw
    local lx, ly = raw[n - 1], raw[n]
    local dx, dy = x - lx, y - ly
    if dx * dx + dy * dy < MIN_STEP * MIN_STEP then return false end
    raw[n + 1], raw[n + 2] = x, y
    if x < s.minX then s.minX = x elseif x > s.maxX then s.maxX = x end
    if y < s.minY then s.minY = y elseif y > s.maxY then s.maxY = y end
    local ox, oy = s.pts[1], s.pts[2]
    local d = sqrt((x - ox) * (x - ox) + (y - oy) * (y - oy))
    if d > s.moved then s.moved = d end
    if #raw // 2 >= CHUNK + 1 then flushRaw(s, onFlush, now) end
    return true
  end

  local function finishStroke(s, onFlush, now)
    flushRaw(s, onFlush, now)
    s.dot = (s.moved < DOT_MOVE) or pointCount(s) < 2
  end

  -- True when the finger segment AB passes within r of the stroke.
  local function strokeHit(s, ax, ay, bx, by, r)
    local reach = r + s.width / 2
    local sx0, sy0 = min(ax, bx) - reach, min(ay, by) - reach
    local sx1, sy1 = max(ax, bx) + reach, max(ay, by) + reach
    if s.maxX < sx0 or s.minX > sx1 or s.maxY < sy0 or s.minY > sy1 then return false end
    local pts = s.pts
    local n = #pts // 2
    local r2 = reach * reach
    if s.dot or n < 2 then
      return segDist2(pts[1], pts[2], ax, ay, bx, by) <= r2
    end
    local px, py = pts[1], pts[2]
    if segDist2(px, py, ax, ay, bx, by) <= r2 then return true end
    for i = 2, n do
      local qx, qy = pts[2 * i - 1], pts[2 * i]
      -- the segment's own box first: most segments are far from the finger
      local lo, hi = min(px, qx), max(px, qx)
      if hi >= sx0 and lo <= sx1 then
        lo, hi = min(py, qy), max(py, qy)
        if hi >= sy0 and lo <= sy1 then
          if segDist2(qx, qy, ax, ay, bx, by) <= r2 then return true end
          if segmentsCross(ax, ay, bx, by, px, py, qx, qy) then return true end
          if segDist2(ax, ay, px, py, qx, qy) <= r2 then return true end
        end
      end
      px, py = qx, qy
    end
    return false
  end

  Modes["Whiteboard"] = {
    id = "whiteboard",
    pretty = "Whiteboard",
    hint = HINT,

    controls = function(C, props)
      C.add({ Name = "PenWidth", ControlType = "Knob", ControlUnit = "Float", Min = MIN_WIDTH, Max = MAX_WIDTH,
              DefaultValue = DEFAULT_WIDTH, PinStyle = "Input" })
      C.add({ Name = "PenColor", ControlType = "Text", PinStyle = "Input", DefaultValue = "Accent",
              Choices = COLOR_NAMES })
      C.add({ Name = "Eraser", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input" })
      C.add({ Name = "Undo", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input" })
      C.add({ Name = "ClearBoard", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input" })
      C.add({ Name = "Snapshot", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input" })
      C.add({ Name = "Strokes", ControlType = "Indicator", IndicatorType = "Text", PinStyle = "Output" })
      C.add({ Name = "LastFile", ControlType = "Text", PinStyle = "Output" })
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "PEN")
        L.combo("PenColor", { ctx.side, ctx.sideY }, { ctx.sideW, 24 })
        ctx.sideY = ctx.sideY + 30
        L.caption("WIDTH", { ctx.side, ctx.sideY + 10 }, { 48, 10 }, "Left")
        L.knob("PenWidth", { ctx.side + 52, ctx.sideY }, { 32, 32 })
        ctx.sideY = ctx.sideY + 40
        L.sideButton(ctx, "Eraser", "ERASER")
        L.sideCaption(ctx, "BOARD")
        L.sideButton(ctx, "Undo", "UNDO")
        L.sideButton(ctx, "ClearBoard", "CLEAR BOARD")
        L.sideButton(ctx, "Snapshot", "SNAPSHOT")
        L.sideCaption(ctx, "PAD")
        L.sideButton(ctx, "Lock", "LOCK")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "W H I T E B O A R D", 118)
        L.caption("WIDTH", { ix, iy }, { 56, 10 })
        L.knob("PenWidth", { ix + 12, iy + 12 }, { 32, 32 })
        L.caption("PEN COLOUR", { ix + 72, iy }, { 120, 10 }, "Left")
        L.combo("PenColor", { ix + 72, iy + 12 }, { 120, 22 })
        L.toggle("Eraser", "ERASER", { ix + 204, iy + 12 }, { iw - 204, 24 })
        L.caption("LAST SNAPSHOT FILE", { ix, iy + 52 }, { iw, 10 }, "Left")
        L.readout("LastFile", { ix, iy + 64 }, { iw, 22 }, { fontSize = 9 })
        L.label("Snapshot writes Whiteboard/<time>.svg under design/ (Emulate) or media/ (Core).\nUndo removes the last stroke; the board keeps the newest 60 strokes.",
                { ix, iy + 90 }, { iw, 28 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local self = {
        strokes = {},            -- oldest first; the live stroke is the last entry while drawing
        live = nil,              -- the stroke under the finger
        down = false, fx = 0, fy = 0,
        eraser = false, color = T.accent, colorName = "accent", width = DEFAULT_WIDTH,
        layer = nil,             -- cached SVG of the finished strokes (nil = rebuild)
        resumable = nil,         -- { stroke, at }: a stroke ended by an inferred lift
        toast = nil, toastHandle = nil, staleHandle = nil,
        acted = {},              -- name -> time of the last trigger handled
        lastStamp = nil, stampN = 0,
      }
      local eraseR = U.clamp(floor(min(W, H) * 0.03), 8, 20)
      local radius = U.clamp(tonumber(E.props["Corner Radius"]) or 18, 0, 40)
      local background = tostring(E.props["Background"] or "Solid")

      -- ---------- control readers ----------
      local function readWidth()
        local c = E.ctl("PenWidth")
        local v = c and tonumber(c.Value) or DEFAULT_WIDTH
        v = floor(v * 2 + 0.5) / 2
        self.width = U.clamp(v, MIN_WIDTH, MAX_WIDTH)
      end
      local function readColor()
        local c = E.ctl("PenColor")
        local name = U.lower(U.trim(c and c.String or ""))
        local hex = COLOR_HEX[name]
        if hex then
          self.color, self.colorName = hex, name
        else
          self.color, self.colorName = T.accent, "accent"
        end
      end
      local function readEraser()
        local c = E.ctl("Eraser")
        self.eraser = (c ~= nil and c.Boolean) and true or false
      end

      -- ---------- board bookkeeping ----------
      local function countOut()
        E.out("Strokes", tostring(#self.strokes))
      end

      local function touched()
        self.layer = nil
        countOut()
        E.invalidate()
      end

      local function totalPoints()
        local n = 0
        for i = 1, #self.strokes do n = n + pointCount(self.strokes[i]) end
        return n
      end

      -- The board keeps at most MAX_TOTAL points: the oldest strokes are
      -- halved until it fits (each pass halves at most every stroke once).
      local function trimTotal(now)
        local total = totalPoints()
        for _ = 1, 4 do
          if total <= MAX_TOTAL then return end
          for i = 1, #self.strokes do
            local s = self.strokes[i]
            local n = pointCount(s)
            if n > 8 and s ~= self.live then
              decimate(s, now)
              total = total - n + pointCount(s)
              if total <= MAX_TOTAL then return end
            end
          end
        end
      end

      -- ---------- rendering ----------
      local function paintOf(s)
        return { stroke = s.color, sw = s.width, cap = "round", join = "round" }
      end

      -- One finished stroke as SVG elements (cached on the stroke).
      local function strokeSvg(s)
        if s.svg then return s.svg end
        local sc = Svg.new(W, H, { limit = STROKE_SVG_LIMIT })
        if s.dot then
          sc:circle(s.pts[1], s.pts[2], max(1.5, s.width * 0.8), { fill = s.color })
        else
          sc:polyline(s.pts, paintOf(s))
        end
        s.svg = concat(sc.parts)
        return s.svg
      end

      local function layerSvg()
        if self.layer then return self.layer end
        local parts = {}
        for i = 1, #self.strokes do
          local s = self.strokes[i]
          if s ~= self.live then parts[#parts + 1] = strokeSvg(s) end
        end
        self.layer = concat(parts)
        return self.layer
      end

      -- Re-renders one out-of-date stroke per frame, only on a frame later
      -- than the change, and asks for another frame while any remain.
      local function refreshOneStale()
        local now = E.now()
        local done, pending = false, false
        for i = 1, #self.strokes do
          local s = self.strokes[i]
          if s.stale and s ~= self.live then
            if not done and now > s.staleAt then
              s.svg, s.stale = nil, false
              self.layer = nil
              done = true
            else
              pending = true
            end
          end
        end
        if pending and not self.staleHandle then
          self.staleHandle = E.after(REFRESH_AFTER, function()
            self.staleHandle = nil
            E.invalidate()
          end)
        end
      end

      -- A simplified chunk of the live stroke is rendered as it is flushed,
      -- so a frame renders at most one chunk plus the raw tail.
      local function renderChunk(s, chunk)
        if not s.keptParts then return end
        local sc = Svg.new(W, H, { limit = STROKE_SVG_LIMIT })
        sc:polyline(chunk, paintOf(s))
        s.keptParts[#s.keptParts + 1] = concat(sc.parts)
      end

      -- The live stroke: the kept points as cached chunk elements (rebuilt as
      -- one element after a halving or a resume), the raw tail (at most 25
      -- points) on every frame; round caps and joins hide the seams.
      local function drawLive(c, s)
        local n = pointCount(s)
        if n >= 2 then
          if not s.keptParts then
            local sc = Svg.new(W, H, { limit = STROKE_SVG_LIMIT })
            sc:polyline(s.pts, paintOf(s))
            s.keptParts = { concat(sc.parts) }
          end
          for i = 1, #s.keptParts do c:raw(s.keptParts[i]) end
        end
        if #s.raw >= 4 then
          c:polyline(s.raw, paintOf(s))
        elseif n < 2 then
          c:circle(s.pts[1], s.pts[2], max(1.5, s.width * 0.8), { fill = s.color })
        end
      end

      -- ---------- toast ----------
      local function showToast(text, kind)
        if self.toastHandle then self.toastHandle:cancel() end
        self.toast = { text = text, kind = kind }
        self.toastHandle = E.after(TOAST, function()
          self.toast, self.toastHandle = nil, nil
          E.invalidate()
        end)
        E.invalidate()
      end

      -- ---------- actions ----------
      local function beginStroke(x, y)
        if #self.strokes >= MAX_STROKES then
          table.remove(self.strokes, 1)
          self.layer = nil
        end
        local s = newStroke(x, y, self.color, self.width)
        s.keptParts = {}
        self.strokes[#self.strokes + 1] = s
        self.live = s
        countOut()
      end

      -- Ends the live stroke. Its chunk elements become its cached rendering
      -- (a dot is drawn afresh, it is one element), consolidated into one
      -- polyline on a later frame.
      local function endStroke(now)
        local s = self.live
        if not s then return end
        self.live = nil
        finishStroke(s, renderChunk, now)
        if s.dot then
          s.svg = nil
        elseif s.keptParts and #s.keptParts > 0 then
          s.svg = concat(s.keptParts)
          s.stale, s.staleAt = true, now
        else
          s.svg = nil
        end
        s.keptParts = nil
        trimTotal(now)
        self.layer = nil
      end

      local function erase(ax, ay, bx, by)
        local removed = 0
        for i = #self.strokes, 1, -1 do
          local s = self.strokes[i]
          if s ~= self.live and strokeHit(s, ax, ay, bx, by, eraseR) then
            table.remove(self.strokes, i)
            removed = removed + 1
          end
        end
        if removed > 0 then
          E.setGesture(removed == 1 and "ERASED 1 STROKE" or ("ERASED " .. removed .. " STROKES"))
          touched()
        end
        return removed
      end

      local function undo()
        local n = #self.strokes
        if n == 0 then
          E.setGesture("NOTHING TO UNDO")
          return
        end
        local s = self.strokes[n]
        self.strokes[n] = nil
        if s == self.live then self.live = nil end
        self.resumable = nil
        E.setGesture("UNDO")
        touched()
      end

      local function clearBoard()
        local had = #self.strokes
        self.strokes = {}
        self.live, self.resumable = nil, nil
        E.setGesture(had > 0 and "BOARD CLEARED" or "BOARD EMPTY")
        touched()
      end

      -- The board as a standalone SVG file (pad background and strokes).
      local function boardSvg()
        local c = Svg.new(W, H, { family = tostring(E.props["Font"] or "Roboto") })
        Shapes.padFrame(c, T, W, H, radius, background)
        local layer = layerSvg()
        if layer ~= "" then c:raw(layer) end
        if self.live then drawLive(c, self.live) end
        return c:finish()
      end

      local function timeStamp()
        local ok, s = pcall(function()
          if type(Q) == "table" and type(Q.date) == "function" then return Q.date("%Y%m%d_%H%M%S") end
          return os.date("%Y%m%d_%H%M%S")
        end)
        if ok and type(s) == "string" and s ~= "" then return s end
        return tostring(floor(E.now()))
      end

      local function snapshot()
        local folder = E.file.base() .. "/Whiteboard"
        E.file.mkdir(folder)
        local stamp = timeStamp()
        if stamp == self.lastStamp then
          self.stampN = self.stampN + 1
        else
          self.lastStamp, self.stampN = stamp, 0
        end
        local name = stamp .. ((self.stampN > 0) and ("_" .. self.stampN) or "") .. ".svg"
        local path = folder .. "/" .. name
        local ok, err = E.file.write(path, boardSvg())
        if ok then
          E.out("LastFile", path)
          E.setGesture("SNAPSHOT SAVED")
          E.dbg("whiteboard snapshot " .. path)
          showToast("Saved " .. name, "ok")
        else
          E.status("Snapshot not saved: " .. tostring(err or "write failed"), "warn")
          E.setGesture("SNAPSHOT FAILED")
          showToast("Not saved", "bad")
        end
      end

      -- A Trigger's handler may run with Boolean already false (ctl:Trigger
      -- or a UCI button); the trailing edge of a pulse just handled is skipped.
      local function triggered(name, ctl)
        local now = E.now()
        local last = self.acted[name] or -100
        if ctl.Boolean or now - last >= TRIGGER_GUARD then
          self.acted[name] = now
          return true
        end
        return false
      end

      -- ---------- engine hooks ----------
      function self:onStart()
        readWidth()
        readColor()
        readEraser()
        countOut()
        E.invalidate()
      end

      function self:onTouchStart(x, y, t)
        self.down, self.fx, self.fy = true, x, y
        self.resumable = nil
        if self.eraser then
          erase(x, y, x, y)
        else
          beginStroke(x, y)
        end
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        local px, py = self.fx, self.fy
        self.fx, self.fy = x, y
        if self.eraser then
          erase(px, py, x, y)
        elseif self.live then
          addPoint(self.live, x, y, renderChunk, t)
        end
        E.invalidate()
      end

      function self:onTouchEnd(x, y, t, info)
        self.down = false
        if self.live then
          addPoint(self.live, x, y, renderChunk, t)
          local s = self.live
          endStroke(t)
          if info and info.inferred and not info.aborted and not s.dot then
            self.resumable = { stroke = s, at = t }
          end
          E.dbg(string.format("whiteboard stroke %d: %d points%s", #self.strokes, pointCount(s), s.dot and " (dot)" or ""))
        end
        E.invalidate()
      end

      -- An inferred lift taken back: the stroke it ended continues.
      function self:onTouchResume(x, y, t)
        self.down, self.fx, self.fy = true, x, y
        local r = self.resumable
        self.resumable = nil
        if self.eraser then
          erase(x, y, x, y)
        elseif r and t - r.at <= RESUME_WINDOW and self.strokes[#self.strokes] == r.stroke then
          local s = r.stroke
          s.dot, s.svg, s.stale, s.keptParts = false, nil, false, nil
          self.live = s
          self.layer = nil
          addPoint(s, x, y, renderChunk, t)
        else
          beginStroke(x, y)
        end
        E.invalidate()
      end

      function self:onLock(locked)
        self.down = false
        if locked then
          endStroke(E.now())
          self.resumable = nil
        end
        E.invalidate()
      end

      function self:onControl(name, index, ctl)
        if name == "PenWidth" then
          readWidth()
        elseif name == "PenColor" then
          readColor()
        elseif name == "Eraser" then
          readEraser()
          E.setGesture(self.eraser and "ERASER ON" or "PEN")
        elseif name == "Undo" then
          if triggered(name, ctl) then undo() end
        elseif name == "ClearBoard" then
          if triggered(name, ctl) then clearBoard() end
        elseif name == "Snapshot" then
          if triggered(name, ctl) then snapshot() end
        end
        E.invalidate()
      end

      -- ---------- drawing ----------
      local function drawBadge(c)
        local bx, by = W - 16, H - 16
        if self.eraser then
          Shapes.icon(c, "eraser", bx, by, 16, T.accent2)
          c:text(bx - 12, by + 4, "ERASER", { size = 10, fill = T.accent2, anchor = "end", weight = "bold" })
        else
          Shapes.icon(c, "pen", bx, by, 16, T.muted)
          c:circle(bx - 18, by, 5, { fill = self.color, stroke = T.line, sw = 1 })
        end
      end

      local function drawToast(c)
        local tst = self.toast
        if not tst then return end
        local colour = (tst.kind == "ok") and T.ok or T.danger
        local tw = min(W - 24, Font.width(tst.text, 13, "bold") + 24)
        c:rect(W / 2 - tw / 2, 10, tw, 24, { fill = T.panel, stroke = colour, sw = 1, rx = 6 })
        c:textFit(W / 2, 27, tw - 12, tst.text, { size = 13, fill = colour, anchor = "middle", weight = "bold" })
      end

      function self:draw(c)
        refreshOneStale()
        local layer = layerSvg()
        if layer ~= "" then c:raw(layer) end
        if self.live then drawLive(c, self.live) end
        if self.eraser and self.down then
          c:circle(self.fx, self.fy, eraseR, { fill = "none", stroke = T.accent2, sw = 1.5, dash = "3 3" })
        end
        drawBadge(c)
        drawToast(c)
        if E.hint and not self.down and (#self.strokes == 0 or self.eraser) then
          Shapes.hint(c, T, self.eraser and ERASE_HINT or HINT, W, H)
        end
      end

      return self
    end,
  }
end
