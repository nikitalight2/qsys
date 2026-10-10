-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Swipe Layer mode
--
-- A pad that shows almost nothing: a finger trail that fades behind the
-- touch and a brief chevron in the direction of a recognised swipe. The
-- swipe pulses (SwipeLeft / SwipeRight / SwipeUp / SwipeDown) are the common
-- outputs; this mode adds the Setup knob `SwipeDistance` (fraction of the pad
-- diagonal a swipe must cover, 0.05..0.8, default 0.2) and recognises the
-- swipes the engine's fixed 0.2 threshold leaves out when the knob sits
-- below it. A swipe needs distance and speed: 0.6 s at most from the start
-- of its stroke to the lift.
--
-- Quick swipes in a row each count. With Panel Touch wired every lift is
-- certain, so the engine already separates them. Without Panel Touch a
-- finger that lands again within the release time looks like one long
-- touch whose position jumped: the mode splits the touch into strokes at
-- such a jump, classifies the stroke that just ended and pulses its swipe at
-- once, so the second swipe is not lost.
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
  local JUMP_FRACTION = 0.3                   -- a single report moving this much of the diagonal is a new stroke
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
      local JUMP = max(JUMP_FRACTION * DIAG, 120)
      local width = min(10, max(4, DIAG * 0.012))       -- trail stroke width
      local chevronSize = min(W, H) * 0.36
      local self = {
        fraction = DIST_DEFAULT,
        down = false,
        x = 0, y = 0,
        trail = {}, first = 1,                           -- points { x, y, t }; first = index of the oldest
        stroke = nil,                                    -- { x0, y0, t0, x, y, t, fresh }
        chevron = nil,                                   -- { dir, t }
        animating = false,
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

      -- A swipe the engine did not see: pulse the pin and name the gesture.
      local function ownSwipe(dir)
        self.swipes = self.swipes + 1
        E.pulse(DIRS[dir][3])
        E.setGesture("SWIPE " .. dir)
        E.dbg("swipe layer: " .. dir .. " (mode threshold)")
        showChevron(dir)
      end

      local function addPoint(x, y, t)
        local trail = self.trail
        trail[#trail + 1] = { x, y, t }
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

      local function newStroke(x, y, t, fresh)
        self.stroke = { x0 = x, y0 = y, t0 = t, x = x, y = y, t = t, fresh = fresh }
      end

      -- ---------- touch events ----------
      function self:onStart()
        readFraction()
      end

      function self:onTouchStart(x, y, t)
        self.down, self.x, self.y = true, x, y
        addPoint(x, y, t)
        newStroke(x, y, t, false)
        animate(true)
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        local s = self.stroke
        if s and sqrt(dx * dx + dy * dy) >= JUMP then
          -- The finger landed somewhere else within the release time: the
          -- stroke that just ended is classified now, the new one starts here.
          local dir = classify(s.x0, s.y0, s.t0, s.x, s.y, s.t)
          if dir then ownSwipe(dir) end
          self.trail, self.first = {}, 1
          newStroke(x, y, t, true)
        elseif s then
          s.x, s.y, s.t = x, y, t
        else
          newStroke(x, y, t, false)
        end
        self.x, self.y = x, y
        addPoint(x, y, t)
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
        local dir = info.swipe
        if dir then
          showChevron(dir)
        elseif s and not info.tap and (not info.resumed or s.fresh) then
          -- Below the engine's fixed threshold but above SwipeDistance, or a
          -- stroke that started after a jump: the mode classifies it.
          dir = classify(s.x0, s.y0, s.t0, x, y, t)
          if dir then ownSwipe(dir) end
        end
        E.invalidate()
      end

      function self:onTouchResume(x, y, t)
        self.down, self.x, self.y = true, x, y
        -- The drag goes on but its swipe was classified at the inferred lift.
        newStroke(x, y, t, false)
        addPoint(x, y, t)
        animate(true)
        E.invalidate()
      end

      function self:onControl(name, index, ctl)
        if name == "SwipeDistance" then
          readFraction()
          return
        end
        local dir = PIN_DIR[name]
        if dir and ctl and ctl.Boolean then
          -- A script pulsing a swipe pin: show the chevron, pulse nothing.
          showChevron(dir)
        end
      end

      function self:onLock(locked)
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
