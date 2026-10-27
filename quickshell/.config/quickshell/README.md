# Quickshell desktop shell

Replaces waybar, swaync and the rofi app launcher. The look follows the
system theme (see `~/.config/theme/README.md`).

## Packages

```sh
sudo pacman -S quickshell networkmanager bluez bluez-utils pipewire wireplumber \
  upower brightnessctl ttf-nerd-fonts-symbols
```

Needs Quickshell 0.2 or newer, which has `qs.*` imports and the Bluetooth module.
`swaync` must not be running: only one notification daemon can own the D-Bus name.

## What's in it

| Part | File | Opens with |
|---|---|---|
| Top bar (one per monitor) | `modules/bar/Bar.qml` | starts with `qs` |
| Wi-Fi list, connect, password, forget | `modules/popouts/NetworkPopout.qml` | click the network icon |
| Bluetooth devices, pair, connect | `modules/popouts/BluetoothPopout.qml` | click; right-click toggles power |
| Volume, output device, per-app volume | `modules/popouts/AudioPopout.qml` | click; right-click mutes, scroll changes volume |
| Now playing | `modules/popouts/MediaPopout.qml` | click the track; middle-click play/pause, right-click next player |
| Calendar | `modules/popouts/CalendarPopout.qml` | click the clock |
| System tray | `modules/bar/Tray.qml` | left-click activates, right-click opens the menu |
| Notification popups | `modules/notifications/NotificationPopups.qml` | |
| Control center: toggles, sliders, media, history | `modules/controlcenter/ControlCenter.qml` | `ALT+N`, or click the bell (right-click toggles DND) |
| App launcher | `modules/launcher/Launcher.qml` | `ALT+Space` |
| Theme picker | same file, `themes` mode | `ALT+SHIFT+Space`, or the Theme tile |

The launcher takes arrows, Tab, Ctrl+J/K and Ctrl+N/P to move, Enter to launch,
and Esc to close.

## Layout

```
shell.qml          entry point, IPC handlers
config/            Theme (colors from the theme system), Icons (Nerd Font glyphs)
services/          state singletons: Audio, Bluetooth, Network (nmcli), Notifs,
                   Media (MPRIS), System (scripts, brightness), Hypr, Panels, Time
components/        small reusable widgets
modules/           bar, popouts, notifications, controlcenter, launcher
```

## IPC

```sh
qs ipc call launcher toggle | themes
qs ipc call notifications toggle | clear | toggleDnd | dnd true
qs ipc call bar show | hide | toggle
qs ipc call theme reload | gamemode true
qs ipc call panels close
```

`lockscreen.sh` and `hypr-gamemode.sh` use these.

## Notes

- The Hyprland config is Lua, so workspace clicks dispatch Lua
  (`hl.dsp.focus({ workspace = N })`, see `services/Hypr.qml`). If you go back
  to hyprlang, change that to `workspace N`.
- Debug with `qs -d` or `qs log`. Quickshell reloads on save.
- Waybar and swaync configs are still in the repo and use the theme colors, so
  you can switch back by changing `configs/autostart.lua`.
