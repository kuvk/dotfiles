-- ~/.config/swayimg/init.lua (swayimg 5.x)
--
-- Colors follow the system theme (~/.config/theme/current/swayimg.lua, written
-- by theme-set.py, which also tells running swayimg windows to reload them).
-- swayimg's own defaults stay; the bindings below are added on top.
--
-- Viewer                               Gallery (Enter switches)
--   h / l, N / n previous / next image   h j k l      select
--   H J K L      move the image          g / G        first / last
--   g / G        first / last image      Ctrl+d / u   page down / up
--   + / -        zoom in / out           K / J        bigger / smaller thumbnails
--   0            fit to window           Enter        open in the viewer
--   w            fit to width            q            quit
--   r / R        rotate right / left
--   f            fullscreen
--   i            show/hide info (also t)
--   q            quit (also Escape)

local THEME = os.getenv("HOME") .. "/.config/theme/current/swayimg.lua"

-- catppuccin-mocha, used until theme-set has written the theme file
local fallback = {
  base = 0xff1e1e2e, mantle = 0xff181825, crust = 0xff11111b,
  surface0 = 0xff313244, surface1 = 0xff45475a, surface2 = 0xff585b70,
  overlay1 = 0xff7f849c, text = 0xffcdd6f4, subtext0 = 0xffa6adc8,
  accent = 0xfffab387, accent2 = 0xff89b4fa, overlay_bg = 0xcc181825,
}

local function apply_theme()
  local ok, c = pcall(dofile, THEME)
  if not ok or type(c) ~= "table" then
    c = fallback
  end

  swayimg.text.color = c.text
  swayimg.text.background = c.overlay_bg
  swayimg.text.shadow = 0x00000000

  swayimg.viewer.set_window_background(c.base)
  swayimg.viewer.set_image_chessboard(16, c.surface0, c.surface1)
  swayimg.viewer.mark_color = c.accent2
  swayimg.slideshow.set_window_background(c.base)

  swayimg.gallery.window_color = c.base
  swayimg.gallery.unselected_color = c.surface0
  swayimg.gallery.selected_color = c.surface1
  swayimg.gallery.border_color = c.accent
end

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
swayimg.appid = "swayimg" -- Hyprland floats and centers it (hypr rules.lua)
swayimg.decoration = false

-- opening one image lists the others in its folder, so H/L browse them
swayimg.imagelist.adjacent = true
swayimg.imagelist.order = "alpha"

swayimg.text.font = "JetBrainsMono Nerd Font"
swayimg.text.size = 16
swayimg.text.padding = 12
swayimg.text.timeout = 3

swayimg.gallery.thumb_size = 180
swayimg.gallery.padding_size = 8
swayimg.gallery.border_size = 3
swayimg.gallery.selected_scale = 1.1

apply_theme()

--------------------------------------------------------------------------------
-- Vim keys
--------------------------------------------------------------------------------
local STEP = 60 -- pixels per H/J/K/L press

local function move(dx, dy)
  return function()
    local pos = swayimg.viewer.get_position()
    swayimg.viewer.set_abs_position(pos.x + dx, pos.y + dy)
  end
end

local function zoom(factor)
  return function()
    swayimg.viewer.set_abs_scale(swayimg.viewer.scale * factor)
  end
end

local function open(dir)
  return function()
    swayimg.viewer.open(dir)
  end
end

local function toggle_info()
  swayimg.text.visible = not swayimg.text.visible
end

do
  local mode = swayimg.viewer
  mode.on_key("Shift+h", move(STEP, 0))
  mode.on_key("Shift+l", move(-STEP, 0))
  mode.on_key("Shift+k", move(0, STEP))
  mode.on_key("Shift+j", move(0, -STEP))

  mode.on_key({ "h", "Shift+n" }, open("prev"))
  mode.on_key({ "l", "n" }, open("next"))
  mode.on_key("g", open("first"))
  mode.on_key("Shift+g", open("last"))

  mode.on_key({ "plus", "Shift+plus", "equal" }, zoom(1.25))
  mode.on_key("minus", zoom(0.8))
  mode.on_key("0", function() swayimg.viewer.set_fix_scale("optimal") end)
  mode.on_key("w", function() swayimg.viewer.set_fix_scale("width") end)

  mode.on_key("r", function() swayimg.viewer.rotate(90) end)
  mode.on_key("Shift+r", function() swayimg.viewer.rotate(270) end)
  mode.on_key("i", toggle_info)
  mode.on_key("q", function() swayimg.exit() end)
end

swayimg.slideshow.on_key("q", function() swayimg.exit() end)

local function select(dir)
  return function()
    swayimg.gallery.select(dir)
  end
end

swayimg.gallery.on_key("h", select("left"))
swayimg.gallery.on_key("l", select("right"))
swayimg.gallery.on_key("k", select("up"))
swayimg.gallery.on_key("j", select("down"))
swayimg.gallery.on_key("g", select("first"))
swayimg.gallery.on_key("Shift+g", select("last"))
swayimg.gallery.on_key("Ctrl+d", select("pgdown"))
swayimg.gallery.on_key("Ctrl+u", select("pgup"))
swayimg.gallery.on_key("Shift+k", function()
  swayimg.gallery.thumb_size = swayimg.gallery.thumb_size + 20
end)
swayimg.gallery.on_key("Shift+j", function()
  swayimg.gallery.thumb_size = math.max(60, swayimg.gallery.thumb_size - 20)
end)
swayimg.gallery.on_key("i", toggle_info)
swayimg.gallery.on_key("q", function() swayimg.exit() end)

--------------------------------------------------------------------------------
-- Theme switches (theme-set.py sends SIGUSR1)
--------------------------------------------------------------------------------
for _, mode in ipairs({ swayimg.viewer, swayimg.slideshow, swayimg.gallery }) do
  mode.on_signal("USR1", apply_theme)
end
