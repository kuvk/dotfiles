import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// One-line text input: Enter accepts, Esc cancels
Rectangle {
    id: field

    property string placeholder
    property alias text: input.text
    property bool password: false
    property bool active: false
    signal accepted(string value)
    signal canceled

    Layout.fillWidth: true
    implicitHeight: 34
    radius: Theme.smallRadius
    color: Theme.cardBg
    border.color: input.activeFocus ? Theme.highlight : "transparent"
    border.width: Theme.borderWidth

    onActiveChanged: if (active) input.forceActiveFocus()
    Component.onCompleted: if (active) input.forceActiveFocus()

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        clip: true
        onAccepted: field.accepted(text)
        Keys.onEscapePressed: field.canceled()

        StyledText {
            anchors.fill: parent
            visible: input.text === ""
            text: field.placeholder
            color: Theme.overlay1
        }
    }
}
