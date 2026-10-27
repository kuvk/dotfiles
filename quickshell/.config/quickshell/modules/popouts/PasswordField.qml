import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

Rectangle {
    id: root

    property bool active: false
    signal accepted(string password)

    Layout.fillWidth: true
    implicitHeight: 36
    radius: Theme.smallRadius
    color: Theme.cardBg
    border.color: input.activeFocus ? Theme.highlight : "transparent"

    onActiveChanged: {
        input.text = "";
        if (active)
            input.forceActiveFocus();
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        echoMode: TextInput.Password
        clip: true
        onAccepted: if (text.length > 0) root.accepted(text)

        StyledText {
            anchors.fill: parent
            visible: input.text === ""
            text: "Password"
            color: Theme.overlay1
        }
    }
}
