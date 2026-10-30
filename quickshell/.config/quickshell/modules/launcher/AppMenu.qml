import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// App menu: drops from the Arch icon in the top-left corner (or ALT+CTRL+Space)
// with the categories on the left and their apps on the right. Typing
// filters the current category. ↑/↓ apps, ←/→ or Tab categories, Enter
// launches, Esc clears the filter, then closes.
PanelWindow {
    id: root

    readonly property bool shown: Panels.appMenu
    property string group: "all"
    readonly property var groupIds: Apps.menuGroups.map(g => g.id)
    readonly property var results: Apps.search(filter.text, Apps.inGroup(group))

    function stepGroup(delta: int): void {
        const i = groupIds.indexOf(group);
        group = groupIds[(i + delta + groupIds.length) % groupIds.length];
        list.currentIndex = 0;
    }

    function activate(index: int): void {
        const app = results[index];
        if (!app)
            return;
        Panels.appMenu = false;
        Apps.launch(app);
    }

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: reveal.value > 0
    color: "transparent"
    anchors {
        top: true
        left: true
    }
    margins {
        // the panel's left edge on the bar's (floating bar margin)
        left: Math.max(2, Theme.barMargin - pad)
    }
    // panel size, plus the gap under the bar and a transparent margin (as in
    // dropdowns/Dropdown.qml, so fractional scales never cut the border)
    readonly property int gap: 6
    readonly property int pad: 4
    readonly property int panelWidth: 680
    readonly property int panelHeight: 540
    implicitWidth: panelWidth + pad * 2
    implicitHeight: panelHeight + gap + pad
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell-appmenu"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        filter.text = "";
        group = "all";
        list.currentIndex = 0;
        if (shown)
            filter.forceActiveFocus();
    }

    HyprlandFocusGrab {
        active: root.shown
        // the bars too: clicking another bar icon switches to its dropdown
        windows: [root].concat(Panels.bars)
        onCleared: Panels.appMenu = false
    }

    Reveal {
        id: reveal

        shown: root.shown
        duration: Theme.animDuration * 1.6
    }

    // Clipped at the bar's edge, so the menu drops out of it like the dropdowns
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            x: root.pad
            y: Math.round(root.gap - (root.panelHeight + root.gap) * (1 - reveal.value))
            width: root.panelWidth
            height: root.panelHeight
            color: Theme.panelBg
            radius: Theme.radius
            border.color: Theme.border
            border.width: Theme.borderWidth

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.borderWidth
                spacing: 0

                // Categories
                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 190
                    color: Theme.alpha(Theme.mantle, 0.6)
                    topLeftRadius: Theme.radius
                    bottomLeftRadius: Theme.radius

                    ListView {
                        id: groups

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: shortcuts.top
                        anchors.margins: 10
                        spacing: 2
                        clip: true
                        model: Apps.menuGroups
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: MouseArea {
                            id: groupEntry

                            required property var modelData

                            readonly property bool current: root.group === modelData.id

                            width: ListView.view.width
                            implicitHeight: 34
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.group = modelData.id;
                                list.currentIndex = 0;
                            }
                            // hovering a category shows it, like a start menu
                            onContainsMouseChanged: if (containsMouse && root.group !== modelData.id) hoverDelay.restart()

                            Timer {
                                id: hoverDelay

                                interval: 120
                                onTriggered: if (groupEntry.containsMouse) {
                                    root.group = groupEntry.modelData.id;
                                    list.currentIndex = 0;
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.smallRadius
                                color: groupEntry.current ? Theme.alpha(Theme.highlight, 0.2) : groupEntry.containsMouse ? Theme.hoverBg : "transparent"
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Icon {
                                    Layout.preferredWidth: 18
                                    text: groupEntry.modelData.icon
                                    color: groupEntry.current ? Theme.highlight : Theme.subtext0
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: groupEntry.modelData.label
                                    color: groupEntry.current ? Theme.highlight : Theme.text
                                    font.weight: groupEntry.current ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Settings, Displays, Keybindings, System information
                    ShellShortcuts {
                        id: shortcuts

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        buttonHeight: 32
                    }
                }

                // Apps
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 12
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.smallRadius
                        color: Theme.alpha(Theme.surface0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Icon {
                                text: Icons.search
                                color: Theme.accent2
                            }

                            TextInput {
                                id: filter

                                Layout.fillWidth: true
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 1
                                clip: true
                                onTextChanged: list.currentIndex = 0

                                Keys.onEscapePressed: {
                                    if (filter.text !== "")
                                        filter.text = "";
                                    else
                                        Panels.appMenu = false;
                                }
                                Keys.onReturnPressed: root.activate(list.currentIndex)
                                Keys.onEnterPressed: root.activate(list.currentIndex)
                                Keys.onUpPressed: list.decrementCurrentIndex()
                                Keys.onDownPressed: list.incrementCurrentIndex()
                                Keys.onTabPressed: root.stepGroup(1)
                                Keys.onBacktabPressed: root.stepGroup(-1)
                                Keys.onPressed: event => {
                                    // ←/→ switch categories while there's no text to move in
                                    if (filter.text === "" && event.key === Qt.Key_Left) {
                                        root.stepGroup(-1);
                                        event.accepted = true;
                                    } else if (filter.text === "" && event.key === Qt.Key_Right) {
                                        root.stepGroup(1);
                                        event.accepted = true;
                                    }
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: filter.text === ""
                                    text: `Filter ${Apps.menuGroups.find(g => g.id === root.group)?.label ?? ""}…`
                                    color: Theme.surface2
                                }
                            }
                        }
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.results
                        highlightMoveDuration: Theme.animDuration
                        boundsBehavior: Flickable.StopAtBounds

                        highlight: Rectangle {
                            radius: Theme.smallRadius
                            color: Theme.alpha(Theme.surface0, 0.8)
                        }

                        delegate: MouseArea {
                            id: entry

                            required property var modelData
                            required property int index

                            width: ListView.view.width - 12
                            implicitHeight: 44
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = index
                            onClicked: root.activate(index)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                IconImage {
                                    implicitSize: 28
                                    source: Apps.iconSource(entry.modelData.icon ?? "", "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: entry.modelData.name
                                        color: entry.ListView.isCurrentItem ? Theme.highlight : Theme.text
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: entry.modelData.genericName || entry.modelData.comment || ""
                                        color: Theme.overlay1
                                        font.pixelSize: Theme.fontSize - 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        ScrollBar {
                            parent: list
                            flick: list
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: root.results.length === 0
                            text: "No apps"
                            color: Theme.overlay1
                        }
                    }
                }
            }
        }
    }
}
