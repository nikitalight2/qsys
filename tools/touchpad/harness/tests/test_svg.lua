-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: unit tests for 07_svg.lua (Svg, Canvas)

local function isAscii(s)
  return not string.find(s, "[\128-\255]")
end

-- tiny well-formedness checker: tags balance and nest properly
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

-- numbers out of a path "d" attribute
local function nums(d)
  local out = {}
  for n in string.gmatch(d, "-?%d+%.?%d*") do out[#out + 1] = tonumber(n) end
  return out
end

function test_num()
  T.eq(Svg.num(1.0), "1", "no trailing .0")
  T.eq(Svg.num(2.345), "2.3", "one decimal")
  T.eq(Svg.num(-0.04), "0", "negative zero")
  T.eq(Svg.num(-0.0), "0", "minus zero literal")
  T.eq(Svg.num(0), "0", "zero")
  T.eq(Svg.num(12), "12", "integer")
  T.eq(Svg.num(-3.75), "-3.7", "negative rounding")
  T.eq(Svg.num(0.96), "1", "rounds up to integer")
  T.eq(Svg.num(123456.78), "123456.8", "large")
  T.eq(Svg.num(0 / 0), "0", "nan")
  T.eq(Svg.num(nil), "0", "nil")
  T.eq(Svg.frac(0.25), "0.25", "frac two decimals")
  T.eq(Svg.frac(1), "1", "frac one")
  T.eq(Svg.frac(0.5), "0.5", "frac one decimal")
end

function test_colours()
  T.eq(Svg.mix("#000000", "#FFFFFF", 0.5), "#808080", "mix mid")
  T.eq(Svg.mix("#C513E8", "#000000", 0), "#C513E8", "mix t=0 is A")
  T.eq(Svg.mix("#C513E8", "#000000", 1), "#000000", "mix t=1 is B")
  T.eq(Svg.mix("bad", "#112233", 0.5), "#112233", "bad A falls back to B")
  T.eq(Svg.lighten("#000000", 1), "#FFFFFF", "lighten full")
  T.eq(Svg.lighten("#FFFFFF", -1), "#000000", "darken full")
  T.eq(Svg.lighten("#808080", 0), "#808080", "lighten zero")
  T.eq(Svg.lighten("#000000", 0.5), "#808080", "lighten half")
  T.eq(Svg.lighten("#FFFFFF", -0.5), "#808080", "darken half")
  local hex, a = Svg.withAlpha("#C513E8", 0.5)
  T.eq(hex, "#C513E8", "withAlpha keeps hex")
  T.eq(a, 0.5, "withAlpha returns alpha")
end

function test_document()
  local c = Svg.new(200, 100)
  c:rect(0, 0, 200, 100, { fill = "#17151C", rx = 8 })
  local svg = c:finish()
  T.eq(string.sub(svg, 1, 5), "<svg ", "starts with svg")
  T.ok(string.find(svg, 'xmlns="http://www.w3.org/2000/svg"', 1, true) ~= nil, "namespace")
  T.ok(string.find(svg, 'viewBox="0 0 200 100"', 1, true) ~= nil, "viewBox")
  T.ok(string.find(svg, 'width="200" height="100"', 1, true) ~= nil, "size")
  T.ok(string.find(svg, '<rect x="0" y="0" width="200" height="100" rx="8" fill="#17151C"/>', 1, true) ~= nil, "rect")
  T.eq(string.sub(svg, -6), "</svg>", "ends with closing tag")
  T.ok(balanced(svg), "balanced")
  T.eq(c:finish(), svg, "finish is repeatable")
  T.eq(#svg, c:len(), "len matches the finished length")
end

function test_ascii_only_text()
  local inputs = {
    "plain", "a<b&c\"d", "\215\169\215\156\215\149\215\157", "\240\159\152\128 party", "bad\255byte\226\128",
    "caf\195\169 \228\184\173\230\150\135",
  }
  for i = 1, #inputs do
    local c = Svg.new(100, 100)
    c:text(10, 20, inputs[i], { size = 12, fill = "#FFF" })
    c:textFit(10, 40, 50, inputs[i], { size = 12 })
    c:raw("<!-- " .. (string.gsub(inputs[i], "[<>&\"]", "")) .. " -->")
    local svg = c:finish()
    T.ok(isAscii(svg), "ascii output for input " .. i)
    T.ok(balanced(svg), "balanced for input " .. i)
  end
  local c = Svg.new(100, 100)
  c:text(0, 0, "\215\144<", { fill = "\195\169", family = "Ar\195\169al", anchor = "middle", weight = "bold", baseline = "middle", opacity = 0.5, spacing = 1 })
  local svg = c:finish()
  T.ok(isAscii(svg), "ascii attributes")
  T.ok(string.find(svg, ">&#1488;&lt;</text>", 1, true) ~= nil, "text content referenced and escaped")
  T.ok(string.find(svg, 'font-family="Ar&#233;al, Roboto, sans-serif"', 1, true) ~= nil, "family chain")
  T.ok(string.find(svg, 'text-anchor="middle"', 1, true) ~= nil, "anchor")
  T.ok(string.find(svg, 'font-weight="bold"', 1, true) ~= nil, "weight")
  T.ok(string.find(svg, 'dominant-baseline="middle"', 1, true) ~= nil, "baseline")
  T.ok(string.find(svg, 'opacity="0.5"', 1, true) ~= nil, "opacity")
  local d = Svg.new(10, 10)
  d:text(0, 0, "x")
  T.ok(string.find(d:finish(), 'font-family="Roboto, sans-serif" font-size="14"', 1, true) ~= nil, "default family and size")
end

function test_text_fit()
  local c = Svg.new(100, 100)
  local drawn = c:textFit(0, 0, 30, "Conference Room Display", { size = 14 })
  T.ok(Font.width(drawn, 14) <= 30, "fitted width")
  T.eq(string.sub(drawn, -3), "...", "ellipsis")
  T.ok(string.find(c:finish(), ">" .. drawn .. "</text>", 1, true) ~= nil, "drawn text in output")
  local e = Svg.new(100, 100)
  T.eq(e:textFit(0, 0, 1, "Wide", {}), "", "nothing fits returns empty")
  T.eq(count(e:finish(), "<text"), 0, "nothing drawn when nothing fits")
end

function test_shapes()
  local c = Svg.new(100, 100)
  c:circle(50, 50, 10.04, { fill = "#FFF", stroke = "#000", sw = 1.5 })
  c:ellipse(1, 2, 3, 4, { opacity = 0.25 })
  c:line(0, 0, 10, 10, { stroke = "#F00", sw = 2, cap = "round", dash = { 4, 2 } })
  c:polyline({ 0, 0, 10, 5, 20, 0 }, { stroke = "#0F0" })
  c:polyline({ 0, 0, 10, 5, 20, 0 }, { close = true, fill = "#00F" })
  c:path("M0 0L10 10", { stroke = "#FFF", dash = "2 1", join = "round" })
  local svg = c:finish()
  T.ok(string.find(svg, '<circle cx="50" cy="50" r="10" fill="#FFF" stroke="#000" stroke-width="1.5"/>', 1, true) ~= nil, "circle")
  T.ok(string.find(svg, '<ellipse cx="1" cy="2" rx="3" ry="4" opacity="0.25"/>', 1, true) ~= nil, "ellipse")
  T.ok(string.find(svg, '<line x1="0" y1="0" x2="10" y2="10" stroke="#F00" stroke-width="2" stroke-dasharray="4 2" stroke-linecap="round"/>', 1, true) ~= nil, "line")
  T.ok(string.find(svg, '<polyline points="0,0 10,5 20,0" fill="none" stroke="#0F0"/>', 1, true) ~= nil, "polyline default fill none")
  T.ok(string.find(svg, '<polygon points="0,0 10,5 20,0" fill="#00F"/>', 1, true) ~= nil, "polygon")
  T.ok(string.find(svg, '<path d="M0 0L10 10" fill="none" stroke="#FFF" stroke-dasharray="2 1" stroke-linejoin="round"/>', 1, true) ~= nil, "path")
  T.ok(balanced(svg), "balanced")
  local order = Svg.new(10, 10)
  order:rect(0, 0, 1, 1):circle(0, 0, 1)
  local o = order:finish()
  T.ok(string.find(o, "<rect", 1, true) < string.find(o, "<circle", 1, true), "painter order")
end

function test_arc_geometry()
  local c = Svg.new(100, 100)
  c:arc(50, 50, 10, 0, 90, { stroke = "#FFF" })
  local svg = c:finish()
  local d = string.match(svg, 'd="([^"]*)"')
  T.ok(d ~= nil, "arc path present")
  local n = nums(d)
  T.near(n[1], 60, 1e-9, "start x (0 deg = right)")
  T.near(n[2], 50, 1e-9, "start y")
  T.eq(n[3], 10, "radius x")
  T.eq(n[4], 10, "radius y")
  T.eq(n[6], 0, "small arc")
  T.eq(n[7], 0, "counter-clockwise sweep on screen")
  T.near(n[8], 50, 1e-9, "end x (90 deg = up)")
  T.near(n[9], 40, 1e-9, "end y")
  T.ok(string.find(svg, 'fill="none"', 1, true) ~= nil, "arc is stroke only")
  local cw = Svg.new(100, 100)
  cw:arc(50, 50, 10, 90, 0, { stroke = "#FFF" })
  local n2 = nums(string.match(cw:finish(), 'd="([^"]*)"'))
  T.near(n2[1], 50, 1e-9, "reverse start x") T.near(n2[2], 40, 1e-9, "reverse start y")
  T.eq(n2[7], 1, "clockwise sweep")
  local big = Svg.new(100, 100)
  big:arc(50, 50, 10, 0, 270, { stroke = "#FFF" })
  local n3 = nums(string.match(big:finish(), 'd="([^"]*)"'))
  T.eq(n3[6], 1, "large arc flag")
  T.near(n3[8], 50, 1e-9, "270 end x") T.near(n3[9], 60, 1e-9, "270 end y (down)")
  local full = Svg.new(100, 100)
  full:arc(50, 50, 10, 0, 360, { stroke = "#FFF" })
  local fd = string.match(full:finish(), 'd="([^"]*)"')
  T.eq(count(fd, "A"), 2, "full circle uses two arcs")
end

function test_wedge_and_ring()
  local c = Svg.new(100, 100)
  c:wedge(50, 50, 20, 0, 90, { fill = "#F0F" })
  local d = string.match(c:finish(), 'd="([^"]*)"')
  T.ok(string.sub(d, 1, 7) == "M50 50L", "wedge starts at the centre")
  T.ok(string.sub(d, -1) == "Z", "wedge closed")
  local n = nums(d)
  T.near(n[3], 70, 1e-9, "wedge outer start x") T.near(n[4], 50, 1e-9, "wedge outer start y")
  T.near(n[10], 50, 1e-9, "wedge end x") T.near(n[11], 30, 1e-9, "wedge end y")
  local r = Svg.new(100, 100)
  r:ring(50, 50, 20, 10, 0, 90, { fill = "#0FF" })
  local rd = string.match(r:finish(), 'd="([^"]*)"')
  local rn = nums(rd)
  T.near(rn[1], 70, 1e-9, "ring outer start x")
  T.near(rn[8], 50, 1e-9, "ring outer end x") T.near(rn[9], 30, 1e-9, "ring outer end y")
  T.near(rn[10], 50, 1e-9, "ring inner start x") T.near(rn[11], 40, 1e-9, "ring inner start y")
  T.near(rn[17], 60, 1e-9, "ring inner end x") T.near(rn[18], 50, 1e-9, "ring inner end y")
  T.eq(count(rd, "A"), 2, "ring has two arcs")
  T.ok(string.sub(rd, -1) == "Z", "ring closed")
  local fw = Svg.new(100, 100)
  fw:wedge(50, 50, 20, 0, 360, { fill = "#F0F" })
  T.ok(string.find(fw:finish(), "<circle", 1, true) ~= nil, "full wedge is a circle")
  local fr = Svg.new(100, 100)
  fr:ring(50, 50, 20, 10, 0, 360, { fill = "#F0F" })
  local frs = fr:finish()
  T.ok(string.find(frs, 'fill-rule="evenodd"', 1, true) ~= nil, "full ring uses evenodd")
  T.ok(balanced(frs), "balanced")
end

function test_gradients_and_clips()
  local c = Svg.new(100, 100)
  c:gradient("g1", "linear", { { 0, "#000000" }, { 1, "#FFFFFF", 0.5 } })
  c:gradient("g2", "radial", { { 0.25, "#C513E8" } }, { cx = 0.3 })
  c:gradient("g3", "linear", { { 0, "#000" } }, { x1 = 0, y1 = 0, x2 = 1, y2 = 0 })
  c:clipRect("clip1", 10, 10, 80, 80, 6)
  c:rect(0, 0, 100, 100, { fill = "url(#g1)" })
  c:group({ clip = "clip1" }, function(g) g:circle(50, 50, 40, { fill = "url(#g2)" }) end)
  local svg = c:finish()
  T.ok(balanced(svg), "balanced")
  T.ok(string.find(svg, "<defs>", 1, true) < string.find(svg, "<rect", 1, true), "defs come first")
  T.ok(string.find(svg, '<linearGradient id="g1" x1="0%" y1="0%" x2="0%" y2="100%">', 1, true) ~= nil, "linear default top to bottom")
  T.ok(string.find(svg, '<stop offset="0%" stop-color="#000000"/><stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.5"/>', 1, true) ~= nil, "stops")
  T.ok(string.find(svg, '<radialGradient id="g2" cx="30%" cy="50%" r="50%">', 1, true) ~= nil, "radial")
  T.ok(string.find(svg, '<stop offset="25%" stop-color="#C513E8"/>', 1, true) ~= nil, "radial stop")
  T.ok(string.find(svg, 'x2="100%" y2="0%"', 1, true) ~= nil, "linear custom direction")
  T.ok(string.find(svg, '<clipPath id="clip1"><rect x="10" y="10" width="80" height="80" rx="6"/></clipPath>', 1, true) ~= nil, "clipPath")
  T.ok(string.find(svg, '<g clip-path="url(#clip1)">', 1, true) ~= nil, "group references clip by id")
  T.ok(string.find(svg, 'fill="url(#g1)"', 1, true) ~= nil, "fill references gradient by id")
  T.eq(count(svg, "<defs>"), 1, "one defs block")
end

function test_groups()
  local c = Svg.new(100, 100)
  local depthSeen = 0
  c:group({ opacity = 0.5, transform = "translate(10 10)" }, function(g)
    g:rect(0, 0, 10, 10)
    g:group({ transform = "rotate(45)" }, function(g2)
      depthSeen = g2.depth
      g2:circle(0, 0, 5)
    end)
    g:line(0, 0, 1, 1)
  end)
  c:rect(1, 1, 1, 1)
  local svg = c:finish()
  T.eq(depthSeen, 2, "nested depth")
  T.eq(c.depth, 0, "depth restored")
  T.ok(balanced(svg), "balanced")
  T.ok(string.find(svg, '<g opacity="0.5" transform="translate(10 10)"><rect x="0" y="0" width="10" height="10"/><g transform="rotate(45)"><circle cx="0" cy="0" r="5"/></g><line', 1, true) ~= nil, "nesting order")
  T.eq(count(svg, "<g"), 2, "two groups opened")
  T.eq(count(svg, "</g>"), 2, "two groups closed")
  local e = Svg.new(10, 10)
  e:group(nil, nil)
  T.eq(e:finish(), e.header .. "<g></g></svg>", "empty group")
end

function test_limit_truncates()
  local c = Svg.new(100, 100, { limit = 400 })
  for i = 1, 50 do c:rect(i, i, 10, 10, { fill = "#FFFFFF" }) end
  T.ok(c.truncated, "truncated flag set")
  local svg = c:finish()
  T.ok(#svg <= 400, "finished document within the limit")
  T.ok(count(svg, "<rect") < 50, "elements dropped")
  T.ok(count(svg, "<rect") > 0, "early elements kept")
  T.ok(balanced(svg), "balanced after truncation")
  local ok = Svg.new(100, 100, { limit = 60000 })
  for i = 1, 50 do ok:rect(i, i, 10, 10) end
  T.ok(not ok.truncated, "not truncated below the limit")
end

function test_limit_keeps_groups_balanced()
  local c = Svg.new(100, 100, { limit = 300 })
  c:group({ opacity = 0.9 }, function(g)
    for i = 1, 40 do
      g:group({ transform = "translate(1 1)" }, function(g2) g2:rect(i, i, 5, 5, { fill = "#FFF" }) end)
    end
  end)
  c:clipRect("late", 0, 0, 1, 1)
  local svg = c:finish()
  T.ok(c.truncated, "truncated")
  T.ok(#svg <= 300, "within limit")
  T.ok(balanced(svg), "balanced with nested groups")
  T.eq(count(svg, "<g"), count(svg, "</g>"), "every opened group is closed")
  local deep = Svg.new(100, 100, { limit = 100 })
  deep:group({ opacity = 0.5 }, function(g) g:rect(0, 0, 1, 1) end)
  T.ok(deep.truncated, "group that does not fit is dropped")
  T.ok(balanced(deep:finish()), "still balanced")
end

function test_raw_and_len()
  local c = Svg.new(10, 10)
  local before = c:len()
  c:raw("<!-- note -->")
  T.eq(c:len(), before + #"<!-- note -->", "len counts raw")
  c:raw("caf\195\169")
  local svg = c:finish()
  T.ok(isAscii(svg), "raw is sanitised")
  T.ok(string.find(svg, "caf??", 1, true) ~= nil, "non-ascii bytes replaced")
  T.eq(#svg, c:len(), "len equals final length")
end

local function tileFrame(tiles)
  local c = Svg.new(800, 480)
  c:gradient("bg", "linear", { { 0, "#201D26" }, { 1, "#17151C" } })
  c:rect(0, 0, 800, 480, { fill = "url(#bg)", rx = 12 })
  for i = 1, tiles do
    local x, y = ((i - 1) % 8) * 100, ((i - 1) // 8) * 60
    c:group({ opacity = 0.95 }, function(g)
      g:rect(x + 4, y + 4, 92, 52, { fill = "#201D26", stroke = "#35313E", sw = 1, rx = 8 })
      g:textFit(x + 50, y + 34, 84, "Conference Laptop " .. i .. " \215\169\215\156\215\149\215\157", { size = 14, anchor = "middle", fill = "#F4F2F7" })
    end)
  end
  c:arc(400, 240, 100, 0, 270, { stroke = "#C513E8", sw = 6 })
  return c:finish()
end

function test_frame_budget()
  Font.clearCache()
  local cold = T.instructions(function() tileFrame(24) end)
  local warm = T.instructions(function() tileFrame(24) end)
  T.ok(cold < 60000, "24 tiles with new names stay under the frame budget (" .. cold .. ")")
  T.ok(warm < 25000, "24 tiles with cached names are cheap (" .. warm .. ")")
  local svg = tileFrame(24)
  T.ok(#svg < 40000, "24 tiles well under the 40k character target (" .. #svg .. ")")
  T.ok(balanced(svg), "balanced")
end

-- ---------- regressions from review ----------

function test_num_extremes()
  T.eq(Svg.num(1e19), "1000000000", "huge floats clamp")
  T.eq(Svg.num(-1e19), "-1000000000", "huge negative floats clamp")
  T.eq(Svg.num(9.3e18), "1000000000", "float near 2^63 clamps")
  T.eq(Svg.num(1e308), "1000000000", "1e308 clamps instead of inf")
  T.eq(Svg.num(math.maxinteger), "1000000000", "maxinteger clamps instead of wrapping")
  T.eq(Svg.num(math.mininteger), "-1000000000", "mininteger clamps")
  T.eq(Svg.num(2 ^ 63 - 1024), "1000000000", "no trailing .0 on big floats")
  T.eq(Svg.num(math.huge), "0", "inf")
  T.eq(Svg.num(-math.huge), "0", "-inf")
  T.eq(Svg.num("14"), "14", "numeric string")
  T.eq(Svg.num("2.25"), "2.3", "numeric string rounds")
  T.eq(Svg.num("abc"), "0", "non-numeric string")
  T.eq(Svg.num(true), "0", "boolean")
  T.eq(Svg.frac(1e20), "1000000000", "frac huge clamps")
  T.eq(Svg.frac(1e18), "1000000000", "frac large integer clamps")
  T.eq(Svg.frac(math.huge), "0", "frac inf")
  T.eq(Svg.frac(-math.huge), "0", "frac -inf")
  T.eq(Svg.frac(0 / 0), "0", "frac nan")
  T.eq(Svg.frac(nil), "0", "frac nil")
  T.eq(Svg.frac("0.5"), "0.5", "frac numeric string")
  T.eq(Svg.frac(2), "2", "frac above one is kept (icon scale factors)")
  local c = Svg.new(10, 10)
  c:rect("10", "10", "50", "50", { fill = "#F00" })
  c:text(0, 0, "x", { size = "14" })
  local svg = c:finish()
  T.ok(string.find(svg, '<rect x="10" y="10" width="50" height="50"', 1, true) ~= nil, "string geometry is coerced")
  T.ok(string.find(svg, 'font-size="14"', 1, true) ~= nil, "string size is coerced")
  local far = Svg.new(10, 10)
  far:circle(50 / 1e-18, 50, 5)
  T.ok(string.find(far:finish(), 'cx="1000000000"', 1, true) ~= nil, "a near-zero denominator does not raise")
end

function test_opacity_clamped()
  local c = Svg.new(10, 10)
  c:rect(0, 0, 10, 10, { fill = "#F00", opacity = 1 / 0 })
  c:rect(0, 0, 10, 10, { fill = "#F00", opacity = 1.5 })
  c:rect(0, 0, 10, 10, { fill = "#F00", opacity = -0.5 })
  c:rect(0, 0, 10, 10, { fill = "#F00", opacity = 0 / 0 })
  c:text(0, 0, "x", { opacity = 7 })
  c:group({ opacity = 2 }, function() end)
  c:gradient("g", "linear", { { 0, "#000", 3 } })
  local svg = c:finish()
  T.eq(count(svg, 'opacity="1"'), 5, "opacities above one clamp to one (rect, rect, text, group, stop)")
  T.eq(count(svg, 'opacity="0"'), 2, "negative and NaN opacities clamp to zero")
  T.ok(string.find(svg, "inf", 1, true) == nil, "no inf in the document")
  local ok = Svg.new(10, 10)
  ok:rect(0, 0, 1, 1, { opacity = 0.25 })
  T.ok(string.find(ok:finish(), 'opacity="0.25"', 1, true) ~= nil, "in-range opacity untouched")
end

function test_raw_control_bytes()
  local c = Svg.new(10, 10)
  c:raw("x\127y\0z\1\tw\n\rv")
  local svg = c:finish()
  T.ok(string.find(svg, "x?y?z?\tw\n\rv", 1, true) ~= nil, "DEL, NUL and control bytes become ?; tab, LF and CR kept")
  T.ok(string.find(svg, "[%z\1-\8\11\12\14-\31\127-\255]") == nil, "only printable ascii and whitespace emitted")
end

function test_negative_sizes()
  local c = Svg.new(10, 10)
  c:rect(0, 0, -5, -5, { rx = -1, ry = -2, sw = -3 })
  c:circle(1, 1, -4)
  c:ellipse(1, 1, -1, -2)
  c:clipRect("k", 0, 0, -3, -3, -1)
  c:text(0, 0, "x", { size = -14 })
  c:line(-5, -5, 5, 5)
  local svg = c:finish()
  T.ok(string.find(svg, '<rect x="0" y="0" width="0" height="0" rx="0" ry="0" stroke-width="0"/>', 1, true) ~= nil, "rect sizes clamp to 0")
  T.ok(string.find(svg, '<circle cx="1" cy="1" r="0"/>', 1, true) ~= nil, "radius clamps")
  T.ok(string.find(svg, '<ellipse cx="1" cy="1" rx="0" ry="0"/>', 1, true) ~= nil, "ellipse radii clamp")
  T.ok(string.find(svg, '<clipPath id="k"><rect x="0" y="0" width="0" height="0" rx="0"/></clipPath>', 1, true) ~= nil, "clip sizes clamp")
  T.ok(string.find(svg, 'font-size="0"', 1, true) ~= nil, "font size clamps")
  T.ok(string.find(svg, 'x1="-5" y1="-5"', 1, true) ~= nil, "coordinates may still be negative")
  T.ok(string.find(Svg.new(-10, -10):finish(), 'viewBox="0 0 0 0" width="0" height="0"', 1, true) ~= nil, "canvas size clamps")
end

function test_path_default_fill()
  local c = Svg.new(10, 10)
  c:path("M0 0L10 10L0 10", { stroke = "#FFF" })
  c:path("M0 0L10 10")
  c:path("M0 0L10 10", { fill = "#F00" })
  local svg = c:finish()
  T.ok(string.find(svg, '<path d="M0 0L10 10L0 10" fill="none" stroke="#FFF"/>', 1, true) ~= nil, "stroke-only path is not filled")
  T.ok(string.find(svg, '<path d="M0 0L10 10" fill="none"/>', 1, true) ~= nil, "bare path is not filled")
  T.ok(string.find(svg, '<path d="M0 0L10 10" fill="#F00"/>', 1, true) ~= nil, "explicit fill kept")
end

function test_near_full_arcs()
  for _, r in ipairs({ 6, 10, 20, 50, 100 }) do
    for _, a1 in ipairs({ 359.5, 359.6, 359.9, 359.95, 359.99, -359.95 }) do
      local d = Svg.arcPath(100, 100, r, 0, a1)
      local n = nums(d)
      local label = "r=" .. r .. " sweep " .. a1
      if count(d, "A") == 1 then
        T.ok(n[1] ~= n[8] or n[2] ~= n[9], "single arc has distinct end points at " .. label)
      else
        T.eq(count(d, "A"), 2, "near-full sweep drawn as two arcs at " .. label)
      end
    end
  end
  T.ok(Svg.fullTurn(100, 100, 50, 0, 359.95), "359.95 at r=50 counts as a full turn")
  T.ok(not Svg.fullTurn(100, 100, 50, 0, 359.9), "359.9 at r=50 is still an arc")
  T.ok(not Svg.fullTurn(100, 100, 50, 0, 270), "270 is an arc")
  T.ok(Svg.fullTurn(100, 100, 50, 90, -270), "reverse full turn")
  local w = Svg.new(200, 200)
  w:wedge(100, 100, 50, 0, 359.95, { fill = "#F00" })
  T.ok(string.find(w:finish(), "<circle", 1, true) ~= nil, "near-full wedge is a circle")
  local rg = Svg.new(200, 200)
  rg:ring(100, 100, 50, 30, 0, 359.95, { fill = "#F00" })
  T.ok(string.find(rg:finish(), 'fill-rule="evenodd"', 1, true) ~= nil, "near-full ring is a full ring")
  local a = Svg.new(200, 200)
  a:arc(100, 100, 50, 0, 359.95, { stroke = "#FFF" })
  T.eq(count(string.match(a:finish(), 'd="([^"]*)"'), "A"), 2, "near-full arc keeps two arc commands")
end

function test_defs_survive_truncation()
  local c = Svg.new(100, 100, { limit = 2000 })
  for i = 1, 100 do c:rect(i, i, 10, 10, { fill = "url(#g)" }) end
  c:gradient("g", "linear", { { 0, "#000" }, { 1, "#FFF" } })
  c:clipRect("k", 0, 0, 10, 10)
  local svg = c:finish()
  T.ok(c.truncated, "truncated")
  T.ok(#svg <= 2000, "within the limit (" .. #svg .. ")")
  T.eq(#svg, c:len(), "len matches")
  T.ok(string.find(svg, '<linearGradient id="g"', 1, true) ~= nil, "gradient defined after the limit was hit")
  T.ok(string.find(svg, '<clipPath id="k"', 1, true) ~= nil, "clip defined after the limit was hit")
  T.ok(count(svg, "<rect") > 10, "ordinary elements still filled the rest")
  T.ok(balanced(svg), "balanced")
  local full = Svg.new(100, 100)
  T.eq(full.reserve, 2048, "default reserve")
  for i = 1, 1200 do full:rect(i, i, 10, 10, { fill = "#FFFFFF" }) end
  T.ok(full.truncated, "60k limit reached")
  full:gradient("late", "linear", { { 0, "#000" } })
  local fs = full:finish()
  T.ok(#fs <= 60000, "within 60000 (" .. #fs .. ")")
  T.ok(string.find(fs, '<linearGradient id="late"', 1, true) ~= nil, "late gradient defined at the default limit")
  local small = Svg.new(100, 100, { limit = 400 })
  T.eq(small.reserve, 50, "reserve is at most limit / 8")
end

function test_duplicate_and_bad_ids()
  local c = Svg.new(100, 100)
  for i = 1, 3 do
    c:clipRect("tile", i * 10, 0, 10, 10)
    c:gradient("g", "linear", { { 0, "#000" } })
  end
  c:clipRect("", 0, 0, 10, 10)
  c:clipRect("a b", 0, 0, 10, 10)
  c:clipRect("x)", 0, 0, 10, 10)
  c:clipRect(7, 0, 0, 10, 10)
  c:gradient(nil, "linear", { { 0, "#000" } })
  c:gradient("caf\195\169", "radial", { { 0, "#000" } })
  c:group({ clip = "" }, function(g) g:rect(0, 0, 1, 1) end)
  c:group({ clip = "a b" }, function(g) g:rect(0, 0, 1, 1) end)
  c:group({ clip = "tile" }, function(g) g:rect(0, 0, 1, 1) end)
  c:group({ clip = 7 }, function(g) g:rect(0, 0, 1, 1) end)
  local svg = c:finish()
  T.eq(count(svg, 'id="tile"'), 1, "one clipPath per id")
  T.eq(count(svg, 'id="g"'), 1, "one gradient per id")
  T.ok(string.find(svg, '<clipPath id="tile"><rect x="10"', 1, true) ~= nil, "first definition wins")
  T.eq(count(svg, "<clipPath"), 2, "invalid ids define nothing, a numeric id is accepted")
  T.ok(string.find(svg, '<clipPath id="7">', 1, true) ~= nil, "numeric id")
  T.eq(count(svg, "Gradient id="), 1, "nil and non-ascii ids define nothing")
  T.eq(count(svg, "clip-path"), 2, "blank or invalid clip references are omitted")
  T.ok(string.find(svg, '<g clip-path="url(#tile)">', 1, true) ~= nil, "valid clip reference kept")
  T.ok(string.find(svg, '<g clip-path="url(#7)">', 1, true) ~= nil, "numeric clip reference kept")
  T.ok(balanced(svg), "balanced")
end

function test_blank_attributes()
  local c = Svg.new(100, 100, { family = "" })
  c:rect(0, 0, 10, 10, { fill = "", stroke = "", dash = {}, class = "", cap = "", join = "" })
  c:group({ transform = "", opacity = nil }, function() end)
  c:gradient("g", "linear", { { 0, "" } })
  c:text(0, 0, "x", { fill = "", anchor = "", family = "" })
  c:line(0, 0, 1, 1, { dash = "" })
  c:line(0, 0, 1, 1, { dash = "  " })
  c:polyline({ 0, 0, 1, 1 }, { fill = "" })
  local svg = c:finish()
  T.ok(string.find(svg, '<rect x="0" y="0" width="10" height="10"/>', 1, true) ~= nil, "blank paint attributes omitted")
  T.ok(string.find(svg, "<g></g>", 1, true) ~= nil, "blank transform omitted")
  T.ok(string.find(svg, '<stop offset="0%"/>', 1, true) ~= nil, "blank stop colour omitted")
  T.ok(string.find(svg, '<text x="0" y="0" font-family="Roboto, sans-serif" font-size="14">x</text>', 1, true) ~= nil, "blank text attributes omitted and family falls back")
  T.eq(count(svg, '<line x1="0" y1="0" x2="1" y2="1"/>'), 2, "blank dash omitted")
  T.ok(string.find(svg, '<polyline points="0,0 1,1" fill="none"/>', 1, true) ~= nil, "blank fill falls back to the default")
  T.ok(string.find(svg, '=""', 1, true) == nil, "no empty attribute values")
  T.ok(string.find(svg, "url(#)", 1, true) == nil, "no empty url reference")
  T.eq(Svg.familyAttr("  "), ' font-family="Roboto, sans-serif"', "whitespace family falls back")
end
