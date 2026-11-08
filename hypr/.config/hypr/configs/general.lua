-- Border colors follow the theme, gaps are Quickshell's Settings (Windows); both written to
-- generated/theme.lua by ~/.local/bin/hyprdori-theme-set. Missing there: these.
local ok, theme = pcall(require, "configs.generated.theme")
if not ok then
  theme = { active_border = "rgb(fab387)", inactive_border = "rgba(7f849cee)" }
end

hl.config({
  general = {
    gaps_in = theme.gaps_in or 5,
    gaps_out = theme.gaps_out or 10,
    border_size = 2,
    col = {
      active_border = theme.active_border,
      inactive_border = theme.inactive_border,
    },
    resize_on_border = false,
    -- Only windows with an `immediate` rule tear (games, rules.lua): lower input latency
    allow_tearing = true,
    layout = "dwindle",
  },

  dwindle = {
    preserve_split = true,
    force_split = 2,
  },


  binds = {
    workspace_back_and_forth = false,
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false,
  },

  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_scale_notification = true,
    focus_on_activate = true,
    on_focus_under_fullscreen = 1,
    initial_workspace_tracking = 0,
    -- the shell's lock screen takes the lock over after a reload or a crash restart
    allow_session_lock_restore = true,
    -- Variable refresh rate is set per monitor in Displays (hyprdori-monitors); off elsewhere
    vrr = 0,
  },

  -- No switching to HDR for fullscreen HDR content (no HDR at all: the monitor rules have
  -- supports_hdr = -1, see hyprdori-monitors)
  render = {
    cm_auto_hdr = 0,
  },

  -- Hyprland
  debug = {
    disable_logs = false,
  },
})
