-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: unit tests for 05_util.lua (U)

local function isAscii(s)
  return not string.find(s, "[\128-\255]")
end

function test_clamp_lerp_round()
  T.eq(U.clamp(5, 0, 3), 3, "clamp high")
  T.eq(U.clamp(-1, 0, 3), 0, "clamp low")
  T.eq(U.clamp(2, 0, 3), 2, "clamp inside")
  T.eq(U.lerp(0, 10, 0.25), 2.5, "lerp")
  T.eq(U.round(2.5), 3, "round half up")
  T.eq(U.round(-2.4), -2, "round negative")
  T.eq(U.round(3.14159, 2), 3.14, "round 2 decimals")
  T.eq(math.type(U.round(2.2)), "integer", "round returns an integer")
end

function test_dist_angles()
  T.eq(U.dist(0, 0, 3, 4), 5, "dist 3-4-5")
  T.near(U.angleDeg(1, 0), 0, 1e-9, "right is 0")
  T.near(U.angleDeg(0, -1), 90, 1e-9, "up is 90 (screen y down)")
  T.near(U.angleDeg(-1, 0), 180, 1e-9, "left is 180")
  T.near(U.angleDeg(0, 1), -90, 1e-9, "down is -90")
  T.near(U.angleDeg(1, -1), 45, 1e-9, "diagonal")
  T.eq(U.angleDeg(0, 0), 0, "zero vector")
  T.eq(U.normAngle(370), 10, "normAngle wraps")
  T.eq(U.normAngle(-190), 170, "normAngle negative wraps")
  T.eq(U.normAngle(180), 180, "normAngle keeps 180")
  T.eq(U.normAngle(-180), 180, "normAngle -180 -> 180")
  T.eq(U.normAngle(45), 45, "normAngle identity")
end

function test_strings()
  T.deq(U.split("a,b,,c", ","), { "a", "b", "", "c" }, "split")
  T.deq(U.split("a", ","), { "a" }, "split no separator")
  T.deq(U.split("a,", ","), { "a", "" }, "split trailing")
  T.deq(U.split("a.b", "."), { "a", "b" }, "split is plain, not a pattern")
  T.deq(U.split("", ","), { "" }, "split empty")
  T.eq(U.trim("  hi there \n"), "hi there", "trim")
  T.eq(U.trim(nil), "", "trim nil")
  T.ok(U.startsWith("Laptop 1", "Lap"), "startsWith")
  T.ok(not U.startsWith("Laptop", "top"), "startsWith false")
  T.eq(U.lower("ABC"), "abc", "lower")
  T.deq(U.wordsOf("Laptop-HDMI 2 (Teams)"), { "laptop", "hdmi", "2", "teams" }, "wordsOf")
  T.ok(U.hasWord("Zoom Room PC", "pc"), "hasWord")
  T.ok(not U.hasWord("Zoom Room PC", "room pc"), "hasWord whole word only")
  T.ok(not U.hasWord("Laptop", "lap"), "hasWord partial does not match")
  T.eq(U.pad2(5), "05", "pad2")
  T.eq(U.pad2(12), "12", "pad2 two digits")
end

function test_utf8_decode()
  T.deq(U.utf8chars("a"), { 97 }, "ascii")
  T.deq(U.utf8chars("a\195\169"), { 97, 233 }, "two-byte e acute")
  T.deq(U.utf8chars("\215\144"), { 1488 }, "hebrew alef")
  T.deq(U.utf8chars("\240\159\152\128"), { 128512 }, "emoji")
  T.deq(U.utf8chars("\255"), { 63 }, "invalid lead byte")
  T.deq(U.utf8chars("\226\128"), { 63, 63 }, "truncated three-byte sequence")
  T.deq(U.utf8chars("\128a"), { 63, 97 }, "stray continuation byte")
  T.deq(U.utf8chars("\192\128"), { 63, 63 }, "overlong encoding rejected")
  T.deq(U.utf8chars("\237\160\128"), { 63, 63, 63 }, "surrogate rejected")
  T.eq(U.utf8len("h\195\169llo"), 5, "utf8len")
  T.eq(U.utf8len(""), 0, "utf8len empty")
end

function test_ascii()
  T.eq(U.ascii('a<b&"c"'), "a&lt;b&amp;&quot;c&quot;", "xml escapes")
  T.eq(U.ascii("x>y"), "x&gt;y", "gt escape")
  T.eq(U.ascii("caf\195\169"), "caf&#233;", "latin char reference")
  T.eq(U.ascii("\215\169\215\156\215\149\215\157"), "&#1513;&#1500;&#1493;&#1501;", "hebrew")
  T.eq(U.ascii("\240\159\152\128"), "&#128512;", "emoji")
  T.eq(U.ascii("a\255b"), "a?b", "invalid byte")
  T.eq(U.ascii("\226\128"), "??", "truncated sequence")
  T.eq(U.ascii("\127"), "&#127;", "DEL is referenced")
  T.eq(U.ascii("a\1b"), "a?b", "control char")
  T.eq(U.ascii("a\nb"), "a\nb", "newline kept")
  T.eq(U.ascii(nil), "", "nil")
  T.eq(U.ascii(12), "12", "number")
  T.ok(isAscii(U.ascii("<\215\144&\240\159\152\128\255>")), "mixed output is ascii")
end

function test_truncate_chars()
  T.eq(U.truncateChars("h\195\169llo", 2), "h\195\169", "keeps a whole sequence")
  T.eq(U.truncateChars("h\195\169llo", 1), "h", "one char")
  T.eq(U.truncateChars("h\195\169llo", 0), "", "zero chars")
  T.eq(U.truncateChars("hi", 10), "hi", "n beyond length")
  T.eq(U.truncateChars("\240\159\152\128ab", 1), "\240\159\152\128", "four-byte sequence")
end

function test_tables()
  local src = { a = { b = { 1, 2 } }, c = "x" }
  local cp = U.deepcopy(src)
  T.deq(cp, src, "deepcopy equal")
  cp.a.b[1] = 99
  T.eq(src.a.b[1], 1, "deepcopy is independent")
  T.deq(U.keys({ zeta = 1, alpha = 2, mid = 3 }), { "alpha", "mid", "zeta" }, "keys sorted")
  T.deq(U.keys({ [3] = 1, [1] = 2, b = 3, a = 4 }), { 1, 3, "a", "b" }, "keys mixed types")
  T.eq(U.indexOf({ "a", "b", "c" }, "b"), 2, "indexOf")
  T.eq(U.indexOf({ "a" }, "z"), nil, "indexOf missing")
end

function test_colours()
  local r, g, b = U.hexToRgb("#C513E8")
  T.eq(r, 197, "r") T.eq(g, 19, "g") T.eq(b, 232, "b")
  T.eq(U.hexToRgb("C513E8"), nil, "no hash")
  T.eq(U.hexToRgb("#C513E"), nil, "short")
  T.eq(U.hexToRgb("#GG0000"), nil, "bad digit")
  T.eq(U.rgbToHex(197, 19, 232), "#C513E8", "rgbToHex")
  T.eq(U.rgbToHex(300, -5, 12.6), "#FF000D", "rgbToHex clamps and rounds")
  T.ok(U.isHex("#abcdef"), "isHex lower")
  T.ok(not U.isHex("#abcdeg"), "isHex bad")
  T.ok(not U.isHex(123), "isHex non-string")
end

function test_csv_cell()
  T.eq(U.csvCell("plain"), "plain", "plain")
  T.eq(U.csvCell("a,b"), '"a,b"', "comma quoted")
  T.eq(U.csvCell('say "hi"'), '"say ""hi"""', "quotes doubled")
  T.eq(U.csvCell("line\nbreak"), '"line\nbreak"', "newline quoted")
  T.eq(U.csvCell("=1+1"), "'=1+1", "formula prefix")
  T.eq(U.csvCell("+5"), "'+5", "plus prefix")
  T.eq(U.csvCell("-5"), "'-5", "minus prefix")
  T.eq(U.csvCell("@x"), "'@x", "at prefix")
  T.eq(U.csvCell(" lead"), '" lead"', "leading space quoted")
  T.eq(U.csvCell(nil), "", "nil")
  T.eq(U.csvCell(42), "42", "number")
end

function test_json_encode()
  T.eq(U.jsonEncode({ b = 1, a = "x" }), '{"a":"x","b":1}', "object sorted keys")
  T.eq(U.jsonEncode({ 1, 2, 3 }), "[1,2,3]", "array")
  T.eq(U.jsonEncode({ { x = 1 }, { y = { true, false } } }), '[{"x":1},{"y":[true,false]}]', "nested")
  T.eq(U.jsonEncode('a"b\\c\n\t'), '"a\\"b\\\\c\\n\\t"', "string escapes")
  T.eq(U.jsonEncode("\1"), '"\\u0001"', "control escape")
  T.eq(U.jsonEncode(nil), "null", "nil")
  T.eq(U.jsonEncode(true), "true", "true")
  T.eq(U.jsonEncode(1.5), "1.5", "float")
  T.eq(U.jsonEncode(3.0), "3", "integral float")
  T.eq(U.jsonEncode(0 / 0), "null", "nan")
  T.eq(U.jsonEncode({}), "[]", "empty table")
  T.eq(U.jsonEncode({ [1] = 1, [3] = 3 }), '{"1":1,"3":3}', "sparse is an object")
  T.eq(U.jsonEncode({ [1] = "a", x = 2 }), '{"1":"a","x":2}', "mixed keys is an object")
  T.eq(U.jsonEncode({ "caf\195\169" }), '["caf\195\169"]', "utf-8 passes through")
end

function test_base64()
  T.eq(U.base64(""), "", "empty")
  T.eq(U.base64("f"), "Zg==", "f")
  T.eq(U.base64("fo"), "Zm8=", "fo")
  T.eq(U.base64("foo"), "Zm9v", "foo")
  T.eq(U.base64("foob"), "Zm9vYg==", "foob")
  T.eq(U.base64("fooba"), "Zm9vYmE=", "fooba")
  T.eq(U.base64("foobar"), "Zm9vYmFy", "foobar")
  T.eq(U.base64("\0\255"), "AP8=", "binary")
  T.eq(U.base64("\255\255\255"), "////", "all ones")
end

function test_polygons()
  local sq = { 0, 0, 10, 0, 10, 10, 0, 10 }
  T.ok(U.pointInPoly(5, 5, sq), "inside")
  T.ok(not U.pointInPoly(15, 5, sq), "outside")
  T.ok(not U.pointInPoly(5, -1, sq), "outside above")
  T.eq(U.polyArea(sq), 100, "area")
  T.eq(U.polyArea({ 0, 0, 0, 10, 10, 10, 10, 0 }), 100, "area is absolute")
  T.eq(U.polyArea({ 0, 0, 1, 1 }), 0, "degenerate")
  local cx, cy = U.polyCentroid(sq)
  T.near(cx, 5, 1e-9, "centroid x") T.near(cy, 5, 1e-9, "centroid y")
  local tx, ty = U.polyCentroid({ 0, 0, 6, 0, 0, 6 })
  T.near(tx, 2, 1e-9, "triangle centroid x") T.near(ty, 2, 1e-9, "triangle centroid y")
  local lx, ly = U.polyCentroid({ 0, 0, 4, 0 })
  T.near(lx, 2, 1e-9, "degenerate centroid is the mean")
  T.near(ly, 0, 1e-9, "degenerate centroid y")
end

function test_simplify()
  T.deq(U.simplify({ 0, 0, 5, 0.1, 10, 0 }, 1), { 0, 0, 10, 0 }, "collinear middle dropped")
  T.deq(U.simplify({ 0, 0, 5, 5, 10, 0 }, 1), { 0, 0, 5, 5, 10, 0 }, "peak kept")
  T.deq(U.simplify({ 0, 0, 10, 0 }, 1), { 0, 0, 10, 0 }, "two points unchanged")
  T.deq(U.simplify({ 3, 4 }, 1), { 3, 4 }, "single point")
  T.deq(U.simplify({}, 1), {}, "empty")
  local pts = {}
  for i = 0, 100 do pts[#pts + 1] = i; pts[#pts + 1] = (i % 2) * 0.2 end
  local out = U.simplify(pts, 0.5)
  T.deq(out, { 0, 0, 100, 0 }, "small zigzag flattened")
  local fine = U.simplify(pts, 0.05)
  T.eq(#fine, #pts, "below tolerance keeps every point")
  local src = { 0, 0, 1, 1, 2, 2 }
  U.simplify(src, 10)
  T.deq(src, { 0, 0, 1, 1, 2, 2 }, "input is not modified")
end

function test_even_pages()
  T.deq(U.evenPages(50, 7), { 7, 7, 6, 6, 6, 6, 6, 6 }, "50/7")
  T.deq(U.evenPages(13, 7), { 7, 6 }, "13/7")
  T.deq(U.evenPages(17, 16), { 9, 8 }, "17/16")
  T.deq(U.evenPages(12, 12), { 12 }, "12/12")
  T.deq(U.evenPages(5, 12), { 5 }, "fewer than a page")
  T.deq(U.evenPages(0, 7), {}, "zero items")
  T.deq(U.evenPages(3, 0), { 1, 1, 1 }, "perPage below 1 is treated as 1")
end

function test_iso_time()
  T.eq(U.isoTime(0), "1970-01-01T00:00:00Z", "epoch")
  T.eq(U.isoTime(1700000000), "2023-11-14T22:13:20Z", "known time")
  T.eq(U.isoTime(951782400), "2000-02-29T00:00:00Z", "leap day")
  T.eq(U.isoTime(1709251199), "2024-02-29T23:59:59Z", "end of leap day")
  T.ok(string.find(U.isoTime(), "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") ~= nil, "now has the format")
end

-- ---------- regressions from review ----------

function test_clamp_nan()
  T.eq(U.clamp(0 / 0, 0, 1), 0, "NaN clamps to the lower bound")
  T.eq(U.clamp(0 / 0, -5, 5), -5, "NaN clamps to the lower bound of any range")
  T.eq(U.rgbToHex(0 / 0, 0, 0), "#000000", "rgbToHex with a NaN channel")
  T.eq(U.rgbToHex(math.huge, -math.huge, 1), "#FF0001", "rgbToHex with infinite channels")
  T.eq(U.rgbToHex("12", nil, "x"), "#0C0000", "rgbToHex coerces strings and ignores junk")
  T.eq(Svg.lighten("#FFFFFF", 0 / 0), "#000000", "lighten with a NaN amount does not raise")
  T.eq(Svg.mix("#000000", "#FFFFFF", 0 / 0), "#000000", "mix with a NaN factor does not raise")
end

function test_pad2_non_finite()
  T.eq(U.pad2(0 / 0), "00", "NaN")
  T.eq(U.pad2(math.huge), "00", "inf")
  T.eq(U.pad2(-math.huge), "00", "-inf")
  T.eq(U.pad2(1e300), "00", "beyond the integer range")
  T.eq(U.pad2(nil), "00", "nil")
  T.eq(U.pad2("7"), "07", "numeric string")
  T.eq(U.pad2(7.9), "07", "floors")
end

function test_ascii_xml_nonchars()
  T.eq(U.ascii("\239\191\190"), "?", "U+FFFE is not an XML character")
  T.eq(U.ascii("\239\191\191"), "?", "U+FFFF is not an XML character")
  T.eq(U.ascii("\239\191\189"), "&#65533;", "U+FFFD is still referenced")
  T.eq(U.ascii("a\239\191\190b"), "a?b", "noncharacter inside text")
end

function test_deepcopy_cycles()
  local t = { name = "a" }
  t.self = t
  t.list = { t, t }
  local cp = U.deepcopy(t)
  T.ok(cp ~= t, "a copy was made")
  T.eq(cp.self, cp, "self reference points at the copy")
  T.eq(cp.list[1], cp, "shared reference points at the copy")
  T.eq(cp.list[2], cp.list[1], "sharing preserved")
  T.eq(cp.name, "a", "values copied")
  local shared = { x = 1 }
  local two = U.deepcopy({ a = shared, b = shared })
  T.eq(two.a, two.b, "a shared subtable is copied once")
  T.ok(two.a ~= shared, "shared subtable is a copy")
  local deep = {}
  local cur = deep
  for _ = 1, 100 do cur[1] = {}; cur = cur[1] end
  local dc = U.deepcopy(deep)
  T.ok(dc ~= deep, "deep nesting copies without overflowing")
end

function test_json_cycles()
  local t = { name = "a" }
  t.self = t
  T.eq(U.jsonEncode(t), '{"name":"a","self":null}', "a cycle encodes as null")
  local shared = { 1 }
  T.eq(U.jsonEncode({ shared, shared }), "[[1],[1]]", "a shared subtable is encoded in both places")
  local ring = { { } }
  ring[1][1] = ring
  T.eq(U.jsonEncode(ring), "[[null]]", "a longer cycle encodes as null")
  local deep = {}
  local cur = deep
  for _ = 1, 100 do cur[1] = {}; cur = cur[1] end
  local s = U.jsonEncode(deep)
  T.ok(string.find(s, "null", 1, true) ~= nil, "nesting beyond the depth cap becomes null")
end

function test_even_pages_non_finite()
  T.deq(U.evenPages(math.huge, 7), {}, "inf items gives no pages")
  T.deq(U.evenPages(-math.huge, 7), {}, "-inf items gives no pages")
  T.deq(U.evenPages(0 / 0, 7), {}, "NaN items gives no pages")
  T.deq(U.evenPages(5, math.huge), { 5 }, "inf per page is one page")
  T.deq(U.evenPages(5, 0 / 0), { 1, 1, 1, 1, 1 }, "NaN per page is treated as 1")
  T.deq(U.evenPages("50", "7"), { 7, 7, 6, 6, 6, 6, 6, 6 }, "numeric strings accepted")
  T.eq(#U.evenPages(1e300, 50000), 2, "huge counts are capped")
  local n = T.instructions(function() U.evenPages(math.maxinteger, 1) end)
  T.ok(n < 2000000, "a capped count stays bounded (" .. n .. ")")
end

function test_iso_time_before_year_zero()
  T.eq(U.isoTime(-62162035200), "0000-03-01T00:00:00Z", "0000-03-01")
  T.eq(U.isoTime(-62162121600), "0000-02-29T00:00:00Z", "year 0 is a leap year")
  T.eq(U.isoTime(-62162208000), "0000-02-28T00:00:00Z", "two days before 0000-03-01")
  T.eq(U.isoTime(-62162294400), "0000-02-27T00:00:00Z", "three days before 0000-03-01")
  T.eq(U.isoTime(-62162035200 - 86400 * 366), "-001-03-01T00:00:00Z", "a year earlier (year 0 has 366 days)")
end
