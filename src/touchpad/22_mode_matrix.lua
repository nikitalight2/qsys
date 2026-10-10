-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: Matrix mode
--
-- A crosspoint grid: sources are the rows, destinations the columns. Tap a
-- crosspoint to toggle it; a drag that starts on a crosspoint paints its new
-- state across every crosspoint it crosses; a tap on a row header sends that
-- source to every column; a tap on a column header clears that column. With
-- ExclusiveColumns on (the default) a column carries one source at a time and
-- Route n (the source number of column n, 0 = none) is kept in sync both
-- ways; with it off a column may carry several sources and Route n shows the
-- source routed last (0 once the column is empty). The grid shows at most 12
-- rows and 12 columns at a time, fewer on a pad too small for 4 px cells:
-- larger matrices page with arrow bars under the row headers (row pages) and
-- under the cells (column pages); a swipe that starts on a header or an arrow
-- bar turns the pages too. A tap acts on the cell or header that was pressed
-- (and drawn pressed), not on whatever lies under the lift. Pin writes go
-- through a queue: a handler writes at most SYNC_WRITES pins itself and the
-- rest follow ASYNC_WRITES per engine turn, so a row select, a Clear All or
-- the start-up scan of a 64 x 64 matrix never nears the budget.
--
-- Pins (spec 3.12): SourceName n, DestName n (in), Cross n (both, index =
-- (row - 1) * columns + column), Route n (both, per column), ExclusiveColumns
-- (in, default on), ClearAll (in).

Modes = Modes or {}

do
  local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs

  local HINT = "Tap a crosspoint, drag to paint"
  local TEXT_CLEARED = "All cleared"
  local MAX_PAGE = 12                    -- rows and columns per page at most
  local MIN_CELL = 4                     -- the page size shrinks before a cell gets smaller
  local ARROW_H = 28
  local CELL_GAP = 3
  local MAX_CELL_W, MAX_CELL_H = 180, 120
  local ROTATE_BELOW = 60                -- column labels turn vertical under this cell width
  local PAINT_START = 12                 -- pad px of movement before a drag paints
  local NAME_IN_TEXT = 40                -- characters of a name used in the Gesture text
  local SYNC_WRITES = 64                 -- pin writes done inside the handler itself (a full column set)
  local ASYNC_WRITES = 128               -- pin writes per follow-up engine turn
  local SCAN_FIRST, SCAN_CHUNK = 64, 512  -- Cross pins read in the load, then per turn
  local ENFORCE_COLS = 4                 -- columns checked per turn when Exclusive turns on
  local CHUNK_DELAY = 0.02
  local COLD_PER_FRAME = 8               -- headers rendered from scratch in one frame
  local WARM_DELAY = 0.03

  local function countOf(props, name, default)
    local p = props and props[name]
    if type(p) == "table" then p = p.Value end
    local v = tonumber(p) or default
    v = floor(v + 0.5)
    if v < 1 then v = 1 elseif v > 64 then v = 64 end
    return v
  end

  -- Rows of "n" and a name box, filled column by column; returns the y below.
  local function nameRows(L, base, n, x, y, w, cols)
    local G = L.G
    local colW = floor((w - (cols - 1) * G) / cols)
    local rows = ceil(n / cols)
    for i = 1, n do
      local col, row = (i - 1) // rows, (i - 1) % rows
      local cx, cy = x + col * (colW + G), y + row * 32
      L.caption(tostring(i), { cx, cy + 7 }, { 24, 10 }, "Right")
      L.text(L.key(base, i), { cx + 28, cy + 2 }, { colW - 28, 22 })
    end
    return y + rows * 32
  end

  Modes["Matrix"] = {
    id = "matrix",
    pretty = "Matrix",
    hint = HINT,

    controls = function(C, props)
      local nS = countOf(props, "Sources", 4)
      local nD = countOf(props, "Destinations", 2)
      C.add{ Name = "SourceName", ControlType = "Text", Count = nS, PinStyle = "Input", Group = "Sources" }
      C.add{ Name = "DestName", ControlType = "Text", Count = nD, PinStyle = "Input", Group = "Routing" }
      C.add{ Name = "Cross", ControlType = "Button", ButtonType = "Toggle", Count = nS * nD,
             PinStyle = "Both", Group = "Matrix" }
      C.add{ Name = "Route", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = nS, DefaultValue = 0,
             Count = nD, PinStyle = "Both", Group = "Routing" }
      C.add{ Name = "ExclusiveColumns", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Input",
             Group = "Routing", DefaultValue = true }
      C.add{ Name = "ClearAll", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Input", Group = "Routing" }
    end,

    -- Names (or Sources / Destinations above 16) hold the name boxes; the Pad
    -- page gets the two routing buttons on the side; Setup explains them.
    layout = function(L, page, props, ctx)
      local nS = countOf(props, "Sources", 4)
      local nD = countOf(props, "Destinations", 2)
      if page == "Pad" then
        L.padDisplay(ctx)
        L.gesture(ctx)
        L.hint(ctx, HINT)
        L.sideCaption(ctx, "MATRIX")
        L.sideButton(ctx, "ClearAll", "CLEAR ALL")
        L.sideButton(ctx, "ExclusiveColumns", "EXCLUSIVE COLUMNS")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "M A T R I X", 86)
        L.toggle("ExclusiveColumns", "EXCLUSIVE COLUMNS", { ix, iy }, { 140, 24 })
        L.trigger("ClearAll", "CLEAR ALL", { ix + 148, iy }, { 100, 24 })
        L.label(string.format("%d sources (rows) x %d destinations (columns). Cross n is the crosspoint\n(row - 1) x %d + column. Exclusive Columns: one source per column, Route n\nin sync both ways. Tap a row header: source to every column; a column\nheader clears the column. Pages above 12 x 12.", nS, nD, nD),
                { ix, iy + 30 }, { iw, 56 })
      elseif page == "Names" then
        local rowsS = ceil(nS / 2)
        local ix, iy, iw = L.section(ctx, "S O U R C E S  ( R O W S )", rowsS * 32)
        nameRows(L, "SourceName", nS, ix, iy, iw, 2)
        local rowsD = ceil(nD / 2)
        ix, iy, iw = L.section(ctx, "D E S T I N A T I O N S  ( C O L U M N S )", rowsD * 32)
        nameRows(L, "DestName", nD, ix, iy, iw, 2)
      elseif page == "Sources" then
        local rows = ceil(nS / 3)
        local ix, iy, iw = L.section(ctx, "S O U R C E  N A M E S  ( R O W S )", rows * 32)
        nameRows(L, "SourceName", nS, ix, iy, iw, 3)
      elseif page == "Destinations" then
        local rows = ceil(nD / 3)
        local ix, iy, iw = L.section(ctx, "D E S T I N A T I O N  N A M E S  ( C O L U M N S )", rows * 32)
        nameRows(L, "DestName", nD, ix, iy, iw, 3)
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
      local nCross = nS * nD

      -- ---------- state ----------
      local cross = {}                 -- cross[idx] = true while on
      local colCount = {}              -- on cells per column
      local route = {}                 -- route[c] = source row or 0
      local exclusive = true
      local src, dst = {}, {}          -- raw names ("" = unnamed)
      local nameRev = { S = {}, D = {} }
      local fit = { S = {}, D = {} }   -- fitted labels per name, width and size
      local down = nil                 -- hit at touch start { kind, r, c, idx, x, y }
      local tapHit = nil               -- the hit of the last touch start, for the tap gesture
      local painting = false
      local paintOn = false
      local painted = 0                -- cells this stroke changed that still hold the painted state
      local paintSet = {}              -- paintSet[idx] = true for those cells
      local lastPaintIdx = nil
      local resumable = nil            -- paint state kept across an inferred lift
      local lastClear = nil
      local lastText = nil
      local lastDownKind = nil         -- what the last touch started on (for swipes)
      local pend, pendN, pendHead = {}, 0, 1   -- write queue: idx > 0 = Cross idx, < 0 = Route column
      local pendTimer = nil
      local staleList = {}             -- tables of on cells whose pins Clear All still has to write
      local staleKey = nil
      local staleFrom, staleTo = nil, nil   -- Cross pins a Clear All during the scan never read: written false
      local scanPos = nil              -- next Cross pin the start-up scan reads
      local scanTimer = nil
      local scanSkip = {}              -- columns cleared during the scan: their unread pins go false
      local enforcePos = nil           -- next column the Exclusive enforcement checks
      local enforceTimer = nil
      local self = {}

      for c = 1, nD do colCount[c] = 0; route[c] = 0 end

      local function idxOf(r, c) return (r - 1) * nD + c end
      local function rowOf(idx) return (idx - 1) // nD + 1 end
      local function colOf(idx) return (idx - 1) % nD + 1 end

      -- ---------- names ----------
      local function rawName(kind, i)
        local list = (kind == "S") and src or dst
        local s = list[i]
        if s == nil then
          local ctl = E.ctl((kind == "S") and "SourceName" or "DestName", i)
          s = tostring((ctl and ctl.String) or "")
          list[i] = s
        end
        return s
      end

      local function displayName(kind, i)
        local s = rawName(kind, i)
        if s ~= "" then return s end
        return ((kind == "S") and "Source " or "Dest ") .. i
      end

      local function shortName(kind, i)
        return U.truncateChars(displayName(kind, i), NAME_IN_TEXT)
      end

      local hdrCache = { S = {}, D = {} }
      local function setName(kind, i, s)
        s = tostring(s or "")
        nameRev[kind][i] = (nameRev[kind][i] or 0) + 1
        if kind == "S" then src[i] = s else dst[i] = s end
        fit[kind][i] = nil
        hdrCache[kind][i] = nil
      end

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

      local function say(text)
        lastText = text
        E.setGesture(text)
      end

      -- ---------- the pin write queue ----------
      -- State changes at once; the pins follow from the queue. flush(limit)
      -- writes up to `limit` pins (the current state at that moment) and arms
      -- a timer for the rest. Clear All leaves its old state table behind and
      -- the queue drains it too, writing false where a cell is still off.
      local flush

      local function armFlush()
        if not pendTimer then
          pendTimer = E.after(CHUNK_DELAY, function()
            pendTimer = nil
            flush(ASYNC_WRITES)
          end)
        end
      end

      flush = function(limit)
        local n = 0
        while pendHead <= pendN and n < limit do
          local e = pend[pendHead]
          pend[pendHead] = nil
          pendHead = pendHead + 1
          if e > 0 then
            E.out("Cross", cross[e] == true, e)
          else
            E.out("Route", route[-e], -e)
          end
          n = n + 1
        end
        if pendHead > pendN then pend, pendN, pendHead = {}, 0, 1 end
        while n < limit and staleList[1] do
          local stale = staleList[1]
          local k = staleKey
          while n < limit do
            k = next(stale, k)
            if k == nil then break end
            if not cross[k] then E.out("Cross", false, k) end
            n = n + 1
          end
          staleKey = k
          if k == nil then table.remove(staleList, 1) end
        end
        while n < limit and staleFrom do
          if not cross[staleFrom] then E.out("Cross", false, staleFrom) end
          n = n + 1
          staleFrom = staleFrom + 1
          if staleFrom > staleTo then staleFrom, staleTo = nil, nil end
        end
        if pendHead <= pendN or staleList[1] or staleFrom then armFlush() end
      end

      local function queue(e)
        pendN = pendN + 1
        pend[pendN] = e
      end

      -- ---------- crosspoints and routes ----------
      local function setCross(idx, on)
        local was = cross[idx] == true
        if was == on then return false end
        cross[idx] = on or nil
        queue(idx)
        return true
      end

      local function setRoute(c, r)
        if route[c] == r then return end
        route[c] = r
        queue(-c)
      end

      -- lowest on row of a column (bounded by the row count)
      local function lowestOn(c)
        for r = 1, nS do
          if cross[idxOf(r, c)] then return r end
        end
        return 0
      end

      -- Routing a source that is already on routes it "last": Route follows
      -- (a no-op with Exclusive on, where the on cell is the route already).
      local function turnOn(r, c)
        local idx = idxOf(r, c)
        if cross[idx] then
          setRoute(c, r)
          return false
        end
        if exclusive then
          local prev = route[c]
          if prev > 0 and prev ~= r and cross[idxOf(prev, c)] then
            setCross(idxOf(prev, c), false)
            colCount[c] = colCount[c] - 1
          end
        end
        setCross(idx, true)
        colCount[c] = colCount[c] + 1
        setRoute(c, r)
        return true
      end

      local function turnOff(r, c)
        local idx = idxOf(r, c)
        if not cross[idx] then return false end
        setCross(idx, false)
        colCount[c] = max(0, colCount[c] - 1)
        if route[c] == r then
          setRoute(c, (colCount[c] > 0) and lowestOn(c) or 0)
        end
        return true
      end

      local function toggle(r, c)
        if cross[idxOf(r, c)] then
          turnOff(r, c)
          return false
        end
        turnOn(r, c)
        return true
      end

      local function selectRow(r)
        for c = 1, nD do turnOn(r, c) end
      end

      local function clearCol(c)
        for r = 1, nS do
          local idx = idxOf(r, c)
          if cross[idx] then setCross(idx, false) end
        end
        colCount[c] = 0
        setRoute(c, 0)
        if scanPos then scanSkip[c] = true end
      end

      -- Clear All drops the state at once; the old table joins the queue's
      -- stale list so its pins are written false over the following turns.
      local function clearAll()
        if next(cross) ~= nil then staleList[#staleList + 1] = cross end
        cross = {}
        if scanPos then
          -- the start-up scan ends here: the pins it has not read are written
          -- false from the queue instead of being adopted as state
          if scanTimer then scanTimer:cancel(); scanTimer = nil end
          if not staleFrom or scanPos < staleFrom then staleFrom = scanPos end
          staleTo = nCross
          scanPos = nil
        end
        for c = 1, nD do
          colCount[c] = 0
          setRoute(c, 0)
        end
        down, painting, resumable = nil, false, nil
        say(TEXT_CLEARED)
        E.invalidate()
      end

      -- Exclusive switched on with several sources in a column: the routed
      -- one stays, the others go. ENFORCE_COLS columns per turn.
      local function enforceStep()
        enforceTimer = nil
        if not enforcePos or not exclusive then enforcePos = nil; return end
        local last = min(nD, enforcePos + ENFORCE_COLS - 1)
        for c = enforcePos, last do
          if colCount[c] > 1 then
            local keep = route[c]
            if keep == 0 or not cross[idxOf(keep, c)] then keep = lowestOn(c) end
            for r = 1, nS do
              if r ~= keep then
                local idx = idxOf(r, c)
                if cross[idx] then setCross(idx, false) end
              end
            end
            colCount[c] = 1
            setRoute(c, keep)
          end
        end
        enforcePos = last + 1
        if enforcePos > nD then
          enforcePos = nil
          E.invalidate()
        else
          enforceTimer = E.after(CHUNK_DELAY, enforceStep)
        end
        flush(SYNC_WRITES)
      end

      local function enforceExclusive()
        if enforceTimer then enforceTimer:cancel(); enforceTimer = nil end
        enforcePos = 1
        enforceStep()
      end

      -- ---------- geometry constants ----------
      local showHint = E.hint and true or false
      local margin = U.clamp(floor(min(W, H) * 0.03), 6, 14)
      local hintH = showHint and 16 or 0
      local rowHdrW = U.clamp(floor(W * 0.22), 44, 140)
      local gx0 = margin + rowHdrW + CELL_GAP            -- left edge of the cells
      local cellsW0 = W - margin - gx0                   -- width available to the cells

      local function hdrHeight(rotated)
        if rotated then return U.clamp(floor(H * 0.2), 24, 96) end
        return U.clamp(floor(H * 0.1), 24, 40)
      end

      -- ---------- paging ----------
      -- At most MAX_PAGE rows and columns per page, fewer when the pad cannot
      -- hold that many cells of MIN_CELL px: the columns per page follow the
      -- width; the rows per page follow the height under the column headers
      -- (whose height depends on the widest page's cell width) and above the
      -- arrow bar once either axis pages.
      local function perPage(space)
        return U.clamp(floor((space + CELL_GAP) / (MIN_CELL + CELL_GAP)), 1, MAX_PAGE)
      end
      local function rowsFit(colsN, withArrows)
        local cellW = min(MAX_CELL_W, (cellsW0 - (colsN - 1) * CELL_GAP) / colsN)
        local gy = margin + hdrHeight(cellW < ROTATE_BELOW) + CELL_GAP
        local bottom = H - margin - hintH
        local cellsH = (withArrows and (bottom - ARROW_H - CELL_GAP) or bottom) - gy
        return perPage(cellsH)
      end
      local colPages = U.evenPages(nD, perPage(cellsW0))
      if #colPages == 0 then colPages = { nD } end
      local perRows = rowsFit(colPages[1], #colPages > 1)
      if #colPages == 1 and nS > perRows then perRows = rowsFit(colPages[1], true) end
      local rowPages = U.evenPages(nS, perRows)
      if #rowPages == 0 then rowPages = { nS } end
      local rowFirst, colFirst = {}, {}
      do
        local acc = 1
        for p = 1, #rowPages do rowFirst[p] = acc; acc = acc + rowPages[p] end
        acc = 1
        for p = 1, #colPages do colFirst[p] = acc; acc = acc + colPages[p] end
      end
      local rowPage, colPage = 1, 1
      local paged = (#rowPages > 1) or (#colPages > 1)

      local function turnRowPage(dir)
        local p = U.clamp(rowPage + dir, 1, #rowPages)
        if p == rowPage then return false end
        rowPage = p
        return true
      end
      local function turnColPage(dir)
        local p = U.clamp(colPage + dir, 1, #colPages)
        if p == colPage then return false end
        colPage = p
        return true
      end

      -- ---------- geometry (cached per page shape) ----------
      local arrowH = paged and ARROW_H or 0
      local geoms = {}

      local function geom()
        local rowsN, colsN = rowPages[rowPage], colPages[colPage]
        local key = rowsN * 100 + colsN
        local g = geoms[key]
        if g then return g end
        local gx = gx0
        local cellW = min(MAX_CELL_W, (cellsW0 - (colsN - 1) * CELL_GAP) / colsN)
        local rotated = cellW < ROTATE_BELOW
        local colHdrH = hdrHeight(rotated)
        local gy = margin + colHdrH + CELL_GAP
        local bottom = H - margin - hintH
        local ay = bottom - arrowH
        local cellsH = ((arrowH > 0) and (ay - CELL_GAP) or bottom) - gy
        local cellH = min(MAX_CELL_H, (cellsH - (rowsN - 1) * CELL_GAP) / rowsN)
        if cellW < 4 then cellW = 4 end
        if cellH < 4 then cellH = 4 end
        g = { rowsN = rowsN, colsN = colsN, gx = gx, gy = gy, cellW = cellW, cellH = cellH,
              gridW = colsN * cellW + (colsN - 1) * CELL_GAP, gridH = rowsN * cellH + (rowsN - 1) * CELL_GAP,
              colHdrH = colHdrH, rotated = rotated, ay = ay,
              radius = min(6, floor(min(cellW, cellH) / 5)), xy = {} }
        -- the x / y attributes of every cell position, built once
        local pre = '<rect width="' .. Svg.num(cellW - 1) .. '" height="' .. Svg.num(cellH - 1) ..
                    '" rx="' .. Svg.num(g.radius) .. '"'
        g.offPre = pre .. ' fill="' .. T.well .. '" stroke="' .. T.line .. '" stroke-width="1"'
        g.onPre = pre .. ' fill="' .. T.accent .. '" stroke="' .. T.accent .. '" stroke-width="1"'
        for ri = 1, rowsN do
          local y = Svg.num(gy + (ri - 1) * (cellH + CELL_GAP) + 0.5)
          for ci = 1, colsN do
            g.xy[(ri - 1) * colsN + ci] = ' x="' .. Svg.num(gx + (ci - 1) * (cellW + CELL_GAP) + 0.5) ..
                                          '" y="' .. y .. '"/>'
          end
        end
        geoms[key] = g
        return g
      end

      local function cellRect(g, ri, ci)
        return g.gx + (ci - 1) * (g.cellW + CELL_GAP), g.gy + (ri - 1) * (g.cellH + CELL_GAP), g.cellW, g.cellH
      end

      -- Hit: { kind = "cell", r, c, idx } | { kind = "row", r } | { kind = "col", c }
      -- | { kind = "rowArrow"|"colArrow", dir } | nil
      local function hitTest(x, y)
        local g = geom()
        if arrowH > 0 and y >= g.ay and y <= g.ay + arrowH then
          if x >= margin and x < g.gx and #rowPages > 1 then
            return { kind = "rowArrow", dir = (x < margin + rowHdrW / 2) and -1 or 1 }
          elseif x >= g.gx and x <= g.gx + g.gridW and #colPages > 1 then
            return { kind = "colArrow", dir = (x < g.gx + g.gridW / 2) and -1 or 1 }
          end
          return nil
        end
        local ci, ri = nil, nil
        if x >= g.gx and x < g.gx + g.gridW + CELL_GAP then
          ci = floor((x - g.gx) / (g.cellW + CELL_GAP)) + 1
          if ci < 1 or ci > g.colsN then ci = nil end
        end
        if y >= g.gy and y < g.gy + g.gridH + CELL_GAP then
          ri = floor((y - g.gy) / (g.cellH + CELL_GAP)) + 1
          if ri < 1 or ri > g.rowsN then ri = nil end
        end
        if ri and ci then
          local r, c = rowFirst[rowPage] + ri - 1, colFirst[colPage] + ci - 1
          return { kind = "cell", r = r, c = c, idx = idxOf(r, c), ri = ri, ci = ci }
        elseif ri and x >= margin and x < g.gx then
          return { kind = "row", r = rowFirst[rowPage] + ri - 1, ri = ri }
        elseif ci and y >= margin and y < g.gy then
          return { kind = "col", c = colFirst[colPage] + ci - 1, ci = ci }
        end
        return nil
      end

      -- ---------- touch ----------
      local function paintCell(h)
        if h.idx == lastPaintIdx then return end
        lastPaintIdx = h.idx
        if paintOn then
          -- with Exclusive on, this cell may switch a cell of the same stroke off
          local prev = exclusive and route[h.c] or 0
          local prevIdx = (prev > 0) and idxOf(prev, h.c) or nil
          if turnOn(h.r, h.c) then
            painted = painted + 1
            paintSet[h.idx] = true
            if prevIdx and paintSet[prevIdx] and not cross[prevIdx] then
              paintSet[prevIdx] = nil
              painted = painted - 1
            end
          end
        elseif turnOff(h.r, h.c) then
          painted = painted + 1
          paintSet[h.idx] = true
        end
      end

      function self:onTouchStart(x, y, t)
        resumable = nil
        down = hitTest(x, y)
        tapHit = down
        lastDownKind = down and down.kind or nil
        if down then down.x, down.y = x, y end
        painting, painted, paintSet, lastPaintIdx = false, 0, {}, nil
        E.invalidate()
      end

      function self:onTouchMove(x, y, t, dx, dy)
        if down and down.kind == "cell" then
          if not painting and U.dist(down.x, down.y, x, y) >= PAINT_START then
            painting = true
            paintOn = not cross[down.idx]
            paintCell(down)
          end
          if painting then
            local h = hitTest(x, y)
            if h and h.kind == "cell" then paintCell(h) end
          end
          flush(SYNC_WRITES)
        end
        E.invalidate()
      end

      function self:onTouchEnd(x, y, t, info)
        if painting then
          if info and info.inferred and not info.aborted then
            resumable = { paintOn = paintOn, painted = painted, paintSet = paintSet, lastPaintIdx = lastPaintIdx }
          end
          local n = painted
          say((paintOn and "Set " or "Cleared ") .. n .. ((n == 1) and " crosspoint" or " crosspoints"))
        end
        down, painting = nil, false
        E.invalidate()
      end

      -- An inferred lift taken back: the paint continues where it stopped.
      function self:onTouchResume(x, y, t)
        local r = resumable
        resumable = nil
        if not r then return end
        painting, paintOn, painted, paintSet, lastPaintIdx = true, r.paintOn, r.painted, r.paintSet, r.lastPaintIdx
        down = { kind = "cell", x = x, y = y }
        local h = hitTest(x, y)
        if h and h.kind == "cell" then paintCell(h) end
        flush(SYNC_WRITES)
        E.invalidate()
      end

      local function onTap(h)
        if not h then return end
        if h.kind == "cell" then
          if toggle(h.r, h.c) then
            say(shortName("S", h.r) .. " -> " .. shortName("D", h.c))
          else
            say(shortName("S", h.r) .. " -> " .. shortName("D", h.c) .. " off")
          end
        elseif h.kind == "row" then
          selectRow(h.r)
          say(shortName("S", h.r) .. " -> all")
        elseif h.kind == "col" then
          clearCol(h.c)
          say(shortName("D", h.c) .. " cleared")
        elseif h.kind == "rowArrow" then
          turnRowPage(h.dir)
          say("Rows page " .. rowPage .. " of " .. #rowPages)
        elseif h.kind == "colArrow" then
          turnColPage(h.dir)
          say("Columns page " .. colPage .. " of " .. #colPages)
        end
        flush(SYNC_WRITES)
        E.invalidate()
      end

      function self:onGesture(g)
        if g.type == "tap" then
          -- the hit pressed (and drawn pressed) at touch start, not the lift spot
          local h = tapHit or hitTest(g.x, g.y)
          tapHit = nil
          onTap(h)
        elseif g.type == "double" then
          -- the engine's "DOUBLE TAP" text follows the second tap: keep ours
          if lastText then E.setGesture(lastText) end
        elseif g.type == "swipe" then
          -- a swipe over the crosspoints is a paint (or a stroke on them),
          -- never a page turn; headers, arrows and empty space turn pages
          if lastDownKind == "cell" then
            if lastText then E.setGesture(lastText) end
            return
          end
          local turned = false
          if g.dir == "left" then turned = turnColPage(1)
          elseif g.dir == "right" then turned = turnColPage(-1)
          elseif g.dir == "up" then turned = turnRowPage(1)
          elseif g.dir == "down" then turned = turnRowPage(-1) end
          if turned then
            if g.dir == "left" or g.dir == "right" then
              say("Columns page " .. colPage .. " of " .. #colPages)
            else
              say("Rows page " .. rowPage .. " of " .. #rowPages)
            end
            E.invalidate()
          end
        end
      end

      function self:onLock(locked)
        if locked then down, painting, resumable = nil, false, nil end
        E.invalidate()
      end

      -- ---------- pins ----------
      local function clampRoute(v)
        v = floor((tonumber(v) or 0) + 0.5)
        if v < 0 then v = 0 elseif v > nS then v = nS end
        return v
      end

      function self:onControl(name, index, ctl)
        if name == "SourceName" then
          setName("S", index, ctl.String)
        elseif name == "DestName" then
          setName("D", index, ctl.String)
        elseif name == "Cross" then
          if index >= 1 and index <= nCross then
            local r, c = rowOf(index), colOf(index)
            if ctl.Boolean then turnOn(r, c) else turnOff(r, c) end
          end
        elseif name == "Route" then
          local v = clampRoute(ctl.Value)
          if v ~= route[index] then
            if v == 0 then
              clearCol(index)
            else
              turnOn(v, index)
            end
          end
        elseif name == "ExclusiveColumns" then
          exclusive = ctl.Boolean and true or false
          if exclusive then
            enforceExclusive()
          else
            -- an enforcement still running column by column stops here
            if enforceTimer then enforceTimer:cancel(); enforceTimer = nil end
            enforcePos = nil
          end
        elseif name == "ClearAll" then
          local now = E.now()
          if (not ctl.Boolean) and lastClear and (now - lastClear) < 1 then return end
          lastClear = now
          clearAll()
        end
        flush(SYNC_WRITES)
        E.invalidate()
      end

      -- Start: the Cross pins define the state; a column without any on cell
      -- follows its Route pin. The first SCAN_FIRST pins are read in the
      -- load, the rest SCAN_CHUNK per engine turn (a 64 x 64 matrix has 4096
      -- pins); the Route pins are settled once the scan is complete.
      local function scanDone()
        for c = 1, nD do
          local rc = E.ctl("Route", c)
          local want = clampRoute(rc and rc.Value or 0)
          if colCount[c] == 0 and want > 0 then
            turnOn(want, c)
          else
            queue(-c)
          end
        end
        flush(SYNC_WRITES)
        E.invalidate()
      end

      local function scanStep(limit)
        scanTimer = nil
        if not scanPos then return end
        local last = min(nCross, scanPos + limit - 1)
        for idx = scanPos, last do
          local ctl = E.ctl("Cross", idx)
          if ctl and ctl.Boolean then
            local c = colOf(idx)
            if scanSkip[c] or (exclusive and colCount[c] > 0) then
              queue(idx)                       -- a cleared column, or a second source in it: off
            elseif not cross[idx] then
              cross[idx] = true
              colCount[c] = colCount[c] + 1
              if route[c] == 0 then route[c] = rowOf(idx) end
            end
          end
        end
        scanPos = last + 1
        if scanPos > nCross then
          scanPos = nil
          scanSkip = {}
          scanDone()
        else
          flush(SYNC_WRITES)
          scanTimer = E.after(CHUNK_DELAY, function() scanStep(SCAN_CHUNK) end)
        end
      end

      function self:onStart()
        local ex = E.ctl("ExclusiveColumns")
        exclusive = (ex == nil) or (ex.Boolean and true or false)
        scanPos = 1
        scanStep(SCAN_FIRST)
      end

      -- ---------- drawing ----------
      local coldLeft, needWarm, warmTimer = 0, false, nil

      local function sizeFor(h)
        if h >= 40 then return 13 elseif h >= 28 then return 11 end
        return 9
      end

      -- A header is rendered once per (position, name, state) into a scratch
      -- canvas; at most COLD_PER_FRAME from scratch per frame, the rest are
      -- plain boxes until a follow-up frame WARM_DELAY later.
      local function headerRaw(c, kind, i, x, y, w, h, pressed)
        local key = floor(x) .. ":" .. floor(y) .. ":" .. floor(w) .. ":" .. floor(h) .. ":" ..
                    (pressed and "p" or "-") .. ":" .. (nameRev[kind][i] or 0)
        local e = hdrCache[kind][i]
        if e and e.key == key then return e.raw end
        local s = Svg.new(W, H, { family = c.family, limit = 4000 })
        local radius = min(8, h / 4, w / 4)
        s:rect(x + 0.5, y + 0.5, w - 1, h - 1,
          { fill = T.panel, stroke = pressed and T.accent or T.line, sw = pressed and 2 or 1, rx = radius })
        if coldLeft <= 0 then
          needWarm = true
          return table.concat(s.parts)
        end
        coldLeft = coldLeft - 1
        local g = geom()
        if kind == "D" and g.rotated then
          local size = sizeFor(w)
          local label = fittedLabel(kind, i, h - 10, size)
          s:group({ transform = "translate(" .. Svg.num(x + w / 2 + size * 0.35) .. " " .. Svg.num(y + h - 5) .. ") rotate(-90)" },
            function(gg)
              gg:text(0, 0, label, { size = size, fill = T.text })
            end)
        else
          local size = sizeFor(h)
          local label = fittedLabel(kind, i, w - 10, size)
          s:text(x + w / 2, y + h / 2 + size * 0.35, label, { size = size, fill = T.text, anchor = "middle" })
        end
        local raw = table.concat(s.parts)
        hdrCache[kind][i] = { key = key, raw = raw }
        return raw
      end

      function self:draw(c)
        local g = geom()
        coldLeft, needWarm = COLD_PER_FRAME, false
        local r0, c0 = rowFirst[rowPage], colFirst[colPage]
        -- column headers
        for ci = 1, g.colsN do
          local x = g.gx + (ci - 1) * (g.cellW + CELL_GAP)
          local pressed = down ~= nil and down.kind == "col" and down.c == c0 + ci - 1
          c:raw(headerRaw(c, "D", c0 + ci - 1, x, margin, g.cellW, g.colHdrH, pressed))
        end
        -- row headers
        for ri = 1, g.rowsN do
          local y = g.gy + (ri - 1) * (g.cellH + CELL_GAP)
          local pressed = down ~= nil and down.kind == "row" and down.r == r0 + ri - 1
          c:raw(headerRaw(c, "S", r0 + ri - 1, margin, y, rowHdrW, g.cellH, pressed))
        end
        -- cells: one cached position string per cell, prefixed by its state
        local parts, n = {}, 0
        local xy, onPre, offPre = g.xy, g.onPre, g.offPre
        for ri = 1, g.rowsN do
          local base = (r0 + ri - 2) * nD + c0 - 1
          local pbase = (ri - 1) * g.colsN
          for ci = 1, g.colsN do
            n = n + 1
            parts[n] = (cross[base + ci] and onPre or offPre) .. xy[pbase + ci]
          end
        end
        c:raw(table.concat(parts))
        -- the pressed crosspoint
        if down and down.kind == "cell" and down.ri and not painting then
          local x, y, w, h = cellRect(g, down.ri, down.ci)
          c:rect(x + 1, y + 1, w - 2, h - 2, { fill = "none", stroke = T.accent2, sw = 2, rx = g.radius })
        end
        -- arrows
        if arrowH > 0 then
          if #rowPages > 1 then
            Shapes.arrowBar(c, T, margin, g.ay, rowHdrW, arrowH, rowPage > 1, rowPage < #rowPages,
              rowPage .. " / " .. #rowPages)
          end
          if #colPages > 1 then
            Shapes.arrowBar(c, T, g.gx, g.ay, g.gridW, arrowH, colPage > 1, colPage < #colPages,
              colPage .. " / " .. #colPages)
          end
        end
        if needWarm and not warmTimer then
          warmTimer = E.after(WARM_DELAY, function()
            warmTimer = nil
            E.invalidate()
          end)
        end
        if showHint then
          Shapes.hint(c, T, HINT, W, H)
        end
      end

      -- ---------- probes for tests and debugging (no engine use) ----------
      function self:cellCentre(r, c)
        local g = geom()
        local ri, ci = r - rowFirst[rowPage] + 1, c - colFirst[colPage] + 1
        if ri < 1 or ri > g.rowsN or ci < 1 or ci > g.colsN then return nil end
        local x, y, w, h = cellRect(g, ri, ci)
        return x + w / 2, y + h / 2, w, h
      end
      function self:rowHeaderCentre(r)
        local g = geom()
        local ri = r - rowFirst[rowPage] + 1
        if ri < 1 or ri > g.rowsN then return nil end
        local _, y, _, h = cellRect(g, ri, 1)
        return margin + rowHdrW / 2, y + h / 2
      end
      function self:colHeaderCentre(c)
        local g = geom()
        local ci = c - colFirst[colPage] + 1
        if ci < 1 or ci > g.colsN then return nil end
        local x, _, w = cellRect(g, 1, ci)
        return x + w / 2, margin + g.colHdrH / 2
      end
      function self:arrowCentre(kind, dir)
        local g = geom()
        if arrowH == 0 then return nil end
        if kind == "R" then
          if #rowPages < 2 then return nil end
          return margin + rowHdrW * ((dir < 0) and 0.25 or 0.75), g.ay + arrowH / 2
        end
        if #colPages < 2 then return nil end
        return g.gx + g.gridW * ((dir < 0) and 0.25 or 0.75), g.ay + arrowH / 2
      end
      function self:pageInfo(kind)
        if kind == "R" then return rowPage, #rowPages, table.concat(rowPages, ",") end
        return colPage, #colPages, table.concat(colPages, ",")
      end
      function self:isOn(r, c) return cross[idxOf(r, c)] == true end
      function self:routeOf(c) return route[c] end
      function self:isPainting() return painting end
      function self:pendingWrites() return (pendN - pendHead + 1) + #staleList + (staleFrom and 1 or 0) end
      function self:scanning() return scanPos ~= nil end

      return self
    end,
  }
end
