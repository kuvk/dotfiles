import QtQuick
import QtQuick.Layouts
import qs.config

// Compact font chooser: shows the current family in its own font; a click
// unfolds the list of `options` (each drawn in its font), a pick folds it.
ColumnLayout {
    id: root

    property string value
    property var options: []
    property string sample: ""
    property bool open: false
    signal picked(string family)

    readonly property bool installed: Qt.fontFamilies().includes(value)

    Layout.fillWidth: true
    spacing: 4
    opacity: enabled ? 1 : 0.4

    onEnabledChanged: if (!enabled) open = false

    MouseArea {
        id: button

        Layout.fillWidth: true
        implicitHeight: 34
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.open = !root.open

        Rectangle {
            anchors.fill: parent
            radius: Theme.smallRadius
            color: button.containsMouse && root.enabled ? Theme.hoverBg : Theme.cardBg
            border.color: root.open ? Theme.highlight : "transparent"
            border.width: Theme.borderWidth
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: chevron.left
            anchors.rightMargin: 8
            text: root.installed ? root.value : `${root.value} (not installed)`
            color: root.installed ? Theme.text : Theme.peach
            font.family: root.value
            elide: Text.ElideRight
        }

        Icon {
            id: chevron

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
            text: root.open ? Icons.chevronUp : Icons.chevronDown
            color: Theme.subtext0
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: root.open
        implicitHeight: Math.min(220, list.contentHeight + 8)
        radius: Theme.smallRadius
        color: Theme.cardBg

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.options.indexOf(root.value)
            onVisibleChanged: if (visible) positionViewAtIndex(Math.max(0, currentIndex), ListView.Center)

            delegate: MouseArea {
                id: entry

                required property string modelData

                width: list.width - 10
                height: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.picked(modelData);
                    root.open = false;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.smallRadius
                    color: entry.modelData === root.value ? Theme.alpha(Theme.highlight, 0.2) : entry.containsMouse ? Theme.hoverBg : "transparent"
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    width: parent.width - 16
                    text: root.sample ? `${entry.modelData}   ${root.sample}` : entry.modelData
                    color: entry.modelData === root.value ? Theme.highlight : Theme.text
                    font.family: entry.modelData
                    elide: Text.ElideRight
                }
            }
        }

        ScrollBar {
            flick: list
        }
    }
}
