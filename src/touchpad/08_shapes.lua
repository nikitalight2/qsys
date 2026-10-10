-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: shapes (pad frame, hints, tiles, arrow bars, lock overlay, targets, icons)
--
-- Shared drawing on top of the Canvas (07_svg.lua). Every function takes the
-- canvas first and the theme table T second (except the icon helpers). Icons
-- are stroke paths on a 24 x 24 grid placed with a translate/scale group, so
-- one icon costs one raw element and well under 400 characters.

Shapes = Shapes or {}

local floor, min, max = math.floor, math.min, math.max
local concat = table.concat
local num, frac = Svg.num, Svg.frac

-- ---------- pad frame, hint, title ----------

-- background "Solid" | "Transparent" | "Panel"; unknown values draw Solid.
-- Transparent draws nothing so the UCI shows through.
function Shapes.padFrame(c, T, W, H, radius, background)
  if background == "Transparent" then return c end
  radius = radius or 0
  local fill = (background == "Panel") and T.panel or T.bg
  c:rect(0, 0, W, H, { fill = fill, rx = radius })
  c:rect(0.5, 0.5, W - 1, H - 1, { fill = "none", stroke = T.line, sw = 1, rx = radius })
  return c
end

-- Bottom-centre muted text, 12 px, only when text is non-empty.
function Shapes.hint(c, T, text, W, H)
  if text == nil or text == "" then return c end
  c:textFit(W / 2, H - 8, W - 16, text, { size = 12, fill = T.muted, anchor = "middle" })
  return c
end

-- Top-centre bold title, 15 px, only when text is non-empty.
function Shapes.title(c, T, text, W)
  if text == nil or text == "" then return c end
  c:textFit(W / 2, 22, W - 24, text, { size = 15, fill = T.text, anchor = "middle", weight = "bold" })
  return c
end

-- ---------- grid, crosshair, dot ----------

local MAX_DOTS = 400

-- Dots every `step` px, centred on the pad, as one path (round caps make the
-- short dashes round). At most MAX_DOTS dots: the step doubles until it fits.
function Shapes.gridDots(c, T, W, H, step)
  step = max(step or 24, 8)
  local cols, rows = floor(W / step), floor(H / step)
  for _ = 1, 12 do
    if cols * rows <= MAX_DOTS then break end
    step = step * 2
    cols, rows = floor(W / step), floor(H / step)
  end
  if cols < 1 or rows < 1 then return c end
  local x0 = (W - (cols - 1) * step) / 2
  local y0 = (H - (rows - 1) * step) / 2
  local parts, n = {}, 0
  for j = 0, rows - 1 do
    local ys = num(y0 + j * step)
    for i = 0, cols - 1 do
      n = n + 1
      parts[n] = "M" .. num(x0 + i * step) .. " " .. ys .. "h0.5"
    end
  end
  c:path(concat(parts), { fill = "none", stroke = T.line, sw = 2, cap = "round", opacity = 0.8 })
  return c
end

-- Dashed hairlines through (x, y) across the whole pad plus a small ring.
function Shapes.crosshair(c, T, x, y, W, H)
  local o = { stroke = T.line, sw = 1, dash = { 4, 4 }, opacity = 0.7 }
  c:line(0, y, W, y, o)
  c:line(x, 0, x, H, o)
  c:circle(x, y, 6, { fill = "none", stroke = T.accent, sw = 1.5 })
  return c
end

-- Accent dot with a soft halo (finger / value marker).
function Shapes.dot(c, T, x, y, r)
  r = r or 8
  c:circle(x, y, r * 1.8, { fill = T.accent, opacity = 0.25 })
  c:circle(x, y, r, { fill = T.accent, stroke = T.onAccent, sw = 1 })
  return c
end

-- ---------- tiles ----------

local TILE_PAD = 8

local function tileBox(c, T, x, y, w, h, o, accent)
  local radius = o.radius or min(8, h / 4)
  local fill = o.on and accent or T.panel
  if o.picked then
    c:rect(x + 1.5, y + 1.5, w - 3, h - 3, { fill = fill, stroke = accent, sw = 3, rx = radius })
  else
    c:rect(x + 0.5, y + 0.5, w - 1, h - 1, { fill = fill, stroke = o.stroke or T.line, sw = 1, rx = radius })
  end
end

local function tileText(c, T, x, y, w, h, label, o, iconW)
  local tx = x + TILE_PAD + iconW
  local maxW = w - 2 * TILE_PAD - iconW
  local size = o.size or 14
  local fill = o.on and T.onAccent or T.text
  if o.sub and o.sub ~= "" then
    local drawn = c:textFit(tx, y + h / 2 - 2, maxW, label, { size = size, fill = fill })
    c:textFit(tx, y + h / 2 + 12, maxW, o.sub,
      { size = 11, fill = o.on and T.onAccent or T.muted, opacity = o.on and 0.8 or nil })
    return drawn
  end
  return c:textFit(tx, y + h / 2 + size * 0.35, maxW, label, { size = size, fill = fill })
end

local function tileBody(c, T, x, y, w, h, label, o)
  local accent = o.accent or T.accent
  tileBox(c, T, x, y, w, h, o, accent)
  local iconW = 0
  if o.icon then
    local s = min(24, h * 0.6)
    Shapes.icon(c, o.icon, x + TILE_PAD + s / 2, y + h / 2, s, o.on and T.onAccent or T.muted)
    iconW = s + 6
  end
  return tileText(c, T, x, y, w, h, label or "", o, iconW)
end

-- o: on, dim, icon, sub, radius, accent, stroke, picked, size. Returns the
-- label as drawn (fitted to the tile width).
function Shapes.tile(c, T, x, y, w, h, label, o)
  o = o or {}
  if not o.dim then return tileBody(c, T, x, y, w, h, label, o) end
  local drawn = ""
  c:group({ opacity = 0.45 }, function(g)
    drawn = tileBody(g, T, x, y, w, h, label, o)
  end)
  return drawn
end

-- ---------- arrow bar ----------

local function arrowHalf(c, T, x, y, w, h, on, icon, ix, radius)
  local function body(g)
    g:rect(x + 0.5, y + 0.5, w - 1, h - 1, { fill = T.panel, stroke = T.line, sw = 1, rx = radius })
    Shapes.icon(g, icon, ix, y + h / 2, h * 0.55, on and T.text or T.muted)
  end
  if on then body(c) else c:group({ opacity = 0.3 }, body) end
end

-- Two halves with chevrons; a half with no page that way is drawn at 30 %
-- opacity. pageText (e.g. "2 / 5") sits between the chevrons.
function Shapes.arrowBar(c, T, x, y, w, h, leftOn, rightOn, pageText)
  local half = w / 2
  local radius = min(8, h / 3)
  arrowHalf(c, T, x, y, half - 1, h, leftOn, "chevronLeft", x + h / 2, radius)
  arrowHalf(c, T, x + half + 1, y, half - 1, h, rightOn, "chevronRight", x + w - h / 2, radius)
  if pageText and pageText ~= "" then
    c:textFit(x + w / 2, y + h / 2 + 4, max(w - 2 * h - 16, 0), pageText,
      { size = 12, fill = T.muted, anchor = "middle" })
  end
  return c
end

-- ---------- lock overlay, calibration targets ----------

function Shapes.lockOverlay(c, T, W, H)
  local s = U.clamp(min(W, H) * 0.22, 24, 96)
  c:rect(0, 0, W, H, { fill = T.bg, opacity = 0.72 })
  Shapes.icon(c, "lock", W / 2, H / 2 - 8, s, T.muted)
  c:text(W / 2, H / 2 + s / 2 + 14, "Locked", { size = 14, fill = T.muted, anchor = "middle" })
  return c
end

local function target(c, T, x, y)
  c:circle(x, y, 14, { fill = "none", stroke = T.accent, sw = 2 })
  c:line(x - 22, y, x + 22, y, { stroke = T.accent, sw = 1 })
  c:line(x, y - 22, x, y + 22, { stroke = T.accent, sw = 1 })
  c:circle(x, y, 3, { fill = T.accent })
end

-- Two targets 12 % in from the top-left and bottom-right corners.
-- Returns their centres: {x=, y=}, {x=, y=}.
function Shapes.targets(c, T, W, H)
  local x1, y1 = W * 0.12, H * 0.12
  local x2, y2 = W * 0.88, H * 0.88
  target(c, T, x1, y1)
  target(c, T, x2, y2)
  return { x = x1, y = y1 }, { x = x2, y = y2 }
end

-- ---------- icons ----------

-- Stroke paths on a 24 x 24 grid (centre 12, 12), stroke width 2, round caps.
local ICONS = {
  laptop = "M4 5h16v10H4z M2 19h20 M10 8h4",
  pc = "M3 5h11v10H3z M8.5 15v3 M5 18h7 M17 4h4v16h-4z M19 7v1 M19 10v1",
  teams = "M4 4h16v12h-9l-4 4v-4H4z M9 8h6 M12 8v5",
  zoom = "M3 7h12v10H3z M15 10l5-3v10l-5-3",
  webex = "M12 4a8 8 0 1 0 0 16a8 8 0 1 0 0-16 M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6",
  camera = "M3 8h4l2-3h6l2 3h4v11H3z M12 10.5a3 3 0 1 0 0 6a3 3 0 1 0 0-6",
  doccam = "M3 20h18 M6 20V6 M6 6h8 M14 4h4v5h-4z M16 9v3",
  appletv = "M3 7h18v10H3z M8 20h8 M10 10l4 2-4 2z",
  clickshare = "M12 11a5 5 0 1 0 0 10a5 5 0 1 0 0-10 M12 11V3 M9 6h6",
  mic = "M9 6a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0z M6 11a6 6 0 0 0 12 0 M12 17v4 M9 21h6",
  music = "M9 18V6l10-2v12 M6.5 18a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0 M16.5 16a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0",
  display = "M2 4h20v13H2z M8 21h8 M12 17v4",
  projector = "M2 9h20v8H2z M15.5 13a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0 M6 17v2 M18 17v2 M5 13h6",
  room = "M3 3h18v18H3z M11 3v8 M11 15v6 M3 12h8",
  person = "M12 4a4 4 0 1 0 0 8a4 4 0 1 0 0-8 M4 21a8 7 0 0 1 16 0",
  lock = "M7 10V7a5 5 0 0 1 10 0v3 M5 10h14v11H5z M12 15v2",
  unlock = "M7 10V7a5 5 0 0 1 9-3 M5 10h14v11H5z M12 15v2",
  home = "M3 11l9-8 9 8 M5 10v11h14V10 M10 21v-6h4v6",
  up = "M12 20V4 M5 11l7-7 7 7",
  down = "M12 4v16 M5 13l7 7 7-7",
  left = "M20 12H4 M11 5l-7 7 7 7",
  right = "M4 12h16 M13 5l7 7-7 7",
  chevronLeft = "M15 5l-7 7 7 7",
  chevronRight = "M9 5l7 7-7 7",
  plus = "M12 5v14 M5 12h14",
  minus = "M5 12h14",
  cross = "M6 6l12 12 M18 6L6 18",
  check = "M4 12l5 5L20 7",
  undo = "M9 14L4 9l5-5 M4 9h11a5 5 0 0 1 0 10h-3",
  eraser = "M17 3l4 4L10 18H6l-3-3L17 3z M6 21h15 M9 9l6 6",
  pen = "M4 20l1-5L16 4l4 4L9 19z M14 6l4 4",
  bookmark = "M6 3h12v18l-6-4-6 4z",
  grid = "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z",
  signal = "M4 20v-4 M9 20v-8 M14 20v-12 M19 20V4",
  phone = "M5 3h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 12l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 5a2 2 0 0 1 2-2z",
  hdmi = "M2 8h20v5l-3 3H5l-3-3z M7 11h10 M9 14h6",
  wireless = "M2 9a15 15 0 0 1 20 0 M6 13a9 9 0 0 1 12 0 M9.5 16.5a4 4 0 0 1 5 0 M11.5 20h1",
}
Shapes.ICONS = ICONS

function Shapes.iconNames()
  return U.keys(ICONS)
end

-- Rendered <path> per (name, colour), bounded cache.
local BODY, bodyCount, BODY_MAX = {}, 0, 128

local function iconBody(name, color)
  local d = ICONS[name]
  if not d then return nil end
  local key = name .. color
  local hit = BODY[key]
  if hit then return hit end
  local s = '<path d="' .. d .. '" fill="none" stroke="' .. U.ascii(color)
    .. '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
  if bodyCount >= BODY_MAX then BODY = {}; bodyCount = 0 end
  BODY[key] = s
  bodyCount = bodyCount + 1
  return s
end

-- Compact vector icon centred at (x, y), `size` px tall and wide.
-- Unknown names draw a small circle.
function Shapes.icon(c, name, x, y, size, color)
  size = size or 24
  color = color or "#FFFFFF"
  if size <= 0 then return c end
  local body = iconBody(name, color)
  if not body then
    c:circle(x, y, size * 0.25, { fill = "none", stroke = color, sw = 2 })
    return c
  end
  local k = size / 24
  c:raw('<g transform="translate(' .. num(x - 12 * k) .. " " .. num(y - 12 * k) .. ") scale(" .. frac(k) .. ')">'
    .. body .. "</g>")
  return c
end

-- ---------- icon from a source / destination name ----------

local WORD_ICON = {
  laptop = "laptop", pc = "pc", computer = "pc", teams = "teams", zoom = "zoom", webex = "webex",
  codec = "phone", call = "phone", phone = "phone", camera = "camera", cam = "camera",
  doc = "doccam", doccam = "doccam", document = "doccam", apple = "appletv", clickshare = "clickshare",
  mic = "mic", music = "music", audio = "music", player = "music",
  display = "display", screen = "display", tv = "display", projector = "projector",
  room = "room", hall = "room", hdmi = "hdmi", wireless = "wireless", airplay = "wireless", cast = "wireless",
}
Shapes.WORD_ICON = WORD_ICON

local DEST_KINDS = { destination = true, dest = true, dst = true, output = true, sink = true }

-- kind names a destination in any case: one of DEST_KINDS or a word that
-- starts with "dest" or "out" (plurals and property labels included).
local function isDestination(kind)
  if kind == nil then return false end
  local k = U.lower(kind)
  return DEST_KINDS[k] == true or U.startsWith(k, "dest") or U.startsWith(k, "out")
end
Shapes.isDestination = isDestination

-- Whole-word match on the name, first matching word wins. Default: "display"
-- for destinations (see isDestination), "laptop" otherwise.
function Shapes.iconFor(name, kind)
  local words = U.wordsOf(name)
  for i = 1, #words do
    local icon = WORD_ICON[words[i]]
    if icon then return icon end
  end
  if isDestination(kind) then return "display" end
  return "laptop"
end
