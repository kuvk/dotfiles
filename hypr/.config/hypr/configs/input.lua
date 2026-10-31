-- Input and Cursor configuration
hl.config({
  input = {
    kb_layout = "us,hr",
    kb_variant = "",
    kb_model = "",
    kb_options = "ctrl:nocaps,grp:win_space_toggle",
    kb_rules = "",
    numlock_by_default = true,
    follow_mouse = 1,
    sensitivity = 0,

    touchpad = {
      disable_while_typing = true,
      natural_scroll = false,
      scroll_factor = 0.2,
      tap_and_drag = true,
      clickfinger_behavior = true,
      tap_to_click = true,
    },
  },
  gestures = {
    workspace_swipe_forever = false,
  },
  cursor = {
    no_hardware_cursors = 1,
    -- XCursor themes only: otherwise Hyprland starts with the first hyprcursor theme it
    -- finds, as Adwaita isn't one, until autostart sets the cursor
    enable_hyprcursor = false,
  },
})

-- Specific Gesture binding
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})

-- Per-device configuration
hl.device({
  name = "asustek-rog-keris-wireless-aimpoint",
  sensitivity = -0.8,
  accel_profile = "adaptive",
})
