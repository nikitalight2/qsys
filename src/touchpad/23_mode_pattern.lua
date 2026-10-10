-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Pattern Lock mode
--
-- A dot grid (3x3 by default, up to 5x5 through the GridSize control). The
-- finger joins dots; a lift checks the drawn pattern against the secret in
-- `Pattern` ("1-5-9-6" or "1596", dots numbered left to right, top to
-- bottom). Unlocked / Failed pulse the result, LastPattern carries the drawn
-- pattern, Learn stores the next drawn pattern as the secret, Locked goes on
-- after MaxTries failures for LockoutSeconds (and can be driven both ways
-- from its pin). Masked hides the trail (a row of small dots above the grid
-- counts the joined dots instead); AutoSubmit checks as soon as the drawn
-- pattern is as long as the secret (never while learning: the lift decides
-- the length of a new secret). A pattern has at least two dots: a drawing of
-- one dot (a tap on a dot) is dropped without a check, does not count as a
-- try and is not learned, and a Pattern text with fewer than two dots is no
-- secret. The grid keeps room for the top line (feedback / tries / masked
-- dots) and the hint; on a pad too small for them the texts are left out
-- rather than drawn over the dots.
--
-- Design time (controls, pages, layout) and the runtime `create(E)` live here.

Modes = Modes or {}

do
  local HINT = "Draw your pattern"
  local HINT_EMPTY = "Set a pattern first"
  local FEEDBACK_TIME = 0.8     -- green or red feedback after a check
  local HIT = 0.22              -- hit radius as a fraction of the dot spacing
  local RESUME_WAIT = 1.6       -- the engine can take an inferred lift back for 1.5 s
  local MAX_DOTS = 25           -- 5 x 5
  local MIN_DOTS = 2            -- a pattern (drawn or secret) has at least two dots
  local DRAG_START = 12         -- px: the engine pauses (and can resume) only a touch that moved this far
  local MIN_SPACING = 36        -- px between dots: below this the texts make room, not the grid
  local MASK_R = 4              -- radius of the masking dots
  local MAX_PATTERN_CHARS = 200 -- only this much of the Pattern text is parsed
  local GRID_MIN, GRID_MAX, GRID_DEFAULT = 3, 5, 3
  local TRIES_MIN, TRIES_MAX, TRIES_DEFAULT = 1, 10, 5
  local LOCK_MIN, LOCK_MAX, LOCK_DEFAULT = 10, 3600, 60

  local floor, ceil, min, max, abs, sqrt = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt

  -- "1-5-9-6", "1 5 9 6", "1,5,9,6" or "1596" -> { 1, 5, 9, 6 }; dots above
  -- maxDot and repeats are dropped; the dash form is the only unambiguous
  -- one for grids larger than 3 x 3.
  local function parsePattern(s, maxDot)
    s = tostring(s or "")
    if #s > MAX_PATTERN_CHARS then s = s:sub(1, MAX_PATTERN_CHARS) end
    local out, seen = {}, {}
    local function push(n)
      if n and n >= 1 and n <= maxDot and not seen[n] and #out < MAX_DOTS then
        seen[n] = true
        out[#out + 1] = n
      end
    end
    if s:find("[^%d]") then
      for tok in s:gmatch("%d+") do
        if #tok <= 3 then push(tonumber(tok)) end
      end
    else
      for i = 1, #s do push(tonumber(s:sub(i, i))) end
    end
    return out
  end

  local function patternString(path)
    local parts = {}
    for i = 1, #path do parts[i] = tostring(path[i]) end
    return table.concat(parts, "-")
  end

  local function samePath(a, b)
    if #a ~= #b or #a == 0 then return false end
    for i = 1, #a do
      if a[i] ~= b[i] then return false end
    end
    return true
  end

  local function gcd(a, b)
    a, b = abs(a), abs(b)
    for _ = 1, 8 do
      if b == 0 then return a end
      a, b = b, a % b
    end
    return a
  end

  local function clampInt(v, lo, hi, default)
    v = tonumber(v)
    if v == nil or v ~= v then return default end
    v = floor(v + 0.5)
    if v < lo then v = lo end
    if v > hi then v = hi end
    return v
  end

  Modes["Pattern Lock"] = {
    id = "pattern",
    pretty = "Pattern Lock",
    hint = HINT,

    controls = function(C, props)
      C.add{ Name = "GridSize", ControlType = "Knob", ControlUnit = "Integer", Min = GRID_MIN, Max = GRID_MAX,
             DefaultValue = GRID_DEFAULT, PinStyle = "Input" }
      C.add{ Name = "Pattern", ControlType = "Text", PinStyle = "Input" }
      C.add{ Name = "Unlocked", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output" }
      C.add{ Name = "Failed", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output" }
      C.add{ Name = "Locked", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" }
      C.add{ Name = "MaxTries", ControlType = "Knob", ControlUnit = "Integer", Min = TRIES_MIN, Max = TRIES_MAX,
             DefaultValue = TRIES_DEFAULT, PinStyle = "Input" }
      C.add{ Name = "LockoutSeconds", ControlType = "Knob", ControlUnit = "Integer", Min = LOCK_MIN, Max = LOCK_MAX,
             DefaultValue = LOCK_DEFAULT, PinStyle = "Input" }
      C.add{ Name = "LastPattern", ControlType = "Indicator", IndicatorType = "Text", PinStyle = "Output" }
      C.add{ Name = "Learn", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input" }
      C.add{ Name = "Masked", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input" }
      C.add{ Name = "AutoSubmit", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input" }
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "PATTERN")
        L.sideButton(ctx, "Learn", "LEARN")
        L.sideButton(ctx, "Locked", "LOCKED")
        L.sideButton(ctx, "Masked", "MASKED")
        L.sideButton(ctx, "AutoSubmit", "AUTO SUBMIT")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "P A T T E R N  L O C K", 160)
        L.caption("PATTERN: DOTS LEFT TO RIGHT, TOP TO BOTTOM (1-5-9-6 OR 1596)", { ix, iy }, { iw, 10 }, "Left")
        L.text("Pattern", { ix, iy + 12 }, { iw - 92, 22 })
        L.toggle("Learn", "LEARN", { ix + iw - 84, iy + 12 }, { 84, 22 })
        local cellW = floor((iw - 2 * L.G) / 3)
        L.grid({ "GridSize", "MaxTries", "LockoutSeconds" }, ix, iy + 42, 3, cellW, 48)
        L.caption("LAST PATTERN", { ix, iy + 98 }, { iw, 10 }, "Left")
        L.readout("LastPattern", { ix, iy + 110 }, { iw - 184, 22 })
        L.toggle("Masked", "MASKED", { ix + iw - 176, iy + 110 }, { 84, 22 })
        L.toggle("AutoSubmit", "AUTO SUBMIT", { ix + iw - 84, iy + 110 }, { 84, 22 })
        L.label("Learn: the next drawn pattern becomes the secret. Masked hides the trail.", { ix, iy + 138 }, { iw, 14 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local side = min(W, H)
      local textSize = max(10, min(15, floor(side * 0.035)))

      local self = {
        n = GRID_DEFAULT,
        dots = {},            -- dots[k] = { x, y, row, col }
        spacing = 1, r = 8,
        secret = {},
        path = {}, seen = {}, -- the pattern being drawn
        active = false,       -- a finger is drawing
        submitted = false,    -- AutoSubmit checked this touch already
        fx = nil, fy = nil,   -- finger position for the rubber-band segment
        x0 = 0, y0 = 0, moved = 0, -- touch origin and the farthest the finger got from it
        pending = nil,        -- delayed check after an inferred lift
        pendingLearn = false, -- the Learn flag at the time of that lift
        topY = 0, maskY = 0,  -- baselines of the top line and the masking dots
        showTop = true, showMask = true, showHint = true, -- room for them above / below the grid
        feedback = nil,       -- { kind = "ok"|"fail", text = ... }
        fbTimer = nil,
        tries = 0,
        lockedUntil = nil, lockTimer = nil, shownRemaining = nil,
        learn = false, masked = false, auto = false,
      }

      local function ctlBool(name)
        local c = E.ctl(name)
        return c ~= nil and c.Boolean == true
      end
      local function ctlString(name)
        local c = E.ctl(name)
        return c and tostring(c.String or "") or ""
      end
      local function ctlInt(name, lo, hi, default)
        local c = E.ctl(name)
        return clampInt(c and c.Value, lo, hi, default)
      end

      -- The grid is centred; it takes 72 % of the shorter side unless the top
      -- line, the masking dots and the hint need the room, and it never
      -- shrinks below MIN_SPACING: on a pad too small for everything the
      -- texts that would overlap the dots are left out instead (see draw).
      local function buildGrid(n)
        self.n = n
        local topY = textSize + 14
        local maskY = topY + 12
        self.topY, self.maskY = topY, maskY
        local reserveTop = maskY + MASK_R + 4
        local reserveBottom = E.hint and 24 or 8
        local span = side * 0.72
        local r = 18
        for _ = 1, 3 do
          local fit = H - 2 * max(reserveTop, reserveBottom) - 2 * r
          span = min(side * 0.72, max(fit, MIN_SPACING * (n - 1)))
          r = max(5, min(18, span / (n - 1) * 0.11))
        end
        local spacing = span / (n - 1)
        local ox, oy = (W - span) / 2, (H - span) / 2
        local dots = {}
        for row = 0, n - 1 do
          for col = 0, n - 1 do
            dots[row * n + col + 1] = { x = ox + col * spacing, y = oy + row * spacing, row = row, col = col }
          end
        end
        self.dots, self.spacing, self.r = dots, spacing, r
        self.showTop = oy - r >= topY + 4
        self.showMask = oy - r >= maskY + MASK_R + 2
        self.showHint = oy + span + r <= H - 22
      end

      local function clearPath()
        self.path, self.seen = {}, {}
        self.active, self.submitted = false, false
        self.fx, self.fy = nil, nil
      end

      local function cancelPending()
        if self.pending then
          self.pending:cancel()
          self.pending = nil
        end
      end

      local function cancelFeedback()
        if self.fbTimer then
          self.fbTimer:cancel()
          self.fbTimer = nil
        end
        self.feedback = nil
      end

      local function setFeedback(kind, text)
        cancelFeedback()
        self.feedback = { kind = kind, text = text }
        self.fbTimer = E.after(FEEDBACK_TIME, function()
          self.fbTimer, self.feedback = nil, nil
          if not self.active then clearPath() end
          E.invalidate()
        end)
      end

      local function isLocked()
        return self.lockedUntil ~= nil
      end

      local function remaining()
        if not self.lockedUntil then return 0 end
        return max(0, ceil(self.lockedUntil - E.now()))
      end

      local function unlock(fromPin)
        if self.lockTimer then
          self.lockTimer:cancel()
          self.lockTimer = nil
        end
        local was = self.lockedUntil ~= nil
        self.lockedUntil, self.shownRemaining = nil, nil
        self.tries = 0
        if not fromPin then E.out("Locked", false) end
        E.animate(false)
        if was then E.setGesture("UNLOCKED PAD") end
        E.invalidate()
      end

      local function lock(fromPin)
        local secs = ctlInt("LockoutSeconds", LOCK_MIN, LOCK_MAX, LOCK_DEFAULT)
        if self.lockTimer then self.lockTimer:cancel() end
        cancelPending()
        clearPath()
        self.tries = 0
        self.lockedUntil = E.now() + secs
        self.shownRemaining = nil
        if not fromPin then E.out("Locked", true) end
        self.lockTimer = E.after(secs, function()
          self.lockTimer = nil
          unlock(false)
        end)
        E.animate(true)
        E.setGesture("LOCKED " .. secs .. " S")
        E.invalidate()
      end

      -- Adds dot k and, before it, every grid dot lying exactly on the
      -- segment from the previous dot (a skipped middle dot).
      local function addDot(k)
        local seen, path = self.seen, self.path
        if seen[k] or #path >= MAX_DOTS then return end
        local last = path[#path]
        if last then
          local a, b = self.dots[last], self.dots[k]
          local dr, dc = b.row - a.row, b.col - a.col
          local g = gcd(dr, dc)
          if g > 1 then
            local sr, sc = dr // g, dc // g
            for i = 1, g - 1 do
              local m = (a.row + sr * i) * self.n + (a.col + sc * i) + 1
              if not seen[m] and #path < MAX_DOTS then
                seen[m] = true
                path[#path + 1] = m
              end
            end
          end
        end
        if #path < MAX_DOTS then
          seen[k] = true
          path[#path + 1] = k
        end
      end

      local function nearestDot(x, y)
        local best, bestD = nil, HIT * self.spacing
        local dots = self.dots
        for k = 1, self.n * self.n do
          local d = dots[k]
          local dist = sqrt((d.x - x) * (d.x - x) + (d.y - y) * (d.y - y))
          if dist <= bestD then best, bestD = k, dist end
        end
        return best
      end

      -- Checks (or learns) the drawn pattern. `learn` is the Learn flag to
      -- use: a delayed check passes the flag captured at its lift.
      local function submit(learn)
        if learn == nil then learn = self.learn end
        cancelPending()
        self.active = false
        self.fx, self.fy = nil, nil
        local path = self.path
        if #path < MIN_DOTS then
          -- a single dot (a tap on a dot) is not a pattern: no check, no try
          clearPath()
          E.invalidate()
          return
        end
        local str = patternString(path)
        E.out("LastPattern", str)
        if learn then
          self.secret = parsePattern(str, self.n * self.n)
          E.out("Pattern", str)
          self.learn = false
          E.out("Learn", false)
          self.tries = 0
          setFeedback("ok", "Pattern stored")
          E.setGesture("PATTERN STORED")
        elseif samePath(path, self.secret) then
          self.tries = 0
          E.pulse("Unlocked")
          setFeedback("ok", "Unlocked")
          E.setGesture("UNLOCKED")
        else
          self.tries = self.tries + 1
          E.pulse("Failed")
          E.setGesture("FAILED")
          local maxTries = ctlInt("MaxTries", TRIES_MIN, TRIES_MAX, TRIES_DEFAULT)
          if self.tries >= maxTries then
            lock(false)
          else
            setFeedback("fail", "Try " .. self.tries .. " of " .. maxTries)
          end
        end
        E.invalidate()
      end

      local function addNear(x, y)
        local k = nearestDot(x, y)
        if k and not self.seen[k] then
          addDot(k)
          -- AutoSubmit checks; it never cuts a new secret short while learning
          if self.auto and not self.learn and not self.submitted and #self.secret > 0 and #self.path >= #self.secret then
            self.submitted = true
            submit()
          end
        end
      end

      local function readSecret()
        local secret = parsePattern(ctlString("Pattern"), self.n * self.n)
        if #secret < MIN_DOTS then secret = {} end
        self.secret = secret
      end

      function self:onStart()
        buildGrid(ctlInt("GridSize", GRID_MIN, GRID_MAX, GRID_DEFAULT))
        readSecret()
        self.learn = ctlBool("Learn")
        self.masked = ctlBool("Masked")
        self.auto = ctlBool("AutoSubmit")
        if ctlBool("Locked") then lock(true) end
        E.invalidate()
      end

      function self:onTouchStart(x, y, t)
        if isLocked() then return end
        cancelFeedback()
        if self.pending then
          -- the previous drawing was never resumed: check it now, and stop
          -- here if that check locked the pad
          submit(self.pendingLearn)
          if isLocked() then return end
        end
        clearPath()
        self.active = true
        self.fx, self.fy = x, y
        self.x0, self.y0, self.moved = x, y, 0
        addNear(x, y)
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        if not self.active then return end
        self.fx, self.fy = x, y
        local d = sqrt((x - self.x0) * (x - self.x0) + (y - self.y0) * (y - self.y0))
        if d > self.moved then self.moved = d end
        addNear(x, y)
        E.invalidate()
      end

      function self:onTouchEnd(x, y, t, info)
        if not self.active then return end
        info = info or {}
        if info.aborted then
          clearPath()
          E.invalidate()
          return
        end
        addNear(x, y)
        if self.submitted or not self.active then
          self.active = false
          self.fx, self.fy = nil, nil
          E.invalidate()
          return
        end
        self.fx, self.fy = nil, nil
        if info.inferred and not info.tap and self.moved > DRAG_START then
          -- The engine may take this lift back (a resting finger sends nothing
          -- in Designer), but only for a touch that dragged: check once the
          -- resume window is over, with the Learn flag as it is now.
          cancelPending()
          local learn = self.learn
          self.pendingLearn = learn
          self.pending = E.after(RESUME_WAIT, function()
            self.pending = nil
            submit(learn)
          end)
          E.invalidate()
        else
          submit()
        end
      end

      function self:onTouchResume(x, y, t)
        if isLocked() or not self.pending then return end
        cancelPending()
        self.active = true
        self.fx, self.fy = x, y
        addNear(x, y)
        E.invalidate()
      end

      function self:onLock(locked)
        if locked then
          cancelPending()
          clearPath()
        end
        E.invalidate()
      end

      function self:onControl(name, index, ctl)
        if name == "Pattern" then
          readSecret()
        elseif name == "GridSize" then
          local n = clampInt(ctl.Value, GRID_MIN, GRID_MAX, GRID_DEFAULT)
          if n ~= self.n then
            -- a real change only: a same-value write keeps the drawing in progress
            buildGrid(n)
            cancelPending()
            clearPath()
            readSecret()
          end
        elseif name == "Locked" then
          if ctl.Boolean then
            if not isLocked() then lock(true) end
          elseif isLocked() then
            unlock(true)
          end
        elseif name == "Learn" then
          self.learn = ctl.Boolean == true
        elseif name == "Masked" then
          self.masked = ctl.Boolean == true
        elseif name == "AutoSubmit" then
          self.auto = ctl.Boolean == true
        else
          return
        end
        E.invalidate()
      end

      function self:tick(dt)
        if not self.lockedUntil then
          E.animate(false)
          return
        end
        if E.now() >= self.lockedUntil then
          unlock(false)
          return
        end
        local rem = remaining()
        if rem ~= self.shownRemaining then
          self.shownRemaining = rem
          E.invalidate()
        end
      end

      function self:draw(c)
        local locked = isLocked()
        local fb = self.feedback
        local colour = self.learn and T.accent2 or T.accent
        local fbColour = colour
        if fb then
          fbColour = (fb.kind == "ok") and T.ok or T.danger
          -- the result colours the trail it belongs to, not a drawing in progress
          if not self.active then colour = fbColour end
        end
        local dots, n, r = self.dots, self.n, self.r
        local path, seen = self.path, self.seen
        local showTrail = not self.masked and not locked
        local dim = locked and 0.35 or 1

        -- the trail under the dots, plus the rubber band to the finger
        if showTrail and #path > 0 then
          local pts = {}
          for i = 1, #path do
            local d = dots[path[i]]
            pts[#pts + 1] = d.x
            pts[#pts + 1] = d.y
          end
          if self.active and self.fx then
            pts[#pts + 1] = self.fx
            pts[#pts + 1] = self.fy
          end
          if #pts >= 4 then
            c:polyline(pts, { stroke = colour, sw = max(3, self.spacing * 0.06), cap = "round", join = "round", opacity = 0.85 })
          end
        end

        -- the dots
        for k = 1, n * n do
          local d = dots[k]
          if showTrail and seen[k] then
            c:circle(d.x, d.y, r * 1.9, { fill = colour, opacity = 0.22 })
            c:circle(d.x, d.y, r, { fill = colour, stroke = T.onAccent, sw = 1 })
          else
            c:circle(d.x, d.y, r, { fill = T.well, stroke = T.line, sw = 1.5, opacity = dim })
          end
        end

        -- masked entry: one small dot per joined dot, like a hidden PIN, on
        -- its own line under the top line
        if self.masked and not locked and self.showMask and #path > 0 then
          local step = 3 * MASK_R
          local x0 = W / 2 - (#path - 1) * step / 2
          for i = 1, #path do
            c:circle(x0 + (i - 1) * step, self.maskY, MASK_R, { fill = colour })
          end
        end

        -- the top line: feedback, learn prompt, tries, or the lockout
        local topY = self.topY
        if locked then
          c:rect(0, 0, W, H, { fill = T.bg, opacity = 0.55 })
          local s = max(24, min(72, side * 0.18))
          Shapes.icon(c, "lock", W / 2, H / 2 - s * 0.35, s, T.muted)
          c:text(W / 2, H / 2 + s * 0.5 + textSize, "Locked", { size = textSize + 2, fill = T.text, anchor = "middle", weight = "bold" })
          c:textFit(W / 2, H / 2 + s * 0.5 + textSize * 2.4, W - 16, "Try again in " .. remaining() .. " s",
                    { size = textSize, fill = T.muted, anchor = "middle" })
        elseif not self.showTop then
          -- no room above the dots: the colours alone carry the result
        elseif fb then
          c:textFit(W / 2, topY, W - 16, fb.text, { size = textSize + 1, fill = fbColour, anchor = "middle", weight = "bold" })
        elseif self.learn then
          c:textFit(W / 2, topY, W - 16, "Draw the new pattern", { size = textSize, fill = T.accent2, anchor = "middle", weight = "bold" })
        elseif self.tries > 0 and not self.active then
          local maxTries = ctlInt("MaxTries", TRIES_MIN, TRIES_MAX, TRIES_DEFAULT)
          c:textFit(W / 2, topY, W - 16, "Try " .. self.tries .. " of " .. maxTries, { size = textSize, fill = T.muted, anchor = "middle" })
        end

        if E.hint and self.showHint and not self.active and not locked and not fb and not self.pending then
          local hint = HINT
          if #self.secret == 0 and not self.learn then hint = HINT_EMPTY end
          Shapes.hint(c, T, hint, W, H)
        end
      end

      return self
    end,
  }
end
