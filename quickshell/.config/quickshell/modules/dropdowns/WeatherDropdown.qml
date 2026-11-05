import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Dropdown {
    id: root

    name: "weather"
    contentWidth: 320

    onShownChanged: if (shown && Weather.ready && Date.now() - Weather.updated > 10 * 60 * 1000) Weather.refresh()

    StyledText {
        Layout.fillWidth: true
        visible: !Weather.ready
        text: "Weather unavailable"
        color: Theme.subtext0
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Weather.ready
        spacing: 14

        Icon {
            text: Weather.icon
            color: Theme.yellow
            font.pixelSize: 40
            Layout.preferredWidth: 56
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: `${Weather.temp}${Weather.unit}`
                font.pixelSize: 28
                font.weight: Font.Bold
            }

            StyledText {
                Layout.fillWidth: true
                text: Weather.description
                color: Theme.subtext0
            }

            StyledText {
                Layout.fillWidth: true
                text: `${Icons.mapMarker}  ${Weather.location}`
                color: Theme.overlay1
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Weather.ready
        spacing: 8

        Repeater {
            model: [
                { icon: Icons.weatherSunny, label: "Feels like", value: `${Weather.feelsLike}${Weather.unit}` },
                { icon: Icons.tint, label: "Humidity", value: `${Weather.humidity}%` },
                { icon: Icons.wind, label: "Wind", value: `${Weather.wind} ${Weather.windUnit}` }
            ]

            Card {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 54

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.value
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.label
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }

    Repeater {
        model: Weather.ready ? Weather.forecast : []

        RowLayout {
            id: day

            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: 10

            StyledText {
                Layout.preferredWidth: 90
                text: day.index === 0 ? "Today" : Qt.formatDate(new Date(day.modelData.date + "T12:00:00"), "dddd")
            }

            Icon {
                Layout.preferredWidth: 24
                text: Weather.iconFor(day.modelData.code, false)
                color: Theme.yellow
            }

            StyledText {
                Layout.fillWidth: true
                text: day.modelData.description
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 1
            }

            StyledText {
                text: `${day.modelData.max}° / ${day.modelData.min}°`
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Weather.ready
        text: `Updated ${Qt.formatTime(Weather.updated, "HH:mm")} · wttr.in`
        color: Theme.overlay0
        font.pixelSize: Theme.fontSize - 2
        horizontalAlignment: Text.AlignRight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Weather.refresh()
        }
    }
}
