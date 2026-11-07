-- Monitors (written by ~/.config/scripts/hypr-monitors.py; missing on a fresh install)
if not pcall(require, "configs.generated.monitors") then
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
end

-- Input
require("configs.input")

-- Environment and autostart
require("configs.environment")
-- No cursor until the shell is up (a cold start only)
require("configs.startup-cursor")
require("configs.autostart")

-- Configuration
require("configs.general")
require("configs.decoration")
require("configs.animations")
require("configs.rules")

-- Single window (SUPER+SHIFT+S, ~/.config/scripts/hypr-single-window.sh): on while the flag exists
local single = io.open(os.getenv("HOME") .. "/.local/state/kuvk-shell/single-window")
if single then
  single:close()
  require("configs.single-window")
end
require("configs.bindings")
