import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

Row {
    id: root

    required property var bar

    spacing: 0
    leftPadding: 4
    rightPadding: 4

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
