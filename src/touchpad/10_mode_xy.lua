-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: XY Pad mode
--
-- The plainest mode: the common outputs only (X, Y, Touching, the pulses,
-- Gesture, drag distance and angle). The pad draws a card with a dotted grid,
-- crosshair lines and a dot at the finger. Hint: "Drag anywhere".
--
-- Design time lives here (controls, pages, layout); the runtime half is the
-- `create` function filled in by the engine work.

Modes = Modes or {}

Modes["XY Pad"] = {
  id = "xy",
  pretty = "XY Pad",
  hint = "Drag anywhere",

  -- No controls beyond the common set.
  controls = function(C, props)
  end,

  -- No extra pages: Pad, Setup, Outputs, Display, About only.
  pages = {},

  -- Pad page: the Display at pad size, the Gesture readout and the hint label.
  -- Other pages carry only the framework's common controls.
  layout = function(L, page, props, ctx)
    if page == "Pad" then
      L.padDisplay(ctx)
      L.gesture(ctx)
      L.hint(ctx, "Drag anywhere")
    end
  end,

  padColour = function(T)
    return T.bg
  end,

  -- Runtime: filled in by the engine (50_runtime.lua calls Modes[mode].create(E)).
  create = nil,
}
