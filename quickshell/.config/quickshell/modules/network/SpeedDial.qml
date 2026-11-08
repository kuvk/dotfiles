import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

// One speed test dial: an open 270° arc with the gap at the bottom, a tick ring, a needle
// fading toward the pivot and the figure in the middle. After Omarchy's SpeedTestOverlay
// (github.com/basecamp/omarchy, MIT).
Item {
    id: dial

    required property string label
    // the scale both dials share
    required property real fullScale
    required property real value
    required property bool live

    readonly property real diameter: 210
    // 0° is 3 o'clock, clockwise; the gap at the bottom
    readonly property real start: 135
    readonly property real sweep: 270
    readonly property int ticks: 46
    readonly property real arcWidth: 4
    readonly property real arcRadius: diameter / 2 - arcWidth
    // the dial that isn't measuring yet stays dim until it has a figure
    readonly property bool engaged: live || value > 0
    property real needle: 0
    // the figure shows the reading, not the sweep
    readonly property real reading: ignition.running ? value : needle
    readonly property real fraction: fullScale > 0 ? Math.max(0, Math.min(1, needle / fullScale)) : 0
    readonly property bool arcVisible: fraction > 0.004

    width: diameter
    height: diameter
    opacity: engaged ? 1 : 0.5

    function ignite(): void {
        ignition.restart();
    }

    onValueChanged: if (!ignition.running) needle = value

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDuration * 1.6
        }
    }

    // readings come a few times a second: glide between them
    Behavior on needle {
        enabled: !ignition.running

        NumberAnimation {
            duration: Theme.animDuration * 4
            easing.type: Easing.OutCubic
        }
    }

    // the needle sweeps to full scale and back before the readings take over
    SequentialAnimation {
        id: ignition

        NumberAnimation {
            target: dial
            property: "needle"
            to: fullScale
            duration: Theme.animDuration * 3.6
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: dial
            property: "needle"
            to: 0
            duration: Theme.animDuration * 4.3
            easing.type: Easing.OutCubic
        }

        onFinished: dial.needle = dial.value
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // the whole scale
        ShapePath {
            strokeWidth: dial.arcWidth
            strokeColor: Theme.alpha(Theme.foreground, 0.14)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: dial.width / 2
                centerY: dial.height / 2
                radiusX: dial.arcRadius
                radiusY: dial.arcRadius
                startAngle: dial.start
                sweepAngle: dial.sweep
            }
        }

        // a soft glow under the value
        ShapePath {
            strokeWidth: dial.arcWidth * 3
            strokeColor: dial.arcVisible ? Theme.alpha(Theme.accent, 0.18) : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: dial.width / 2
                centerY: dial.height / 2
                radiusX: dial.arcRadius
                radiusY: dial.arcRadius
                startAngle: dial.start
                sweepAngle: dial.sweep * dial.fraction
            }
        }

        ShapePath {
            strokeWidth: dial.arcWidth
            strokeColor: dial.arcVisible ? Theme.accent : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: dial.width / 2
                centerY: dial.height / 2
                radiusX: dial.arcRadius
                radiusY: dial.arcRadius
                startAngle: dial.start
                sweepAngle: dial.sweep * dial.fraction
            }
        }
    }

    // tick ring inside the arc, every fifth a major one
    Repeater {
        model: dial.ticks

        Item {
            required property int index
            readonly property bool major: index % 5 === 0

            anchors.fill: parent
            rotation: dial.start + index / (dial.ticks - 1) * dial.sweep - 270

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.arcWidth * 2 + (parent.major ? 0 : 2)
                width: parent.major ? 2 : 1
                height: parent.major ? 10 : 6
                radius: width / 2
                color: Theme.alpha(Theme.foreground, parent.major ? 0.3 : 0.12)
            }
        }
    }

    // the needle, fading toward the middle
    Item {
        anchors.fill: parent
        rotation: dial.start + dial.fraction * dial.sweep - 270

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.arcWidth * 2 + 10
            width: 3
            height: dial.diameter * 0.32
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.accent
                }

                GradientStop {
                    position: 0.55
                    color: Theme.accent
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: 14

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.reading.toFixed(dial.reading < 10 ? 1 : 0)
            font.pixelSize: Theme.fontSize * 2.6
            font.weight: Font.Bold
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Mb/s"
            color: Theme.subtext
            font.pixelSize: Theme.fontSize - 1
        }
    }

    // the direction in the gap at the bottom
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: dial.label
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 1
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }
}
