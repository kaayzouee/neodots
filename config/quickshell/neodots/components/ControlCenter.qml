import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import "../services"

PopupWindow {
    id: root

    required property Item anchorItem

    readonly property real panelWidth: Math.min(Screen.width * 0.33, Screen.height * 0.48)
    readonly property real contentInset: panelWidth * 0.045
    readonly property real sectionGap: panelWidth * 0.028
    readonly property real modulePadding: panelWidth * 0.032
    readonly property real blockSize:
        (panelWidth - contentInset * 2 - sectionGap) / 2
    readonly property real titleSize: panelWidth * 0.03
    readonly property real detailSize: panelWidth * 0.024
    readonly property real panelCornerRadius: 51

    anchor.item: root.anchorItem
    anchor.rect.y: root.anchorItem.height + 10
    anchor.rect.x: -root.implicitWidth * 0.77

    implicitWidth: panelWidth
    implicitHeight: contentLayout.implicitHeight + root.contentInset * 2
    color: "transparent"
    visible: false
    grabFocus: true

    Rectangle {
        id: panelSurface

        anchors.fill: parent
        radius: root.panelCornerRadius
        color: Qt.rgba(0.08, 0.09, 0.12, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: root.contentInset
        spacing: root.sectionGap

        RowLayout {
            id: connectivityGrid

            Layout.fillWidth: true
            Layout.preferredHeight: root.blockSize
            spacing: root.sectionGap

            ColumnLayout {
                id: connectivityStack

                Layout.preferredWidth: root.blockSize
                Layout.fillHeight: true
                spacing: root.sectionGap

                Rectangle {
                    id: wifiCard

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Math.min(root.panelCornerRadius * 0.45, height * 0.28)
                    color: SystemState.networkConnected
                        ? Qt.rgba(0.20, 0.38, 0.72, 0.32)
                        : Qt.rgba(1, 1, 1, 0.075)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root.modulePadding
                        spacing: root.sectionGap * 0.55

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.detailSize * 0.35

                            Text {
                                text: "Wi-Fi"
                                color: "#ffffff"
                                font.pixelSize: root.titleSize
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: !SystemState.wifiEnabled
                                    ? "Wi-Fi Off"
                                    : SystemState.networkConnected
                                        ? (SystemState.networkName || "Connected")
                                        : "Disconnected"
                                color: Qt.rgba(1, 1, 1, 0.64)
                                font.pixelSize: root.detailSize
                                elide: Text.ElideRight
                            }
                        }

                        Canvas {
                            id: wifiIcon

                            Layout.preferredWidth: root.blockSize * 0.23
                            Layout.preferredHeight: root.blockSize * 0.23

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.strokeStyle = "#ffffff";
                                ctx.fillStyle = "#ffffff";
                                ctx.lineWidth = Math.max(1.5, width * 0.065);

                                const cx = width * 0.5;
                                const cy = height * 0.66;
                                for (let i = 0; i < 3; i++) {
                                    ctx.beginPath();
                                    ctx.arc(
                                        cx,
                                        cy,
                                        width * (0.43 - i * 0.13),
                                        Math.PI * 1.22,
                                        Math.PI * 1.78
                                    );
                                    ctx.stroke();
                                }

                                ctx.beginPath();
                                ctx.arc(cx, height * 0.84, width * 0.055, 0, Math.PI * 2);
                                ctx.fill();

                                if (!SystemState.wifiEnabled || !SystemState.networkConnected) {
                                    ctx.beginPath();
                                    ctx.lineWidth = Math.max(2, width * 0.085);
                                    ctx.moveTo(width * 0.20, height * 0.22);
                                    ctx.lineTo(width * 0.80, height * 0.80);
                                    ctx.stroke();
                                }
                            }

                            Connections {
                                target: SystemState

                                function onWifiEnabledChanged() {
                                    wifiIcon.requestPaint();
                                }

                                function onNetworkConnectedChanged() {
                                    wifiIcon.requestPaint();
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: SystemState.toggleWifi()
                    }
                }

                Rectangle {
                    id: bluetoothCard

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Math.min(root.panelCornerRadius * 0.45, height * 0.28)
                    color: SystemState.bluetoothConnected
                        ? Qt.rgba(0.20, 0.38, 0.72, 0.32)
                        : Qt.rgba(1, 1, 1, 0.075)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root.modulePadding
                        spacing: root.sectionGap * 0.55

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.detailSize * 0.35

                            Text {
                                text: "Bluetooth"
                                color: "#ffffff"
                                font.pixelSize: root.titleSize
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: SystemState.bluetoothStatusText
                                color: Qt.rgba(1, 1, 1, 0.64)
                                font.pixelSize: root.detailSize
                                elide: Text.ElideRight
                            }
                        }

                        Canvas {
                            id: bluetoothIcon

                            Layout.preferredWidth: root.blockSize * 0.23
                            Layout.preferredHeight: root.blockSize * 0.23

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.strokeStyle = "#ffffff";
                                ctx.lineWidth = Math.max(1.7, width * 0.075);

                                const cx = width * 0.5;
                                const cy = height * 0.5;
                                ctx.beginPath();
                                ctx.moveTo(cx, height * 0.08);
                                ctx.lineTo(cx, height * 0.92);
                                ctx.moveTo(cx, cy);
                                ctx.lineTo(width * 0.76, height * 0.27);
                                ctx.lineTo(cx, height * 0.08);
                                ctx.lineTo(cx, height * 0.92);
                                ctx.lineTo(width * 0.76, height * 0.73);
                                ctx.lineTo(cx, cy);
                                ctx.lineTo(width * 0.24, height * 0.29);
                                ctx.moveTo(cx, cy);
                                ctx.lineTo(width * 0.24, height * 0.71);
                                ctx.stroke();

                                if (!SystemState.bluetoothPowered || !SystemState.bluetoothConnected) {
                                    ctx.beginPath();
                                    ctx.lineWidth = Math.max(2, width * 0.085);
                                    ctx.moveTo(width * 0.18, height * 0.18);
                                    ctx.lineTo(width * 0.82, height * 0.82);
                                    ctx.stroke();
                                }
                            }

                            Connections {
                                target: SystemState

                                function onBluetoothPoweredChanged() {
                                    bluetoothIcon.requestPaint();
                                }

                                function onBluetoothConnectedChanged() {
                                    bluetoothIcon.requestPaint();
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: SystemState.toggleBluetooth()
                    }
                }
            }

            Rectangle {
                id: calendarCard

                Layout.preferredWidth: root.blockSize
                Layout.fillHeight: true
                radius: Math.min(root.panelCornerRadius * 0.45, height * 0.28)
                color: Qt.rgba(1, 1, 1, 0.075)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.modulePadding
                    spacing: root.sectionGap * 0.5

                    Text {
                        text: "Calendar"
                        color: "#ffffff"
                        font.pixelSize: root.titleSize
                        font.weight: Font.DemiBold
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Canvas {
                            anchors.centerIn: parent
                            width: root.blockSize * 0.36
                            height: width

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.78);
                                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.78);
                                ctx.lineWidth = Math.max(1.5, width * 0.045);
                                ctx.lineJoin = "round";

                                ctx.beginPath();
                                ctx.roundRect(
                                    width * 0.12,
                                    height * 0.20,
                                    width * 0.76,
                                    height * 0.68,
                                    width * 0.08,
                                    height * 0.08
                                );
                                ctx.stroke();

                                ctx.beginPath();
                                ctx.moveTo(width * 0.12, height * 0.39);
                                ctx.lineTo(width * 0.88, height * 0.39);
                                ctx.moveTo(width * 0.32, height * 0.10);
                                ctx.lineTo(width * 0.32, height * 0.29);
                                ctx.moveTo(width * 0.68, height * 0.10);
                                ctx.lineTo(width * 0.68, height * 0.29);
                                ctx.stroke();

                                for (let row = 0; row < 2; row++) {
                                    for (let col = 0; col < 3; col++) {
                                        ctx.beginPath();
                                        ctx.arc(
                                            width * (0.30 + col * 0.20),
                                            height * (0.53 + row * 0.17),
                                            width * 0.025,
                                            0,
                                            Math.PI * 2
                                        );
                                        ctx.fill();
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Coming soon"
                        color: Qt.rgba(1, 1, 1, 0.44)
                        font.pixelSize: root.detailSize
                    }
                }
            }
        }

        RowLayout {
            id: utilityRow

            Layout.fillWidth: true
            Layout.preferredHeight: root.blockSize * 0.46
            spacing: root.sectionGap

            Rectangle {
                id: batteryCard

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Math.min(root.panelCornerRadius * 0.45, height * 0.28)
                color: Qt.rgba(1, 1, 1, 0.075)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.modulePadding
                    spacing: root.detailSize * 0.48

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Battery"
                            color: "#ffffff"
                            font.pixelSize: root.titleSize
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: SystemState.batteryReady
                                ? Math.round(SystemState.batteryPercent) + "%"
                                : "—"
                            color: "#ffffff"
                            font.pixelSize: root.titleSize
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: SystemState.batteryStatusText
                        color: Qt.rgba(1, 1, 1, 0.60)
                        font.pixelSize: root.detailSize
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.panelWidth * 0.012
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.11)

                        Rectangle {
                            width: parent.width
                                * Math.max(0, Math.min(1, SystemState.batteryPercent / 100))
                            height: parent.height
                            radius: parent.radius
                            color: SystemState.batteryCharging
                                ? Qt.rgba(0.52, 1, 0.68, 0.82)
                                : Qt.rgba(1, 1, 1, 0.82)
                        }
                    }
                }
            }

            Rectangle {
                id: soundCard

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Math.min(root.panelCornerRadius * 0.45, height * 0.28)
                color: Qt.rgba(1, 1, 1, 0.075)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.modulePadding
                    spacing: root.detailSize * 0.55

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: SystemState.volumeMuted ? "Muted" : "Sound"
                            color: "#ffffff"
                            font.pixelSize: root.titleSize
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: SystemState.volumeText
                            color: Qt.rgba(1, 1, 1, 0.68)
                            font.pixelSize: root.detailSize
                        }

                        Rectangle {
                            width: root.panelWidth * 0.115
                            height: root.panelWidth * 0.058
                            radius: height / 2
                            color: muteMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.17)
                                : Qt.rgba(1, 1, 1, 0.09)

                            Text {
                                anchors.centerIn: parent
                                text: SystemState.volumeMuted ? "Unmute" : "Mute"
                                color: "#ffffff"
                                font.pixelSize: root.detailSize * 0.9
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: SystemState.toggleMute()
                            }
                        }
                    }

                    Rectangle {
                        id: volumeTrack

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.panelWidth * 0.018
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.11)

                        Rectangle {
                            width: parent.width
                                * Math.max(0, Math.min(1, SystemState.volumePercent / 100))
                            height: parent.height
                            radius: parent.radius
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: volumeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true

                            function updateVolume(x) {
                                const ratio = Math.max(0, Math.min(1, x / width));
                                SystemState.setVolumePercent(ratio * 100);
                            }

                            onPressed: mouse => updateVolume(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    updateVolume(mouse.x);
                            }
                            onWheel: wheel => {
                                SystemState.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5);
                            }
                        }
                    }
                }
            }
        }
    }
}
