import QtQuick
import qs.config

// Slim scroll bar for a Flickable/ListView, placed over its right edge:
// faint while idle, clearer while scrolling or under the mouse, draggable.
// Hidden when everything fits.
Item {
    id: root

    required property Flickable flick
    readonly property bool needed: flick.contentHeight > flick.height + 1
    readonly property bool active: flick.moving || area.containsMouse || area.pressed

    anchors.top: flick.top
    anchors.bottom: flick.bottom
    anchors.right: flick.right
    anchors.rightMargin: 1
    width: 8
    visible: needed
    z: 10

    Rectangle {
        id: handle

        anchors.right: parent.right
        width: root.active ? 6 : 4
        radius: width / 2
        height: Math.max(24, root.flick.visibleArea.heightRatio * root.height)
        y: Math.min(root.height - height, root.flick.visibleArea.yPosition * root.height)
        color: Theme.overlay1
        opacity: root.active ? 0.8 : 0.3

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animDuration
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true

        function scrollTo(y: real): void {
            const f = root.flick;
            const ratio = Math.max(0, Math.min(1, (y - handle.height / 2) / Math.max(1, root.height - handle.height)));
            f.contentY = f.originY + ratio * (f.contentHeight - f.height);
        }

        onPressed: mouse => scrollTo(mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                scrollTo(mouse.y);
        }
    }
}
