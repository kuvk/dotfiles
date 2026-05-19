hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
    border_size = 2,
    col = {
      active_border = "rgba(fab387ee)",
      inactive_border = "rgba(89b4faaa)",
    },
    allow_tearing = false,
    layout = "dwindle",
  },

  dwindle = {
    preserve_split = true,
  },

  binds = {
    workspace_back_and_forth = false,
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false,
  },

  misc = {
    force_default_wallpaper = 0,
    session_lock_xray = true,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    initial_workspace_tracking = 1,
    allow_session_lock_restore = true,
  },
})
