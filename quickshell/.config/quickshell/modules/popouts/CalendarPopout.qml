import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Month view with ISO week numbers, like the waybar/Omarchy calendar.
// Scroll or use the arrows to change month, click the title to go back to today.
Popout {
    id: root

    name: "calendar"
    contentWidth: 330

    property int month: Time.date.getMonth()
    property int year: Time.date.getFullYear()

    // 6 weeks starting on the Monday on or before the 1st
    readonly property var weeks: {
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - (first.getDay() + 6) % 7);
        const rows = [];
        for (let w = 0; w < 6; w++) {
            const days = [];
            for (let d = 0; d < 7; d++)
                days.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + d));
            rows.push({
                week: isoWeek(days[0]),
                days: days
            });
        }
        return rows;
    }

    function isoWeek(date: date): int {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    function shift(delta: int): void {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    function today(): void {
        month = Time.date.getMonth();
        year = Time.date.getFullYear();
    }

    onShownChanged: if (shown) today()

    StyledText {
        Layout.fillWidth: true
        text: Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy  ·  HH:mm:ss")
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
            color: Theme.accent
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize + 2
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.today()
            }
        }

        IconButton {
            icon: Icons.chevronRight
            onClicked: root.shift(1)
        }
    }

    GridLayout {
        id: grid

        Layout.fillWidth: true
        columns: 8
        rowSpacing: 2
        columnSpacing: 2

        // Scroll anywhere on the grid to change month
        WheelHandler {
            onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
        }

        Repeater {
            model: [1, 2, 3, 4, 5, 6, 0]

            StyledText {
                required property int modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Qt.locale().dayName(modelData, Locale.ShortFormat)
                color: modelData === 0 || modelData === 6 ? Theme.red : Theme.accent2
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "W"
            color: Theme.overlay1
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: root.weeks

            Repeater {
                id: week

                required property var modelData

                model: [...modelData.days, null]

                Item {
                    id: cell

                    required property var modelData
                    readonly property bool isWeek: modelData === null
                    readonly property bool inMonth: !isWeek && modelData.getMonth() === root.month
                    readonly property bool isToday: !isWeek && modelData.toDateString() === Time.date.toDateString()
                    readonly property bool weekend: !isWeek && (modelData.getDay() === 0 || modelData.getDay() === 6)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.accent
                        visible: cell.isToday
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: cell.isWeek ? `W${week.modelData.week}` : cell.modelData.getDate()
                        font.pixelSize: cell.isWeek ? Theme.fontSize - 2 : Theme.fontSize
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                        color: {
                            if (cell.isWeek)
                                return Theme.overlay1;
                            if (cell.isToday)
                                return Theme.base;
                            if (!cell.inMonth)
                                return Theme.surface2;
                            return cell.weekend ? Theme.red : Theme.text;
                        }
                    }
                }
            }
        }
    }
}
