import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A faint line between sections of a dropdown
Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 2
    Layout.bottomMargin: 2
    implicitHeight: 1
    color: Theme.alpha(Theme.foreground, 0.12)
}
