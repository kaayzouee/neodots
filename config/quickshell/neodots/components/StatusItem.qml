import QtQuick

Item {
    id: root

    required property string text
    property color textColor: Qt.rgba(1, 1, 1, 0.84)
    property color hoverColor: Qt.rgba(1, 1, 1, 0.08)
    property real horizontalPadding: 9
    property real controlHeight: 30
    property real cornerRadius: 9
    property real fontPointSize: 11.25
    property int fontWeight: Font.Normal
    property bool active: false
    property bool itemEnabled: true
    property string visibilityMode: "always"
    property bool batteryMode: false
    property real batteryPercent: 0
    property bool batteryCharging: false

    readonly property bool visibleByMode:
        root.visibilityMode === "always" || root.active
    readonly property string batteryPercentText:
        Math.round(Math.max(0, Math.min(100, root.batteryPercent))) + "%"

    signal activated()
    signal pressedAt(real ratio)
    signal movedAt(real ratio, bool pressed)
    signal wheelDelta(int delta)

    implicitWidth: (root.batteryMode
        ? batteryGlyph.implicitWidth
        : content.implicitWidth) + root.horizontalPadding * 2
    implicitHeight: root.controlHeight
    width: root.visible ? root.implicitWidth : 0
    height: root.controlHeight
    visible: root.itemEnabled && root.visibleByMode

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: mouse.containsMouse
            ? root.hoverColor
            : "transparent"
    }

    Text {
        id: content

        anchors.centerIn: parent
        visible: !root.batteryMode
        text: root.text
        color: root.textColor
        font.pointSize: root.fontPointSize
        font.weight: root.fontWeight
    }

    Item {
        id: batteryGlyph

        anchors.centerIn: parent
        visible: root.batteryMode
        implicitWidth: batteryBody.width + batteryTerminal.width
        implicitHeight: batteryBody.height
        width: implicitWidth
        height: implicitHeight

        Rectangle {
            id: batteryBody

            width: Math.max(batteryPercent.implicitWidth + 8,
                root.controlHeight * 1.1)
            height: root.controlHeight * 0.58
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            radius: height * 0.18
            color: Qt.rgba(1, 1, 1, 0.025)
            border.width: 1
            border.color: root.textColor
        }

        Rectangle {
            id: batteryLevel

            x: batteryBody.x + 2
            y: batteryBody.y + 2
            width: Math.max(0, (batteryBody.width - 4)
                * Math.max(0, Math.min(100, root.batteryPercent)) / 100)
            height: batteryBody.height - 4
            radius: height * 0.12
            color: root.batteryCharging
                ? Qt.rgba(0.52, 1, 0.68, 0.28)
                : Qt.rgba(1, 1, 1, 0.16)
        }

        Rectangle {
            id: batteryTerminal

            x: batteryBody.width - 0.2
            anchors.verticalCenter: batteryBody.verticalCenter
            width: root.controlHeight * 0.13
            height: batteryBody.height * 0.36
            radius: width * 0.3
            color: root.textColor
        }

        Text {
            id: batteryPercent

            anchors.centerIn: batteryBody
            text: root.batteryPercentText
            color: root.textColor
            font.pointSize: root.fontPointSize * 0.72
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.itemEnabled && root.visibleByMode
        hoverEnabled: true
        preventStealing: true

        onClicked: root.activated()
        onPressed: mouse => root.pressedAt(mouse.x / width)
        onPositionChanged: mouse => root.movedAt(mouse.x / width, pressed)
        onWheel: wheel => root.wheelDelta(
            wheel.angleDelta.y > 0 ? 5 : -5
        )
    }
}
