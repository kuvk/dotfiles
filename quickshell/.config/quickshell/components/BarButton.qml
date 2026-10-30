import QtQuick
import Quickshell
import qs.config
import qs.services

// Bar item. With `indicator`, an open dropdown (`active`) shows an animated
// accent line underneath. Hovering for a moment shows `tooltip` (one line per
// "\n").
MouseArea {
    id: root

    default property alias content: row.data
    property bool active: false
    property bool indicator: true
    property string tooltip: ""

    implicitWidth: row.implicitWidth + Theme.padding * 2
    implicitHeight: Theme.barHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onContainsMouseChanged: {
        if (containsMouse) {
            tooltipDelay.restart();
        } else {
            tooltipDelay.stop();
            Panels.hideTooltip();
        }
    }
    onPressed: {
        tooltipDelay.stop();
        Panels.hideTooltip();
    }
    // Keep a visible tooltip in sync with the value it shows
    onTooltipChanged: if (containsMouse && Panels.tooltip !== "") showTooltip()

    function showTooltip(): void {
        if (tooltip === "" || Panels.dropdown !== "")
            return;
        const pos = mapToItem(null, width / 2, 0);
        Panels.showTooltip(tooltip, QsWindow.window?.screen ?? null, pos.x + Theme.barMargin);
    }

    Timer {
        id: tooltipDelay

        interval: 450
        onTriggered: root.showTooltip()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6
    }

    // Open dropdown
    Rectangle {
        visible: root.indicator
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        height: 2
        radius: 1
        color: Theme.accent
        width: root.active ? row.implicitWidth + 10 : 0

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration * 1.6
                easing.type: Easing.OutCubic
            }
        }
    }
}
