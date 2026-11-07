-- Single window (SUPER+SHIFT+S): the shape a lone tiled window keeps, width to height
-- ({ 0, 0 } fills the screen). Loaded by hyprland.lua while it is on.
hl.config({
  layout = {
    single_window_aspect_ratio = { 1, 1 },
  },
})
