import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A section's label in a dropdown or Settings: small capitals, bold, the text color darkened
StyledText {
    color: Theme.labelText
    font.capitalization: Font.AllUppercase
    font.pixelSize: Theme.captionSize
    font.weight: Font.Bold
    font.letterSpacing: 1.2
}
