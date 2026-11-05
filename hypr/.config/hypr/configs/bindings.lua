---------------------
---- MY PROGRAMS ----
---------------------
local terminal = "kitty"
local fileManager = terminal .. " -e yazi"
-- local fileManager = "dolphin"
local menu = "qs ipc call launcher toggle"
local themes = "qs ipc call launcher themes"
local browser = "brave"
local notifications = "qs ipc call notifications toggle"
local bar = "qs ipc call bar toggle"
local displays = "qs ipc call displays toggle"
local lock = "qs ipc call lock lock"
local powermenu = "qs ipc call power toggle"
local settings = "qs ipc call settings toggle"
local music = "kitty --class cliamp -e cliamp"
local email = "thunderbird"
local gamemode = "~/.config/scripts/hypr-gamemode.sh"

---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "ALT"

-- General Binds
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + CONTROL + return", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(email))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(notifications))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.exec_cmd(bar))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(themes))
hl.bind(mainMod .. " + CONTROL + M", hl.dsp.exec_cmd(displays))
hl.bind(mainMod .. " + CONTROL + P", hl.dsp.exec_cmd(settings))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(music))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd(lock))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(powermenu))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + S", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + equal", hl.dsp.exec_cmd("~/.config/scripts/hypr-monitors.py"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(gamemode))

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"))
hl.bind("CONTROL + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"))

-- Wallpapers
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call wallpaper static"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call wallpaper live"))
hl.bind(mainMod .. " + CONTROL + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper.py stop"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper.py pause"))

-- Focus and Movement
local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(dirs) do
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- Resize
hl.bind(mainMod .. " + CONTROL + h", hl.dsp.window.resize({ x = -20, y = 0, relative = true}), { repeating = true })
hl.bind(mainMod .. " + CONTROL + j", hl.dsp.window.resize({ x = 0, y = -20, relative = true}), { repeating = true })
hl.bind(mainMod .. " + CONTROL + k", hl.dsp.window.resize({ x = 0, y = 20, relative = true}), { repeating = true })
hl.bind(mainMod .. " + CONTROL + l", hl.dsp.window.resize({ x = 20, y = 0, relative = true}), { repeating = true })

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true })

-- Workspaces
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Multimedia keys
local media_opts = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"), media_opts)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"), media_opts)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), media_opts)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), media_opts)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), media_opts)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), media_opts)

-- Player control
local player_opts = { locked = true }
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), player_opts)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), player_opts)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), player_opts)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), player_opts)
