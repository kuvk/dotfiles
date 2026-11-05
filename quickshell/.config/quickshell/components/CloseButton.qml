import QtQuick
import qs.config

// Small X for the top right corner of windows; hover shows the round background.
// Hidden unless Settings > Windows > Window buttons is on.
IconButton {
    visible: Config.windowButtons
    size: 28
    icon: Icons.close
    color: Theme.subtext0
}
