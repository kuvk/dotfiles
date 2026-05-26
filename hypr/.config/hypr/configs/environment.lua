-- Environment Variables
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME","nvidia")
-- hl.env("GBM_BACKEND", "nvidia-drm")
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")
-- hl.env("NVD_BACKEND", "direct")

hl.env("GDK_BACKEND", "wayland,x11,*")

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")

hl.env("QT_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT6CT_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

hl.env("GTK_THEME", "Catppuccin")
hl.env("XCURSOR_THEME", "Colloid-dark-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Colloid-dark-cursors")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("OZONE_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("CLUTTER_BACKEND", "wayland")

hl.env("XDG_CONFIG_HOME", os.getenv("HOME") .. "/.config")
hl.env("XDG_CACHE_HOME", os.getenv("HOME") .. "/.cache")
hl.env("XDG_DATA_HOME", os.getenv("HOME") .. "/.local/share")
hl.env("ZDOTDIR", os.getenv("HOME") .. "/.config/zsh")
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")
hl.env("SYSTEMD_EDITOR", "nvim")
hl.env("TERMINAL", "kitty")
hl.env("BAT_THEME", "Catppuccin Mocha")
