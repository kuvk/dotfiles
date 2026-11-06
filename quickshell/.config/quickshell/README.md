# Quickshell desktop shell

Bar, notifications, launchers, panels and settings for Hyprland. The look follows
the system theme (see `~/.config/theme/README.md`).

## Packages

`install.sh` installs everything the shell needs from `packages/core.txt` (see "Quickshell, and the
services it talks to" and "Commands the shell and scripts run"). To install by hand:

```sh
sed 's/#.*//' <repo>/packages/core.txt | xargs paru -S --needed
```

Brightness of external monitors over DDC/CI also needs `ddcutil` and
`sudo usermod -aG i2c "$USER"`, then log in again.

Needs Quickshell 0.2 or newer. No other notification daemon may run: only one
can own the D-Bus name.

## What's in it

| Part | File | Opens with |
|---|---|---|
| Top bar (one per monitor), tooltips on hover | `modules/bar/Bar.qml` | starts with `qs`; `SUPER+SHIFT+B` hides/shows it, `SUPER+CTRL+B` floats it |
| Clock and calendar (week numbers, scroll for months) | `modules/dropdowns/CalendarDropdown.qml` | click the clock |
| Weather (wttr.in) | `modules/dropdowns/WeatherDropdown.qml` | click the temperature |
| Network, after Omarchy's panel: the connection with ping, packet loss, throughput, IP and gateway (click to copy); Wi-Fi band (Automatic or pinned); DNS; VPNs (import WireGuard `.conf` from `~/.config/wireguard` or `~/Downloads`); wired ports with a cable; Wi-Fi networks as Connected, Known and Other, filled in live while it's open. Buttons for the Wi-Fi QR code (with the password on request) and the speed test (download and upload dials) | `modules/dropdowns/NetworkDropdown.qml`, `modules/network/` + `services/Network.qml` (Quickshell.Networking) + `scripts/network.py` | click the network icon |
| Bluetooth devices, pair, connect | `modules/dropdowns/BluetoothDropdown.qml` | click; right-click toggles power |
| Volume, output and input device, per-app volume | `modules/dropdowns/AudioDropdown.qml` | click; right-click mutes, scroll changes volume |
| Now playing; with several players a card each, switched with the arrows or Left/Right (also in the Control Center) | `components/MediaCard.qml`, `modules/dropdowns/MediaDropdown.qml` | click the track; middle-click play/pause, right-click next player |
| System tray, themed right-click menus | `modules/bar/Tray.qml`, `modules/dropdowns/TrayMenu.qml` | hover the arrow; right-click an icon |
| Battery, power mode (Quiet / Balanced / Performance) | `modules/dropdowns/BatteryDropdown.qml` | click the battery |
| Night light | `scripts/nightlight-toggle.sh` + `services/System.qml` | the Control Center tile, or `SUPER+CTRL+N`; temperature and schedule in Settings |
| Stay awake | `services/System.qml` | the coffee icon: no idle lock or sleep; the same while media plays |
| Work-Game: **Work** mode (no blur, animations or rounding, own gaps, live wallpapers paused) and **Game** mode (the same, plus a plain US keyboard and Stay Awake) | `scripts/hypr-gamemode.sh` + `services/System.qml` | `SUPER+G` Work, `SUPER+CTRL+G` Game (each again for off); the rocket icon or Control Center tile goes normal, Work, Game. The icon is mauve in Work, accent3 in Game |
| Displays | `modules/displays/DisplaysPanel.qml` | the monitor icon, or `SUPER+CTRL+M` |
| Notification popups, with actions and inline replies; web apps show their own name and icon | `modules/notifications/NotificationPopups.qml` | |
| Clipboard history in RAM (a reboot wipes it): text and images, type to filter | `modules/launcher/Clipboard.qml` | `SUPER+SHIFT+V` |
| Control Center: toggles, sliders, media (with visualizer), notifications grouped by app, session buttons | `modules/controlcenter/ControlCenter.qml` | `SUPER+N`, or the sliders icon (right-click toggles DND) |
| Search launcher (just the field; apps appear as you type) | `modules/launcher/Launcher.qml` | `SUPER+Space` |
| App menu: categories on the left, apps on the right | `modules/launcher/AppMenu.qml` + `services/Apps.qml` | the Arch icon, or `SUPER+CTRL+Space` |
| Theme carousel (each card the theme's palette as bars, type to search; other monitors are blurred) | `modules/themes/ThemePicker.qml` | `SUPER+CTRL+T`, or the Theme tile |
| Power menu (log out, reboot and shut down go through hyprshutdown, which closes apps first) | `modules/powermenu/PowerMenu.qml` | `SUPER+CTRL+Q`, or the power icon |
| Lock screen (Settings > Lock Screen has a preview) | `modules/lock/` + `services/Lock.qml` | `` SUPER+` ``, the power menu, idle, the lid, before every sleep |
| Wallpaper carousel (type to search; other monitors are blurred) | `modules/wallpaper/WallpaperPicker.qml` | `SUPER+W`, Tab for live wallpapers |
| System information (fastfetch's output drawn cell by cell like kitty, in a window sized to it; it opens once the output is ready, Ctrl+C copies it) | `modules/sysinfo/SysinfoWindow.qml` | the ⓘ button in the app menu and Control Center |
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

Preferences are set in Settings, one sidebar section each: Appearance (the three accents per theme,
whether the wallpaper follows the theme, corner radius, cursor and size, icon theme, border width,
opacity, animations), Fonts (a Nerd Font and a
display font, "Nerd Fonts only" and "Use Nerd Symbols font" switches, hinting and antialiasing), Bar (full width or floating with
margins and rounded corners, clock format, weather location and unit, and which modules show on the primary monitor's bar and on
the others; the clock always shows), Windows (window buttons, gaps for regular
and Work-Game), Notifications, Lock Screen (style; sections for the clock and date, avatar, box,
password field and the login screen's power buttons), Idle (minutes until the screen locks and the
machine sleeps; on a laptop a second set for battery),
and Tray & Player (tray icon style, apps that keep their own colors, the
visualizer and its bar count). They are saved to Quickshell's state folder
(`~/.local/state/quickshell/by-shell/<id>/settings.json`). **Save as defaults** writes them to
`config/defaults.json` in this repo; a first start and **Reset to defaults** apply that file, then
`config/Config.qml` covers anything it lacks.

Fonts apply to the shell, GTK, Qt, Hyprland's own windows and the lock and login screens; terminals
set theirs in `kitty.conf`. Slight hinting suits most screens, and grayscale antialiasing avoids
color fringes. Cursors reach the login screen only from `/usr/share/icons`. An icon theme with
`-Light` and `-Dark` versions follows the color theme. The Window buttons switch adds a close button
to shell windows and GTK apps with their own title bar; minimize and maximize never show. Windows
without a title bar (most Qt apps) have no button to show.

## Network

Wi-Fi comes from NetworkManager over D-Bus (`Quickshell.Networking`): while the dropdown is open
the Wi-Fi scanner runs and networks appear as scans report them; connecting, forgetting and the
Wi-Fi switch go through it too, and a wrong or missing password opens the network's password field
again. `scripts/network.py` covers the rest: wired, VPN and DNS (`status`), the live stats with a ping to
the router and 1.1.1.1 every 1.5 s (`stats`), the Wi-Fi band (`band`), the QR code (`qr`, needs
`qrencode`), the password (`password`), WPA-Enterprise sign-in (`eap`, the password on stdin) and the
speed test against Cloudflare (`speedtest`).

The dropdown, the QR code and the speed test dials follow
[Omarchy](https://github.com/basecamp/omarchy)'s network panel, Wi-Fi QR and speed test overlay
(MIT, © David Heinemeier Hansson), restyled for this shell.

## Notifications

The shell is the notification daemon. These come from the dotfiles; to give another script a shell
icon, add its `notify-send -a` name to `appGlyphs` in `services/Notifs.qml`.

| App name | Sent by | When |
|---|---|---|
| Work-Game | `hypr-gamemode.sh` | Work or Game mode on, or off |
| Theme | `theme-set.py` | a theme is applied by name, or applying fails |
| Boot screens | `theme-set.py`, `theme-boot.sh` | the boot splash and menu use an older theme (with an Update button), or updating them finished or failed |
| Wallpapers | `wallpaper.py` | live wallpapers pause or resume, none is running, or mpvpaper is missing |

Screenshots (`hyprshot`) send their own notification. Neovim and yazi show theirs inside the app.

## Lock screen

The lock screen is part of the shell (`modules/lock/`, `services/Lock.qml`), after
[Omarchy](https://github.com/basecamp/omarchy)'s Quickshell lock (MIT). It's a Wayland session
lock: a surface on every monitor, with the clock and password on the one focused when locking (or
the first one left if that monitor is gone). `` SUPER+` ``, the power menu, the idle timer, the lid
and every suspend lock it (`qs ipc call lock lock`). It stays on screen until the machine sleeps:
unlike Omarchy's lock it doesn't turn the screens off, as Hyprland on the laptop's Intel + NVIDIA
crashed when the NVIDIA GPU was left without a lit output.

- **Password:** checked by the system's PAM stack (`/etc/pam.d/login`, the same as hyprlock
  used), so nothing in your home folder decides it. Keys typed on any monitor count.
- **Waking up:** the monitors come back one by one, and with the laptop's screen off Hyprland can
  have only its FALLBACK output for a moment; the lock goes up only once a real screen exists, and
  once up stays until the right password, whatever the monitors do.
- **Reloads and crashes:** Hyprland keeps the session locked when the shell goes away, and a shell
  that starts while Hyprland still holds a lock (and no other lock program runs) locks again at
  once (`misc:allow_session_lock_restore`), as after a reload (editing a shell file) or a crash. A
  new session never starts locked. `scripts/shell.sh` starts the shell again if it crashes, and
  gives up after 5 failures in a row right after starting (`journalctl -t shell.sh`): a Hyprland
  restarted after its own crash can refuse it; log in again from a TTY then.

Settings > Lock Screen sets the style, **Background** (the current wallpaper) or **Image** (an
image you choose; the wallpaper if none is chosen or it can't be read), then in sections: the clock
and date (on or off, one color), the avatar (`~/.face`; on or off, outline), the box behind them
(on or off, outline, background with opacity), the password field (outline, background with
opacity, typing dots, user name, text, and the checking, wrong password and Caps Lock states) and
the login screen's power buttons (background with opacity, icons, outline). **Preview** shows it
without locking. The login screen (`sddm/kuvk`) uses the same settings, sizes and positions, and
always the wallpaper as its background.

## Idle and sleep

The shell does idle itself, after [Omarchy](https://github.com/basecamp/omarchy)'s idle service and
sleep lock (MIT); there's no hypridle.

- **Idle** (`services/Idle.qml`): Hyprland reports the idle time (Quickshell's `IdleMonitor`, which
  respects apps' own idle inhibitors, like a playing video). The screen locks and the machine
  sleeps after the times in Settings > Idle, the battery ones while unplugged on a laptop; any
  input starts over. Stay Awake and playing media hold both off. The screens go off when it sleeps.
  The Displays panel reads monitor brightness (DDC/CI) only while it's open and the screen isn't
  locked: probing the monitors as they woke from sleep upset them.
- **Before every suspend** (the power menu, idle, the lid): `scripts/sleep-monitor.sh`, started at
  login, holds a logind delay inhibitor; when logind announces the sleep it runs
  `scripts/sleep-lock.sh`, which locks and waits until the lock is up on every screen, within
  logind's delay window (`InhibitDelayMaxSec`: 15 s with the drop-in `install.sh` adds, 5 s
  otherwise). If it can't, a notification says the session slept unlocked.
- **The lid** (`scripts/lid-close.sh`, from `bindings.lua`): with no external monitor connected it
  locks at once, and logind suspends (`HandleLidSwitch`, suspend by default, on battery and plugged in
  alike). With one connected the laptop counts as docked: logind ignores the lid
  (`HandleLidSwitchDocked`), nothing locks, and the laptop's screen stays a monitor (turn it off in
  Displays). Unplugging the monitors with the lid closed makes logind suspend after a while, and
  `sleep-lock.sh` locks first.

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
saved and restored at login. With Settings > Appearance > Wallpaper follows theme on, each theme
or accent change draws the logo in accent2 on base and sets it; picking another wallpaper turns it
off. `SUPER+CTRL+W` stops live wallpapers and
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
`ddcutil`), set variable refresh rate (off, always, fullscreen, fullscreen games and video; only
where the screen supports it) and the color mode (sRGB, the panel's own colors from its EDID, and HDR
where supported), assign workspaces, and set the text size in px. Text size sets the shell font, the
GTK and Qt font size in points (13 px is 10 pt) and kitty's font size. Apply writes
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
