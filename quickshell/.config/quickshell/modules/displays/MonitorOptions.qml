import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The selected monitor's options, as Settings' options: on or off, primary, mode, scale,
// variable refresh, colors, depth, brightness and its workspaces (Displays)
ColumnLayout {
    // the DisplaysEditor: its monitors, selection and actions
    required property var panel

    Layout.fillWidth: true
    visible: panel.current !== null
    spacing: 12

    // The saved choice; with the lid closed and another monitor on, the laptop's screen is off
    // anyway (clamshell) and comes back as chosen here
    SettingRow {
        label: "Enabled"
        hint: panel.current?.lid_closed ? "Off while the lid is closed" : ""

        Switch {
            checked: panel.current?.enabled ?? false
            onToggled: panel.setEnabled(panel.selected, !checked)
        }
    }

    SettingRow {
        label: "Primary"
        hint: "Gets the first workspaces"

        Switch {
            checked: panel.current !== null && panel.current.id === panel.primary
            onToggled: {
                panel.primary = panel.current.id;
                panel.dirty = true;
            }
        }
    }

    SettingRow {
        label: "Resolution"

        Stepper {
            enabled: panel.current?.enabled ?? false
            text: panel.current ? panel.current.mode.replace("@", " @ ") + " Hz" : ""
            onStep: delta => panel.setMode(panel.selected, panel.cycle(panel.current.modes, panel.current.mode, delta))
        }
    }

    SettingRow {
        label: "Scale"

        Stepper {
            enabled: panel.current?.enabled ?? false
            text: panel.current ? `${Math.round(panel.current.scale * 1000) / 10}%  (${Math.round(panel.current.width)}×${Math.round(panel.current.height)})` : ""
            onStep: delta => panel.update(panel.selected, { scale: panel.cycle(panel.validScales(panel.current.mode), panel.current.scale, delta) })
        }
    }

    SettingRow {
        visible: !!panel.current?.enabled && !!panel.current?.vrr_capable
        label: "Variable refresh"
        hint: "May blink when it switches"

        Stepper {
            text: panel.vrrNames[panel.current?.vrr ?? 0] ?? "Off"
            onStep: delta => panel.update(panel.selected, { vrr: ((panel.current.vrr ?? 0) + delta + 4) % 4 })
        }
    }

    SettingRow {
        label: "Colors"

        Stepper {
            enabled: panel.current?.enabled ?? false
            text: panel.current ? (panel.colorNames[panel.current.cm] ?? panel.current.cm) : ""
            onStep: delta => panel.update(panel.selected, { cm: panel.cycle(panel.colorModes, panel.current.cm, delta) })
        }
    }

    // Screens that take 10-bit (their EDID)
    SettingRow {
        visible: !!panel.current?.enabled && (panel.current?.max_bitdepth ?? 8) >= 10
        label: "Color depth"
        hint: (panel.current?.bitdepth ?? 10) === 10 ? "Smoother gradients" : ""

        Stepper {
            text: `${panel.current?.bitdepth ?? 10}-bit`
            onStep: delta => panel.update(panel.selected, { bitdepth: (panel.current?.bitdepth ?? 10) === 10 ? 8 : 10 })
        }
    }

    // Reading the brightness takes a moment after opening: the slider keeps its place meanwhile
    // (invisible), so Displays opens at its final size. Hidden for a monitor without a
    // brightness control (null).
    SettingSlider {
        readonly property var level: panel.current ? Displays.brightness[panel.current.name] : undefined

        visible: !!panel.current?.enabled && level !== null
        opacity: level === undefined ? 0 : 1
        enabled: level !== undefined
        label: "Brightness"
        valueText: `${level ?? 0}%`
        value: (level ?? 0) / 100
        onChanged: v => Displays.setBrightness(panel.current.name, Math.max(1, Math.round(v * 100)))
    }

    SettingRow {
        label: "Workspaces"
        hint: "Outlined: assigned to another monitor"

        // a click assigns one to this monitor, or unassigns it
        Row {
            spacing: 4

            Repeater {
                model: 10

                MouseArea {
                    id: wsChip

                    required property int index
                    readonly property int ws: index + 1
                    readonly property string owner: panel.workspaces[String(ws)] ?? ""
                    readonly property bool mine: panel.current !== null && owner === panel.current.id

                    width: 30
                    height: 30
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
        }
    }
}
