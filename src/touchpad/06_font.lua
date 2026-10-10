-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: font (text width estimation, Roboto-like per-character widths, cached)
--
-- Widths are Roboto Regular advance widths in 1/1000 em for ASCII 32..126.
-- Code points 128..0x2FFF count 0.55 em, everything else (CJK, emoji) 1 em.
-- ASCII runs take a byte-array fast path; widths and fits are memoised.

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

-- Walks the first MAX_CHARS code points of str adding advance widths. ASCII
-- runs go through a byte array; U.utf8next decodes only non-ASCII bytes.
-- Returns units, charCount, lastByteIncluded.
local function walk(str)
  local utf8next = U.utf8next
  local i, n, units, count = 1, #str, 0, 0
  while i <= n and count < MAX_CHARS do
    local a = sfind(str, "[\128-\255]", i)
    if a == i then
      local cp, nx = utf8next(str, i)
      units, count, i = units + cpWidth(cp), count + 1, nx
    else
      local stop = (a or (n + 1)) - 1
      local room = MAX_CHARS - count
      if stop - i + 1 > room then stop = i + room - 1 end
      local bytes = { sbyte(str, i, stop) }
      for k = 1, #bytes do units = units + W[bytes[k]] end
      count = count + #bytes
      i = stop + 1
    end
  end
  return units, count, i - 1
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
function Font.width(str, size, weight)
  if str == nil or str == "" then return 0 end
  if type(str) ~= "string" then str = tostring(str) end
  size = tonumber(size) or 14
  local c = cacheFor(size, weight)
  local hit = c.map[str]
  if hit then return hit end
  local units, n = unitsOf(str)
  local px = scale(units, size, weight)
  if n <= MAX_CHARS then
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

-- true when a prefix of count code points measuring units still fits maxW
-- with "..." appended; the same arithmetic as scale() so Font.width agrees.
local function prefixFits(units, count, size, weight, maxW)
  local px = (units + ellipsisUnits(count)) * size / 1000
  if weight == "bold" then px = px * BOLD_SCALE end
  return px <= maxW
end

-- ASCII run of walkFit: bytes[] from byte index i. Returns units, count and
-- the last byte that fits, or -1 while everything fitted. The fit test is
-- prefixFits inlined (same arithmetic as scale), as it runs per character.
local function fitAscii(bytes, i, units, count, size, weight, maxW)
  local bold = (weight == "bold")
  for k = 1, #bytes do
    local u = units + ((count < MAX_CHARS) and W[bytes[k]] or WIDE_W)
    local e = (count + 4 <= MAX_CHARS) and ELLIPSIS_UNITS or ellipsisUnits(count + 1)
    local px = (u + e) * size / 1000
    if bold then px = px * BOLD_SCALE end
    if px > maxW then return units, count, i + k - 2 end
    units, count = u, count + 1
  end
  return units, count, -1
end

-- Longest prefix whose width plus "..." fits maxW, charging 0.55 em per
-- code point past MAX_CHARS like Font.width. Never stops inside a UTF-8
-- sequence. Returns lastByteIncluded (0 when only "..." fits).
local function walkFit(str, size, weight, maxW)
  local utf8next = U.utf8next
  local i, n, units, count = 1, #str, 0, 0
  while i <= n do
    local a = sfind(str, "[\128-\255]", i)
    if a == i then
      local cp, nx = utf8next(str, i)
      local u = units + ((count < MAX_CHARS) and cpWidth(cp) or WIDE_W)
      if not prefixFits(u, count + 1, size, weight, maxW) then return i - 1 end
      units, count, i = u, count + 1, nx
    else
      local stop = (a or (n + 1)) - 1
      if stop - i + 1 > MAX_CHARS then stop = i + MAX_CHARS - 1 end
      local last
      units, count, last = fitAscii({ sbyte(str, i, stop) }, i, units, count, size, weight, maxW)
      if last >= 0 then return last end
      i = stop + 1
    end
  end
  return i - 1
end

local function fitUncached(str, size, maxW, weight)
  if Font.width(str, size, weight) <= maxW then return str end
  if not prefixFits(0, 0, size, weight, maxW) then return "" end
  local last = walkFit(str, size, weight, maxW)
  return ssub(str, 1, last) .. "..."
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
