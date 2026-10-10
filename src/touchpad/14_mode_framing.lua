-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Camera Framing mode
--
-- Draw a box around the next shot (spec 3.5). The pad shows the camera's
-- current view as the widest 16:9 box on the pad. A box drawn on it is a
-- region of that view: when it is applied the camera frames it, the Apply
-- pin pulses and FramePan / FrameTilt (0..1, the frame centre within the
-- home view; 0.5 = home) and FrameZoom (0 = whole view, 1 = the tightest
-- frame, MinFrame of the home view) follow. The box stays on the pad:
-- dragging inside moves it, dragging a corner resizes it, each applied as
-- a corrected shot within the same view. A new box drawn outside it first
-- re-bases the pad on the current shot, so boxes add up: each is relative
-- to the view the camera has at that moment. A box smaller than 8 % of the
-- pad (width or height) is ignored; a nudge that never crosses the drag
-- threshold changes nothing. A certain lift applies at once; an inferred
-- lift (no Panel Touch) applies 1.5 s later unless the drag resumes.
-- Double tap = zoom out (Reset: the whole home view; pulses Reset). Home
-- (Both) does the same and sends the camera home. InvertPan / InvertTilt
-- mirror the direction of the outputs and of the camera. HFOV and
-- OpticalZoom turn a frame into camera degrees and a zoom position:
-- pan = (cx - 0.5) * HFOV, tilt = (0.5 - cy) * HFOV * 9 / 16, zoom position
-- = (1 / fw - 1) / (OpticalZoom - 1), sent through gotoPosition. Zoom +/-
-- drive the camera and the pad adopts the camera's zoom afterwards.

Modes = Modes or {}

do
  local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
  local sformat = string.format

  local HINT = "Draw a box to frame. Double tap = zoom out"
  local ASPECT = 9 / 16
  local MIN_BOX = 0.08                      -- of the pad: a smaller box is ignored (spec 3.5)
  local DRAG_START = 12                     -- px: a nudge below it changes nothing (spec 5.4)
  local PENDING = 1.5                       -- s: an inferred lift applies after this unless resumed
  local PIN_GUARD = 0.5                     -- s: the trailing edge of a pulse just handled is not a second one
  local ZOOM_POLL = 0.2                     -- s between zoom readings while Zoom +/- is held
  local HANDLE_MIN = 12                     -- px: corner grab radius (at least)

  local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
  end

  Modes["Camera Framing"] = {
    id = "framing",
    pretty = "Camera Framing",
    hint = HINT,

    controls = function(C, props)
      C.add{ Name = "FramePan", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, DefaultValue = 0.5, PinStyle = "Output" }
      C.add{ Name = "FrameTilt", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, DefaultValue = 0.5, PinStyle = "Output" }
      C.add{ Name = "FrameZoom", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, DefaultValue = 0, PinStyle = "Output" }
      C.add{ Name = "Apply", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both" }
      C.add{ Name = "Reset", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both" }
      C.add{ Name = "Home", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both" }
      C.add{ Name = "MinFrame", ControlType = "Knob", ControlUnit = "Float", Min = 0.1, Max = 0.6, DefaultValue = 0.25, PinStyle = "Input" }
      C.add{ Name = "InvertPan", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" }
      C.add{ Name = "InvertTilt", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both" }
      C.add{ Name = "HFOV", ControlType = "Knob", ControlUnit = "Float", Min = 20, Max = 120, DefaultValue = 60, PinStyle = "Input", Group = "Camera" }
      C.add{ Name = "OpticalZoom", ControlType = "Knob", ControlUnit = "Float", Min = 1, Max = 40, DefaultValue = 12, PinStyle = "Input", Group = "Camera" }
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "FRAMING")
        L.sideButton(ctx, "Apply", "RESEND")
        L.sideButton(ctx, "Reset", "ZOOM OUT")
        L.sideButton(ctx, "Home", "HOME")
        L.sideButton(ctx, "InvertPan", "FLIP PAN")
        L.sideButton(ctx, "InvertTilt", "FLIP TILT")
      elseif page == "Setup" then
        local ix, iy = L.section(ctx, "C A M E R A  F R A M I N G", 48)
        L.grid({ "MinFrame", "HFOV", "OpticalZoom" }, ix, iy, 3, 96, 48)
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local inset = min(10, floor(min(W, H) * 0.04))
      local cw, ch = W - 2 * inset, H - 2 * inset      -- the card
      -- the view: the widest 16:9 box on the card, centred
      local vw = min(cw, ch / ASPECT)
      local vh = vw * ASPECT
      local vx, vy = inset + (cw - vw) / 2, inset + (ch - vh) / 2
      local minW, minH = MIN_BOX * W, MIN_BOX * H
      local HANDLE = max(HANDLE_MIN, floor(min(W, H) * 0.035))

      local self = {
        -- the view the pad represents, within the home view: centre (0..1,
        -- y down) and width fraction (1 = the whole home view)
        px = 0.5, py = 0.5, pw = 1,
        box = nil,                      -- { x0, y0, x1, y1 } pad px, the current shot within the view
        gesture = nil,                  -- "draw" | "move" | "resize" while a finger works
        down = false, active = false,   -- active: the drag crossed its threshold
        ox = 0, oy = 0,                 -- draw: origin; move: box offset from the finger
        corner = nil,                   -- resize: { ax, ay } the anchored (opposite) corner
        accX = 0, accY = 0,
        fx = 0, fy = 0,
        box0 = nil,                     -- the box before a nudge (restored by Lock)
        pending = nil,                  -- timer: apply after an inferred lift
        unsent = false,                 -- the box was finished but not sent yet
        applyAt = -10, resetAt = -10, homeAt = -10,
        camZoom = 0,                    -- zoom position 0..1 read from the camera
        zooming = false, zoomPollAt = 0,
        minimap = nil,
      }

      -- ---------- controls ----------
      local function knob(name, default)
        local c = E.ctl(name)
        if c == nil then return default end
        local v = tonumber(c.Value)
        if v == nil then return default end
        return v
      end
      local function toggle(name)
        local c = E.ctl(name)
        return c ~= nil and c.Boolean == true
      end
      local function minFrame() return clamp(knob("MinFrame", 0.25), 0.1, 0.6) end
      local function hfov() return clamp(knob("HFOV", 60), 20, 120) end
      local function opticalZoom() return clamp(knob("OpticalZoom", 12), 1, 40) end
      local function signX() return toggle("InvertPan") and -1 or 1 end
      local function signY() return toggle("InvertTilt") and -1 or 1 end

      -- ---------- geometry ----------
      local function normBox(x0, y0, x1, y1)
        if x1 < x0 then x0, x1 = x1, x0 end
        if y1 < y0 then y0, y1 = y1, y0 end
        return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
      end
      local function clampPoint(x, y)
        return clamp(x, vx, vx + vw), clamp(y, vy, vy + vh)
      end
      -- Moves a box so it lies inside the view (its size is kept, capped at the view).
      local function fitBox(b)
        local w, h = min(b.x1 - b.x0, vw), min(b.y1 - b.y0, vh)
        local x0 = clamp(b.x0, vx, vx + vw - w)
        local y0 = clamp(b.y0, vy, vy + vh - h)
        return { x0 = x0, y0 = y0, x1 = x0 + w, y1 = y0 + h }
      end
      -- The 16:9 shot a box asks for: relative size f and centre (bx, by) in view units.
      local function shotOf(b)
        local f = max((b.x1 - b.x0) / vw, (b.y1 - b.y0) / vh)
        f = clamp(f, 0.001, 1)
        local bx = ((b.x0 + b.x1) / 2 - vx) / vw
        local by = ((b.y0 + b.y1) / 2 - vy) / vh
        return f, bx, by
      end
      -- The box composed onto the current view: the frame within the home view.
      local function compose(b)
        if b == nil then return self.px, self.py, self.pw end
        local f, bx, by = shotOf(b)
        local fw = self.pw * f
        local lo = minFrame()
        if fw < lo then fw = lo end
        if fw > 1 then fw = 1 end
        local cx = self.px + (bx - 0.5) * self.pw
        local cy = self.py + (by - 0.5) * self.pw
        cx = clamp(cx, fw / 2, 1 - fw / 2)
        cy = clamp(cy, fw / 2, 1 - fw / 2)
        return cx, cy, fw
      end
      -- The 16:9 frame the camera really gets for a box (MinFrame applied),
      -- as a pad rect around the box's centre, kept inside the view.
      local function ghostOf(b)
        local _, _, fw = compose(b)
        local f = clamp(fw / self.pw, 0.001, 1)
        local w, h = f * vw, f * vh
        local mx, my = (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2
        return fitBox({ x0 = mx - w / 2, y0 = my - h / 2, x1 = mx + w / 2, y1 = my + h / 2 })
      end
      local function frameDeg(cx, cy)
        return signX() * (cx - 0.5) * hfov(), signY() * (0.5 - cy) * hfov() * ASPECT
      end
      local function zoomPosOf(fw)
        local oz = opticalZoom()
        if oz <= 1 then return 0 end
        return clamp((1 / fw - 1) / (oz - 1), 0, 1)
      end

      -- ---------- camera ----------
      local function cam() return E.camera end

      local function readZoom(cb)
        local c = cam()
        if c == nil or type(c.getPosition) ~= "function" then return end
        pcall(c.getPosition, c, function(p, t, z)
          if type(z) == "number" then
            z = clamp(z, 0, 1)
            if z ~= self.camZoom then
              self.camZoom = z
              E.invalidate()
            end
            if cb then cb(z) end
          end
        end)
      end

      local function sendFrame(cx, cy, fw)
        local c = cam()
        if c == nil or type(c.gotoPosition) ~= "function" then return end
        local pan, tilt = frameDeg(cx, cy)
        local z = zoomPosOf(fw)
        pcall(c.gotoPosition, c, pan, tilt, z)
        self.camZoom = z
      end

      -- ---------- outputs ----------
      local function outputs()
        local cx, cy, fw = compose(self.box)
        local ox = signX() > 0 and cx or 1 - cx
        local oy = signY() > 0 and 1 - cy or cy
        E.out("FramePan", clamp(ox, 0, 1))
        E.out("FrameTilt", clamp(oy, 0, 1))
        local lo = minFrame()
        local z = 0
        if lo < 1 then z = clamp((1 - fw) / (1 - lo), 0, 1) end
        E.out("FrameZoom", z)
      end

      local function cancelPending()
        if self.pending then self.pending:cancel(); self.pending = nil end
      end

      -- Sends the current box as a shot.
      local function apply(pulseOut)
        cancelPending()
        self.unsent = false
        if self.box == nil then return end
        local cx, cy, fw = compose(self.box)
        outputs()
        sendFrame(cx, cy, fw)
        self.applyAt = E.now()
        E.setGesture("APPLY")
        if pulseOut then E.pulse("Apply") end
        E.invalidate()
      end

      -- The current shot becomes the view the pad represents.
      local function rebase()
        if self.box == nil then return end
        self.px, self.py, self.pw = compose(self.box)
        self.box = nil
      end

      local function zoomOut(now, pulseName)
        cancelPending()
        self.unsent = false
        self.px, self.py, self.pw = 0.5, 0.5, 1
        self.box = nil
        self.gesture, self.active = nil, false
        outputs()
        if pulseName == "Reset" then
          self.resetAt = now
          E.setGesture("RESET")
          local c = cam()
          if c and type(c.gotoPosition) == "function" then
            pcall(c.gotoPosition, c, 0, 0, 0)
            self.camZoom = 0
          end
        else
          self.homeAt = now
          E.setGesture("HOME")
          local c = cam()
          if c and type(c.home) == "function" then
            pcall(c.home, c)
            self.camZoom = 0
          end
        end
        E.invalidate()
      end

      -- After Zoom +/-: the pad adopts the camera's zoom as its view.
      local function adoptCameraZoom()
        readZoom(function(z)
          rebase()
          local f = 1 + z * (opticalZoom() - 1)
          self.pw = clamp(1 / f, 0.001, 1)
          self.px = clamp(self.px, self.pw / 2, 1 - self.pw / 2)
          self.py = clamp(self.py, self.pw / 2, 1 - self.pw / 2)
          outputs()
          E.invalidate()
        end)
      end

      -- ---------- the gesture ----------
      local function nearCorner(b, x, y)
        local cs = { { b.x0, b.y0 }, { b.x1, b.y0 }, { b.x0, b.y1 }, { b.x1, b.y1 } }
        for i = 1, 4 do
          local c = cs[i]
          if abs(x - c[1]) <= HANDLE and abs(y - c[2]) <= HANDLE then
            return { ax = b.x0 + b.x1 - c[1], ay = b.y0 + b.y1 - c[2] }
          end
        end
        return nil
      end
      local function inside(b, x, y)
        return x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1
      end

      -- Applies the finger position to the box in progress.
      local function track(x, y)
        local g = self.gesture
        if g == "draw" then
          local x1, y1 = clampPoint(x, y)
          local x0, y0 = clampPoint(self.ox, self.oy)
          self.box = normBox(x0, y0, x1, y1)
        elseif g == "move" then
          local b = self.box0
          local w, h = b.x1 - b.x0, b.y1 - b.y0
          local x0, y0 = x + self.ox, y + self.oy
          self.box = fitBox({ x0 = x0, y0 = y0, x1 = x0 + w, y1 = y0 + h })
        elseif g == "resize" then
          local a = self.corner
          local x1, y1 = clampPoint(x, y)
          -- the box keeps at least the minimum size on the anchored side
          if abs(x1 - a.ax) < minW then x1 = a.ax + (x1 >= a.ax and minW or -minW) end
          if abs(y1 - a.ay) < minH then y1 = a.ay + (y1 >= a.ay and minH or -minH) end
          self.box = fitBox(normBox(a.ax, a.ay, x1, y1))
        end
      end

      local function beginGesture(x, y)
        local b = self.box
        self.box0 = b
        if b then
          local c = nearCorner(b, x, y)
          if c then
            self.gesture, self.corner = "resize", c
            return
          end
          if inside(b, x, y) then
            self.gesture = "move"
            self.ox, self.oy = b.x0 - x, b.y0 - y
            return
          end
        end
        self.gesture = "draw"
        self.ox, self.oy = x, y
      end

      function self:onTouchStart(x, y, t)
        -- a shot still pending from the previous lift goes out first
        if self.pending then apply(true) end
        self.down, self.active = true, false
        self.fx, self.fy = x, y
        self.accX, self.accY = 0, 0
        beginGesture(x, y)
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        self.fx, self.fy = x, y
        if not self.active then
          self.accX, self.accY = self.accX + dx, self.accY + dy
          if sqrt(self.accX * self.accX + self.accY * self.accY) <= DRAG_START then return end
          self.active = true
          if self.gesture == "draw" and self.box0 then
            -- a new box: the pad re-bases on the current shot first
            rebase()
            self.box0 = nil
          end
        end
        track(x, y)
        E.invalidate()
      end

      local function finish(inferred)
        local g = self.gesture
        self.down = false
        if not self.active then
          -- nothing moved: the box is as it was (a box taken back from an
          -- inferred lift still has to go out)
          self.gesture = nil
          self.box = self.box0
          self.box0 = nil
          if not (self.unsent and self.box) then
            E.invalidate()
            return
          end
        end
        local b = self.box
        if g == "draw" and self.active and (b == nil or b.x1 - b.x0 < minW or b.y1 - b.y0 < minH) then
          -- too small: ignored (the view was already re-based, the frame is unchanged)
          self.box = nil
          self.gesture, self.active = nil, false
          E.setGesture("TOO SMALL")
          E.invalidate()
          return
        end
        self.gesture, self.active = nil, false
        self.box0 = nil
        self.unsent = true
        if inferred then
          cancelPending()
          self.pending = E.after(PENDING, function()
            self.pending = nil
            apply(true)
          end)
          E.invalidate()
        else
          apply(true)
        end
      end

      function self:onTouchEnd(x, y, t, info)
        if self.gesture == nil then self.down = false; return end
        if info and info.aborted then
          -- the engine dropped the touch (Lock, a clock step): nothing is
          -- sent and the box is as it was before the gesture
          self.down, self.active, self.gesture = false, false, nil
          self.box = self.box0
          self.box0 = nil
          E.invalidate()
          return
        end
        if self.active then track(x, y) end
        finish(info and info.inferred)
      end

      function self:onTouchResume(x, y, t)
        -- the lift is taken back: the same gesture goes on from here
        cancelPending()
        self.down = true
        self.fx, self.fy = x, y
        if self.gesture == nil then
          -- the box finished at the lift: continue as a nudge of that box
          beginGesture(x, y)
          self.active = false
          self.accX, self.accY = 0, 0
          E.invalidate()
          return
        end
        if self.gesture == "move" and self.box then
          self.box0 = self.box
          self.ox, self.oy = self.box.x0 - x, self.box.y0 - y
        end
        E.invalidate()
      end

      function self:onGesture(g)
        if g.type == "double" then zoomOut(g.t or E.now(), "Reset"); E.pulse("Reset") end
      end

      function self:onLock(locked)
        if locked then
          cancelPending()
          self.unsent = false
          if self.gesture then
            self.box = self.box0
            self.box0 = nil
          end
          self.gesture, self.active, self.down = nil, false, false
          local c = cam()
          if c and type(c.stop) == "function" then pcall(c.stop, c) end
        end
        E.invalidate()
      end

      -- ---------- controls ----------
      function self:onControl(name, index, ctl)
        local now = E.now()
        if name == "Home" then
          if ctl.Boolean or now - self.homeAt >= PIN_GUARD then zoomOut(now, "Home") end
          return
        end
        if name == "Reset" then
          if ctl.Boolean or now - self.resetAt >= PIN_GUARD then zoomOut(now, "Reset") end
          return
        end
        if name == "Apply" then
          -- re-send the current shot (the pin or the Pad page button)
          if ctl.Boolean or now - self.applyAt >= PIN_GUARD then
            local cx, cy, fw = compose(self.box)
            outputs()
            sendFrame(cx, cy, fw)
            self.applyAt = now
            E.setGesture("APPLY")
            E.invalidate()
          end
          return
        end
        if name == "InvertPan" or name == "InvertTilt" or name == "MinFrame" then
          outputs()
          E.invalidate()
          return
        end
        if name == "HFOV" or name == "OpticalZoom" then
          E.invalidate()
          return
        end
        local c = cam()
        if c == nil then return end
        if name == "ZoomIn" or name == "ZoomOut" then
          if type(c.onControl) == "function" then pcall(c.onControl, c, name, index, ctl) end
          self.zooming = ctl.Boolean and true or false
          if self.zooming then
            self.zoomPollAt = now
            E.animate(true)
          else
            E.after(ZOOM_POLL, adoptCameraZoom)
          end
          E.invalidate()
          return
        end
        if type(c.onControl) == "function" then pcall(c.onControl, c, name, index, ctl) end
      end

      function self:tick(dt)
        if self.zooming then
          local now = E.now()
          if now - self.zoomPollAt >= ZOOM_POLL - 0.0005 then
            self.zoomPollAt = now
            readZoom()
          end
        else
          E.animate(false)
        end
      end

      function self:onStart()
        outputs()
        readZoom()
      end

      -- ---------- drawing ----------
      local function handles(c, b)
        local s = 8
        local o = { fill = T.accent, stroke = T.onAccent, sw = 1 }
        c:rect(b.x0 - s / 2, b.y0 - s / 2, s, s, o)
        c:rect(b.x1 - s / 2, b.y0 - s / 2, s, s, o)
        c:rect(b.x0 - s / 2, b.y1 - s / 2, s, s, o)
        c:rect(b.x1 - s / 2, b.y1 - s / 2, s, s, o)
      end

      local function minimap(c)
        if cw < 160 or ch < 90 then return end
        local mw = clamp(floor(cw * 0.22), 32, 96)
        local mh = floor(mw * ASPECT + 0.5)
        local mx, my = inset + cw - mw - 8, inset + 8
        c:rect(mx, my, mw, mh, { fill = T.well, stroke = T.line, sw = 1, rx = 2, opacity = 0.9 })
        local cx, cy, fw = compose(self.box)
        local fx, fy = mx + (cx - fw / 2) * mw, my + (cy - fw / 2) * mh
        c:rect(fx, fy, fw * mw, fw * mh, { fill = T.accent, opacity = 0.25 })
        c:rect(fx, fy, fw * mw, fw * mh, { fill = "none", stroke = T.accent, sw = 1 })
        return mw
      end

      function self:draw(c)
        c:rect(inset, inset, cw, ch, { fill = T.panel, stroke = T.line, sw = 1, rx = max(4, floor(inset * 1.2)) })
        -- the view: what the camera sees now (widest 16:9 box on the pad)
        c:rect(vx, vy, vw, vh, { rx = 2, fill = T.well, stroke = T.line, sw = 1 })
        local g = { stroke = T.line, sw = 1, opacity = 0.6 }
        c:line(vx + vw / 3, vy, vx + vw / 3, vy + vh, g)
        c:line(vx + 2 * vw / 3, vy, vx + 2 * vw / 3, vy + vh, g)
        c:line(vx, vy + vh / 3, vx + vw, vy + vh / 3, g)
        c:line(vx, vy + 2 * vh / 3, vx + vw, vy + 2 * vh / 3, g)
        -- the current box
        local b = self.box
        if b then
          local pending = self.pending ~= nil
          local w, h = b.x1 - b.x0, b.y1 - b.y0
          -- the 16:9 frame the camera really gets, when it is not the box itself
          local gb = ghostOf(b)
          if (self.gesture == "draw" and self.down) or abs(gb.x1 - gb.x0 - w) > 0.5 or abs(gb.y1 - gb.y0 - h) > 0.5 then
            c:rect(gb.x0, gb.y0, gb.x1 - gb.x0, gb.y1 - gb.y0,
              { fill = "none", stroke = T.muted, sw = 1, dash = { 4, 3 }, opacity = 0.8 })
          end
          local small = w < minW or h < minH
          c:rect(b.x0, b.y0, w, h, { fill = T.accent, opacity = small and 0.06 or 0.14, rx = 2 })
          c:rect(b.x0, b.y0, w, h, { rx = 2, fill = "none", stroke = small and T.muted or T.accent, sw = 2,
                                     dash = pending and { 6, 4 } or nil })
          if not small and not (self.gesture == "draw" and self.down) then handles(c, b) end
        end
        -- readout and the mini-map of the home view
        local mw = minimap(c) or 0
        local cx, cy, fw = compose(b)
        local pan, tilt = frameDeg(cx, cy)
        local txt = sformat("FRAME x%.1f  PAN %+d  TILT %+d", 1 / fw, floor(pan + 0.5), floor(tilt + 0.5))
        if cam() then txt = txt .. sformat("  ZOOM x%.1f", 1 + self.camZoom * (opticalZoom() - 1)) end
        c:textFit(inset + 8, inset + 20, max(20, cw - mw - 24), txt,
          { size = 12, fill = T.text, anchor = "start", weight = "bold" })
        local flips = (toggle("InvertPan") and "FLIP PAN " or "") .. (toggle("InvertTilt") and "FLIP TILT" or "")
        if flips ~= "" then
          c:textFit(inset + 8, inset + 36, max(20, cw - mw - 24), flips, { size = 10, fill = T.accent2, anchor = "start" })
        end
        if self.pending then
          c:text(W / 2, vy + vh - 8, "SENDING...", { size = 11, fill = T.accent2, anchor = "middle", weight = "bold" })
        end
        if self.down and self.active then
          c:circle(self.fx, self.fy, 4, { fill = T.muted, opacity = 0.6 })
        end
        if E.hint and not self.down then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- Camera View (480 x 270): the Demo camera's scene.
      function self:drawCamera(c)
        local cm = cam()
        if cm and type(cm.drawView) == "function" then
          cm:drawView(c)
        else
          c:rect(0, 0, 480, 270, { fill = T.well })
          c:text(240, 140, "No camera view", { size = 14, fill = T.muted, anchor = "middle" })
        end
      end

      return self
    end,
  }
end
