import QtQuick
import qs.config

// Small X for the top right corner of panels
IconButton {
    size: 28
    icon: Icons.close
    color: containsMouse ? Theme.red : Theme.subtext0
}
