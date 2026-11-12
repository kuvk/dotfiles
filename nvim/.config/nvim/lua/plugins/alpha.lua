return {
  {
    "goolord/alpha-nvim",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[                                                                       ]],
        [[                                                                       ]],
        [[                                                                     ]],
        [[       ████ ██████           █████      ██                     ]],
        [[      ███████████             █████                             ]],
        [[      █████████ ███████████████████ ███   ███████████   ]],
        [[     █████████  ███    █████████████ █████ ██████████████   ]],
        [[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
        [[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
        [[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
        [[                                                                       ]],
        [[                                                                       ]],
        [[                                                                       ]],
      }
      dashboard.section.header.opts.hl = "AlphaHeader"

      local buttons = {
        dashboard.button("e", "  > New File", "<cmd>ene<CR>"),
        dashboard.button("C-n", "  > File Explorer", "<cmd>Neotree toggle<CR>"),
        dashboard.button("SPC ff", "󰱽  > Find File", "<cmd>Telescope find_files hidden=true<CR>"),
        dashboard.button("SPC fg", "  > Find Word", "<cmd>Telescope live_grep<CR>"),
        dashboard.button("SPC Sr", "  > Restore Session For Current Directory", "<cmd>AutoSession restore<CR>"),
        dashboard.button("SPC Sa", "  > Saved Sessions", "<cmd>AutoSession search<CR>"),
        dashboard.button("q", "󰿅  > Quit NVIM", "<cmd>qa<CR>"),
      }
      for _, button in ipairs(buttons) do
        button.opts.hl = "AlphaButtons"
        button.opts.hl_shortcut = "AlphaShortcut"
      end

      dashboard.section.buttons.val = buttons

      -- The logo (~/.config/theme/logo/dori-logo, every line as it is) under two empty rows
      local footer = { "", "" }
      local logo = io.open(vim.fn.expand("~/.config/theme/logo/dori-logo"))
      if logo then
        for line in logo:lines() do
          table.insert(footer, line)
        end
        logo:close()
      end
      dashboard.section.footer.val = footer
      dashboard.section.footer.opts.hl = "AlphaFooter"

      alpha.setup(dashboard.opts)
    end,
  },
}
