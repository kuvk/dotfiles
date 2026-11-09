import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Bar
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingRow {
        label: "Floating bar"

        Switch {
            checked: Config.barFloating
            onToggled: Config.barFloating = !Config.barFloating
        }
    }

    SettingRow {
        visible: Config.barFloating
        label: "Bar margin"

        Stepper {
            text: `${Config.barMargin} px`
            onStep: d => Config.barMargin = settings.clamp(Config.barMargin + d * 2, 0, 40)
        }
    }

    SettingRow {
        label: "Shadow"
        normalOnly: true

        Switch {
            checked: Config.barShadow
            onToggled: Config.barShadow = !Config.barShadow
        }
    }

    SettingRow {
        label: "Clock"

        Stepper {
            text: Qt.formatDateTime(Time.date, Config.clockFormat)
            onStep: d => Config.clockFormat = settings.cycle(settings.clockFormats, Config.clockFormat, d)
        }
    }

    SettingRow {
        label: "Weather location"

        Rectangle {
            implicitWidth: Math.round(220 * Theme.textScale)
            implicitHeight: 34
            radius: Theme.smallRadius
            color: Theme.cardBg
            border.color: location.activeFocus ? Theme.accent : "transparent"
            border.width: Theme.borderWidth

            TextInput {
                id: location

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                clip: true
                text: Config.weatherLocation
                onEditingFinished: Config.weatherLocation = text.trim()

                StyledText {
                    anchors.fill: parent
                    visible: location.text === "" && !location.activeFocus
                    text: "Automatic"
                    color: Theme.dimText
                }
            }
        }
    }

    SettingRow {
        label: "Temperature unit"

        TextButton {
            text: Config.weatherFahrenheit ? "°F" : "°C"
            onClicked: Config.weatherFahrenheit = !Config.weatherFahrenheit
        }
    }

    // Modules per bar: the primary monitor's and the others'
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 16
        rowSpacing: 8

        StyledText {
            Layout.fillWidth: true
            text: "Module"
            color: Theme.subtext
            font.weight: Font.DemiBold
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Primary"
            color: Theme.subtext
            font.weight: Font.DemiBold
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Others"
            color: Theme.subtext
            font.weight: Font.DemiBold
        }

        Repeater {
            model: Config.barModules

            StyledText {
                required property var modelData
                required property int index

                Layout.row: index + 1
                Layout.column: 0
                Layout.fillWidth: true
                text: modelData.label
                color: Theme.foreground
            }
        }

        Repeater {
            model: Config.barModules

            Switch {
                required property var modelData
                required property int index

                Layout.row: index + 1
                Layout.column: 1
                Layout.alignment: Qt.AlignHCenter
                checked: Config.barShows(true, modelData.id)
                onToggled: Config.setBarModule(true, modelData.id, !checked)
            }
        }

        Repeater {
            model: Config.barModules

            Switch {
                required property var modelData
                required property int index

                Layout.row: index + 1
                Layout.column: 2
                Layout.alignment: Qt.AlignHCenter
                checked: Config.barShows(false, modelData.id)
                onToggled: Config.setBarModule(false, modelData.id, !checked)
            }
        }
    }
}
