import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings.pages

// Settings (gear in the Control Center, SUPER+CTRL+S). Sections in a sidebar;
// changes apply immediately and are saved by Config.
FloatingWindow {
    id: root

    readonly property bool shown: Panels.settings
    readonly property var clockFormats: ["dddd HH:mm", "ddd HH:mm", "HH:mm", "ddd d MMM  HH:mm", "dddd h:mm AP"]
    readonly property var sections: [
        { id: "style", label: "Style", icon: Icons.palette },
        { id: "fonts", label: "Fonts", icon: Icons.font },
        { id: "bar", label: "Bar", icon: Icons.sliders },
        { id: "lock", label: "Lock Screen", icon: Icons.lock },
        { id: "idle", label: "Idle", icon: Icons.bed },
        { id: "nightlight", label: "Night Light", icon: Icons.nightlight },
        { id: "tray", label: "Tray & Player", icon: Icons.music }
    ]
    property string section: "style"
    property var cursorThemes: ["Adwaita"]
    property var iconThemes: ["Papirus"]
    // Lock Screen: a setting the boot splash draws changed since it was last built
    property bool bootStale: false

    function cycle(list: var, value: var, step: int): var {
        const i = Math.max(0, list.indexOf(value));
        return list[(i + step + list.length) % list.length];
    }

    // Settings > Idle: minutes, 0 is never
    readonly property var idleSteps: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180]

    function minutesText(minutes: int): string {
        if (minutes === 0)
            return "Never";
        if (minutes < 60)
            return `${minutes} min`;
        return `${Math.floor(minutes / 60)} h` + (minutes % 60 ? ` ${minutes % 60} min` : "");
    }

    // "HH:mm" moved by some minutes, wrapping around midnight
    function stepTime(value: string, minutes: int): string {
        const [h, m] = value.split(":").map(Number);
        const total = (h * 60 + m + minutes + 1440) % 1440;
        return String(Math.floor(total / 60)).padStart(2, "0") + ":" + String(total % 60).padStart(2, "0");
    }

    function clamp(v: real, lo: real, hi: real): real {
        return Math.max(lo, Math.min(hi, v));
    }

    visible: shown
    title: "Settings"
    color: Theme.panelBg
    implicitWidth: Math.round(780 * Theme.textScale)
    implicitHeight: Math.round(560 * Theme.textScale)
    // can grow, not shrink below the default size
    minimumSize: Qt.size(implicitWidth, implicitHeight)

    // A regular window (floating and centered by a Hyprland rule, can be
    // tiled); closing it from Hyprland updates the panel state
    onClosed: Panels.settings = false

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        focus: root.shown
        Keys.onEscapePressed: Panels.settings = false

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Sidebar
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: Math.round(190 * Theme.textScale)
                color: Theme.alpha(Theme.darkBackground, 0.6)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    StyledText {
                        Layout.bottomMargin: 10
                        Layout.leftMargin: 6
                        text: "Settings"
                        font.pixelSize: Theme.headingSize
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: root.sections

                        MouseArea {
                            id: entry

                            required property var modelData
                            readonly property bool current: root.section === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: 36
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.section = modelData.id

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.smallRadius
                                color: entry.current ? Theme.selectedFill : (entry.containsMouse ? Theme.hoverBg : "transparent")
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 10

                                Icon {
                                    width: 18
                                    text: entry.modelData.icon
                                    color: entry.current ? Theme.accent : Theme.subtext
                                }

                                StyledText {
                                    text: entry.modelData.label
                                    color: entry.current ? Theme.accent : Theme.foreground
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: defaultsSaved.running ? "Saved" : "Save as defaults"
                        onClicked: {
                            Config.saveDefaults();
                            defaultsSaved.restart();
                        }

                        Timer {
                            id: defaultsSaved

                            interval: 1500
                        }
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: "Reset to defaults"
                        onClicked: Config.reset()
                    }
                }
            }

            // Section content
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 12

                SectionHeader {
                    title: root.sections.find(s => s.id === root.section)?.label ?? ""

                    CloseButton {
                        onClicked: Panels.settings = false
                    }
                }

                Flickable {
                    id: settingsFlick

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: page.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar {
                        flick: settingsFlick
                    }

                    ColumnLayout {
                        id: page
                        width: settingsFlick.width
                        spacing: 12

                        StylePage {
                            settings: root
                            visible: root.section === "style"
                        }

                        BarPage {
                            settings: root
                            visible: root.section === "bar"
                        }

                        LockPage {
                            settings: root
                            visible: root.section === "lock"
                        }

                        IdlePage {
                            settings: root
                            visible: root.section === "idle"
                        }

                        NightLightPage {
                            settings: root
                            visible: root.section === "nightlight"
                        }

                        FontsPage {
                            settings: root
                            visible: root.section === "fonts"
                        }

                        TrayPage {
                            settings: root
                            visible: root.section === "tray"
                        }
                    }
                }
            }
        }
    }
}
