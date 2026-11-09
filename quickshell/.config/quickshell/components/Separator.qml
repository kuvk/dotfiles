import QtQuick
import QtQuick.Layouts
import qs.config

// A faint line between sections of a dropdown or Settings page; `vertical` between side-by-side
// parts (Settings' sidebar and page)
Rectangle {
    property bool vertical: false

    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    Layout.topMargin: vertical ? 0 : 2
    Layout.bottomMargin: vertical ? 0 : 2
    implicitHeight: 1
    implicitWidth: 1
    color: Theme.alpha(Theme.foreground, 0.12)
}
