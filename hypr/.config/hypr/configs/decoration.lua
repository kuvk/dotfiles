-- Decoration settings
hl.config({
  decoration = {
    rounding = 6,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 0.9,
    fullscreen_opacity = 1.0,

    shadow = {
      enabled = true,
      range = 30,
      render_power = 3,
      color = 0x66000000,
    },

    blur = {
      enabled = true,
      size = 12,
      passes = 4,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
      noise = 0.0117,
      contrast = 0.8916,
      brightness = 0.8172,
      vibrancy = 0.1696,
      vibrancy_darkness = 0.0,
      popups = true,
      popups_ignorealpha = 0.5,
    },
  },
})
