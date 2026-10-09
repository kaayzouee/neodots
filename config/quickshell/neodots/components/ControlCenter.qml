import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"

PopupWindow {
    id: root

    required property Item anchorItem

    anchor.item: root.anchorItem
    anchor.rect.y: root.anchorItem.height + 10
    anchor.rect.x: -300

    implicitWidth: 390
    implicitHeight: 360
    color: "transparent"
    visible: false
    grabFocus: true

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.rgba(0.08, 0.09, 0.12, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "Control Center"
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    id: wifiCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 94
                    radius: 18
                    color: SystemState.networkConnected
                        ? Qt.rgba(0.20, 0.38, 0.72, 0.32)
                        : Qt.rgba(1, 1, 1, 0.07)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: "Wi-Fi"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: root.networkIcon
                                color: "#ffffff"
                                font.pixelSize: 16
                            }
                        }

                        Text {
                            text: SystemState.wifiEnabled
                                ? (SystemState.networkConnected
                                    ? SystemState.networkName
                                    : "Not Connected")
                                : "Wi-Fi Off"
                            color: Qt.rgba(1, 1, 1, 0.60)
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: SystemState.toggleWifi()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 94
                    radius: 18
                    color: SystemState.batteryReady
                        ? Qt.rgba(1, 1, 1, 0.07)
                        : Qt.rgba(1, 1, 1, 0.04)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: "Battery"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: SystemState.batteryReady
                                    ? Math.round(SystemState.batteryPercent) + "%"
                                    : "—"
                                color: "#ffffff"
                                font.pixelSize: 15
                            }
                        }

                        Text {
                            text: SystemState.batteryStatusText
                            color: Qt.rgba(1, 1, 1, 0.60)
                            font.pixelSize: 11
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            radius: 2.5
                            color: Qt.rgba(1, 1, 1, 0.10)

                            Rectangle {
                                width: parent.width
                                    * Math.max(
                                        0,
                                        Math.min(1, SystemState.batteryPercent / 100)
                                    )
                                height: parent.height
                                radius: parent.radius
                                color: Qt.rgba(1, 1, 1, 0.80)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 112
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.07)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: SystemState.volumeMuted ? "Muted" : "Sound"
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: SystemState.volumeText
                            color: Qt.rgba(1, 1, 1, 0.68)
                            font.pixelSize: 11
                        }

                        Rectangle {
                            width: 30
                            height: 28
                            radius: 8
                            color: volumeMuteMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.10)
                                : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: SystemState.volumeMuted ? "◼" : "◖"
                                color: "#ffffff"
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: volumeMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: SystemState.toggleMute()
                            }
                        }
                    }

                    Rectangle {
                        id: volumeTrack

                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.10)

                        Rectangle {
                            width: parent.width
                                * Math.max(
                                    0,
                                    Math.min(1, SystemState.volumePercent / 100)
                                )
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
                                const ratio = Math.max(
                                    0,
                                    Math.min(1, x / width)
                                );
                                SystemState.setVolumePercent(ratio * 100);
                            }

                            onPressed: mouse => updateVolume(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    updateVolume(mouse.x);
                            }

                            onWheel: wheel => {
                                SystemState.adjustVolume(
                                    wheel.angleDelta.y > 0 ? 5 : -5
                                );
                            }
                        }
                    }

                    Text {
                        text: "Drag, click, or scroll to adjust volume"
                        color: Qt.rgba(1, 1, 1, 0.42)
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Network signal  " + SystemState.networkSignal + "%"
                    color: Qt.rgba(1, 1, 1, 0.52)
                    font.pixelSize: 11
                }

                Text {
                    text: SystemState.workspaceText
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }

    readonly property string networkIcon:
        !SystemState.wifiEnabled
            ? "○"
            : !SystemState.networkConnected
                ? "◌"
                : SystemState.networkSignal >= 75
                    ? "▂▄▆█"
                    : SystemState.networkSignal >= 50
                        ? "▂▄▆"
                        : SystemState.networkSignal >= 25
                            ? "▂▄"
                            : "▂"
}
