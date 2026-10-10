-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: font (text width estimation, Roboto-like per-character widths, cached)
--
-- Widths are Roboto Regular advance widths in 1/1000 em for ASCII 32..126.
-- Code points 128..0x2FFF count 0.55 em, everything else (CJK, emoji) 1 em.
-- ASCII runs take a byte-array fast path; widths and fits are memoised.

do
Font = Font or {}

local sbyte, ssub, sfind = string.byte, string.sub, string.find
local DEFAULT_W = 550
local WIDE_W = 550      -- 128..0x2FFF
local EM_W = 1000       -- CJK, emoji, everything else
local BOLD_SCALE = 1.06
local MAX_CHARS = 128   -- longer strings: first 128 measured, 0.55 em per extra
local CACHE_MAX = 512   -- width strings per (size, weight)
local FIT_MAX = 256     -- fit results per (size, weight)
local DOT_W = 263       -- "."
local ELLIPSIS_UNITS = 3 * DOT_W

-- Advance widths, indexed by code point (0..127 always defined).
local W = {}
for b = 0, 31 do W[b] = 0 end
for b = 32, 127 do W[b] = DEFAULT_W end
local function set(cp, w) W[cp] = w end
local function setRange(cps, w)
  for i = 1, #cps do W[sbyte(cps, i)] = w end
end

set(32, 248)                        -- space
setRange("0123456789", 562)
set(97, 544)  set(98, 561)  set(99, 523)  set(100, 564) set(101, 530) set(102, 346)   -- a b c d e f
set(103, 561) set(104, 551) set(105, 243) set(106, 239) set(107, 503) set(108, 243)   -- g h i j k l
set(109, 876) set(110, 551) set(111, 570) set(112, 561) set(113, 568) set(114, 338)   -- m n o p q r
set(115, 516) set(116, 327) set(117, 551) set(118, 484) set(119, 751) set(120, 496)   -- s t u v w x
set(121, 473) set(122, 496)                                                           -- y z
set(65, 652)  set(66, 623)  set(67, 651)  set(68, 656)  set(69, 568)  set(70, 553)    -- A B C D E F
set(71, 681)  set(72, 713)  set(73, 272)  set(74, 552)  set(75, 627)  set(76, 538)    -- G H I J K L
set(77, 873)  set(78, 713)  set(79, 688)  set(80, 631)  set(81, 688)  set(82, 616)    -- M N O P Q R
set(83, 593)  set(84, 597)  set(85, 648)  set(86, 636)  set(87, 887)  set(88, 627)    -- S T U V W X
set(89, 600)  set(90, 599)                                                            -- Y Z
set(46, 263)  set(44, 196)  set(58, 242)  set(45, 276)  set(47, 412)                  -- . , : - /
set(40, 343)  set(41, 343)  set(38, 622)  set(43, 567)  set(61, 549)  set(95, 451)    -- ( ) & + = _
set(39, 191)  set(34, 358)  set(64, 898)  set(35, 616)  set(37, 733)  set(42, 435)    -- ' " @ # % *
set(33, 257)  set(63, 473)  set(91, 265)  set(93, 265)  set(123, 338) set(125, 338)   -- ! ? [ ] { }
set(124, 244) set(126, 680) set(92, 410)  set(94, 418)  set(96, 309)  set(36, 562)    -- | ~ \ ^ ` $
set(60, 525)  set(62, 525)  set(59, 212)                                              -- < > ;

-- width of one code point in 1/1000 em
local function cpWidth(cp)
  if cp <= 127 then return W[cp] end
  if cp <= 0x2FFF then return WIDE_W end
  return EM_W
end
Font.cpWidth = cpWidth

-- Width units of the UTF-8 sequence starting at bytes[k] (a byte array),
-- classified exactly as U.utf8next decodes it: an invalid or truncated
-- sequence is "?" and one byte long. Lead bytes alone place the code point:
-- C2..DF -> U+0080..07FF and E0..E2 -> U+0800..2FFF count 0.55 em,
-- E3..EF and F0..F4 count 1 em. Returns units, bytesConsumed.
local QMARK_W = W[63]
local function seqWidth(bytes, k)
  local b = bytes[k]
  local need, lo2, hi2, units = 0, 0x80, 0xBF, WIDE_W
  if b >= 0xC2 and b <= 0xDF then need = 1
  elseif b >= 0xE0 and b <= 0xEF then
    need = 2
    if b == 0xE0 then lo2 = 0xA0 elseif b == 0xED then hi2 = 0x9F end
    if b > 0xE2 then units = EM_W end
  elseif b >= 0xF0 and b <= 0xF4 then
    need, units = 3, EM_W
    if b == 0xF0 then lo2 = 0x90 elseif b == 0xF4 then hi2 = 0x8F end
  else
    return QMARK_W, 1
  end
  local b2 = bytes[k + 1]
  if not b2 or b2 < lo2 or b2 > hi2 then return QMARK_W, 1 end
  for j = 2, need do
    local bj = bytes[k + j]
    if not bj or bj < 0x80 or bj > 0xBF then return QMARK_W, 1 end
  end
  return units, need + 1
end

-- A string's first MAX_CHARS code points fit in 4 * MAX_CHARS bytes, so one
-- byte array of that size covers everything walk() and fit measure per
-- character; a cut at its end can only fall after the MAX_CHARS-th point.
local SLICE = 4 * MAX_CHARS

-- Walks the first MAX_CHARS code points of str adding advance widths: one
-- byte array, ASCII bytes straight through the table, anything else through
-- seqWidth. Returns units, charCount, lastByteIncluded.
local function walk(str)
  local n = #str
  if not sfind(str, "[\128-\255]") then
    local stop = (n > MAX_CHARS) and MAX_CHARS or n
    local bytes = { sbyte(str, 1, stop) }
    local units = 0
    for k = 1, stop do units = units + W[bytes[k]] end
    return units, stop, stop
  end
  local stop = (n > SLICE) and SLICE or n
  local bytes = { sbyte(str, 1, stop) }
  local k, units, count = 1, 0, 0
  while k <= stop and count < MAX_CHARS do
    local b = bytes[k]
    if b < 0x80 then
      units, k = units + W[b], k + 1
    else
      -- well-formed sequences inline, chosen by the lead byte (two bytes:
      -- Latin-1, Cyrillic, Greek, Hebrew, Arabic; three: Indic, Thai, CJK;
      -- four: emoji), with the narrower second-byte ranges of the E0, ED,
      -- F0 and F4 leads; anything malformed goes through seqWidth
      local b2 = bytes[k + 1]
      if b <= 0xDF then
        if b >= 0xC2 and b2 and b2 >= 0x80 and b2 <= 0xBF then units, k = units + WIDE_W, k + 2
        else local u, len = seqWidth(bytes, k); units, k = units + u, k + len end
      elseif b <= 0xEF then
        local b3 = bytes[k + 2]
        if b2 and b2 >= ((b == 0xE0) and 0xA0 or 0x80) and b2 <= ((b == 0xED) and 0x9F or 0xBF)
           and b3 and b3 >= 0x80 and b3 <= 0xBF then
          units, k = units + ((b <= 0xE2) and WIDE_W or EM_W), k + 3
        else local u, len = seqWidth(bytes, k); units, k = units + u, k + len end
      else
        local b3, b4 = bytes[k + 2], bytes[k + 3]
        if b <= 0xF4 and b2 and b2 >= ((b == 0xF0) and 0x90 or 0x80) and b2 <= ((b == 0xF4) and 0x8F or 0xBF)
           and b3 and b3 >= 0x80 and b3 <= 0xBF and b4 and b4 >= 0x80 and b4 <= 0xBF then
          units, k = units + EM_W, k + 4
        else local u, len = seqWidth(bytes, k); units, k = units + u, k + len end
      end
    end
    count = count + 1
  end
  return units, count, k - 1
end

-- units of the first MAX_CHARS code points plus 0.55 em per extra; returns units, charCount
local function unitsOf(str)
  local units, count, last = walk(str)
  if last < #str then
    -- characters past the 128th: one per non-continuation byte (one C call)
    local _, extra = string.gsub(ssub(str, last + 1), "[^\128-\191]", "")
    units = units + extra * WIDE_W
    count = count + extra
  end
  return units, count
end

local normalCaches, boldCaches = {}, {}

local function cacheFor(size, weight)
  local map = (weight == "bold") and boldCaches or normalCaches
  local c = map[size]
  if not c then
    c = { map = {}, count = 0, fit = {}, fitCount = 0 }
    map[size] = c
  end
  return c
end

local function scale(units, size, weight)
  local px = units * size / 1000
  if weight == "bold" then px = px * BOLD_SCALE end
  return px
end

-- Width in px of str drawn at size px. weight "bold" is 6 % wider.
-- Results are cached for strings up to 4 * MAX_CHARS bytes.
function Font.width(str, size, weight)
  if str == nil or str == "" then return 0 end
  if type(str) ~= "string" then str = tostring(str) end
  size = tonumber(size) or 14
  local c = cacheFor(size, weight)
  local hit = c.map[str]
  if hit then return hit end
  local units = unitsOf(str)
  local px = scale(units, size, weight)
  if #str <= SLICE then
    if c.count >= CACHE_MAX then c.map = {}; c.count = 0 end
    c.map[str] = px
    c.count = c.count + 1
  end
  return px
end

-- Drops every cached width and fit (tests and font changes).
function Font.clearCache()
  normalCaches, boldCaches = {}, {}
end

function Font.cacheSize(size, weight)
  return cacheFor(size or 14, weight).count
end

-- Units of "..." appended after count code points: dots inside the first
-- MAX_CHARS positions measure as "." does, later ones 0.55 em (as unitsOf).
local function ellipsisUnits(count)
  if count + 3 <= MAX_CHARS then return ELLIPSIS_UNITS end
  if count >= MAX_CHARS then return 3 * WIDE_W end
  local u = 0
  for k = 1, 3 do u = u + ((count + k <= MAX_CHARS) and DOT_W or WIDE_W) end
  return u
end

-- One pass over str that stops as soon as the measured prefix alone is wider
-- than maxW: the characters walked are bounded by what fits, however long
-- the string is, and a string that fits whole is returned unchanged. The
-- arithmetic is scale()'s, so Font.width agrees with the result. Past
-- MAX_CHARS code points every character counts 0.55 em, as Font.width does.
-- The longest prefix of an ASCII run that fits maxW with "..." appended,
-- backing up from byte k (the first that overflowed, or one past the run)
-- with units the width before it; valid while count + 3 <= MAX_CHARS, where
-- the ellipsis measures ELLIPSIS_UNITS. Returns the prefix's last byte (0
-- when only "..." fits, -1 when not even that).
local function backFit(bytes, k, units, size, bold, maxW)
  local j = k - 1
  while true do
    local e = (units + ELLIPSIS_UNITS) * size / 1000
    if bold then e = e * BOLD_SCALE end
    if e <= maxW then return j end
    if j == 0 then return -1 end
    units = units - W[bytes[j]]
    j = j - 1
  end
end

local function fitUncached(str, size, maxW, weight)
  if maxW ~= maxW or maxW < 0 then return "" end
  local bold = (weight == "bold")
  local utf8next = U.utf8next
  local n = #str
  local stop = (n > SLICE) and SLICE or n
  local bytes = { sbyte(str, 1, stop) }
  local k, units, count, fitEnd = 1, 0, 0, 0
  if not sfind(str, "[\128-\255]") then
    -- pure ASCII (one byte per character): the plain width alone is tested
    -- per character and the ellipsis point found once by backing up, while
    -- the ellipsis measures the same for every prefix (count + 3 <= MAX_CHARS)
    local lim = MAX_CHARS - 3
    if lim > stop then lim = stop end
    while k <= lim do
      local u = units + W[bytes[k]]
      local px = u * size / 1000
      if bold then px = px * BOLD_SCALE end
      if px > maxW then
        local last = backFit(bytes, k, units, size, bold, maxW)
        if last < 0 then return "" end
        return ssub(str, 1, last) .. "..."
      end
      units, count, k = u, count + 1, k + 1
    end
    if k > n then return str end
    fitEnd = backFit(bytes, k, units, size, bold, maxW)
    if fitEnd < 0 then fitEnd = 0 end
  end
  while k <= n do
    local w, len
    if k <= stop then
      local b = bytes[k]
      if b < 0x80 then w, len = W[b], 1
      else
        -- the same inline classification as walk()
        local b2 = bytes[k + 1]
        if b <= 0xDF then
          if b >= 0xC2 and b2 and b2 >= 0x80 and b2 <= 0xBF then w, len = WIDE_W, 2
          else w, len = seqWidth(bytes, k) end
        elseif b <= 0xEF then
          local b3 = bytes[k + 2]
          if b2 and b2 >= ((b == 0xE0) and 0xA0 or 0x80) and b2 <= ((b == 0xED) and 0x9F or 0xBF)
             and b3 and b3 >= 0x80 and b3 <= 0xBF then
            w, len = ((b <= 0xE2) and WIDE_W or EM_W), 3
          else w, len = seqWidth(bytes, k) end
        else
          local b3, b4 = bytes[k + 2], bytes[k + 3]
          if b <= 0xF4 and b2 and b2 >= ((b == 0xF0) and 0x90 or 0x80) and b2 <= ((b == 0xF4) and 0x8F or 0xBF)
             and b3 and b3 >= 0x80 and b3 <= 0xBF and b4 and b4 >= 0x80 and b4 <= 0xBF then
            w, len = EM_W, 4
          else w, len = seqWidth(bytes, k) end
        end
      end
    else
      local _, nx = utf8next(str, k)
      w, len = WIDE_W, nx - k
    end
    if count >= MAX_CHARS then w = WIDE_W end
    local u = units + w
    local px = u * size / 1000
    if bold then px = px * BOLD_SCALE end
    if px > maxW then
      -- the whole string does not fit: the prefix recorded so far plus "..."
      if not (((ellipsisUnits(0) * size / 1000) * (bold and BOLD_SCALE or 1)) <= maxW) then return "" end
      return ssub(str, 1, fitEnd) .. "..."
    end
    units, count, k = u, count + 1, k + len
    local e = (u + ((count + 3 <= MAX_CHARS) and ELLIPSIS_UNITS or ellipsisUnits(count))) * size / 1000
    if bold then e = e * BOLD_SCALE end
    if e <= maxW then fitEnd = k - 1 end
  end
  return str
end

-- Estimated VM instructions that fitting str to maxW px and drawing the
-- result costs when nothing is cached: the code points the width can take
-- (never more than the string holds) times a per-character cost, non-ASCII
-- text being several times dearer to fit and to escape. Modes charge cold
-- tile and header renders against a per-frame budget with it. Two C calls
-- and a little arithmetic, whatever the string's length.
local ASCII_CHAR_COST, WIDE_CHAR_COST = 40, 200
function Font.fitCost(str, size, maxW)
  if str == nil or str == "" then return 0 end
  if type(str) ~= "string" then str = tostring(str) end
  size = tonumber(size) or 14
  local holds = math.floor((tonumber(maxW) or 0) / (size * 0.5)) + 1
  local _, chars = string.gsub(str, "[^\128-\191]", "")
  if holds > chars then holds = chars end
  if sfind(str, "[\128-\255]") then return holds * WIDE_CHAR_COST end
  return holds * ASCII_CHAR_COST
end

-- Longest prefix of str that fits maxW, with "..." when truncated.
-- Never cuts inside a UTF-8 sequence; "" when even "..." does not fit.
-- A missing or non-numeric maxW fits nothing (""); numeric strings are accepted.
function Font.fit(str, size, maxW, weight)
  if str == nil or str == "" then return "" end
  if type(str) ~= "string" then str = tostring(str) end
  size = tonumber(size) or 14
  maxW = tonumber(maxW)
  if maxW == nil then return "" end
  local c = cacheFor(size, weight)
  local key = str .. "\0" .. maxW
  local hit = c.fit[key]
  if hit then return hit end
  local r = fitUncached(str, size, maxW, weight)
  if #str <= 4 * MAX_CHARS then
    if c.fitCount >= FIT_MAX then c.fit = {}; c.fitCount = 0 end
    c.fit[key] = r
    c.fitCount = c.fitCount + 1
  end
  return r
end

-- Wraps str at spaces into at most maxLines lines no wider than maxW.
-- The last line is fitted with "..." when text remains.
function Font.lines(str, size, maxW, maxLines)
  local out = {}
  if str == nil or str == "" then return out end
  if type(str) ~= "string" then str = tostring(str) end
  size = size or 14
  maxLines = maxLines or 1
  if maxLines < 1 then return out end
  local words, widths = {}, {}
  for w in string.gmatch(str, "%S+") do
    words[#words + 1] = w
    widths[#words] = Font.width(w, size)
  end
  local spaceW = Font.width(" ", size)
  local line, lineW = "", 0
  local i = 1
  while i <= #words do
    local w, ww = words[i], widths[i]
    if line == "" then
      line, lineW = w, ww
      i = i + 1
    elseif lineW + spaceW + ww <= maxW then
      line, lineW = line .. " " .. w, lineW + spaceW + ww
      i = i + 1
    else
      out[#out + 1] = line
      line, lineW = "", 0
      if #out == maxLines then break end
    end
  end
  if #out < maxLines then
    if line ~= "" then out[#out + 1] = line end
  else
    local rest = {}
    for k = i, #words do rest[#rest + 1] = words[k] end
    local last = out[maxLines]
    if #rest > 0 then last = last .. " " .. table.concat(rest, " ") end
    out[maxLines] = Font.fit(last, size, maxW)
  end
  for k = 1, #out do
    if Font.width(out[k], size) > maxW then out[k] = Font.fit(out[k], size, maxW) end
  end
  return out
end
end
