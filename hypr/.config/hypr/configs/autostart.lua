-- Autostart (exec-once)
hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  -- Waits for late outputs (dock, dGPU port), applies the profile and focuses workspace 1
  hl.exec_cmd("~/.config/scripts/hypr-monitors.py startup")
  -- Regenerate ~/.config/theme/current (no-op if nothing changed), then the shell
  hl.exec_cmd("~/.config/scripts/theme-set.py")
  hl.exec_cmd("qs & hyprpaper & hypridle & udiskie &")
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
