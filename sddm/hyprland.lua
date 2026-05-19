-- Environment Variables
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("XCURSOR_THEME", "Colloid-dark-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Colloid-dark-cursors")
hl.env("HYPRCURSOR_SIZE", "24")

-- Global Configuration Categories
hl.config({
  ecosystem = {
    enforce_permissions = false,
    no_update_news = true,
    no_donation_nag = true,
  },
  misc = {
    disable_watchdog_warning = true,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    initial_workspace_tracking = 1,
  },
  input = {
    kb_layout = "us,hr",
    kb_options = "ctrl:nocaps,grp:win_space_toggle",
    numlock_by_default = true,
    follow_mouse = 1,
    sensitivity = 0,
    accel_profile = "adaptive",
    touchpad = {
      disable_while_typing = true,
      natural_scroll = false,
      scroll_factor = 0.4,
      tap_and_drag = true,
      clickfinger_behavior = true,
      tap_to_click = true,
    },
  },
  cursor = {
    no_hardware_cursors = true,
  },
})

-- Monitor Configuration
hl.monitor({
  output = "", -- empty string for all/default
  mode = "highrr",
  position = "auto",
  scale = "1.3333",
})

-- Window Rules
hl.window_rule({
  name = "sddm-fix",
  match = { class = "^(sddm-greeter)$" },
  workspace = "emptym",
  fullscreen = true,
  stay_focused = true,
  decorate = false,
  no_anim = true,
  border_size = 0,
  no_dim = true,
  rounding = 0,
  no_shadow = true,
})
