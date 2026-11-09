import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A section's label in a dropdown: small, bold, the text color darkened
StyledText {
    color: Theme.labelText
    font.pixelSize: Theme.captionSize
    font.weight: Font.Bold
    font.letterSpacing: 1.2
}
