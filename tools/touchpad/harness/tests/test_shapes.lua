-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: unit tests for 08_shapes.lua (Shapes)

local T0 = THEMES["Nikita"]

local function isAscii(s)
  return not string.find(s, "[\128-\255]")
end

-- tags balance and nest properly
local function balanced(svg)
  local stack = {}
  for close, name, body in string.gmatch(svg, "<(/?)([%w]+)([^>]*)>") do
    if close == "/" then
      if stack[#stack] ~= name then return false, "unexpected </" .. name .. ">" end
      stack[#stack] = nil
    elseif string.sub(body, -1) ~= "/" then
      stack[#stack + 1] = name
    end
  end
  if #stack > 0 then return false, "unclosed <" .. stack[#stack] .. ">" end
  return true
end

local function count(s, needle)
  local n, pos = 0, 1
  while true do
    local a, b = string.find(s, needle, pos, true)
    if not a then return n end
    n = n + 1
    pos = b + 1
  end
end

local function has(s, needle)
  return string.find(s, needle, 1, true) ~= nil
end

local SPEC_ICONS = {
  "laptop", "pc", "teams", "zoom", "webex", "camera", "doccam", "appletv", "clickshare", "mic",
  "music", "display", "projector", "room", "person", "lock", "unlock", "home", "up", "down", "left",
  "right", "chevronLeft", "chevronRight", "plus", "minus", "cross", "check", "undo", "eraser", "pen",
  "bookmark", "grid", "signal", "phone", "hdmi", "wireless",
}

-- ---------- icons ----------

function test_icon_every_name()
  for _, name in ipairs(SPEC_ICONS) do
    T.ok(Shapes.ICONS[name] ~= nil, "icon defined: " .. name)
    local c = Svg.new(64, 64)
    local before = c:len()
    Shapes.icon(c, name, 32, 32, 32, "#A79FB3")
    local used = c:len() - before
    T.ok(used > 0, "non-empty element: " .. name)
    T.ok(used < 400, "under 400 chars: " .. name .. " (" .. used .. ")")
    local svg = c:finish()
    T.ok(isAscii(svg), "ascii: " .. name)
    T.ok(balanced(svg), "balanced: " .. name)
    T.ok(has(svg, "<path d=\"" .. Shapes.ICONS[name] .. "\""), "path body: " .. name)
    T.ok(has(svg, 'stroke="#A79FB3"'), "stroke colour: " .. name)
  end
  T.eq(#Shapes.iconNames(), #SPEC_ICONS, "exactly the spec icons")
end

function test_icon_placement()
  local c = Svg.new(100, 100)
  Shapes.icon(c, "lock", 50, 40, 48, "#FFFFFF")
  local svg = c:finish()
  -- 24-grid centre (12, 12) lands on (50, 40): translate = (50 - 24, 40 - 24), scale 2
  T.ok(has(svg, 'transform="translate(26 16) scale(2)"'), "translate and scale for 48 px")
  c = Svg.new(100, 100)
  Shapes.icon(c, "mic", 10, 10, 20, "#FFFFFF")
  svg = c:finish()
  T.ok(has(svg, "scale(0.83)"), "20 px scale")
  T.ok(has(svg, "translate(0 0)"), "20 px translate")
  -- same body string is reused from the cache (no change in output)
  local c2 = Svg.new(100, 100)
  Shapes.icon(c2, "mic", 10, 10, 20, "#FFFFFF")
  T.eq(c2:finish(), svg, "cached body gives identical output")
end

function test_icon_unknown()
  local c = Svg.new(64, 64)
  Shapes.icon(c, "nosuchicon", 32, 32, 24, "#FFFFFF")
  local svg = c:finish()
  T.ok(has(svg, '<circle cx="32" cy="32" r="6"'), "unknown draws a small circle")
  T.ok(not has(svg, "<path"), "no path for unknown")
  c = Svg.new(64, 64)
  Shapes.icon(c, nil, 32, 32, 24)
  T.ok(has(c:finish(), "<circle"), "nil name draws a circle")
end

function test_icon_colour_is_escaped()
  local c = Svg.new(64, 64)
  Shapes.icon(c, "plus", 32, 32, 24, "#C513E8\"><script>")
  local svg = c:finish()
  T.ok(isAscii(svg), "ascii")
  T.ok(has(svg, "&quot;&gt;&lt;script&gt;"), "quotes and angle brackets escaped")
  T.ok(balanced(svg), "balanced")
end

function test_iconFor()
  T.eq(Shapes.iconFor("Microsoft Surface Hub"), "laptop", "no partial word match (mic in Microsoft)")
  T.eq(Shapes.iconFor("Microsoft Surface Hub", "destination"), "display", "destination default")
  T.eq(Shapes.iconFor("Conference Room"), "room", "room")
  T.eq(Shapes.iconFor("Screen Share"), "display", "screen")
  T.eq(Shapes.iconFor("Teams Call"), "teams", "teams before call")
  T.eq(Shapes.iconFor("Zoom Room"), "zoom", "first word wins")
  T.eq(Shapes.iconFor("Laptop HDMI"), "laptop", "laptop")
  T.eq(Shapes.iconFor("HDMI 2"), "hdmi", "hdmi")
  T.eq(Shapes.iconFor("Room PC"), "room", "room first")
  T.eq(Shapes.iconFor("Computer"), "pc", "computer -> pc")
  T.eq(Shapes.iconFor("Codec"), "phone", "codec -> phone")
  T.eq(Shapes.iconFor("Conference Phone"), "phone", "phone")
  T.eq(Shapes.iconFor("PTZ Cam 1"), "camera", "cam -> camera")
  T.eq(Shapes.iconFor("Doc Cam"), "doccam", "doc -> doccam")
  T.eq(Shapes.iconFor("Apple TV"), "appletv", "apple -> appletv")
  T.eq(Shapes.iconFor("ClickShare"), "clickshare", "clickshare")
  T.eq(Shapes.iconFor("Wireless Mic"), "wireless", "wireless first")
  T.eq(Shapes.iconFor("Handheld Mic"), "mic", "mic")
  T.eq(Shapes.iconFor("Music Player"), "music", "music")
  T.eq(Shapes.iconFor("Audio"), "music", "audio -> music")
  T.eq(Shapes.iconFor("Main TV"), "display", "tv -> display")
  T.eq(Shapes.iconFor("Projector"), "projector", "projector")
  T.eq(Shapes.iconFor("Town Hall"), "room", "hall -> room")
  T.eq(Shapes.iconFor("AirPlay"), "wireless", "airplay")
  T.eq(Shapes.iconFor("Chromecast"), "laptop", "chromecast is not the word cast")
  T.eq(Shapes.iconFor("Cast"), "wireless", "cast")
  T.eq(Shapes.iconFor("Webex"), "webex", "webex")
  T.eq(Shapes.iconFor(""), "laptop", "empty source")
  T.eq(Shapes.iconFor(nil, "destination"), "display", "nil destination")
end

-- ---------- tiles ----------

function test_tile_long_label_fits()
  local label = string.rep("Conference ", 7) .. "Room"   -- 81 characters
  T.ok(#label >= 80, "label is 80+ chars")
  for _, w in ipairs({ 60, 90, 120, 200 }) do
    local c = Svg.new(400, 100)
    local drawn = Shapes.tile(c, T0, 10, 10, w, 40, label)
    T.ok(drawn ~= "" and drawn ~= label, "label truncated at w=" .. w)
    T.ok(string.sub(drawn, -3) == "...", "ellipsis at w=" .. w)
    T.ok(Font.width(drawn, 14) <= w - 16, "fitted width inside tile at w=" .. w)
    T.ok(has(c:finish(), ">" .. drawn .. "<"), "drawn label appears in the svg")
  end
  -- with an icon the label budget shrinks by the icon width
  local c = Svg.new(400, 100)
  local drawn = Shapes.tile(c, T0, 10, 10, 120, 40, label, { icon = "laptop" })
  T.ok(Font.width(drawn, 14) <= 120 - 16 - 30, "label fits beside the icon")
  T.ok(has(c:finish(), Shapes.ICONS.laptop), "icon drawn")
end

function test_tile_short_label()
  local c = Svg.new(200, 100)
  local drawn = Shapes.tile(c, T0, 0, 0, 120, 40, "Laptop")
  T.eq(drawn, "Laptop", "short label unchanged")
  local svg = c:finish()
  T.ok(has(svg, 'fill="' .. T0.panel .. '"'), "panel fill when off")
  T.ok(has(svg, 'stroke="' .. T0.line .. '"'), "line stroke when off")
  T.ok(has(svg, 'fill="' .. T0.text .. '"'), "text colour when off")
  T.ok(balanced(svg), "balanced")
end

function test_tile_states()
  local c = Svg.new(200, 100)
  Shapes.tile(c, T0, 0, 0, 120, 40, "On", { on = true })
  local svg = c:finish()
  T.ok(has(svg, 'fill="' .. T0.accent .. '"'), "accent fill when on")
  T.ok(has(svg, 'fill="' .. T0.onAccent .. '"'), "onAccent text when on")

  c = Svg.new(200, 100)
  Shapes.tile(c, T0, 0, 0, 120, 40, "Picked", { picked = true })
  svg = c:finish()
  T.ok(has(svg, 'stroke="' .. T0.accent .. '" stroke-width="3"'), "thick accent stroke when picked")

  c = Svg.new(200, 100)
  Shapes.tile(c, T0, 0, 0, 120, 40, "Dim", { dim = true })
  svg = c:finish()
  T.ok(has(svg, '<g opacity="0.45">'), "dim group at 45 %")
  T.ok(balanced(svg), "dim group balanced")

  c = Svg.new(200, 100)
  local drawn = Shapes.tile(c, T0, 0, 0, 120, 40, "Label", { sub = "Sub text", accent = "#123456", on = true })
  svg = c:finish()
  T.eq(drawn, "Label", "label returned")
  T.ok(has(svg, 'fill="#123456"'), "custom accent")
  T.ok(has(svg, 'font-size="11"'), "sub text at 11 px")
  T.ok(has(svg, ">Sub text<"), "sub text drawn")

  c = Svg.new(200, 100)
  Shapes.tile(c, T0, 0, 0, 120, 40, "Hebrew \xD7\xA9\xD7\x9C\xD7\x95\xD7\x9D", { stroke = "#ABCDEF", radius = 2 })
  svg = c:finish()
  T.ok(isAscii(svg), "non-ASCII label becomes references")
  T.ok(has(svg, "&#1513;"), "hebrew shin reference")
  T.ok(has(svg, 'stroke="#ABCDEF"'), "custom stroke")
  T.ok(has(svg, 'rx="2"'), "custom radius")
end

-- ---------- pad frame, hint, title ----------

function test_padFrame_backgrounds()
  for _, theme in ipairs({ "Nikita", "Sunset", "Ocean", "Light" }) do
    local T1 = THEMES[theme]
    local c = Svg.new(300, 200)
    Shapes.padFrame(c, T1, 300, 200, 10, "Solid")
    local svg = c:finish()
    T.ok(has(svg, '<rect x="0" y="0" width="300" height="200" rx="10" fill="' .. T1.bg .. '"'), theme .. " solid bg")
    T.ok(has(svg, 'stroke="' .. T1.line .. '"'), theme .. " solid border")

    c = Svg.new(300, 200)
    Shapes.padFrame(c, T1, 300, 200, 0, "Panel")
    svg = c:finish()
    T.ok(has(svg, 'fill="' .. T1.panel .. '"'), theme .. " panel fill")
    T.ok(not has(svg, 'fill="' .. T1.bg .. '"') or T1.bg == T1.panel, theme .. " panel does not use bg")

    c = Svg.new(300, 200)
    local before = c:len()
    Shapes.padFrame(c, T1, 300, 200, 10, "Transparent")
    T.eq(c:len(), before, theme .. " transparent draws nothing")
    T.ok(not has(c:finish(), "<rect"), theme .. " transparent has no rect")
  end
  local c = Svg.new(300, 200)
  Shapes.padFrame(c, T0, 300, 200, 4, "Bogus")
  T.ok(has(c:finish(), 'fill="' .. T0.bg .. '"'), "unknown background falls back to Solid")
end

function test_hint_and_title()
  local c = Svg.new(300, 200)
  local before = c:len()
  Shapes.hint(c, T0, "", 300, 200)
  Shapes.hint(c, T0, nil, 300, 200)
  Shapes.title(c, T0, "", 300)
  T.eq(c:len(), before, "empty hint and title draw nothing")

  Shapes.hint(c, T0, "Drag to move", 300, 200)
  local svg = c:finish()
  T.ok(has(svg, '<text x="150" y="192"'), "hint at bottom centre")
  T.ok(has(svg, 'font-size="12" fill="' .. T0.muted .. '" text-anchor="middle">Drag to move</text>'), "hint style")

  c = Svg.new(300, 200)
  Shapes.title(c, T0, "Zone Select", 300)
  svg = c:finish()
  T.ok(has(svg, 'fill="' .. T0.text .. '" text-anchor="middle" font-weight="bold">Zone Select</text>'), "title style")

  -- a long hint is fitted to the pad width
  c = Svg.new(120, 100)
  Shapes.hint(c, T0, string.rep("hint ", 30), 120, 100)
  svg = c:finish()
  local drawn = string.match(svg, ">([^<]*)</text>")
  T.ok(drawn and string.sub(drawn, -3) == "...", "long hint truncated")
  T.ok(Font.width(drawn, 12) <= 120 - 16, "fitted hint width")
end

-- ---------- grid, crosshair, dot ----------

function test_gridDots()
  local c = Svg.new(320, 240)
  Shapes.gridDots(c, T0, 320, 240, 32)
  local svg = c:finish()
  T.eq(count(svg, "<path"), 1, "one path for the grid")
  T.eq(count(svg, "M"), 10 * 7, "10 x 7 dots at step 32")
  T.ok(has(svg, 'stroke-linecap="round"'), "round caps make dots")
  T.ok(has(svg, "M16 24h0.5"), "centred grid starts at (16, 24)")

  c = Svg.new(4000, 4000)
  Shapes.gridDots(c, T0, 4000, 4000, 8)
  svg = c:finish()
  T.ok(count(svg, "M") <= 400, "dot count bounded")
  T.ok(count(svg, "M") > 0, "still draws")

  c = Svg.new(10, 10)
  local before = c:len()
  Shapes.gridDots(c, T0, 10, 10, 2)
  T.ok(c:len() > before, "tiny pad still gets dots")
  c = Svg.new(4, 4)
  before = c:len()
  Shapes.gridDots(c, T0, 4, 4, 8)
  T.eq(c:len(), before, "no room, nothing drawn")
end

function test_crosshair_and_dot()
  local c = Svg.new(300, 200)
  Shapes.crosshair(c, T0, 100, 50, 300, 200)
  local svg = c:finish()
  T.ok(has(svg, '<line x1="0" y1="50" x2="300" y2="50"'), "horizontal line across the pad")
  T.ok(has(svg, '<line x1="100" y1="0" x2="100" y2="200"'), "vertical line across the pad")
  T.ok(has(svg, 'stroke-dasharray="4 4"'), "dashed")
  T.ok(has(svg, '<circle cx="100" cy="50" r="6"'), "ring at the point")

  c = Svg.new(300, 200)
  Shapes.dot(c, T0, 40, 30, 10)
  svg = c:finish()
  T.ok(has(svg, '<circle cx="40" cy="30" r="18" fill="' .. T0.accent .. '" opacity="0.25"'), "halo")
  T.ok(has(svg, '<circle cx="40" cy="30" r="10" fill="' .. T0.accent .. '"'), "dot")
  T.ok(balanced(svg), "balanced")
end

-- ---------- arrow bar, lock overlay, targets ----------

function test_arrowBar()
  local c = Svg.new(300, 60)
  Shapes.arrowBar(c, T0, 0, 10, 300, 40, false, true, "1 / 4")
  local svg = c:finish()
  T.eq(count(svg, '<g opacity="0.3">'), 1, "one dim half")
  T.ok(has(svg, Shapes.ICONS.chevronLeft), "left chevron")
  T.ok(has(svg, Shapes.ICONS.chevronRight), "right chevron")
  T.ok(has(svg, ">1 / 4</text>"), "page text")
  T.ok(has(svg, '<text x="150"'), "page text centred")
  T.ok(balanced(svg), "balanced")
  -- the dim group holds the left half (it appears before the right chevron)
  local dimAt = string.find(svg, '<g opacity="0.3">', 1, true)
  local rightAt = string.find(svg, Shapes.ICONS.chevronRight, 1, true)
  T.ok(dimAt < rightAt, "left half is the dim one")

  c = Svg.new(300, 60)
  Shapes.arrowBar(c, T0, 0, 10, 300, 40, true, false, "")
  svg = c:finish()
  T.eq(count(svg, '<g opacity="0.3">'), 1, "right half dim")
  T.ok(not has(svg, "<text"), "no page text when empty")
  dimAt = string.find(svg, '<g opacity="0.3">', 1, true)
  local leftAt = string.find(svg, Shapes.ICONS.chevronLeft, 1, true)
  T.ok(dimAt > leftAt, "right half is the dim one")

  c = Svg.new(300, 60)
  Shapes.arrowBar(c, T0, 0, 10, 300, 40, true, true, "2 / 2")
  svg = c:finish()
  T.eq(count(svg, '<g opacity="0.3">'), 0, "no dim half when both pages exist")
  T.eq(count(svg, "<rect"), 2, "two halves")
end

function test_lockOverlay()
  local c = Svg.new(400, 300)
  Shapes.lockOverlay(c, T0, 400, 300)
  local svg = c:finish()
  T.ok(has(svg, '<rect x="0" y="0" width="400" height="300" fill="' .. T0.bg .. '" opacity="0.72"'), "dimming rect")
  T.ok(has(svg, Shapes.ICONS.lock), "lock icon")
  T.ok(has(svg, ">Locked</text>"), "caption")
  T.ok(balanced(svg), "balanced")
  -- icon size is clamped on tiny and huge pads
  c = Svg.new(40, 40)
  Shapes.lockOverlay(c, T0, 40, 40)
  T.ok(has(c:finish(), "scale(1)"), "minimum 24 px lock")
  c = Svg.new(2000, 2000)
  Shapes.lockOverlay(c, T0, 2000, 2000)
  T.ok(has(c:finish(), "scale(4)"), "maximum 96 px lock")
end

function test_targets()
  local c = Svg.new(400, 300)
  local a, b = Shapes.targets(c, T0, 400, 300)
  T.near(a.x, 48, 1e-9, "first target x 12 % in")
  T.near(a.y, 36, 1e-9, "first target y 12 % in")
  T.near(b.x, 352, 1e-9, "second target x 12 % from the right")
  T.near(b.y, 264, 1e-9, "second target y 12 % from the bottom")
  local svg = c:finish()
  T.ok(has(svg, '<circle cx="48" cy="36" r="14"'), "first ring")
  T.ok(has(svg, '<circle cx="352" cy="264" r="14"'), "second ring")
  T.eq(count(svg, "<circle"), 4, "two rings and two centre dots")
  T.ok(balanced(svg), "balanced")
end

-- ---------- budget and limit behaviour ----------

function test_truncation_keeps_balance()
  local c = Svg.new(400, 300, { limit = 700 })
  for i = 1, 20 do
    Shapes.tile(c, T0, 10, i * 10, 120, 40, "Tile " .. i, { icon = "laptop", dim = (i % 2 == 0) })
  end
  T.ok(c.truncated, "limit hit")
  local svg = c:finish()
  T.ok(#svg <= 700, "within limit")
  T.ok(balanced(svg), "balanced after truncation")
end

local function drawPage(c, n)
  Shapes.padFrame(c, T0, 480, 320, 8, "Solid")
  for i = 1, n do
    local col, row = (i - 1) % 6, (i - 1) // 6
    Shapes.tile(c, T0, 8 + col * 78, 8 + row * 60, 72, 52, "Source " .. i,
      { icon = Shapes.iconFor("Laptop " .. i), on = (i % 5 == 0), dim = (i % 7 == 0), sub = "HDMI" })
  end
  Shapes.arrowBar(c, T0, 8, 272, 464, 40, true, false, "1 / 3")
  Shapes.hint(c, T0, "Drag a source onto a display", 480, 320)
end

function test_frame_budget()
  local cold = T.instructions(function() drawPage(Svg.new(480, 320), 24) end)
  local warm = T.instructions(function() drawPage(Svg.new(480, 320), 24) end)
  T.ok(cold < 60000, "24 tiles with icons and sub text cold under 60k (" .. cold .. ")")
  T.ok(warm < 40000, "warm under 40k (" .. warm .. ")")
  T.ok(warm <= cold, "warm run is not dearer than cold (" .. warm .. " vs " .. cold .. ")")
  local c = Svg.new(480, 320)
  drawPage(c, 24)
  local svg = c:finish()
  T.ok(#svg < 14000, "24-tile page under 14k chars (" .. #svg .. ")")
  T.ok(balanced(svg), "balanced")
  T.ok(isAscii(svg), "ascii")
end

function test_icon_cost()
  local c = Svg.new(100, 100)
  Shapes.icon(c, "teams", 50, 50, 24, T0.text)       -- warm the body cache
  local n = T.instructions(function() Shapes.icon(c, "teams", 50, 50, 24, T0.text) end)
  T.ok(n < 400, "cached icon under 400 instructions (" .. n .. ")")
end

-- ---------- regressions from review ----------

function test_iconFor_kind_spellings()
  for _, kind in ipairs({ "Destination", "DESTINATION", "destinations", "Output", "outputs", "dst", "Sink", "dest", "Dest Zones" }) do
    T.eq(Shapes.iconFor("Monitor", kind), "display", "destination kind: " .. kind)
  end
  for _, kind in ipairs({ "source", "Source", "input", "", "in", "sources" }) do
    T.eq(Shapes.iconFor("Monitor", kind), "laptop", "source kind: " .. kind)
  end
  T.eq(Shapes.iconFor("Monitor", nil), "laptop", "nil kind is a source")
  T.eq(Shapes.iconFor("Main TV", "input"), "display", "words still win over kind")
  T.eq(Shapes.iconFor("Laptop", "Destination"), "laptop", "words win over a destination kind too")
  T.ok(Shapes.isDestination("OUTPUT"), "isDestination exported")
  T.ok(not Shapes.isDestination("route"), "unrelated kind is not a destination")
end

function test_small_boxes_never_negative()
  local c = Svg.new(100, 100)
  Shapes.tile(c, T0, 0, 0, 10, 2, "x", { picked = true })
  Shapes.tile(c, T0, 0, 0, 2, 2, "x", { icon = "laptop", sub = "s" })
  Shapes.padFrame(c, T0, 0.5, 0.5, 4, "Solid")
  Shapes.arrowBar(c, T0, 0, 0, 3, 10, true, true, "1 / 2")
  Shapes.dot(c, T0, 10, 10, -2)
  Shapes.gridDots(c, T0, 5, 5, 8)
  Shapes.lockOverlay(c, T0, 1, 1)
  local svg = c:finish()
  T.ok(not string.find(svg, '="%-'), "no negative attribute values")
  T.ok(string.find(svg, 'r="0"', 1, true) ~= nil, "negative dot radius clamps to zero")
  T.ok(balanced(svg), "balanced")
  T.ok(isAscii(svg), "ascii")
end
