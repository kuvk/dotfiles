local function get_venv(variable)
  local venv = os.getenv(variable)
  if venv ~= nil and string.find(venv, "/") then
    local orig_venv = venv
    for w in orig_venv:gmatch("([^/]+)") do
      venv = w
    end
    venv = string.format("%s", venv)
  end
  return venv
end

local conditions = {
  buffer_not_empty = function()
    return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
  end,
  hide_in_width = function()
    return vim.fn.winwidth(0) > 80
  end,
}

-- Foreground of a highlight group only. Passing a group name to lualine
-- would also take its background and break the section's look.
local function fg(group)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl.fg and { fg = string.format("#%06x", hl.fg) } or nil
end

local function setup()
  require("lualine").setup({
    options = {
      icons_enabled = true,
      theme = "auto",
      component_separators = "",
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
      lualine_b = {
        {
          "filename",
          cond = conditions.hide_in_width,
        },
        "branch",
        {
          "diff",
          symbols = { added = " ", modified = " ", removed = " " },
          diff_color = {
            added = fg("GitSignsAdd") or fg("DiffAdd"),
            modified = fg("GitSignsChange") or fg("DiffChange"),
            removed = fg("GitSignsDelete") or fg("DiffDelete"),
          },
        },
      },
      lualine_c = {
        "%=",
        {
          function()
            local msg = "No Active Lsp"
            local buf_ft = vim.api.nvim_buf_get_option(0, "filetype")
            local clients = vim.lsp.get_clients()
            if next(clients) == nil then
              return msg
            end
            for _, client in ipairs(clients) do
              local filetypes = client.config.filetypes
              if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
                return client.name
              end
            end
            return msg
          end,
          icon = " LSP:",
          color = fg("DiagnosticHint"),
          cond = conditions.hide_in_width,
        },
      },
      lualine_x = {},
      lualine_y = {
        {
          "diagnostics",
          symbols = {
            error = " ",
            warn = " ",
            info = " ",
            hint = "󰌵 ",
          },
          cond = conditions.hide_in_width,
        },
        {
          "filetype",
        },
        {
          "progress",
        },
        -- Virtual environment
        function()
          local venv = get_venv("CONDA_DEFAULT_ENV") or get_venv("VIRTUAL_ENV")
          if venv then
            return " " .. venv
          end
          return ""
        end,
      },
      lualine_z = {
        { "location", separator = { right = "" }, left_padding = 2 },
      },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {},
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    tabline = {},
    extensions = {},
  })
end

return {
  "nvim-lualine/lualine.nvim",
  config = function()
    setup()
    -- Colors come from the colorscheme, so rebuild when the theme changes
    vim.api.nvim_create_autocmd("ColorScheme", { callback = setup })
  end,
}
