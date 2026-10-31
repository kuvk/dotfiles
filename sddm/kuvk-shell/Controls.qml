import QtQuick

// ‹ label › pill for choosing a session or user
Rectangle {
    id: root

    property string label
    signal stepped(int delta)

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 36
    radius: 9
    color: Qt.alpha(config.base, 0.75)
    border.color: Qt.alpha(config.outline, 0.3)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Arrow {
            delta: -1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: config.text
            font.family: config.font
            font.pixelSize: 14
        }

        Arrow {
            delta: 1
        }
    }

    component Arrow: MouseArea {
        id: arrow

        property int delta

        width: 28
        height: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.stepped(delta)

        Text {
            anchors.centerIn: parent
            text: arrow.delta < 0 ? "\uf053" : "\uf054"
            color: arrow.containsMouse ? config.dots : config.subtext
            font.family: config.iconFont
            font.pixelSize: 11
        }
    }
}
