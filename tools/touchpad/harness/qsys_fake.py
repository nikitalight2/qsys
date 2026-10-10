#!/usr/bin/env python3
# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: offline fake of the Q-SYS control engine (Python + lupa)
"""Fake Q-SYS runtime for testing the Touch Pad plugin without Designer.

`QSys(...)` loads a .qplug into a fresh Lua 5.3 state whose Q-SYS globals are
replaced by fakes: `Controls` built from the plugin's own `GetControls`,
`Properties`, `Timer` on a virtual clock, `Component` with a fake Color
Picker, `System`, `Crypto`, `require("rapidjson")`, `HttpClient`,
`UdpSocket`, `TcpSocket`, `io` / `dir` sandboxed to a temp folder, captured
`print` and `Log`, and `os.time` / `os.date` on the virtual clock. Every
call into Lua goes through one dispatcher that counts VM instructions with
`debug.sethook` and records the maximum per label.

The public API is described in README.md next to this file. Spec sections 7,
12 and 13 are the contract.
"""
import atexit
import os
import shutil
import tempfile
import weakref

import lupa.lua53 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_PLUGIN = os.path.join(REPO, "plugins", "NikitaTouchPad.qplug")
FIXTURE_PLUGIN = os.path.join(HERE, "fixtures", "mini_plugin.lua")

HANDLER_BUDGET = 120000     # VM instructions per callback (spec section 0)
FRAME_BUDGET = 60000        # VM instructions per dispatch that changed Display's icon
DESIGNER_AXIS_GAP = 0.06    # seconds between the two axis reports in Designer
EN_DASH = "–"

_ACTIVE = []                # QSys instances created since the last reset_registry()


class BudgetError(AssertionError):
    """A Lua callback or frame used more VM instructions than the budget allows."""


class LuaHandlerError(RuntimeError):
    """A Lua callback raised an error that the plugin did not catch."""


class HarnessError(RuntimeError):
    """The harness was used incorrectly (unknown control, property...)."""


def reset_registry():
    """Forgets the QSys instances created so far (run_tests calls it per test)."""
    del _ACTIVE[:]


def active():
    """QSys instances created since the last reset_registry()."""
    return list(_ACTIVE)


# --------------------------------------------------------------------------
# Lua side of the fake. Installed into the state before the plugin loads.
# --------------------------------------------------------------------------
PRELUDE = r"""
local F = {}
__FAKE = F
F.now = 0.0
F.epoch = os.time({ year = 2026, month = 10, day = 10, hour = 12, min = 0, sec = 0 })
F.emulating = false
F.echo = true
F.missing_component = "error"
F.surface_reports = false
F.udp_requires_open = false
F.http_latency = 0.01
F.tcp_latency = 0.01
F.seq = 0
F.queue = {}
F.output = {}
F.log = {}
F.errors = {}
F.maxima = {}
F.frame_max = 0
F.frames = 0
F.dispatches = 0
F.display_writes = 0
F.icon_writes = {}
F.pulses = {}
F.state = setmetatable({}, { __mode = "k" })
F.controls = {}
F.registry = {}
F.registry_order = {}
F.http_log = {}
F.http_reply = { code = 200, data = "", err = nil, headers = {} }
F.udp_log = {}
F.udp_socks = {}
F.tcp_log = {}
F.tcp_connects = {}
F.tcp_socks = {}
F.files_root = ""
F.ticks = 0
F.depth = 0
F.hook_on = false
F.ICON_KEYS = { Display = true, CameraView = true }

local HOOK_GRAN = 10
local real_os, real_io = os, io
local unpack = table.unpack
local pack = table.pack

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

-- ---------------------------------------------------------------- hook
local function hook() F.ticks = F.ticks + 1 end

function F.pause()
  local on = F.hook_on
  if on then
    F.hook_on = false
    debug.sethook()
  end
  return on
end

function F.resume(on)
  if on and not F.hook_on then
    F.hook_on = true
    debug.sethook(hook, "", HOOK_GRAN)
  end
end

-- Runs fn with the instruction counter paused (fake library code is "C" on a Core).
local function uncounted(fn)
  return function(...)
    local on = F.pause()
    local r = pack(pcall(fn, ...))
    F.resume(on)
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
  end
end
F.uncounted = uncounted

local function traceback(e)
  return debug.traceback(tostring(e), 2)
end

local function record(label, used)
  if used > (F.maxima[label] or 0) then F.maxima[label] = used end
end

-- Every call into plugin code goes through here.
function F.dispatch(label, fn, ...)
  if type(fn) ~= "function" then return true, nil, 0 end
  local prev = F.hook_on
  if F.depth == 0 then F.ticks = 0 end
  F.depth = F.depth + 1
  F.dispatches = F.dispatches + 1
  F.resume(true)
  local start = F.ticks
  local d0 = F.display_writes
  local ok, err = xpcall(fn, traceback, ...)
  F.hook_on = false
  debug.sethook()
  F.depth = F.depth - 1
  local used = (F.ticks - start) * HOOK_GRAN
  record(label, used)
  if F.display_writes ~= d0 and label ~= "load" then
    F.frames = F.frames + 1
    if used > F.frame_max then F.frame_max = used end
    record("frame:" .. label, used)
  end
  if not ok then
    F.errors[#F.errors + 1] = { label = label, msg = tostring(err) }
    F.output[#F.output + 1] = "LUA ERROR in " .. label .. ": " .. tostring(err)
  end
  if F.depth > 0 and prev then F.resume(true) end
  return ok, err, used
end

-- ------------------------------------------------------------ controls
local UNITS = {
  dB = { -100, 20 }, Percent = { 0, 100 }, Float = { 0, 1 }, Position = { 0, 1 },
  Integer = { 0, 100 }, Seconds = { 0, 1 }, Pan = { -1, 1 }, Hz = { 20, 20000 },
}
local VALUE_KEYS = { Value = true, String = true, Boolean = true, Position = true }
local PLAIN_KEYS = { Color = true, Choices = true, IsDisabled = true, IsInvisible = true,
                     IsIndeterminate = true, RampTime = true, CssClass = true }

local function tonum(v)
  if type(v) == "number" then return v end
  if type(v) == "boolean" then return v and 1 or 0 end
  if type(v) == "string" then
    local n = tonumber(v)
    if n == nil then n = tonumber(v:match("^%s*(-?%d+%.?%d*)")) end
    return n
  end
  return nil
end

local function fmtKnob(st)
  local v, u = st.Value, st.Unit
  if u == "Integer" then return string.format("%d", math.floor(v + 0.5)) end
  if u == "dB" then return string.format("%.1fdB", v) end
  if u == "Percent" then return string.format("%.0f%%", v) end
  if u == "Hz" then return string.format("%.0fHz", v) end
  if u == "Seconds" then return string.format("%.2fs", v) end
  return string.format("%.2f", v)
end

local coerce = {}
coerce.Knob = function(st, k, v)
  local val
  if k == "Value" then val = tonum(v)
  elseif k == "Position" then
    local p = tonum(v)
    if p then val = st.Min + clamp(p, 0, 1) * (st.Max - st.Min) end
  elseif k == "String" then val = tonum(v)
  elseif k == "Boolean" then val = v and st.Max or st.Min end
  if val == nil then error("cannot set " .. k .. " of '" .. st.key .. "' from a " .. type(v), 4) end
  if st.Unit == "Integer" then val = math.floor(val + 0.5) end
  val = clamp(val, st.Min, st.Max)
  st.Value = val
  st.Position = (st.Max > st.Min) and (val - st.Min) / (st.Max - st.Min) or 0
  st.Boolean = st.Position > 0.5
  st.String = fmtKnob(st)
end
coerce.Meter = coerce.Knob
coerce.Button = function(st, k, v)
  local b
  if k == "Boolean" then b = v and true or false
  elseif k == "Value" or k == "Position" then
    local n = tonum(v)
    if n == nil then error("cannot set " .. k .. " of '" .. st.key .. "' from a " .. type(v), 4) end
    b = n > 0.5
  else
    local s = tostring(v):lower()
    b = (s == "true" or s == "1" or s == "on")
  end
  st.Boolean = b
  st.Value = b and 1 or 0
  st.Position = st.Value
  st.String = b and "true" or "false"
end
coerce.Led = coerce.Button
coerce.Text = function(st, k, v)
  if k == "String" then
    st.String = tostring(v)
    st.Value = tonumber(st.String) or 0
  elseif k == "Value" then
    local n = tonum(v)
    if n == nil then error("cannot set Value of '" .. st.key .. "' from a " .. type(v), 4) end
    st.Value = n
    st.String = tostring(v)
  elseif k == "Boolean" then
    st.String = v and "true" or "false"
    st.Value = v and 1 or 0
  else
    local n = tonum(v) or 0
    st.Value = n
    st.String = tostring(n)
  end
  st.Position = 0
  st.Boolean = false
end
coerce.Status = function(st, k, v)
  if k == "String" then st.String = tostring(v) return end
  local n
  if k == "Value" then n = tonum(v)
  elseif k == "Position" then n = (tonum(v) or 0) * 5
  else n = v and 1 or 0 end
  if n == nil then error("cannot set " .. k .. " of '" .. st.key .. "' from a " .. type(v), 4) end
  n = clamp(math.floor(n + 0.5), 0, 5)
  st.Value = n
  st.Position = n / 5
  st.Boolean = st.Position > 0.5
end

local function kindOf(spec)
  local ct = spec.ControlType
  if ct == "Button" then return "Button" end
  if ct == "Knob" then return "Knob" end
  if ct == "Text" then return "Text" end
  if ct == "Indicator" then
    local it = spec.IndicatorType or "Led"
    if it == "Led" then return "Led" end
    if it == "Meter" then return "Meter" end
    if it == "Text" then return "Text" end
    if it == "Status" or it == "StatusGP" then return "Status" end
    error("GetControls: unknown IndicatorType '" .. tostring(it) .. "' on '" .. tostring(spec.Name) .. "'")
  end
  error("GetControls: unknown ControlType '" .. tostring(ct) .. "' on '" .. tostring(spec.Name) .. "'")
end

function F.trigger(ctl)
  local st = F.state[ctl]
  if st.EventHandler then F.dispatch("trigger:" .. st.key, st.EventHandler, ctl) end
end

local CtlMT = {}
CtlMT.__index = function(ctl, k)
  if k == "Trigger" then return F.trigger end
  return F.state[ctl][k]
end
CtlMT.__newindex = function(ctl, k, v)
  F.ctl_set(ctl, k, v, false, "lua")
end
CtlMT.__tostring = function(ctl)
  return "Control(" .. F.state[ctl].key .. ")"
end

-- Sets a control property. origin "lua" = the script, "py" = the outside
-- world (a panel, another script, a pin). Returns true when the value changed.
function F.ctl_set(ctl, k, v, force, origin)
  local st = F.state[ctl]
  if st == nil then error("not a control", 3) end
  local on = F.pause()
  if VALUE_KEYS[k] then
    local oV, oS, oB, oP = st.Value, st.String, st.Boolean, st.Position
    local ok, err = pcall(coerce[st.kind], st, k, v)
    if not ok then F.resume(on) error(err, 0) end
    local changed = oV ~= st.Value or oS ~= st.String or oB ~= st.Boolean or oP ~= st.Position
    if st.Boolean and not oB then F.pulses[st.key] = (F.pulses[st.key] or 0) + 1 end
    F.resume(on)
    if (changed or force) and st.EventHandler and (origin == "py" or F.echo) then
      F.dispatch("ctl:" .. st.key, st.EventHandler, ctl)
    end
    return changed
  elseif k == "Legend" or k == "Style" then
    v = tostring(v)
    local changed = st[k] ~= v
    st[k] = v
    if changed and F.ICON_KEYS[st.key] then
      F.icon_writes[st.key] = (F.icon_writes[st.key] or 0) + 1
      st.iconKey = k
      if st.key == "Display" then F.display_writes = F.display_writes + 1 end
    end
    F.resume(on)
    return changed
  elseif PLAIN_KEYS[k] then
    st[k] = v
    F.resume(on)
    return true
  elseif k == "EventHandler" then
    if v ~= nil and type(v) ~= "function" then
      F.resume(on)
      error("EventHandler of '" .. st.key .. "' must be a function", 3)
    end
    st.EventHandler = v
    F.resume(on)
    return true
  end
  F.resume(on)
  error("control '" .. st.key .. "' has no property '" .. tostring(k) .. "'", 3)
end

function F.new_control(spec, index, key, owner)
  local kind = kindOf(spec)
  local unit = spec.ControlUnit or "Float"
  local range = UNITS[unit] or UNITS.Float
  local min = spec.Min or range[1]
  local max = spec.Max or range[2]
  if kind == "Status" then min, max = 0, 5 end
  if kind == "Button" or kind == "Led" then min, max = 0, 1 end
  if max < min then max = min end
  local st = {
    Name = spec.Name, Index = index, key = key, owner = owner, kind = kind,
    Min = min, Max = max, Unit = unit, ButtonType = spec.ButtonType,
    Value = 0, String = "", Boolean = false, Position = 0,
    Legend = "", Style = "", Color = "", Choices = {}, CssClass = "",
    IsDisabled = false, IsInvisible = false, IsIndeterminate = false, RampTime = 0,
    EventHandler = nil, iconKey = nil,
  }
  local ctl = setmetatable({}, CtlMT)
  F.state[ctl] = st
  st.ctl = ctl
  local d = spec.DefaultValue
  if kind == "Knob" or kind == "Meter" then
    coerce.Knob(st, "Value", d ~= nil and d or min)
  elseif kind == "Button" or kind == "Led" then
    coerce.Button(st, "Boolean", d == true or d == 1)
  elseif kind == "Text" then
    coerce.Text(st, "String", d ~= nil and tostring(d) or "")
  else
    coerce.Status(st, "Value", 0)
    st.String = ""
  end
  if kind == "Button" and spec.Legend then st.Legend = tostring(spec.Legend) end
  return ctl
end

function F.build_controls(list)
  local C = {}
  for _, spec in ipairs(list) do
    if type(spec.Name) ~= "string" then error("GetControls: a control has no Name") end
    local count = spec.Count or 1
    if count == 1 then
      C[spec.Name] = F.new_control(spec, 1, spec.Name, nil)
    else
      local a = {}
      for i = 1, count do a[i] = F.new_control(spec, i, spec.Name .. " " .. i, nil) end
      C[spec.Name] = a
    end
  end
  F.controls = C
  Controls = C
  return C
end

function F.get_control(name, index)
  local obj = F.controls[name]
  if obj == nil and index == nil then
    local base, n = name:match("^(.-) (%d+)$")
    if base and F.controls[base] ~= nil then
      obj = F.controls[base]
      index = tonumber(n)
    end
  end
  if obj == nil then return nil, "no control named '" .. tostring(name) .. "'" end
  if F.state[obj] then
    if index ~= nil and index ~= 1 then
      return nil, "control '" .. name .. "' is a single control (Count 1); index " .. tostring(index) .. " does not exist"
    end
    return obj
  end
  if index == nil then return nil, "control '" .. name .. "' has " .. #obj .. " elements: pass an index" end
  local c = obj[index]
  if c == nil then return nil, "control '" .. name .. "' has no index " .. tostring(index) end
  return c
end

local function hex(s)
  return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end
F.hex = hex

function F.snapshot(ctl)
  local st = F.state[ctl]
  local choices = {}
  for i, c in ipairs(st.Choices or {}) do choices[i] = tostring(c) end
  return {
    Value = st.Value, StringHex = hex(st.String), Boolean = st.Boolean, Position = st.Position,
    Legend = st.Legend, Style = st.Style, Color = tostring(st.Color), Choices = choices,
    IsDisabled = st.IsDisabled and true or false, IsInvisible = st.IsInvisible and true or false,
    IsIndeterminate = st.IsIndeterminate and true or false, Index = st.Index, Key = st.key,
  }
end

function F.set_from_py(ctl, key, value, force)
  return F.ctl_set(ctl, key, value, force, "py")
end

function F.pulse_count(ctl)
  return F.pulses[F.state[ctl].key] or 0
end

function F.reset_pulses()
  F.pulses = {}
end

-- Decodes the icon of a control: the IconData base64 inside the Legend (or
-- Style) JSON, returned as hex of the SVG bytes; nil when there is none.
function F.icon_hex(name)
  local ctl = F.controls[name]
  if ctl == nil or F.state[ctl] == nil then return nil end
  local st = F.state[ctl]
  local src = st[st.iconKey or "Legend"]
  if type(src) ~= "string" or src == "" then return nil end
  local b64 = src:match('"IconData"%s*:%s*"([^"]*)"')
  if not b64 then return nil end
  return hex(F.base64decode(b64))
end

-- ----------------------------------------------------------- properties
function F.build_props(mode, overrides)
  local list = GetProperties()
  local props = {}
  local order = {}
  for _, p in ipairs(list) do
    local copy = {}
    for k, v in pairs(p) do copy[k] = v end
    props[p.Name] = copy
    order[#order + 1] = p.Name
  end
  if mode ~= nil then
    if props["Mode"] == nil then error("GetProperties has no 'Mode' property") end
    props["Mode"].Value = mode
  end
  if overrides then
    for k, v in pairs(overrides) do
      if props[k] == nil then error("unknown property '" .. tostring(k) .. "'") end
      props[k].Value = v
    end
  end
  props["page_index"] = { Name = "page_index", Value = 1 }
  if type(RectifyProperties) == "function" then RectifyProperties(props) end
  return props, order
end

-- --------------------------------------------------------------- Timer
Timer = {}
local TimerMT = {}
TimerMT.__index = TimerMT

local function schedule(entry)
  F.seq = F.seq + 1
  entry.seq = F.seq
  F.queue[#F.queue + 1] = entry
  return entry
end

function Timer.Now() return F.now end

function Timer.New()
  local t = setmetatable({ EventHandler = nil, _running = false, _gen = 0, _period = 0 }, TimerMT)
  return t
end

TimerMT.Start = uncounted(function(self, seconds)
  seconds = tonumber(seconds)
  if seconds == nil or seconds <= 0 then error("Timer:Start needs a positive interval", 2) end
  self._gen = self._gen + 1
  self._running = true
  self._period = seconds
  schedule({ due = F.now + seconds, kind = "timer", obj = self, gen = self._gen })
end)

TimerMT.Stop = uncounted(function(self)
  self._gen = self._gen + 1
  self._running = false
end)

function TimerMT.IsRunning(self) return self._running end

Timer.CallAfter = uncounted(function(fn, seconds)
  if type(fn) ~= "function" then error("Timer.CallAfter needs a function", 2) end
  seconds = tonumber(seconds) or 0
  if seconds < 0 then seconds = 0 end
  schedule({ due = F.now + seconds, kind = "after", fn = fn })
end)

local function popDue(limit)
  local best, bi
  for i, e in ipairs(F.queue) do
    if e.due <= limit and (best == nil or e.due < best.due or (e.due == best.due and e.seq < best.seq)) then
      best, bi = e, i
    end
  end
  if best then table.remove(F.queue, bi) end
  return best
end

local function fire(e)
  if e.kind == "timer" then
    local t = e.obj
    if t._running and t._gen == e.gen then
      F.dispatch("timer", t.EventHandler, t)
      if t._running and t._gen == e.gen then
        schedule({ due = e.due + t._period, kind = "timer", obj = t, gen = e.gen })
      end
    end
  elseif e.kind == "after" then
    F.dispatch("callafter", e.fn)
  elseif e.kind == "http" then
    local r = F.http_reply
    e.log.code = r.code
    local headers = r.headers or {}
    F.dispatch("http", e.tbl.EventHandler, e.tbl, r.code, r.data or "", r.err, headers)
  elseif e.kind == "tcp" then
    F.tcp_fire(e.sock, e.evt, e.err)
  end
end

function F.advance(seconds)
  seconds = tonumber(seconds) or 0
  if seconds < 0 then error("advance needs a non-negative time") end
  local target = F.now + seconds
  local guard = 0
  while true do
    guard = guard + 1
    if guard > 200000 then error("timer storm: more than 200000 events in one advance()") end
    local e = popDue(target)
    if e == nil then break end
    if e.due > F.now then F.now = e.due end
    fire(e)
  end
  F.now = target
  return F.now
end

function F.pending()
  return #F.queue
end

-- ----------------------------------------------------------- Component
Component = {}

function F.add_component(name, ctype)
  if F.registry[name] then
    F.registry[name] = nil
    for i, n in ipairs(F.registry_order) do
      if n == name then table.remove(F.registry_order, i) break end
    end
  end
  local c = { Name = name, Type = ctype, controls = {}, order = {} }
  c.proxy = setmetatable({}, {
    __index = function(_, k) return c.controls[k] end,
    __newindex = function(_, k) error("cannot create control '" .. tostring(k) .. "' on component '" .. name .. "'", 2) end,
    __tostring = function() return "Component(" .. name .. ")" end,
  })
  F.registry[name] = c
  F.registry_order[#F.registry_order + 1] = name
  return c
end

function F.add_control(comp, ctlname, kind, min, max, value)
  local c = F.registry[comp]
  local spec
  if kind == "Button" then
    spec = { Name = ctlname, ControlType = "Button", ButtonType = "Toggle", DefaultValue = value }
  elseif kind == "Text" then
    spec = { Name = ctlname, ControlType = "Text", DefaultValue = value }
  else
    spec = { Name = ctlname, ControlType = "Knob", ControlUnit = "Float", Min = min, Max = max, DefaultValue = value }
  end
  local ctl = F.new_control(spec, 1, comp .. "~" .. ctlname, comp)
  c.controls[ctlname] = ctl
  c.order[#c.order + 1] = ctlname
  return ctl
end

function F.remove_component(name)
  F.registry[name] = nil
  for i, n in ipairs(F.registry_order) do
    if n == name then table.remove(F.registry_order, i) break end
  end
end

Component.New = uncounted(function(name)
  local c = F.registry[name]
  if c == nil then
    if F.missing_component == "empty" then return {} end
    error("Component.New: no component with code name '" .. tostring(name) .. "' (or its Script Access is None)", 2)
  end
  return c.proxy
end)

Component.GetComponents = uncounted(function()
  local out = {}
  for _, name in ipairs(F.registry_order) do
    local c = F.registry[name]
    out[#out + 1] = { Name = c.Name, Type = c.Type, Properties = {} }
  end
  return out
end)

local TYPE_NAMES = { Knob = "Float", Meter = "Float", Button = "Boolean", Led = "Boolean", Text = "Text", Status = "Status" }
Component.GetControls = uncounted(function(name)
  local c = F.registry[name]
  if c == nil then return {} end
  local out = {}
  for i, ctlname in ipairs(c.order) do
    local st = F.state[c.controls[ctlname]]
    out[i] = { Name = ctlname, Value = st.Value, String = st.String, Position = st.Position, Boolean = st.Boolean,
               Type = TYPE_NAMES[st.kind] or st.kind, Direction = "Read/Write", MinValue = st.Min, MaxValue = st.Max,
               MinString = tostring(st.Min), MaxString = tostring(st.Max), RampTime = 0, Index = 1 }
  end
  return out
end)

function F.component_control(comp, ctlname)
  local c = F.registry[comp]
  if c == nil then return nil end
  return c.controls[ctlname]
end

-- Picker axis write from the outside (a finger). Returns true when it changed.
function F.picker_axis(comp, ctlname, pos, force)
  local ctl = F.component_control(comp, ctlname)
  if ctl == nil then error("picker '" .. comp .. "' has no control '" .. ctlname .. "'") end
  return F.ctl_set(ctl, "Position", pos, force, "py")
end

function F.picker_surface(comp, u, v)
  local ctl = F.component_control(comp, "color_picker_surface")
  if ctl == nil then return end
  local hexc = string.format("#%02X%02X%02X", math.floor(255 * (1 - u) * v + 0.5), math.floor(255 * v * (1 - u * 0.5) + 0.5), math.floor(255 * v + 0.5))
  if F.surface_reports then
    F.ctl_set(ctl, "String", hexc, true, "py")
  else
    local st = F.state[ctl]
    st.String = hexc
  end
end

-- ------------------------------------------------------------- System
System = { IsEmulating = false, BuildVersion = "10.4.0", MajorVersion = 10, MinorVersion = 4,
           Version = "10.4.0", LockingId = "HARNESS-0000-0000" }

-- -------------------------------------------------------------- Crypto
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64R = {}
for i = 1, 64 do B64R[B64:sub(i, i)] = i - 1 end

local function base64encode(s, pad)
  if type(s) ~= "string" then error("Crypto.Base64Encode needs a string", 3) end
  if pad == nil then pad = true end
  local out = {}
  local n = #s
  for i = 1, n, 3 do
    local a, b, c = s:byte(i, i + 2)
    local v = a * 65536 + (b or 0) * 256 + (c or 0)
    local c1 = (v >> 18) & 63
    local c2 = (v >> 12) & 63
    local c3 = (v >> 6) & 63
    local c4 = v & 63
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (b and B64:sub(c3 + 1, c3 + 1) or (pad and "=" or ""))
      .. (c and B64:sub(c4 + 1, c4 + 1) or (pad and "=" or ""))
  end
  return table.concat(out)
end

local function base64decode(s)
  if type(s) ~= "string" then error("Crypto.Base64Decode needs a string", 3) end
  s = s:gsub("[^%w%+/=]", "")
  local out = {}
  local bits, nbits = 0, 0
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == "=" then break end
    local v = B64R[ch]
    if v == nil then error("Crypto.Base64Decode: bad character", 3) end
    bits = (bits << 6) | v
    nbits = nbits + 6
    if nbits >= 8 then
      nbits = nbits - 8
      out[#out + 1] = string.char((bits >> nbits) & 255)
      bits = bits & ((1 << nbits) - 1)
    end
  end
  return table.concat(out)
end
F.base64decode = base64decode

Crypto = {
  Base64Encode = uncounted(base64encode),
  Base64Decode = uncounted(base64decode),
  Digest = function() error("Crypto.Digest is not available in the harness") end,
  HMAC = function() error("Crypto.HMAC is not available in the harness") end,
}

-- ---------------------------------------------------------------- JSON
local json = {}
json.null = setmetatable({}, { __tostring = function() return "null" end, __name = "json.null" })
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function escapeString(s)
  return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function isArray(t)
  local mt = getmetatable(t)
  if mt and mt.__jsontype then return mt.__jsontype == "array" end
  return #t > 0
end

local function encodeValue(v, out, depth)
  if depth > 64 then error("json.encode: nesting too deep") end
  local tv = type(v)
  if v == nil or v == json.null then out[#out + 1] = "null"
  elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then error("json.encode: cannot encode " .. tostring(v)) end
    if math.type(v) == "integer" then out[#out + 1] = string.format("%d", v)
    elseif v == math.floor(v) and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", math.floor(v))
    else out[#out + 1] = string.format("%.14g", v) end
  elseif tv == "string" then out[#out + 1] = escapeString(v)
  elseif tv == "table" then
    if isArray(v) then
      out[#out + 1] = "["
      for i = 1, #v do
        if i > 1 then out[#out + 1] = "," end
        encodeValue(v[i], out, depth + 1)
      end
      out[#out + 1] = "]"
    else
      local keys = {}
      for k in pairs(v) do
        if type(k) == "string" then keys[#keys + 1] = k end
      end
      table.sort(keys)
      out[#out + 1] = "{"
      for i, k in ipairs(keys) do
        if i > 1 then out[#out + 1] = "," end
        out[#out + 1] = escapeString(k)
        out[#out + 1] = ":"
        encodeValue(v[k], out, depth + 1)
      end
      out[#out + 1] = "}"
    end
  else
    error("json.encode: cannot encode a " .. tv)
  end
end

json.encode = uncounted(function(v, opts)
  local out = {}
  encodeValue(v, out, 0)
  return table.concat(out)
end)

local function decodeString(s, pos)
  local out = {}
  local i = pos + 1
  local n = #s
  local guard = 0
  while i <= n do
    guard = guard + 1
    if guard > n + 2 then break end
    local plain = s:find('[%c"\\]', i)
    if plain == nil then break end
    if plain > i then out[#out + 1] = s:sub(i, plain - 1) end
    local c = s:sub(plain, plain)
    if c == '"' then return table.concat(out), plain + 1 end
    if c == "\\" then
      local e = s:sub(plain + 1, plain + 1)
      if e == "u" then
        local cp = tonumber(s:sub(plain + 2, plain + 5), 16)
        if cp == nil then error("json.decode: bad \\u escape at " .. plain) end
        out[#out + 1] = utf8.char(cp)
        i = plain + 6
      else
        local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        if map[e] == nil then error("json.decode: bad escape at " .. plain) end
        out[#out + 1] = map[e]
        i = plain + 2
      end
    else
      error("json.decode: control character in string at " .. plain)
    end
  end
  error("json.decode: unterminated string at " .. pos)
end

local decodeValue
local function skipSpace(s, pos)
  return s:find("[^ \t\r\n]", pos) or (#s + 1)
end

decodeValue = function(s, pos, depth)
  if depth > 64 then error("json.decode: nesting too deep") end
  pos = skipSpace(s, pos)
  local c = s:sub(pos, pos)
  if c == "{" then
    local obj = {}
    pos = skipSpace(s, pos + 1)
    if s:sub(pos, pos) == "}" then return obj, pos + 1 end
    local guard = 0
    while true do
      guard = guard + 1
      if guard > #s then error("json.decode: runaway object") end
      pos = skipSpace(s, pos)
      if s:sub(pos, pos) ~= '"' then error("json.decode: expected a key at " .. pos) end
      local key
      key, pos = decodeString(s, pos)
      pos = skipSpace(s, pos)
      if s:sub(pos, pos) ~= ":" then error("json.decode: expected ':' at " .. pos) end
      local val
      val, pos = decodeValue(s, pos + 1, depth + 1)
      obj[key] = val
      pos = skipSpace(s, pos)
      local d = s:sub(pos, pos)
      if d == "}" then return obj, pos + 1 end
      if d ~= "," then error("json.decode: expected ',' or '}' at " .. pos) end
      pos = pos + 1
    end
  elseif c == "[" then
    local arr = setmetatable({}, { __jsontype = "array" })
    pos = skipSpace(s, pos + 1)
    if s:sub(pos, pos) == "]" then return arr, pos + 1 end
    local guard = 0
    while true do
      guard = guard + 1
      if guard > #s then error("json.decode: runaway array") end
      local val
      val, pos = decodeValue(s, pos, depth + 1)
      arr[#arr + 1] = val
      pos = skipSpace(s, pos)
      local d = s:sub(pos, pos)
      if d == "]" then return arr, pos + 1 end
      if d ~= "," then error("json.decode: expected ',' or ']' at " .. pos) end
      pos = pos + 1
    end
  elseif c == '"' then
    return decodeString(s, pos)
  elseif s:sub(pos, pos + 3) == "true" then return true, pos + 4
  elseif s:sub(pos, pos + 4) == "false" then return false, pos + 5
  elseif s:sub(pos, pos + 3) == "null" then return json.null, pos + 4
  else
    local num = s:match("^-?%d+%.?%d*[eE][-+]?%d+", pos) or s:match("^-?%d+%.?%d*", pos)
    if num == nil or num == "" then error("json.decode: unexpected character at " .. pos) end
    local n = tonumber(num)
    if n == nil then error("json.decode: bad number at " .. pos) end
    return n, pos + #num
  end
end

json.decode = uncounted(function(s)
  if type(s) ~= "string" then return nil, "json.decode needs a string" end
  local ok, val, pos = pcall(decodeValue, s, 1, 0)
  if not ok then return nil, tostring(val) end
  pos = skipSpace(s, pos)
  if pos <= #s then return nil, "json.decode: trailing characters at " .. pos end
  return val
end)
F.json = json

package = nil
function require(name)
  if name == "rapidjson" or name == "json" then return json end
  error("module '" .. tostring(name) .. "' not found (the harness offers rapidjson and json only)", 2)
end

-- ---------------------------------------------------------- HttpClient
HttpClient = {}

local function request(kind, method, tbl)
  if type(tbl) ~= "table" then error("HttpClient." .. kind .. " needs a table", 3) end
  if type(tbl.Url) ~= "string" then error("HttpClient." .. kind .. ": Url must be a string", 3) end
  local headers = {}
  for k, v in pairs(tbl.Headers or {}) do headers[tostring(k)] = tostring(v) end
  local entry = { kind = kind, method = tbl.Method or method, url = tbl.Url, headers = headers,
                  body = tbl.Data or "", timeout = tbl.Timeout, code = nil, at = F.now }
  F.http_log[#F.http_log + 1] = entry
  schedule({ due = F.now + F.http_latency, kind = "http", tbl = tbl, log = entry })
end

HttpClient.Upload = uncounted(function(tbl)
  local m = tbl and tbl.Method
  if m ~= "POST" and m ~= "PUT" and m ~= "PATCH" then error("HttpClient.Upload: Method must be POST, PUT or PATCH", 2) end
  request("Upload", m, tbl)
end)
HttpClient.Download = uncounted(function(tbl) request("Download", "GET", tbl) end)
HttpClient.Get = uncounted(function(tbl) request("Get", "GET", tbl) end)
HttpClient.Post = uncounted(function(tbl) request("Post", "POST", tbl) end)
HttpClient.Put = uncounted(function(tbl) request("Put", "PUT", tbl) end)
HttpClient.Patch = uncounted(function(tbl) request("Patch", "PATCH", tbl) end)
HttpClient.Delete = uncounted(function(tbl) request("Delete", "DELETE", tbl) end)

function HttpClient.EncodeString(s)
  return (tostring(s):gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end
function HttpClient.DecodeString(s)
  return (tostring(s):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
function HttpClient.EncodeParams(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = HttpClient.EncodeString(k) .. "=" .. HttpClient.EncodeString(t[k]) end
  return table.concat(parts, "&")
end
function HttpClient.CreateUrl(t)
  local url = "http://" .. tostring(t.Host)
  if t.Port then url = url .. ":" .. tostring(t.Port) end
  url = url .. (t.Path or "/")
  if t.Query then url = url .. "?" .. HttpClient.EncodeParams(t.Query) end
  return url
end

-- ----------------------------------------------------------- UdpSocket
UdpSocket = {}
local UdpMT = {}
UdpMT.__index = UdpMT

function UdpSocket.New()
  local s = setmetatable({ EventHandler = nil, Data = nil, MulticastTtl = 1, _open = false, _closed = false,
                           _ip = nil, _port = nil, _groups = {} }, UdpMT)
  F.udp_socks[#F.udp_socks + 1] = s
  return s
end

UdpMT.Open = uncounted(function(self, ip, port)
  self._open, self._closed, self._ip, self._port = true, false, ip, port
end)
UdpMT.Close = uncounted(function(self)
  self._open, self._closed = false, true
end)
UdpMT.Send = uncounted(function(self, ip, port, data)
  if self._closed or (F.udp_requires_open and not self._open) then error("UdpSocket: socket is closed", 2) end
  if type(ip) ~= "string" then error("UdpSocket:Send: ip must be a string", 2) end
  port = tonumber(port)
  if port == nil or port < 0 or port > 65535 then error("UdpSocket:Send: port must be 0..65535", 2) end
  if type(data) ~= "string" then error("UdpSocket:Send: data must be a string", 2) end
  if #data > 65535 then error("UdpSocket:Send: data longer than 65535 bytes", 2) end
  self._open = true
  F.udp_log[#F.udp_log + 1] = { ip = ip, port = math.floor(port), data = data, at = F.now }
end)
UdpMT.JoinMulticast = uncounted(function(self, group, localIp)
  self._groups[#self._groups + 1] = group
end)

function F.udp_inject(index, data, address, port)
  local targets = {}
  if index then
    targets[1] = F.udp_socks[index]
  else
    for _, s in ipairs(F.udp_socks) do
      if not s._closed then targets[#targets + 1] = s end
    end
  end
  local n = 0
  for _, s in ipairs(targets) do
    local packet = { Address = address, Port = port, Data = data }
    if type(s.EventHandler) == "function" then
      F.dispatch("udp", s.EventHandler, s, packet)
      n = n + 1
    elseif type(s.Data) == "function" then
      F.dispatch("udp", s.Data, s, packet)
      n = n + 1
    end
  end
  return n
end

-- ----------------------------------------------------------- TcpSocket
TcpSocket = {
  Events = { Connected = "CONNECTED", Reconnect = "RECONNECT", Data = "DATA", Closed = "EOF", Error = "ERROR", Timeout = "TIMEOUT" },
  EOL = { Any = 0, CrLf = 1, CrLfStrict = 2, Lf = 3, Null = 4, Custom = 5 },
}
local TcpMT = {}
TcpMT.__index = TcpMT

function TcpSocket.New()
  local s = setmetatable({ EventHandler = nil, Connected = nil, Reconnect = nil, Data = nil, Closed = nil,
                           Error = nil, Timeout = nil, ReadTimeout = 0, WriteTimeout = 0, ReconnectTimeout = 5,
                           IsConnected = false, BufferLength = 0, PeerAddress = "", _buf = "", _ip = nil, _port = nil }, TcpMT)
  F.tcp_socks[#F.tcp_socks + 1] = s
  return s
end

TcpMT.Connect = uncounted(function(self, ip, port)
  if type(ip) ~= "string" then error("TcpSocket:Connect: ip must be a string", 2) end
  port = tonumber(port)
  if port == nil then error("TcpSocket:Connect: port must be a number", 2) end
  self._ip, self._port = ip, math.floor(port)
  F.tcp_connects[#F.tcp_connects + 1] = { ip = ip, port = self._port, at = F.now }
  schedule({ due = F.now + F.tcp_latency, kind = "tcp", sock = self, evt = "CONNECTED" })
end)
TcpMT.Disconnect = uncounted(function(self)
  self.IsConnected = false
  self._buf = ""
  self.BufferLength = 0
end)
TcpMT.Write = uncounted(function(self, data)
  if not self.IsConnected then error("TcpSocket:Write: socket is not connected", 2) end
  if type(data) ~= "string" then error("TcpSocket:Write: data must be a string", 2) end
  F.tcp_log[#F.tcp_log + 1] = { ip = self._ip, port = self._port, data = data, at = F.now }
end)
TcpMT.Read = uncounted(function(self, n)
  if self._buf == "" then return nil end
  n = tonumber(n) or #self._buf
  local out = self._buf:sub(1, n)
  self._buf = self._buf:sub(n + 1)
  self.BufferLength = #self._buf
  return out
end)
TcpMT.ReadLine = uncounted(function(self, eol, custom)
  local buf = self._buf
  local s, e
  if eol == 0 then s, e = buf:find("[\r\n]+")
  elseif eol == 1 then s, e = buf:find("\r?\n")
  elseif eol == 2 then s, e = buf:find("\r\n", 1, true)
  elseif eol == 3 then s, e = buf:find("\n", 1, true)
  elseif eol == 4 then s, e = buf:find("\0", 1, true)
  elseif eol == 5 then
    if type(custom) ~= "string" or custom == "" then error("TcpSocket:ReadLine: EOL.Custom needs a delimiter", 2) end
    s, e = buf:find(custom, 1, true)
  else error("TcpSocket:ReadLine: unknown EOL", 2) end
  if s == nil then return nil end
  local line = buf:sub(1, s - 1)
  self._buf = buf:sub(e + 1)
  self.BufferLength = #self._buf
  return line
end)
TcpMT.Search = uncounted(function(self, str, start)
  local s = self._buf:find(str, start or 1, true)
  return s
end)

function F.tcp_fire(sock, evt, err)
  if evt == "CONNECTED" then
    sock.IsConnected = true
    sock.PeerAddress = sock._ip or ""
  elseif evt == "EOF" or evt == "ERROR" or evt == "TIMEOUT" then
    sock.IsConnected = false
  end
  local label = "tcp:" .. evt:lower()
  if type(sock.EventHandler) == "function" then
    F.dispatch(label, sock.EventHandler, sock, evt, err)
  end
  local per = { CONNECTED = "Connected", RECONNECT = "Reconnect", DATA = "Data", EOF = "Closed", ERROR = "Error", TIMEOUT = "Timeout" }
  local cb = sock[per[evt]]
  if type(cb) == "function" then F.dispatch(label, cb, sock, err) end
end

local function tcpTargets(index)
  if index then return { F.tcp_socks[index] } end
  local t = {}
  for _, s in ipairs(F.tcp_socks) do
    if s.IsConnected then t[#t + 1] = s end
  end
  return t
end

function F.tcp_inject(index, data)
  local n = 0
  for _, s in ipairs(tcpTargets(index)) do
    s._buf = s._buf .. data
    s.BufferLength = #s._buf
    F.tcp_fire(s, "DATA", nil)
    n = n + 1
  end
  return n
end

function F.tcp_event(index, evt, err)
  local n = 0
  for _, s in ipairs(tcpTargets(index)) do
    F.tcp_fire(s, evt, err)
    n = n + 1
  end
  return n
end

-- ---------------------------------------------------------- io and dir
local function sandboxPath(p)
  if type(p) ~= "string" then return nil, "path must be a string" end
  if p:find("\\", 1, true) or p:find("..", 1, true) or p:sub(1, 1) == "/" then
    return nil, p .. ": Permission denied"
  end
  if p == "media" or p == "design" then p = p .. "/" end
  if p:sub(1, 6) ~= "media/" and p:sub(1, 7) ~= "design/" then
    return nil, p .. ": Permission denied (paths must start with media/ or design/)"
  end
  return F.files_root .. "/" .. p
end
F.sandbox_path = sandboxPath

io = {
  open = uncounted(function(p, mode)
    local full, err = sandboxPath(p)
    if not full then return nil, err end
    return real_io.open(full, mode or "r")
  end),
  lines = uncounted(function(p, ...)
    local full, err = sandboxPath(p)
    if not full then error(err, 2) end
    return real_io.lines(full, ...)
  end),
  type = real_io.type,
}

dir = {
  get = uncounted(function(p)
    local full = sandboxPath(p)
    if not full then return nil end
    return __py_dir_get(full)
  end),
  create = uncounted(function(p)
    local full = sandboxPath(p)
    if not full then return nil end
    return __py_dir_create(full)
  end),
  remove = uncounted(function(p)
    local full = sandboxPath(p)
    if not full then return nil end
    return __py_dir_remove(full)
  end),
}

-- --------------------------------------------------------- print / Log
print = uncounted(function(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[i] = tostring((select(i, ...))) end
  F.output[#F.output + 1] = table.concat(parts, "\t")
end)

Log = {
  Message = uncounted(function(s) F.log[#F.log + 1] = { "message", tostring(s) } end),
  Error = uncounted(function(s) F.log[#F.log + 1] = { "error", tostring(s) } end),
}

-- ------------------------------------------------------------------ os
os = {
  time = uncounted(function(t)
    if t then return real_os.time(t) end
    return math.floor(F.epoch + F.now)
  end),
  date = uncounted(function(fmt, t)
    if t == nil then t = math.floor(F.epoch + F.now) end
    return real_os.date(fmt, t)
  end),
  difftime = real_os.difftime,
  clock = function() error("os.clock is not allowed on a Core: use Timer.Now()", 2) end,
}

-- ------------------------------------------------------------ helpers
function F.load_chunk(code, name)
  local fn, err = load(code, "@" .. name)
  if not fn then error(err, 0) end
  return fn
end

function F.get_output()
  local out = {}
  for i, line in ipairs(F.output) do out[i] = hex(line) end
  return out
end

function F.get_log()
  local out = {}
  for i, e in ipairs(F.log) do out[i] = { e[1], hex(e[2]) } end
  return out
end

function F.get_http()
  local out = {}
  for i, e in ipairs(F.http_log) do
    out[i] = { kind = e.kind, method = e.method, url = e.url, headers = e.headers, body = hex(e.body),
               timeout = e.timeout, code = e.code, at = e.at }
  end
  return out
end

function F.get_udp()
  local out = {}
  for i, e in ipairs(F.udp_log) do out[i] = { ip = e.ip, port = e.port, data = hex(e.data), at = e.at } end
  return out
end

function F.get_tcp()
  local out = {}
  for i, e in ipairs(F.tcp_log) do out[i] = { ip = e.ip, port = e.port, data = hex(e.data), at = e.at } end
  return out
end

function F.set_http_reply(code, data, err)
  F.http_reply = { code = code, data = data, err = err, headers = {} }
end

function F.maxima_list()
  local out = {}
  for label, used in pairs(F.maxima) do out[#out + 1] = { label, used } end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

function F.errors_list()
  local out = {}
  for i, e in ipairs(F.errors) do out[i] = { e.label, hex(e.msg) } end
  return out
end

return F
"""


# --------------------------------------------------------------------------
# Python side
# --------------------------------------------------------------------------
def _lua_list(t):
    """A Lua array table as a Python list (1..#t)."""
    if t is None:
        return []
    return [t[i] for i in range(1, len(t) + 1)]


def _from_hex(h, text=True):
    data = bytes.fromhex(h)
    if not text:
        return data
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def _ascii_ok(text):
    """True when the text is ASCII apart from the brand en dash."""
    return all(ord(ch) < 128 or ch == EN_DASH for ch in text)


class ComponentHandle:
    """A fake component in the registry: `controls[name]` are Lua control objects."""

    def __init__(self, q, name, ctype):
        self.q = q
        self.name = name
        self.type = ctype
        self.controls = {}

    def control(self, name):
        return self.controls[name]

    def get(self, name):
        """{"Value", "String", "Boolean", "Position"} of one of the component's controls."""
        return self.q._snapshot(self.controls[name])

    def set(self, name, value, fire=None):
        """External write to a component control; fires its EventHandler when it changes."""
        self.q._set_control(self.controls[name], value, fire)

    def __repr__(self):
        return "ComponentHandle(%r, %r, %r)" % (self.name, self.type, sorted(self.controls))


class PickerHandle(ComponentHandle):
    """The fake Color Picker: `set(u, v)` writes both axes as a finger would."""

    def __init__(self, q, name, x_name, y_name):
        ComponentHandle.__init__(self, q, name, "color_picker")
        self.x_name = x_name
        self.y_name = y_name

    def set_axis(self, axis, value, force=False):
        """Writes one axis Position (axis "x" or "y"). Returns True when it changed."""
        name = self.x_name if axis == "x" else self.y_name
        value = min(1.0, max(0.0, float(value)))
        changed = bool(self.q.F.picker_axis(self.name, name, value, bool(force)))
        self.q._check_errors()
        return changed

    def set(self, u, v, force=False):
        """Writes u then v (Position 0..1 on the two axes). Returns (changed_u, changed_v)."""
        cu = self.set_axis("x", u, force)
        cv = self.set_axis("y", v, force)
        self.q.F.picker_surface(self.name, float(u), float(v))
        self.q._check_errors()
        return cu, cv

    @property
    def position(self):
        """(u, v) currently held by the two axis controls."""
        return (self.get(self.x_name)["Position"], self.get(self.y_name)["Position"])


class QSys:
    """One plugin instance running inside a fake Q-SYS control engine."""

    HANDLER_BUDGET = HANDLER_BUDGET
    FRAME_BUDGET = FRAME_BUDGET

    def __init__(self, mode="XY Pad", props=None, picker="Color_Picker", emulate=False,
                 plugin=None, picker_names=("saturation", "value"), source=None, runtime=True,
                 echo_on_self_write=True, strict=True, strict_errors=True, touch_mode=None,
                 missing_component="error", picker_type="color_picker"):
        if source is None:
            self.plugin_path = plugin or DEFAULT_PLUGIN
            with open(self.plugin_path, "rb") as fh:
                source = fh.read()
            chunk_name = os.path.basename(self.plugin_path)
        else:
            self.plugin_path = None
            if isinstance(source, str):
                source = source.encode("utf-8")
            chunk_name = "source"
        self.mode = mode
        self.emulate = bool(emulate)
        self.strict = strict
        self.strict_errors = strict_errors
        self.touch_mode = touch_mode or ("designer" if emulate else "panel")
        self.calibration = None          # (x0, y0, w, h) override for the finger-to-picker mapping
        self.release_extra = 0.4         # silence added past ReleaseTime by lift() (covers the 0.3 s park)
        self.panel_settle = 0.35         # time advanced after PanelTouch false by lift() (covers the park)
        self.components = {}
        self.picker = None
        self._down = None
        self._errors_seen = 0
        self._closed = False

        self.files = tempfile.mkdtemp(prefix="qsys_fake_")
        os.makedirs(os.path.join(self.files, "media"))
        os.makedirs(os.path.join(self.files, "design"))
        self._finalizer = weakref.finalize(self, shutil.rmtree, self.files, True)

        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.G = self.lua.globals()
        self.G["__py_dir_get"] = self._dir_get
        self.G["__py_dir_create"] = self._dir_create
        self.G["__py_dir_remove"] = self._dir_remove
        self.F = self.lua.execute(PRELUDE)
        self.F.files_root = self.files
        self.F.emulating = self.emulate
        self.G.System.IsEmulating = self.emulate
        self.F.echo = bool(echo_on_self_write)
        self.F.missing_component = missing_component

        # Design time: the whole file runs with Controls = nil.
        self._chunk = self.F.load_chunk(source, chunk_name)
        self.G.Controls = None
        self.G.Properties = None
        try:
            self._chunk()
        except lupa.LuaError as exc:
            raise HarnessError("plugin failed to load at design time: %s" % exc)
        for name in ("GetProperties", "GetControls", "GetControlLayout", "GetPages"):
            if self.G[name] is None:
                raise HarnessError("plugin has no %s function" % name)

        self.props_overrides = dict(props or {})
        self.properties = self._build_props(mode, self.props_overrides)
        self.G.Properties = self.properties
        try:
            controls = self.G.GetControls(self.properties)
            self.F.build_controls(controls)
        except lupa.LuaError as exc:
            raise HarnessError("GetControls: %s" % exc)
        self._control_specs = [dict(_lua_pairs(spec)) for spec in _lua_list(controls)]

        if picker:
            self.picker = self.add_picker(picker, picker_names, picker_type)

        _ACTIVE.append(self)
        if runtime:
            self._dispatch("load", self._chunk)

    # ---------------------------------------------------------- plumbing
    def _build_props(self, mode, overrides):
        try:
            props, _order = self.F.build_props(mode, self.lua.table_from(overrides))
        except lupa.LuaError as exc:
            raise HarnessError("properties: %s" % exc)
        return props

    def _dispatch(self, label, fn, *args):
        ok, err, used = self.F.dispatch(label, fn, *args)
        self._check_errors()
        return used

    def _check_errors(self):
        n = len(self.F.errors)
        if n > self._errors_seen:
            new = self.errors[self._errors_seen:]
            self._errors_seen = n
            if self.strict_errors:
                raise LuaHandlerError("uncaught Lua error in %s: %s" % (new[-1][0], new[-1][1]))

    def _dir_get(self, full):
        if not os.path.isdir(full):
            return None
        entries = []
        for name in sorted(os.listdir(full)):
            kind = "directory" if os.path.isdir(os.path.join(full, name)) else "file"
            entries.append(self.lua.table_from({"name": name, "type": kind}))
        return self.lua.table_from(entries)

    def _dir_create(self, full):
        parent = os.path.dirname(full.rstrip("/"))
        if not os.path.isdir(parent):
            return None
        if os.path.isdir(full):
            return True
        try:
            os.mkdir(full)
        except OSError:
            return None
        return True

    def _dir_remove(self, full):
        try:
            if os.path.isdir(full):
                os.rmdir(full)
            else:
                os.remove(full)
        except OSError:
            return None
        return True

    def _snapshot(self, ctl):
        s = self.F.snapshot(ctl)
        return {
            "Value": s["Value"], "String": _from_hex(s["StringHex"]), "Boolean": bool(s["Boolean"]),
            "Position": s["Position"], "Legend": s["Legend"], "Style": s["Style"], "Color": s["Color"],
            "Choices": _lua_list(s["Choices"]), "IsDisabled": bool(s["IsDisabled"]),
            "IsInvisible": bool(s["IsInvisible"]), "IsIndeterminate": bool(s["IsIndeterminate"]),
            "Index": s["Index"], "Key": s["Key"],
        }

    def _set_control(self, ctl, value, fire=None):
        if isinstance(value, bool):
            key = "Boolean"
        elif isinstance(value, (int, float)):
            key = "Value"
        elif isinstance(value, (str, bytes)):
            key = "String"
        elif isinstance(value, dict) and len(value) == 1:
            key, value = next(iter(value.items()))
        else:
            raise HarnessError("set_pin: value must be a bool, number, string or {property: value}")
        try:
            changed = self.F.set_from_py(ctl, key, value, bool(fire))
        except lupa.LuaError as exc:
            raise HarnessError(str(exc))
        self._check_errors()
        return bool(changed)

    def close(self):
        """Removes the sandbox folder. Instances are also cleaned up when collected."""
        if not self._closed:
            self._closed = True
            self._finalizer()

    # ----------------------------------------------------------- controls
    def control(self, name, index=None):
        """The Lua control object (reads/writes behave as script writes)."""
        res = self.F.get_control(name, index)
        if isinstance(res, tuple):
            raise HarnessError(res[1])
        return res

    def has_control(self, name):
        return self.G.Controls[name] is not None

    def control_names(self):
        """Control keys as the runtime sees them ("Name" or "Name n"), in GetControls order."""
        names = []
        for spec in self._control_specs:
            count = int(spec.get("Count") or 1)
            if count == 1:
                names.append(spec["Name"])
            else:
                names.extend("%s %d" % (spec["Name"], i) for i in range(1, count + 1))
        return names

    def pin(self, name, index=None):
        """{"Value", "String", "Boolean", "Position", "Legend", "Color", "Choices", ...} of a control."""
        return self._snapshot(self.control(name, index))

    def set_pin(self, name, value, index=None, fire=None):
        """External write (a panel, a pin, another script). bool -> Boolean, number -> Value,
        str -> String, {"Position": 0.5} -> that property. Fires the EventHandler when the
        value changed, or always with fire=True. Returns True when the value changed."""
        return self._set_control(self.control(name, index), value, fire)

    def pulses(self, name, index=None):
        """Rising edges (Boolean false -> true) seen on the control since start or reset_pulses()."""
        return int(self.F.pulse_count(self.control(name, index)))

    def reset_pulses(self):
        self.F.reset_pulses()

    def trigger(self, name, index=None):
        """Calls ctl:Trigger() (runs the handler without changing the value)."""
        ctl = self.control(name, index)
        self._dispatch("trigger:" + name, self.F.state[ctl].EventHandler, ctl)

    def status(self):
        """Controls.Status.String, or None when the plugin has no Status control."""
        if not self.has_control("Status"):
            return None
        return self.pin("Status")["String"]

    def icon(self, name="Display"):
        """The SVG last set on the control (decoded from the Legend / Style JSON); None if never."""
        h = self.F.icon_hex(name)
        if h is None:
            return None
        return _from_hex(h)

    def camera_view(self):
        return self.icon("CameraView")

    @property
    def icons(self):
        """Number of distinct icon writes on Display."""
        return int(self.F.icon_writes["Display"] or 0)

    def icon_writes(self, name):
        return int(self.F.icon_writes[name] or 0)

    # ------------------------------------------------------- virtual time
    @property
    def now(self):
        return float(self.F.now)

    def advance(self, seconds):
        """Runs every timer, HTTP reply and TCP connect due within `seconds`, in time order."""
        try:
            self.F.advance(float(seconds))
        except lupa.LuaError as exc:
            self._check_errors()
            raise HarnessError(str(exc))
        self._check_errors()
        return self.now

    def pending_events(self):
        return int(self.F.pending())

    @property
    def epoch(self):
        """Wall-clock seconds at virtual time 0 (os.time() returns epoch + now)."""
        return int(self.F.epoch)

    @epoch.setter
    def epoch(self, value):
        self.F.epoch = int(value)

    # --------------------------------------------------------- components
    def add_component(self, name, ctype, controls=None):
        """Registers a fake named component. controls = {name: {"Value": 0.5, "Min": -1, "Max": 1}
        | {"Boolean": False} | {"String": "x"}}. Returns a ComponentHandle."""
        self.F.add_component(name, ctype)
        handle = ComponentHandle(self, name, ctype)
        for cname, spec in (controls or {}).items():
            handle.controls[cname] = self._add_control(name, cname, spec)
        self.components[name] = handle
        return handle

    def _add_control(self, comp, cname, spec):
        spec = dict(spec or {})
        if "Boolean" in spec:
            return self.F.add_control(comp, cname, "Button", 0, 1, bool(spec["Boolean"]))
        if "String" in spec and "Value" not in spec:
            return self.F.add_control(comp, cname, "Text", 0, 1, str(spec["String"]))
        value = float(spec.get("Value", 0))
        lo = float(spec.get("Min", min(0.0, value)))
        hi = float(spec.get("Max", max(1.0, value)))
        return self.F.add_control(comp, cname, "Knob", lo, hi, value)

    def add_picker(self, name, picker_names=("saturation", "value"), ctype="color_picker"):
        """Registers a fake Color Picker with the two axis controls plus color_picker_surface and hue."""
        x_name, y_name = picker_names
        self.F.add_component(name, ctype)
        handle = PickerHandle(self, name, x_name, y_name)
        handle.type = ctype
        handle.controls[x_name] = self.F.add_control(name, x_name, "Knob", 0, 100, 0)
        handle.controls[y_name] = self.F.add_control(name, y_name, "Knob", 0, 100, 0)
        if "hue" not in (x_name, y_name):
            handle.controls["hue"] = self.F.add_control(name, "hue", "Knob", 0, 360, 0)
        handle.controls["color_picker_surface"] = self.F.add_control(name, "color_picker_surface", "Text", 0, 1, "#000000")
        self.components[name] = handle
        return handle

    def remove_component(self, name):
        self.F.remove_component(name)
        self.components.pop(name, None)

    # --------------------------------------------------------------- touch
    @property
    def pad_size(self):
        W = self.properties["Pad Width"]
        H = self.properties["Pad Height"]
        return (float(W.Value) if W is not None else 500.0, float(H.Value) if H is not None else 500.0)

    def _default_calibration(self):
        """The engine's default finger geometry (spec 5.2, 13.1, 13.3): the picker's
        touch square has the side S of the pad's longer side and the pad sits at
        its top-left, so the pad is u 0..W/S, v 1-H/S..1 (v = 0 at the bottom);
        Designer draws the surface wider and the square is the left 4/7 of it.
        A square pad gives (0, 0, 1, 1) and (0, 0, 4/7, 1)."""
        W, H = self.pad_size
        S = max(W, H)
        xf = (4.0 / 7.0) if self.emulate else 1.0
        return (0.0, 1.0 - H / S, xf * W / S, H / S)

    def to_picker(self, x, y):
        """Pad pixels (y down) -> (u, v) picker Positions through the geometry the
        engine assumes (q.calibration overrides the default). A point outside the
        pad but inside the touch square stays outside the pad for the engine; one
        outside the square is clamped to its edge."""
        W, H = self.pad_size
        px = x / W
        py = 1.0 - y / H
        x0, y0, w, h = self.calibration or self._default_calibration()
        u = x0 + px * w
        v = y0 + py * h
        return (min(1.0, max(0.0, u)), min(1.0, max(0.0, v)))

    def _release_time(self):
        if self.has_control("ReleaseTime"):
            return float(self.pin("ReleaseTime")["Value"])
        return 0.25

    def touch(self, points, dt=0.05, mode=None, panel_touch=False, lift=True, hold=0.0, pause=None, silence=None):
        """Replays a finger path. points: [(x, y), ...] in pad px (y down).
        designer mode: the two axes 0.06 s apart, unchanged values suppressed;
        panel mode: both axes at once, every point sent. panel_touch=True drives
        Controls.PanelTouch true before the first point and false at the lift.
        hold: seconds to wait after the last point; pause: (index, seconds) stops
        reporting before point `index`; lift=False leaves the finger down."""
        if self.picker is None:
            raise HarnessError("no picker registered (pass picker=... to QSys)")
        mode = mode or self.touch_mode
        if mode not in ("panel", "designer"):
            raise HarnessError("touch mode must be 'panel' or 'designer'")
        if panel_touch:
            if not self.has_control("PanelTouch"):
                raise HarnessError("the plugin has no PanelTouch control")
            self.set_pin("PanelTouch", True)
        self._down = {"mode": mode, "panel_touch": panel_touch}
        for i, (x, y) in enumerate(points):
            if pause is not None and i == pause[0] and i > 0:
                self.advance(pause[1])
            u, v = self.to_picker(x, y)
            if mode == "designer":
                wrote_u = self.picker.set_axis("x", u, force=False)
                gap = 0.0
                if abs(self.picker.get(self.picker.y_name)["Position"] - v) > 1e-9:
                    if wrote_u:
                        self.advance(DESIGNER_AXIS_GAP)
                        gap = DESIGNER_AXIS_GAP
                    self.picker.set_axis("y", v, force=False)
                self.F.picker_surface(self.picker.name, u, v)
                self.advance(max(dt - gap, 0.0))
            else:
                self.picker.set(u, v, force=True)
                self.advance(dt)
        if hold:
            self.advance(hold)
        if lift:
            self.lift(silence)
        return self

    def lift(self, silence=None):
        """Lifts a finger left down: PanelTouch false then `silence` (default
        panel_settle, 0.35 s) for panel_touch touches, else silence of ReleaseTime +
        release_extra (0.4 s) so the engine infers the lift; both cover the park."""
        if self._down is None:
            return self
        down, self._down = self._down, None
        if down["panel_touch"]:
            self.set_pin("PanelTouch", False)
            self.advance(self.panel_settle if silence is None else silence)
        else:
            self.advance((self._release_time() + self.release_extra) if silence is None else silence)
        return self

    def tap(self, x, y, **kw):
        return self.touch([(x, y)], **kw)

    def double_tap(self, x, y, gap=0.15, **kw):
        """Two taps `gap` seconds apart. In designer mode a second tap on the same
        spot is not reported (Designer does not resend a value): use panel mode."""
        kw.pop("lift", None)
        kw.pop("silence", None)
        self.touch([(x, y)], silence=gap, **kw)
        return self.touch([(x, y)], **kw)

    def long_press(self, x, y, seconds=1.0, panel_touch=True, **kw):
        """A held finger. Without panel_touch the engine cannot tell a hold from a lift."""
        return self.touch([(x, y)], panel_touch=panel_touch, hold=seconds, **kw)

    def swipe(self, x1, y1, x2, y2, seconds=0.2, steps=6, **kw):
        pts = [(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps) for i in range(steps + 1)]
        return self.touch(pts, dt=seconds / steps, **kw)

    def drag(self, points, seconds=1.0, **kw):
        n = max(len(points) - 1, 1)
        return self.touch(list(points), dt=seconds / n, **kw)

    @property
    def finger_down(self):
        return self._down is not None

    # ------------------------------------------------------------ outputs
    def output(self):
        """Captured print() lines (and uncaught Lua errors)."""
        return [_from_hex(h) for h in _lua_list(self.F.get_output())]

    def clear_output(self):
        self.lua.execute("__FAKE.output = {}")

    @property
    def log(self):
        """Log.Message / Log.Error calls as [(kind, text)]."""
        return [(e[1], _from_hex(e[2])) for e in _lua_list(self.F.get_log())]

    @property
    def errors(self):
        """Uncaught errors raised inside Lua callbacks as [(label, traceback)]."""
        return [(e[1], _from_hex(e[2])) for e in _lua_list(self.F.errors_list())]

    def run(self, code):
        """Runs Lua code in the plugin's state (for white-box tests)."""
        return self.lua.execute(code)

    # ------------------------------------------------------------- budget
    def budget(self, strict=None):
        """{"max_handler", "max_frame", "load", "handlers": {label: max}, "frames", "dispatches"}.
        max_handler is the largest handler apart from the load dispatch (reported as "load");
        the load draws the first frame but is never counted as one. Raises BudgetError
        above the budgets unless strict (default q.strict) is False."""
        handlers = {}
        for row in _lua_list(self.F.maxima_list()):
            handlers[row[1]] = int(row[2])
        plain = {k: v for k, v in handlers.items() if not k.startswith("frame:")}
        steady = {k: v for k, v in plain.items() if k != "load"}
        result = {
            "max_handler": max(steady.values()) if steady else 0,
            "max_frame": int(self.F.frame_max),
            "load": int(handlers.get("load", 0)),
            "handlers": handlers,
            "frames": int(self.F.frames),
            "dispatches": int(self.F.dispatches),
        }
        if strict is None:
            strict = self.strict
        if strict:
            over = ["%s: %d > %d" % (k, v, self.HANDLER_BUDGET) for k, v in sorted(plain.items()) if v > self.HANDLER_BUDGET]
            over += ["%s: %d > %d (frame)" % (k, v, self.FRAME_BUDGET) for k, v in sorted(handlers.items())
                     if k.startswith("frame:") and v > self.FRAME_BUDGET]
            if over:
                raise BudgetError("instruction budget exceeded: " + "; ".join(over))
        return result

    def instructions(self, label):
        return int(self.F.maxima[label] or 0)

    # -------------------------------------------------------------- files
    def read_file(self, rel, text=True):
        with open(os.path.join(self.files, rel), "rb") as fh:
            data = fh.read()
        return data.decode("utf-8") if text else data

    def write_file(self, rel, data):
        path = os.path.join(self.files, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if isinstance(data, str):
            data = data.encode("utf-8")
        with open(path, "wb") as fh:
            fh.write(data)

    def file_exists(self, rel):
        return os.path.exists(os.path.join(self.files, rel))

    def list_files(self, rel=""):
        base = os.path.join(self.files, rel)
        out = []
        for root, _dirs, files in os.walk(base):
            for name in files:
                out.append(os.path.relpath(os.path.join(root, name), self.files))
        return sorted(out)

    # ---------------------------------------------------------------- http
    @property
    def http_posts(self):
        """Every HttpClient request so far: {"url", "method", "headers", "body", "timeout", "code", "kind"}."""
        out = []
        for e in _lua_list(self.F.get_http()):
            out.append({
                "url": e["url"], "method": e["method"], "kind": e["kind"],
                "headers": dict(_lua_pairs(e["headers"])), "body": _from_hex(e["body"]),
                "body_bytes": _from_hex(e["body"], text=False), "timeout": e["timeout"],
                "code": e["code"], "at": e["at"],
            })
        return out

    @property
    def http_reply(self):
        r = self.F.http_reply
        return (r.code, r.data, r.err)

    @http_reply.setter
    def http_reply(self, value):
        code, data, err = (tuple(value) + (None, None))[:3]
        self.F.set_http_reply(int(code), data if data is not None else "", err)

    @property
    def http_latency(self):
        return float(self.F.http_latency)

    @http_latency.setter
    def http_latency(self, seconds):
        self.F.http_latency = float(seconds)

    # ------------------------------------------------------------- sockets
    @property
    def udp_sent(self):
        return [(e["ip"], int(e["port"]), _from_hex(e["data"], text=False)) for e in _lua_list(self.F.get_udp())]

    @property
    def tcp_sent(self):
        return [(e["ip"], int(e["port"]), _from_hex(e["data"], text=False)) for e in _lua_list(self.F.get_tcp())]

    @property
    def tcp_connects(self):
        return [(e["ip"], int(e["port"])) for e in _lua_list(self.F.tcp_connects)]

    def inject_udp(self, data, address="127.0.0.1", port=0, index=None):
        """Delivers a datagram to the UDP sockets (all open ones, or the index-th created)."""
        if isinstance(data, str):
            data = data.encode("latin-1")
        n = int(self.F.udp_inject(index, data, address, int(port)))
        self._check_errors()
        return n

    def inject_tcp(self, data, index=None):
        """Appends bytes to the connected TCP sockets' buffers and fires their Data event."""
        if isinstance(data, str):
            data = data.encode("latin-1")
        n = int(self.F.tcp_inject(index, data))
        self._check_errors()
        return n

    def tcp_event(self, event, err=None, index=None):
        """Fires a TcpSocket event: "Connected", "Reconnect", "Data", "Closed", "Error" or "Timeout"."""
        names = {"Connected": "CONNECTED", "Reconnect": "RECONNECT", "Data": "DATA", "Closed": "EOF",
                 "Error": "ERROR", "Timeout": "TIMEOUT"}
        if event not in names:
            raise HarnessError("unknown TCP event %r" % event)
        n = int(self.F.tcp_event(index, names[event], err))
        self._check_errors()
        return n

    @property
    def tcp_latency(self):
        return float(self.F.tcp_latency)

    @tcp_latency.setter
    def tcp_latency(self, seconds):
        self.F.tcp_latency = float(seconds)

    # ------------------------------------------------------------- layout
    def layout_lint(self, matrix=None, mode=None):
        """Runs GetPages / GetControls / GetControlLayout for every page and every
        property override dict in `matrix` (default [{}]); returns a list of problems."""
        problems = []
        mode = mode or self.mode
        for overrides in (matrix or [{}]):
            merged = dict(self.props_overrides)
            merged.update(overrides)
            tag = "%s%s" % (mode, (" " + repr(overrides)) if overrides else "")
            try:
                props = self._build_props(mode, merged)
            except HarnessError as exc:
                problems.append("%s: %s" % (tag, exc))
                continue
            try:
                pages = [p["name"] for p in _lua_list(self.G.GetPages(props))]
                specs = [dict(_lua_pairs(s)) for s in _lua_list(self.G.GetControls(props))]
            except lupa.LuaError as exc:
                problems.append("%s: %s" % (tag, exc))
                continue
            if not pages:
                problems.append("%s: GetPages returned no pages" % tag)
            expected = set()
            for spec in specs:
                count = int(spec.get("Count") or 1)
                if count == 1:
                    expected.add(spec["Name"])
                else:
                    expected.update("%s %d" % (spec["Name"], i) for i in range(1, count + 1))
            placed = set()
            for i, page in enumerate(pages, 1):
                props["page_index"]["Value"] = i
                ptag = "%s/%s" % (tag, page)
                try:
                    result = self.G.GetControlLayout(props)
                except lupa.LuaError as exc:
                    problems.append("%s: GetControlLayout raised %s" % (ptag, exc))
                    continue
                layout, graphics = (result if isinstance(result, tuple) else (result, None))
                problems.extend(self._lint_page(ptag, layout, graphics, expected, placed))
            for key in sorted(expected - placed):
                problems.append("%s: control '%s' is not placed on any page" % (tag, key))
        return problems

    def _lint_page(self, ptag, layout, graphics, expected, placed):
        problems = []
        page_w = page_h = None
        entries = list(_lua_pairs(graphics)) if graphics is not None else []
        for _k, g in entries:
            pos, size = g["Position"], g["Size"]
            if pos is not None and size is not None and float(pos[1]) == 0 and float(pos[2]) == 0:
                if page_w is None or float(size[1]) * float(size[2]) > page_w * page_h:
                    page_w, page_h = float(size[1]), float(size[2])

        def check_box(what, entry):
            pos, size = entry["Position"], entry["Size"]
            if pos is None or size is None:
                problems.append("%s: %s has no Position/Size" % (ptag, what))
                return
            x, y, w, h = float(pos[1]), float(pos[2]), float(size[1]), float(size[2])
            if x < 0 or y < 0:
                problems.append("%s: %s at negative position (%g, %g)" % (ptag, what, x, y))
            if w <= 0 or h <= 0:
                problems.append("%s: %s has an empty size (%g x %g)" % (ptag, what, w, h))
            if page_w is not None and (x + w > page_w + 0.5 or y + h > page_h + 0.5):
                problems.append("%s: %s (%g, %g, %g x %g) leaves the %g x %g page" % (ptag, what, x, y, w, h, page_w, page_h))

        def check_text(what, entry, fields):
            for f in fields:
                v = entry[f]
                if isinstance(v, str) and not _ascii_ok(v):
                    problems.append("%s: %s has non-ASCII text in %s: %r" % (ptag, what, f, v))

        for key, entry in _lua_pairs(layout):
            key = str(key)
            what = "control '%s'" % key
            if key not in expected:
                problems.append("%s: layout places unknown %s" % (ptag, what))
            placed.add(key)
            if entry["Style"] is None:
                problems.append("%s: %s has no Style" % (ptag, what))
            check_box(what, entry)
            check_text(what, entry, ("Legend", "PrettyName"))
        for i, (_k, g) in enumerate(entries, 1):
            what = "graphic %d (%s)" % (i, g["Type"])
            if g["Type"] is None:
                problems.append("%s: graphic %d has no Type" % (ptag, i))
            check_box(what, g)
            check_text(what, g, ("Text",))
        if page_w is None:
            problems.append("%s: no full-page background graphic at (0, 0), page size unknown" % ptag)
        return problems

    def __repr__(self):
        return "QSys(mode=%r, now=%.3f, picker=%r)" % (self.mode, self.now, self.picker and self.picker.name)


def _lua_pairs(t):
    """(key, value) pairs of a Lua table."""
    if t is None:
        return []
    return list(t.items())


def plugin_has_framework(path):
    """True when the plugin at `path` defines the four design-time functions (loads it)."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    with open(path, "rb") as fh:
        lua.execute(fh.read())
    g = lua.globals()
    return all(g[n] is not None for n in ("GetProperties", "GetControls", "GetControlLayout", "GetPages"))


def plugin_modes(path):
    """MODE_NAMES of the plugin at `path` (empty when absent)."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    with open(path, "rb") as fh:
        lua.execute(fh.read())
    return _lua_list(lua.globals()["MODE_NAMES"])


def _cleanup_all():
    for q in list(_ACTIVE):
        q.close()


atexit.register(_cleanup_all)
