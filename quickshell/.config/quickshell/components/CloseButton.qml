import QtQuick
import qs.config
import qs.services

// Small X for the top right corner of windows: no background, the X turns
// the accent color on hover. Shown with Settings > Style > Window buttons;
// off, it keeps its place, so the window's layout doesn't move.
MouseArea {
    id: root

    opacity: Config.windowButtons ? 1 : 0
    enabled: Config.windowButtons
    implicitWidth: 28
    implicitHeight: 28
    hoverEnabled: true
    // not in the keyboard order: Esc closes every window
    activeFocusOnTab: false
    Keys.onPressed: event => {
        if (Nav.isActivate(event)) {
            root.clicked(null);
            event.accepted = true;
        }
    }
    cursorShape: Qt.PointingHandCursor

    Icon {
        anchors.centerIn: parent
        text: Icons.close
        color: root.containsMouse ? Theme.accent : Theme.subtext

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }
    }

    FocusRing {}
}
