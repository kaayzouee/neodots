pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

Singleton {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function pad(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function formatTime(date) {
        let hours = date.getHours();
        const minutes = date.getMinutes();
        const meridiem = hours >= 12 ? "PM" : "AM";

        hours %= 12;
        if (hours === 0)
            hours = 12;

        return hours + ":" + root.pad(minutes) + " " + meridiem;
    }

    function formatDate(date) {
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const months = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];

        return days[date.getDay()] + " "
            + months[date.getMonth()] + " "
            + date.getDate();
    }

    function refreshNetwork() {
        if (!networkProcess.running)
            networkProcess.running = true;
    }

    function refreshBattery() {
        if (!batteryProcess.running)
            batteryProcess.running = true;
    }

    function refreshVolume() {
        if (!volumeProcess.running)
            volumeProcess.running = true;
    }

    function refreshWorkspace() {
        if (!workspaceProcess.running)
            workspaceProcess.running = true;
    }

    function setVolumePercent(percent) {
        const clamped = Math.max(0, Math.min(100, Math.round(percent)));
        Quickshell.execDetached({
            command: [
                "wpctl",
                "set-volume",
                "@DEFAULT_AUDIO_SINK@",
                (clamped / 100).toFixed(2)
            ]
        });
        root.volumePercent = clamped;
        root.volumeText = clamped + "%";
    }

    function adjustVolume(delta) {
        root.setVolumePercent(
            (root.volumePercent >= 0 ? root.volumePercent : 50) + delta
        );
    }

    function toggleMute() {
        Quickshell.execDetached({
            command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        });
    }

    function refreshNetworkConnections() {
        if (!networkConnectionProcess.running)
            networkConnectionProcess.running = true;
    }

    function toggleWifi() {
        Quickshell.execDetached({
            command: [
                "nmcli",
                "radio",
                "wifi",
                root.wifiEnabled ? "off" : "on"
            ]
        });
        root.refreshNetwork();
        root.refreshNetworkConnections();
    }

    function refreshBluetooth() {
        if (!bluetoothProcess.running)
            bluetoothProcess.running = true;
        if (!bluetoothDevicesProcess.running)
            bluetoothDevicesProcess.running = true;
    }

    function toggleBluetooth() {
        if (!root.bluetoothAvailable)
            return;

        Quickshell.execDetached({
            command: [
                "bluetoothctl",
                "power",
                root.bluetoothPowered ? "off" : "on"
            ]
        });
    }

    readonly property date now: clock.date
    readonly property string timeText: root.formatTime(clock.date)
    readonly property string dateText: root.formatDate(clock.date)
    readonly property string dateTimeText: root.dateText + "  " + root.timeText

    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property string activeAppId: root.activeToplevel?.appId ?? ""
    readonly property string activeTitle: root.activeToplevel?.title ?? ""

    readonly property var battery:
        UPower.devices.values.find(device => device.isLaptopBattery)
        || UPower.displayDevice
    property real fallbackBatteryPercent: -1
    property string fallbackBatteryState: ""

    readonly property bool batteryReady:
        root.fallbackBatteryPercent >= 0
        || (root.battery?.ready ?? false)

    readonly property real batteryPercent: {
        if (root.fallbackBatteryPercent >= 0)
            return root.fallbackBatteryPercent;

        const raw = root.battery?.percentage ?? 0;
        return raw <= 1 ? raw * 100 : raw;
    }

    readonly property bool batteryHasSysfsState:
        root.fallbackBatteryState !== ""

    readonly property bool onBattery:
        root.batteryHasSysfsState
            ? root.fallbackBatteryState === "Discharging"
            : UPower.onBattery

    readonly property bool batteryCharging:
        root.batteryHasSysfsState
            ? root.fallbackBatteryState === "Charging"
            : root.battery?.ready
                ? root.battery.state === UPowerDeviceState.Charging
                || root.battery.state === UPowerDeviceState.PendingCharge
                : false

    readonly property string batteryStatusText:
        root.batteryHasSysfsState
            ? root.fallbackBatteryState === "Charging"
                ? "Charging"
                : root.fallbackBatteryState === "Discharging"
                    ? "Battery Power"
                    : root.fallbackBatteryState
            : root.batteryCharging
                ? "Charging"
                : root.onBattery
                    ? "Battery Power"
                    : "Power Adapter"

    property string networkName: ""
    property bool networkConnected: false
    property int networkSignal: 0
    property bool wifiEnabled: true

    property bool bluetoothAvailable: false
    property bool bluetoothPowered: false
    property string bluetoothConnectedDevice: ""

    readonly property bool bluetoothConnected:
        root.bluetoothConnectedDevice !== ""

    readonly property string bluetoothStatusText:
        !root.bluetoothAvailable
            ? "Unavailable"
            : !root.bluetoothPowered
                ? "Bluetooth Off"
                : root.bluetoothConnected
                    ? root.bluetoothConnectedDevice
                    : "Disconnected"

    property string volumeText: "—"
    property real volumePercent: -1
    property bool volumeMuted: false
    property string workspaceText: ""

    Process {
        id: networkProcess

        command: ["nmcli", "-t", "-f", "WIFI", "g"]
        running: true

        stdout: StdioCollector {
            id: networkCollector

            onStreamFinished: {
                root.wifiEnabled = networkCollector.text.trim().includes("enabled");
                root.refreshNetworkConnections();
            }
        }
    }

    Process {
        id: networkConnectionProcess

        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi"]
        running: true

        stdout: StdioCollector {
            id: networkConnectionCollector

            onStreamFinished: {
                const lines = networkConnectionCollector.text.trim().split("\n");
                const active = lines.find(line => line.startsWith("*:"));

                if (!active) {
                    root.networkConnected = false;
                    root.networkName = "";
                    root.networkSignal = 0;
                    return;
                }

                const fields = active.split(":");
                const signalText = fields.pop();
                const name = fields.slice(1).join(":");

                root.networkConnected = true;
                root.networkName = name || "Wi-Fi";
                root.networkSignal = Number.parseInt(signalText, 10) || 0;
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            root.refreshNetwork();
            root.refreshNetworkConnections();
        }
    }

    Process {
        id: bluetoothProcess

        command: ["bluetoothctl", "show"]
        running: true

        stdout: StdioCollector {
            id: bluetoothCollector

            onStreamFinished: {
                const value = bluetoothCollector.text.trim();
                const powered = value.match(/Powered:\s*(yes|no)/i);

                root.bluetoothAvailable = /^Controller\s+/im.test(value);
                root.bluetoothPowered = powered
                    ? powered[1].toLowerCase() === "yes"
                    : false;
            }
        }
    }

    Process {
        id: bluetoothDevicesProcess

        command: ["bluetoothctl", "devices", "Connected"]
        running: true

        stdout: StdioCollector {
            id: bluetoothDevicesCollector

            onStreamFinished: {
                const lines = bluetoothDevicesCollector.text
                    .trim()
                    .split("\\n")
                    .filter(line => /^Device\\s+/i.test(line));
                root.bluetoothConnectedDevice = lines.length > 0
                    ? lines[0].replace(/^Device\\s+\\S+\\s*/i, "").trim()
                        || "Connected device"
                    : "";
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refreshBluetooth()
    }

    Process {
        id: batteryProcess

        command: [
            "sh",
            "-c",
            "for d in /sys/class/power_supply/BAT*; do if [ -r \"$d/capacity\" ]; then printf '%s|%s\\n' \"$(cat \"$d/capacity\")\" \"$(cat \"$d/status\" 2>/dev/null || true)\"; exit 0; fi; done"
        ]
        running: true

        stdout: StdioCollector {
            id: batteryCollector

            onStreamFinished: {
                const value = batteryCollector.text.trim();
                if (!value)
                    return;

                const parts = value.split("|");
                const percent = Number.parseFloat(parts[0]);

                if (Number.isFinite(percent))
                    root.fallbackBatteryPercent = percent;

                root.fallbackBatteryState = parts[1] || "";
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refreshBattery()
    }

    Process {
        id: volumeProcess

        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true"]
        running: true

        stdout: StdioCollector {
            id: volumeCollector

            onStreamFinished: {
                const value = volumeCollector.text.trim();
                root.volumeMuted = value.includes("[MUTED]");

                const match = value.match(/([0-9]+(?:\.[0-9]+)?)/);
                root.volumePercent = match
                    ? Math.round(parseFloat(match[1]) * 100)
                    : -1;

                root.volumeText = root.volumePercent >= 0
                    ? root.volumePercent + "%"
                    : "—";
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshVolume()
    }

    Process {
        id: workspaceProcess

        command: ["sh", "-c", "riverctl list-tags 2>/dev/null || true"]
        running: true

        stdout: StdioCollector {
            id: workspaceCollector

            onStreamFinished: {
                root.workspaceText = workspaceCollector.text.trim().replace(/\s+/g, " ");
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refreshWorkspace()
    }
}
