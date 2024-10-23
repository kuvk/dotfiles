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

      dashboard.section.buttons.val = {
        dashboard.button("e", "  > New File", "<cmd>ene<CR>"),
        dashboard.button("C-n", "  > File Explorer", "<cmd>Neotree toggle<CR>"),
        dashboard.button("SPC ff", "󰱽  > Find File", "<cmd>Telescope find_files hidden=true<CR>"),
        dashboard.button("SPC fg", "  > Find Word", "<cmd>Telescope live_grep<CR>"),
        dashboard.button("SPC wr", "  > Restore Session For Current Directory", "<cmd>SessionRestore<CR>"),
        dashboard.button("SPC wa", "  > Saved Sessions", "<cmd>Autosession search<CR>"),
        dashboard.button("q", "󰿅  > Quit NVIM", "<cmd>qa<CR>"),
      }

      dashboard.section.footer.val = {
        [[                     .]],
        [[                    / V\]],
        [[       KUVK       / `  /]],
        [[                 <<   |]],
        [[                 /    |]],
        [[               /      |]],
        [[             /        |]],
        [[           /    \  \ /]],
        [[          (      ) | |]],
        [[  ________|   _/_  | |]],
        [[<__________\______)\__)]],
      }

      alpha.setup(dashboard.opts)
    end,
  },
}
