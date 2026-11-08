-- Colorschemes of the system themes: each theme's neovim.lua (~/.config/theme/themes/*/) names
-- its plugin, which is installed here and loaded on :colorscheme. catppuccin is set up in
-- catppuccin.lua; aether draws themes without a colorscheme of their own (lua/theme.lua).
local specs, seen = {}, {}
for _, file in ipairs(vim.fn.glob(vim.fn.expand("~/.config/theme/themes/*/neovim.lua"), false, true)) do
  local ok, theme = pcall(dofile, file)
  for _, spec in ipairs(ok and type(theme) == "table" and theme or {}) do
    local repo = spec[1]
    if type(repo) == "string" and repo ~= "LazyVim/LazyVim" and repo ~= "catppuccin/nvim" and not seen[repo] then
      seen[repo] = true
      local plugin = vim.deepcopy(spec)
      -- loaded when a theme asks for it, not at startup
      plugin.lazy, plugin.priority = true, nil
      -- one aether for every theme that builds on it
      for i, dep in ipairs(type(plugin.dependencies) == "table" and plugin.dependencies or {}) do
        if type(dep) == "string" and dep:match("/aether%.nvim$") then
          plugin.dependencies[i] = "omacom/aether.nvim"
        end
      end
      table.insert(specs, plugin)
    end
  end
end
table.insert(specs, { "omacom/aether.nvim", branch = "v3", name = "aether", lazy = true })
return specs
