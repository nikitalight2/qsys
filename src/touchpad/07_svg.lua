-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: svg (Canvas: SVG string builder, pure ASCII output)
--
-- Every attribute value goes through val(): numbers via Svg.num, strings via
-- U.ascii, so the canvas never emits a byte above 126. Elements are appended
-- in call order. A character limit drops elements once reached (c.truncated).

Svg = Svg or {}

local floor, abs, cos, sin, pi, min = math.floor, math.abs, math.cos, math.sin, math.pi, math.min
local sformat, concat, sfind = string.format, table.concat, string.find

-- ---------- number and colour helpers ----------

local NUM_MAX = 1e9   -- magnitudes are clamped here so n * 100 stays an exact integer

-- Finite number or nil: numeric strings are converted, NaN and inf give nil.
local function finite(n)
  if type(n) ~= "number" then n = tonumber(n) end
  if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
  if n > NUM_MAX then return NUM_MAX end
  if n < -NUM_MAX then return -NUM_MAX end
  return n
end
Svg.finite = finite

-- Number to string, at most 1 decimal, no trailing ".0", "-0" -> "0".
-- Memoised: coordinates repeat on every frame, so most calls are one lookup.
local NUMS, numCount, NUM_CACHE_MAX = {}, 0, 4096

local function numFormat(n)
  local r = floor(n * 10 + 0.5)
  if r == 0 then return "0" end
  if r % 10 == 0 then return sformat("%d", r // 10) end
  return sformat("%.1f", r / 10)
end

-- NaN, inf, nil and non-numeric strings give "0"; |n| is clamped to NUM_MAX.
function Svg.num(n)
  local hit = NUMS[n]
  if hit then return hit end
  local v = finite(n)
  if v == nil then return "0" end
  local r = numFormat(v)
  if type(n) == "number" then
    if numCount >= NUM_CACHE_MAX then NUMS = {}; numCount = 0 end
    NUMS[n] = r
    numCount = numCount + 1
  end
  return r
end
local num = Svg.num

-- Fraction (opacity, gradient stops, icon scale): at most 2 decimals. Same
-- guards as Svg.num; values above 1 are kept because scale factors use it.
function Svg.frac(n)
  n = finite(n)
  if n == nil then return "0" end
  local r = floor(n * 100 + 0.5)
  if r == 0 then return "0" end
  if r % 100 == 0 then return sformat("%d", r // 100) end
  if r % 10 == 0 then return sformat("%.1f", r / 100) end
  return sformat("%.2f", r / 100)
end
local frac = Svg.frac

-- Blend two "#rrggbb" colours; t = 0 gives hexA, t = 1 gives hexB.
function Svg.mix(hexA, hexB, t)
  local r1, g1, b1 = U.hexToRgb(hexA)
  local r2, g2, b2 = U.hexToRgb(hexB)
  if not r1 then return hexB or "#000000" end
  if not r2 then return hexA end
  t = U.clamp(t or 0.5, 0, 1)
  return U.rgbToHex(U.lerp(r1, r2, t), U.lerp(g1, g2, t), U.lerp(b1, b2, t))
end

-- amount -1..1: positive moves toward white, negative toward black.
function Svg.lighten(hex, amount)
  amount = U.clamp(amount or 0, -1, 1)
  if amount >= 0 then return Svg.mix(hex, "#FFFFFF", amount) end
  return Svg.mix(hex, "#000000", -amount)
end

-- Alpha never goes into the colour string; use o.opacity. Returns hex, a.
function Svg.withAlpha(hex, a)
  return hex, a
end

-- ---------- attribute helpers ----------

local ascii = U.ascii

-- nil, "" and whitespace-only strings count as an absent attribute value
local function blank(v)
  if v == nil then return true end
  if type(v) == "string" then return sfind(v, "%S") == nil end
  return false
end

-- lengths (width, height, radii, stroke width, font size) are never negative
local function nonneg(v)
  if type(v) == "number" and v >= 0 then return num(v) end
  v = finite(v)
  if v == nil or v < 0 then return "0" end
  return num(v)
end

-- opacity attributes are clamped to 0..1 (NaN and non-numbers give 0)
local function alpha(v)
  if type(v) == "number" and v >= 0 and v <= 1 then return frac(v) end
  v = tonumber(v)
  if v == nil or v ~= v then return "0" end
  return frac(U.clamp(v, 0, 1))
end

-- ids must be non-empty ASCII words (letters, digits, "_", "-", ".") so that
-- url(#id) stays well formed; anything else yields nil
local function cleanId(id)
  if id == nil then return nil end
  id = tostring(id)
  if sfind(id, "^[%w_%-%.]+$") then return id end
  return nil
end

local function val(v)
  if type(v) == "number" then return num(v) end
  return ascii(v)
end

local function attr(name, v)
  if blank(v) then return "" end
  return " " .. name .. '="' .. val(v) .. '"'
end

local function dashAttr(d)
  if type(d) == "table" then
    if #d == 0 then return "" end
    local parts = {}
    for i = 1, #d do parts[i] = num(d[i]) end
    d = concat(parts, " ")
  end
  if blank(d) then return "" end
  return ' stroke-dasharray="' .. ascii(d) .. '"'
end

-- fill, stroke, sw, opacity, dash, cap, join, class (all optional; nil and
-- "" are treated as absent, the checks are inlined because paint runs for
-- every element of every frame)
local function paint(o, defaultFill)
  if not o then
    if defaultFill then return ' fill="' .. defaultFill .. '"' end
    return ""
  end
  local fill, stroke, cap, join, class = o.fill, o.stroke, o.cap, o.join, o.class
  if fill == nil or fill == "" then fill = defaultFill end
  local s = fill and (' fill="' .. ascii(fill) .. '"') or ""
  if stroke ~= nil and stroke ~= "" then s = s .. ' stroke="' .. ascii(stroke) .. '"' end
  if o.sw ~= nil then s = s .. ' stroke-width="' .. nonneg(o.sw) .. '"' end
  if o.opacity ~= nil then s = s .. ' opacity="' .. alpha(o.opacity) .. '"' end
  if o.dash ~= nil then s = s .. dashAttr(o.dash) end
  if cap ~= nil and cap ~= "" then s = s .. ' stroke-linecap="' .. ascii(cap) .. '"' end
  if join ~= nil and join ~= "" then s = s .. ' stroke-linejoin="' .. ascii(join) .. '"' end
  if class ~= nil and class ~= "" then s = s .. ' class="' .. ascii(class) .. '"' end
  return s
end

-- ---------- canvas ----------

local Canvas = {}
Canvas.__index = Canvas

local SVG_NS = 'xmlns="http://www.w3.org/2000/svg"'
local DEFS_RESERVE = 2048   -- characters kept free for <defs> (at most limit / 8)

function Svg.new(w, h, opts)
  opts = opts or {}
  local c = setmetatable({}, Canvas)
  c.w, c.h = w, h
  c.family = opts.family or "Roboto"
  c.familyAttr = Svg.familyAttr(c.family)
  c.limit = opts.limit or 60000
  c.reserve = min(DEFS_RESERVE, c.limit // 8)
  c.header = "<svg " .. SVG_NS .. ' viewBox="0 0 ' .. nonneg(w) .. " " .. nonneg(h) .. '" width="' .. nonneg(w)
    .. '" height="' .. nonneg(h) .. '">'
  c.parts = {}
  c.defs = {}
  c.defChars = 0
  c.ids = {}
  c.chars = #c.header + 6        -- "</svg>" reserved
  c.truncated = false
  c.depth = 0
  return c
end

-- appends s when it fits the limit (keeping the unused part of the defs
-- reserve free); otherwise marks truncated and drops it
local function add(c, s, reserve)
  local keep = c.reserve - c.defChars
  if keep < 0 then keep = 0 end
  if c.truncated or c.chars + #s + (reserve or 0) + keep > c.limit then
    c.truncated = true
    return false
  end
  c.parts[#c.parts + 1] = s
  c.chars = c.chars + #s
  return true
end

-- defs may use the whole limit including the reserve, so a gradient or clip
-- defined after its consumers still gets in when ordinary parts were dropped
local function addDef(c, s)
  local extra = (#c.defs == 0) and 13 or 0      -- "<defs></defs>"
  if c.chars + #s + extra > c.limit then
    c.truncated = true
    return false
  end
  c.defs[#c.defs + 1] = s
  c.chars = c.chars + #s + extra
  c.defChars = c.defChars + #s + extra
  return true
end

function Canvas:len()
  return self.chars
end

-- appended as-is apart from bytes that are not printable ASCII: control
-- bytes, DEL and anything above 126 become "?" (tab, LF and CR are kept)
function Canvas:raw(s)
  if s == nil then return self end
  s = tostring(s):gsub("[%z\1-\8\11\12\14-\31\127-\255]", "?")
  add(self, s)
  return self
end

function Canvas:rect(x, y, w, h, o)
  local s = '<rect x="' .. num(x) .. '" y="' .. num(y) .. '" width="' .. nonneg(w) .. '" height="' .. nonneg(h) .. '"'
  if o then
    if o.rx ~= nil then s = s .. ' rx="' .. nonneg(o.rx) .. '"' end
    if o.ry ~= nil then s = s .. ' ry="' .. nonneg(o.ry) .. '"' end
  end
  add(self, s .. paint(o) .. "/>")
  return self
end

function Canvas:circle(cx, cy, r, o)
  add(self, '<circle cx="' .. num(cx) .. '" cy="' .. num(cy) .. '" r="' .. nonneg(r) .. '"' .. paint(o) .. "/>")
  return self
end

function Canvas:ellipse(cx, cy, rx, ry, o)
  add(self, '<ellipse cx="' .. num(cx) .. '" cy="' .. num(cy) .. '" rx="' .. nonneg(rx) .. '" ry="' .. nonneg(ry) .. '"'
    .. paint(o) .. "/>")
  return self
end

function Canvas:line(x1, y1, x2, y2, o)
  add(self, '<line x1="' .. num(x1) .. '" y1="' .. num(y1) .. '" x2="' .. num(x2) .. '" y2="' .. num(y2) .. '"'
    .. paint(o) .. "/>")
  return self
end

local function pointList(points)
  local parts = {}
  local n = #points - (#points % 2)
  for i = 1, n, 2 do
    parts[#parts + 1] = num(points[i]) .. "," .. num(points[i + 1])
  end
  return concat(parts, " ")
end

-- flat array; o.close -> <polygon>; fill defaults to "none"
function Canvas:polyline(points, o)
  local tag = (o and o.close) and "polygon" or "polyline"
  add(self, "<" .. tag .. ' points="' .. pointList(points) .. '"' .. paint(o, "none") .. "/>")
  return self
end

-- fill defaults to "none" (a stroke-only path would otherwise be filled black)
function Canvas:path(d, o)
  add(self, '<path d="' .. ascii(d) .. '"' .. paint(o, "none") .. "/>")
  return self
end

-- point on a circle: 0 = right, positive = counter-clockwise on screen (y down)
local function polar(cx, cy, r, deg)
  local a = deg * pi / 180
  return cx + r * cos(a), cy - r * sin(a)
end
Svg.polar = polar

local function pt(x, y)
  return num(x) .. " " .. num(y)
end

-- "A r r 0 large sweep x y" from angle a0 to a1 on a circle of radius r
local function arcTo(cx, cy, r, a0, a1)
  local delta = a1 - a0
  local large = (abs(delta) > 180) and 1 or 0
  local sweep = (delta > 0) and 0 or 1
  local x, y = polar(cx, cy, r, a1)
  return "A" .. num(r) .. " " .. num(r) .. " 0 " .. large .. " " .. sweep .. " " .. pt(x, y)
end

-- A sweep counts as a full turn when it covers 360 degrees or when its
-- rounded end point lands on its rounded start point: renderers drop an arc
-- whose end points coincide, so a 359.95 degree arc would vanish.
local function fullTurn(cx, cy, r, a0, a1)
  local delta = abs(a1 - a0)
  if delta >= 360 then return true end
  if delta <= 180 then return false end
  local x0, y0 = polar(cx, cy, r, a0)
  local x1, y1 = polar(cx, cy, r, a1)
  return pt(x0, y0) == pt(x1, y1)
end
Svg.fullTurn = fullTurn

-- arc path from a0 to a1; a full turn is split into two halves
local function arcPath(cx, cy, r, a0, a1)
  local x0, y0 = polar(cx, cy, r, a0)
  if fullTurn(cx, cy, r, a0, a1) then
    local half = (a1 > a0) and 180 or -180
    return "M" .. pt(x0, y0) .. arcTo(cx, cy, r, a0, a0 + half) .. arcTo(cx, cy, r, a0 + half, a0 + 2 * half), x0, y0
  end
  return "M" .. pt(x0, y0) .. arcTo(cx, cy, r, a0, a1), x0, y0
end
Svg.arcPath = arcPath

-- degrees, 0 = right, positive = counter-clockwise (screen y down), stroke only
function Canvas:arc(cx, cy, r, a0, a1, o)
  o = o or {}
  local d = arcPath(cx, cy, r, a0, a1)
  add(self, '<path d="' .. d .. '"' .. paint(o, "none") .. "/>")
  return self
end

-- filled sector (pie slice)
function Canvas:wedge(cx, cy, r, a0, a1, o)
  if fullTurn(cx, cy, r, a0, a1) then return self:circle(cx, cy, r, o) end
  local x0, y0 = polar(cx, cy, r, a0)
  local d = "M" .. pt(cx, cy) .. "L" .. pt(x0, y0) .. arcTo(cx, cy, r, a0, a1) .. "Z"
  add(self, '<path d="' .. d .. '"' .. paint(o) .. "/>")
  return self
end

-- filled annular sector
function Canvas:ring(cx, cy, rOuter, rInner, a0, a1, o)
  local d
  if fullTurn(cx, cy, rOuter, a0, a1) then
    local outer = arcPath(cx, cy, rOuter, 0, 360)
    local inner = arcPath(cx, cy, rInner, 0, 360)
    d = outer .. "Z" .. inner .. "Z"
    add(self, '<path d="' .. d .. '" fill-rule="evenodd"' .. paint(o) .. "/>")
    return self
  end
  local ox, oy = polar(cx, cy, rOuter, a0)
  local ix, iy = polar(cx, cy, rInner, a1)
  d = "M" .. pt(ox, oy) .. arcTo(cx, cy, rOuter, a0, a1) .. "L" .. pt(ix, iy) .. arcTo(cx, cy, rInner, a1, a0) .. "Z"
  add(self, '<path d="' .. d .. '"' .. paint(o) .. "/>")
  return self
end

local BASELINES = { middle = "middle", hanging = "hanging" }

-- font-family attribute: "<family>, Roboto, sans-serif"
function Svg.familyAttr(family)
  if blank(family) or family == "Roboto" then return ' font-family="Roboto, sans-serif"' end
  return ' font-family="' .. ascii(family) .. ', Roboto, sans-serif"'
end

-- o: size (14), fill, anchor, weight, family, baseline, opacity, spacing
function Canvas:text(x, y, str, o)
  local s = '<text x="' .. num(x) .. '" y="' .. num(y) .. '"'
  if not o then
    add(self, s .. self.familyAttr .. ' font-size="14">' .. ascii(str) .. "</text>")
    return self
  end
  s = s .. (o.family and Svg.familyAttr(o.family) or self.familyAttr) .. ' font-size="' .. nonneg(o.size or 14) .. '"'
  if not blank(o.fill) then s = s .. ' fill="' .. ascii(o.fill) .. '"' end
  if not blank(o.anchor) and o.anchor ~= "start" then s = s .. ' text-anchor="' .. ascii(o.anchor) .. '"' end
  if o.weight == "bold" then s = s .. ' font-weight="bold"' end
  if BASELINES[o.baseline] then s = s .. ' dominant-baseline="' .. BASELINES[o.baseline] .. '"' end
  if o.opacity ~= nil then s = s .. ' opacity="' .. alpha(o.opacity) .. '"' end
  if o.spacing then s = s .. ' letter-spacing="' .. num(o.spacing) .. '"' end
  add(self, s .. ">" .. ascii(str) .. "</text>")
  return self
end

-- Font.fit then text; returns the drawn string
function Canvas:textFit(x, y, maxW, str, o)
  o = o or {}
  local drawn = Font.fit(str, o.size or 14, maxW, o.weight)
  if drawn ~= "" then self:text(x, y, drawn, o) end
  return drawn
end

-- o: opacity, transform, clip (clipPath id); fn(c) draws the children
function Canvas:group(o, fn)
  o = o or {}
  local open = "<g"
  local clip = cleanId(o.clip)
  if o.opacity ~= nil then open = open .. ' opacity="' .. alpha(o.opacity) .. '"' end
  if not blank(o.transform) then open = open .. ' transform="' .. ascii(o.transform) .. '"' end
  if clip then open = open .. ' clip-path="url(#' .. clip .. ')"' end
  open = open .. ">"
  if not add(self, open, 4) then return self end
  self.chars = self.chars + 4                -- "</g>" reserved
  self.depth = self.depth + 1
  if fn then fn(self) end
  self.depth = self.depth - 1
  self.parts[#self.parts + 1] = "</g>"
  return self
end

-- id of a new def, or nil when the id is invalid or already defined on this
-- canvas (the first definition wins, so every id stays unique)
local function defId(c, id)
  id = cleanId(id)
  if id == nil or c.ids[id] then return nil end
  return id
end

function Canvas:clipRect(id, x, y, w, h, rx)
  id = defId(self, id)
  if id == nil then return self end
  local s = '<clipPath id="' .. id .. '"><rect' .. attr("x", x) .. attr("y", y) .. ' width="' .. nonneg(w)
    .. '" height="' .. nonneg(h) .. '"'
  if rx ~= nil then s = s .. ' rx="' .. nonneg(rx) .. '"' end
  if addDef(self, s .. "/></clipPath>") then self.ids[id] = true end
  return self
end

local function pct(v, default)
  if v == nil then v = default end
  return num(v * 100) .. "%"
end

local function stopList(stops)
  local parts = {}
  for i = 1, #stops do
    local s = stops[i]
    parts[i] = "<stop" .. attr("offset", pct(s[1], 0)) .. attr("stop-color", s[2])
      .. (s[3] ~= nil and (' stop-opacity="' .. alpha(s[3]) .. '"') or "") .. "/>"
  end
  return concat(parts)
end

-- kind "linear"|"radial"; stops = { {offset, color, opacity}, ... }
-- linear o: x1, y1, x2, y2 in 0..1 (default top to bottom); radial o: cx, cy, r, fx, fy in 0..1
function Canvas:gradient(id, kind, stops, o)
  o = o or {}
  id = defId(self, id)
  if id == nil then return self end
  local s
  if kind == "radial" then
    s = '<radialGradient id="' .. id .. '"' .. attr("cx", pct(o.cx, 0.5)) .. attr("cy", pct(o.cy, 0.5))
      .. attr("r", pct(o.r, 0.5)) .. attr("fx", o.fx and pct(o.fx)) .. attr("fy", o.fy and pct(o.fy)) .. ">"
      .. stopList(stops or {}) .. "</radialGradient>"
  else
    s = '<linearGradient id="' .. id .. '"' .. attr("x1", pct(o.x1, 0)) .. attr("y1", pct(o.y1, 0))
      .. attr("x2", pct(o.x2, 0)) .. attr("y2", pct(o.y2, 1)) .. ">" .. stopList(stops or {}) .. "</linearGradient>"
  end
  if addDef(self, s) then self.ids[id] = true end
  return self
end

function Canvas:finish()
  local defs = ""
  if #self.defs > 0 then defs = "<defs>" .. concat(self.defs) .. "</defs>" end
  return self.header .. defs .. concat(self.parts) .. "</svg>"
end
