import QtQuick
import QtQuick.Layouts
import qs.config

// A setting set by dragging: its name in small capitals with the value on the right ("95.0%"),
// the slider under them. `value` runs from `from` to `to`; changed() gives the new one, to a
// thousandth (a tenth of a percent).
ColumnLayout {
    id: root

    property string label
    property string hint: ""
    property real value: 0
    property real from: 0
    property real to: 1
    // shown as a percentage unless set
    property string valueText: `${(value * 100).toFixed(1)}%`
    // a key press or wheel step: a tenth of a percent, as shown (or as set)
    property real step: 0.001
    // fixed values (StyledSlider's ticks)
    property int ticks: 0
    // Only used in normal mode: dimmed and locked in Work and Game
    property bool normalOnly: false
    signal changed(real value)

    Layout.fillWidth: true
    enabled: !normalOnly || !Theme.gamemode
    opacity: enabled ? 1 : 0.4
    spacing: 4

    SectionLabel {
        text: root.label
        value: root.valueText
    }

    // the fill shows the value itself (90% fills 90% whatever the lowest allowed), and stops
    // at `from`
    SliderRow {
        value: root.value
        to: root.to
        step: root.step
        ticks: root.ticks
        onMoved: v => root.changed(Math.round(Math.max(root.from, v) * 1000) / 1000)
    }

    Caption {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.enabled ? root.hint : "Not used in Work and Game modes"
        color: Theme.dimText
        font.weight: Font.Normal
        font.capitalization: Font.MixedCase
        font.letterSpacing: 0
    }
}
