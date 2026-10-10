-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Drag & Drop mode
--
-- Sources on the left, screens (destinations) on the right. Drag a source
-- tile onto a screen to route it, or tap a source and then a screen. A
-- double tap on a source (two taps on the same tile) sends it to every
-- screen; with AllowCalls on (the default) screens whose name carries a call
-- word (teams, zoom, webex, codec, call) are left alone so a running call is
-- not hijacked, with it off the broadcast reaches every screen. Lists page
-- when their tiles would drop under 56 px (and never show more than 12
-- sources or 16 screens on a page); dropping a source on a list's arrows
-- turns that page and keeps the source picked. A picked source is put down
-- after 8 s. Tile icons follow whole words in the names (Shapes.iconFor);
-- SourceActive off dims a source. Route n is read and written: a value written
-- from outside updates the drawing and pulses Routed n only when it changed.
--
-- Pins (spec 3.11): SourceName n, SourceActive n (in), DestName n (in),
-- Route n (both), Routed n, RouteName n (out), ClearRoutes, TapOnly, AllowCalls (in).

Modes = Modes or {}

do
  local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

  local HINT_DRAG = "Drag a source to a screen"
  local HINT_TAP = "Tap a source, then a screen"
  local HINT_PICKED = "Now tap a screen"
  local HINT_CARRY = "Drop on a screen"
  local HINT_NO_SOURCE = "Pick a source first"
  local TEXT_CLEARED = "All cleared"
  local MAX_SRC_PAGE, MAX_DST_PAGE = 12, 16
  local MIN_TILE, TILE_GAP, ARROW_H, MAX_TILE_H = 56, 6, 28, 96
  local TILE_PAD = 8                     -- Shapes.tile's inner padding
  local PUT_DOWN = 8                     -- seconds a picked source stays picked
  local DOUBLE_TIME = 0.4                -- second tap on the same tile within this = double
  local FLASH = 0.8                      -- seconds a freshly routed screen glows
  local NAME_IN_TEXT = 40                -- characters of a name used in the Gesture text
  local CALL_WORDS = { teams = true, zoom = true, webex = true, codec = true, call = true }

  local function countOf(props, name, default)
    local p = props and props[name]
    if type(p) == "table" then p = p.Value end
    local v = tonumber(p) or default
    v = floor(v + 0.5)
    if v < 1 then v = 1 elseif v > 64 then v = 64 end
    return v
  end

  -- Rows of "n", a name box and (for sources) a SIGNAL toggle, filled column
  -- by column. Returns the y below the last row.
  local function nameRows(L, base, n, x, y, w, cols, withSignal)
    local G = L.G
    local colW = floor((w - (cols - 1) * G) / cols)
    local rows = ceil(n / cols)
    for i = 1, n do
      local col, row = (i - 1) // rows, (i - 1) % rows
      local cx, cy = x + col * (colW + G), y + row * 32
      L.caption(tostring(i), { cx, cy + 7 }, { 24, 10 }, "Right")
      local tw = colW - 28
      if withSignal then tw = tw - 64 - G end
      L.text(L.key(base, i), { cx + 28, cy + 2 }, { tw, 22 })
      if withSignal then
        L.toggle(L.key("SourceActive", i), "SIGNAL", { cx + 28 + tw + G, cy + 2 }, { 64, 22 })
      end
    end
    return y + rows * 32
  end

  Modes["Drag & Drop"] = {
    id = "dragdrop",
    pretty = "Drag & Drop",
    hint = HINT_DRAG,

    controls = function(C, props)
      local nS = countOf(props, "Sources", 4)
      local nD = countOf(props, "Destinations", 2)
      C.add{ Name = "SourceName", ControlType = "Text", Count = nS, PinStyle = "Input", Group = "Sources" }
      C.add{ Name = "SourceActive", ControlType = "Button", ButtonType = "Toggle", Count = nS,
             PinStyle = "Input", Group = "Sources", DefaultValue = true }
      C.add{ Name = "DestName", ControlType = "Text", Count = nD, PinStyle = "Input", Group = "Routing" }
      C.add{ Name = "Route", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = nS, DefaultValue = 0,
             Count = nD, PinStyle = "Both", Group = "Routing" }
      C.add{ Name = "Routed", ControlType = "Button", ButtonType = "Trigger", Count = nD, PinStyle = "Output",
             Group = "Routing" }
      C.add{ Name = "RouteName", ControlType = "Text", Count = nD, PinStyle = "Output", Group = "Routing" }
      C.add{ Name = "ClearRoutes", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Group = "Routing" }
      C.add{ Name = "TapOnly", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", Group = "Routing" }
      C.add{ Name = "AllowCalls", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input", Group = "Routing",
             DefaultValue = true }
    end,

    -- Names (or Sources / Destinations above 16) hold the name boxes; the Pad
    -- page gets the routing buttons on the side; Setup explains the options.
    layout = function(L, page, props, ctx)
      local nS = countOf(props, "Sources", 4)
      local nD = countOf(props, "Destinations", 2)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT_DRAG)
        L.sideCaption(ctx, "ROUTING")
        L.sideButton(ctx, "ClearRoutes", "CLEAR ROUTES")
        L.sideButton(ctx, "TapOnly", "TAP ONLY")
        L.sideButton(ctx, "AllowCalls", "ALLOW CALLS")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "R O U T I N G", 72)
        L.toggle("TapOnly", "TAP ONLY", { ix, iy }, { 100, 24 })
        L.toggle("AllowCalls", "ALLOW CALLS", { ix + 108, iy }, { 100, 24 })
        L.label("Tap Only: no drags; tap a source, then a screen.\nAllow Calls: a double tap sends a source to every screen\nexcept Teams / Zoom / Webex / codec / call screens.",
                { ix, iy + 30 }, { iw, 42 })
      elseif page == "Names" then
        local rowsS = ceil(nS / 2)
        local ix, iy, iw = L.section(ctx, "S O U R C E S", rowsS * 32)
        nameRows(L, "SourceName", nS, ix, iy, iw, 2, true)
        local rowsD = ceil(nD / 2)
        ix, iy, iw = L.section(ctx, "D E S T I N A T I O N S", rowsD * 32)
        nameRows(L, "DestName", nD, ix, iy, iw, 2, false)
      elseif page == "Sources" then
        local rows = ceil(nS / 3)
        local ix, iy, iw = L.section(ctx, "S O U R C E  N A M E S  A N D  S I G N A L", rows * 32)
        nameRows(L, "SourceName", nS, ix, iy, iw, 3, true)
      elseif page == "Destinations" then
        local rows = ceil(nD / 4)
        local ix, iy, iw = L.section(ctx, "D E S T I N A T I O N  N A M E S", rows * 32)
        nameRows(L, "DestName", nD, ix, iy, iw, 4, false)
      end
    end,

    padColour = function(T)
      return T.bg
    end,

    create = function(E)
      local W, H, T = E.W, E.H, E.T

      local function countCtls(name, propName, default)
        local list = E.ctls(name)
        if type(list) == "table" and #list > 0 then return #list end
        return countOf(E.props, propName, default)
      end
      local nS = countCtls("SourceName", "Sources", 4)
      local nD = countCtls("DestName", "Destinations", 2)

      -- ---------- state ----------
      local src, dst = {}, {}          -- raw names ("" = unnamed)
      local iconS, iconD = {}, {}      -- icon names
      local active, routes, callD = {}, {}, {}
      local fit = { S = {}, D = {} }   -- fitted labels: fit[kind][i][key] = text
      local tapOnly, allowCalls = false, true
      local picked = nil               -- picked source index
      local timer = nil                -- put-down timer handle
      local carry = nil                -- { i, x, y, dragging }
      local down = nil                 -- hit at touch start
      local hover = nil                -- screen under a carried source
      local lastTap = nil              -- { kind, i, t } for the same-tile double tap
      local touchT0 = 0
      local lastDrop = nil             -- an inferred drop that a resume takes back
      local lastClear = nil
      local flash = nil                -- { j, at }
      local lastText = nil             -- the last Gesture text this mode set
      local hintText = HINT_DRAG
      local self = {}

      -- ---------- names ----------
      local function displayName(kind, i)
        local s = (kind == "S") and src[i] or dst[i]
        if s ~= nil and s ~= "" then return s end
        return ((kind == "S") and "Source " or "Screen ") .. i
      end

      local function isCall(name)
        local words = U.wordsOf(name)
        for k = 1, #words do
          if CALL_WORDS[words[k]] then return true end
        end
        return false
      end

      local function shortName(kind, i)
        return U.truncateChars(displayName(kind, i), NAME_IN_TEXT)
      end

      local function say(text)
        lastText = text
        E.setGesture(text)
      end

      local function idleHint()
        return tapOnly and HINT_TAP or HINT_DRAG
      end

      -- Names are stored raw; the icon, the call flag, the fitted labels and
      -- the rendered tiles derive from them on demand (a 64 x 64 start-up
      -- stays cheap).
      local tileCache = { S = {}, D = {} }   -- tileCache[kind][i] = { key, raw }
      local function setName(kind, i, s)
        s = tostring(s or "")
        if kind == "S" then
          src[i] = s
          iconS[i] = nil
          fit.S[i] = nil
          tileCache.S[i] = nil
          for j = 1, nD do
            if routes[j] == i then E.out("RouteName", displayName("S", i), j) end
          end
        else
          dst[i] = s
          iconD[i] = nil
          callD[i] = nil
          fit.D[i] = nil
          tileCache.D[i] = nil
        end
      end

      local function iconOf(kind, i)
        local icons = (kind == "S") and iconS or iconD
        local icon = icons[i]
        if icon == nil then
          icon = Shapes.iconFor(displayName(kind, i), (kind == "S") and "source" or "dest")
          icons[i] = icon
        end
        return icon
      end

      local function isCallDest(j)
        local v = callD[j]
        if v == nil then
          v = isCall(dst[j] or "")
          callD[j] = v
        end
        return v
      end

      -- Fitted label cache per name, tile width and font size.
      local function fittedLabel(kind, i, maxW, size)
        local per = fit[kind][i]
        if not per then per = {}; fit[kind][i] = per end
        local key = floor(maxW * 4) * 100 + size
        local hit = per[key]
        if hit then return hit end
        local text = Font.fit(displayName(kind, i), size, max(maxW, 0))
        per[key] = text
        return text
      end

      -- ---------- geometry and paging ----------
      local showHint = E.hint and true or false
      local margin = U.clamp(floor(min(W, H) * 0.03), 6, 14)
      local capH = (H >= 200) and 16 or 0
      local hintH = showHint and 16 or 0
      local stacked = H > W * 1.25
      local areaS, areaD
      if stacked then
        local ah = (H - 3 * margin - 2 * capH - hintH) / 2
        areaS = { x = margin, y = margin + capH, w = W - 2 * margin, h = ah }
        areaD = { x = margin, y = 2 * margin + 2 * capH + ah, w = W - 2 * margin, h = ah }
      else
        local aw = (W - 3 * margin) / 2
        local ah = H - 2 * margin - capH - hintH
        areaS = { x = margin, y = margin + capH, w = aw, h = ah }
        areaD = { x = 2 * margin + aw, y = margin + capH, w = aw, h = ah }
      end

      local function planList(area, n, limit)
        local maxCols = max(1, floor((area.w + TILE_GAP) / (MIN_TILE + TILE_GAP)))
        local maxRows = max(1, floor((area.h + TILE_GAP) / (MIN_TILE + TILE_GAP)))
        local plan = { area = area, n = n, page = 1, tiles = {} }
        if n > maxCols * maxRows or n > limit then
          local rows = max(1, floor((area.h - ARROW_H) / (MIN_TILE + TILE_GAP)))
          local cap = min(limit, maxCols * rows)
          plan.pages = U.evenPages(n, cap)
          plan.arrows = true
          plan.gridH = max(area.h - ARROW_H - TILE_GAP, 8)
          plan.rowsAvail = rows
        else
          plan.pages = { n }
          plan.arrows = false
          plan.gridH = area.h
          plan.rowsAvail = maxRows
        end
        if #plan.pages == 0 then plan.pages = { n } end
        plan.first = {}
        local acc = 1
        for p = 1, #plan.pages do
          plan.first[p] = acc
          acc = acc + plan.pages[p]
        end
        return plan
      end
      local plans = { S = planList(areaS, nS, MAX_SRC_PAGE), D = planList(areaD, nD, MAX_DST_PAGE) }

      -- Tile rectangles of one page: as few columns as the rows allow, so
      -- tiles are wide and their labels readable.
      local function tilesOf(plan, page)
        local cached = plan.tiles[page]
        if cached then return cached end
        local k = plan.pages[page] or 0
        local rows = max(1, min(k, plan.rowsAvail))
        local cols = max(1, ceil(k / rows))
        rows = max(1, ceil(k / cols))
        local area = plan.area
        local tw = (area.w - (cols - 1) * TILE_GAP) / cols
        local th = min(MAX_TILE_H, (plan.gridH - (rows - 1) * TILE_GAP) / rows)
        if th < 8 then th = 8 end
        local list = {}
        local first = plan.first[page] or 1
        for idx = 1, k do
          local r, cidx = (idx - 1) // cols, (idx - 1) % cols
          list[idx] = { i = first + idx - 1, x = area.x + cidx * (tw + TILE_GAP), y = area.y + r * (th + TILE_GAP),
                        w = tw, h = th }
        end
        plan.tiles[page] = list
        return list
      end

      local function hitList(plan, kind, x, y)
        local a = plan.area
        if x < a.x or x > a.x + a.w or y < a.y or y > a.y + a.h then return nil end
        local tiles = tilesOf(plan, plan.page)
        for idx = 1, #tiles do
          local tl = tiles[idx]
          if x >= tl.x and x <= tl.x + tl.w and y >= tl.y and y <= tl.y + tl.h then
            return { kind = kind, i = tl.i, tile = tl }
          end
        end
        if plan.arrows and y >= a.y + a.h - ARROW_H then
          return { kind = kind, arrow = (x < a.x + a.w / 2) and -1 or 1 }
        end
        return { kind = kind }
      end

      local function hitTest(x, y)
        return hitList(plans.S, "S", x, y) or hitList(plans.D, "D", x, y)
      end

      local function turnPage(kind, dir)
        local plan = plans[kind]
        local p = U.clamp(plan.page + dir, 1, #plan.pages)
        if p == plan.page then return false end
        plan.page = p
        return true
      end

      -- ---------- picking and routing ----------
      local function armTimer()
        if timer then timer:cancel() end
        timer = E.after(PUT_DOWN, function()
          timer = nil
          if picked ~= nil and carry == nil then
            picked = nil
            hintText = idleHint()
            say(hintText)
            E.invalidate()
          end
        end)
      end

      local function putDown()
        if timer then timer:cancel(); timer = nil end
        picked = nil
        hintText = idleHint()
      end

      local function pick(i)
        picked = i
        armTimer()
        hintText = HINT_PICKED
        say(HINT_PICKED)
      end

      local function clampRoute(v)
        v = floor((tonumber(v) or 0) + 0.5)
        if v < 0 then v = 0 elseif v > nS then v = nS end
        return v
      end

      local function writeRoute(j, i)
        routes[j] = i
        E.out("Route", i, j)
        E.out("RouteName", (i > 0) and displayName("S", i) or "", j)
      end

      local function startFlash(j)
        flash = { j = j, at = E.now() }
        E.after(FLASH + 0.05, function() E.invalidate() end)
      end

      local function route(j, i, inferred)
        local prev = routes[j]
        writeRoute(j, i)
        E.pulse("Routed", j)
        startFlash(j)
        say(shortName("S", i) .. " -> " .. shortName("D", j))
        if inferred then
          lastDrop = { i = i, j = j, prev = prev }
        else
          lastDrop = nil
        end
      end

      local function broadcast(i)
        local n = 0
        for j = 1, nD do
          if not (allowCalls and isCallDest(j)) then
            writeRoute(j, i)
            E.pulse("Routed", j)
            n = n + 1
          end
        end
        putDown()
        if n > 0 then
          flash = { j = 0, at = E.now() }
          E.after(FLASH + 0.05, function() E.invalidate() end)
          say(shortName("S", i) .. " -> all screens")
        else
          say(idleHint())
        end
      end

      local function clearAll()
        for j = 1, nD do
          if routes[j] ~= 0 then
            writeRoute(j, 0)
            E.pulse("Routed", j)
          end
        end
        putDown()
        carry, hover = nil, nil
        say(TEXT_CLEARED)
        E.invalidate()
      end

      -- ---------- touch ----------
      function self:onTouchStart(x, y, t)
        touchT0 = t
        lastDrop = nil
        down = hitTest(x, y)
        hover = nil
        carry = nil
        if down and down.kind == "S" and down.i and not tapOnly then
          carry = { i = down.i, x = x, y = y, dragging = false }
        end
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        if carry then
          carry.x, carry.y = x, y
          if not carry.dragging then
            carry.dragging = true
            if timer then timer:cancel(); timer = nil end
            picked = carry.i
            hintText = HINT_CARRY
            say(HINT_CARRY)
          end
          local h = hitTest(x, y)
          hover = (h and h.kind == "D" and h.i) or nil
        end
        E.invalidate()
      end

      function self:onTouchEnd(x, y, t, info)
        local c = carry
        carry, hover, down = nil, nil, nil
        if info and info.aborted then
          if c and c.dragging then putDown() end
          E.invalidate()
          return
        end
        if c and c.dragging then
          local h = hitTest(x, y)
          if h and h.kind == "D" and h.i then
            putDown()
            route(h.i, c.i, info and info.inferred)
          elseif h and h.arrow then
            local prevPage = plans[h.kind].page
            turnPage(h.kind, h.arrow)
            pick(c.i)
            if info and info.inferred then
              lastDrop = { i = c.i, pageKind = h.kind, prevPage = prevPage }
            end
          else
            putDown()
            say(idleHint())
            if info and info.inferred then lastDrop = { i = c.i } end
          end
        end
        E.invalidate()
      end

      -- An inferred lift taken back: the drop (or page turn) is undone and
      -- the source is carried again. A Routed pulse already sent stays sent.
      function self:onTouchResume(x, y, t)
        local d = lastDrop
        lastDrop = nil
        if not d then return end
        if d.j then
          writeRoute(d.j, d.prev)
          flash = nil
        elseif d.pageKind then
          plans[d.pageKind].page = d.prevPage
        end
        if timer then timer:cancel(); timer = nil end
        picked = d.i
        carry = { i = d.i, x = x, y = y, dragging = true }
        local h = hitTest(x, y)
        hover = (h and h.kind == "D" and h.i) or nil
        hintText = HINT_CARRY
        say(HINT_CARRY)
        E.invalidate()
      end

      local function onTap(h, t)
        if not h then lastTap = nil; return end
        if h.kind == "S" and h.i then
          local i = h.i
          if lastTap and lastTap.kind == "S" and lastTap.i == i and (touchT0 - lastTap.t) <= DOUBLE_TIME then
            lastTap = nil
            broadcast(i)
          else
            lastTap = { kind = "S", i = i, t = t }
            if picked == i then
              putDown()
              say(idleHint())
            else
              pick(i)
            end
          end
        elseif h.kind == "D" and h.i then
          lastTap = { kind = "D", i = h.i, t = t }
          if picked then
            route(h.i, picked, false)
            armTimer()
          else
            say(HINT_NO_SOURCE)
          end
        elseif h.arrow then
          lastTap = nil
          turnPage(h.kind, h.arrow)
          if picked then
            armTimer()
            say(HINT_PICKED)
          else
            local plan = plans[h.kind]
            say(((h.kind == "S") and "Sources page " or "Screens page ") .. plan.page .. " of " .. #plan.pages)
          end
        else
          lastTap = nil
        end
        E.invalidate()
      end

      function self:onGesture(g)
        if g.type == "tap" then
          onTap(hitTest(g.x, g.y), g.t)
        elseif g.type == "double" then
          -- The engine's "DOUBLE TAP" text follows the second tap: keep ours.
          if lastText then E.setGesture(lastText) end
        elseif g.type == "swipe" then
          -- A fast drag-drop is also a swipe to the engine: keep the route text.
          if lastText then E.setGesture(lastText) end
          if (g.dir == "left" or g.dir == "right") and down == nil and lastDrop == nil then
            local h = hitTest(g.x, g.y)
            if h and (h.kind == "S" or h.kind == "D") and not (h.kind == "S" and picked ~= nil and not tapOnly) then
              if turnPage(h.kind, (g.dir == "left") and 1 or -1) then E.invalidate() end
            end
          end
        end
      end

      function self:onLock(locked)
        if locked then
          carry, hover, down = nil, nil, nil
          putDown()
        end
        E.invalidate()
      end

      -- ---------- pins ----------
      function self:onControl(name, index, ctl)
        if name == "SourceName" then
          setName("S", index, ctl.String)
        elseif name == "DestName" then
          setName("D", index, ctl.String)
        elseif name == "SourceActive" then
          active[index] = ctl.Boolean and true or false
        elseif name == "Route" then
          local v = clampRoute(ctl.Value)
          if v ~= routes[index] then
            routes[index] = v
            E.out("RouteName", (v > 0) and displayName("S", v) or "", index)
            E.pulse("Routed", index)
          end
        elseif name == "ClearRoutes" then
          local now = E.now()
          if (not ctl.Boolean) and lastClear and (now - lastClear) < 1 then return end
          lastClear = now
          clearAll()
        elseif name == "TapOnly" then
          tapOnly = ctl.Boolean and true or false
          if tapOnly and carry then carry, hover = nil, nil end
          if picked == nil then
            hintText = idleHint()
            say(hintText)
          end
        elseif name == "AllowCalls" then
          allowCalls = ctl.Boolean and true or false
        end
        E.invalidate()
      end

      function self:onStart()
        for i = 1, nS do
          local c = E.ctl("SourceName", i)
          local a = E.ctl("SourceActive", i)
          active[i] = (a == nil) or (a.Boolean and true or false)
          src[i] = tostring((c and c.String) or "")
        end
        for j = 1, nD do
          local c = E.ctl("DestName", j)
          dst[j] = tostring((c and c.String) or "")
          local r = E.ctl("Route", j)
          routes[j] = clampRoute(r and r.Value or 0)
          E.out("RouteName", (routes[j] > 0) and displayName("S", routes[j]) or "", j)
        end
        local to = E.ctl("TapOnly")
        tapOnly = (to ~= nil) and (to.Boolean and true or false) or false
        local ac = E.ctl("AllowCalls")
        allowCalls = (ac == nil) or (ac.Boolean and true or false)
        hintText = idleHint()
        if tapOnly then say(hintText) end
      end

      -- ---------- drawing ----------
      local function sizeFor(h)
        if h >= 64 then return 14 elseif h >= 44 then return 12 end
        return 10
      end

      -- A tile is rendered once per visual state (picked, routed, dimmed,
      -- pressed, hovered, flashing, its sub label) into a scratch canvas and
      -- the string is replayed on later frames: a 64 x 64 page costs a few
      -- lookups per frame instead of a full tile drawing.
      local function tileRaw(c, kind, i, tl, o, label, key)
        local e = tileCache[kind][i]
        if e and e.key == key then return e.raw end
        local s = Svg.new(W, H, { family = c.family, limit = 6000 })
        Shapes.tile(s, T, tl.x, tl.y, tl.w, tl.h, label, o)
        local raw = table.concat(s.parts)
        tileCache[kind][i] = { key = key, raw = raw }
        return raw
      end

      local function drawList(c, plan, kind, now)
        local tiles = tilesOf(plan, plan.page)
        for idx = 1, #tiles do
          local tl = tiles[idx]
          local i = tl.i
          local size = sizeFor(tl.h)
          local iconW = min(24, tl.h * 0.6) + 6
          local maxW = tl.w - 2 * TILE_PAD - iconW
          local o = { size = size, radius = min(8, tl.h / 4), icon = iconOf(kind, i) }
          local key
          if kind == "S" then
            o.picked = (picked == i)
            o.dim = not active[i]
            if down and down.kind == "S" and down.i == i and not o.picked then o.stroke = T.accent end
            key = (o.picked and "p" or "-") .. (o.dim and "d" or "-") .. (o.stroke and "s" or "-")
          else
            local r = routes[i]
            o.on = r > 0
            if r > 0 and tl.h >= 56 then o.sub = fittedLabel("S", r, maxW, 11) end
            if hover == i then o.picked = true end
            if flash and (flash.j == i or (flash.j == 0 and r > 0)) and (now - flash.at) < FLASH then
              o.accent = T.accent2
            end
            key = (o.picked and "h" or "-") .. (o.accent and "f" or "-") .. r .. "|" .. (o.sub or "")
          end
          c:raw(tileRaw(c, kind, i, tl, o, fittedLabel(kind, i, maxW, size), key))
        end
        if plan.arrows then
          local a = plan.area
          Shapes.arrowBar(c, T, a.x, a.y + a.h - ARROW_H, a.w, ARROW_H, plan.page > 1, plan.page < #plan.pages,
            plan.page .. " / " .. #plan.pages)
        end
      end

      function self:draw(c)
        local now = E.now()
        if capH > 0 then
          c:text(areaS.x + 2, areaS.y - 5, "SOURCES", { size = 10, fill = T.muted, weight = "bold", spacing = 1 })
          c:text(areaD.x + 2, areaD.y - 5, "SCREENS", { size = 10, fill = T.muted, weight = "bold", spacing = 1 })
        end
        drawList(c, plans.S, "S", now)
        drawList(c, plans.D, "D", now)
        if carry and carry.dragging then
          local gw = U.clamp(areaS.w * 0.8, 72, 180)
          local gh = 36
          local gx = U.clamp(carry.x - gw / 2, 0, W - gw)
          local gy = U.clamp(carry.y - gh - 12, 0, H - gh)
          local i = carry.i
          local iconW = min(24, gh * 0.6) + 6
          c:group({ opacity = 0.92 }, function(g)
            Shapes.tile(g, T, gx, gy, gw, gh, fittedLabel("S", i, gw - 2 * TILE_PAD - iconW, 12),
              { on = true, icon = iconOf("S", i), size = 12, radius = 8 })
          end)
        end
        if showHint then
          Shapes.hint(c, T, hintText, W, H)
        end
      end

      -- ---------- probes for tests and debugging (no engine use) ----------
      function self:tileCentre(kind, i)
        local plan = plans[kind]
        local tiles = tilesOf(plan, plan.page)
        for idx = 1, #tiles do
          local tl = tiles[idx]
          if tl.i == i then return tl.x + tl.w / 2, tl.y + tl.h / 2, tl.w, tl.h end
        end
        return nil
      end
      function self:arrowCentre(kind, dir)
        local plan = plans[kind]
        if not plan.arrows then return nil end
        local a = plan.area
        return a.x + a.w * ((dir < 0) and 0.25 or 0.75), a.y + a.h - ARROW_H / 2
      end
      function self:pageInfo(kind)
        local plan = plans[kind]
        return plan.page, #plan.pages, table.concat(plan.pages, ",")
      end
      function self:pickedSource() return picked end
      function self:isCarrying() return carry ~= nil and carry.dragging end

      return self
    end,
  }
end
