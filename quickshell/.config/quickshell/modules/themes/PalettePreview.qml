import QtQuick
import qs.config

// A small mock desktop in a theme's colors for the theme carousel: a bar,
// a window with a few lines of code, and the palette as swatches.
Rectangle {
    id: root

    property var colors: ({})
    property string title: ""

    function c(name: string): color {
        return colors[name] ?? "#808080";
    }

    color: c("crust")

    // Bar
    Rectangle {
        id: bar

        width: parent.width
        height: parent.height * 0.075
        color: root.c("base")

        Row {
            anchors.left: parent.left
            anchors.leftMargin: parent.height * 0.4
            anchors.verticalCenter: parent.verticalCenter
            spacing: parent.height * 0.25

            Repeater {
                model: 5

                Rectangle {
                    required property int index

                    width: bar.height * (index === 0 ? 0.9 : 0.35)
                    height: bar.height * 0.35
                    radius: height / 2
                    color: index === 0 ? root.c("accent") : root.c("surface1")
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "12:30"
            color: root.c("text")
            font.family: Theme.font
            font.pixelSize: bar.height * 0.45
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: parent.height * 0.4
            anchors.verticalCenter: parent.verticalCenter
            spacing: parent.height * 0.3

            Repeater {
                model: ["blue", "green", "yellow", "red"]

                Rectangle {
                    required property string modelData

                    width: bar.height * 0.32
                    height: width
                    radius: width / 2
                    color: root.c(modelData)
                }
            }
        }
    }

    // Window
    Rectangle {
        id: win

        x: parent.width * 0.07
        y: bar.height + parent.height * 0.06
        width: parent.width * 0.86
        height: parent.height * 0.62
        radius: parent.height * 0.02
        color: root.c("base")
        border.color: root.c("accent")
        border.width: Math.max(1, parent.height * 0.005)

        // title strip
        Rectangle {
            id: strip

            width: parent.width
            height: parent.height * 0.12
            topLeftRadius: win.radius
            topRightRadius: win.radius
            color: root.c("mantle")

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: parent.height * 0.5
                text: root.title
                color: root.c("subtext0")
                font.family: Theme.font
                font.pixelSize: strip.height * 0.5
            }
        }

        // code lines: [indent, [[color, width]...]]
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: strip.bottom
            anchors.margins: win.height * 0.07
            spacing: win.height * 0.055

            Repeater {
                model: [
                    [0, [["mauve", 0.12], ["blue", 0.22], ["overlay1", 0.08]]],
                    [1, [["red", 0.1], ["text", 0.18], ["peach", 0.08]]],
                    [1, [["mauve", 0.08], ["green", 0.34]]],
                    [2, [["teal", 0.14], ["text", 0.1], ["yellow", 0.12]]],
                    [1, [["overlay0", 0.42]]],
                    [0, [["pink", 0.06]]]
                ]

                Row {
                    required property var modelData

                    x: modelData[0] * win.width * 0.05
                    spacing: win.width * 0.015

                    Repeater {
                        model: parent.modelData[1]

                        Rectangle {
                            required property var modelData

                            width: win.width * modelData[1]
                            height: win.height * 0.045
                            radius: height / 2
                            color: root.c(modelData[0])
                        }
                    }
                }
            }
        }
    }

    // Palette swatches
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.06
        spacing: parent.height * 0.02

        Repeater {
            model: ["accent", "accent2", "red", "peach", "yellow", "green", "teal", "blue", "mauve", "text"]

            Rectangle {
                required property string modelData

                width: root.height * 0.07
                height: width
                radius: width / 2
                color: root.c(modelData)
                border.color: root.c("surface1")
                border.width: 1
            }
        }
    }
}
