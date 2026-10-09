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

    signal activated()
    signal pressedAt(real ratio)
    signal movedAt(real ratio, bool pressed)
    signal wheelDelta(int delta)

    readonly property bool visibleByMode:
        root.visibilityMode === "always" || root.active

    implicitWidth: content.implicitWidth + root.horizontalPadding * 2
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
        text: root.text
        color: root.textColor
        font.pointSize: root.fontPointSize
        font.weight: root.fontWeight
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
