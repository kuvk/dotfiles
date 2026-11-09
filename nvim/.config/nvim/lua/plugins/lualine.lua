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

-- The buffer's language server, and how many more: "󰒍 pyright +1". Nothing without one.
local function lsp_status()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client.name ~= "null-ls" then
      table.insert(names, client.name)
    end
  end
  if #names == 0 then
    return ""
  end
  return "\u{f048d} " .. names[1] .. (#names > 1 and " +" .. (#names - 1) or "")
end

-- The macro being recorded; there's no command line row to show it in
local function recording_status()
  local register = vim.fn.reg_recording()
  return register ~= "" and "recording @" .. register or ""
end

-- Foreground of a highlight group only. Passing a group name to lualine
-- would also take its background and break the section's look.
local function fg(group)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl.fg and { fg = string.format("#%06x", hl.fg) } or nil
end

-- Mode colors from the system theme, the same in yazi and starship's prompt: normal in the
-- accent, insert green, visual magenta, command yellow. The middle has no background of
-- its own.
local function mode_theme()
  local theme = require("theme")
  local p = theme.palette
  if not p.bg then
    return "auto"
  end
  local function mode(color)
    return {
      a = { fg = p.bg, bg = color, gui = "bold" },
      b = { fg = color, bg = p.lighter_bg },
      c = { fg = p.fg, bg = "NONE" },
    }
  end
  return {
    normal = mode(p.accent),
    insert = mode(p.green),
    visual = mode(p.magenta),
    command = mode(p.yellow),
    replace = mode(p.red),
    terminal = mode(p.green),
    inactive = {
      a = { fg = p.dark_fg, bg = "NONE" },
      b = { fg = p.dark_fg, bg = "NONE" },
      c = { fg = p.dark_fg, bg = "NONE" },
    },
  }
end

local function setup()
  local square = require("theme").square()
  local left = square and "" or "\u{e0b6}"
  local right = square and "" or "\u{e0b4}"
  require("lualine").setup({
    options = {
      icons_enabled = true,
      theme = mode_theme(),
      component_separators = "",
      section_separators = { left = right, right = left },
      -- one status line for every window (laststatus 3), set once rather than per window, so
      -- new windows (the file tree, a buffer) never show it empty until lualine's next refresh
      globalstatus = true,
    },
    sections = {
      lualine_a = { { "mode", separator = { left = left }, right_padding = 2 } },
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
      lualine_c = {},
      lualine_x = {
        {
          recording_status,
          color = fg("DiagnosticWarn"),
        },
        {
          lsp_status,
          color = fg("DiagnosticHint"),
          cond = conditions.hide_in_width,
        },
      },
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
        { "location", separator = { right = right }, left_padding = 2 },
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
    -- lualine writes its line into each window; a new window (the file tree) or a new buffer
    -- would show the empty global one until lualine's next refresh, so the global one follows
    -- the latest line
    local nvim_opts = require("lualine.utils.nvim_opts")
    local set = nvim_opts.set
    nvim_opts.set = function(name, value, opts)
      set(name, value, opts)
      if name == "statusline" and opts and opts.window and type(value) == "string" and value ~= "" then
        vim.go.statusline = value
      end
    end
    setup()
    vim.o.laststatus = 3
    -- Colors come from the colorscheme, so rebuild when the theme changes
    vim.api.nvim_create_autocmd("ColorScheme", { callback = setup })
    vim.api.nvim_create_autocmd("User", { pattern = "ThemeShape", callback = setup })
    vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
      callback = function()
        vim.schedule(function()
          require("lualine").refresh({ place = { "statusline" } })
        end)
      end,
    })
  end,
}
