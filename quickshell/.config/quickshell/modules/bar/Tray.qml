import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

// System tray collapsed behind an arrow; click the arrow to slide the icons out
Row {
    id: root

    property bool expanded: false

    visible: SystemTray.items.values.length > 0
    spacing: 0

    Item {
        id: drawer

        height: Theme.barHeight - 6
        width: root.expanded ? icons.implicitWidth : 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration * 2
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: icons

            anchors.right: parent.right

            Repeater {
                model: SystemTray.items

                BarButton {
                    id: item

                    required property SystemTrayItem modelData

                    implicitWidth: 30
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton && !modelData.onlyMenu)
                            modelData.activate();
                        else if (mouse.button === Qt.MiddleButton)
                            modelData.secondaryActivate();
                        else if (modelData.hasMenu)
                            menu.open();
                    }

                    IconImage {
                        implicitSize: 15
                        source: {
                            // Some apps (Steam, Discord, ...) send "name?path=/dir"
                            let icon = item.modelData.icon;
                            if (icon.includes("?path=")) {
                                const [name, path] = icon.split("?path=");
                                icon = `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
                            }
                            return icon;
                        }
                    }

                    QsMenuAnchor {
                        id: menu

                        menu: item.modelData.menu
                        anchor.item: item
                        anchor.edges: Edges.Bottom
                        anchor.gravity: Edges.Bottom
                    }
                }
            }
        }
    }

    BarButton {
        implicitWidth: 26
        onClicked: root.expanded = !root.expanded

        Icon {
            text: root.expanded ? Icons.chevronRight : Icons.chevronLeft
            color: Theme.overlay2
            font.pixelSize: 11
        }
    }
}
