import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// "NOTIFICATIONS" with Clear, and the notifications grouped by app (stacked or open) (Control Center)
ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 14

    // in small capitals like the dropdowns' sections
    RowLayout {
        Layout.fillWidth: true

        Caption {
            Layout.fillWidth: true
            text: "NOTIFICATIONS"
        }

        MouseArea {
            id: clearButton

            visible: Notifs.count > 0
            implicitWidth: clearLabel.implicitWidth + 16
            implicitHeight: 26
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.clearAll()

            StyledText {
                id: clearLabel

                anchors.centerIn: parent
                text: `${Icons.clearAll}  Clear`
                color: clearButton.containsMouse ? Theme.accent2 : Theme.subtext0
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ScrollBar {
            id: notifScroll

            flick: notifList
        }

        ListView {
            id: notifList

            // Groups whose older notifications are shown
            property var expanded: ({})
            // Groups shown as a stack (hidden), per app
            property var stackedApps: ({})

            anchors.fill: parent
            clip: true
            spacing: 12
            model: Notifs.groups

            delegate: ColumnLayout {
                id: group

                required property var modelData
                readonly property bool open: notifList.expanded[modelData.app] === true
                readonly property bool stacked: notifList.stackedApps[modelData.app] === true && modelData.list.length > 1
                readonly property var shownCards: open && !stacked ? modelData.list : modelData.list.slice(0, 3)

                function toggleStack(): void {
                    const s = Object.assign({}, notifList.stackedApps);
                    s[modelData.app] = !stacked;
                    notifList.stackedApps = s;
                }
                readonly property string iconSource: {
                    const icon = modelData.icon;
                    if (!icon)
                        return "";
                    if (icon.startsWith("/"))
                        return "file://" + icon;
                    return icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
                }

                // room for the scroll bar when the list scrolls
                width: ListView.view.width - (notifScroll.needed ? 12 : 0)
                spacing: 6

                // App header: icon, name, count, clear
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Icon {
                        visible: text !== ""
                        text: Notifs.appGlyphs[group.modelData.app] ?? ""
                        color: Theme.highlight
                    }

                    IconImage {
                        implicitSize: 18
                        source: group.iconSource
                        visible: group.iconSource !== "" && !Notifs.appGlyphs[group.modelData.app]
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: group.modelData.app
                        color: Theme.highlight
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        text: group.modelData.list.length
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSize - 1
                    }

                    // hide (stack) / reveal this app's notifications
                    IconButton {
                        size: 24
                        visible: group.modelData.list.length > 1
                        icon: group.stacked ? Icons.chevronDown : Icons.chevronUp
                        color: Theme.overlay1
                        onClicked: group.toggleStack()
                    }

                    IconButton {
                        size: 24
                        icon: Icons.trash
                        color: Theme.overlay1
                        onClicked: Notifs.clearGroup(group.modelData.app)
                    }
                }

                // The cards: one under another, or stacked (the
                // newest on top, two more peeking out below it).
                // Positions animate between the two.
                Item {
                    id: cards

                    // card heights by index, kept by the cards
                    property var heights: []
                    readonly property int peek: 7
                    readonly property real topHeight: heights[0] ?? 0
                    readonly property real fullHeight: {
                        let h = 0;
                        for (let i = 0; i < group.shownCards.length; i++)
                            h += (heights[i] ?? 0) + (i > 0 ? 6 : 0);
                        return h;
                    }

                    function setHeight(i: int, h: real): void {
                        if (heights[i] === h)
                            return;
                        const copy = heights.slice();
                        copy[i] = h;
                        heights = copy;
                    }

                    function yFor(i: int): real {
                        if (group.stacked)
                            // bottoms aligned under the top card, each a bit lower
                            return topHeight - (heights[i] ?? 0) + i * peek;
                        let y = 0;
                        for (let j = 0; j < i; j++)
                            y += (heights[j] ?? 0) + 6;
                        return y;
                    }

                    Layout.fillWidth: true
                    implicitHeight: group.stacked ? topHeight + (group.shownCards.length - 1) * peek : fullHeight
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: Theme.animDuration * 1.6
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: group.shownCards

                        NotificationCard {
                            id: card

                            required property var modelData
                            required property int index

                            width: cards.width
                            notification: modelData
                            showAppName: false
                            // nothing shows through the top card
                            solid: group.stacked
                            z: -index
                            y: cards.yFor(index)
                            // the ones behind are a little smaller and fainter,
                            // scaled from their bottom edge so it still peeks out
                            transformOrigin: Item.Bottom
                            scale: group.stacked ? 1 - index * 0.04 : 1
                            opacity: group.stacked && index > 0 ? 1 - index * 0.15 : 1
                            onImplicitHeightChanged: cards.setHeight(index, implicitHeight)
                            Component.onCompleted: cards.setHeight(index, implicitHeight)

                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.animDuration * 1.6
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.animDuration * 1.6
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animDuration * 1.6
                                }
                            }
                        }
                    }

                    // a click on the stack reveals it
                    MouseArea {
                        anchors.fill: parent
                        visible: group.stacked
                        z: 10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: group.toggleStack()
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !group.stacked && group.modelData.list.length > 3
                    text: group.open ? "Show less" : `Show ${group.modelData.list.length - 3} more`
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSize - 1

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const e = Object.assign({}, notifList.expanded);
                            e[group.modelData.app] = !group.open;
                            notifList.expanded = e;
                        }
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: notifList.count === 0
            text: `${Icons.bell}  No notifications`
            color: Theme.overlay1
        }
    }
}
