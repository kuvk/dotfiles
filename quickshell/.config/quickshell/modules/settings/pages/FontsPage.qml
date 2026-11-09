import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Fonts
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    id: fontsPage

    // Monospaced families, one entry each, as fc-list names them (no emoji or symbol fonts):
    // the font is the terminals' too
    property var families: []
    // the rest, for the display font
    readonly property var displayFonts: Qt.fontFamilies().filter(f => !families.includes(f) && !/Nerd Font|emoji/i.test(f))

    Process {
        running: true
        command: ["fc-list", ":spacing=100", "-f", "%{family[0]}\n"]
        stdout: StdioCollector {
            onStreamFinished: fontsPage.families = [...new Set(text.split("\n").filter(f => f !== "" && !/emoji|signwriting|Symbols Nerd Font/i.test(f)))].sort()
        }
    }

    Layout.fillWidth: true
    spacing: 12

    // How the bar's text and icons look with these fonts
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: preview.implicitHeight + 24
        radius: Theme.smallRadius
        color: Theme.barBg

        Row {
            id: preview

            anchors.centerIn: parent
            spacing: 12

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Distro.logo
                color: Theme.accent
                font.pixelSize: Math.round(17 * Theme.textScale)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(Time.date, Config.clockFormat)
                font.weight: Font.DemiBold
            }

            Repeater {
                model: [Icons.music, Icons.coffee, Icons.bluetooth, Icons.font, Icons.cog, Icons.power]

                Icon {
                    required property string modelData

                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: Theme.subtext
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: "Open terminals change now; reopen other apps. Icons are always Symbols Nerd Font's."
        color: Theme.dimText
        font.pixelSize: Theme.smallSize
        wrapMode: Text.Wrap
    }

    SettingRow {
        label: "Monospace everywhere"
        hint: "The font for all text; off: the display font outside terminals"

        Switch {
            checked: Config.monoEverywhere
            onToggled: {
                Config.monoEverywhere = !Config.monoEverywhere;
                fontApply.restart();
            }
        }
    }

    StyledText {
        Layout.topMargin: 4
        text: "Font"
        font.weight: Font.DemiBold
    }

    FontDropdown {
        value: Config.font
        options: fontsPage.families
        sample: "0O1lI {}[] => != " + Icons.cog
        onPicked: family => {
            Config.font = family;
            fontApply.restart();
        }
    }

    StyledText {
        Layout.topMargin: 4
        text: "Display font"
        font.weight: Font.DemiBold
        opacity: Config.monoEverywhere ? 0.4 : 1
    }

    FontDropdown {
        enabled: !Config.monoEverywhere
        value: Config.displayFont
        options: fontsPage.displayFonts
        onPicked: family => {
            Config.displayFont = family;
            fontApply.restart();
        }
    }

    SettingRow {
        Layout.topMargin: 4
        label: "Hinting"
        hint: "Slight suits most screens"

        Stepper {
            text: Config.fontHinting.charAt(0).toUpperCase() + Config.fontHinting.slice(1)
            onStep: d => {
                Config.fontHinting = settings.cycle(["none", "slight", "medium", "full"], Config.fontHinting, d);
                fontApply.restart();
            }
        }
    }

    SettingRow {
        label: "Antialiasing"
        hint: "Grayscale avoids color fringes"

        Stepper {
            text: ({ none: "None", grayscale: "Grayscale", rgba: "Subpixel" })[Config.fontAntialiasing]
            onStep: d => {
                Config.fontAntialiasing = settings.cycle(["none", "grayscale", "rgba"], Config.fontAntialiasing, d);
                fontApply.restart();
            }
        }
    }

    // Stepping through several options applies only the last
    Timer {
        id: fontApply

        interval: 400
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--fonts", Config.font, Config.displayFont, Config.monoEverywhere ? "on" : "off", Config.fontHinting, Config.fontAntialiasing])
    }
}
