import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    name: "calendar"
    contentWidth: 300

    property int month: Time.date.getMonth()
    property int year: Time.date.getFullYear()

    function shift(delta: int): void {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    onShownChanged: {
        if (shown) {
            month = Time.date.getMonth();
            year = Time.date.getFullYear();
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy")
        color: Theme.subtext0
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        Layout.fillWidth: true

        IconButton {
            icon: Icons.chevronLeft
            onClicked: root.shift(-1)
        }

        StyledText {
            Layout.fillWidth: true
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
        }

        IconButton {
            icon: Icons.chevronRight
            onClicked: root.shift(1)
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: grid.locale
        delegate: StyledText {
            required property string shortName
            text: shortName
            color: Theme.accent2
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MonthGrid {
        id: grid

        Layout.fillWidth: true
        month: root.month
        year: root.year
        locale: Qt.locale()
        delegate: Item {
            id: day

            required property var model
            implicitHeight: 32

            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 15
                color: Theme.accent
                visible: day.model.today
            }

            StyledText {
                anchors.centerIn: parent
                text: day.model.day
                color: day.model.today ? Theme.base : (day.model.month === root.month ? Theme.text : Theme.overlay0)
                font.weight: day.model.today ? Font.Bold : Font.Normal
            }
        }
    }
}
