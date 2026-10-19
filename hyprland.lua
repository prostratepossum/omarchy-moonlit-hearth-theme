-- Moonlit Hearth: moonlight to hearth amber on the focused window.
local active_border_color = { colors = { "rgba(8fbbe0ee)", "rgba(f0c47aee)" }, angle = 45 }
local inactive_border_color = "rgba(1a2c45aa)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})
