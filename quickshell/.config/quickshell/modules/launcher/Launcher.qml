import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Search launcher (ALT+Space): only the input field, a quarter down the
// screen; matching apps appear under it once something is typed. The menu
// with categories is modules/launcher/AppMenu.qml (ALT+CTRL+Space, Arch icon).
PanelWindow {
    id: root

    readonly property bool shown: Panels.launcher
    readonly property int maxRows: 7
    readonly property int rowHeight: 52
    readonly property var results: search.text.trim() === "" ? [] : Apps.search(search.text)

    function activate(index: int): void {
        const app = results[index];
        if (!app)
            return;
        Panels.launcher = false;
        Apps.launch(app);
    }

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: shown
    color: "transparent"
    anchors {
        top: true
    }
    margins {
        top: Math.round((screen?.height ?? 1080) * 0.22)
    }
    implicitWidth: 600
    // grows downward with the results, so the field never moves
    implicitHeight: 74 + (results.length > 0 ? Math.min(results.length, maxRows) * (rowHeight + 4) + 12 : 0)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand like the dropdowns: the focus grab below hands this window the
    // keyboard and closes it on a click anywhere else (bar included)
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        search.text = "";
        list.currentIndex = 0;
        if (shown)
            search.forceActiveFocus();
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root]
        onCleared: Panels.launcher = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        radius: Theme.radius
        border.color: Theme.border
        border.width: Theme.borderWidth

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.smallRadius
                color: Theme.alpha(Theme.surface0, 0.8)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 12

                    Icon {
                        text: Icons.search
                        color: Theme.accent2
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 16
                        clip: true
                        onTextChanged: list.currentIndex = 0

                        Keys.onEscapePressed: {
                            if (search.text !== "")
                                search.text = "";
                            else
                                Panels.launcher = false;
                        }
                        Keys.onReturnPressed: root.activate(list.currentIndex)
                        Keys.onEnterPressed: root.activate(list.currentIndex)
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onBacktabPressed: list.decrementCurrentIndex()
                        Keys.onPressed: event => {
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                                    list.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                                    list.decrementCurrentIndex();
                                    event.accepted = true;
                                }
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: "Search apps…"
                            color: Theme.surface2
                            font.pixelSize: 16
                        }
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.results.length > 0
                clip: true
                spacing: 4
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

                    width: ListView.view.width
                    implicitHeight: root.rowHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = index
                    onClicked: root.activate(index)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        IconImage {
                            implicitSize: 32
                            source: Quickshell.iconPath(entry.modelData.icon ?? "", "application-x-executable")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: entry.modelData.name
                                color: entry.ListView.isCurrentItem ? Theme.highlight : Theme.text
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: entry.modelData.genericName || entry.modelData.comment || ""
                                color: Theme.overlay1
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
