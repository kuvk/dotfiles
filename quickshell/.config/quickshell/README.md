# Quickshell desktop shell

Replaces waybar, swaync, rofi (app launcher), wlogout and hyprlock. The look
follows the system theme (see `~/.config/theme/README.md`).

## Packages

```sh
sudo pacman -S quickshell networkmanager bluez bluez-utils pipewire wireplumber \
  upower power-profiles-daemon brightnessctl curl ttf-nerd-fonts-symbols noto-fonts-cjk \
  hyprpaper mpvpaper imagemagick ffmpeg
# optional: brightness of external monitors over DDC/CI
sudo pacman -S ddcutil && sudo usermod -aG i2c "$USER"   # then log in again
```

Needs Quickshell 0.2 or newer. `swaync` must not be running: only one
notification daemon can own the D-Bus name. `noto-fonts-cjk` provides the
katakana in the lock screen's digital rain.

## What's in it

| Part | File | Opens with |
|---|---|---|
| Top bar (one per monitor), tooltips on hover | `modules/bar/Bar.qml` | starts with `qs`; `ALT+SHIFT+Space` hides/shows it |
| Clock and calendar (week numbers, scroll for months) | `modules/popouts/CalendarPopout.qml` | click the clock |
| Weather (wttr.in) | `modules/popouts/WeatherPopout.qml` | click the temperature |
| Wi-Fi list, connect, password, forget | `modules/popouts/NetworkPopout.qml` | click the network icon |
| Bluetooth devices, pair, connect | `modules/popouts/BluetoothPopout.qml` | click; right-click toggles power |
| Volume, output device, per-app volume | `modules/popouts/AudioPopout.qml` | click; right-click mutes, scroll changes volume |
| Now playing | `modules/popouts/MediaPopout.qml` | click the track; middle-click play/pause, right-click next player |
| System tray | `modules/bar/Tray.qml` | hover the arrow |
| Battery, power mode (Quiet / Balanced / Performance) | `modules/popouts/BatteryPopout.qml` | click the battery |
| Stay awake | `services/System.qml` | the coffee icon (holds an idle inhibitor) |
| Displays | `modules/displays/Displays.qml` | the monitor icon, or `ALT+M` |
| Notification popups | `modules/notifications/NotificationPopups.qml` | |
| Control center: toggles, sliders, media, notifications, session buttons | `modules/controlcenter/ControlCenter.qml` | `ALT+N`, or the sliders icon (right-click toggles DND) |
| App launcher | `modules/launcher/Launcher.qml` | `ALT+Space` |
| Theme picker | same file, `themes` mode | `ALT+SHIFT+T`, or the Theme tile |
| Power menu (the old wlogout layout) | `modules/powermenu/PowerMenu.qml` | `ALT+SHIFT+E`, or the power icon |
| Lock screen | `modules/lock/LockScreen.qml` | `` ALT+` ``, hypridle, before sleep |
| Wallpaper carousel | `modules/wallpaper/WallpaperPicker.qml` | `ALT+P` (static), `ALT+W` (live) |
| Settings | `modules/settings/SettingsWindow.qml` | gear in the control center |

The launcher takes arrows, Tab, Ctrl+J/K and Ctrl+N/P to move, Enter to launch,
and Esc to close. The power menu takes `l` lock, `u` sleep, `e` log out,
`r` reboot, `s` shut down.

Dropdowns slide out of the bar; one click anywhere outside closes them.
Hovering a bar item shows a dot under it, an open dropdown an accent line.

Preferences (corner radius, border width, opacity, animations, clock format,
weather location and units, notification timeout, lock screen effects) are
set in the Settings window and saved to Quickshell's state folder
(`~/.local/state/quickshell/by-shell/<id>/settings.json`). Defaults are in
`config/Config.qml`.

## Lock screen

A curtain of digital rain drops from the top on every monitor. The focused
monitor also shows the clock, `~/.face` and the password field. It uses the
`ext-session-lock` protocol, so if Quickshell crashes the session stays locked.
The password is checked with PAM using `pam/password.conf`
(`auth required pam_unix.so`).

hypridle runs `qs ipc call lock lock` on `loginctl lock-session`, and
`lock lockNow` (no animation) before sleep.

## Wallpapers

`~/.config/scripts/wallpaper.py` backs the carousel. Static wallpapers go in
`~/Pictures/Wallpapers` (hyprpaper), live ones in `~/Pictures/WallpapersLive`
(mpvpaper, one process per monitor, paused while covered by windows). Enter
applies to every monitor, Shift+Enter to the focused one only. The choice is
saved and restored at login. `ALT+CTRL+W` stops live wallpapers and
`ALT+SHIFT+W` pauses them. Put source videos in `~/Pictures/WallpapersLive/source`
and run `convert-live-wallpapers.py` to make lighter 1440p/30fps copies.

## Displays

`~/.config/scripts/hypr-monitors.py` keeps one profile per combination of
connected monitors in `~/.config/hypr/monitors.json`. Monitors are matched by
their EDID description, so a profile survives a different port or dock. The
first time a setup is seen, its profile is created from the current layout and
workspaces 1–10 are split across the screens. When a monitor is plugged in or
out, the shell re-applies the matching profile.

Workspace defaults: the primary monitor gets 1–5 and a second one 6–10; with
three monitors each gets three, starting with the primary. Click a workspace to
assign it to the selected monitor, click again to unassign it.

In the panel you can drag monitors (they snap edge to edge), turn them on or
off, pick the primary, change resolution and scale (only scales Hyprland
accepts for that mode), set brightness (laptop backlight, or DDC/CI with
`ddcutil`), assign workspaces, and set the text size in px. Text size works
like Omarchy's: it sets the shell font, GTK's `text-scaling-factor` (rounded
to whole points) and kitty's font size. Apply writes
`~/.config/hypr/configs/generated/monitors.lua` and reloads Hyprland.
Brightness changes right away.

## Layout

```
shell.qml          entry point, IPC handlers
config/            Theme (colors), Icons (Nerd Font glyphs), Config (preferences)
services/          state singletons: Audio, Bluetooth, Displays, Hypr, Lock,
                   Media, Network (nmcli), Notifs, Panels, System, Time, Weather
components/        small reusable widgets
modules/           bar, popouts, notifications, controlcenter, launcher,
                   powermenu, lock, displays
pam/               PAM config for the lock screen
```

## IPC

```sh
qs ipc call launcher toggle | themes
qs ipc call notifications toggle | clear | toggleDnd | dnd true
qs ipc call bar show | hide | toggle
qs ipc call lock lock | lockNow
qs ipc call power toggle
qs ipc call displays toggle
qs ipc call theme reload | gamemode true
qs ipc call wallpaper static | live
qs ipc call settings toggle
qs ipc call panels close
```

## Notes

- With a Lua Hyprland config, workspace clicks dispatch Lua
  (`hl.dsp.focus({ workspace = N })`); with hyprlang they use `workspace N`.
- Debug with `qs -d` or `qs log`. Quickshell reloads on save.
- Waybar and swaync configs are still in the repo and use the theme colors, so
  you can switch back by changing `configs/autostart.lua`.
