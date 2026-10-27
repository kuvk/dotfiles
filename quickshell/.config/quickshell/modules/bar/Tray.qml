import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// System tray behind a left arrow. Hovering slides the icons out to the
// right of the arrow; they stay while the pointer is over them or a menu is open.
Item {
    id: root

    property int menusOpen: 0
    readonly property bool expanded: hover.hovered || menusOpen > 0 || collapseDelay.running

    visible: SystemTray.items.values.length > 0
    implicitWidth: arrow.implicitWidth + drawer.width
    implicitHeight: Theme.barHeight

    HoverHandler {
        id: hover

        onHoveredChanged: if (!hovered) collapseDelay.restart()
    }

    Timer {
        id: collapseDelay

        interval: 500
    }

    BarButton {
        id: arrow

        implicitWidth: 26
        indicator: false
        tooltip: root.expanded ? "" : "System tray"

        Icon {
            text: Icons.chevronLeft
            color: root.expanded ? Theme.accent : Theme.overlay2
            font.pixelSize: 11
        }
    }

    Item {
        id: drawer

        anchors.left: arrow.right
        height: parent.height
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

            Repeater {
                model: SystemTray.items

                BarButton {
                    id: item

                    required property SystemTrayItem modelData

                    implicitWidth: 30
                    tooltip: modelData.tooltipTitle || modelData.title || modelData.id
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
                        onOpened: root.menusOpen++
                        onClosed: root.menusOpen = Math.max(0, root.menusOpen - 1)
                    }
                }
            }
        }
    }
}
