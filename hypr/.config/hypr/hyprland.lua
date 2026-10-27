-- Monitors (written by ~/.config/scripts/hypr-monitors.py; missing on a fresh install)
if not pcall(require, "configs.generated.monitors") then
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
end

-- Input
require("configs.input")

-- Environment and autostart
require("configs.environment")
require("configs.autostart")

-- Configuration
require("configs.general")
require("configs.decoration")
require("configs.animations")
require("configs.rules")
require("configs.bindings")
