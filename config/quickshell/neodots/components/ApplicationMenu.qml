pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property Item anchorItem
    property real anchorX: 0
    property string menuName: ""
    property var items: []

    anchor.item: root.anchorItem
    anchor.rect.y: root.anchorItem.height + 3
    anchor.rect.x: root.anchorX

    implicitWidth: 250
    implicitHeight: 224
    color: "transparent"
    visible: false

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0.08, 0.09, 0.12, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                width: parent.width
                height: 24
                leftPadding: 10
                verticalAlignment: Text.AlignVCenter
                text: root.menuName
                color: Qt.rgba(1, 1, 1, 0.52)
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.items

                delegate: Item {
                    required property var modelData

                    width: parent.width
                    height: modelData?.separator === true ? 9 : 34

                    readonly property bool isSeparator:
                        modelData?.separator === true
                    readonly property string itemLabel:
                        modelData?.label ?? ""

                    Rectangle {
                        visible: isSeparator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.09)
                    }

                    Rectangle {
                        visible: !isSeparator
                        anchors.fill: parent
                        radius: 9
                        color: actionMouse.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : "transparent"

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: itemLabel
                            color: "#f5f5f7"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: actionMouse

                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                const command = modelData?.command ?? [];
                                if (command.length > 0) {
                                    Quickshell.execDetached({
                                        command: command
                                    });
                                }

                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
