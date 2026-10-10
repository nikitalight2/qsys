-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Swipe Layer mode
--
-- A pad that shows almost nothing: a finger trail that fades behind the
-- touch and a brief chevron in the direction of a recognised swipe. The
-- swipe pulses (SwipeLeft / SwipeRight / SwipeUp / SwipeDown) are the common
-- outputs; this mode adds the Setup knob `SwipeDistance` (fraction of the pad
-- diagonal a swipe must cover, 0.05..0.8, default 0.2). A swipe needs
-- distance and speed: 0.6 s at most from the start of its stroke to the lift.
--
-- The engine classifies a whole touch from its first point with a fixed 0.2
-- threshold. The mode works in strokes instead and keeps the engine's view of
-- the touch in step with the current stroke through the engine's live touch
-- record (TouchPad.state.touch, the white-box handle the engine publishes for
-- later modules): the record's origin follows the stroke, and a stroke the
-- knob calls too short is hidden from the engine's threshold. So the knob
-- owns the swipe distance in both directions, the mode pulses the swipes the
-- engine does not see, and the two never pulse the same swipe twice. Without
-- the handle the mode still pulses what the engine misses.
--
-- Quick swipes in a row each count. With Panel Touch wired every lift is
-- certain, so the engine already separates them. Without Panel Touch a
-- finger that lands again within the release time looks like one long touch
-- to the engine: the mode starts a new stroke when a report arrives after a
-- gap of more than three 30 Hz reports (a resting finger sends nothing, a
-- moving one reports every 33 ms) or when a single report jumps across the
-- pad, classifies the stroke that just ended and pulses its swipe at once.
-- A stroke that continues after a taken-back lift (resume) is classified by
-- the mode as well, since the engine never classifies a resumed touch.
--
-- Design time (controls, pages, layout) and the runtime `create(E)` live here.

Modes = Modes or {}

do
  local HINT = "Swipe in any direction"
  local SWIPE_TIME, SWIPE_RATIO = 0.6, 1.5    -- spec 5.4
  local DIST_MIN, DIST_MAX, DIST_DEFAULT = 0.05, 0.8, 0.2
  local TRAIL_LIFE = 0.7                      -- s a trail point stays visible
  local TRAIL_MAX = 40                        -- points kept (older ones are dropped)
  local TRAIL_STEPS = 8                       -- opacity buckets (polylines per frame at most)
  local CHEVRON_LIFE = 0.55                   -- s the chevron stays visible
  local ENGINE_FRACTION = 0.2                 -- the engine's own fixed swipe distance (fraction of the diagonal)
  local JUMP_FRACTION = 0.3                   -- a single report moving this much of the diagonal is a new stroke
  local LAND_GAP = 0.11                       -- s without a report before a move: more than three missed 30 Hz reports
  local LAND_WAIT = 0.12                      -- s after such a report in which the finger shows whether it landed
  local LAND_MOVE = 12                        -- px (TAP_MOVE) it must move from the point before the gap to have landed
  local DIRS = {
    left = { -1, 0, "SwipeLeft" }, right = { 1, 0, "SwipeRight" },
    up = { 0, -1, "SwipeUp" }, down = { 0, 1, "SwipeDown" },
  }
  local PIN_DIR = { SwipeLeft = "left", SwipeRight = "right", SwipeUp = "up", SwipeDown = "down" }

  Modes["Swipe Layer"] = {
    id = "swipe",
    pretty = "Swipe Layer",
    hint = HINT,

    controls = function(C, props)
      C.add({ Name = "SwipeDistance", ControlType = "Knob", ControlUnit = "Float",
              Min = DIST_MIN, Max = DIST_MAX, DefaultValue = DIST_DEFAULT,
              PinStyle = "Input", Group = "Setup" })
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "S W I P E", 56)
        L.caption("DISTANCE", { ix - 4, iy }, { 64, 10 })
        L.knob("SwipeDistance", { ix + 12, iy + 12 }, { 32, 32 }, { color = Nikita.Orange })
        L.label("Swipe distance: the fraction of the pad diagonal a quick stroke\n(0.6 s or less) must cover to count as a swipe. Default 0.2.",
                { ix + 72, iy + 4 }, { iw - 72, 40 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local sqrt, abs, floor, min, max = math.sqrt, math.abs, math.floor, math.min, math.max
      local DIAG = sqrt(W * W + H * H)
      local JUMP = JUMP_FRACTION * DIAG
      local width = min(10, max(4, DIAG * 0.012))       -- trail stroke width
      local chevronSize = min(W, H) * 0.36
      local self = {
        fraction = DIST_DEFAULT,
        down = false,
        x = 0, y = 0,
        trail = {}, first = 1,                           -- points { x, y, t[, break] }; first = index of the oldest
        stroke = nil,                                    -- { x0, y0, t0, x, y, t, own, gap }; own: the engine's view follows it
        chevron = nil,                                   -- { dir, t }
        animating = false,
        locked = false,
        swipes = 0,                                      -- swipes the mode pulsed itself (tests)
      }

      -- ---------- helpers ----------
      local function readFraction()
        local ctl = E.ctl("SwipeDistance")
        local v = ctl and tonumber(ctl.Value) or nil
        if v == nil then v = DIST_DEFAULT end
        if v < DIST_MIN then v = DIST_MIN end
        if v > DIST_MAX then v = DIST_MAX end
        self.fraction = v
        return v
      end

      -- Direction of a stroke from (x0, y0, t0) to (x, y, t), or nil.
      local function classify(x0, y0, t0, x, y, t)
        local dx, dy = x - x0, y - y0
        local dist = sqrt(dx * dx + dy * dy)
        if t - t0 > SWIPE_TIME or dist < self.fraction * DIAG then return nil end
        local ax, ay = abs(dx), abs(dy)
        if ax >= SWIPE_RATIO * ay then return (dx > 0) and "right" or "left" end
        if ay >= SWIPE_RATIO * ax then return (dy > 0) and "down" or "up" end
        return nil
      end

      local function animate(on)
        if on ~= self.animating then
          self.animating = on
          E.animate(on)
        end
      end

      -- The chevron is timed from now, not from the handler's t: an inferred
      -- lift carries the time of the last report, already ReleaseTime ago.
      local function showChevron(dir)
        if not DIRS[dir] then return end
        self.chevron = { dir = dir, t = E.now() }
        animate(true)
        E.invalidate()
      end

      -- A swipe the engine does not pulse: pulse the pin and name the gesture.
      local function ownSwipe(dir)
        self.swipes = self.swipes + 1
        E.pulse(DIRS[dir][3])
        E.setGesture("SWIPE " .. dir)
        E.dbg("swipe layer: " .. dir .. " (mode threshold)")
        showChevron(dir)
      end

      -- brk: no trail segment joins this point to the one before it.
      local function addPoint(x, y, t, brk)
        local trail = self.trail
        trail[#trail + 1] = { x, y, t, brk }
        if #trail - self.first + 1 > TRAIL_MAX then self.first = self.first + 1 end
        if self.first > 64 then
          -- compact the array now and then so it never grows without bound
          local fresh, n = {}, 0
          for i = self.first, #trail do n = n + 1; fresh[n] = trail[i] end
          self.trail, self.first = fresh, 1
        end
      end

      -- Drops points older than TRAIL_LIFE; returns true when some remain.
      local function prune(now)
        local trail = self.trail
        local i, n = self.first, #trail
        while i <= n and now - trail[i][3] > TRAIL_LIFE do i = i + 1 end
        if i > n then
          self.trail, self.first = {}, 1
          return false
        end
        self.first = i
        return true
      end

      local function newStroke(x, y, t, own)
        self.stroke = { x0 = x, y0 = y, t0 = t, x = x, y = y, t = t, own = own }
        return self.stroke
      end

      -- The engine's live touch record, when it is published (see the header).
      local function engineTouch()
        local tp = TouchPad
        local st = type(tp) == "table" and tp.state or nil
        local touch = type(st) == "table" and st.touch or nil
        if type(touch) == "table" and type(touch.t0) == "number" and type(touch.x0) == "number" then
          return touch
        end
        return nil
      end

      -- Keeps the engine's view of the touch equal to the stroke: its origin
      -- is the stroke's, and while the knob asks for more than the engine's
      -- fixed threshold a stroke that is long enough for the engine but not
      -- for the knob is made too slow for the engine. Only for strokes the
      -- engine would classify (the first one and those started at a split):
      -- a resumed touch is never classified by the engine.
      local function syncEngine(s)
        if not s.own then return end
        local touch = engineTouch()
        if not touch then return end
        touch.x0, touch.y0 = s.x0, s.y0
        local dx, dy = s.x - s.x0, s.y - s.y0
        local d = sqrt(dx * dx + dy * dy)
        if self.fraction > ENGINE_FRACTION and d >= ENGINE_FRACTION * DIAG and d < self.fraction * DIAG then
          touch.t0 = s.t0 - SWIPE_TIME - 1
        else
          touch.t0 = s.t0
        end
      end

      -- ---------- touch events ----------
      function self:onStart()
        readFraction()
      end

      function self:onTouchStart(x, y, t)
        self.down, self.x, self.y = true, x, y
        addPoint(x, y, t)
        newStroke(x, y, t, true)
        animate(true)
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        local s = self.stroke
        if not s then s = newStroke(x, y, t, false) end
        local jump = sqrt(dx * dx + dy * dy)
        local landing = t - s.t >= LAND_GAP
        local gap = s.gap
        if landing then
          -- A report after silence: the finger may have landed again. The
          -- stroke's last point is kept; the landing is decided over the next
          -- LAND_WAIT from how far the finger moves away from that point.
          gap = { x = s.x, y = s.y, t = s.t, lx = x, ly = y, lt = t }
          s.gap = gap
        elseif gap and t - gap.lt > LAND_WAIT then
          gap, s.gap = nil, nil
        end
        local split = jump >= JUMP
        if not split and gap then
          local gx, gy = x - gap.x, y - gap.y
          split = sqrt(gx * gx + gy * gy) >= LAND_MOVE
        end
        if split then
          -- The finger landed again within the release time: the stroke that
          -- ended before the gap is classified now, the new one starts at the
          -- landing.
          local ox, oy, ot, ex, ey, et = x, y, t, s.x, s.y, s.t
          if gap and jump < JUMP then ox, oy, ot, ex, ey, et = gap.lx, gap.ly, gap.lt, gap.x, gap.y, gap.t end
          local dir = classify(s.x0, s.y0, s.t0, ex, ey, et)
          if dir then ownSwipe(dir) end
          if jump >= JUMP then self.trail, self.first = {}, 1 end
          s = newStroke(ox, oy, ot, true)
        end
        s.x, s.y, s.t = x, y, t
        addPoint(x, y, t, landing or jump >= JUMP)      -- a new trail line starts after a gap or a jump
        syncEngine(s)
        self.x, self.y = x, y
        E.invalidate()
      end

      function self:onTouchEnd(x, y, t, info)
        self.down, self.x, self.y = false, x, y
        local s = self.stroke
        self.stroke = nil
        if info.aborted then
          self.trail, self.first = {}, 1
          E.invalidate()
          return
        end
        if s and (x ~= s.x or y ~= s.y) then addPoint(x, y, t) end
        local dir = nil
        if s and not info.tap then dir = classify(s.x0, s.y0, s.t0, x, y, t) end
        if dir and dir ~= info.swipe then
          -- Below the engine's threshold, a stroke started at a split, or a
          -- resumed stroke: the mode pulses it.
          ownSwipe(dir)
        elseif info.swipe then
          -- The engine pulsed it (and the mode agrees, or cannot veto it).
          showChevron(info.swipe)
        end
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        self.down, self.x, self.y = true, x, y
        -- The drag goes on; the engine classified its swipe at the inferred
        -- lift and never classifies a resumed touch, so the continued stroke
        -- is the mode's to classify at the lift.
        newStroke(x, y, t, false)
        addPoint(x, y, t)
        animate(true)
        E.invalidate()
      end

      function self:onControl(name, index, ctl)
        if name == "SwipeDistance" then
          readFraction()
          if self.stroke then syncEngine(self.stroke) end
          return
        end
        if self.locked then return end                   -- a locked pad reacts to nothing (spec 5.6)
        local dir = PIN_DIR[name]
        if dir and ctl and ctl.Boolean then
          -- A script pulsing a swipe pin: show the chevron, pulse nothing.
          showChevron(dir)
        end
      end

      function self:onLock(locked)
        self.locked = locked and true or false
        self.down, self.stroke, self.chevron = false, nil, nil
        self.trail, self.first = {}, 1
        animate(false)
        E.invalidate()
      end

      function self:tick(dt)
        local now = E.now()
        local alive = prune(now) or self.down
        if self.chevron and now - self.chevron.t > CHEVRON_LIFE then self.chevron = nil end
        if self.chevron then alive = true end
        if not alive then animate(false) end
        E.invalidate()
      end

      -- ---------- drawing ----------
      local function drawTrail(c, now)
        local trail, first, n = self.trail, self.first, #self.trail
        if n - first < 1 then return end
        local pts, count, bucket = {}, 0, nil
        local function flush()
          if count >= 4 and bucket then
            local a = bucket / TRAIL_STEPS
            c:polyline(pts, { stroke = T.accent, sw = width * (0.35 + 0.65 * a), opacity = 0.15 + 0.85 * a,
                              cap = "round", join = "round" })
          end
          pts, count = {}, 0
        end
        for i = first + 1, n do
          local p = trail[i]
          if p[4] then
            -- a new stroke: nothing joins it to the one before
            flush()
            bucket = nil
          else
            local age = now - p[3]
            local a = 1 - age / TRAIL_LIFE
            if a < 0 then a = 0 end
            local b = floor(a * TRAIL_STEPS + 0.999)
            if b < 1 then b = 1 end
            if b ~= bucket then
              flush()
              bucket = b
              local q = trail[i - 1]
              pts[1], pts[2], count = q[1], q[2], 2
            end
            pts[count + 1], pts[count + 2] = p[1], p[2]
            count = count + 2
          end
        end
        flush()
      end

      local function drawChevron(c, now)
        local ch = self.chevron
        if not ch then return end
        local a = 1 - (now - ch.t) / CHEVRON_LIFE
        if a <= 0 then return end
        local d = DIRS[ch.dir]
        local fx, fy = d[1], d[2]
        local px, py = -fy, fx
        local s = chevronSize
        local slide = s * 0.3 * (1 - a)
        local cx, cy = W / 2 + fx * slide, H / 2 + fy * slide
        local sw = width * 1.6
        local function chevron(ox, oy, opacity)
          local bx, by = cx + fx * ox, cy + fy * oy
          local tipx, tipy = bx + fx * s * 0.22, by + fy * s * 0.22
          local tx, ty = bx - fx * s * 0.22, by - fy * s * 0.22
          c:polyline({ tx + px * s * 0.5, ty + py * s * 0.5, tipx, tipy, tx - px * s * 0.5, ty - py * s * 0.5 },
                     { stroke = T.accent2, sw = sw, opacity = opacity, cap = "round", join = "round" })
        end
        chevron(-s * 0.3, -s * 0.3, a * 0.35)
        chevron(0, 0, a)
      end

      function self:draw(c)
        local now = E.now()
        local hasTrail = prune(now)
        if hasTrail then drawTrail(c, now) end
        if self.down then
          c:circle(self.x, self.y, width * 2.2, { fill = T.accent, opacity = 0.25 })
          c:circle(self.x, self.y, width * 0.9, { fill = T.accent })
        end
        drawChevron(c, now)
        if E.hint and not self.down and not hasTrail and not self.chevron then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      return self
    end,
  }
end
