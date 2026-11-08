-- Environment Variables

-- The boot display's GPU (the one driving the built-in screen, or the only one), found at each
-- start: card numbers can swap between boots. aquamarine renders on it by itself, so
-- AQ_DRM_DEVICES isn't set: forcing the order makes modesets on the other GPU's outputs fail.
local boot_gpu = nil
for i = 0, 15 do
  local boot_file = io.open("/sys/class/drm/card" .. i .. "/device/boot_vga")
  if boot_file then
    local is_boot = boot_file:read("l") == "1"
    boot_file:close()
    local vendor_file = is_boot and io.open("/sys/class/drm/card" .. i .. "/device/vendor")
    if vendor_file then
      boot_gpu = { vendor = vendor_file:read("l") }
      vendor_file:close()
      break
    end
  end
end

-- NVIDIA rendering the desktop (the desktop PC): video decoding and GLX through its driver.
-- On the laptop Intel renders, and apps go to NVIDIA only when asked (prime-run).
if boot_gpu and boot_gpu.vendor == "0x10de" then
  hl.env("LIBVA_DRIVER_NAME", "nvidia")
  hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end

hl.env("GDK_BACKEND", "wayland,x11,*")

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")

hl.env("QT_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- Chosen in Settings > Appearance (theme-set.py writes it)
local has_theme, theme = pcall(require, "configs.generated.theme")
hl.env("XCURSOR_THEME", has_theme and theme.cursor_theme or "Adwaita")
hl.env("XCURSOR_SIZE", has_theme and theme.cursor_size or "24")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland,x11")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("CLUTTER_BACKEND", "wayland")

-- ~/.local/bin first, for apps started from the shell and keybindings too (the dotfiles'
-- bin/ wrappers, like btop's); once, though the config runs again on every reload
local local_bin = os.getenv("HOME") .. "/.local/bin"
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not (":" .. path .. ":"):find(":" .. local_bin .. ":", 1, true) then
  hl.env("PATH", local_bin .. ":" .. path)
end

hl.env("XDG_CONFIG_HOME", os.getenv("HOME") .. "/.config")
hl.env("XDG_CACHE_HOME", os.getenv("HOME") .. "/.cache")
hl.env("XDG_DATA_HOME", os.getenv("HOME") .. "/.local/share")
hl.env("ZDOTDIR", os.getenv("HOME") .. "/.config/zsh")
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")
hl.env("SYSTEMD_EDITOR", "nvim")
hl.env("TERMINAL", "kitty")
hl.env("LG_CONFIG_FILE", os.getenv("HOME") .. "/.config/lazygit/config.yml," .. os.getenv("HOME") .. "/.config/theme/current/lazygit.yml")
