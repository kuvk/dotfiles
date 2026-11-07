import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// A stat in a dropdown, beside its Label; with `copyable`, a click copies it
StyledText {
    id: value

    property bool copyable: false

    Layout.fillWidth: true
    horizontalAlignment: Text.AlignRight
    font.pixelSize: Theme.fontSize - 1

    MouseArea {
        anchors.fill: parent
        enabled: value.copyable && value.text !== "--"
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: Quickshell.execDetached(["wl-copy", value.text])
    }
}
