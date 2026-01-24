#!/bin/bash
# Script to recolor wlogout icons using ImageMagick and save to $HOME/.config/wlogout/icons

# Catppuccin colors
green="#a6e3a1"
mauve="#cba6f7"
peach="#fab387"
red="#f38ba8"
blue="#89b4fa"
teal="#94e2d5"

SRC_DIR="/usr/share/wlogout/icons"
DEST_DIR="$HOME/.config/wlogout/icons"

if command -v magick &> /dev/null; then
    IM_CMD="magick"
elif command -v convert &> /dev/null; then
    IM_CMD="convert"
else
    echo "Neither 'magick' nor 'convert' command found. Please install ImageMagick."
    exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
    echo "Source directory $SRC_DIR does not exist. Install wlogout first."
    exit 1
fi

declare -A color_map
color_map=(
    [lock.png]="$green"
    [hibernate.png]="$blue"
    [logout.png]="$teal"
    [reboot.png]="$mauve"
    [suspend.png]="$peach"
    [shutdown.png]="$red"
)

mkdir -p "$DEST_DIR"

for icon in "${!color_map[@]}"; do
    src="$SRC_DIR/$icon"
    dest="$DEST_DIR/$icon"
    color="${color_map[$icon]}"
    if [[ -f "$src" ]]; then
        "$IM_CMD" "$src" xc:"$color" -channel RGB -clut "$dest"
        echo "Processed $icon with color $color"
    else
        echo "Warning: $src not found, skipping."
    fi
done

echo "All icons processed and saved to $DEST_DIR"
