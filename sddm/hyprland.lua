-- The greeter's compositor, /usr/share/sddm/hypr/hyprland.lua, installed by sddm/install.sh
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")

-- Your cursor from Settings (theme-set.py writes it), if the greeter can read that theme.
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
hl.env("XCURSOR_THEME", cursor_theme)
hl.env("XCURSOR_SIZE", cursor_size)

hl.config({
  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },
  misc = {
    disable_watchdog_warning = true,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },
  input = {
    kb_layout = "us,hr",
    kb_options = "ctrl:nocaps,grp:win_space_toggle",
    numlock_by_default = true,
    touchpad = {
      disable_while_typing = true,
      tap_to_click = true,
    },
  },
  cursor = {
    no_hardware_cursors = true,
    enable_hyprcursor = false,
  },
})

hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "1" })

-- Your session's monitor layout (hypr-monitors.py writes it). The file is yours to write and
-- this runs as the greeter's user, so it's only read as data, never run.
local layout = io.open("/var/lib/kuvk-shell/monitors.conf")
if layout then
  for line in layout:lines() do
    local output, scale, position, transform = line:match("^([^\t]+)\t([%d.]+)\t([^\t]+)\t(%d+)$")
    if output and position == "disabled" then
      hl.monitor({ output = output, disabled = true })
    elseif output then
      hl.monitor({ output = output, mode = "highrr", position = position, scale = scale, transform = tonumber(transform) })
    end
  end
  layout:close()
end

hl.window_rule({
  name = "sddm-greeter",
  match = { class = "^(sddm-greeter)$" },
  workspace = "emptym",
  fullscreen = true,
  no_anim = true,
})
