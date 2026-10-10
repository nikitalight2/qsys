-- Nikita Visual Arts – nikitavisual.art
-- Touch Pad for Q-SYS: XY Pad mode
--
-- The plainest mode: the common outputs only (X, Y, Touching, the pulses,
-- Gesture, drag distance and angle). The pad draws a card with a dotted grid,
-- crosshair lines and a dot at the finger. Hint: "Drag anywhere".
--
-- Design time (controls, pages, layout) and the runtime `create(E)` live here.

Modes = Modes or {}

local HINT = "Drag anywhere"

Modes["XY Pad"] = {
  id = "xy",
  pretty = "XY Pad",
  hint = HINT,

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
      L.hint(ctx, HINT)
    end
  end,

  padColour = function(T)
    return T.bg
  end,

  -- Runtime: the engine calls create(E) once and drives the instance.
  create = function(E)
    local W, H, T = E.W, E.H, E.T
    local inset = math.min(10, math.floor(math.min(W, H) * 0.04))
    local self = {
      x = W / 2, y = H / 2,     -- crosshair position (last finger position)
      down = false,
      grid = nil,               -- cached dotted grid (static per pad and theme)
    }

    -- The dotted grid never changes: draw it once into a scratch canvas and
    -- replay the raw string on every frame (one element per frame).
    local function gridRaw()
      if self.grid then return self.grid end
      local scratch = Svg.new(W, H, { limit = 20000 })
      Shapes.gridDots(scratch, T, W - 2 * inset, H - 2 * inset, 24)
      scratch.parts[1] = scratch.parts[1] or ""
      self.grid = '<g transform="translate(' .. Svg.num(inset) .. " " .. Svg.num(inset) .. ')">'
        .. table.concat(scratch.parts) .. "</g>"
      return self.grid
    end

    function self:onTouchStart(x, y, t)
      self.x, self.y, self.down = x, y, true
      E.invalidate()
    end

    function self:onTouchMove(x, y, t, dx, dy)
      self.x, self.y = x, y
      E.invalidate()
    end

    function self:onTouchEnd(x, y, t, info)
      self.x, self.y, self.down = x, y, false
      E.invalidate()
    end

    function self:onTouchResume(x, y, t)
      self.x, self.y, self.down = x, y, true
      E.invalidate()
    end

    function self:onLock(locked)
      if locked then self.down = false end
      E.invalidate()
    end

    function self:draw(c)
      -- card
      c:rect(inset, inset, W - 2 * inset, H - 2 * inset,
        { fill = T.panel, stroke = T.line, sw = 1, rx = math.max(4, math.floor(inset * 1.2)) })
      c:raw(gridRaw())
      -- crosshair at the finger (or where it was last)
      Shapes.crosshair(c, T, self.x, self.y, W, H)
      if self.down then
        Shapes.dot(c, T, self.x, self.y, 9)
      else
        c:circle(self.x, self.y, 5, { fill = T.accent, opacity = 0.6 })
      end
      if E.hint and not self.down then
        Shapes.hint(c, T, HINT, W, H)
      end
    end

    return self
  end,
}
