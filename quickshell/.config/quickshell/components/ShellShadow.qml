import QtQuick
import QtQuick.Effects

// The shell's shadow, as an item's layer.effect: black at 40%, soft, slightly down (close to a
// Hyprland window shadow). Its window needs Theme.shadowPad of room around the item. Shown on
// the shell's popups and notifications with Settings > Style > Shell > Shadow, on the bar with
// Settings > Bar > Shadow.
MultiEffect {
    shadowEnabled: true
    shadowColor: "black"
    shadowOpacity: 0.4
    shadowBlur: 0.5
    shadowHorizontalOffset: 1
    shadowVerticalOffset: 3
    autoPaddingEnabled: true
}
