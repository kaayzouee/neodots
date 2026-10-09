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

                        Image {
                            id: wifiIcon

                            Layout.preferredWidth: root.blockSize * 0.23
                            Layout.preferredHeight: root.blockSize * 0.23
                            source: !SystemState.wifiEnabled || !SystemState.networkConnected
                                ? "../assets/icons/wifi-disconnected.svg"
                                : "../assets/icons/wifi.svg"
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
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

                        Image {
                            id: bluetoothIcon

                            Layout.preferredWidth: root.blockSize * 0.23
                            Layout.preferredHeight: root.blockSize * 0.23
                            source: !SystemState.bluetoothPowered || !SystemState.bluetoothConnected
                                ? "../assets/icons/bluetooth-disconnected.svg"
                                : "../assets/icons/bluetooth.svg"
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
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

                        Image {
                            anchors.centerIn: parent
                            width: root.blockSize * 0.36
                            height: width
                            source: "../assets/icons/calendar.svg"
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
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
