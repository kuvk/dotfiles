-- Layer Rules
hl.layer_rule({
  match = { class = "^(waybar|rofi|swaync-control-center|swaync-notification-window|logout_dialog)$" },
  blur = true,
  ignore_alpha = 0.5,
})

-- XWayland Settings
hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
})
hl.window_rule({
  name = "xwayland",
  match = { xwayland = true },
  no_blur = true,
  opaque = true,
})

-- XDG Desktop Portal GTK
hl.window_rule({
  name = "xdg-desktop-portal-gtk",
  match = { class = ".*xdg-desktop-portal-gtk.*" },
  float = true,
  center = true,
  pin = true,
  size = "800 600",
})

-- QT Settings
hl.window_rule({
  name = "qt-settings",
  match = { class = "(qt5ct|qt6ct|kvantummanager)" },
  float = true,
  center = true,
  size = "800 600",
})

-- Dialogs
hl.window_rule({
  name = "dialogs",
  match = {
    title = "(.*Open.*|.*Save.*|.*wants to save.*|.*to open.*|.*Export.*|.*Select.*|.*Find.*|.*VLSub.*|.*Confirm.*|.*Choose.*|.*Print.*)",
  },
  float = true,
  pin = true,
  center = true,
})

-- kitty
hl.window_rule({
  name = "kitty",
  match = { class = "kitty" },
  opacity = "0.9 0.9 1",
})

-- Spotify
hl.window_rule({
  name = "spotify",
  match = { class = "Spotify" },
  opacity = "0.9 0.9 1",
})

-- Matrix Lock
hl.window_rule({
  name = "matrix-lock",
  match = { title = "MATRIXLOCK" },
  stay_focused = true,
})

-- Thunderbird
hl.window_rule({
  name = "thunderbird",
  match = { class = "org.mozilla.Thunderbird" },
  opacity = "0.9 0.9 1",
})

hl.window_rule({
  name = "thunderbird-write",
  match = { title = ".*Write:.*" },
  float = true,
  center = true,
  size = "800 700",
})

-- Applications
local apps = {
  { name = "qBittorrent", class = "org.qbittorrent.qBittorrent", float = true, center = true },
  { name = "vlc", class = "vlc", no_blur = true, opaque = true },
  { name = "brasero", class = "brasero", float = true, center = true },
  { name = "rog-control-center", class = "rog-control-center", float = true, center = true, size = "950 600" },
  { name = "openrgb", class = "org.openrgb.OpenRGB", float = true, center = true, size = "950 600" },
  { name = "coolercontrol", class = "org.coolercontrol.CoolerControl", float = true, center = true, size = "1100 700" },
  { name = "timeshift", class = "timeshift-gtk", float = true, center = true },
  { name = "frame-checker", class = "Frame Checker", float = true, center = true },
  { name = "gpicview", class = "gpicview", float = true, center = true, size = "1000 600" },
  { name = "nwg-look", class = "nwg-look", float = true, center = true, size = "700 600" },
  { name = "pavucontrol", class = "org.pulseaudio.pavucontrol", float = true, center = true, size = "700 600" },
  { name = "blueman-manager", class = "blueman-manager", float = true, center = true, size = "700 600" },
  { name = "nm-connection-editor", class = "nm-connection-editor", float = true, center = true, size = "800 700" },
  { name = "virt-manager", class = "virt-manager", float = true, center = true, size = "800 700" },
  { name = "cameractrls", class = "hu.irl.cameractrls", float = true, center = true, size = "600 800" },
}

for _, app in ipairs(apps) do
  hl.window_rule({
    name = app.name,
    match = { class = app.class },
    float = app.float,
    center = app.center,
    size = app.size,
    no_blur = app.no_blur,
    opaque = app.opaque,
  })
end

-- Steam
hl.window_rule({
  name = "steam",
  match = { initial_class = "steam" },
  no_blur = true,
  opaque = true,
  center = true,
  idle_inhibit = "always",
})

hl.window_rule({
  name = "steam-other",
  match = { title = "Steam" },
  no_blur = true,
  opaque = true,
  center = true,
})

-- Bitwarden
hl.window_rule({
  name = "bitwarden",
  match = { initial_title = "_crx_.*" },
  float = true,
  pin = true,
  center = true,
  stay_focused = true,
  size = "400 600",
})
