pragma Singleton

import QtQuick
import Quickshell

// Nerd Font glyphs, by code point so they survive editors and copy/paste
Singleton {
    function g(cp: int): string {
        return String.fromCodePoint(cp);
    }

    readonly property string arch: g(0xf303)
    readonly property string search: g(0xf002)
    readonly property string power: g(0xf011)
    readonly property string close: g(0xf00d)
    readonly property string trash: g(0xf1f8)
    readonly property string check: g(0xf00c)
    readonly property string chevronRight: g(0xf054)
    readonly property string chevronLeft: g(0xf053)
    readonly property string cog: g(0xf013)
    readonly property string refresh: g(0xf021)
    readonly property string lock: g(0xf023)
    readonly property string palette: g(0xf1fc)
    readonly property string sun: g(0xf185)
    readonly property string moon: g(0xf186)
    readonly property string nightlight: g(0xf4ee)
    readonly property string gamepad: g(0xf11b)
    readonly property string keyboard: g(0xf11c)
    readonly property string calendar: g(0xf073)
    readonly property string coffee: g(0xf0f4)
    readonly property string rocket: g(0xf135)
    readonly property string sliders: g(0xf1de)
    readonly property string display: g(0xf108)
    readonly property string text: g(0xf031)
    readonly property string signOut: g(0xf08b)
    readonly property string bed: g(0xf236)
    readonly property string reboot: g(0xf01e)
    readonly property string user: g(0xf007)
    readonly property string mapMarker: g(0xf041)
    readonly property string tint: g(0xf043)
    readonly property string wind: g(0xf059d)

    // Weather (nf-weather)
    readonly property string weatherSunny: g(0xe30d)
    readonly property string weatherNight: g(0xe32b)
    readonly property string weatherPartly: g(0xe302)
    readonly property string weatherCloudy: g(0xe312)
    readonly property string weatherFog: g(0xe313)
    readonly property string weatherShowers: g(0xe319)
    readonly property string weatherRain: g(0xe318)
    readonly property string weatherSleet: g(0xe3ad)
    readonly property string weatherSnow: g(0xe31a)
    readonly property string weatherThunder: g(0xe31d)

    readonly property string workspace: g(0xf10c)
    readonly property string workspaceActive: g(0xf192)

    // Audio
    readonly property string volumeOff: g(0xf026)
    readonly property string volumeLow: g(0xf027)
    readonly property string volumeHigh: g(0xf028)
    readonly property string volumeMuted: g(0xeee8)
    readonly property string headphones: g(0xf025)
    readonly property string mic: g(0xf130)
    readonly property string micMuted: g(0xf131)

    // Media
    readonly property string music: g(0xf001)
    readonly property string play: g(0xf04b)
    readonly property string pause: g(0xf04c)
    readonly property string next: g(0xf051)
    readonly property string previous: g(0xf048)
    readonly property string spotify: g(0xf1bc)
    readonly property string vlc: g(0xf057c)
    readonly property string firefox: g(0xf269)
    readonly property string globe: g(0xf0ac)
    readonly property string chrome: g(0xf268)

    // Network
    readonly property var wifiLevels: [g(0xf092f), g(0xf091f), g(0xf0922), g(0xf0925), g(0xf0928)]
    readonly property string wifiOff: g(0xf092d)
    readonly property string wifiUnknown: g(0xf092b)
    readonly property string ethernet: g(0xf0200)
    readonly property string linked: g(0xf0319)
    readonly property string shield: g(0xf132)
    readonly property string gauge: g(0xf0e4)
    readonly property string arrowDown: g(0xf063)
    readonly property string arrowUp: g(0xf062)
    readonly property string plus: g(0xf067)
    readonly property string info: g(0xf05a)

    // Bluetooth
    readonly property string bluetooth: g(0xf00af)
    readonly property string bluetoothConnected: g(0xf00b1)
    readonly property string bluetoothOff: g(0xf00b2)

    // Battery
    readonly property var batteryLevels: [g(0xf008e), g(0xf007a), g(0xf007b), g(0xf007c), g(0xf007d), g(0xf007e), g(0xf007f), g(0xf0080), g(0xf0081), g(0xf0082), g(0xf0079)]
    readonly property string batteryCharging: g(0xf140b)
    readonly property string batteryFull: g(0xf0084)

    // Notifications
    readonly property string bell: g(0xf009a)
    readonly property string bellBadge: g(0xf116b)
    readonly property string bellDnd: g(0xf00a0)
    readonly property string clearAll: g(0xf039f)
}
