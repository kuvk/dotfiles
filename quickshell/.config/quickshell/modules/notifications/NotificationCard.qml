import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One notification. `popup` cards time out and only hide; closing a card
// in the control center dismisses it for good.
Rectangle {
    id: root

    required property Notification notification
    property bool popup: false

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property string imageSource: {
        const img = notification.image;
        if (img)
            return img;
        const icon = notification.appIcon;
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    implicitHeight: layout.implicitHeight + 24
    radius: Theme.smallRadius
    color: popup ? Theme.panelBg : Theme.cardBg
    border.width: popup || critical ? Theme.borderWidth : 0
    border.color: critical ? Theme.red : Theme.border

    Timer {
        running: root.popup && Notifs.timeoutFor(root.notification) > 0 && !hover.containsMouse
        interval: Notifs.timeoutFor(root.notification) * 1000
        onTriggered: Notifs.dismissPopup(root.notification)
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.notification.dismiss();
                return;
            }
            const def = root.notification.actions.find(a => a.identifier === "default");
            if (def) {
                def.invoke();
                if (!root.notification.resident)
                    root.notification.dismiss();
            } else if (root.popup) {
                Notifs.dismissPopup(root.notification);
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            IconImage {
                Layout.alignment: Qt.AlignTop
                implicitSize: 40
                source: root.imageSource
                visible: root.imageSource !== ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: root.notification.appName || "Notification"
                        color: root.critical ? Theme.red : Theme.highlight
                        font.pixelSize: Theme.fontSize - 2
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        text: Notifs.relativeTime(root.notification, Time.date)
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSize - 2
                    }

                    IconButton {
                        size: 22
                        icon: Icons.close
                        color: Theme.overlay2
                        onClicked: root.popup ? Notifs.dismissPopup(root.notification) : root.notification.dismiss()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.notification.summary
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notification.body
                    textFormat: Text.StyledText
                    color: Theme.subtext1
                    wrapMode: Text.Wrap
                    maximumLineCount: root.popup ? 4 : 8
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: actionsRepeater.count > 0
            spacing: 6

            Repeater {
                id: actionsRepeater

                model: root.notification.actions.filter(a => a.identifier !== "default")

                MouseArea {
                    id: action

                    required property NotificationAction modelData

                    Layout.fillWidth: true
                    implicitHeight: 30
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        modelData.invoke();
                        if (!root.notification.resident)
                            root.notification.dismiss();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.smallRadius
                        color: action.containsMouse ? Theme.surface1 : Theme.surface0
                    }

                    StyledText {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 12)
                        text: action.modelData.text
                    }
                }
            }
        }
    }
}
