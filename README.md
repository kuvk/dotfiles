# Dotfiles

Arch Linux with Hyprland (Lua config), a Quickshell desktop shell and one theme for everything.
Each top-level folder is a [GNU Stow](https://www.gnu.org/software/stow/) package:

```sh
cd ~/dotfiles
stow hypr quickshell theme scripts fontconfig kitty tmux zsh nvim yazi   # or any you want
~/.config/scripts/theme-set.py catppuccin-mocha
```

| Package | What it has |
|---|---|
| `hypr` | Hyprland config in Lua, hypridle, Work-Game, window rules. `ALT+SHIFT+/` lists every key |
| `quickshell` | Bar, notifications, launchers, clipboard history, panels, settings. See [its README](quickshell/.config/quickshell/README.md) |
| `theme` | One palette rendered into every app, with live reloads. See [its README](theme/.config/theme/README.md) |
| `scripts` | `theme-set.py`, `wallpaper.py`, `hypr-monitors.py`, `lockscreen.sh`, `webapp.py`, `network.py`, `sysmaintenance.sh` and others |
| `sddm` | Login screen: your wallpaper, fonts, cursor and monitor scales. Not stowed; install with `sudo sddm/install.sh` |
| `fontconfig` | Font folders; rendering comes from Settings > Fonts |
| `kitty`, `tmux`, `zsh` | Terminal, multiplexer and shell (below) |
| `nvim`, `lazygit`, `yazi`, `bat`, `btop`, `cava`, `fastfetch`, `starship`, `swayimg`, `spotify`, `cliamp` | App configs; those with colors follow the theme |

## Terminal keys

- **Panes:** `Ctrl+H/J/K/L` moves across tmux panes and Neovim splits. The tmux prefix is `Ctrl+S`.
- **Clipboard:** `y` copies and `p`/`P` paste the system clipboard in zsh, Neovim and tmux copy mode
  (tmux pastes with prefix `P`). `Ctrl+Shift+V` pastes anywhere.
- **Neovim:** `x`, `c` and `s` leave the clipboard alone, and `<leader>d` deletes without copying.
- **zsh:** vi mode, with history in `~/.local/state/zsh/history`. Prompt and tool init output is
  cached in `~/.cache/zsh`.
- **herdr:** runs beside tmux with the same prefix and follows the theme.
