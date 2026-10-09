pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property Item anchorItem

    // Keep menu rhythm tied to typography, not absolute row/padding pixels.
    readonly property int fontPixelSize: 13
    readonly property real lineHeightRatio: 1.15
    readonly property real itemHorizontalPaddingRatio: 0.95
    readonly property real surfaceHorizontalPaddingRatio: 1.0
    readonly property real surfaceVerticalPaddingRatio: 0.85
    readonly property real separatorHeightRatio: 0.78
    readonly property real separatorThicknessRatio: 0.07
    readonly property real itemCornerRadiusRatio: 0.72
    readonly property real popupAnchorGapRatio: 0.65

    readonly property real textLineHeight: fontPixelSize * lineHeightRatio
    readonly property real itemHorizontalPadding:
        fontPixelSize * itemHorizontalPaddingRatio
    readonly property real menuContentWidth:
        widthMeasure.implicitWidth + itemHorizontalPadding * 2
    readonly property real surfaceHorizontalPadding:
        fontPixelSize * surfaceHorizontalPaddingRatio
    readonly property real surfaceVerticalPadding:
        fontPixelSize * surfaceVerticalPaddingRatio
    readonly property real separatorBlockHeight:
        fontPixelSize * separatorHeightRatio
    readonly property real itemCornerRadius:
        fontPixelSize * itemCornerRadiusRatio
    readonly property string currentUserName: Quickshell.env("USER") || "User"

    readonly property var menuItems: [
        { label: "About this mark", command: ["fastfetch"] },
        { separator: true },
        { label: "System Settings...", command: ["xfce4-settings-manager"] },
        { label: "Location", command: ["thunar", Quickshell.env("HOME")] },
        { label: "App Store...", command: ["waterfox", "https://search.nixos.org/packages"] },
        { separator: true },
        { label: "Recent Items", command: ["thunar", "recent://"] },
        { separator: true },
        { label: "Force Quit...", command: ["xfce4-taskmanager"] },
        { separator: true },
        { label: "Sleep", command: ["systemctl", "suspend"] },
        { label: "Restart...", command: ["systemctl", "reboot"] },
        { label: "Shut Down...", command: ["systemctl", "poweroff"] },
        { separator: true },
        { label: "Lock Screen", command: ["swaylock", "-f"] },
        { label: "Log out " + root.currentUserName + "...", command: ["riverctl", "exit"] }
    ]

    anchor.item: root.anchorItem
    anchor.rect.y: root.anchorItem.height + root.fontPixelSize * root.popupAnchorGapRatio
    anchor.rect.x: 0

    implicitWidth: root.menuContentWidth + root.surfaceHorizontalPadding * 2
    implicitHeight: menuColumn.implicitHeight + root.surfaceVerticalPadding * 2
    color: "transparent"
    visible: false
    grabFocus: true

    // Measure every label independently so the rows can all share the width
    // of the longest label without creating a width/implicitWidth binding loop.
    Column {
        id: widthMeasure

        visible: false

        Repeater {
            model: root.menuItems

            delegate: Text {
                required property var modelData

                text: modelData?.separator === true
                    ? ""
                    : modelData?.label ?? ""
                font.pixelSize: root.fontPixelSize
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.fontPixelSize * 1.45
        color: Qt.rgba(0.08, 0.09, 0.12, 0.97)
        border.width: root.fontPixelSize * 0.055
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Column {
            id: menuColumn

            x: root.surfaceHorizontalPadding
            y: root.surfaceVerticalPadding
            width: root.menuContentWidth
            spacing: 0

            Repeater {
                model: root.menuItems

                delegate: Item {
                    id: menuRow

                    required property var modelData

                    readonly property bool isSeparator:
                        modelData?.separator === true
                    readonly property string itemLabel:
                        modelData?.label ?? ""

                    implicitWidth: isSeparator
                        ? 0
                        : itemText.implicitWidth + root.itemHorizontalPadding * 2
                    implicitHeight: isSeparator
                        ? root.separatorBlockHeight
                        : root.textLineHeight
                    width: menuColumn.width
                    height: implicitHeight

                    Rectangle {
                        visible: menuRow.isSeparator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.max(1, root.fontPixelSize * root.separatorThicknessRatio)
                        color: Qt.rgba(1, 1, 1, 0.10)
                    }

                    Rectangle {
                        visible: !menuRow.isSeparator
                        anchors.fill: parent
                        radius: root.itemCornerRadius
                        color: menuMouse.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : "transparent"

                        Text {
                            id: itemText

                            anchors.fill: parent
                            anchors.leftMargin: root.itemHorizontalPadding
                            anchors.rightMargin: root.itemHorizontalPadding
                            verticalAlignment: Text.AlignVCenter
                            text: menuRow.itemLabel
                            color: "#f5f5f7"
                            font.pixelSize: root.fontPixelSize
                        }

                        MouseArea {
                            id: menuMouse

                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                const command = menuRow.modelData?.command ?? [];
                                if (command.length > 0)
                                    Quickshell.execDetached({ command: command });

                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}