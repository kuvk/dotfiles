-- Border colors follow the theme (written by ~/.config/scripts/theme-set.py)
local ok, theme = pcall(require, "configs.generated.theme")
if not ok then
  theme = { active_border = "rgb(fab387)", inactive_border = "rgba(89b4faaa)" }
end

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
    border_size = 2,
    col = {
      active_border = theme.active_border,
      inactive_border = theme.inactive_border,
    },
    -- Only windows with an `immediate` rule tear (games, rules.lua): lower input latency
    allow_tearing = true,
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
    -- Variable refresh rate is set per monitor in Displays (hypr-monitors.py); off elsewhere
    vrr = 0,
  },
})
