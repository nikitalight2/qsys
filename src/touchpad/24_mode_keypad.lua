-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Keypad mode
--
-- A numeric keypad drawn by the pad (digits 0-9, clear, enter) for PIN entry
-- on a lobby or lectern. Accepted codes live in `Pin` (several separated by
-- commas); every key press updates `Entry`; a code is checked on Enter or,
-- with `AutoSubmit`, as soon as the entry equals a code or reaches the length
-- of the longest code. `MaxTries` failures lock the keypad (`Locked` on) for
-- `LockoutSeconds`; `Locked` is a pin both ways (a script locks or clears).
-- `Learn` stores the next entered code (ended by Enter) into `Pin`. `Masked`
-- shows dots instead of digits on the pad. A swipe left deletes a digit.
--
-- The whole body sits in a `do` block: the built plugin is one chunk with a
-- 200-local limit, so only Modes["Keypad"] is defined at the top level.

Modes = Modes or {}

do
  local HINT = "Tap a key, swipe left to delete"
  -- 3 x 4 keys, row by row; "C" clears, "E" enters.
  local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "E" }
  local MAX_CODES, MAX_CODE_LEN, MAX_ENTRY, MAX_PIN_TEXT = 32, 16, 16, 1024
  local FLASH, FEEDBACK = 0.15, 0.8
  local MIN_LOCKOUT, MAX_LOCKOUT, MIN_TRIES, MAX_TRIES = 10, 3600, 1, 10

  -- "1234, 5678" -> { "1234", "5678" }: trimmed, digits only, bounded.
  local function parseCodes(text)
    local out = {}
    text = tostring(text or "")
    if #text > MAX_PIN_TEXT then text = string.sub(text, 1, MAX_PIN_TEXT) end
    local parts = U.split(text, ",")
    for i = 1, math.min(#parts, MAX_CODES) do
      local code = U.trim(parts[i])
      if code ~= "" and #code <= MAX_CODE_LEN and not string.find(code, "[^%d]") then
        out[#out + 1] = code
      end
    end
    return out
  end

  Modes["Keypad"] = {
    id = "keypad",
    pretty = "Keypad",
    hint = HINT,

    controls = function(C, props)
      C.add({ Name = "Pin", ControlType = "Text", PinStyle = "Input", DefaultValue = "1234" })
      C.add({ Name = "Entry", ControlType = "Text", PinStyle = "Output" })
      C.add({ Name = "Masked", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", DefaultValue = true })
      C.add({ Name = "AutoSubmit", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", DefaultValue = true })
      C.add({ Name = "Learn", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input" })
      C.add({ Name = "Accepted", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output" })
      C.add({ Name = "Rejected", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output" })
      C.add({ Name = "Locked", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" })
      C.add({ Name = "MaxTries", ControlType = "Knob", ControlUnit = "Integer", Min = MIN_TRIES, Max = MAX_TRIES,
              DefaultValue = 5, PinStyle = "Input" })
      C.add({ Name = "LockoutSeconds", ControlType = "Knob", ControlUnit = "Integer", Min = MIN_LOCKOUT,
              Max = MAX_LOCKOUT, DefaultValue = 60, PinStyle = "Input" })
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "KEYPAD")
        L.sideButton(ctx, "Masked", "MASKED")
        L.sideButton(ctx, "AutoSubmit", "AUTO SUBMIT")
        L.sideButton(ctx, "Learn", "LEARN CODE")
        L.sideButton(ctx, "Locked", "LOCKED")
        L.sideCaption(ctx, "PAD")
        L.sideButton(ctx, "Lock", "LOCK")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "K E Y P A D", 142)
        L.caption("ACCEPTED CODES (DIGITS, COMMA SEPARATED)", { ix, iy }, { iw, 10 }, "Left")
        L.text("Pin", { ix, iy + 12 }, { iw, 22 })
        local cellW = math.floor((iw - 2 * L.G) / 3)
        L.grid({ "MaxTries", "LockoutSeconds", "AutoSubmit" }, ix, iy + 42, 3, cellW, 44)
        L.label("Lockout after Max Tries failures for Lockout Seconds; a script clears it early through Locked.\nLearn stores the next code ended by Enter into Pin.",
                { ix, iy + 94 }, { iw, 40 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local self = {
        codes = {},            -- accepted codes (strings of digits)
        entry = "",            -- digits typed since the last submit or clear
        tries = 0,             -- failures since the last success or unlock
        locked = false, lockUntil = 0, lockTimer = nil,
        flash = nil, flashHandle = nil,         -- key index highlighted after a tap
        feedback = nil, feedbackText = "", feedbackHandle = nil,  -- "ok" | "bad"
        downKey = nil, downX = 0, downY = 0,    -- key under a resting finger
        masked = true, auto = true, learn = false,
        keys = {},             -- { x, y, w, h, label } per key, computed once
      }

      -- ---------- geometry (computed once) ----------
      local m = U.clamp(math.floor(math.min(W, H) * 0.04), 4, 12)
      local g = U.clamp(math.floor(math.min(W, H) * 0.02), 3, 10)
      local hintH = E.hint and 18 or 0
      local dispH = U.clamp(math.floor(H * 0.16), 34, 72)
      local gridY = m + dispH + g
      local gridH = H - gridY - m - hintH
      local keyW = (W - 2 * m - 2 * g) / 3
      local keyH = (gridH - 3 * g) / 4
      for i = 1, #KEYS do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        self.keys[i] = { x = m + col * (keyW + g), y = gridY + row * (keyH + g), w = keyW, h = keyH, label = KEYS[i] }
      end
      local keyRadius = U.clamp(math.floor(math.min(keyW, keyH) * 0.16), 3, 14)
      local digitSize = U.clamp(math.floor(math.min(keyH * 0.5, keyW * 0.45)), 10, 44)

      local function hitKey(x, y)
        for i = 1, #self.keys do
          local k = self.keys[i]
          if x >= k.x and x <= k.x + k.w and y >= k.y and y <= k.y + k.h then return i end
        end
        return nil
      end

      -- Centre of the key with this label (white-box helper for the tests).
      function self:keyCenter(label)
        for i = 1, #self.keys do
          local k = self.keys[i]
          if k.label == label then return k.x + k.w / 2, k.y + k.h / 2 end
        end
        return nil
      end

      -- ---------- control readers ----------
      local function ctlBool(name, default)
        local c = E.ctl(name)
        if c == nil then return default end
        return c.Boolean and true or false
      end
      local function ctlInt(name, default, lo, hi)
        local c = E.ctl(name)
        local v = c and tonumber(c.Value) or default
        return U.clamp(math.floor(v + 0.5), lo, hi)
      end
      local function ctlStr(name)
        local c = E.ctl(name)
        return c and tostring(c.String or "") or ""
      end

      local function longestCode()
        local n = 0
        for i = 1, #self.codes do
          if #self.codes[i] > n then n = #self.codes[i] end
        end
        return n
      end

      local function matches(entry)
        for i = 1, #self.codes do
          if self.codes[i] == entry then return true end
        end
        return false
      end

      -- ---------- timed visuals ----------
      local function clearFlash()
        if self.flashHandle then self.flashHandle:cancel() end
        self.flash, self.flashHandle = nil, nil
      end
      local function flashKey(i)
        clearFlash()
        self.flash = i
        self.flashHandle = E.after(FLASH, function()
          self.flash, self.flashHandle = nil, nil
          E.invalidate()
        end)
      end
      local function clearFeedback()
        if self.feedbackHandle then self.feedbackHandle:cancel() end
        self.feedback, self.feedbackText, self.feedbackHandle = nil, "", nil
      end
      local function showFeedback(kind, text)
        clearFeedback()
        self.feedback, self.feedbackText = kind, text
        self.feedbackHandle = E.after(FEEDBACK, function()
          self.feedback, self.feedbackText, self.feedbackHandle = nil, "", nil
          E.invalidate()
        end)
      end

      -- ---------- lockout ----------
      local function stopLockTimer()
        if self.lockTimer then self.lockTimer:cancel() end
        self.lockTimer = nil
      end

      local function unlock(write)
        stopLockTimer()
        self.locked, self.lockUntil, self.tries, self.entry = false, 0, 0, ""
        clearFeedback()
        if write then E.out("Locked", false) end
        E.setGesture("UNLOCKED")
        E.invalidate()
      end

      local function lock(seconds)
        stopLockTimer()
        clearFlash()
        clearFeedback()
        self.locked = true
        self.lockUntil = E.now() + seconds
        self.entry, self.downKey = "", nil
        E.out("Locked", true)
        E.setGesture("LOCKED")
        -- One tick per second redraws the countdown and ends the lockout.
        self.lockTimer = E.every(1, function()
          if E.now() >= self.lockUntil - 1e-6 then
            unlock(true)
          else
            E.invalidate()
          end
        end)
        E.invalidate()
      end

      -- ---------- entry and submit ----------
      local function setEntry(s)
        self.entry = s
        E.out("Entry", s)
      end

      local function submit()
        if self.locked then return end
        local entry = self.entry
        if entry == "" then return end
        self.entry = ""                           -- the Entry pin keeps the last code for scripts
        if self.learn then
          self.learn = false
          self.codes = { entry }
          E.out("Pin", entry)
          E.out("Learn", false)
          showFeedback("ok", "Code stored")
          E.setGesture("CODE STORED")
          return
        end
        if matches(entry) then
          self.tries = 0
          E.pulse("Accepted")
          showFeedback("ok", "Accepted")
          E.setGesture("ACCEPTED")
          return
        end
        self.tries = self.tries + 1
        E.pulse("Rejected")
        E.setGesture("REJECTED")
        if self.tries >= ctlInt("MaxTries", 5, MIN_TRIES, MAX_TRIES) then
          lock(ctlInt("LockoutSeconds", 60, MIN_LOCKOUT, MAX_LOCKOUT))
        else
          showFeedback("bad", "Try again")
        end
      end

      -- AutoSubmit: a match submits at once; otherwise the entry is checked
      -- when it is as long as the longest code (so it can only be rejected).
      local function autoCheck()
        if not self.auto or self.learn or #self.codes == 0 then return end
        if matches(self.entry) or #self.entry >= longestCode() then submit() end
      end

      local function pressKey(i)
        if self.locked then return end
        flashKey(i)
        if self.feedback then clearFeedback() end   -- typing again ends the last verdict's display
        local label = KEYS[i]
        if label == "C" then
          setEntry("")
          E.setGesture("CLEAR")
        elseif label == "E" then
          E.setGesture("ENTER")
          submit()
        else
          if #self.entry < MAX_ENTRY then setEntry(self.entry .. label) end
          E.setGesture("KEY " .. label)
          autoCheck()
        end
        E.invalidate()
      end

      local function backspace()
        if self.locked or self.entry == "" then return end
        setEntry(string.sub(self.entry, 1, #self.entry - 1))
        E.setGesture("DELETE")
        E.invalidate()
      end

      -- ---------- engine hooks ----------
      function self:onStart()
        self.codes = parseCodes(ctlStr("Pin"))
        self.masked = ctlBool("Masked", true)
        self.auto = ctlBool("AutoSubmit", true)
        self.learn = ctlBool("Learn", false)
        if ctlBool("Locked", false) then lock(ctlInt("LockoutSeconds", 60, MIN_LOCKOUT, MAX_LOCKOUT)) end
        E.invalidate()
      end

      function self:onTouchStart(x, y, t)
        self.downX, self.downY = x, y
        self.downKey = (not self.locked) and hitKey(x, y) or nil
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        if self.downKey and U.dist(x, y, self.downX, self.downY) > 12 then
          self.downKey = nil                      -- a drag is not a key press
          E.invalidate()
        end
      end

      function self:onTouchEnd(x, y, t, info)
        if self.downKey then
          self.downKey = nil
          E.invalidate()
        end
      end

      function self:onGesture(gst)
        if gst.type == "tap" then
          local i = hitKey(gst.x, gst.y)
          if i then pressKey(i) end
        elseif gst.type == "swipe" and gst.dir == "left" then
          backspace()
        end
      end

      function self:onLock(locked)
        self.downKey = nil
        E.invalidate()
      end

      function self:onControl(name, index, ctl)
        if name == "Pin" then
          self.codes = parseCodes(ctl.String)
        elseif name == "Locked" then
          if ctl.Boolean then
            if not self.locked then lock(ctlInt("LockoutSeconds", 60, MIN_LOCKOUT, MAX_LOCKOUT)) end
          elseif self.locked then
            unlock(false)
          end
        elseif name == "Masked" then
          self.masked = ctl.Boolean and true or false
        elseif name == "AutoSubmit" then
          self.auto = ctl.Boolean and true or false
        elseif name == "Learn" then
          self.learn = ctl.Boolean and true or false
          if self.learn then self.entry = "" end
        end
        E.invalidate()
      end

      -- ---------- drawing ----------
      local function drawEntry(c, bx, by, bw, bh)
        local cx, cy = bx + bw / 2, by + bh / 2
        if self.locked then
          local remaining = math.max(0, math.ceil(self.lockUntil - E.now() - 1e-6))
          local s = U.clamp(math.floor(bh * 0.5), 14, 28)
          Shapes.icon(c, "lock", bx + 12 + s / 2, cy, s, T.danger)
          c:textFit(bx + 20 + s, cy - 2, bw - 32 - s, "Locked", { size = U.clamp(math.floor(bh * 0.3), 11, 18), fill = T.danger, weight = "bold" })
          c:textFit(bx + 20 + s, cy + 13, bw - 32 - s, "Try again in " .. remaining .. " s", { size = 11, fill = T.muted })
          return
        end
        if self.feedback then
          local colour = (self.feedback == "ok") and T.ok or T.danger
          local icon = (self.feedback == "ok") and "check" or "cross"
          local s = U.clamp(math.floor(bh * 0.5), 14, 28)
          local tw = Font.width(self.feedbackText, 18, "bold")
          local x0 = cx - (tw + s + 8) / 2
          Shapes.icon(c, icon, x0 + s / 2, cy, s, colour)
          c:textFit(x0 + s + 8, cy + 6, bw - 24 - s, self.feedbackText, { size = 18, fill = colour, weight = "bold" })
          return
        end
        local n = #self.entry
        if n == 0 then
          local text = "Enter code"
          if self.learn then text = "New code, then Enter"
          elseif #self.codes == 0 then text = "No code set" end
          c:textFit(cx, cy + 5, bw - 24, text, { size = 14, fill = T.muted, anchor = "middle" })
        elseif self.masked then
          local r = U.clamp(math.floor(bh * 0.12), 3, 7)
          local step = math.min(2.6 * r, (bw - 16) / n)
          local x0 = cx - step * (n - 1) / 2
          for i = 1, n do
            c:circle(x0 + (i - 1) * step, cy, r, { fill = T.text })
          end
        else
          c:textFit(cx, cy + math.floor(bh * 0.18), bw - 24, self.entry,
            { size = U.clamp(math.floor(bh * 0.5), 12, 36), fill = T.text, anchor = "middle", weight = "bold" })
        end
        if self.learn and n > 0 then
          c:textFit(bx + bw - 8, by + 12, bw / 2, "Learn", { size = 10, fill = T.accent2, anchor = "end" })
        elseif self.tries > 0 then
          c:textFit(bx + bw - 8, by + 12, bw / 2,
            "Attempt " .. self.tries .. " of " .. ctlInt("MaxTries", 5, MIN_TRIES, MAX_TRIES),
            { size = 10, fill = T.danger, anchor = "end" })
        end
      end

      local function drawKeys(c)
        for i = 1, #self.keys do
          local k = self.keys[i]
          local fill, stroke, text = T.panel, T.line, T.text
          if self.flash == i then
            fill, stroke, text = T.accent, T.accent, T.onAccent
          elseif self.downKey == i then
            fill, stroke = Svg.lighten(T.panel, 0.12), T.accent
          end
          c:rect(k.x + 0.5, k.y + 0.5, k.w - 1, k.h - 1, { fill = fill, stroke = stroke, sw = 1, rx = keyRadius })
          local cx, cy = k.x + k.w / 2, k.y + k.h / 2
          if k.label == "C" then
            Shapes.icon(c, "cross", cx, cy, digitSize * 0.9, (self.flash == i) and T.onAccent or T.danger)
          elseif k.label == "E" then
            Shapes.icon(c, "check", cx, cy, digitSize * 0.9, (self.flash == i) and T.onAccent or T.ok)
          else
            c:text(cx, cy + digitSize * 0.35, k.label, { size = digitSize, fill = text, anchor = "middle" })
          end
        end
      end

      function self:draw(c)
        local bx, by, bw, bh = m, m, W - 2 * m, dispH
        local stroke = T.line
        if self.locked or self.feedback == "bad" then stroke = T.danger
        elseif self.feedback == "ok" then stroke = T.ok
        elseif self.learn then stroke = T.accent2 end
        c:rect(bx + 0.5, by + 0.5, bw - 1, bh - 1, { fill = T.well, stroke = stroke, sw = 1, rx = math.min(10, keyRadius + 2) })
        drawEntry(c, bx, by, bw, bh)
        if self.locked then
          c:group({ opacity = 0.35 }, function(gc) drawKeys(gc) end)
        else
          drawKeys(c)
        end
        if E.hint and not self.locked then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      return self
    end,
  }
end
