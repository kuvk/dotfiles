import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One notification. A click anywhere but an action button runs the app's
// default action (if it has one) and removes the card: a popup just hides
// (it stays in the Control Center), a card in the Control Center is dismissed.
// Popups show a thin bar at the top counting down to when they hide.
Item {
    id: root

    required property Notification notification
    property bool popup: false
    property bool showAppName: true
    // opaque background (the card color blended onto the panel), for cards
    // stacked over each other in the Control Center
    property bool solid: false

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property int timeout: popup ? Notifs.timeoutFor(notification) : 0
    readonly property string imageSource: {
        const img = notification.image;
        if (img)
            return img;
        const icon = Notifs.appIconOf(notification);
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    // web apps get their own name, icon and body without the site (Notifs)
    readonly property string appName: Notifs.appNameOf(notification)
    readonly property string body: Notifs.bodyOf(notification)

    function close(): void {
        if (popup)
            Notifs.dismissPopup(notification);
        else
            notification.dismiss();
    }

    implicitHeight: card.implicitHeight

    Rectangle {
        id: card

        anchors.fill: parent
        implicitHeight: layout.implicitHeight + 24
        radius: Theme.radius
        color: root.popup ? Theme.panelBg : root.solid ? Qt.tint(Theme.base, Theme.cardBg) : Theme.cardBg
        // only critical notifications get an outline
        border.width: root.critical ? Theme.borderWidth : 0
        border.color: Theme.red
        clip: true

        layer.enabled: root.popup && !Theme.gamemode
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 0.5
            shadowVerticalOffset: 3
        }

        // Time left before the popup hides
        Rectangle {
            id: progress

            property real remaining: 1

            visible: root.timeout > 0
            anchors.top: parent.top
            anchors.left: parent.left
            height: 2
            width: parent.width * remaining
            color: Theme.highlight
            opacity: 0.8

            NumberAnimation on remaining {
                id: countdown

                running: root.timeout > 0
                paused: running && hover.containsMouse
                from: 1
                to: 0
                duration: root.timeout * 1000
                onFinished: Notifs.dismissPopup(root.notification)
            }
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const def = root.notification.actions.find(a => a.identifier === "default");
                if (def)
                    def.invoke();
                root.close();
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

                    // app name and time; without the app name (Control Center
                    // groups) the time sits to the right of the text instead
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.showAppName

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.showAppName
                            text: root.appName
                            color: root.critical ? Theme.red : Theme.highlight
                            font.pixelSize: Theme.fontSize - 2
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            text: Notifs.relativeTime(root.notification, Time.date)
                            color: Theme.overlay1
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        // a title that only repeats the app name adds nothing
                        visible: text !== "" && !(root.showAppName && text === root.appName)
                        text: root.notification.summary
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.body
                        textFormat: Text.StyledText
                        color: Theme.subtext1
                        wrapMode: Text.Wrap
                        maximumLineCount: root.popup ? 4 : 8
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignTop
                    visible: !root.showAppName
                    text: Notifs.relativeTime(root.notification, Time.date)
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // Action buttons (these don't close the card on their own click area)
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
}
