-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Sign-In mode
--
-- A visitor sign-in pad: a signature area drawn by the pad plus the guest
-- fields `GuestName`, `GuestCompany` and `Visiting` (Text pins both ways; the
-- UCI's own text boxes fill them). `Submit` writes the signature as
-- `<base>/SignIns/<time>_<name>.svg`, appends a line to
-- `<base>/SignIns/log.csv` (UTF-8 with a BOM written once when the file is
-- created; formula-safe cells), pulses `Submitted`, sets `LastGuest` and
-- `TodayCount`, posts the webhook (JSON or a Teams Adaptive Card) and clears
-- the form for the next guest. A failed save shows "Not saved: please ask at
-- reception", counts nothing and pulses nothing. `TodayCount` counts today's
-- lines of the log at start-up and resets at midnight; the form clears after
-- three idle minutes; a second Submit right after a sign-in does nothing.
-- Strokes are polylines simplified to at most 400 points, at most 60 of
-- them; a touch without movement draws a dot.
--
-- The whole body sits in a `do` block: the built plugin is one chunk with a
-- 200-local limit, so only Modes["Sign-In"] is defined at the top level.

Modes = Modes or {}

do
  local HINT = "Sign above the line, then press Sign In"
  local MAX_STROKES, MAX_POINTS = 60, 400
  local CHUNK = 48                    -- raw points simplified per step while drawing
  local MAX_TOTAL = 4000              -- points over every stroke (the pad SVG stays far under its limit)
  local FILE_LIMIT = 400000           -- chars: the signature file's canvas limit
  local SIMPLIFY_TOL = 0.6            -- px: Ramer-Douglas-Peucker tolerance
  local IDLE_CLEAR = 180              -- s without activity clears the form
  local RESUBMIT_GUARD = 2            -- s: a second Submit in this window does nothing
  local MESSAGE_TIME = 5              -- s: the thank-you line stays this long
  local HOUSEKEEP = 10                -- s: idle and midnight check cadence
  local TRIGGER_DEBOUNCE = 0.3
  local MAX_FIELD, MAX_FILE_NAME, MAX_URL = 120, 40, 2048
  local FOLDER = "SignIns"
  local LOG_HEADER = "time,name,company,visiting,room,file"
  local BOM = "\239\187\191"
  local NOT_SAVED = "Not saved: please ask at reception"
  local INK, PAPER = "#1B1F24", "#FFFFFF"   -- the signature file's colours
  local sformat, ssub, sfind, sgsub, concat = string.format, string.sub, string.find, string.gsub, table.concat

  -- Field text as stored: trimmed and bounded (the pins may carry anything).
  local function field(s)
    s = U.trim(tostring(s or ""))
    if U.utf8len(s) > MAX_FIELD then s = U.truncateChars(s, MAX_FIELD) end
    return s
  end

  -- "Ana Lopez-Smith" -> "Ana_Lopez-Smith": letters, digits and dashes only.
  local function fileSafe(name)
    local s = sgsub(tostring(name or ""), "[^%w%-]+", "_")
    s = sgsub(sgsub(s, "^_+", ""), "_+$", "")
    if #s > MAX_FILE_NAME then s = ssub(s, 1, MAX_FILE_NAME) end
    if s == "" then s = "guest" end
    return s
  end

  -- Escapes a plain string for use as a Lua pattern.
  local function patternOf(s)
    return (sgsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
  end

  -- Keeps at most `target` points of a flat array (first and last always).
  local function decimate(pts, target)
    local n = #pts // 2
    if n <= target then return pts end
    local step = math.ceil(n / target)
    local out = {}
    for i = 1, n - 1, step do
      out[#out + 1] = pts[2 * i - 1]
      out[#out + 1] = pts[2 * i]
    end
    out[#out + 1] = pts[2 * n - 1]
    out[#out + 1] = pts[2 * n]
    return out
  end

  Modes["Sign-In"] = {
    id = "signin",
    pretty = "Sign-In",
    hint = HINT,

    controls = function(C, props)
      C.add({ Name = "GuestName", ControlType = "Text", PinStyle = "Both", Group = "Guest" })
      C.add({ Name = "GuestCompany", ControlType = "Text", PinStyle = "Both", Group = "Guest" })
      C.add({ Name = "Visiting", ControlType = "Text", PinStyle = "Both", Group = "Guest" })
      C.add({ Name = "Submit", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Legend = "SIGN IN" })
      C.add({ Name = "Clear", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Legend = "CLEAR" })
      C.add({ Name = "ClearSignature", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Legend = "CLEAR SIGNATURE" })
      C.add({ Name = "Submitted", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Output" })
      C.add({ Name = "LastGuest", ControlType = "Text", PinStyle = "Output" })
      C.add({ Name = "TodayCount", ControlType = "Text", PinStyle = "Output" })
      C.add({ Name = "RoomName", ControlType = "Text", PinStyle = "Input" })
      C.add({ Name = "WebhookUrl", ControlType = "Text", PinStyle = "Input" })
      C.add({ Name = "SendStatus", ControlType = "Text", PinStyle = "Output" })
      C.add({ Name = "PenWidth", ControlType = "Knob", ControlUnit = "Float", Min = 1, Max = 8, DefaultValue = 3, PinStyle = "Input" })
    end,

    pages = {},

    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "SIGN-IN")
        L.sideButton(ctx, "Submit", "SIGN IN")
        L.sideButton(ctx, "Clear", "CLEAR")
        L.sideButton(ctx, "ClearSignature", "CLEAR SIGNATURE")
        L.sideCaption(ctx, "PAD")
        L.sideButton(ctx, "Lock", "LOCK")
        -- The guest fields under the pad: the UCI text boxes bind to these pins.
        local y = ctx.y + ctx.dh + L.G + 24 + 4 + 14 + 16 + L.GAP
        local cellW = math.floor((ctx.dw - 2 * L.G) / 3)
        L.grid({ "GuestName", "GuestCompany", "Visiting" }, ctx.x, y, 3, cellW, 40)
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "S I G N - I N", 196)
        L.caption("ROOM NAME (ON THE LOG AND THE WEBHOOK)", { ix, iy }, { iw - 60, 10 }, "Left")
        L.text("RoomName", { ix, iy + 12 }, { iw - 60, 22 })
        L.caption("PEN", { ix + iw - 48, iy }, { 48, 10 })
        L.knob("PenWidth", { ix + iw - 40, iy + 12 }, { 32, 32 }, { color = Nikita.Magenta })
        L.caption("WEBHOOK URL (POSTED PER PROPERTY: JSON OR TEAMS CARD)", { ix, iy + 44 }, { iw, 10 }, "Left")
        L.text("WebhookUrl", { ix, iy + 56 }, { iw, 22 }, { fontSize = 9 })
        L.caption("SEND STATUS", { ix, iy + 86 }, { iw, 10 }, "Left")
        L.readout("SendStatus", { ix, iy + 98 }, { iw, 22 }, { fontSize = 9 })
        L.label("Each sign-in writes SignIns/<time>_<name>.svg and a line of SignIns/log.csv\n"
                .. "under design/ in Emulate (temporary) and media/ on a Core. The form clears\n"
                .. "after 3 idle minutes; Today Count resets at midnight.",
                { ix, iy + 128 }, { iw, 56 })
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T
      local num = Svg.num
      local self = {
        fields = { name = "", company = "", visiting = "" },
        strokes = {},            -- finished: { d = "M..L..", dot = { x, y } or nil }
        live = nil,              -- { kept = {flat, simplified}, raw = {flat, current chunk}, x0, y0, x1, y1 }
        total = 0,               -- points over every finished stroke
        message = nil,           -- { text, kind = "ok" | "bad" | "info" }
        messageHandle = nil,
        count = 0, today = "",
        lastSubmitAt = -100, actAt = -100, activeAt = 0,
        houseHandle = nil,
        lastFile = "",
      }

      -- ---------- geometry (computed once) ----------
      local m = U.clamp(math.floor(math.min(W, H) * 0.04), 4, 14)
      local hintH = E.hint and 18 or 0
      local hdrH = U.clamp(math.floor(H * 0.2), 40, 92)
      local footH = U.clamp(math.floor(H * 0.09), 18, 34)
      local box = { x = m, y = m + hdrH, w = W - 2 * m, h = H - 2 * m - hdrH - footH - hintH }
      if box.h < 24 then box.h = 24 end
      local baseY = box.y + box.h * 0.78
      local titleSize = U.clamp(math.floor(hdrH * 0.16), 9, 13)
      local nameSize = U.clamp(math.floor(hdrH * 0.26), 11, 22)
      local subSize = U.clamp(math.floor(hdrH * 0.15), 9, 13)
      local radius = U.clamp(math.floor(math.min(W, H) * 0.03), 3, 12)

      local function inBox(x, y)
        return x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
      end

      -- ---------- control readers ----------
      local function ctlStr(name)
        local c = E.ctl(name)
        return c and tostring(c.String or "") or ""
      end
      local function penWidth()
        local c = E.ctl("PenWidth")
        return U.clamp(tonumber(c and c.Value) or 3, 1, 8)
      end
      local function roomName()
        return field(ctlStr("RoomName"))
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

      local function activity()
        self.activeAt = E.now()
      end

      -- ---------- messages ----------
      local function clearMessage()
        if self.messageHandle then self.messageHandle:cancel() end
        self.message, self.messageHandle = nil, nil
      end
      -- A "bad" message stays until the next action; the others fade.
      local function showMessage(kind, text)
        clearMessage()
        self.message = { kind = kind, text = text }
        if kind ~= "bad" then
          self.messageHandle = E.after(MESSAGE_TIME, function()
            self.message, self.messageHandle = nil, nil
            E.invalidate()
          end)
        end
        E.invalidate()
      end

      -- ---------- strokes ----------
      -- A stroke is simplified as it is drawn: every CHUNK raw points are run
      -- through Ramer-Douglas-Peucker and appended to `kept`, so no single
      -- handler (move or lift) simplifies more than one chunk.
      local function closeChunk(live)
        local raw = live.raw
        if #raw < 4 then return end
        local simple = U.simplify(raw, SIMPLIFY_TOL)
        local kept = live.kept
        local from = (#kept > 0) and 3 or 1          -- the chunk starts on the last kept point
        for i = from, #simple do kept[#kept + 1] = simple[i] end
        if #kept // 2 > 2 * MAX_POINTS then live.kept = decimate(kept, MAX_POINTS) end
        local lx, ly = raw[#raw - 1], raw[#raw]
        live.raw = { lx, ly }
      end

      local function startStroke(x, y)
        if #self.strokes >= MAX_STROKES or self.total >= MAX_TOTAL then return end
        x, y = U.clamp(x, box.x, box.x + box.w), U.clamp(y, box.y, box.y + box.h)
        self.live = { kept = {}, raw = { x, y }, x0 = x, y0 = y, x1 = x, y1 = y }
        if self.message and self.message.kind == "bad" then clearMessage() end
        activity()
        E.invalidate()
      end

      local function addPoint(x, y)
        local live = self.live
        if not live then return end
        x, y = U.clamp(x, box.x, box.x + box.w), U.clamp(y, box.y, box.y + box.h)
        local raw = live.raw
        local n = #raw
        if raw[n - 1] == x and raw[n] == y then return end
        raw[n + 1], raw[n + 2] = x, y
        if x < live.x0 then live.x0 = x elseif x > live.x1 then live.x1 = x end
        if y < live.y0 then live.y0 = y elseif y > live.y1 then live.y1 = y end
        if n + 2 >= 2 * CHUNK then closeChunk(live) end
        E.invalidate()
      end

      local function pathOf(pts, n)
        local parts = {}
        for i = 1, 2 * n, 2 do
          parts[#parts + 1] = (i == 1 and "M" or "L") .. num(pts[i]) .. " " .. num(pts[i + 1])
        end
        return concat(parts, " ")
      end

      local function finishStroke()
        local live = self.live
        if not live then return end
        self.live = nil
        if live.x1 - live.x0 < 2 and live.y1 - live.y0 < 2 then
          self.strokes[#self.strokes + 1] = { dot = { live.raw[1], live.raw[2] } }
          self.total = self.total + 1
        else
          closeChunk(live)
          local pts = live.kept
          if #pts < 4 then pts = live.raw end
          local limit = math.min(MAX_POINTS, MAX_TOTAL - self.total)
          if limit >= 2 then
            if #pts // 2 > limit then pts = decimate(pts, limit) end
            local n = #pts // 2
            self.strokes[#self.strokes + 1] = { d = pathOf(pts, n), n = n }
            self.total = self.total + n
          end
        end
        activity()
        E.invalidate()
      end

      local function drawStrokes(c, ink, pw)
        local strokes = self.strokes
        for i = 1, #strokes do
          local s = strokes[i]
          if s.dot then
            c:circle(s.dot[1], s.dot[2], pw * 0.9, { fill = ink })
          else
            c:path(s.d, { stroke = ink, sw = pw, cap = "round", join = "round" })
          end
        end
        local live = self.live
        if live then
          local kept, raw = live.kept, live.raw
          if #kept + #raw <= 2 then
            c:circle(raw[1], raw[2], pw * 0.9, { fill = ink })
          else
            local parts = {}
            for i = 1, #kept, 2 do parts[#parts + 1] = num(kept[i]) .. " " .. num(kept[i + 1]) end
            local from = (#kept > 0) and 3 or 1
            for i = from, #raw, 2 do parts[#parts + 1] = num(raw[i]) .. " " .. num(raw[i + 1]) end
            c:path("M" .. concat(parts, " L"), { stroke = ink, sw = pw, cap = "round", join = "round" })
          end
        end
      end

      -- The signature as its own SVG: the box's size, ink on paper.
      local function signatureSvg()
        local c = Svg.new(math.floor(box.w + 0.5), math.floor(box.h + 0.5), { limit = FILE_LIMIT })
        c:rect(0, 0, box.w, box.h, { fill = PAPER })
        c:group({ transform = "translate(" .. num(-box.x) .. " " .. num(-box.y) .. ")" }, function(gc)
          drawStrokes(gc, INK, penWidth())
        end)
        return c:finish()
      end

      -- ---------- form ----------
      local function setField(key, name, value)
        if self.fields[key] ~= value then
          self.fields[key] = value
          E.out(name, value)
        end
      end

      local function formEmpty()
        return self.fields.name == "" and self.fields.company == "" and self.fields.visiting == ""
          and #self.strokes == 0 and self.live == nil
      end

      local function clearForm(quiet)
        setField("name", "GuestName", "")
        setField("company", "GuestCompany", "")
        setField("visiting", "Visiting", "")
        self.strokes, self.live, self.total = {}, nil, 0
        if not quiet then
          clearMessage()
          E.setGesture("CLEARED")
        end
        E.invalidate()
      end

      -- ---------- the daily count ----------
      local function folder()
        return E.file.base() .. "/" .. FOLDER
      end

      local function countToday(day)
        local data = E.file.read(folder() .. "/log.csv")
        if type(data) ~= "string" or data == "" then return 0 end
        local _, n = sgsub(data, "\n" .. patternOf(day), "")
        return n
      end

      local function setCount(n)
        self.count = n
        E.out("TodayCount", tostring(n))
      end

      -- ---------- the webhook ----------
      local function webhook(rec, svg)
        local kind = tostring(E.props["Sign-In Webhook"] or "Off")
        local url = U.trim(ctlStr("WebhookUrl"))
        if kind == "Off" or url == "" then return end
        if #url > MAX_URL then
          E.out("SendStatus", "Send failed: URL too long")
          return
        end
        local body
        if kind == "Teams Card" then
          body = {
            type = "message",
            attachments = { {
              contentType = "application/vnd.microsoft.card.adaptive",
              content = {
                ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
                type = "AdaptiveCard", version = "1.4",
                body = {
                  { type = "TextBlock", size = "Medium", weight = "Bolder", text = "Visitor signed in" },
                  { type = "FactSet", facts = {
                      { title = "Name", value = rec.name },
                      { title = "Company", value = rec.company },
                      { title = "Visiting", value = rec.visiting },
                      { title = "Room", value = rec.room },
                      { title = "Time", value = rec.time },
                  } },
                },
              },
            } },
          }
        else
          body = { name = rec.name, company = rec.company, visiting = rec.visiting, room = rec.room,
                   time = rec.time, signature = Q.base64(svg), file = rec.file }
        end
        local text = E.json.encode(body)
        E.out("SendStatus", "Sending...")
        local ok = E.http.post(url, text, { ["Content-Type"] = "application/json" }, function(code, data, err)
          code = tonumber(code) or 0
          if err or code < 200 or code >= 300 then
            local why = err and tostring(err) or ("HTTP " .. code)
            if #why > 80 then why = ssub(why, 1, 77) .. "..." end
            E.out("SendStatus", "Send failed: " .. why)
            E.status("Webhook failed: " .. why, "warn")
          else
            E.out("SendStatus", "Sent " .. code)
          end
        end)
        if not ok then E.out("SendStatus", "Send failed: could not start") end
      end

      -- ---------- submit ----------
      local function failSave(why)
        showMessage("bad", NOT_SAVED)
        E.setGesture("NOT SAVED")
        E.status(NOT_SAVED .. (why and (" (" .. tostring(why) .. ")") or ""), "warn")
        E.log("Touch Pad: sign-in not saved: " .. tostring(why or "unknown"))
      end

      local function submit()
        local now = E.now()
        if now - self.lastSubmitAt < RESUBMIT_GUARD then return end
        activity()
        if self.live then finishStroke() end
        local name = self.fields.name
        if name == "" then
          showMessage("info", "Please enter your name")
          E.setGesture("ENTER YOUR NAME")
          return
        end
        if #self.strokes == 0 then
          showMessage("info", "Please sign")
          E.setGesture("PLEASE SIGN")
          return
        end
        local t = Q.time()
        local dir = folder()
        E.file.mkdir(dir)
        local fileName = Q.date("%Y%m%d_%H%M%S", t) .. "_" .. fileSafe(name) .. ".svg"
        local svg = signatureSvg()
        local ok, err = E.file.write(dir .. "/" .. fileName, svg)
        if not ok then return failSave(err) end
        local rec = { name = name, company = self.fields.company, visiting = self.fields.visiting,
                      room = roomName(), time = U.isoTime(t), file = fileName }
        local row = concat({ U.csvCell(Q.date("%Y-%m-%d %H:%M:%S", t)), U.csvCell(rec.name), U.csvCell(rec.company),
                             U.csvCell(rec.visiting), U.csvCell(rec.room), U.csvCell(fileName) }, ",") .. "\r\n"
        local logPath = dir .. "/log.csv"
        if E.file.read(logPath) == nil then
          ok, err = E.file.write(logPath, BOM .. LOG_HEADER .. "\r\n" .. row)
        else
          ok, err = E.file.append(logPath, row)
        end
        if not ok then return failSave(err) end
        -- Saved: count, announce, post, and clear the form for the next guest.
        self.lastSubmitAt = now
        self.lastFile = fileName
        local day = Q.date("%Y-%m-%d", t)
        if day ~= self.today then self.today = day; self.count = 0 end
        setCount(self.count + 1)
        E.out("LastGuest", name)
        E.pulse("Submitted")
        E.setGesture("SIGNED IN: " .. name)
        E.status("OK - Signed in: " .. name, "ok")
        webhook(rec, svg)
        clearForm(true)
        showMessage("ok", "Thank you, " .. name)
      end

      -- ---------- housekeeping: idle clear and midnight ----------
      local function housekeep()
        local now = E.now()
        local day = Q.date("%Y-%m-%d")
        if day ~= self.today then
          self.today = day
          setCount(0)
          E.invalidate()
        end
        if now - self.activeAt >= IDLE_CLEAR and not formEmpty() and self.live == nil then
          clearForm(true)
          clearMessage()
          E.setGesture(HINT)
        end
      end

      -- ---------- engine hooks ----------
      function self:onStart()
        self.fields.name = field(ctlStr("GuestName"))
        self.fields.company = field(ctlStr("GuestCompany"))
        self.fields.visiting = field(ctlStr("Visiting"))
        self.today = Q.date("%Y-%m-%d")
        setCount(countToday(self.today))
        E.out("LastGuest", "")
        local kind = tostring(E.props["Sign-In Webhook"] or "Off")
        E.out("SendStatus", kind == "Off" and "Off" or "Ready")
        self.activeAt = E.now()
        self.houseHandle = E.every(HOUSEKEEP, housekeep)
        E.invalidate()
      end

      function self:onTouchStart(x, y, t)
        activity()
        if inBox(x, y) then startStroke(x, y) end
      end

      function self:onTouchMove(x, y, t, dx, dy)
        if self.live then addPoint(x, y) end
      end

      function self:onTouchEnd(x, y, t, info)
        if self.live then
          if not info.aborted then addPoint(x, y) end
          finishStroke()
        end
      end

      -- A lift taken back by the engine: the ink of the first part is kept
      -- and a fresh stroke starts where the finger landed (no joining line).
      function self:onTouchResume(x, y, t)
        activity()
        if inBox(x, y) then startStroke(x, y) end
      end

      function self:onLock(locked)
        if locked and self.live then finishStroke() end
        E.invalidate()
      end

      function self:onControl(name, index, ctl)
        if name == "GuestName" then
          self.fields.name = field(ctl.String); activity()
        elseif name == "GuestCompany" then
          self.fields.company = field(ctl.String); activity()
        elseif name == "Visiting" then
          self.fields.visiting = field(ctl.String); activity()
        elseif name == "Submit" then
          if fired(ctl) then submit() end
        elseif name == "Clear" then
          if fired(ctl) then activity(); clearForm(false) end
        elseif name == "ClearSignature" then
          if fired(ctl) then
            activity()
            self.strokes, self.live, self.total = {}, nil, 0
            if self.message and self.message.kind ~= "ok" then clearMessage() end
            E.setGesture("SIGNATURE CLEARED")
          end
        elseif name == "WebhookUrl" then
          return
        end
        E.invalidate()
      end

      -- ---------- drawing ----------
      local function drawHeader(c)
        local x0, y = m, m + titleSize
        c:text(x0, y, "Visitor sign-in", { size = titleSize, fill = T.muted, weight = "bold" })
        local right = "Today: " .. self.count
        local room = roomName()
        if room ~= "" then right = room .. "   " .. right end
        c:textFit(W - m, y, W * 0.6, right, { size = titleSize, fill = T.muted, anchor = "end" })
        y = y + nameSize + 4
        local f = self.fields
        if f.name ~= "" then
          c:textFit(x0, y, W - 2 * m, f.name, { size = nameSize, fill = T.text, weight = "bold" })
        else
          c:text(x0, y, "Your name", { size = nameSize, fill = T.line, weight = "bold" })
        end
        y = y + subSize + 6
        local sub = f.company
        if f.visiting ~= "" then sub = (sub ~= "" and (sub .. "  -  ") or "") .. "visiting " .. f.visiting end
        if sub ~= "" then
          c:textFit(x0, y, W - 2 * m, sub, { size = subSize, fill = T.muted })
        else
          c:text(x0, y, "Company and who you are visiting", { size = subSize, fill = T.line })
        end
      end

      local function drawFooter(c)
        local msg = self.message
        local cy = box.y + box.h + footH / 2
        if msg then
          local colour, icon = T.muted, nil
          if msg.kind == "ok" then colour, icon = T.ok, "check"
          elseif msg.kind == "bad" then colour, icon = T.danger, "cross" end
          local size = U.clamp(math.floor(footH * 0.5), 10, 15)
          local tw = math.min(Font.width(msg.text, size, "bold"), W - 2 * m - 24)
          local iconW = icon and (size + 6) or 0
          local x0 = W / 2 - (tw + iconW) / 2
          if icon then Shapes.icon(c, icon, x0 + size / 2, cy, size, colour) end
          c:textFit(x0 + iconW, cy + size * 0.35, W - 2 * m - iconW, msg.text, { size = size, fill = colour, weight = "bold" })
        elseif E.hint and self.live == nil then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      function self:draw(c)
        drawHeader(c)
        local stroke = T.line
        if self.message and self.message.kind == "bad" then stroke = T.danger
        elseif self.message and self.message.kind == "ok" then stroke = T.ok
        elseif self.live then stroke = T.accent end
        c:rect(box.x + 0.5, box.y + 0.5, box.w - 1, box.h - 1, { fill = T.well, stroke = stroke, sw = 1, rx = radius })
        c:line(box.x + m, baseY, box.x + box.w - m, baseY, { stroke = T.line, sw = 1, dash = "4 4" })
        c:text(box.x + m, baseY - 4, "x", { size = subSize, fill = T.muted })
        drawStrokes(c, T.text, penWidth())
        drawFooter(c)
      end

      -- White-box helpers for the tests.
      function self:box() return box.x, box.y, box.w, box.h end
      function self:strokeCount() return #self.strokes end
      function self:strokePoints(i)
        local s = self.strokes[i]
        if not s then return 0 end
        if s.dot then return 1 end
        return s.n
      end

      return self
    end,
  }
end
