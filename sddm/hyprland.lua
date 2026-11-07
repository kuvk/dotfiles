-- The greeter's compositor, /usr/share/sddm/hypr/hyprland.lua, installed by sddm/install.sh

-- Every GPU, the order left to aquamarine. Picking only the boot display's GPU (AQ_DRM_DEVICES)
-- showed the login screen on the laptop's screen alone, and the same setting broke Hyprland 0.57.1
-- in the session.

-- The session's cursor from Settings (theme-set.py writes it), if the greeter can read that theme.
-- Read as data, as below.
local cursor_theme, cursor_size = "Adwaita", "24"
local cursor = io.open("/var/lib/kuvk-shell/cursor.conf")
if cursor then
  local name, size = (cursor:read("l") or ""):match("^([%w%._-]+)\t(%d+)$")
  cursor:close()
  local installed = name and io.open("/usr/share/icons/" .. name .. "/cursors/left_ptr")
  if installed then
    installed:close()
    cursor_theme, cursor_size = name, size
  end
end
hl.env("XCURSOR_SIZE", cursor_size)

-- No cursor until the login screen is up, as in the session (hypr/configs/startup-cursor.lua):
-- Hyprland's first frames come before the cursor theme and the monitors' scales, and showed a
-- larger cursor shrinking. A blank theme (installed next to this file) and a hidden pointer
-- until the greeter's window opens; 10 s at most. The pointer is shown from Lua itself, so
-- the login screen never stays without one.
local blank = "/usr/share/sddm/hypr/cursors"
hl.env("XCURSOR_PATH", blank .. ":/usr/share/icons:/usr/share/pixmaps")
local blank_file = io.open(blank .. "/kuvk-startup/cursors/left_ptr")
if blank_file then
  blank_file:close()
end
hl.env("XCURSOR_THEME", blank_file and "kuvk-startup" or cursor_theme)
hl.config({ cursor = { invisible = true } })

local revealed = false
local function reveal()
  if revealed then
    return
  end
  revealed = true
  hl.env("XCURSOR_PATH", "/usr/share/icons:/usr/share/pixmaps")
  hl.env("XCURSOR_THEME", cursor_theme)
  hl.exec_cmd("hyprctl setcursor '" .. cursor_theme .. "' " .. cursor_size)
  -- time for the theme to load first
  hl.timer(function()
    hl.config({ cursor = { invisible = false } })
  end, { timeout = 150, type = "oneshot" })
end

hl.on("window.open", function()
  hl.timer(reveal, { timeout = 150, type = "oneshot" })
end)
hl.on("hyprland.start", function()
  hl.timer(reveal, { timeout = 10000, type = "oneshot" })
end)

hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },
  -- input = {
  --   kb_layout = "us",
  --   kb_options = "ctrl:nocaps",
  --   touchpad = {
  --     disable_while_typing = true,
  --     tap_to_click = true,
  --   },
  -- },
  animations = {
    enabled = false,
  },
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })

-- The session's monitor layout (hypr-monitors.py writes it). The file is the user's to write and
-- this runs as the greeter's user, so it's only read as data, never run.
local layout = io.open("/var/lib/kuvk-shell/monitors.conf")
if layout then
  for line in layout:lines() do
    local output, scale, position, transform = line:match("^([^\t]+)\t([%d.]+)\t([^\t]+)\t(%d+)$")
    if output and position == "disabled" then
      hl.monitor({ output = output, disabled = true })
    elseif output then
      hl.monitor({
        output = output,
        mode = "preferred",
        position = position,
        scale = scale,
        transform = tonumber(transform),
      })
    end
  end
  layout:close()
end
