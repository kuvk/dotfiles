import QtQuick

// ‹ label › for choosing a session or user. Framed like the power buttons (the session), or
// plain text between the arrows (`framed: false`, the user above the avatar).
Rectangle {
    id: root

    property string label
    property bool framed: true
    signal stepped(int delta)

    readonly property bool hovered: previous.containsMouse || next.containsMouse

    implicitWidth: row.implicitWidth + (framed ? 12 : 0)
    implicitHeight: 36
    radius: Number(config.radius)
    color: framed ? Qt.alpha(config.powerBg, Number(config.powerOpacity)) : "transparent"
    border.width: framed ? 1 : 0
    border.color: hovered ? config.powerHoverOutline : config.powerOutline

    // the shell's hover: the text color over the background
    Rectangle {
        anchors.fill: parent
        visible: root.framed
        radius: parent.radius
        color: Qt.alpha(config.text, root.hovered ? 0.08 : 0.04)
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Arrow {
            id: previous

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
            id: next

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
            text: arrow.delta < 0 ? "" : ""
            color: arrow.containsMouse ? config.text : config.subtext
            font.family: config.iconFont
            font.pixelSize: 11
        }
    }
}
