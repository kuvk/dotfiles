-- No cursor until the desktop is up, after Omarchy's default/hypr/startup-cursor.lua:
-- Hyprland's first frames come before the cursor theme and the monitors' scales are set.
-- At a cold start it gets a blank cursor theme (../cursors/kuvk-startup, one transparent
-- pixel, so nothing shows before the pointer is hidden) and a hidden pointer. The shell
-- reveals it once it is up (shell.qml calls kuvk_cursor_reveal), or after 15 s.
--
-- Lua globals don't survive a config reload, so whether the cursor is still hidden is kept
-- in the compositor's environment (KUVK_CURSOR_PENDING), and this file sets the reveal up
-- again on every load. Runs after environment.lua, which sets XCURSOR_THEME and XCURSOR_SIZE.

local home = os.getenv("HOME")
local blank_dir = home .. "/.config/hypr/cursors"

-- XCURSOR_PATH without the blank theme's folder
local function real_path()
  local kept = {}
  local path = os.getenv("XCURSOR_PATH") or (home .. "/.local/share/icons:" .. home .. "/.icons:/usr/share/icons:/usr/share/pixmaps")
  for entry in path:gmatch("[^:]+") do
    if entry ~= blank_dir then
      table.insert(kept, entry)
    end
  end
  return table.concat(kept, ":")
end

local function real_theme()
  local theme = os.getenv("KUVK_CURSOR_THEME") or ""
  return theme ~= "" and theme or "Adwaita"
end

-- Apps started from here on get the real cursor
local function restore_env()
  hl.env("XCURSOR_PATH", real_path())
  hl.env("XCURSOR_THEME", real_theme())
end

function kuvk_cursor_reveal()
  if os.getenv("KUVK_CURSOR_PENDING") ~= "1" then
    return
  end
  hl.env("KUVK_CURSOR_PENDING", "")
  restore_env()
  local size = os.getenv("XCURSOR_SIZE") or "24"
  -- xsetroot: XWayland's default arrow, for X11 apps without cursors of their own (Parsec).
  -- Hyprland gives it the blank theme's when XWayland starts, and setcursor doesn't change it.
  hl.exec_cmd("hyprctl setcursor '" .. real_theme() .. "' " .. size
    .. "; xsetroot -cursor_name left_ptr >/dev/null 2>&1"
    .. "; hyprctl eval 'hl.config({ cursor = { invisible = false } })'")
end

-- A cold start: no monitors yet (a reload always has some)
if #hl.get_monitors() == 0 and os.getenv("KUVK_CURSOR_PENDING") ~= "1" then
  hl.env("KUVK_CURSOR_PENDING", "1")
  hl.env("KUVK_CURSOR_THEME", os.getenv("XCURSOR_THEME") or "Adwaita")
  hl.env("XCURSOR_PATH", blank_dir .. ":" .. real_path())
  hl.env("XCURSOR_THEME", "kuvk-startup")

  -- before autostart.lua's handler starts anything
  hl.on("hyprland.start", restore_env)
end

if os.getenv("KUVK_CURSOR_PENDING") == "1" then
  -- a reload while hidden resets this, and drops the timer
  hl.config({ cursor = { invisible = true } })
  hl.timer(kuvk_cursor_reveal, { timeout = 15000, type = "oneshot" })
end
