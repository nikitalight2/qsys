-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: unit tests for 40_framework.lua and the XY Pad design time

local EN_DASH = "\226\128\147"

local function defaults(mode, tweak)
  local props = {}
  for _, p in ipairs(GetProperties()) do props[p.Name] = { Value = p.Value } end
  if mode then props["Mode"].Value = mode end
  if tweak then tweak(props) end
  RectifyProperties(props)
  return props
end

local function pageNames(props)
  local out = {}
  for i, p in ipairs(GetPages(props)) do out[i] = p.name end
  return out
end

local function layoutOf(props, pageName)
  for i, n in ipairs(pageNames(props)) do
    if n == pageName then
      props["page_index"] = { Value = i }
      return GetControlLayout(props)
    end
  end
  error("no page named " .. tostring(pageName))
end

local function byName(list)
  local out = {}
  for _, c in ipairs(list) do out[c.Name] = c end
  return out
end

local function names(list)
  local out = {}
  for i, c in ipairs(list) do out[i] = c.Name end
  return out
end

local function isAscii(s)
  s = tostring(s):gsub(EN_DASH, "-")
  return not s:find("[\128-\255]")
end

-- A throwaway mode exercising C.add and the L helpers; removed after each test.
local TEST_MODE = "Unit Test Mode"
local function withTestMode(tbl, fn)
  Modes[TEST_MODE] = tbl
  local ok, err = pcall(fn)
  Modes[TEST_MODE] = nil
  if not ok then error(err, 0) end
end

local function testModeTable()
  return {
    id = "unit", pretty = "Unit Test", hint = "Testing",
    pages = { "Names" },
    controls = function(C, props)
      C.add({ Name = "ZoneSelected", ControlType = "Button", ButtonType = "Toggle", PinStyle = "Both",
              Count = props["Zones"].Value, Group = "Zones" })
      C.add({ Name = "Curve", ControlType = "Text", Choices = { "Linear", "Squared" } })
      C.add({ Name = "Home", ControlType = "Button", ButtonType = "Trigger", PinStyle = "Both" })
      C.add({ Name = "Level", ControlType = "Knob", ControlUnit = "Float", Min = 0, Max = 1, DefaultValue = 0.5, PinStyle = "Input" })
    end,
    layout = function(L, page, props, ctx)
      if page == "Pad" then
        L.sideButton(ctx, "Home", "HOME")
      elseif page == "Setup" then
        local ix, iy, iw = L.section(ctx, "T E S T", 48)
        L.flow({ "Curve", "Level" }, ix, iy, iw)
      elseif page == "Names" then
        L.grid(L.keys("ZoneSelected"), ctx.x, ctx.y, 4, 100, 48)
      end
    end,
  }
end

-- ---------------------------------------------------------------- properties

function test_properties_order_and_types()
  local props = GetProperties()
  local expected = { "Mode", "Pad Width", "Pad Height", "Color Picker", "Swap Axes", "Flip X", "Flip Y",
    "Theme", "Accent Color", "Background Color", "Text Color", "Background", "Corner Radius", "Font",
    "Show Hints", "Max Frame Rate", "Icon Channel", "Camera Control", "Camera Name", "VISCA Brand",
    "Zones", "Sources", "Destinations", "Speakers", "Orientation", "Sign-In Webhook", "Debug Print" }
  T.deq(names(props), expected, "property names in order")
  local reserved = { ["is managed"] = true, ["is required"] = true, ["location"] = true, ["show debug"] = true,
    ["showdebug"] = true, ["page_index"] = true, ["name"] = true, ["script access"] = true, ["code name"] = true }
  for _, p in ipairs(props) do
    T.ok(not reserved[p.Name:lower()], "no reserved property name: " .. p.Name)
  end
  local valid = { string = true, integer = true, double = true, boolean = true, enum = true }
  for _, p in ipairs(props) do
    T.ok(valid[p.Type], "valid type for " .. p.Name)
    if p.Type == "enum" then
      T.ok(type(p.Choices) == "table" and #p.Choices > 0, "choices for " .. p.Name)
      local found = false
      for _, c in ipairs(p.Choices) do if c == p.Value then found = true end end
      T.ok(found, "default is a choice for " .. p.Name)
    elseif p.Type == "integer" then
      T.ok(type(p.Min) == "number" and type(p.Max) == "number" and p.Min <= p.Value and p.Value <= p.Max, "range for " .. p.Name)
    end
  end
  local m = byName(props)
  T.deq(m["Mode"].Choices, MODE_NAMES, "mode choices are MODE_NAMES")
  T.eq(m["Mode"].Value, "XY Pad", "default mode")
  T.eq(m["Pad Width"].Max, 1600, "pad width max")
  T.eq(m["Pad Height"].Max, 1200, "pad height max")
  T.eq(m["Max Frame Rate"].Value, "20", "frame rate default")
  T.eq(m["Icon Channel"].Value, "Legend", "icon channel default")
  T.eq(m["Corner Radius"].Value, 18, "corner radius default")
  T.eq(m["Font"].Value, "Roboto", "font default")
end

function test_pretty_name()
  T.eq(GetPrettyName(defaults()), "Touch Pad: XY Pad 500x500", "default pretty name")
  local props = defaults("Dial", function(p) p["Pad Width"].Value = 800; p["Pad Height"].Value = 400 end)
  T.eq(GetPrettyName(props), "Touch Pad: Dial 800x400", "mode and size in the name")
  T.ok(GetPrettyName(nil):find("Touch Pad", 1, true), "survives nil props")
  T.ok(GetPrettyName({}):find("XY Pad", 1, true), "empty props fall back to the default mode")
end

function test_rectify_hides_by_mode()
  local p = defaults("XY Pad")
  for _, name in ipairs({ "Zones", "Sources", "Destinations", "Camera Control", "Camera Name", "VISCA Brand",
                          "Speakers", "Orientation", "Sign-In Webhook", "Accent Color" }) do
    T.eq(p[name].IsHidden, true, name .. " hidden for XY Pad")
  end
  for _, name in ipairs({ "Mode", "Pad Width", "Theme", "Swap Axes", "Flip X", "Flip Y", "Icon Channel", "Debug Print" }) do
    T.ok(not p[name].IsHidden, name .. " visible for XY Pad")
  end
  T.eq(defaults("Zone Select")["Zones"].IsHidden, false, "Zones for Zone Select")
  T.eq(defaults("Panner")["Speakers"].IsHidden, false, "Speakers for Panner")
  T.eq(defaults("Fader")["Orientation"].IsHidden, false, "Orientation for Fader")
  T.eq(defaults("Sign-In")["Sign-In Webhook"].IsHidden, false, "Webhook for Sign-In")
  local m = defaults("Matrix")
  T.eq(m["Sources"].IsHidden, false, "Sources for Matrix")
  T.eq(m["Destinations"].IsHidden, false, "Destinations for Matrix")
  T.eq(m["Zones"].IsHidden, true, "Zones hidden for Matrix")
  local d = defaults("Drag & Drop")
  T.eq(d["Sources"].IsHidden, false, "Sources for Drag & Drop")
end

function test_rectify_camera_and_theme()
  local j = defaults("Joystick")
  T.eq(j["Camera Control"].IsHidden, false, "Camera Control for Joystick")
  T.eq(j["Camera Name"].IsHidden, true, "Camera Name hidden while None")
  T.eq(j["VISCA Brand"].IsHidden, true, "VISCA Brand hidden while None")
  local q = defaults("PTZ Pad", function(p) p["Camera Control"].Value = "Q-SYS Camera" end)
  T.eq(q["Camera Name"].IsHidden, false, "Camera Name for Q-SYS Camera")
  T.eq(q["VISCA Brand"].IsHidden, true, "VISCA Brand hidden for Q-SYS Camera")
  local v = defaults("Camera Framing", function(p) p["Camera Control"].Value = "VISCA over IP" end)
  T.eq(v["VISCA Brand"].IsHidden, false, "VISCA Brand for VISCA")
  T.eq(v["Camera Name"].IsHidden, true, "Camera Name hidden for VISCA")
  T.eq(defaults("Dial")["Camera Control"].IsHidden, false, "Dial is a camera mode")
  T.eq(defaults("Knob")["Camera Control"].IsHidden, true, "Knob is not a camera mode")
  local c = defaults("XY Pad", function(p) p["Theme"].Value = "Custom" end)
  T.eq(c["Accent Color"].IsHidden, false, "Accent Color for Custom")
  T.eq(c["Background Color"].IsHidden, false, "Background Color for Custom")
  T.eq(c["Text Color"].IsHidden, false, "Text Color for Custom")
  T.eq(defaults()["Text Color"].IsHidden, true, "Text Color hidden for Nikita")
end

function test_rectify_never_errors()
  local p = defaults("No Such Mode")
  T.eq(p["Zones"].IsHidden, true, "unknown mode hides mode properties")
  T.eq(RectifyProperties({}) ~= nil, true, "empty props")
  T.eq(RectifyProperties(nil), nil, "nil props returns nil without error")
  local partial = { Mode = { Value = "Zone Select" } }
  T.eq(RectifyProperties(partial), partial, "partial props returned")
  local odd = defaults(nil, function(q) q["Mode"].Value = 42 end)
  T.eq(odd["Zones"].IsHidden, true, "non-string mode value")
end

-- ---------------------------------------------------------------- controls

function test_common_controls()
  local list = GetControls(defaults())
  local expected = { "Status", "Display", "Picker", "Refresh", "PanelTouch", "Calibrate", "Calibration",
    "PickerLayout", "ReleaseTime", "LongPressTime", "Lock", "Touching", "X", "Y", "Tap", "DoubleTap",
    "LongPress", "Press", "Release", "SwipeLeft", "SwipeRight", "SwipeUp", "SwipeDown", "Gesture",
    "DragDistance", "DragAngle" }
  T.deq(names(list), expected, "common controls in order")
  T.eq(#list, 26, "26 common controls")
  local m = byName(list)
  T.eq(m["Status"].IndicatorType, "Status", "Status indicator")
  T.eq(m["Display"].ButtonType, "Momentary", "Display momentary")
  T.eq(m["Touching"].IndicatorType, "Led", "Touching led")
  T.eq(m["Gesture"].IndicatorType, "Text", "Gesture text")
  T.eq(m["PickerLayout"].ControlType, "Indicator", "PickerLayout indicator")
  T.eq(m["Calibration"].ControlType, "Text", "Calibration text")
  for _, c in ipairs(list) do
    T.eq(c.Count, 1, "Count 1 for " .. c.Name)
    T.eq(c.Group, nil, "no Group key leaks for " .. c.Name)
    T.eq(c.Pretty, nil, "no Pretty key leaks for " .. c.Name)
  end
  T.eq(#GetControls(defaults("Whiteboard")), 26, "a mode without a module gets the common set")
end

function test_pin_styles()
  local m = byName(GetControls(defaults()))
  local function pin(name, style)
    T.eq(m[name].PinStyle, style, name .. " pin style")
    T.eq(m[name].UserPin, true, name .. " user pin")
  end
  pin("Status", "Output")
  pin("Picker", "Input"); pin("Refresh", "Input"); pin("PanelTouch", "Input"); pin("Calibrate", "Input")
  pin("ReleaseTime", "Input"); pin("LongPressTime", "Input"); pin("Lock", "Input")
  pin("Touching", "Output"); pin("X", "Output"); pin("Y", "Output"); pin("Gesture", "Output")
  pin("Press", "Output"); pin("Release", "Output"); pin("DragDistance", "Output"); pin("DragAngle", "Output")
  pin("Tap", "Both"); pin("DoubleTap", "Both"); pin("LongPress", "Both")
  pin("SwipeLeft", "Both"); pin("SwipeRight", "Both"); pin("SwipeUp", "Both"); pin("SwipeDown", "Both")
  for _, name in ipairs({ "Display", "Calibration", "PickerLayout" }) do
    T.eq(m[name].PinStyle, nil, name .. " has no pin")
    T.eq(m[name].UserPin, nil, name .. " has no user pin")
  end
  T.eq(m["ReleaseTime"].ControlUnit, "Seconds", "ReleaseTime unit")
  T.eq(m["ReleaseTime"].Min, 0.1, "ReleaseTime min"); T.eq(m["ReleaseTime"].Max, 1.0, "ReleaseTime max")
  T.eq(m["ReleaseTime"].DefaultValue, 0.25, "ReleaseTime default")
  T.eq(m["LongPressTime"].Min, 0.3, "LongPressTime min"); T.eq(m["LongPressTime"].Max, 3, "LongPressTime max")
  T.eq(m["LongPressTime"].DefaultValue, 0.6, "LongPressTime default")
  T.eq(m["X"].ControlUnit, "Float", "X unit"); T.eq(m["X"].Min, 0, "X min"); T.eq(m["X"].Max, 1, "X max")
  T.eq(m["DragDistance"].Max, 2, "DragDistance max")
  T.eq(m["DragAngle"].Min, -180, "DragAngle min"); T.eq(m["DragAngle"].Max, 180, "DragAngle max")
  T.eq(m["Tap"].ButtonType, "Trigger", "Tap trigger"); T.eq(m["Lock"].ButtonType, "Toggle", "Lock toggle")
end

function test_camera_controls()
  T.eq(#GetControls(defaults("Joystick")), 26, "no camera controls while None")
  local demo = byName(GetControls(defaults("Joystick", function(p) p["Camera Control"].Value = "Demo (simulated)" end)))
  for _, name in ipairs({ "ZoomIn", "ZoomOut", "MaxSpeed", "ZoomSpeed", "CameraStatus", "CameraView" }) do
    T.ok(demo[name] ~= nil, name .. " present for Demo")
  end
  T.eq(demo["CameraIP"], nil, "no CameraIP for Demo")
  T.eq(demo["ZoomIn"].ButtonType, "Momentary", "ZoomIn momentary")
  T.eq(demo["ZoomIn"].PinStyle, "Input", "ZoomIn input pin")
  T.eq(demo["CameraStatus"].PinStyle, "Output", "CameraStatus output")
  T.eq(demo["CameraView"].PinStyle, nil, "CameraView has no pin")
  T.eq(demo["MaxSpeed"].ControlUnit, "Percent", "MaxSpeed percent")
  local visca = byName(GetControls(defaults("PTZ Pad", function(p) p["Camera Control"].Value = "VISCA over IP" end)))
  T.ok(visca["CameraIP"] ~= nil, "CameraIP for VISCA")
  T.eq(visca["CameraIP"].PinStyle, "Input", "CameraIP input")
  T.eq(visca["CameraView"], nil, "no CameraView for VISCA")
  local xy = GetControls(defaults("XY Pad", function(p) p["Camera Control"].Value = "Demo (simulated)" end))
  T.eq(#xy, 26, "camera property ignored outside camera modes")
end

function test_mode_controls_and_count()
  withTestMode(testModeTable(), function()
    local list = GetControls(defaults(TEST_MODE))
    T.eq(#list, 30, "common + 4 mode controls")
    local m = byName(list)
    T.eq(m["ZoneSelected"].Count, 8, "Count from the Zones property")
    T.eq(m["ZoneSelected"].PinStyle, "Both", "mode pin style kept")
    T.eq(m["ZoneSelected"].UserPin, true, "pinned mode control gets UserPin")
    T.eq(m["Curve"].Choices, nil, "Choices stay out of the Designer definition")
    T.eq(m["Curve"].ControlType, "Text", "Curve is a Text control")
    T.eq(m["Curve"].UserPin, nil, "unpinned mode control has no UserPin")
    T.eq(m["Level"].DefaultValue, 0.5, "DefaultValue kept")
    local big = byName(GetControls(defaults(TEST_MODE, function(p) p["Zones"].Value = 32 end)))
    T.eq(big["ZoneSelected"].Count, 32, "Count follows the property")
    local _, meta = Framework.buildControls(defaults(TEST_MODE))
    T.eq(meta["ZoneSelected"].pretty, "Zones~Zone Selected", "group from the definition")
    T.eq(meta["Home"].pretty, "Unit Test~Home", "default group is the mode's pretty name")
    T.eq(meta["X"].pretty, "Live~X", "common Live group")
    T.eq(meta["SwipeLeft"].pretty, "Actions~Swipe Left", "common Actions group, spaced")
    T.eq(meta["Curve"].choices[2], "Squared", "choices kept in the metadata")
  end)
  withTestMode({ controls = function(C) C.add({ Name = "X", ControlType = "Text" }) end }, function()
    T.err(function() GetControls(defaults(TEST_MODE)) end, "duplicate control name errors")
  end)
  withTestMode({ controls = function(C) C.add({ ControlType = "Text" }) end }, function()
    T.err(function() GetControls(defaults(TEST_MODE)) end, "control without a Name errors")
  end)
end

-- ---------------------------------------------------------------- pages

function test_pages()
  T.deq(pageNames(defaults("XY Pad")), { "Pad", "Setup", "Outputs", "Display", "About" }, "XY pages")
  T.deq(pageNames(defaults("Zone Select")), { "Pad", "Setup", "Names", "Outputs", "Display", "About" }, "Zone Select pages")
  T.deq(pageNames(defaults("Matrix")), { "Pad", "Setup", "Names", "Outputs", "Display", "About" }, "Matrix pages")
  local dd = defaults("Drag & Drop", function(p) p["Sources"].Value = 20 end)
  T.deq(pageNames(dd), { "Pad", "Setup", "Sources", "Destinations", "Outputs", "Display", "About" }, "split names pages")
  local dd2 = defaults("Matrix", function(p) p["Destinations"].Value = 17 end)
  T.deq(pageNames(dd2), { "Pad", "Setup", "Sources", "Destinations", "Outputs", "Display", "About" }, "split on destinations")
  local demo = defaults("Joystick", function(p) p["Camera Control"].Value = "Demo (simulated)" end)
  T.deq(pageNames(demo), { "Pad", "Setup", "Camera View", "Outputs", "Display", "About" }, "camera view page")
  local visca = defaults("Joystick", function(p) p["Camera Control"].Value = "VISCA over IP" end)
  T.deq(pageNames(visca), { "Pad", "Setup", "Outputs", "Display", "About" }, "no camera view for VISCA")
  T.deq(pageNames(defaults("Whiteboard")), { "Pad", "Setup", "Outputs", "Display", "About" }, "mode without module")
  withTestMode(testModeTable(), function()
    T.deq(pageNames(defaults(TEST_MODE)), { "Pad", "Setup", "Names", "Outputs", "Display", "About" }, "mode-declared extra page")
  end)
  withTestMode({ pages = function(props) return { "A", "B" } end }, function()
    T.deq(pageNames(defaults(TEST_MODE)), { "Pad", "Setup", "A", "B", "Outputs", "Display", "About" }, "pages as a function")
  end)
  for _, p in ipairs(GetPages(defaults())) do T.eq(type(p.name), "string", "page entries carry a name") end
end

-- ---------------------------------------------------------------- layout

function test_layout_every_page()
  local props = defaults("XY Pad")
  for _, page in ipairs(pageNames(props)) do
    local layout, graphics = layoutOf(props, page)
    T.ok(layout["Status"] ~= nil, "Status on " .. page)
    T.eq(layout["Status"].PrettyName, "Setup~Status", "Status pretty name on " .. page)
    T.eq(layout["Status"].Style, "Led", "Status style on " .. page)
    T.eq(graphics[1].Type, "GroupBox", "background first on " .. page)
    T.ok(graphics[1].Size[1] >= 700 and graphics[1].Size[2] > 48, "page size on " .. page)
    T.eq(graphics[2].Size[1], graphics[1].Size[1], "header spans the page on " .. page)
    T.eq(#LAYOUT_PROBLEMS, 0, "no layout problems on " .. page)
    local hasLogoLine = false
    for _, g in ipairs(graphics) do
      if g.Type == "Label" and g.Text == BrandName then hasLogoLine = true end
      if g.Text then T.ok(isAscii(g.Text), "ascii text on " .. page) end
    end
    T.ok(hasLogoLine, "brand name in the header on " .. page)
  end
  local pad = layoutOf(props, "Pad")
  T.deq(pad["Display"].Size, { 500, 500 }, "Display at pad size on Pad")
  T.eq(pad["Display"].ButtonVisualStyle, "Flat", "Display flat")
  T.eq(pad["Display"].IsReadOnly, true, "Display read only")
  T.deq(pad["Display"].Color, { 255, 255, 255 }, "Display white")
  T.ok(pad["Gesture"] ~= nil and pad["Gesture"].IsReadOnly, "Gesture readout on Pad")
  T.ok(pad["Lock"] ~= nil, "Lock in the side column")
  local disp = layoutOf(props, "Display")
  T.deq(disp["Display"].Size, { 500, 500 }, "Display at exact size on the Display page")
  local wide = defaults("XY Pad", function(p) p["Pad Width"].Value = 1600; p["Pad Height"].Value = 300 end)
  local padW = layoutOf(wide, "Pad")
  T.deq(padW["Display"].Size, { 760, 143 }, "Pad page scales a wide pad to 760")
  local dispW = layoutOf(wide, "Display")
  T.deq(dispW["Display"].Size, { 1600, 300 }, "Display page keeps the exact size")
  T.eq(pad["Picker"], nil, "Picker is not on the Pad page")
  local setup = layoutOf(props, "Setup")
  for _, name in ipairs({ "Picker", "Refresh", "PanelTouch", "Calibrate", "Calibration", "PickerLayout", "ReleaseTime", "LongPressTime", "Lock" }) do
    T.ok(setup[name] ~= nil, name .. " on Setup")
  end
  T.eq(setup["Picker"].PrettyName, "Setup~Picker", "Picker pretty name")
  T.eq(setup["Lock"].PrettyName, "Setup~Lock", "Lock pretty name")
  T.eq(setup["PickerLayout"].PrettyName, nil, "no pretty name without a pin")
end

function test_outputs_page()
  local layout = layoutOf(defaults(), "Outputs")
  local expect = { X = "Live~X", Y = "Live~Y", Touching = "Live~Touching", Gesture = "Live~Gesture",
                   DragDistance = "Live~Drag Distance", DragAngle = "Live~Drag Angle",
                   Tap = "Actions~Tap", DoubleTap = "Actions~Double Tap", LongPress = "Actions~Long Press",
                   Press = "Actions~Press", Release = "Actions~Release", SwipeLeft = "Actions~Swipe Left",
                   SwipeRight = "Actions~Swipe Right", SwipeUp = "Actions~Swipe Up", SwipeDown = "Actions~Swipe Down" }
  for name, pretty in pairs(expect) do
    T.ok(layout[name] ~= nil, name .. " on Outputs")
    T.eq(layout[name].PrettyName, pretty, name .. " pretty name")
  end
  T.eq(layout["X"].Style, "Knob", "X as a knob")
  T.eq(layout["Touching"].Style, "Led", "Touching as a led")
  T.eq(layout["Tap"].Style, "Button", "Tap as a button")
  T.eq(layout["Tap"].ButtonStyle, "Trigger", "Tap trigger style")
  T.eq(layout["Gesture"].Style, "Text", "Gesture as text")
  T.eq(layout["Picker"], nil, "inputs are not on Outputs")
  T.eq(layout["Display"], nil, "Display is not on Outputs")
  T.eq(layout["Status"] ~= nil, true, "Status stays in the header")
  -- 15 outputs fit one column of 16: all share the first column's x.
  T.eq(layout["X"].Position[1] > 0 and layout["Tap"].Position[2] > layout["X"].Position[2], true, "cells flow down a column")
  local demo = layoutOf(defaults("Joystick", function(p) p["Camera Control"].Value = "Demo (simulated)" end), "Outputs")
  T.eq(demo["CameraStatus"].PrettyName, "Camera~Camera Status", "camera output listed")
  T.eq(demo["ZoomIn"], nil, "camera inputs not listed")
  withTestMode(testModeTable(), function()
    local big = layoutOf(defaults(TEST_MODE, function(p) p["Zones"].Value = 32 end), "Outputs")
    T.ok(big["ZoneSelected 1"] ~= nil and big["ZoneSelected 32"] ~= nil, "long arrays listed as mini cells")
    T.eq(big["ZoneSelected 32"].PrettyName, "Zones~Zone Selected 32", "indexed pretty name")
    T.eq(big["Home"].PrettyName, "Unit Test~Home", "mode group on a Both pin")
  end)
end

function test_layout_builder_helpers()
  withTestMode(testModeTable(), function()
    local props = defaults(TEST_MODE)
    local pad = layoutOf(props, "Pad")
    T.eq(pad["Home"].Style, "Button", "sideButton places a button")
    T.eq(pad["Home"].Legend, "HOME", "sideButton legend")
    T.eq(pad["Home"].ButtonStyle, "Trigger", "style from the definition")
    T.eq(pad["Home"].Position[1], 16 + 500 + 12, "side column right of the pad")
    T.ok(pad["Lock"].Position[2] > pad["Home"].Position[2], "framework buttons stack below the mode's")
    T.ok(pad["Display"] ~= nil and pad["Gesture"] ~= nil, "framework fills the pad for a mode that does not")
    local setup, sg = layoutOf(props, "Setup")
    T.eq(setup["Curve"].Style, "ComboBox", "Text with Choices becomes a ComboBox")
    T.eq(setup["Level"].Style, "Knob", "flow places a knob")
    T.eq(setup["Level"].PrettyName, "Unit Test~Level", "flow fills the pretty name")
    local title = false
    for _, g in ipairs(sg) do if g.Text == "T E S T" then title = true end end
    T.ok(title, "section draws its title")
    local names = layoutOf(props, "Names")
    T.ok(names["ZoneSelected 1"] ~= nil and names["ZoneSelected 8"] ~= nil, "grid places every element")
    T.eq(names["ZoneSelected 5"].Position[1], names["ZoneSelected 1"].Position[1], "grid wraps after 4 columns")
    T.ok(names["ZoneSelected 5"].Position[2] > names["ZoneSelected 1"].Position[2], "grid second row lower")
    T.eq(names["ZoneSelected 2"].Position[1] - names["ZoneSelected 1"].Position[1], 108, "grid pitch = cell + gap")
    T.eq(#LAYOUT_PROBLEMS, 0, "clean layout")
  end)
  withTestMode({ layout = function(L, page, props, ctx)
    if page == "Pad" then
      L.knob("Nope", { 10, 100 }, { 32, 32 })
      L.toggle("Lock", "LOCK", { 10, 200 }, { 64, 24 })
      L.toggle("Lock", "LOCK", { 10, 240 }, { 64, 24 })
    elseif page == "Setup" then
      error("boom")
    end
  end }, function()
    local props = defaults(TEST_MODE)
    layoutOf(props, "Pad")
    T.eq(#LAYOUT_PROBLEMS, 2, "unknown key and duplicate are recorded")
    T.ok(LAYOUT_PROBLEMS[1]:find("Nope", 1, true), "unknown key named")
    T.ok(LAYOUT_PROBLEMS[2]:find("twice", 1, true), "duplicate named")
    local layout = layoutOf(props, "Setup")
    T.ok(layout["Picker"] ~= nil, "framework content survives a mode layout error")
    T.ok(LAYOUT_PROBLEMS[1]:find("boom", 1, true), "mode layout error recorded")
  end)
end

function test_picker_geometry()
  local g = Framework.pickerGeometry(500, 500)
  T.eq(g.w, 955, "picker width for 500")
  T.eq(g.h, 524, "picker height for 500")
  T.eq(g.dx, 38, "pad offset x for 500")
  T.eq(g.dy, 12, "pad offset y")
  T.eq(g.xMin, 39, "x range start")
  T.eq(g.xMax, 1280 - 955 + 38, "x range end")
  local g2 = Framework.pickerGeometry(560, 560)
  T.eq(g2.w, 1070, "picker width for 560")
  T.eq(g2.h, 584, "picker height for 560")
  T.eq(g2.dx, 43, "pad offset x for 560")
  T.eq(g2.coverW, 1074, "cover width")
  T.eq(g2.coverH, 588, "cover height")
  T.eq(Framework.pickerGeometry(300, 500).side, 500, "longer side rules")
  local txt = Framework.pickerText(500, 500)
  T.ok(txt:find("955 x 524", 1, true), "text carries the size")
  T.ok(txt:find("(38, 12)", 1, true), "text carries the offset")
  T.ok(txt:find("x 39..", 1, true), "text carries the x range")
  T.ok(isAscii(txt), "text is ascii")
  local _, g3 = layoutOf(defaults(), "Setup")
  local found = false
  for _, e in ipairs(g3) do if e.Text and e.Text:find("955 x 524", 1, true) then found = true end end
  T.ok(found, "Setup page prints the picker size")
end

function test_display_page_and_colour_note()
  local _, g = layoutOf(defaults(), "Display")
  local note = false
  for _, e in ipairs(g) do if e.Text and e.Text:find("Pad colour: 23,21,28", 1, true) then note = true end end
  T.ok(note, "Nikita pad colour on the Display page")
  T.eq(Framework.padColourNote(defaults(nil, function(p) p["Theme"].Value = "Sunset" end)), "Pad colour: 18,11,8", "theme colour")
  T.eq(Framework.padColourNote(defaults(nil, function(p) p["Theme"].Value = "Custom"; p["Background Color"].Value = "#1C232D" end)),
       "Pad colour: 28,35,45", "custom colour")
  T.eq(Framework.padColourNote(defaults(nil, function(p) p["Theme"].Value = "Custom"; p["Background Color"].Value = "" end)),
       "Pad colour: 23,21,28", "blank custom falls back to Nikita")
  T.ok(Framework.padColourNote(defaults(nil, function(p) p["Background"].Value = "Transparent" end)):find("none", 1, true), "transparent note")
  local three = false
  for _, e in ipairs(g) do if e.Text and e.Text:find("three times", 1, true) then three = true end end
  T.ok(three, "three copies instruction")
end

function test_about_page()
  local _, g = layoutOf(defaults(), "About")
  local logo, brand, version, credits = false, false, false, false
  for _, e in ipairs(g) do
    if e.Type == "Image" and e.Image == NikitaAssets.Logo then logo = true end
    if e.Text == BrandName .. " " .. EN_DASH .. " " .. BrandSite then brand = true end
    if e.Text and e.Text:find(PluginInfo.Version, 1, true) then version = true end
    if e.Text and e.Text:find("native Color Picker", 1, true) then credits = true end
  end
  T.ok(logo, "logo on About")
  T.ok(brand, "brand line with the en dash")
  T.ok(version, "version on About")
  T.ok(credits, "credits on About")
end

function test_camera_view_page_and_setup()
  local props = defaults("Joystick", function(p) p["Camera Control"].Value = "Demo (simulated)" end)
  local cv = layoutOf(props, "Camera View")
  T.deq(cv["CameraView"].Size, { 480, 270 }, "camera view at 16:9")
  T.eq(cv["CameraView"].IsReadOnly, true, "camera view read only")
  local setup = layoutOf(props, "Setup")
  for _, name in ipairs({ "CameraStatus", "MaxSpeed", "ZoomSpeed", "ZoomIn", "ZoomOut" }) do
    T.ok(setup[name] ~= nil, name .. " on Setup")
  end
  T.eq(setup["CameraIP"], nil, "no IP field for Demo")
  local visca = layoutOf(defaults("Joystick", function(p) p["Camera Control"].Value = "VISCA over IP" end), "Setup")
  T.ok(visca["CameraIP"] ~= nil, "IP field for VISCA")
  T.eq(visca["CameraIP"].PrettyName, "Camera~Camera IP", "IP pretty name")
  local pad = layoutOf(props, "Pad")
  T.ok(pad["ZoomIn"] ~= nil and pad["ZoomOut"] ~= nil, "zoom buttons in the Pad side column")
end

function test_xy_mode_table()
  local xy = Modes["XY Pad"]
  T.ok(type(xy) == "table", "XY Pad registered")
  T.eq(xy.id, "xy", "id")
  T.eq(xy.pretty, "XY Pad", "pretty")
  T.eq(xy.hint, "Drag anywhere", "hint")
  T.eq(type(xy.controls), "function", "controls function")
  T.eq(type(xy.layout), "function", "layout function")
  T.eq(type(xy.create), "function", "create is the runtime half")
  T.eq(xy.padColour(THEMES["Nikita"]), "#17151C", "pad colour is the theme background")
  T.eq(#GetControls(defaults("XY Pad")), 26, "no extra controls")
  local _, g = layoutOf(defaults("XY Pad"), "Pad")
  local hint = false
  for _, e in ipairs(g) do if e.Text == "Drag anywhere" then hint = true end end
  T.ok(hint, "hint label on the Pad page")
end

function test_empty_tables_and_colour()
  local props = defaults()
  T.deq(GetPins(props), {}, "GetPins empty")
  T.deq(GetComponents(props), {}, "GetComponents empty")
  T.deq(GetWiring(props), {}, "GetWiring empty")
  local c = GetColor(props)
  T.eq(#c, 3, "GetColor is an RGB triple")
  T.deq(c, Nikita.BG, "GetColor is the brand background")
  T.eq(Framework.spaced("DoubleTap"), "Double Tap", "spaced")
  T.eq(Framework.spaced("JoyX"), "Joy X", "spaced before a trailing capital")
  T.eq(Framework.spaced("HFOV"), "HFOV", "all caps untouched")
  T.eq(Framework.spaced("ZoneSelected 3"), "Zone Selected 3", "spaced with an index")
end

function test_page_index_fallbacks()
  local props = defaults()
  props["page_index"] = nil
  local layout = GetControlLayout(props)
  T.ok(layout["Display"] ~= nil and layout["Gesture"] ~= nil, "missing page_index means the Pad page")
  props["page_index"] = { Value = 99 }
  local l2 = GetControlLayout(props)
  T.ok(l2["Status"] ~= nil, "out-of-range page index still lays out")
  local every = {}
  for _, page in ipairs(pageNames(props)) do
    local l = layoutOf(props, page)
    for key in pairs(l) do every[key] = true end
  end
  for _, c in ipairs(GetControls(props)) do
    T.ok(every[c.Name], c.Name .. " is on some page")
  end
end
