import QtQuick
import qs.config

// Power menu / session icon: the theme's recolored SVG from
// ~/.config/theme/icons/<theme>/ (theme-icons.py), or the Nerd Font glyph
// when there is none.
Item {
    id: root

    required property var entry // an entry of System.sessionActions
    property real size: 18

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image

        anchors.fill: parent
        source: Theme.iconsDir !== "" ? `file://${Theme.iconsDir}/${root.entry.id}.svg` : ""
        sourceSize.width: Math.ceil(root.size * 2)
        sourceSize.height: Math.ceil(root.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    Icon {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: root.entry.icon
        color: Theme[root.entry.color]
        font.pixelSize: root.size
    }
}
