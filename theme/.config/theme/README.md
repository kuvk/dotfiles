# Themes

Works like Omarchy's theme switching: one palette per theme, rendered into
every app's format, with running apps reloaded.

```
themes/<name>/colors.toml   the palette, the only file a theme needs
themes/<name>/<file>        optional: replaces the rendered file of the same name
templates/*.tpl             one per app, rendered into current/
current/                    generated (gitignored); app configs point here
```

## Switching

```sh
~/.config/scripts/theme-set.py tokyo-night   # apply
~/.config/scripts/theme-set.py               # re-render the current theme
~/.config/scripts/theme-set.py --list
```

Or press `ALT+SHIFT+T`, or use the Theme tile in the control center.

## Included themes

Catppuccin Mocha (default) and Catppuccin Latte are exact Catppuccin palettes.
Every other theme is imported from [Omarchy](https://github.com/basecamp/omarchy)
(MIT): Ethereal, Everforest, Flexoki Light, Gruvbox, Hackerman, Jade Horse,
Kanagawa, Last Horizon, Lumon, Lupine, Matte Black, Miasma, Nord, Retro 82,
Ristretto, Rose Pine, Solitude, Starship, Tokyo Night, Vantablack and White.

To pull in new or updated Omarchy themes:

```sh
git clone --depth 1 https://github.com/basecamp/omarchy /tmp/omarchy
~/.config/theme/import-omarchy.py /tmp/omarchy/themes          # all
~/.config/theme/import-omarchy.py /tmp/omarchy/themes nord     # or some
```

Omarchy themes are semantic (background, foreground, accent, ANSI colors), so
the importer interpolates the in-between shades. Terminal colors match Omarchy's
kitty template. Neovim uses the theme's own colorscheme where Omarchy names one,
and otherwise [aether](https://github.com/omacom/aether.nvim) built from the
palette, as Omarchy does. Wallpapers aren't imported (161 MB); put one in a
theme folder and set `wallpaper` under `[apps]`.

| App | Reads | Reload |
|---|---|---|
| Quickshell | `current/quickshell.json` | live (file watch + IPC) |
| Hyprland borders | `~/.config/hypr/configs/generated/theme.lua` | live (`hyprctl eval`) |
| kitty | `current/kitty.conf` | live (SIGUSR1) |
| Neovim | `current/nvim.lua` | live (`lua/theme.lua` watches it) |
| btop | `~/.config/btop/themes/current.theme` | live (SIGUSR2) |
| bat | `~/.config/bat/themes/Current.tmTheme` | next run (`bat cache --build`) |
| tmux | `~/.tmux/plugins/catppuccin/tmux/themes/catppuccin_current_tmux.conf`, a catppuccin/tmux flavor (the plugin is loaded by `.tmux.conf`, not TPM) | live (`source-file`) |
| starship | `~/.config/starship.toml` (generated from `~/.config/starship/base.toml` + palette) | next prompt |
| lazygit | `current/lazygit.yml` (via `LG_CONFIG_FILE`) | next start |
| yazi | `~/.config/yazi/theme.toml` | live for yazi started with `yazi-live.sh` (`ALT+E`, `y`): it reopens in the same folder |
| cava | `~/.config/cava/themes/current` | live (SIGUSR2) |
| Chromium, Brave | managed policy `BrowserThemeColor` (one-time `browser-theme-setup.sh`) | live |
| cliamp | `~/.config/cliamp/themes/system.toml` | live (`cliamp theme system`) |
| ls, eza, zsh completion | `current/ls_colors.zsh` (`dircolors` output of `current/dir_colors`) | live in open shells (SIGUSR1) |
| herdr | `~/.config/herdr/config.toml`, the whole file: edit `templates/herdr-config.toml.tpl`, not the output | live (`herdr server reload-config`) |
| swayimg | `current/swayimg.lua` (loaded by `~/.config/swayimg/init.lua`) | live (SIGUSR1) |
| scripts | `current/colors.sh` | sourced by `hypr-gamemode.sh` |
| GTK apps | `gsettings ... color-scheme` | live (dark/light only) |

## Power menu icons

The power menu and the Control Center use wlogout's icons, recolored per theme
(lock green, sleep peach, log out teal, reboot mauve, shut down red). The
sources are in `icons/source/`, and `~/.config/scripts/theme-icons.py` writes
`icons/<theme>/*.svg` for every theme (`--missing` only for themes without a
folder, or name the themes). A theme without icons uses Catppuccin Mocha's.

## Adding a theme

1. Copy `themes/catppuccin-mocha` to `themes/<name>`.
2. Fill in all 26 slots in `[colors]`. The names are Catppuccin's because every
   config already uses them. Map your palette by role: `base`/`mantle`/`crust`
   are backgrounds from lightest to darkest,
   `surface*` are raised surfaces, `overlay*` are muted text, and `text`/`subtext*`
   are foregrounds.
3. Set `accent` (borders, highlights) and `accent2` to a slot name or a hex value.
4. In `[apps]`, set `nvim_colorscheme`, and add its plugin to
   `nvim/lua/plugins/themes.lua` if it isn't there.
5. Optional: `[terminal]` overrides for the 16 ANSI colors, `cursor`, and
   `selection_fg`/`selection_bg`; `wallpaper = "~/wallpapers/x.jpg"` (or a path
   inside the theme folder) in `[apps]` sets the wallpaper on switch.
6. Run `~/.config/scripts/theme-icons.py <name>` for its power menu icons.

## Adding an app

Add `templates/<output-file>.tpl` with placeholders such as `{{ base }}` (`#1e1e2e`),
`{{ base.hex }}` (`1e1e2e`), `{{ base.rgb }}` (`30, 30, 46`), `{{ base.ansi }}` (`38;2;30;30;46`), `{{ accent }}`,
`{{ term_color1 }}`, `{{ mode }}`, `{{ theme_name }}`, or any `[apps]` key. Point the
app at `~/.config/theme/current/<output-file>`, and add a reload command to
`reload_apps()` in `theme-set.py` if the app supports one.

Not wired up yet: yazi, lazygit, bat, fastfetch, cava, the GTK/Qt widget themes,
and SDDM.
