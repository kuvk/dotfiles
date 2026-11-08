return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    -- Icons like yazi's and eza's (icons.toml through lua/theme.lua): folders by name in accent;
    -- files from nvim-web-devicons, yazi's generic icon for the rest. Links ([link], cyan):
    -- a linked folder; a broken link; a working link to a file its file's icon, or the
    -- generic one in cyan when it has none
    local function icon_provider(icon, node)
      local icons = require("theme").icons or {}
      if node.is_link and node.type == "directory" then
        icon.text = icons.link_dir or icon.text
        icon.highlight = "NeoTreeLinkIcon"
      elseif node.type == "link" then -- broken: neo-tree keeps the type "link"
        icon.text = icons.link_broken or icon.text
        icon.highlight = "NeoTreeLinkIcon"
      elseif node.is_link then
        local ok, devicons = pcall(require, "nvim-web-devicons")
        local devicon, hl
        if ok then
          devicon, hl = devicons.get_icon(node.name, nil, { default = false })
        end
        icon.text = devicon or icons.link_file or icon.text
        icon.highlight = devicon and hl or "NeoTreeLinkIcon"
      elseif node.type == "directory" then
        icon.text = (icons.dirs or {})[node.name] or icon.text
      elseif node.type == "file" or node.type == "terminal" then
        local ok, devicons = pcall(require, "nvim-web-devicons")
        if ok then
          local devicon, hl = devicons.get_icon(node.type == "terminal" and "terminal" or node.name)
          icon.text = devicon or icon.text
          icon.highlight = hl or icon.highlight
        end
      end
      return icon
    end

    -- Link names in cyan, like yazi and eza
    local common = require("neo-tree.sources.common.components")
    local function name(config, node, state)
      local result = common.name(config, node, state)
      if node.is_link and type(result) == "table" and result.text then
        result.highlight = "NeoTreeLinkName"
      end
      return result
    end
    -- Broken links: the target in red
    local function symlink_target(config, node, state)
      local result = common.symlink_target(config, node, state)
      if node.is_link and type(result) == "table" and result.text and not vim.uv.fs_stat(node.path) then
        result.highlight = "NeoTreeBrokenLinkTarget"
      end
      return result
    end

    require("neo-tree").setup({
      close_if_last_window = true,
      popup_border_style = "", -- follows winborder
      default_component_configs = {
        diagnostics = {
          symbols = {
            hint = "󰌵 ",
            warn = " ",
            info = " ",
            error = " ",
          },
          highlights = {
            hint = "DiagnosticSignHint",
            info = "DiagnosticSignInfo",
            warn = "DiagnosticSignWarn",
            error = "DiagnosticSignError",
          },
        },
        git_status = {
          symbols = {
            -- Change type
            added = "", -- nf-fa-plus
            deleted = "",
            modified = "", -- nf-oct-dot_fill
            renamed = "",
            -- Status type
            untracked = "",
            ignored = "",
            unstaged = "",
            staged = "",
            conflict = "",
          },
          align = "right",
        },
        icon = {
          folder_closed = "\u{e5ff}", -- yazi's folder icons
          folder_open = "\u{e5fe}",
          default = "\u{f15b}", -- yazi's for files without their own
          provider = icon_provider,
        },
        -- " → target" after a link's name
        symlink_target = { enabled = true, text_format = " → %s" },
        indent = {
          with_markers = false,
          with_expanders = true,
          expander_collapsed = "",
          expander_expanded = "",
        },
      },
      window = {
        position = "left",
        auto_expand_width = false,
        width = 30,
      },
      filesystem = {
        components = { name = name, symlink_target = symlink_target },
        -- Broken links stay of type "link", which has no layout of its own: show them like files
        renderers = {
          link = {
            { "indent" },
            { "icon" },
            { "name", use_git_status_colors = false },
            { "symlink_target" },
          },
        },
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          always_show = { -- remains visible even if other settings would normally hide it
            ".gitignored",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            ".DS_Store",
            "thumbs.db",
          },
        },
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
      },
    })
  end,
}
