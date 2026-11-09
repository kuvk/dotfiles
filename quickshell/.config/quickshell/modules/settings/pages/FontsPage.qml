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

    readonly property var families: Qt.fontFamilies()
    // full Nerd Fonts, one entry per family (no Mono/Propo
    // variants, no Symbols): letters and icons
    readonly property var nerdFonts: families.filter(f => /Nerd Font$/.test(f) && !f.startsWith("Symbols Nerd Font"))
    // everything else, for the display font
    readonly property var displayFonts: families.filter(f => !/Nerd Font/.test(f))

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
                font.pixelSize: 17
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
        text: "Everywhere but terminals. Reopen apps to apply."
        color: Theme.dimText
        font.pixelSize: Theme.smallSize
        wrapMode: Text.Wrap
    }

    SettingRow {
        label: "Nerd Fonts only"
        hint: "Nerd Font for all text"

        Switch {
            checked: Config.nerdFontOnly
            onToggled: {
                Config.nerdFontOnly = !Config.nerdFontOnly;
                fontApply.restart();
            }
        }
    }

    SettingRow {
        label: "Use Nerd Symbols font"
        hint: "Off: icons from the Nerd Font"

        Switch {
            checked: Config.nerdSymbols
            onToggled: Config.nerdSymbols = !Config.nerdSymbols
        }
    }

    StyledText {
        Layout.topMargin: 4
        text: "Nerd Font"
        font.weight: Font.DemiBold
    }

    FontDropdown {
        value: Config.nerdFont
        options: fontsPage.nerdFonts
        sample: Distro.logo + " " + Icons.cog + " 0O1lI"
        onPicked: family => {
            Config.nerdFont = family;
            fontApply.restart();
        }
    }

    StyledText {
        Layout.topMargin: 4
        text: "Display font"
        font.weight: Font.DemiBold
        opacity: Config.nerdFontOnly ? 0.4 : 1
    }

    FontDropdown {
        enabled: !Config.nerdFontOnly
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
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--fonts", Config.nerdFont, Config.displayFont, Config.nerdFontOnly ? "on" : "off", Config.fontHinting, Config.fontAntialiasing])
    }
}
