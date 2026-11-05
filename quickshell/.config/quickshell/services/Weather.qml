pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Current conditions and a 3-day forecast from wttr.in
Singleton {
    id: root

    property bool ready: false
    property string location: ""
    property string description: ""
    property int temp: 0
    property int feelsLike: 0
    property int humidity: 0
    property int wind: 0
    property int code: 113
    property var forecast: [] // { date, max, min, code, description }
    property date updated

    readonly property string unit: Config.weatherFahrenheit ? "°F" : "°C"
    readonly property string windUnit: Config.weatherFahrenheit ? "mph" : "km/h"
    readonly property string icon: iconFor(code, true)

    function refresh(): void {
        proc.running = true;
    }

    // Settings changes refetch right away
    readonly property string query: Config.weatherLocation + Config.weatherFahrenheit
    onQueryChanged: refresh()

    // WWO weather codes used by wttr.in
    function iconFor(code: int, current: bool): string {
        const hour = new Date().getHours();
        const night = current && (hour < 6 || hour >= 20);
        if (code === 113)
            return night ? Icons.weatherNight : Icons.weatherSunny;
        if (code === 116)
            return Icons.weatherPartly;
        if ([119, 122].includes(code))
            return Icons.weatherCloudy;
        if ([143, 248, 260].includes(code))
            return Icons.weatherFog;
        if ([200, 386, 389, 392, 395].includes(code))
            return Icons.weatherThunder;
        if ([179, 182, 185, 281, 284, 311, 314, 317, 350, 362, 365, 374, 377].includes(code))
            return Icons.weatherSleet;
        if ([227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(code))
            return Icons.weatherSnow;
        if ([176, 263, 266, 293, 296, 353].includes(code))
            return Icons.weatherShowers;
        return Icons.weatherRain;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: Config.weatherInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Retry sooner while offline
    Timer {
        interval: 60 * 1000
        running: !root.ready
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc

        command: ["curl", "-sf", "--max-time", "15", `https://wttr.in/${encodeURIComponent(Config.weatherLocation)}?format=j1`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text)
                    return;
                try {
                    const d = JSON.parse(text);
                    const f = Config.weatherFahrenheit;
                    const cur = d.current_condition[0];
                    const area = d.nearest_area?.[0];
                    root.location = Config.weatherLocation || (area ? `${area.areaName[0].value}, ${area.country[0].value}` : "");
                    root.description = cur.weatherDesc[0].value.trim();
                    root.temp = parseInt(f ? cur.temp_F : cur.temp_C);
                    root.feelsLike = parseInt(f ? cur.FeelsLikeF : cur.FeelsLikeC);
                    root.humidity = parseInt(cur.humidity);
                    root.wind = parseInt(f ? cur.windspeedMiles : cur.windspeedKmph);
                    root.code = parseInt(cur.weatherCode);
                    root.forecast = d.weather.map(day => {
                        const noon = day.hourly[Math.min(4, day.hourly.length - 1)];
                        return {
                            date: day.date,
                            max: parseInt(f ? day.maxtempF : day.maxtempC),
                            min: parseInt(f ? day.mintempF : day.mintempC),
                            code: parseInt(noon.weatherCode),
                            description: noon.weatherDesc[0].value.trim()
                        };
                    });
                    root.updated = new Date();
                    root.ready = true;
                } catch (e) {
                    console.warn("Weather: could not parse wttr.in response", e);
                }
            }
        }
    }
}
