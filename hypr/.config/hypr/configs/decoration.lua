-- Decoration settings. Corners, window opacity and blur are Quickshell's Settings
-- (Appearance), written to generated/theme.lua by ~/.config/scripts/theme-set.py; missing
-- there, these. Work-Game turns off blur and rounding and makes every window opaque
-- (hypr-gamemode.sh), and leaving it runs this file again, so theme.lua is read afresh.
package.loaded["configs.generated.theme"] = nil
local ok, theme = pcall(require, "configs.generated.theme")
if not ok then
  theme = {}
end

hl.config({
  decoration = {
    rounding = theme.rounding or 6,
    rounding_power = 2,
    active_opacity = theme.active_opacity or 0.98,
    inactive_opacity = theme.inactive_opacity or 0.95,
    fullscreen_opacity = 1.0,

    shadow = {
      enabled = false,
      range = 10,
      render_power = 3,
      color = 0x66000000,
    },

    blur = {
      enabled = theme.blur ~= false,
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
