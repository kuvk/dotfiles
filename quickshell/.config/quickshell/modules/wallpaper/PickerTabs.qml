import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The Static and Live tabs and the search field, above the carousel (wallpaper picker)
ColumnLayout {
    // the wallpaper picker: the list, the selection and the card geometry
    required property var picker

    spacing: 12

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Repeater {
            model: [
                { kind: "static", label: "Wallpapers" },
                { kind: "live", label: "Live wallpapers" }
            ]

            MouseArea {
                id: tab

                required property var modelData
                readonly property bool current: picker.kind === modelData.kind

                width: tabLabel.implicitWidth + 28
                height: 32
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.wallpapers = modelData.kind

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: tab.current ? Theme.alpha(Theme.highlight, 0.25) : Theme.alpha(Theme.base, 0.6)
                    border.color: tab.current ? Theme.highlight : "transparent"
                    border.width: Theme.borderWidth
                }

                StyledText {
                    id: tabLabel

                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: tab.current ? Theme.highlight : Theme.subtext0
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 320
        implicitHeight: 34
        radius: height / 2
        color: Theme.alpha(Theme.base, 0.75)
        border.color: picker.query !== "" ? Theme.highlight : "transparent"
        border.width: Theme.borderWidth

        Row {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                text: Icons.search
                color: picker.query !== "" ? Theme.highlight : Theme.overlay1
            }

            StyledText {
                text: picker.query !== "" ? picker.query : "Type to search"
                color: picker.query !== "" ? Theme.text : Theme.overlay1
            }
        }
    }
}
