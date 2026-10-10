import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property var app
    property bool hovered: false
    property bool running: false
    property bool active: false
    required property int dockIndex
    required property int hoveredIndex
    required property var dockRoot
    required property var dockConfig
    required property real dockIconSize
    required property real dockIconSlotWidth
    required property real dockIndicatorSize
    required property real dockIndicatorGap
    required property real dockHoverCircleSize
    required property real dockHoverLabelMargin

    readonly property real magnificationScale: {
        if (root.hoveredIndex < 0)
            return 1.0;

        const distance = Math.abs(root.dockIndex - root.hoveredIndex);
        const influence = Math.max(
            0,
            1 - distance / root.dockConfig.dockMagnificationSpread
        );

        return 1.0
            + (root.dockConfig.dockMagnificationScale - 1.0) * influence;
    }

    signal activateRequested()

    readonly property string iconName: root.app.entry?.icon
        || root.app.fallbackIcon
        || "application-x-executable"
    readonly property string themedIconSource: root.app.iconSource || ""

    width: root.dockIconSlotWidth
    height: root.dockRoot.dockSurfaceHeight

    Item {
        id: visual

        width: root.dockIconSize
        height: root.dockIconSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        scale: root.magnificationScale
        z: root.hoveredIndex < 0
            ? 0
            : Math.max(0, 100 - Math.abs(root.dockIndex - root.hoveredIndex))
        transformOrigin: Item.Bottom

        Behavior on scale {
            NumberAnimation {
                duration: root.dockConfig.dockAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        transform: Translate {
            id: bounceTransform
        }

        SequentialAnimation {
            id: launchBounce
            running: false

            NumberAnimation {
                target: bounceTransform
                property: "y"
                to: -root.dockIconSize * 0.22
                duration: 180
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: bounceTransform
                property: "y"
                to: 0
                duration: 240
                easing.type: Easing.OutBounce
            }
        }
        IconImage {
            anchors.fill: parent
            implicitSize: root.dockIconSize
            asynchronous: true
            source: root.themedIconSource !== ""
                ? root.themedIconSource
                : Quickshell.iconPath(root.iconName, true)
        }

        Rectangle {
            anchors.centerIn: iconMouse
            width: root.hovered || root.active
                ? root.dockHoverCircleSize
                : 0
            height: width
            radius: width / 2
            color: root.active
                ? Qt.rgba(1, 1, 1, 0.08)
                : Qt.rgba(1, 1, 1, 0.06)

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: iconMouse

            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                root.hovered = true;
                root.dockRoot.hoveredIndex = root.dockIndex;
            }

            onExited: {
                root.hovered = false;
                if (root.dockRoot.hoveredIndex === root.dockIndex)
                    root.dockRoot.hoveredIndex = -1;
            }

            onClicked: {
                if (root.running && root.app.role !== "Launchpad")
                    root.activateRequested();
                else
                    root.launch();
            }
        }
    }

    // The running marker stays with the icon instead of being pinned to the
    // bottom of the full Dock. Both marker size and gap follow icon scale.
    Rectangle {
        visible: root.running
        anchors.horizontalCenter: parent.horizontalCenter
        y: visual.y + visual.height + root.dockIndicatorGap
        width: root.active
            ? root.dockIndicatorSize
            : root.dockIndicatorSize * 0.8
        height: width
        radius: width / 2
        color: "#f5f5f7"
    }

    Text {
        visible: root.hovered
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: root.dockHoverLabelMargin
        text: root.app.role
        color: "#ffffff"
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    onRunningChanged: {
        if (running)
            launchBounce.start();
    }

    function launch() {
        if (root.app.role === "Launchpad") {
            Quickshell.execDetached({
                command: root.app.fallbackCommand
            });
            return;
        }

        if (root.app.entry) {
            root.app.entry.execute();
            return;
        }

        Quickshell.execDetached({
            command: root.app.fallbackCommand
        });
    }
}
