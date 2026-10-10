-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: design-time framework (properties, pages, controls, layout)
--
-- Everything Q-SYS Designer calls before the plugin runs lives here: GetColor,
-- GetPrettyName, GetProperties, RectifyProperties, GetPages, GetControls,
-- GetControlLayout, GetPins, GetComponents and GetWiring.
--
-- A mode module registers Modes["<mode name>"] with the shape
--   { id = "xy", pretty = "XY Pad", hint = "Drag anywhere",
--     controls = function(C, props) C.add{ ... } end,   -- extra controls
--     pages = { "Names" } or function(props) ... end,   -- extra pages (optional)
--     layout = function(L, page, props, ctx) ... end,   -- the mode's own controls
--     padColour = function(T) return T.bg end,
--     create = function(E) ... end }                     -- runtime (50_runtime.lua)
-- A missing mode counts as a mode with no extra controls and no extra pages, so
-- the framework builds and smoke-tests mode by mode.
--
-- Designer runs every reserved function in a fresh Lua state, so nothing here
-- relies on a global set by an earlier call: GetControlLayout rebuilds the
-- control list itself through Framework.buildControls.

Framework = Framework or {}

local BRAND_DASH = "\226\128\147"          -- the brand en dash, written as ASCII escapes
local HEADER, M, GAP, G = 48, 16, 12, 8     -- header height and the 8 px grid
local PAD_FIT_W = 760                       -- the Pad page scales a wider pad down to this
local SETUP_COL_W = 328                     -- Setup page column width
local SIDE_W = 168                          -- Pad page right column (mode buttons)
local OUT_ROWS, OUT_CELL_W, OUT_CELL_H = 16, 112, 48
local MINI = 24                             -- compact cell for arrays longer than 16
local MIN_PAGE_W = 700

local DEFAULT_MODE = "XY Pad"
local CAMERA_NONE, CAMERA_DEMO, CAMERA_QSYS, CAMERA_VISCA =
  "None", "Demo (simulated)", "Q-SYS Camera", "VISCA over IP"
local CAMERA_KINDS = { CAMERA_NONE, CAMERA_DEMO, CAMERA_QSYS, CAMERA_VISCA }
local VISCA_BRANDS = { "PTZOptics", "Sony", "AVer", "Lumens", "Marshall", "BirdDog", "Avonic",
                       "Generic Sony header", "Generic raw TCP" }
local PIN_GROUPS = { "Setup", "Live", "Outputs", "Actions", "Camera", "Zones", "Sources",
                     "Routing", "Guest" }

Framework.HEADER, Framework.M, Framework.GAP, Framework.G = HEADER, M, GAP, G
Framework.PAD_FIT_W = PAD_FIT_W
Framework.PIN_GROUPS = PIN_GROUPS
Framework.CAMERA_KINDS = CAMERA_KINDS
Framework.VISCA_BRANDS = VISCA_BRANDS

-- ---------------------------------------------------------------- helpers

local function copyList(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

local function prop(props, name, default)
  if type(props) ~= "table" then return default end
  local p = props[name]
  if type(p) == "table" and p.Value ~= nil then return p.Value end
  return default
end

local function propInt(props, name, default, lo, hi)
  local v = tonumber(prop(props, name, default)) or default
  v = math.floor(v + 0.5)
  if lo and v < lo then v = lo end
  if hi and v > hi then v = hi end
  return v
end

local function modeOf(props)
  local m = prop(props, "Mode", DEFAULT_MODE)
  if type(m) ~= "string" or m == "" then m = DEFAULT_MODE end
  return m
end

local function modeTable(mode)
  local t = Modes and Modes[mode]
  if type(t) == "table" then return t end
  return nil
end

local function isCameraMode(mode)
  return CAMERA_MODES ~= nil and CAMERA_MODES[mode] == true
end

local function cameraKind(props, mode)
  if not isCameraMode(mode) then return CAMERA_NONE end
  local v = prop(props, "Camera Control", CAMERA_NONE)
  for _, k in ipairs(CAMERA_KINDS) do
    if v == k then return k end
  end
  return CAMERA_NONE
end

local function padSize(props)
  return propInt(props, "Pad Width", 500, 120, 1600), propInt(props, "Pad Height", 500, 120, 1200)
end

-- "DoubleTap" -> "Double Tap", "JoyX" -> "Joy X", "ZoneSelected 3" -> "Zone Selected 3"
local function spaced(name)
  local s = tostring(name or "")
  s = s:gsub("(%l)(%u)", "%1 %2")
  s = s:gsub("(%d)(%u)", "%1 %2")
  return s
end
Framework.spaced = spaced

local function themeOf(props)
  local name = prop(props, "Theme", "Nikita")
  return THEMES[name] or THEMES["Nikita"], name
end

-- Colour to put under the pad on the UCI, as "r,g,b" or a note.
local function padColourNote(props)
  local background = prop(props, "Background", "Solid")
  if background == "Transparent" then
    return "Pad colour: none (Transparent: the page art shows through)"
  end
  local T, name = themeOf(props)
  local rgb = T.padRGB
  if name == "Custom" then
    local r, g, b = U.hexToRgb(prop(props, "Background Color", ""))
    if r then rgb = { r, g, b } end
  end
  return string.format("Pad colour: %d,%d,%d", rgb[1], rgb[2], rgb[3])
end
Framework.padColourNote = padColourNote

-- Picker size and placement for a pad (spec 13.3, measured on the Gesture
-- Pad design): picker width = ceil(1.91 P), height = P + 24, pad top-left =
-- picker top-left + (round(0.04 width), 12), with P the longer pad side. The
-- cover box is the picker rectangle grown by 2 px on each side.
function Framework.pickerGeometry(padW, padH)
  local P = math.max(padW, padH)
  local w = math.ceil(1.91 * P)
  local h = P + 24
  local dx = math.floor(0.04 * w + 0.5)
  local dy = 12
  local g = { w = w, h = h, dx = dx, dy = dy, side = P, coverW = w + 4, coverH = h + 4 }
  g.xMin, g.xMax = dx + 1, 1280 - w + dx
  g.yMin, g.yMax = dy, 800 - h + dy
  return g
end

function Framework.pickerText(padW, padH)
  local g = Framework.pickerGeometry(padW, padH)
  local fit
  if g.xMax >= g.xMin and g.yMax >= g.yMin then
    fit = string.format("Pad top-left fits at x %d..%d, y %d..%d on a 1280 x 800 page.", g.xMin, g.xMax, g.yMin, g.yMax)
  else
    fit = "Wider than a 1280 x 800 page: use a smaller pad or a larger page."
  end
  return string.format("Picker on the UCI: %d x %d px. Pad top-left = picker top-left + (%d, %d).\nCover box: %d x %d px, 2 px outside the picker. %s", g.w, g.h, g.dx, g.dy, g.coverW, g.coverH, fit)
end

-- ---------------------------------------------------------------- GetColor / GetPrettyName

function GetColor(props)
  return Nikita.BG
end

function GetPrettyName(props)
  local w, h = padSize(props)
  return string.format("Touch Pad: %s %dx%d", modeOf(props), w, h)
end

-- ---------------------------------------------------------------- GetProperties

function GetProperties()
  local props = {
    { Name = "Mode", Type = "enum", Choices = copyList(MODE_NAMES), Value = DEFAULT_MODE },
    { Name = "Pad Width", Type = "integer", Min = 120, Max = 1600, Value = 500 },
    { Name = "Pad Height", Type = "integer", Min = 120, Max = 1200, Value = 500 },
    { Name = "Color Picker", Type = "string", Value = "" },
    { Name = "Swap Axes", Type = "boolean", Value = false },
    { Name = "Flip X", Type = "boolean", Value = false },
    { Name = "Flip Y", Type = "boolean", Value = false },
    { Name = "Theme", Type = "enum", Choices = copyList(THEME_NAMES), Value = "Nikita" },
    { Name = "Accent Color", Type = "string", Value = "" },
    { Name = "Background Color", Type = "string", Value = "" },
    { Name = "Text Color", Type = "string", Value = "" },
    { Name = "Background", Type = "enum", Choices = { "Solid", "Transparent", "Panel" }, Value = "Solid" },
    { Name = "Corner Radius", Type = "integer", Min = 0, Max = 40, Value = 18 },
    { Name = "Font", Type = "string", Value = "Roboto" },
    { Name = "Show Hints", Type = "boolean", Value = true },
    { Name = "Max Frame Rate", Type = "enum", Choices = { "10", "15", "20", "30" }, Value = "20" },
    { Name = "Icon Channel", Type = "enum", Choices = { "Legend", "Style" }, Value = "Legend" },
    { Name = "Camera Control", Type = "enum", Choices = copyList(CAMERA_KINDS), Value = CAMERA_NONE },
    { Name = "Camera Name", Type = "string", Value = "" },
    { Name = "VISCA Brand", Type = "enum", Choices = copyList(VISCA_BRANDS), Value = "PTZOptics" },
    { Name = "Zones", Type = "integer", Min = 1, Max = 32, Value = 8 },
    { Name = "Sources", Type = "integer", Min = 1, Max = 64, Value = 4 },
    { Name = "Destinations", Type = "integer", Min = 1, Max = 64, Value = 2 },
    { Name = "Speakers", Type = "enum", Choices = { "Stereo", "LCR", "Quad", "5.1", "7.1" }, Value = "Stereo" },
    { Name = "Orientation", Type = "enum", Choices = { "Vertical", "Horizontal" }, Value = "Vertical" },
    { Name = "Sign-In Webhook", Type = "enum", Choices = { "Off", "JSON", "Teams Card" }, Value = "Off" },
    { Name = "Debug Print", Type = "enum", Choices = { "None", "Gestures", "All" }, Value = "None" },
  }
  -- No "Show Debug" property: Designer reserves that name for its own
  -- Debug Output window (API reference 3.3); "Debug Print" covers the use.
  return props
end

-- ---------------------------------------------------------------- RectifyProperties

function RectifyProperties(props)
  pcall(function()
    local mode = modeOf(props)
    local cam = isCameraMode(mode)
    local kind = cameraKind(props, mode)
    local theme = prop(props, "Theme", "Nikita")
    local function hide(name, hidden)
      local p = props[name]
      if type(p) == "table" then p.IsHidden = hidden and true or false end
    end
    hide("Accent Color", theme ~= "Custom")
    hide("Background Color", theme ~= "Custom")
    hide("Text Color", theme ~= "Custom")
    hide("Camera Control", not cam)
    hide("Camera Name", not (cam and kind == CAMERA_QSYS))
    hide("VISCA Brand", not (cam and kind == CAMERA_VISCA))
    hide("Zones", mode ~= "Zone Select")
    hide("Sources", not (mode == "Drag & Drop" or mode == "Matrix"))
    hide("Destinations", not (mode == "Drag & Drop" or mode == "Matrix"))
    hide("Speakers", mode ~= "Panner")
    hide("Orientation", mode ~= "Fader")
    hide("Sign-In Webhook", mode ~= "Sign-In")
  end)
  return props
end

-- ---------------------------------------------------------------- GetPages

-- Extra pages by the section 4 rules; a mode may override with its own `pages`.
local function extraPages(mode, props)
  local mt = modeTable(mode)
  if mt and mt.pages ~= nil then
    local pages = mt.pages
    if type(pages) == "function" then
      local ok, res = pcall(pages, props)
      pages = ok and res or nil
    end
    if type(pages) == "table" then
      local out = {}
      for i = 1, #pages do
        if type(pages[i]) == "string" then out[#out + 1] = pages[i] end
      end
      return out
    end
    return {}
  end
  if mode == "Zone Select" then return { "Names" } end
  if mode == "Drag & Drop" or mode == "Matrix" then
    local srcs = propInt(props, "Sources", 4, 1, 64)
    local dsts = propInt(props, "Destinations", 2, 1, 64)
    if srcs > 16 or dsts > 16 then return { "Sources", "Destinations" } end
    return { "Names" }
  end
  return {}
end
Framework.extraPages = extraPages

function Framework.pageNames(props)
  local mode = modeOf(props)
  local names = { "Pad", "Setup" }
  for _, p in ipairs(extraPages(mode, props)) do names[#names + 1] = p end
  if cameraKind(props, mode) == CAMERA_DEMO then names[#names + 1] = "Camera View" end
  names[#names + 1] = "Outputs"
  names[#names + 1] = "Display"
  names[#names + 1] = "About"
  return names
end

function GetPages(props)
  local pages = {}
  for _, name in ipairs(Framework.pageNames(props)) do
    pages[#pages + 1] = { name = name }
  end
  return pages
end

-- ---------------------------------------------------------------- controls

-- Keys Designer reads from a control definition; anything else (Group, Pretty,
-- Choices, Legend) is kept in the metadata for the layout.
local CONTROL_KEYS = { "Name", "Count", "ControlType", "PinStyle", "UserPin", "ButtonType",
                       "ControlUnit", "IndicatorType", "DefaultValue", "Icon", "IconType",
                       "Min", "Max", "Description" }

local function knob(name, unit, lo, hi, default, pin, group)
  return { Name = name, ControlType = "Knob", ControlUnit = unit, Min = lo, Max = hi,
           DefaultValue = default, PinStyle = pin, Group = group }
end
local function button(name, kind, pin, group)
  return { Name = name, ControlType = "Button", ButtonType = kind, PinStyle = pin, Group = group }
end
local function indicator(name, kind, pin, group)
  return { Name = name, ControlType = "Indicator", IndicatorType = kind, PinStyle = pin, Group = group }
end
local function text(name, pin, group)
  return { Name = name, ControlType = "Text", PinStyle = pin, Group = group }
end

-- The common controls of spec section 3 (every mode).
local function commonControls()
  return {
    indicator("Status", "Status", "Output", "Setup"),
    { Name = "Display", ControlType = "Button", ButtonType = "Momentary", Group = "Setup", Display = true },
    text("Picker", "Input", "Setup"),
    button("Refresh", "Trigger", "Input", "Setup"),
    button("PanelTouch", "Toggle", "Input", "Setup"),
    button("Calibrate", "Toggle", "Input", "Setup"),
    text("Calibration", nil, "Setup"),
    indicator("PickerLayout", "Text", nil, "Setup"),
    knob("ReleaseTime", "Seconds", 0.1, 1.0, 0.25, "Input", "Setup"),
    knob("LongPressTime", "Seconds", 0.3, 3, 0.6, "Input", "Setup"),
    button("Lock", "Toggle", "Input", "Setup"),
    indicator("Touching", "Led", "Output", "Live"),
    knob("X", "Float", 0, 1, 0, "Output", "Live"),
    knob("Y", "Float", 0, 1, 0, "Output", "Live"),
    button("Tap", "Trigger", "Both", "Actions"),
    button("DoubleTap", "Trigger", "Both", "Actions"),
    button("LongPress", "Trigger", "Both", "Actions"),
    button("Press", "Trigger", "Output", "Actions"),
    button("Release", "Trigger", "Output", "Actions"),
    button("SwipeLeft", "Trigger", "Both", "Actions"),
    button("SwipeRight", "Trigger", "Both", "Actions"),
    button("SwipeUp", "Trigger", "Both", "Actions"),
    button("SwipeDown", "Trigger", "Both", "Actions"),
    indicator("Gesture", "Text", "Output", "Live"),
    knob("DragDistance", "Float", 0, 2, 0, "Output", "Live"),
    knob("DragAngle", "Float", -180, 180, 0, "Output", "Live"),
  }
end

-- Camera controls shared by the camera modes when Camera Control is not None.
local function cameraControls(kind)
  local list = {
    button("ZoomIn", "Momentary", "Input", "Camera"),
    button("ZoomOut", "Momentary", "Input", "Camera"),
    knob("MaxSpeed", "Percent", 1, 100, 50, "Input", "Camera"),
    knob("ZoomSpeed", "Percent", 1, 100, 50, "Input", "Camera"),
    indicator("CameraStatus", "Text", "Output", "Camera"),
  }
  if kind == CAMERA_VISCA then list[#list + 1] = text("CameraIP", "Input", "Camera") end
  if kind == CAMERA_DEMO then
    list[#list + 1] = { Name = "CameraView", ControlType = "Button", ButtonType = "Momentary", Group = "Camera", Display = true }
  end
  return list
end

-- Builds the control list for props. Returns (list, meta, order) where
-- meta[name] = { def, count, group, pretty, pinned, choices, legend, display }.
function Framework.buildControls(props)
  local mode = modeOf(props)
  local mt = modeTable(mode)
  local modePretty = (mt and type(mt.pretty) == "string") and mt.pretty or mode
  local kind = cameraKind(props, mode)
  local list, meta, order = {}, {}, {}

  local function add(def)
    if type(def) ~= "table" or type(def.Name) ~= "string" or def.Name == "" then
      error("GetControls: a control definition needs a Name", 2)
    end
    if meta[def.Name] then
      error("GetControls: control '" .. def.Name .. "' is defined twice", 2)
    end
    local out = {}
    for _, k in ipairs(CONTROL_KEYS) do out[k] = def[k] end
    out.Count = math.max(1, math.floor(tonumber(def.Count) or 1))
    if out.PinStyle ~= nil and out.UserPin == nil then out.UserPin = true end
    if out.PinStyle == nil then out.UserPin = nil end
    local group = def.Group or modePretty
    local pretty = def.Pretty or (group .. "~" .. spaced(def.Name))
    list[#list + 1] = out
    order[#order + 1] = def.Name
    meta[def.Name] = { def = out, count = out.Count, group = group, pretty = pretty,
                       pinned = out.PinStyle ~= nil, choices = def.Choices, legend = def.Legend,
                       display = def.Display == true }
    return out
  end

  for _, def in ipairs(commonControls()) do add(def) end
  if kind ~= CAMERA_NONE then
    for _, def in ipairs(cameraControls(kind)) do add(def) end
  end
  if mt and type(mt.controls) == "function" then
    local C = { add = add, props = props, mode = mode, pretty = modePretty, camera = kind,
                has = function(name) return meta[name] ~= nil end }
    local ok, err = pcall(mt.controls, C, props)
    if not ok then error("GetControls: mode '" .. mode .. "': " .. tostring(err), 0) end
  end
  return list, meta, order
end

function GetControls(props)
  local list = Framework.buildControls(props)
  return list
end

-- ---------------------------------------------------------------- layout builder L

local function layoutKey(name, i, count)
  if count == 1 then return name end
  return name .. " " .. i
end

local WHITE = { 255, 255, 255 }

local function buttonColor(kind)
  if kind == "Trigger" then return Nikita.Orange end
  if kind == "Toggle" then return Nikita.Purple end
  return Nikita.Magenta
end

local function newLayout(page, props, meta, order, prettyName, baseW)
  local L = { page = page, props = props, meta = meta, order = order, layout = {}, graphics = {},
              W = math.max(baseW or MIN_PAGE_W, MIN_PAGE_W), bottom = 0, right = 0,
              placed = {}, problems = {}, M = M, GAP = GAP, G = G, HEADER = HEADER }

  -- Resolves a layout key ("Name" or "Name i") to its control metadata.
  function L.metaOf(key)
    local m = meta[key]
    if m and m.count == 1 then return m, 1 end
    local base, idx = key:match("^(.-) (%d+)$")
    if base and meta[base] then
      idx = tonumber(idx)
      if idx >= 1 and idx <= meta[base].count and meta[base].count > 1 then return meta[base], idx end
    end
    if m then return m, 1 end
    return nil
  end

  function L.pretty(key)
    local m, idx = L.metaOf(key)
    if not m then return nil end
    if m.count == 1 then return m.pretty end
    return m.pretty .. " " .. idx
  end

  function L.key(name, i, count)
    local m = meta[name]
    return layoutKey(name, i or 1, count or (m and m.count) or 1)
  end

  function L.keys(name)
    local m = meta[name]
    local out = {}
    if not m then return out end
    for i = 1, m.count do out[i] = layoutKey(name, i, m.count) end
    return out
  end

  function L.has(key) return L.placed[key] == true end

  function L.track(pos, size)
    if type(pos) ~= "table" or type(size) ~= "table" then return end
    local x, y, w, h = tonumber(pos[1]) or 0, tonumber(pos[2]) or 0, tonumber(size[1]) or 0, tonumber(size[2]) or 0
    if x + w > L.right then L.right = x + w end
    if y + h > L.bottom then L.bottom = y + h end
  end

  function L.put(key, entry)
    local m = L.metaOf(key)
    if not m then
      L.problems[#L.problems + 1] = page .. ": layout key '" .. tostring(key) .. "' is not a control"
    end
    if L.placed[key] then
      L.problems[#L.problems + 1] = page .. ": control '" .. tostring(key) .. "' placed twice"
    end
    if m and m.pinned and entry.PrettyName == nil then entry.PrettyName = L.pretty(key) end
    L.placed[key] = true
    L.layout[key] = entry
    L.track(entry.Position, entry.Size)
    return entry
  end

  function L.graphic(entry)
    L.graphics[#L.graphics + 1] = entry
    L.track(entry.Position, entry.Size)
    return entry
  end

  -- graphics
  function L.label(txt, pos, size, opts)
    opts = opts or {}
    return L.graphic({ Type = "Label", Text = tostring(txt or ""), FontSize = opts.size or 9,
                       FontStyle = opts.bold and "Bold" or nil, HTextAlign = opts.align or "Left",
                       VTextAlign = opts.valign, Color = opts.color or Nikita.Muted,
                       Position = pos, Size = size })
  end
  function L.caption(txt, pos, size, align)
    return L.graphic({ Type = "Label", Text = tostring(txt or ""), FontSize = 8, FontStyle = "Bold",
                       HTextAlign = align or "Center", Color = Nikita.Muted, Position = pos, Size = size })
  end
  function L.title(txt, pos, size)
    return L.graphic({ Type = "Label", Text = tostring(txt or ""), FontSize = 10, FontStyle = "Bold",
                       HTextAlign = "Left", Color = Nikita.Muted, Position = pos, Size = size })
  end
  function L.panel(pos, size)
    return L.graphic({ Type = "GroupBox", Fill = Nikita.Panel, StrokeColor = Nikita.Stroke, StrokeWidth = 1,
                       CornerRadius = 4, Position = pos, Size = size })
  end
  function L.rule(pos, size, color)
    return L.graphic({ Type = "GroupBox", Fill = color or Nikita.Purple, StrokeWidth = 0, CornerRadius = 0,
                       Position = pos, Size = size })
  end
  function L.image(data, pos, size)
    return L.graphic({ Type = "Image", Image = data, Position = pos, Size = size })
  end

  -- controls
  function L.button(key, legend, pos, size, opts)
    opts = opts or {}
    local m = L.metaOf(key)
    local kind = opts.style or (m and m.def.ButtonType) or "Momentary"
    return L.put(key, { Style = "Button", ButtonStyle = kind, Legend = tostring(legend or ""),
                        Color = opts.color or buttonColor(kind), UnlinkOffColor = true,
                        OffColor = opts.offColor or Nikita.BG, FontSize = opts.fontSize or 10,
                        CornerRadius = opts.radius or 4, Position = pos, Size = size,
                        PrettyName = opts.pretty })
  end
  function L.toggle(key, legend, pos, size, opts)
    opts = opts or {}; opts.style = "Toggle"
    return L.button(key, legend, pos, size, opts)
  end
  function L.trigger(key, legend, pos, size, opts)
    opts = opts or {}; opts.style = "Trigger"
    return L.button(key, legend, pos, size, opts)
  end
  function L.momentary(key, legend, pos, size, opts)
    opts = opts or {}; opts.style = "Momentary"
    return L.button(key, legend, pos, size, opts)
  end
  function L.knob(key, pos, size, opts)
    opts = opts or {}
    return L.put(key, { Style = "Knob", Color = opts.color or Nikita.Magenta, Position = pos, Size = size,
                        PrettyName = opts.pretty })
  end
  function L.fader(key, pos, size, opts)
    opts = opts or {}
    return L.put(key, { Style = "Fader", Color = opts.color or Nikita.Purple, Position = pos, Size = size,
                        PrettyName = opts.pretty })
  end
  function L.text(key, pos, size, opts)
    opts = opts or {}
    return L.put(key, { Style = "Text", HTextAlign = opts.align or "Left", FontSize = opts.fontSize or 10,
                        IsReadOnly = opts.readOnly or nil, TextBoxStyle = opts.boxStyle,
                        Position = pos, Size = size, PrettyName = opts.pretty })
  end
  function L.readout(key, pos, size, opts)
    opts = opts or {}; opts.readOnly = true
    return L.text(key, pos, size, opts)
  end
  function L.combo(key, pos, size, opts)
    opts = opts or {}
    return L.put(key, { Style = "ComboBox", FontSize = opts.fontSize or 9, Position = pos, Size = size,
                        PrettyName = opts.pretty })
  end
  function L.led(key, pos, size, opts)
    opts = opts or {}
    return L.put(key, { Style = "Led", Color = opts.color or Nikita.OK, UnlinkOffColor = true,
                        OffColor = Nikita.Stroke, Position = pos, Size = size, PrettyName = opts.pretty })
  end
  function L.meter(key, pos, size, opts)
    opts = opts or {}
    return L.put(key, { Style = "Meter", MeterStyle = opts.meterStyle or "Level", Position = pos, Size = size,
                        PrettyName = opts.pretty })
  end
  -- The pad drawing: a flat white read-only button whose icon the runtime sets.
  function L.display(key, pos, size)
    return L.put(key, { Style = "Button", ButtonStyle = "Momentary", ButtonVisualStyle = "Flat",
                        IsReadOnly = true, Legend = "", Color = WHITE, UnlinkOffColor = true,
                        OffColor = WHITE, CornerRadius = 0, Position = pos, Size = size })
  end

  -- Picks the style from the control definition.
  function L.place(key, pos, size, opts)
    opts = opts or {}
    local m = L.metaOf(key)
    if not m then return L.put(key, { Style = "Text", Position = pos, Size = size }) end
    local d = m.def
    if m.display then return L.display(key, pos, size) end
    if d.ControlType == "Button" then
      return L.button(key, opts.legend or m.legend or spaced(key):upper(), pos, size, opts)
    elseif d.ControlType == "Knob" then
      return L.knob(key, pos, size, opts)
    elseif d.ControlType == "Text" then
      if m.choices then return L.combo(key, pos, size, opts) end
      return L.text(key, pos, size, opts)
    elseif d.IndicatorType == "Led" or d.IndicatorType == "Status" then
      return L.led(key, pos, size, opts)
    elseif d.IndicatorType == "Meter" then
      return L.meter(key, pos, size, opts)
    end
    return L.readout(key, pos, size, opts)
  end

  -- A captioned cell: caption on top, the control sized to its kind below.
  function L.cell(key, x, y, w, h, opts)
    opts = opts or {}
    local m = L.metaOf(key)
    local d = m and m.def or {}
    local cy, ch = y + 12, h - 12
    L.caption(opts.caption or spaced(key):upper(), { x, y }, { w, 10 })
    if d.ControlType == "Knob" then
      local s = math.min(ch, 32)
      L.knob(key, { x + math.floor((w - s) / 2), cy }, { s, s }, opts)
    elseif d.ControlType == "Indicator" and (d.IndicatorType == "Led" or d.IndicatorType == "Status") then
      L.led(key, { x + math.floor((w - 16) / 2), cy + math.floor((ch - 16) / 2) }, { 16, 16 }, opts)
    elseif d.ControlType == "Button" and not (m and m.display) then
      L.place(key, { x, cy }, { w, math.min(ch, 28) }, opts)
    else
      L.place(key, { x, cy }, { w, math.min(ch, 24) }, opts)
    end
  end

  -- Fixed grid of captioned cells; returns the y below the last row.
  function L.grid(names, x, y, cols, cellW, cellH)
    cols = math.max(1, math.floor(cols or 1))
    cellW, cellH = cellW or 104, cellH or 48
    local n = #names
    for i = 1, n do
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      L.cell(names[i], x + col * (cellW + G), y + row * (cellH + G), cellW, cellH)
    end
    if n == 0 then return y end
    return y + math.ceil(n / cols) * (cellH + G) - G
  end

  -- Cells packed left to right into a width; returns the y below the last row.
  function L.flow(names, x, y, w, opts)
    opts = opts or {}
    local cellW, cellH = opts.cellW or 104, opts.cellH or 48
    local cols = math.max(1, math.floor((w + G) / (cellW + G)))
    return L.grid(names, x, y, cols, cellW, cellH)
  end

  -- A titled panel in the mode area of a page; returns the inner origin and
  -- width and moves ctx.y below it.
  function L.section(ctx, title, innerH)
    local h = innerH + 30 + 12
    L.panel({ ctx.x, ctx.y }, { ctx.w, h })
    L.title(title, { ctx.x + 12, ctx.y + 10 }, { ctx.w - 24, 12 })
    local ix, iy, iw = ctx.x + 12, ctx.y + 30, ctx.w - 24
    ctx.y = ctx.y + h + GAP
    return ix, iy, iw
  end

  -- Pad page right column: stacked mode buttons.
  function L.sideButton(ctx, key, legend, opts)
    local e = L.place(key, { ctx.side, ctx.sideY }, { ctx.sideW, 32 }, opts and opts or { legend = legend })
    if legend and e.Legend ~= nil then e.Legend = legend end
    ctx.sideY = ctx.sideY + 40
    return e
  end
  function L.sideCaption(ctx, txt)
    L.caption(txt, { ctx.side, ctx.sideY }, { ctx.sideW, 10 }, "Left")
    ctx.sideY = ctx.sideY + 14
  end

  -- Pad page: the pad drawing, the Gesture readout and the hint line.
  function L.padDisplay(ctx)
    if L.has("Display") then return end
    L.caption("DISPLAY (drawn by the plugin at run time)", { ctx.x, ctx.y - 12 }, { ctx.dw, 10 }, "Left")
    L.display("Display", { ctx.x, ctx.y }, { ctx.dw, ctx.dh })
  end
  function L.gesture(ctx)
    if L.has("Gesture") then return end
    L.readout("Gesture", { ctx.x, ctx.y + ctx.dh + G }, { ctx.dw, 24 }, { align = "Center", fontSize = 11 })
  end
  function L.hint(ctx, txt)
    if ctx.hintDone then return end
    ctx.hintDone = true
    L.label(txt or "", { ctx.x, ctx.y + ctx.dh + G + 24 + 4 }, { ctx.dw, 14 }, { align = "Center" })
  end

  return L
end
Framework.newLayout = newLayout

-- The Mic Mixer header: icon, brand name and site on the left, the plugin
-- name on the right, the Status LED and the three-colour brand rule. Sizes
-- are patched by finishPage once the content width and height are known.
local function header(L, prettyName)
  L.bg = L.graphic({ Type = "GroupBox", Fill = Nikita.BG, StrokeWidth = 0, Position = { 0, 0 }, Size = { L.W, HEADER } })
  L.hdrPanel = L.graphic({ Type = "GroupBox", Fill = Nikita.Panel, StrokeWidth = 0, CornerRadius = 0, Position = { 0, 0 }, Size = { L.W, HEADER } })
  L.image(NikitaAssets.Icon, { M, 11 }, { 26, 26 })
  L.graphic({ Type = "Label", Text = BrandName, FontSize = 13, FontStyle = "Bold", HTextAlign = "Left", Color = Nikita.Text, Position = { M + 32, 7 }, Size = { 180, 18 } })
  L.graphic({ Type = "Label", Text = BrandSite, FontSize = 9, HTextAlign = "Left", Color = Nikita.Muted, Position = { M + 32, 26 }, Size = { 180, 14 } })
  L.hdrName = L.graphic({ Type = "Label", Text = prettyName, FontSize = 13, FontStyle = "Bold", HTextAlign = "Right", Color = Nikita.Text, Position = { L.W - 260 - M - 24, 14 }, Size = { 260, 20 } })
  L.status = L.put("Status", { Style = "Led", Position = { L.W - M - 16, 16 }, Size = { 16, 16 } })
  L.rules = {
    L.rule({ 0, HEADER - 2 }, { 1, 2 }, Nikita.Purple),
    L.rule({ 0, HEADER - 2 }, { 1, 2 }, Nikita.Pink),
    L.rule({ 0, HEADER - 2 }, { 1, 2 }, Nikita.Orange),
  }
end

local function finishPage(L)
  local W = math.max(L.W, L.right + M)
  local H = math.max(L.bottom + M, HEADER + M)
  L.W, L.H = W, H
  L.bg.Size = { W, H }
  L.hdrPanel.Size = { W, HEADER }
  L.hdrName.Position = { W - 260 - M - 24, 14 }
  L.status.Position = { W - M - 16, 16 }
  local seg = math.floor(W / 3)
  L.rules[1].Position, L.rules[1].Size = { 0, HEADER - 2 }, { seg, 2 }
  L.rules[2].Position, L.rules[2].Size = { seg, HEADER - 2 }, { seg, 2 }
  L.rules[3].Position, L.rules[3].Size = { 2 * seg, HEADER - 2 }, { W - 2 * seg, 2 }
end

-- ---------------------------------------------------------------- pages

local function padContext(L, props, page)
  local W, H = padSize(props)
  local scale = math.min(1, PAD_FIT_W / W)
  local dw, dh = math.floor(W * scale + 0.5), math.floor(H * scale + 0.5)
  local ctx = { page = page, W = W, H = H, x = M, y = HEADER + GAP + 16, w = dw, dw = dw, dh = dh,
                scale = scale, sideW = SIDE_W, M = M, GAP = GAP, G = G }
  ctx.side = ctx.x + dw + GAP
  ctx.sideY = ctx.y
  return ctx
end

local function pagePad(L, props, mt, ctx, kind)
  local hint = (mt and type(mt.hint) == "string") and mt.hint or ""
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, "Pad", props, ctx)
    if not ok then L.problems[#L.problems + 1] = "Pad: mode layout error: " .. tostring(err) end
  end
  L.padDisplay(ctx)
  L.gesture(ctx)
  L.hint(ctx, hint)
  if kind ~= CAMERA_NONE then
    if not L.has("ZoomIn") then L.sideCaption(ctx, "CAMERA") end
    if not L.has("ZoomIn") then L.sideButton(ctx, "ZoomIn", "ZOOM +") end
    if not L.has("ZoomOut") then L.sideButton(ctx, "ZoomOut", "ZOOM -") end
  end
  if not L.has("Lock") then
    L.sideCaption(ctx, "PAD")
    L.sideButton(ctx, "Lock", "LOCK")
  end
  if ctx.scale < 1 then
    L.label(string.format("Shown at %d %%: the UCI copy is %d x %d px (see the Display page).",
                          math.floor(ctx.scale * 100 + 0.5), ctx.W, ctx.H),
            { ctx.x, ctx.y + ctx.dh + G + 24 + 4 + 16 }, { ctx.dw, 14 }, { align = "Center" })
  end
end

local function pageSetup(L, props, mt, kind)
  local W, H = padSize(props)
  local y0 = HEADER + GAP
  local colAX, colBX = M, M + SETUP_COL_W + GAP
  local colW = SETUP_COL_W

  -- Column A, panel 1: picker binding, placement, panel touch, calibration.
  local y = y0
  L.panel({ colAX, y }, { colW, 288 })
  L.title("P I C K E R", { colAX + 12, y + 10 }, { colW - 24, 12 })
  L.caption("COLOR PICKER CODE NAME (BLANK = PROPERTY)", { colAX + 12, y + 30 }, { 212, 10 }, "Left")
  L.text("Picker", { colAX + 12, y + 42 }, { 212, 22 })
  L.trigger("Refresh", "RESCAN", { colAX + 232, y + 42 }, { 84, 22 })
  L.caption("SIZE FOR THIS PAD", { colAX + 12, y + 72 }, { colW - 24, 10 }, "Left")
  L.label(Framework.pickerText(W, H), { colAX + 12, y + 84 }, { colW - 24, 40 })
  L.caption("LIVE PLACEMENT", { colAX + 12, y + 128 }, { colW - 24, 10 }, "Left")
  L.readout("PickerLayout", { colAX + 12, y + 140 }, { colW - 24, 40 }, { fontSize = 9 })
  L.toggle("PanelTouch", "PANEL TOUCH", { colAX + 12, y + 190 }, { 100, 24 })
  L.toggle("Calibrate", "CALIBRATE", { colAX + 120, y + 190 }, { 100, 24 })
  L.label("Wire the TSC Touch Activity to Panel Touch.", { colAX + 228, y + 195 }, { colW - 240, 14 })
  L.caption("CALIBRATION (P x0 y0 w h / D x0 y0 w h)", { colAX + 12, y + 222 }, { colW - 24, 10 }, "Left")
  L.text("Calibration", { colAX + 12, y + 234 }, { colW - 24, 40 }, { fontSize = 9 })
  y = y + 288 + GAP

  -- Column A, panel 2: timing and lock.
  L.panel({ colAX, y }, { colW, 96 })
  L.title("T I M I N G  A N D  L O C K", { colAX + 12, y + 10 }, { colW - 24, 12 })
  L.caption("RELEASE", { colAX + 8, y + 32 }, { 56, 10 })
  L.knob("ReleaseTime", { colAX + 20, y + 44 }, { 32, 32 }, { color = Nikita.Purple })
  L.caption("LONG PRESS", { colAX + 72, y + 32 }, { 64, 10 })
  L.knob("LongPressTime", { colAX + 88, y + 44 }, { 32, 32 }, { color = Nikita.Magenta })
  L.toggle("Lock", "LOCK", { colAX + 148, y + 44 }, { 64, 32 })
  L.label("Release: silence counted as a lift\nwhen Panel Touch is not wired.", { colAX + 220, y + 40 }, { colW - 232, 40 })
  local colABottom = y + 96

  -- Column B: camera (when set), debug hints, then the mode's own setup.
  y = y0
  if kind ~= CAMERA_NONE then
    local camH = (kind == CAMERA_VISCA) and 170 or 136
    L.panel({ colBX, y }, { colW, camH })
    L.title("C A M E R A", { colBX + 12, y + 10 }, { colW - 24, 12 })
    local what
    if kind == CAMERA_VISCA then
      what = "VISCA over IP, brand " .. tostring(prop(props, "VISCA Brand", "PTZOptics"))
    elseif kind == CAMERA_QSYS then
      local name = tostring(prop(props, "Camera Name", ""))
      what = "Q-SYS Camera: " .. (name ~= "" and name or "(set the Camera Name property)")
    else
      what = "Demo camera (simulated; see the Camera View page)"
    end
    L.label(what, { colBX + 12, y + 28 }, { colW - 24, 14 }, { color = Nikita.Text })
    local cy = y + 48
    if kind == CAMERA_VISCA then
      L.caption("CAMERA IP ADDRESS", { colBX + 12, cy }, { 160, 10 }, "Left")
      L.text("CameraIP", { colBX + 12, cy + 12 }, { 160, 22 })
      cy = cy + 34
    end
    L.caption("STATUS", { colBX + 12, cy }, { colW - 24, 10 }, "Left")
    L.readout("CameraStatus", { colBX + 12, cy + 12 }, { colW - 24, 22 }, { fontSize = 9 })
    cy = cy + 40
    L.caption("MAX SPEED", { colBX + 8, cy }, { 64, 10 })
    L.knob("MaxSpeed", { colBX + 24, cy + 12 }, { 32, 32 }, { color = Nikita.Purple })
    L.caption("ZOOM SPEED", { colBX + 80, cy }, { 64, 10 })
    L.knob("ZoomSpeed", { colBX + 96, cy + 12 }, { 32, 32 }, { color = Nikita.Magenta })
    L.momentary("ZoomIn", "ZOOM +", { colBX + 156, cy + 12 }, { 72, 32 })
    L.momentary("ZoomOut", "ZOOM -", { colBX + 236, cy + 12 }, { 72, 32 })
    y = y + camH + GAP
  end

  L.panel({ colBX, y }, { colW, 64 })
  L.title("D E B U G", { colBX + 12, y + 10 }, { colW - 24, 12 })
  L.label("Debug Print property: Gestures prints every touch and gesture,\nAll also prints every picker report. Status shows errors.", { colBX + 12, y + 28 }, { colW - 24, 28 })
  y = y + 64 + GAP

  local ctx = { page = "Setup", W = W, H = H, x = colBX, y = y, w = colW, M = M, GAP = GAP, G = G,
                colA = colAX, colABottom = colABottom }
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, "Setup", props, ctx)
    if not ok then L.problems[#L.problems + 1] = "Setup: mode layout error: " .. tostring(err) end
  end
end

local function isOutput(m)
  local pin = m.def.PinStyle
  return (pin == "Output" or pin == "Both") and m.def.Name ~= "Status"
end

local function pageOutputs(L, props, mt)
  local y0 = HEADER + GAP + 20
  L.title("O U T P U T S", { M, HEADER + GAP }, { 400, 12 })
  local n = 0
  local big = {}
  for _, name in ipairs(L.order) do
    local m = L.meta[name]
    if isOutput(m) then
      if m.count <= OUT_ROWS then
        for i = 1, m.count do
          local col, row = math.floor(n / OUT_ROWS), n % OUT_ROWS
          L.cell(layoutKey(name, i, m.count), M + col * (OUT_CELL_W + G), y0 + row * (OUT_CELL_H + G), OUT_CELL_W, OUT_CELL_H)
          n = n + 1
        end
      else
        big[#big + 1] = m
      end
    end
  end
  local y = y0
  if n > 0 then y = y0 + math.min(n, OUT_ROWS) * (OUT_CELL_H + G) + GAP end
  -- Arrays longer than 16: compact blocks of mini cells, 32 per row.
  for _, m in ipairs(big) do
    local cols = math.min(m.count, 32)
    L.caption(string.format("%s 1..%d (%d per row)", spaced(m.def.Name):upper(), m.count, cols), { M, y }, { 400, 10 }, "Left")
    y = y + 12
    for i = 1, m.count do
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      local key = layoutKey(m.def.Name, i, m.count)
      local x, cy = M + col * (MINI + 2), y + row * (MINI + 2)
      if m.def.ControlType == "Button" then
        L.button(key, tostring(i), { x, cy }, { MINI, MINI }, { fontSize = 7, radius = 2 })
      elseif m.def.ControlType == "Knob" then
        L.knob(key, { x, cy }, { MINI, MINI })
      elseif m.def.ControlType == "Indicator" and (m.def.IndicatorType == "Led" or m.def.IndicatorType == "Status") then
        L.led(key, { x + 4, cy + 4 }, { 16, 16 })
      else
        L.place(key, { x, cy }, { MINI, MINI }, { fontSize = 7 })
      end
    end
    y = y + math.ceil(m.count / cols) * (MINI + 2) + GAP
  end
  local W, H = padSize(props)
  local ctx = { page = "Outputs", W = W, H = H, x = M, y = y, w = PAD_FIT_W, M = M, GAP = GAP, G = G }
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, "Outputs", props, ctx)
    if not ok then L.problems[#L.problems + 1] = "Outputs: mode layout error: " .. tostring(err) end
  end
end

local function pageDisplay(L, props, mt)
  local W, H = padSize(props)
  local y = HEADER + GAP
  L.title("D I S P L A Y", { M, y }, { 400, 12 })
  L.label(padColourNote(props) .. ". Put a block of that colour under the button, or set Background = Transparent.", { M, y + 16 }, { 760, 14 }, { color = Nikita.Text })
  L.label(string.format("Drag this button onto the UCI three times, stacked exactly over the picker, each copy %d x %d px.", W, H), { M, y + 32 }, { 760, 14 })
  L.display("Display", { M, y + 52 }, { W, H })
  local ctx = { page = "Display", W = W, H = H, x = M, y = y + 52 + H + GAP, w = W, M = M, GAP = GAP, G = G }
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, "Display", props, ctx)
    if not ok then L.problems[#L.problems + 1] = "Display: mode layout error: " .. tostring(err) end
  end
end

local function pageAbout(L, props, mt)
  local y = HEADER + GAP + 8
  L.image(NikitaAssets.Logo, { M, y }, { 280, 101 })
  L.label(BrandName .. " " .. BRAND_DASH .. " " .. BrandSite, { M, y + 112 }, { 400, 18 }, { size = 13, bold = true, color = Nikita.Text })
  L.label("Touch Pad for Q-SYS, version " .. tostring(PluginInfo.Version), { M, y + 132 }, { 400, 14 }, { color = Nikita.Text })
  L.label("Touch input through a native Color Picker; drawing as a script-set icon.", { M, y + 150 }, { 480, 14 })
  L.label("Mode: " .. modeOf(props) .. ". Sixteen modes, every result on a pin. Open source.", { M, y + 166 }, { 480, 14 })
  local W, H = padSize(props)
  local ctx = { page = "About", W = W, H = H, x = M, y = y + 190, w = 480, M = M, GAP = GAP, G = G }
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, "About", props, ctx)
    if not ok then L.problems[#L.problems + 1] = "About: mode layout error: " .. tostring(err) end
  end
end

local function pageCameraView(L, props, mt)
  local y = HEADER + GAP
  L.title("C A M E R A  V I E W", { M, y }, { 400, 12 })
  L.label("What the demo camera sees. Drag this button onto the UCI next to the pad (480 x 270 px).", { M, y + 16 }, { 760, 14 })
  L.display("CameraView", { M, y + 36 }, { 480, 270 })
  local W, H = padSize(props)
  local ctx = { page = "Camera View", W = W, H = H, x = M, y = y + 36 + 270 + GAP, w = 480, M = M, GAP = GAP, G = G }
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, "Camera View", props, ctx)
    if not ok then L.problems[#L.problems + 1] = "Camera View: mode layout error: " .. tostring(err) end
  end
end

-- Pages the mode owns (Names, Sources, Destinations and anything it declares).
local function pageMode(L, props, mt, page)
  local W, H = padSize(props)
  L.title(string.upper(page:gsub(".", "%0 ")), { M, HEADER + GAP }, { 400, 12 })
  local ctx = { page = page, W = W, H = H, x = M, y = HEADER + GAP + 20, w = PAD_FIT_W, M = M, GAP = GAP, G = G }
  if mt and type(mt.layout) == "function" then
    local ok, err = pcall(mt.layout, L, page, props, ctx)
    if not ok then L.problems[#L.problems + 1] = page .. ": mode layout error: " .. tostring(err) end
  end
end

-- ---------------------------------------------------------------- GetControlLayout

-- Problems found while building the last layout (duplicates, unknown keys,
-- mode layout errors); read by the build lint.
LAYOUT_PROBLEMS = {}

function GetControlLayout(props)
  local mode = modeOf(props)
  local mt = modeTable(mode)
  local kind = cameraKind(props, mode)
  local names = Framework.pageNames(props)
  local index = propInt(props, "page_index", 1, 1, #names)
  local page = names[index] or "Pad"
  local _, meta, order = Framework.buildControls(props)

  local baseW = MIN_PAGE_W
  if page == "Setup" then baseW = M + SETUP_COL_W + GAP + SETUP_COL_W + M end
  local L = newLayout(page, props, meta, order, GetPrettyName(props), baseW)
  header(L, GetPrettyName(props))

  if page == "Pad" then
    pagePad(L, props, mt, padContext(L, props, page), kind)
  elseif page == "Setup" then
    pageSetup(L, props, mt, kind)
  elseif page == "Outputs" then
    pageOutputs(L, props, mt)
  elseif page == "Display" then
    pageDisplay(L, props, mt)
  elseif page == "About" then
    pageAbout(L, props, mt)
  elseif page == "Camera View" then
    pageCameraView(L, props, mt)
  else
    pageMode(L, props, mt, page)
  end

  finishPage(L)
  LAYOUT_PROBLEMS = L.problems
  return L.layout, L.graphics
end

-- ---------------------------------------------------------------- the rest

function GetPins(props) return {} end
function GetComponents(props) return {} end
function GetWiring(props) return {} end
