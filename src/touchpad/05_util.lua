-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: util (pure helpers: numbers, strings, UTF-8, tables, geometry)
--
-- No Q-SYS dependency. Every loop is bounded by the size of its input so a
-- call never approaches the Core's per-callback instruction limit.

U = U or {}

local floor, abs, sqrt, atan, pi = math.floor, math.abs, math.sqrt, math.atan, math.pi
local sbyte, schar, sfind, ssub, sformat = string.byte, string.char, string.find, string.sub, string.format
local concat = table.concat

-- ---------- numbers ----------

-- NaN never compares, so it is pinned to lo instead of passing through.
function U.clamp(v, lo, hi)
  if v ~= v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function U.lerp(a, b, t)
  return a + (b - a) * t
end

function U.round(v, decimals)
  if not decimals or decimals <= 0 then
    return floor(v + 0.5)
  end
  local m = 10 ^ decimals
  return floor(v * m + 0.5) / m
end

function U.dist(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return sqrt(dx * dx + dy * dy)
end

-- Screen coordinates (y grows downwards): 0 = right, 90 = up, result in -180..180.
function U.angleDeg(dx, dy)
  if dx == 0 and dy == 0 then return 0 end
  return atan(-dy, dx) * 180 / pi
end

-- Wraps any angle into (-180, 180].
function U.normAngle(deg)
  local a = deg % 360
  if a > 180 then a = a - 360 end
  return a
end

-- Two-digit zero-padded integer; NaN, infinities and values outside the
-- integer range give "00" instead of an error.
function U.pad2(n)
  n = floor(tonumber(n) or 0)
  if math.type(n) ~= "integer" then return "00" end
  return sformat("%02d", n)
end

-- ---------- strings ----------

function U.split(s, sep)
  local out = {}
  if s == nil then return out end
  s = tostring(s)
  if sep == nil or sep == "" then
    out[1] = s
    return out
  end
  local pos = 1
  local n = #s
  while pos <= n + 1 do
    local a, b = sfind(s, sep, pos, true)
    if not a then
      out[#out + 1] = ssub(s, pos)
      break
    end
    out[#out + 1] = ssub(s, pos, a - 1)
    pos = b + 1
    if pos > n then out[#out + 1] = ""; break end
  end
  return out
end

function U.trim(s)
  if s == nil then return "" end
  return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

function U.startsWith(s, p)
  if s == nil or p == nil then return false end
  return ssub(s, 1, #p) == p
end

function U.lower(s)
  if s == nil then return "" end
  return string.lower(tostring(s))
end

-- Lower-case words made of letters and digits only.
function U.wordsOf(s)
  local out = {}
  if s == nil then return out end
  for w in string.gmatch(string.lower(tostring(s)), "%w+") do
    out[#out + 1] = w
  end
  return out
end

function U.hasWord(s, word)
  if s == nil or word == nil then return false end
  local want = string.lower(tostring(word))
  local words = U.wordsOf(s)
  for i = 1, #words do
    if words[i] == want then return true end
  end
  return false
end

-- ---------- UTF-8 ----------

-- Decodes one code point at byte index i. Returns cp, nextIndex.
-- Invalid or truncated sequences yield 63 ("?") and advance one byte.
local function utf8next(s, i)
  local b = sbyte(s, i)
  if b < 0x80 then return b, i + 1 end
  local need, cp, lo2, hi2 = 0, 0, 0x80, 0xBF
  if b >= 0xC2 and b <= 0xDF then need, cp = 1, b - 0xC0
  elseif b >= 0xE0 and b <= 0xEF then
    need, cp = 2, b - 0xE0
    if b == 0xE0 then lo2 = 0xA0 elseif b == 0xED then hi2 = 0x9F end
  elseif b >= 0xF0 and b <= 0xF4 then
    need, cp = 3, b - 0xF0
    if b == 0xF0 then lo2 = 0x90 elseif b == 0xF4 then hi2 = 0x8F end
  else
    return 63, i + 1
  end
  local b2 = sbyte(s, i + 1)
  if not b2 or b2 < lo2 or b2 > hi2 then return 63, i + 1 end
  cp = cp * 64 + (b2 - 0x80)
  for k = 2, need do
    local bk = sbyte(s, i + k)
    if not bk or bk < 0x80 or bk > 0xBF then return 63, i + 1 end
    cp = cp * 64 + (bk - 0x80)
  end
  return cp, i + need + 1
end
U.utf8next = utf8next

function U.utf8chars(s)
  local out = {}
  if s == nil then return out end
  s = tostring(s)
  local i, n = 1, #s
  while i <= n do
    local cp, nx = utf8next(s, i)
    out[#out + 1] = cp
    i = nx
  end
  return out
end

function U.utf8len(s)
  if s == nil then return 0 end
  s = tostring(s)
  local i, n, count = 1, #s, 0
  while i <= n do
    local _, nx = utf8next(s, i)
    count = count + 1
    i = nx
  end
  return count
end

-- Replacement table for the ASCII side of U.ascii: XML specials and
-- control characters (tab, newline and return are kept).
local ESC = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["\127"] = "&#127;" }
for b = 0, 31 do
  if b ~= 9 and b ~= 10 and b ~= 13 then ESC[schar(b)] = "?" end
end

local function escapeAscii(run)
  return (run:gsub('[%c&<>"]', ESC))
end

-- Results for short strings are memoised (colours, ids and names repeat
-- on every frame); the cache is bounded and simply reset when full.
local ASCII_CACHE, asciiCount, ASCII_CACHE_MAX, ASCII_CACHE_KEY = {}, 0, 1024, 64

local function asciiSlow(s)
  local parts, i, n = {}, 1, #s
  while i <= n do
    local a = sfind(s, "[\128-\255]", i)
    if not a then
      parts[#parts + 1] = escapeAscii(ssub(s, i))
      break
    end
    if a > i then parts[#parts + 1] = escapeAscii(ssub(s, i, a - 1)) end
    local cp, nx = utf8next(s, a)
    -- U+FFFE and U+FFFF are valid UTF-8 but not XML characters
    if cp == 63 or cp == 0xFFFE or cp == 0xFFFF then parts[#parts + 1] = "?"
    else parts[#parts + 1] = "&#" .. cp .. ";" end
    i = nx
  end
  return concat(parts)
end

-- UTF-8 to pure ASCII: code points above 126 become decimal character
-- references, invalid bytes become "?", and & < > " are XML-escaped.
function U.ascii(s)
  if s == nil then return "" end
  local hit = ASCII_CACHE[s]
  if hit then return hit end
  if type(s) ~= "string" then s = tostring(s) end
  local r
  if sfind(s, "[\128-\255]") then r = asciiSlow(s) else r = escapeAscii(s) end
  if #s <= ASCII_CACHE_KEY then
    if asciiCount >= ASCII_CACHE_MAX then ASCII_CACHE = {}; asciiCount = 0 end
    ASCII_CACHE[s] = r
    asciiCount = asciiCount + 1
  end
  return r
end

-- First n code points of s, never cutting inside a UTF-8 sequence.
function U.truncateChars(s, n)
  if s == nil then return "" end
  s = tostring(s)
  if n <= 0 then return "" end
  local i, len, count = 1, #s, 0
  while i <= len and count < n do
    local _, nx = utf8next(s, i)
    count = count + 1
    i = nx
  end
  return ssub(s, 1, i - 1)
end

-- ---------- tables ----------

local MAX_DEPTH = 64   -- nesting cap for deepcopy and jsonEncode

-- seen maps source tables to their copies, so a table referenced twice (or
-- a cycle) is copied once; past MAX_DEPTH the original reference is kept.
local function copyInto(t, seen, depth)
  if type(t) ~= "table" then return t end
  local hit = seen[t]
  if hit then return hit end
  if depth > MAX_DEPTH then return t end
  local out = {}
  seen[t] = out
  for k, v in pairs(t) do
    out[k] = copyInto(v, seen, depth + 1)
  end
  return out
end

function U.deepcopy(t)
  return copyInto(t, {}, 1)
end

local function keyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta == tb and (ta == "number" or ta == "string") then return a < b end
  if ta == "number" then return true end
  if tb == "number" then return false end
  return tostring(a) < tostring(b)
end

function U.keys(t)
  local out = {}
  if type(t) ~= "table" then return out end
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out, keyLess)
  return out
end

function U.indexOf(t, v)
  if type(t) ~= "table" then return nil end
  for i = 1, #t do
    if t[i] == v then return i end
  end
  return nil
end

-- ---------- colours ----------

function U.isHex(s)
  return type(s) == "string" and sfind(s, "^#%x%x%x%x%x%x$") ~= nil
end

function U.hexToRgb(s)
  if not U.isHex(s) then return nil end
  return tonumber(ssub(s, 2, 3), 16), tonumber(ssub(s, 4, 5), 16), tonumber(ssub(s, 6, 7), 16)
end

local function chan(v)
  return floor(U.clamp(tonumber(v) or 0, 0, 255) + 0.5)
end

function U.rgbToHex(r, g, b)
  return sformat("#%02X%02X%02X", chan(r), chan(g), chan(b))
end

-- ---------- encoders ----------

-- CSV cell: quoted when it holds a separator, quote, newline or outer
-- space; quotes doubled; a leading = + - @ gets an apostrophe so a
-- spreadsheet never treats the cell as a formula.
function U.csvCell(s)
  if s == nil then return "" end
  s = tostring(s)
  local first = ssub(s, 1, 1)
  if first == "=" or first == "+" or first == "-" or first == "@" then s = "'" .. s end
  if sfind(s, '[,"\n\r\t]') or sfind(s, "^ ") or sfind(s, " $") then
    return '"' .. s:gsub('"', '""') .. '"'
  end
  return s
end

local JSON_ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f" }

local function jsonEscapeChar(ch)
  return JSON_ESC[ch] or sformat("\\u%04X", sbyte(ch))
end

local function jsonString(s)
  return '"' .. s:gsub('[%c"\\]', jsonEscapeChar) .. '"'
end

local function jsonNumber(v)
  if v ~= v or v == math.huge or v == -math.huge then return "null" end
  if math.type(v) == "integer" then return sformat("%d", v) end
  if v == floor(v) and abs(v) < 1e15 then return sformat("%d", v) end
  return sformat("%.14g", v)
end

-- true when every key is an integer in 1..n with n == number of keys
local function isArray(t)
  local count = 0
  for k in pairs(t) do
    if math.type(k) ~= "integer" or k < 1 then return false end
    count = count + 1
  end
  return count == #t
end

local jsonValue

local function jsonArray(t, path, depth)
  local parts = {}
  for i = 1, #t do parts[i] = jsonValue(t[i], path, depth) end
  return "[" .. concat(parts, ",") .. "]"
end

local function jsonObject(t, path, depth)
  local keys = U.keys(t)
  local parts = {}
  for i = 1, #keys do
    local k = keys[i]
    parts[i] = jsonString(tostring(k)) .. ":" .. jsonValue(t[k], path, depth)
  end
  return "{" .. concat(parts, ",") .. "}"
end

-- path holds the tables currently being encoded: a table met again on its
-- own path is a cycle and becomes null, as does anything nested deeper than
-- MAX_DEPTH. A table shared by two branches is still encoded in both.
jsonValue = function(v, path, depth)
  local tv = type(v)
  if tv == "string" then return jsonString(v) end
  if tv == "number" then return jsonNumber(v) end
  if tv == "boolean" then return v and "true" or "false" end
  if tv ~= "table" or path[v] or depth > MAX_DEPTH then return "null" end
  path[v] = true
  local r
  if isArray(v) then r = jsonArray(v, path, depth + 1) else r = jsonObject(v, path, depth + 1) end
  path[v] = nil
  return r
end

function U.jsonEncode(v)
  return jsonValue(v, {}, 1)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64C = {}
for i = 1, 64 do B64C[i - 1] = ssub(B64, i, i) end

local function b64Triple(a, b, c)
  local v = a * 65536 + b * 256 + c
  return B64C[(v >> 18) & 63] .. B64C[(v >> 12) & 63] .. B64C[(v >> 6) & 63] .. B64C[v & 63]
end

-- RFC 4648 base64 with padding, pure Lua.
function U.base64(s)
  if s == nil then return "" end
  s = tostring(s)
  local n = #s
  local full = n - n % 3
  local parts = {}
  for i = 1, full, 3 do
    local a, b, c = sbyte(s, i, i + 2)
    parts[#parts + 1] = b64Triple(a, b, c)
  end
  local rest = n - full
  if rest == 1 then
    parts[#parts + 1] = ssub(b64Triple(sbyte(s, n), 0, 0), 1, 2) .. "=="
  elseif rest == 2 then
    parts[#parts + 1] = ssub(b64Triple(sbyte(s, n - 1), sbyte(s, n), 0), 1, 3) .. "="
  end
  return concat(parts)
end

-- ---------- geometry (polygons as flat arrays {x1, y1, x2, y2, ...}) ----------

function U.pointInPoly(x, y, poly)
  local n = #poly // 2
  if n < 3 then return false end
  local inside = false
  local jx, jy = poly[2 * n - 1], poly[2 * n]
  for i = 1, n do
    local ix, iy = poly[2 * i - 1], poly[2 * i]
    if (iy > y) ~= (jy > y) then
      local cross = (jx - ix) * (y - iy) / (jy - iy) + ix
      if x < cross then inside = not inside end
    end
    jx, jy = ix, iy
  end
  return inside
end

local function shoelace(poly)
  local n = #poly // 2
  if n < 3 then return 0 end
  local sum = 0
  local jx, jy = poly[2 * n - 1], poly[2 * n]
  for i = 1, n do
    local ix, iy = poly[2 * i - 1], poly[2 * i]
    sum = sum + (jx * iy - ix * jy)
    jx, jy = ix, iy
  end
  return sum / 2
end

function U.polyArea(poly)
  return abs(shoelace(poly))
end

function U.polyCentroid(poly)
  local n = #poly // 2
  if n == 0 then return 0, 0 end
  local a = shoelace(poly)
  if abs(a) < 1e-9 then
    local sx, sy = 0, 0
    for i = 1, n do sx = sx + poly[2 * i - 1]; sy = sy + poly[2 * i] end
    return sx / n, sy / n
  end
  local cx, cy = 0, 0
  local jx, jy = poly[2 * n - 1], poly[2 * n]
  for i = 1, n do
    local ix, iy = poly[2 * i - 1], poly[2 * i]
    local f = jx * iy - ix * jy
    cx = cx + (jx + ix) * f
    cy = cy + (jy + iy) * f
    jx, jy = ix, iy
  end
  return cx / (6 * a), cy / (6 * a)
end

-- squared distance from point p to segment a-b
local function segDist2(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local len2 = dx * dx + dy * dy
  local t = 0
  if len2 > 0 then
    t = U.clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0, 1)
  end
  local qx, qy = ax + t * dx - px, ay + t * dy - py
  return qx * qx + qy * qy
end

-- index (1-based point index) and squared distance of the point farthest from segment first-last
local function farthest(points, first, last)
  local best, bestD = -1, 0
  local ax, ay = points[2 * first - 1], points[2 * first]
  local bx, by = points[2 * last - 1], points[2 * last]
  for i = first + 1, last - 1 do
    local d = segDist2(points[2 * i - 1], points[2 * i], ax, ay, bx, by)
    if d > bestD then best, bestD = i, d end
  end
  return best, bestD
end

-- Ramer-Douglas-Peucker with an explicit stack. Returns a new flat array.
function U.simplify(points, tolerance)
  local n = #points // 2
  local out = {}
  if n <= 2 then
    for i = 1, 2 * n do out[i] = points[i] end
    return out
  end
  local tol2 = (tolerance or 0) ^ 2
  local keep = { [1] = true, [n] = true }
  local stack = { 1, n }
  local guard, limit = 0, 2 * n          -- RDP examines at most 2n - 1 segments
  while #stack > 0 and guard < limit do
    guard = guard + 1
    local last = stack[#stack]; stack[#stack] = nil
    local first = stack[#stack]; stack[#stack] = nil
    local idx, d2 = farthest(points, first, last)
    if idx > 0 and d2 > tol2 then
      keep[idx] = true
      stack[#stack + 1] = first; stack[#stack + 1] = idx
      stack[#stack + 1] = idx; stack[#stack + 1] = last
    end
  end
  for i = 1, n do
    if keep[i] then
      out[#out + 1] = points[2 * i - 1]
      out[#out + 1] = points[2 * i]
    end
  end
  return out
end

local MAX_ITEMS = 65536   -- evenPages never returns more pages than this

-- Page sizes that share n items evenly over ceil(n / perPage) pages.
-- NaN or infinite n gives no pages; n above MAX_ITEMS is capped so the
-- loop stays bounded.
function U.evenPages(n, perPage)
  local out = {}
  n = tonumber(n) or 0
  if n ~= n or n == math.huge or n == -math.huge then return out end
  if n > MAX_ITEMS then n = MAX_ITEMS end
  n = floor(n)
  if n <= 0 then return out end
  perPage = floor(tonumber(perPage) or 1)
  if perPage ~= perPage or perPage < 1 then perPage = 1 end
  if perPage > n then perPage = n end
  local pages = (n + perPage - 1) // perPage
  local base = n // pages
  local extra = n % pages
  for i = 1, pages do
    out[i] = base + ((i <= extra) and 1 or 0)
  end
  return out
end

-- ---------- time ----------

-- Civil date from days since 1970-01-01 (proleptic Gregorian).
local function civil(days)
  local z = days + 719468
  local era = z // 146097            -- floor division: no C-style adjustment for negative z
  local doe = z - era * 146097
  local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
  local mp = (5 * doy + 2) // 153
  local d = doy - (153 * mp + 2) // 5 + 1
  local m = mp < 10 and mp + 3 or mp - 9
  if m <= 2 then y = y + 1 end
  return y, m, d
end

-- ISO 8601 UTC timestamp for a Unix time (default: now).
function U.isoTime(t)
  t = floor(t or os.time())
  local days = t // 86400
  local secs = t % 86400
  local y, m, d = civil(days)
  return sformat("%04d-%02d-%02dT%02d:%02d:%02dZ", y, m, d, secs // 3600, (secs // 60) % 60, secs % 60)
end
