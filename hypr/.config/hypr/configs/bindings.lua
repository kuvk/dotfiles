---------------------
---- MY PROGRAMS ----
---------------------
local terminal = "kitty"
-- yazi-live.sh restarts yazi in place when the theme changes
local fileManager = terminal .. " -e ~/.config/scripts/yazi-live.sh"
-- local fileManager = "dolphin"
local menu = "qs ipc call launcher toggle"
local appMenu = "qs ipc call launcher menu"
local themes = "qs ipc call themes toggle"
local browser = "brave"
local notifications = "qs ipc call notifications toggle"
local bar = "qs ipc call bar toggle"
local displays = "qs ipc call displays toggle"
local lock = "qs ipc call lock lock"
local powermenu = "qs ipc call power toggle"
local settings = "qs ipc call settings toggle"
local keybinds = "qs ipc call keybinds toggle"
local music = "kitty --class cliamp -e cliamp"
local email = "thunderbird"
local gamemode = "~/.config/scripts/hypr-gamemode.sh"

---------------------
---- KEYBINDINGS ----
---------------------
-- The Keybindings window (mainMod + SHIFT + /) is built from this file by
-- ~/.config/scripts/hypr-keybinds.py: a "-- Name" line starts a section, a
-- trailing "-- text" describes a bind, and "--> keys | text" lines describe
-- binds made in loops.
local mainMod = "ALT"

-- General Binds
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal)) -- Terminal
hl.bind(mainMod .. " + CONTROL + return", hl.dsp.exec_cmd(browser)) -- Browser
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(email)) -- Email
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(notifications)) -- Control Center
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager)) -- File manager
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu)) -- Search apps
hl.bind(mainMod .. " + CONTROL + space", hl.dsp.exec_cmd(appMenu)) -- App menu with categories
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.exec_cmd(bar)) -- Show / hide the bar
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(themes)) -- Theme carousel
hl.bind(mainMod .. " + CONTROL + M", hl.dsp.exec_cmd(displays)) -- Displays
hl.bind(mainMod .. " + CONTROL + P", hl.dsp.exec_cmd(settings)) -- Settings
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(music)) -- Music player (cliamp)
hl.bind(mainMod .. " + Q", hl.dsp.window.close()) -- Close window
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd(lock)) -- Lock screen
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(powermenu)) -- Power menu
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" })) -- Float / tile window
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen()) -- Fullscreen
hl.bind(mainMod .. " + S", hl.dsp.layout("togglesplit")) -- Toggle split direction
hl.bind(mainMod .. " + equal", hl.dsp.exec_cmd("~/.config/scripts/hypr-monitors.py")) -- Re-apply the monitor profile
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(gamemode)) -- Work-Game Mode
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd(keybinds)) -- This list of keybindings

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots")) -- Screenshot of a window
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots")) -- Screenshot of a region
hl.bind("CONTROL + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots")) -- Screenshot of a monitor

-- Wallpapers
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle")) -- Wallpaper picker (Tab: live wallpapers)
hl.bind(mainMod .. " + CONTROL + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper.py stop")) -- Stop live wallpapers
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper.py pause")) -- Pause / resume live wallpapers

-- Focus and Movement
--> mainMod + h / j / k / l | Focus left / down / up / right
--> mainMod + SHIFT + h / j / k / l | Move window left / down / up / right
local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(dirs) do
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- Resize
hl.bind(mainMod .. " + CONTROL + h", hl.dsp.window.resize({ x = -20, y = 0, relative = true}), { repeating = true }) -- Shrink width
hl.bind(mainMod .. " + CONTROL + j", hl.dsp.window.resize({ x = 0, y = -20, relative = true}), { repeating = true }) -- Shrink height
hl.bind(mainMod .. " + CONTROL + k", hl.dsp.window.resize({ x = 0, y = 20, relative = true}), { repeating = true }) -- Grow height
hl.bind(mainMod .. " + CONTROL + l", hl.dsp.window.resize({ x = 20, y = 0, relative = true}), { repeating = true }) -- Grow width

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- Move window
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true }) -- Resize window

-- Workspaces
--> mainMod + 1 … 0 | Go to workspace 1 … 10
--> mainMod + SHIFT + 1 … 0 | Move window to workspace 1 … 10
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Multimedia keys
local media_opts = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"), media_opts) -- Volume up
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"), media_opts) -- Volume down
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), media_opts) -- Mute
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), media_opts) -- Mute microphone
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), media_opts) -- Brightness up
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), media_opts) -- Brightness down

-- Player control
local player_opts = { locked = true }
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), player_opts) -- Next track
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), player_opts) -- Play / pause
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), player_opts) -- Play / pause
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), player_opts) -- Previous track
