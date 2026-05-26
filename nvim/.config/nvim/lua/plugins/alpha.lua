return {
  {
    "goolord/alpha-nvim",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[                                                                       ]],
        [[                                                                       ]],
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
        dashboard.button("SPC wr", "  > Restore Session For Current Directory", "<cmd>AutoSession restore<CR>"),
        dashboard.button("SPC wa", "  > Saved Sessions", "<cmd>AutoSession search<CR>"),
        dashboard.button("q", "󰿅  > Quit NVIM", "<cmd>qa<CR>"),
      }
      for _, button in ipairs(buttons) do
        button.opts.hl = "AlphaButtons"
        button.opts.hl_shortcut = "AlphaShortcut"
      end

      dashboard.section.buttons.val = buttons

      dashboard.section.footer.val = {
        [[]],
        [[]],
        [[                     .		  	]],
        [[                    / V\	  	]],
        [[       DORI       / `  /	  	]],
        [[                 <<   |		  	]],
        [[                 /    |		  	]],
        [[               /      |		  	]],
        [[             /        |		  	]],
        [[           /    \  \ /		  	]],
        [[          (      ) | |		  	]],
        [[  ________|   _/_  | |		  	]],
        [[<__________\______)\__)		  	]],
      }
      dashboard.section.footer.opts.hl = "AlphaFooter"

      alpha.setup(dashboard.opts)
    end,
  },
}
