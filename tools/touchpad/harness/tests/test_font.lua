-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: unit tests for 06_font.lua (Font)

local function validUtf8(s)
  local cps = U.utf8chars(s)
  for i = 1, #cps do
    if cps[i] == 63 then return false end
  end
  return true
end

function test_width_basics()
  Font.clearCache()
  T.eq(Font.width("", 14), 0, "empty is zero")
  T.eq(Font.width(nil, 14), 0, "nil is zero")
  T.near(Font.width(" ", 100), 24.8, 1e-9, "space at 100 px")
  T.near(Font.width("0", 100), 56.2, 1e-9, "digit at 100 px")
  T.near(Font.width("m", 10), 8.76, 1e-9, "m scales with size")
  T.near(Font.width("Hello", 100), 71.3 + 53.0 + 24.3 + 24.3 + 57.0, 1e-9, "sum of advances")
  T.ok(Font.width("iii", 14) < Font.width("mmm", 14), "narrow versus wide glyphs")
  T.ok(Font.width("W", 14) > Font.width("I", 14), "W wider than I")
end

function test_width_monotonic_in_size()
  local last = 0
  for size = 8, 48, 4 do
    local w = Font.width("Zone Select 12", size)
    T.ok(w > last, "width grows with size " .. size)
    last = w
  end
end

function test_bold_wider()
  local n = Font.width("Camera Framing", 14, "normal")
  local b = Font.width("Camera Framing", 14, "bold")
  T.near(b, n * 1.06, 1e-9, "bold is 6 percent wider")
  T.ok(b > n, "bold wider")
end

function test_non_ascii_widths()
  T.near(Font.width("\195\169", 100), 55, 1e-9, "latin extended is 0.55 em")
  T.near(Font.width("\215\144", 100), 55, 1e-9, "hebrew is 0.55 em")
  T.near(Font.width("\228\184\173", 100), 100, 1e-9, "CJK is 1 em")
  T.near(Font.width("\240\159\152\128", 100), 100, 1e-9, "emoji is 1 em")
  T.near(Font.width("\255", 100), 47.3, 1e-9, "invalid byte measures as ?")
  T.near(Font.width("\1", 100), 0, 1e-9, "control char has no width")
end

function test_long_strings()
  local s = string.rep("W", 200)
  local expected = (128 * 887 + 72 * 550) * 10 / 1000
  T.near(Font.width(s, 10), expected, 1e-6, "128 measured plus 0.55 em per extra")
  T.near(Font.width(string.rep("W", 128), 10), 128 * 8.87, 1e-6, "exactly 128 all measured")
end

function test_fit()
  local maxW = 60
  local samples = { "Laptop", "Conference Room Display 3", "Wireless Presentation Gateway", "a", "", "MMMMMMMMMMMMMMMMMMMM" }
  for i = 1, #samples do
    local out = Font.fit(samples[i], 14, maxW)
    T.ok(Font.width(out, 14) <= maxW + 1e-9, "fit never exceeds maxW: " .. samples[i])
    if Font.width(samples[i], 14) <= maxW then
      T.eq(out, samples[i], "short strings are unchanged")
    else
      T.eq(string.sub(out, -3), "...", "truncated strings end with ...: " .. samples[i])
    end
  end
  T.eq(Font.fit("Wide text", 14, 1), "", "nothing fits")
  T.eq(Font.fit("WWWWWW", 14, Font.width("...", 14) + 0.5), "...", "only the ellipsis fits")
  T.eq(Font.fit("Laptop", 14, 1000, "bold"), "Laptop", "bold fits")
  local wide = Font.fit("MMMMMMMM", 14, 50, "bold")
  T.ok(Font.width(wide, 14, "bold") <= 50, "bold fit respects maxW")
end

function test_fit_utf8_safe()
  local s = "\215\169\215\156\215\149\215\157 \215\162\215\149\215\156\215\157 caf\195\169 \240\159\152\128\240\159\152\128\240\159\152\128"
  for maxW = 5, 120, 3 do
    local out = Font.fit(s, 12, maxW)
    T.ok(validUtf8(out), "no broken sequence at maxW " .. maxW)
    T.ok(Font.width(out, 12) <= maxW + 1e-9, "fits at maxW " .. maxW)
  end
  local emoji = Font.fit("\240\159\152\128\240\159\152\128\240\159\152\128\240\159\152\128", 10, 25)
  T.eq(emoji, "\240\159\152\128..." , "emoji cut on a boundary")
end

function test_cache()
  Font.clearCache()
  T.eq(Font.cacheSize(14, "normal"), 0, "empty cache")
  local a = Font.width("cached", 14)
  T.eq(Font.cacheSize(14, "normal"), 1, "one entry")
  local b = Font.width("cached", 14)
  T.eq(a, b, "cache hit equals computed")
  T.eq(Font.cacheSize(14, "normal"), 1, "no duplicate entry")
  Font.width("cached", 14, "bold")
  T.eq(Font.cacheSize(14, "bold"), 1, "bold has its own cache")
  Font.width("cached", 15)
  T.eq(Font.cacheSize(15, "normal"), 1, "size has its own cache")
  Font.width(string.rep("x", 200), 14)
  T.eq(Font.cacheSize(14, "normal"), 1, "strings over 128 chars are not cached")
  for i = 1, 600 do Font.width("s" .. i, 14) end
  T.ok(Font.cacheSize(14, "normal") <= 512, "cache bounded at 512")
  T.near(Font.width("cached", 14), a, 1e-9, "still correct after eviction")
end

function test_lines()
  Font.clearCache()
  T.deq(Font.lines("", 14, 100, 3), {}, "empty")
  T.deq(Font.lines("short", 14, 1000, 3), { "short" }, "single line")
  local out = Font.lines("the quick brown fox jumps over the lazy dog", 14, 80, 10)
  T.ok(#out > 1, "wrapped into several lines")
  local joined = table.concat(out, " ")
  T.eq(joined, "the quick brown fox jumps over the lazy dog", "no words lost")
  for i = 1, #out do
    T.ok(Font.width(out[i], 14) <= 80, "line " .. i .. " fits")
  end
  local capped = Font.lines("the quick brown fox jumps over the lazy dog", 14, 80, 2)
  T.eq(#capped, 2, "maxLines respected")
  T.eq(string.sub(capped[2], -3), "...", "last line marks the cut")
  local long = Font.lines("Supercalifragilistic", 14, 40, 2)
  T.eq(#long, 1, "a single wide word is one line")
  T.ok(Font.width(long[1], 14) <= 40, "wide word fitted")
end

function test_cost_bounds()
  Font.clearCache()
  local long = string.rep("Conference \215\169\215\156\215\149\215\157 ", 100)
  local n = T.instructions(function() Font.width(long, 14) end)
  T.ok(n < 6000, "a 2000 byte string is measured cheaply (" .. n .. ")")
  Font.clearCache()
  local w = T.instructions(function() Font.width("Conference Laptop 12", 14) end)
  T.ok(w < 800, "a short ASCII string costs little uncached (" .. w .. ")")
  local hit = T.instructions(function() Font.width("Conference Laptop 12", 14) end)
  T.ok(hit < 150, "a cache hit is a lookup (" .. hit .. ")")
  local f = T.instructions(function() Font.fit("Conference \215\169\215\156\215\149\215\157 Display 7", 14, 84) end)
  T.ok(f < 1500, "an uncached mixed fit is bounded (" .. f .. ")")
  local fh = T.instructions(function() Font.fit("Conference \215\169\215\156\215\149\215\157 Display 7", 14, 84) end)
  T.ok(fh < 150, "a fit cache hit is a lookup (" .. fh .. ")")
end

-- ---------- regressions from review ----------

function test_fit_long_strings()
  Font.clearCache()
  local i200 = string.rep("i", 200)
  T.near(Font.width(i200, 14), (128 * 243 + 72 * 550) * 14 / 1000, 1e-6, "200 i measure 128 real widths plus 0.55 em each")
  T.eq(Font.fit(i200, 14, 1000), i200, "a long narrow string that fits is unchanged")
  local m150 = string.rep("M", 150)
  T.eq(Font.fit(m150, 14, Font.width(m150, 14)), m150, "a long string at exactly its width is unchanged")
  local cut = Font.fit(m150, 14, Font.width(m150, 14) - 1)
  T.ok(cut ~= m150 and string.sub(cut, -3) == "...", "a long string one px over is cut with ...")
  T.ok(Font.width(cut, 14) <= Font.width(m150, 14) - 1, "cut string fits")
  local out = Font.fit(string.rep("i", 300), 14, 1000)
  T.ok(Font.width(out, 14) <= 1000, "300 i fit within 1000")
  T.ok(#out > 131, "fit continues past 128 characters when there is room (" .. #out .. ")")
  local prefix = string.sub(out, 1, -4)
  T.ok(Font.width(prefix .. "i...", 14) > 1000, "fit is the longest prefix")
  for _, maxW in ipairs({ 440, 450, 460, 470, 600, 900, 1000 }) do
    local r = Font.fit(string.rep("i", 200), 14, maxW)
    T.ok(Font.width(r, 14) <= maxW, "fit never exceeds maxW at " .. maxW)
    local lines = Font.lines(string.rep("i", 200), 14, maxW, 1)
    T.ok(Font.width(lines[1], 14) <= maxW, "lines never exceed maxW at " .. maxW)
  end
  local mixed = string.rep("\215\169", 200)
  T.near(Font.width(mixed, 12), 200 * 550 * 12 / 1000, 1e-6, "200 hebrew letters are 0.55 em each")
  local rm = Font.fit(mixed, 12, 1200)
  T.ok(Font.width(rm, 12) <= 1200, "long non-ascii fit within maxW")
  T.eq(#rm % 2, 1, "no broken sequence (pairs of bytes plus ...)")
  T.ok(#rm > 2 * 128 + 3, "non-ascii fit continues past 128 characters (" .. #rm .. ")")
  local rp = string.sub(rm, 1, -4)
  T.ok(Font.width(rp .. "\215\169...", 12) > 1200, "non-ascii fit is the longest prefix")
end

function test_fit_exact_boundary()
  Font.clearCache()
  local e = Font.width("...", 14)
  T.eq(Font.fit("Hello", 14, e), "...", "exactly the ellipsis width fits the ellipsis")
  T.eq(Font.fit("Hello", 14, e - 1e-6), "", "a hair under the ellipsis width fits nothing")
  local target = Font.width("cY 6KS6+%...", 11.5, "bold")
  T.eq(Font.fit("cY 6KS6+%LE$", 11.5, target, "bold"), "cY 6KS6+%...", "exact bold boundary keeps the last character")
  for _, s in ipairs({ "Conference Room Display", "Wireless Presentation Gateway", "abcdefghij", "caf\195\169 \215\169\215\156\215\149\215\157 ok" }) do
    local cps = U.utf8len(s)
    for n = 1, cps - 1 do
      local want = U.truncateChars(s, n) .. "..."
      local w = Font.width(want, 14)
      if Font.width(s, 14) > w then
        T.eq(Font.fit(s, 14, w), want, "boundary at " .. n .. " of " .. s)
      end
    end
  end
end

function test_fit_bad_width()
  T.eq(Font.fit("abc", 14, nil), "", "nil width fits nothing")
  T.eq(Font.fit("abc", 14, 0 / 0), "", "NaN width fits nothing")
  T.eq(Font.fit("abc", 14, -5), "", "negative width fits nothing")
  T.eq(Font.fit("abc", 14, "1000"), "abc", "numeric string width is accepted")
  T.eq(Font.fit("abc", "14", 1000), "abc", "numeric string size is accepted")
  T.eq(Font.fit("abc", nil, 1000), "abc", "nil size defaults")
  T.near(Font.width("abc", "10"), Font.width("abc", 10), 1e-9, "width accepts a numeric string size")
  local c = Svg.new(10, 10)
  T.eq(c:textFit(0, 0, nil, "abc"), "", "textFit without a width draws nothing")
  T.ok(string.find(c:finish(), "<text", 1, true) == nil, "nothing drawn")
end
