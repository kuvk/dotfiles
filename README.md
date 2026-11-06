# Dotfiles

Arch Linux with Hyprland (Lua config), a Quickshell desktop shell and one theme for everything.

## Install

On a fresh Arch install, after the first boot, as yourself with the network up:

```sh
git clone https://github.com/kuvk/dotfiles ~/dotfiles && ~/dotfiles/install.sh
```

The clone can live anywhere (`~/.src/dotfiles`, say): the scripts find the repo through their own links.

It expects the ESP at `/efi` and, for encrypted drives, the systemd initramfs (`systemd` and
`sd-encrypt` hooks, `rd.luks.name=` in the kernel options). It sets up pacman (multilib, the g14 repo
on ASUS laptops), mirrors with a weekly reflector timer, links the dotfiles (files in the way go to
`~/.dotfiles-backup`), installs the package lists for the detected hardware, enables the services,
switches to zsh with its plugins, applies the theme and installs the login screen, boot splash and
boot menu. Run it again any time: it skips what's done.

## Pick and choose

Each top-level folder is a [GNU Stow](https://www.gnu.org/software/stow/) package:

```sh
cd ~/dotfiles   # or wherever you cloned it
stow hypr quickshell theme scripts fontconfig kitty tmux zsh nvim yazi   # or any you want
~/.config/scripts/theme-set.py catppuccin-mocha
```

Install the programs you stow (the lists in `packages/`). `theme-set.py` renders every app's colors even
for apps you don't have (it only creates their config folders), and tmux and cliamp are skipped until
their folders exist. `bat`, `btop`, `cava`, `lazygit`, `starship` and `fastfetch` are separate packages;
stow them too for their themes to be picked up. `hypr`, `quickshell`, `theme` and `scripts` belong
together: the shell, the lock screen and the theme switcher call each other.

| Package | What it has |
|---|---|
| `hypr` | Hyprland config in Lua, Work-Game, window rules. `SUPER+/` lists every key |
| `quickshell` | Bar, notifications, launchers, clipboard history, panels, settings. See [its README](quickshell/.config/quickshell/README.md) |
| `theme` | One palette rendered into every app, with live reloads. See [its README](theme/.config/theme/README.md) |
| `scripts` | `theme-set.py`, `wallpaper.py`, `logo-wallpaper.py` (wallpapers with the logo), `logo-render.py` (draws the logo like kitty does), `theme-boot.sh` (boot splash and menu in the current theme), `hypr-monitors.py`, `shell.sh` (starts the shell, again after a crash), `webapp.py`, `network.py`, `update.sh` (updates everything), `sysmaintenance.sh` (cleans up) and others |
| `sddm` | Login screen (`kuvk/`, the QML theme), laid out like the lock screen: your wallpaper, fonts, cursor, monitor scales and Lock Screen settings. `hyprland.lua` is the greeter's own Hyprland config (it sets your cursor and monitor layout) and `sddm.conf` points SDDM at it. Not stowed; install with `sudo sddm/install.sh` |
| `plymouth` | Boot splash: the logo (`theme/logo/ascii-dori`), a password field for the encrypted drives and a progress bar. Not stowed; install with `sudo plymouth/install.sh`, which uses the current theme's colors (`--preview FILE` to see it first). After a theme change, the **Update** notification or `theme-boot.sh` reinstalls it and the boot menu |
| `limine` | Boot menu: the logo above an Omarchy-style tree of kernels, in the theme's colors. Not stowed; install with `sudo limine/install.sh`, which uses the current theme's colors; `theme-boot.sh` reruns it after a theme change (`--resolution WxH`, `--print` for the config, `--preview FILE` for the wallpaper) |
| `packages` | Package lists for `install.sh`: `core.txt` (needed), `apps.txt` (apps with window rules), `vm.txt` (virtual machines and Docker), `flatpak.txt`, `nvidia.txt`, `intel.txt`, `laptop.txt` (ASUS ROG, g14 repo), `desktop.txt`. Not stowed |
| `fontconfig` | Font folders; rendering comes from Settings > Fonts |
| `kitty`, `tmux`, `zsh` | Terminal, multiplexer and shell (below) |
| `nvim`, `lazygit`, `yazi`, `bat`, `btop`, `cava`, `fastfetch`, `starship`, `swayimg`, `spotify`, `cliamp`, `paru` | App configs; those with colors follow the theme |

## Window manager keys

The main modifier is `SUPER`, set by `mainMod` in `hypr/.config/hypr/configs/bindings.lua`. Alt and Super
are swapped (`altwin:swap_alt_win` in `input.lua`), so `SUPER` is the physical Alt key, and Alt+Space
switches keyboard layout. In Work-Game's Game mode (`SUPER+CTRL+G`) the keyboard is plain US with no swap
and no layout switching, so games get Alt where it's printed and `SUPER` is the key with the Windows logo;
Work mode (`SUPER+G`) keeps the keyboard as it is. `SUPER+/` lists every binding.

## Terminal keys

- **Panes:** `Ctrl+H/J/K/L` moves across tmux panes and Neovim splits. The tmux prefix is `Ctrl+S`.
- **Clipboard:** `y` copies and `p`/`P` paste the system clipboard in zsh, Neovim and tmux copy mode
  (tmux pastes with prefix `P`). `Ctrl+Shift+V` pastes anywhere.
- **Neovim:** `x`, `c` and `s` leave the clipboard alone, and `<leader>d` deletes without copying.
- **zsh:** vi mode, with history in `~/.local/state/zsh/history`. Prompt and tool init output is
  cached in `~/.cache/zsh`.
- **herdr:** runs beside tmux with the same prefix and follows the theme. `install.sh` doesn't install
  it and there is no folder for it here: install it yourself (`theme-set.py` looks on `PATH` and in
  `~/.local/bin`). The theme writes `~/.config/herdr/config.toml` from
  `theme/.config/theme/templates/herdr-config.toml.tpl`.
