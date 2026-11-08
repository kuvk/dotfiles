import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The selected monitor: on/off, mode, scale, rotation, variable refresh, colors, depth, brightness, workspaces (Displays)
// Selected monitor
GridLayout {
    // the Displays panel: its monitors, selection and actions
    required property var panel

    Layout.fillWidth: true
    visible: panel.current !== null
    columns: 2
    columnSpacing: 16
    rowSpacing: 10

    StyledText {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        text: panel.current ? (panel.current.description || panel.current.name) : ""
        color: Theme.subtext
    }

    StyledText {
        text: "Enabled"
    }

    // The saved choice; with the lid closed and another monitor on, the laptop's
    // screen is off anyway (clamshell) and comes back as chosen here
    RowLayout {
        spacing: 10

        Switch {
            checked: panel.current?.enabled ?? false
            onToggled: panel.setEnabled(panel.selected, !checked)
        }

        StyledText {
            visible: !!panel.current?.lid_closed
            text: "Off while the lid is closed"
            color: Theme.dimText
            font.pixelSize: Theme.fontSize - 2
        }
    }

    StyledText {
        text: "Primary"
    }

    RowLayout {
        spacing: 10

        Switch {
            checked: panel.current !== null && panel.current.id === panel.primary
            onToggled: {
                panel.primary = panel.current.id;
                panel.dirty = true;
            }
        }

        StyledText {
            text: "Gets the first workspaces with Default"
            color: Theme.dimText
            font.pixelSize: Theme.fontSize - 2
        }
    }

    StyledText {
        text: "Resolution"
    }

    Stepper {
        enabled: panel.current?.enabled ?? false
        text: panel.current ? panel.current.mode.replace("@", " @ ") + " Hz" : ""
        onStep: delta => panel.setMode(panel.selected, panel.cycle(panel.current.modes, panel.current.mode, delta))
    }

    StyledText {
        text: "Scale"
    }

    Stepper {
        enabled: panel.current?.enabled ?? false
        text: panel.current ? `${Math.round(panel.current.scale * 1000) / 10}%  (${Math.round(panel.current.width)}×${Math.round(panel.current.height)})` : ""
        onStep: delta => panel.update(panel.selected, { scale: panel.cycle(panel.validScales(panel.current.mode), panel.current.scale, delta) })
    }

    StyledText {
        text: "Variable refresh"
        visible: vrrRow.visible
    }

    RowLayout {
        id: vrrRow

        visible: !!panel.current?.enabled && !!panel.current?.vrr_capable
        spacing: 10

        Stepper {
            text: panel.vrrNames[panel.current?.vrr ?? 0] ?? "Off"
            onStep: delta => panel.update(panel.selected, { vrr: ((panel.current.vrr ?? 0) + delta + 4) % 4 })
        }

        StyledText {
            text: "May blink when it switches"
            color: Theme.dimText
            font.pixelSize: Theme.fontSize - 2
        }
    }

    StyledText {
        text: "Colors"
    }

    Stepper {
        enabled: panel.current?.enabled ?? false
        text: panel.current ? (panel.colorNames[panel.current.cm] ?? panel.current.cm) : ""
        onStep: delta => panel.update(panel.selected, { cm: panel.cycle(panel.colorModes, panel.current.cm, delta) })
    }

    StyledText {
        text: "Color depth"
        visible: depthRow.visible
    }

    // Screens that take 10-bit (their EDID)
    RowLayout {
        id: depthRow

        visible: !!panel.current?.enabled && (panel.current?.max_bitdepth ?? 8) >= 10
        spacing: 10

        Stepper {
            text: `${panel.current?.bitdepth ?? 10}-bit`
            onStep: delta => panel.update(panel.selected, { bitdepth: (panel.current?.bitdepth ?? 10) === 10 ? 8 : 10 })
        }

        StyledText {
            text: "Smoother gradients"
            visible: (panel.current?.bitdepth ?? 10) === 10
            color: Theme.dimText
            font.pixelSize: Theme.fontSize - 2
        }
    }

    StyledText {
        text: "Brightness"
        visible: brightnessSlider.visible
        opacity: brightnessSlider.opacity
    }

    RowLayout {
        id: brightnessSlider

        readonly property var value: panel.current ? Displays.brightness[panel.current.name] : undefined

        Layout.fillWidth: true
        // Reading the brightness takes a moment after opening: the row keeps its place
        // meanwhile (invisible), so the window opens at its final size. Hidden for a monitor
        // without a brightness control (null).
        visible: !!panel.current?.enabled && value !== null
        opacity: value === undefined ? 0 : 1
        enabled: value !== undefined
        spacing: 10

        StyledSlider {
            Layout.fillWidth: true
            value: (brightnessSlider.value ?? 0) / 100
            color: Theme.accent
            onMoved: v => Displays.setBrightness(panel.current.name, Math.max(1, Math.round(v * 100)))
        }

        StyledText {
            Layout.preferredWidth: 40
            text: `${brightnessSlider.value ?? 0}%`
            color: Theme.subtext
        }
    }

    StyledText {
        text: "Workspaces"
    }

    ColumnLayout {
        spacing: 4

        RowLayout {
            spacing: 4

            Repeater {
                model: 10

                MouseArea {
                    id: wsChip

                    required property int index
                    readonly property int ws: index + 1
                    readonly property string owner: panel.workspaces[String(ws)] ?? ""
                    readonly property bool mine: panel.current !== null && owner === panel.current.id

                    implicitWidth: 30
                    implicitHeight: 30
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.toggleWorkspace(ws)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.smallRadius
                        color: wsChip.mine ? Theme.accent : (wsChip.containsMouse ? Theme.hoverBg : Theme.cardBg)
                        // assigned to another monitor
                        border.color: !wsChip.mine && wsChip.owner !== "" ? Theme.muted : "transparent"
                        border.width: Theme.borderWidth
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: wsChip.ws
                        color: wsChip.mine ? Theme.background : (wsChip.owner !== "" ? Theme.faintText : Theme.subtext)
                        font.weight: wsChip.mine ? Font.Bold : Font.Normal
                    }
                }
            }

            TextButton {
                text: "Default"
                onClicked: panel.defaultWorkspaces()
            }
        }

        StyledText {
            text: "Click to assign or unassign. Outlined: on another monitor."
            color: Theme.dimText
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
