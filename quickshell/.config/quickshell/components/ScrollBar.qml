import QtQuick
import qs.config

// Slim scroll bar for a Flickable/ListView: faint while idle, clearer while scrolling or under
// the mouse, draggable. Hidden when everything fits.
// It sits in the padding of the surface around the list, 1 px inside its right border: the
// nearest bordered panel (a dropdown, a popup, a framed list), or the window itself (Settings,
// Displays and Keybindings, whose border Hyprland draws outside). It finds that surface on its
// own, so a list only needs `flick`.
Item {
    id: root

    required property Flickable flick
    readonly property bool needed: flick.contentHeight > flick.height + 1
    readonly property bool active: flick.moving || area.containsMouse || area.pressed

    // the surface it sits on: the nearest ancestor with a border, else the window's root item
    readonly property Item edge: {
        let item = flick.parent;
        while (item && item.parent) {
            if (item.border && item.border.width > 0)
                return item;
            item = item.parent;
        }
        return item;
    }
    readonly property int edgeBorder: edge && edge.border ? edge.border.width : 0

    parent: edge
    // along the list's height, mapped onto the surface (again when either moves or resizes)
    y: (flick.x, flick.y, flick.height, edge?.height, needed, edge ? flick.mapToItem(edge, 0, 0).y : 0)
    height: flick.height
    x: (edge?.width ?? 0) - edgeBorder - 1 - width
    width: 8
    visible: needed && flick.visible
    z: 10

    Rectangle {
        id: handle

        anchors.right: parent.right
        width: root.active ? 6 : 4
        radius: width / 2
        height: Math.max(24, root.flick.visibleArea.heightRatio * root.height)
        y: Math.min(root.height - height, root.flick.visibleArea.yPosition * root.height)
        color: Theme.dimText
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
