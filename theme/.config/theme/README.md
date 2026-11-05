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

Or press `ALT+SHIFT+Space`, or use the Theme tile in the control center.

| App | Reads | Reload |
|---|---|---|
| Quickshell | `current/quickshell.json` | live (file watch + IPC) |
| Hyprland borders | `~/.config/hypr/configs/generated/theme.lua` | live (`hyprctl eval`) |
| hyprlock | `current/hyprland.conf` | on next lock |
| kitty | `current/kitty.conf` | live (SIGUSR1) |
| Neovim | `current/nvim.lua` | live (`lua/theme.lua` watches it) |
| btop | `current/btop.theme` | live (SIGUSR2) |
| tmux | `current/tmux.conf` | live (`source-file`) |
| starship | `current/starship.toml` (copy of `~/.config/starship.toml` + palette) | next prompt |
| rofi | `current/rofi.rasi` | next launch |
| waybar, swaync, wlogout | `current/gtk.css` | live for waybar and swaync, next launch for wlogout |
| scripts | `current/colors.sh` | sourced by `hypr-gamemode.sh`, `wlogout-set-icons.sh` |
| GTK apps | `gsettings ... color-scheme` | live (dark/light only) |

## Adding a theme

1. Copy `themes/catppuccin-mocha` to `themes/<name>`.
2. Fill in all 26 slots in `[colors]`. The names are Catppuccin's because every
   config already uses them. Map your palette by role: `base`/`mantle`/`crust`
   are backgrounds from lightest to darkest (reversed for light themes),
   `surface*` are raised surfaces, `overlay*` are muted text, and `text`/`subtext*`
   are foregrounds.
3. Set `accent` (borders, highlights) and `accent2` to a slot name or a hex value.
4. In `[apps]`, set `nvim_colorscheme`, and add its plugin to
   `nvim/lua/plugins/themes.lua` if it isn't there.
5. Optional: `[terminal]` overrides for the 16 ANSI colors, `cursor`, and
   `selection_fg`/`selection_bg`; `wallpaper = "~/wallpapers/x.jpg"` (or a path
   inside the theme folder) in `[apps]` sets the wallpaper on switch.

## Adding an app

Add `templates/<output-file>.tpl` with placeholders such as `{{ base }}` (`#1e1e2e`),
`{{ base.hex }}` (`1e1e2e`), `{{ base.rgb }}` (`30, 30, 46`), `{{ accent }}`,
`{{ term_color1 }}`, `{{ mode }}`, `{{ theme_name }}`, or any `[apps]` key. Point the
app at `~/.config/theme/current/<output-file>`, and add a reload command to
`reload_apps()` in `theme-set.py` if the app supports one.

Not wired up yet: yazi, lazygit, bat, fastfetch, cava, the GTK/Qt widget themes,
and SDDM.
