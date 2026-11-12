import QtQuick
import qs.config

// Where the keyboard is (Nav: Tab, arrows, Ctrl+H/J/K/L): an accent outline on the control's
// edge, the same on every control, with the shell's corners (Theme.smallRadius: square with the
// corner radius at 0 and in Work-Game); a switch passes its own pill shape, square there too.
// Inside the edge by default, so a page's edge never cuts it; a control whose icon or text
// reaches its edge (an icon button, a section's title) sets `outset` (or one side's) to draw it
// around them instead.
Rectangle {
    property Item target: parent
    property real cornerRadius: Theme.smallRadius
    property real outset: 0
    property real leftOutset: outset
    property real rightOutset: outset
    property real topOutset: outset
    property real bottomOutset: outset

    x: -leftOutset
    y: -topOutset
    width: parent.width + leftOutset + rightOutset
    height: parent.height + topOutset + bottomOutset
    visible: target.activeFocus
    color: "transparent"
    border.color: Theme.accent
    border.width: 2
    radius: cornerRadius
    z: 100
}
