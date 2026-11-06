-- Autostart (exec-once)
hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  -- Start on workspace 1 right away; the monitor layout follows when late outputs show up
  hl.exec_cmd([[hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })']])
  -- Waits for late outputs (dock, dGPU port) and applies the profile
  hl.exec_cmd("~/.config/scripts/hypr-monitors.py startup")
  -- Regenerate ~/.config/theme/current (no-op if nothing changed), then the shell
  hl.exec_cmd("~/.config/scripts/theme-set.py")
  -- shell.sh starts the shell again if it crashes
  hl.exec_cmd("~/.config/scripts/shell.sh & hyprpaper & hypridle & udiskie &")
  -- Saved wallpapers per monitor, once hyprpaper is up
  hl.exec_cmd("sleep 1; ~/.config/scripts/wallpaper.py restore")
  hl.exec_cmd("~/.config/scripts/autostart.sh")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)

-- Switch to the saved layout for whatever monitors are now connected
-- (profiles in ~/.config/hypr/monitors.json, edited in the Displays panel)
local function monitors_changed()
  hl.exec_cmd("~/.config/scripts/hypr-monitors.py hotplug")
end
hl.on("monitor.added", monitors_changed)
hl.on("monitor.removed", monitors_changed)
