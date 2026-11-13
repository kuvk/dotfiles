-- Layer Rules
hl.layer_rule({
  match = { class = "^(quickshell-.*)$" },
  blur = true,
  ignore_alpha = 0.2,
})

-- Quickshell animates its dropdowns and tooltips itself
hl.layer_rule({
  match = {
    class = "^(quickshell-dropdown|quickshell-tooltip|quickshell-transition|quickshell-controlcenter|quickshell-appmenu)$",
  },
  no_anim = true,
})

-- Ignore maximize requests (as in Hyprland's example config): apps that
-- restore a saved maximized state (LibreOffice opening a document) would
-- otherwise cover the workspace until they're resized. SUPER+F still works.
hl.window_rule({
  name = "no-maximize",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- XWayland Settings
hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
})
-- XWayland windows: opaque, no blur
hl.window_rule({
  name = "xwayland",
  match = { xwayland = true },
  no_blur = true,
  opaque = true,
})

-- The shell's windows (Settings, Keybindings) draw their own transparency
-- (Settings > Style > Shell opacity): Hyprland's window opacity is overridden to full
hl.window_rule({
  name = "quickshell-opaque",
  match = { class = "^org\\.quickshell$" },
  opacity = "1.0 override 1.0 override",
})

-- Browsers opaque: pages and video behind a see-through window don't read well
hl.window_rule({
  name = "browsers-opaque",
  match = { class = "^(brave-browser|chromium|google-chrome|firefox|zen|librewolf|vivaldi-stable|brave-.*|chrome-.*)$" },
  opacity = "1.0 override 1.0 override",
})

-- Quickshell's Settings and Keybindings: floating and centered (the shell reopens one that gets tiled)
hl.window_rule({
  name = "quickshell-windows",
  match = { class = "^org\\.quickshell$", title = "^(Settings|Keybindings)$" },
  float = true,
  center = true,
})

-- System Information (hyprdori-sysinfo): fastfetch in kitty, at the size kitty opens with
hl.window_rule({
  name = "sysinfo",
  match = { class = "^hyprdori-sysinfo$" },
  float = true,
  center = true,
})

-- System monitor (hyprdori-sysmon): btop in kitty, one at a time
hl.window_rule({
  name = "sysmon",
  match = { class = "^hyprdori-sysmon$" },
  float = true,
  center = true,
  size = "1200 760",
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

-- hyprdori-present windows: the boot screens' and the system's updates (hyprdori-theme-boot
-- --window, hyprdori-update --window)
hl.window_rule({
  name = "hyprdori-window",
  match = { class = "^(hyprdori-window)$" },
  float = true,
  center = true,
  size = "900 600",
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
-- hl.window_rule({
--   name = "kitty",
--   match = { class = "kitty" },
--   opacity = "0.9 0.9 1",
-- })

-- Thunderbird
hl.window_rule({
  name = "thunderbird",
  match = { class = "org.mozilla.Thunderbird" },
  opaque = true,
})
hl.window_rule({
  name = "thunderbird-write",
  match = { title = ".*Write:.*" },
  float = true,
  center = true,
  size = "800 700",
})

-- Bitwarden
hl.window_rule({
  name = "bitwarden",
  match = { initial_title = "_crx_.*" },
  float = true,
  center = true,
  min_size = { 370, 565 },
  max_size = { 370, 565 },
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
  { name = "cliamp", class = "cliamp", float = true, center = true, size = "900 600" },
  { name = "localsend", class = "org.localsend.localsend_app", float = true, center = true, size = "900 450" },
  { name = "nwg-look", class = "nwg-look", float = true, center = true, size = "700 600" },
  { name = "pavucontrol", class = "org.pulseaudio.pavucontrol", float = true, center = true, size = "700 600" },
  { name = "blueman-manager", class = "blueman-manager", float = true, center = true, size = "700 600" },
  { name = "nm-connection-editor", class = "nm-connection-editor", float = true, center = true, size = "800 700" },
  { name = "nvidia-settings", class = "nvidia-settings", float = true, center = true, size = "800 700" },
  { name = "virt-manager", class = "virt-manager", float = true, center = true, size = "800 700" },
  { name = "cameractrls", class = "hu.irl.cameractrls", float = true, center = true, size = "600 800" },
  { name = "lutris", class = "net.lutris.Lutris", no_blur = true, opaque = true, center = true },
  { name = "heroic", class = ".*heroic.*", no_blur = true, opaque = true, center = true },
  { name = "steam", class = "steam", no_blur = true, opaque = true, float = true },
  -- Only windows with a title: Steam's menus are untitled windows of the same class
  { name = "steam-center", class = "steam", title = ".+", center = true },
  { name = "games", class = "steam_app.*", idle_inhibit = "always" },
  { name = "protonqt", class = "net.davidotek.pupgui2", float = true, center = true, size = "700 600" },
  { name = "zathura", class = "org.pwmt.zathura", float = true, center = true, size = "1100 1200" },
  { name = "swayimg", class = "^swayimg$", float = true, center = true, size = "1400 900" },
  { name = "gimp", class = "gimp", center = true, opaque = true, no_blur = true },
  {
    name = "remmina",
    class = "org.remmina.Remmina",
    title = "^Remmina Remote Desktop Client$",
    float = true,
    center = true,
    opaque = true,
    no_blur = true,
  },
  { name = "remmina-sessions", class = "org.remmina.Remmina", no_blur = true, opaque = true },
  { name = "davinci", class = "resolve", no_blur = true, opaque = true },
  { name = "netflix", class = "(brave|chrome)-netflix.*", no_blur = true, opaque = true },
  { name = "eontv", class = "(brave|chrome)-eon.*", no_blur = true, opaque = true },
  {
    name = "whatsapp",
    class = "^(brave|chrome)-web\\.whatsapp\\.com__.*",
    float = true,
    center = true,
    size = "1100 700",
  },
}

for _, app in ipairs(apps) do
  hl.window_rule({
    name = app.name,
    match = { class = app.class, title = app.title },
    float = app.float,
    center = app.center,
    size = app.size,
    no_blur = app.no_blur,
    opaque = app.opaque,
    idle_inhibit = app.idle_inhibit,
  })
end

-- Games skip vsync for lower input latency (general.allow_tearing)
hl.window_rule({
  name = "games-tearing",
  match = { class = "^(steam_app_.*|gamescope)$" },
  immediate = true,
})

-- Steam
hl.window_rule({
  name = "steam-main",
  match = { title = "Steam" },
  float = false,
  center = true,
})

-- Ubisoft Connect
hl.window_rule({
  name = "ubisoft-connect",
  match = { title = "Ubisoft Connect" },
  float = true,
  center = true,
})

-- Rockstar
hl.window_rule({
  name = "rockstar",
  match = { title = "Rockstar Games.*" },
  float = true,
  center = true,
})
