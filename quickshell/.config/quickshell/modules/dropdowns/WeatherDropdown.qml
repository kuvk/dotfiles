import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.dropdowns.common

// Weather from wttr.in: now, a few details, and the days ahead
Dropdown {
    id: root

    name: "weather"
    contentWidth: 460

    onShownChanged: if (shown && Weather.ready && Date.now() - Weather.updated > 10 * 60 * 1000) Weather.refresh()

    Hero {
        icon: Weather.ready ? Weather.icon : Icons.weatherSunny
        iconColor: Weather.ready ? Theme.yellow : Theme.overlay1
        title: Weather.ready ? `${Weather.temp}${Weather.unit}` : "Weather"
        status: Weather.ready ? Weather.description.toUpperCase() : "WEATHER UNAVAILABLE"
    }

    GridLayout {
        Layout.fillWidth: true
        visible: Weather.ready
        columns: 4
        columnSpacing: 12
        rowSpacing: 4

        Label {
            text: "Feels like"
        }

        Value {
            text: `${Weather.feelsLike}${Weather.unit}`
        }

        Label {
            text: "Humidity"
        }

        Value {
            text: `${Weather.humidity}%`
        }

        Label {
            text: "Wind"
        }

        Value {
            text: `${Weather.wind} ${Weather.windUnit}`
        }

        Label {
            text: "Location"
        }

        Value {
            text: Weather.location || "--"
            elide: Text.ElideRight
        }
    }

    Separator {
        visible: Weather.ready
    }

    Caption {
        visible: Weather.ready
        text: "FORECAST"
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
                font.pixelSize: Theme.fontSize - 1
            }

            Icon {
                Layout.preferredWidth: 24
                text: Weather.iconFor(day.modelData.code, false)
                color: Theme.yellow
            }

            Label {
                Layout.fillWidth: true
                text: day.modelData.description
                elide: Text.ElideRight
            }

            Value {
                Layout.fillWidth: false
                text: `${day.modelData.max}° / ${day.modelData.min}°`
            }
        }
    }

    FooterLink {
        text: Weather.ready ? `Updated ${Qt.formatTime(Weather.updated, "HH:mm")} · wttr.in` : "Try again"
        onClicked: Weather.refresh()
    }
}
