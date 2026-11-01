# Quickshell desktop shell

Bar, notifications, launchers, panels and settings for Hyprland. The look follows
the system theme (see `~/.config/theme/README.md`).

## Packages

```sh
sudo pacman -S quickshell networkmanager bluez bluez-utils pipewire wireplumber \
  upower power-profiles-daemon brightnessctl curl ttf-nerd-fonts-symbols noto-fonts-cjk \
  hyprpaper mpvpaper imagemagick ffmpeg cava cliphist wl-clipboard hyprlock hypridle \
  kitty   # the Matrix lock style also needs unimatrix (AUR)
# optional: brightness of external monitors over DDC/CI
sudo pacman -S ddcutil && sudo usermod -aG i2c "$USER"   # then log in again
```

Needs Quickshell 0.2 or newer. No other notification daemon may run: only one
can own the D-Bus name.

## What's in it

| Part | File | Opens with |
|---|---|---|
| Top bar (one per monitor), tooltips on hover | `modules/bar/Bar.qml` | starts with `qs`; `SUPER+SHIFT+B` hides/shows it, `SUPER+CTRL+B` floats it |
| Clock and calendar (week numbers, scroll for months) | `modules/dropdowns/CalendarDropdown.qml` | click the clock |
| Weather (wttr.in) | `modules/dropdowns/WeatherDropdown.qml` | click the temperature |
| Network: Wi-Fi, wired on/off, WireGuard/VPN (import `.conf` from `~/.config/wireguard` or `~/Downloads`), details, live throughput, DNS, speed test | `modules/dropdowns/NetworkDropdown.qml` + `scripts/network.py` | click the network icon |
| Bluetooth devices, pair, connect | `modules/dropdowns/BluetoothDropdown.qml` | click; right-click toggles power |
| Volume, output device, per-app volume | `modules/dropdowns/AudioDropdown.qml` | click; right-click mutes, scroll changes volume |
| Now playing; with several players a card each, switched with the arrows or Left/Right (also in the Control Center) | `components/MediaCard.qml`, `modules/dropdowns/MediaDropdown.qml` | click the track; middle-click play/pause, right-click next player |
| System tray, themed right-click menus | `modules/bar/Tray.qml`, `modules/dropdowns/TrayMenu.qml` | hover the arrow; right-click an icon |
| Battery, power mode (Quiet / Balanced / Performance) | `modules/dropdowns/BatteryDropdown.qml` | click the battery |
| Night light | `scripts/nightlight-toggle.sh` + `services/System.qml` | the Control Center tile |
| Stay awake | `services/System.qml` | the coffee icon (holds an idle inhibitor); while media plays an inhibitor is held automatically |
| Work-Game (no blur/animations/rounding, game gaps, turns Stay Awake on) | `scripts/hypr-gamemode.sh` + `services/System.qml` | the rocket icon, the Control Center tile, or `SUPER+G` |
| Displays | `modules/displays/DisplaysPanel.qml` | the monitor icon, or `SUPER+CTRL+M` |
| Notification popups, with actions and inline replies; web apps show their own name and icon | `modules/notifications/NotificationPopups.qml` | |
| Clipboard history: text and images, type to filter | `modules/launcher/Clipboard.qml` | `SUPER+SHIFT+V` |
| Control Center: toggles, sliders, media (with visualizer), notifications grouped by app, session buttons | `modules/controlcenter/ControlCenter.qml` | `SUPER+N`, or the sliders icon (right-click toggles DND) |
| Search launcher (just the field; apps appear as you type) | `modules/launcher/Launcher.qml` | `SUPER+Space` |
| App menu: categories on the left, apps on the right | `modules/launcher/AppMenu.qml` + `services/Apps.qml` | the Arch icon, or `SUPER+CTRL+Space` |
| Theme carousel (each card the theme's palette as bars, type to search; other monitors are blurred) | `modules/themes/ThemePicker.qml` | `SUPER+CTRL+T`, or the Theme tile |
| Power menu | `modules/powermenu/PowerMenu.qml` | `SUPER+CTRL+Q`, or the power icon |
| Lock screen | hyprlock with `scripts/lockscreen.sh` | `` SUPER+` ``, hypridle |
| Wallpaper carousel (type to search; other monitors are blurred) | `modules/wallpaper/WallpaperPicker.qml` | `SUPER+W`, Tab for live wallpapers |
| System information (fastfetch's output in a window sized to it) | `modules/sysinfo/SysinfoWindow.qml` | the ⓘ button in the app menu and Control Center |
| Keybindings (built from `bindings.lua`, type to filter) | `modules/keybinds/KeybindsWindow.qml` + `scripts/hypr-keybinds.py` | `SUPER+/` |
| Settings | `modules/settings/SettingsWindow.qml` | `SUPER+CTRL+S`, or the gear in the Control Center |

The search launcher takes arrows, Tab, Ctrl+J/K and Ctrl+N/P to move, Enter to
launch, and Esc to clear and close. The app menu switches categories with ←/→
or Tab and filters the category as you type. The power menu takes `l` lock, `u` sleep, `e` log out,
`r` reboot, `s` shut down. In the Control Center, `Shift+C` clears the
notifications and `Shift+D` toggles do not disturb.

The app menu's sidebar and the Control Center (under the clock) have a row
of buttons for Settings, Displays, Keybindings and System information.
Dropdowns close when you switch workspaces, and clicking another bar icon
switches straight to its dropdown.

Settings, Displays, Keybindings and System Information are regular windows: a Hyprland rule (`rules.lua`) makes
them float centered; they always stay floating (tiling one reopens it), open at
their default size and can grow but not shrink below it. They have no close
button unless Settings > Windows > Window buttons is on; close them with Esc
or your close-window binding.

Switching the theme or the wallpaper is animated: a capture of every monitor
covers it while the switch happens underneath, then opens from the middle out
along a diagonal (`services/SwitchFx.qml`, `modules/transition/`). Off with animations or in
Work-Game.

Dropdowns slide out of the bar; one click anywhere outside closes them.
Hovering a bar item shows a dot under it, an open dropdown an accent line.

Preferences are set in Settings, one sidebar section each: Appearance (corner
radius, cursor and size, icon theme, border width, opacity, animations), Fonts (a Nerd Font and a
display font, "Nerd Fonts only" and "Use Nerd Symbols font" switches, hinting and antialiasing), Bar (full width or floating with
margins and rounded corners, clock format, weather location and unit, and which modules show on the primary monitor's bar and on
the others; the clock always shows), Windows (window buttons, gaps for regular
and Work-Game), Notifications, Lock Screen (style and colors),
and Tray & Player (tray icon style, apps that keep their own colors, the
visualizer and its bar count). They are saved to Quickshell's state folder
(`~/.local/state/quickshell/by-shell/<id>/settings.json`). Defaults are in
`config/Config.qml`.

Fonts apply to the shell, GTK, Qt, Hyprland's own windows and the lock and login screens; terminals
set theirs in `kitty.conf`. Slight hinting suits most screens, and grayscale antialiasing avoids
color fringes. Cursors reach the login screen only from `/usr/share/icons`. An icon theme with
`-Light` and `-Dark` versions follows the color theme. The Window buttons switch adds a close button
to shell windows and GTK apps with their own title bar; minimize and maximize never show. Windows
without a title bar (most Qt apps) have no button to show.

## Notifications

The shell is the notification daemon. These come from the dotfiles; to give another script a shell
icon, add its `notify-send -a` name to `appGlyphs` in `services/Notifs.qml`.

| App name | Sent by | When |
|---|---|---|
| Work-Game | `hypr-gamemode.sh` | turned on or off |
| Theme | `theme-set.py` | a theme is applied by name, or applying fails |
| Wallpapers | `wallpaper.py` | live wallpapers pause or resume, none is running, or mpvpaper is missing |

Screenshots (`hyprshot`) send their own notification. Neovim and yazi show theirs inside the app.

## Lock screen

Locking uses hyprlock (`~/.config/scripts/lockscreen.sh`), with the clock and password on the
monitor focused when locking. Settings > Lock Screen sets its colors and style:

- **Matrix**: a fullscreen kitty running unimatrix on every monitor, showing through hyprlock's
  transparent background (`misc:session_lock_xray`). It locks about a second later, once the
  rain is on screen, so that's the frame a wake-up shows first.
- **Background**: the current wallpaper, opaque.
- **Image**: an image you choose, opaque; the wallpaper if none is chosen.

The look is in `theme/.config/theme/templates/hyprlock.conf.tpl`. hypridle runs the script on
`loginctl lock-session` and before sleep.

## Web apps

`~/.config/scripts/webapp.py` makes a site its own app: a Brave/Chromium `--app` window (no tabs, address bar or extension
icons) with a launcher entry and an icon, listed under Internet in the app
menu. `webapp.py` asks for name, URL and icon; `webapp.py install NAME URL
[ICON]`, `list`, `remove NAME`. The icon can be a PNG URL, a file, or a name
from https://dashboardicons.com; without one it tries the app's name there,
then the site's favicon. For no title bar, turn on Brave > Settings >
Appearance > "Use system title bar and borders".

## Wallpapers

`~/.config/scripts/wallpaper.py` backs the carousel. Static wallpapers go in
`~/Pictures/Wallpapers` (hyprpaper), live ones in `~/Pictures/WallpapersLive`
(mpvpaper, one process per monitor, paused while covered by windows). Enter
applies to every monitor, Shift+Enter to the focused one only. The choice is
saved and restored at login. `SUPER+CTRL+W` stops live wallpapers and
`SUPER+SHIFT+W` pauses them. Put source videos in `~/Pictures/WallpapersLive/source`
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
`ddcutil`), assign workspaces, and set the text size in px. Text size sets the shell font, GTK's `text-scaling-factor` (rounded
to whole points) and kitty's font size. Apply writes
`~/.config/hypr/configs/generated/monitors.lua` and reloads Hyprland.
Brightness changes right away.

## Layout

```
shell.qml          entry point, IPC handlers
config/            Theme (colors), Icons (Nerd Font glyphs), Config (preferences)
services/          state singletons: Apps, Audio, Battery, Bluetooth, Cava, Displays, Distro, Hypr,
                   Media, Network (nmcli), Notifs, Panels, SwitchFx, System, Time, Weather
components/        small reusable widgets
modules/           bar, controlcenter, displays, dropdowns, keybinds, launcher, notifications,
                   powermenu, settings, sysinfo, themes, transition, wallpaper
```

## IPC

```sh
qs ipc call launcher toggle | menu
qs ipc call themes toggle
qs ipc call notifications toggle | clear | toggleDnd | dnd true
qs ipc call bar reveal | hide | toggle | floating
qs ipc call power toggle
qs ipc call displays toggle
qs ipc call theme reload | gamemode true
qs ipc call wallpaper toggle | static | live
qs ipc call clipboard toggle
qs ipc call keybinds toggle
qs ipc call sysinfo toggle
qs ipc call settings toggle
qs ipc call panels close
```

## Notes

- With a Lua Hyprland config, workspace clicks dispatch Lua
  (`hl.dsp.focus({ workspace = N })`); with hyprlang they use `workspace N`.
- Debug with `qs -d` or `qs log`. Quickshell reloads on save.
