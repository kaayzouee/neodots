pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "./components"
import "./services"

PanelWindow { // qmllint disable uncreatable-type
    id: root

    BarConfig {
        id: config
    }

    readonly property var activeEntry: DesktopEntries.heuristicLookup(SystemState.activeAppId)
    readonly property string activeAppName: activeEntry?.name
        || SystemState.activeAppId
        || "Finder"

    readonly property var menuDefinitions: [
        {
            label: "File",
            items: [
                { label: "Open Files", command: ["thunar"] },
                { label: "Open Downloads", command: ["thunar", Quickshell.env("HOME") + "/Downloads"] },
                { separator: true },
                { label: "New Terminal", command: ["alacritty"] }
            ]
        },
        {
            label: "Edit",
            items: [
                { label: "Open NixOS Configuration", command: ["thunar", "/etc/nixos"] },
                { label: "Open Neodots", command: ["thunar", Quickshell.env("HOME") + "/neodots"] }
            ]
        },
        {
            label: "View",
            items: [
                { label: "Applications", command: ["fuzzel"] },
                { separator: true },
                { label: "Focus Next Window", command: ["riverctl", "focus-view", "next"] },
                { label: "Focus Previous Window", command: ["riverctl", "focus-view", "previous"] }
            ]
        },
        {
            label: "Window",
            items: [
                { label: "Focus Next Window", command: ["riverctl", "focus-view", "next"] },
                { label: "Focus Previous Window", command: ["riverctl", "focus-view", "previous"] },
                { label: "Toggle Full Screen", command: ["riverctl", "toggle-fullscreen"] },
                { label: "Zoom Window", command: ["riverctl", "zoom"] }
            ]
        },
        {
            label: "Help",
            items: [
                { label: "NixOS Manual", command: ["waterfox", "https://nixos.org/manual/nixos/stable/"] },
                { label: "Quickshell Documentation", command: ["waterfox", "https://quickshell.org/docs/"] },
                { label: "Neodots Repository", command: ["waterfox", "https://github.com/kaayzouee/neodots"] }
            ]
        }
    ]

    property int openMenuIndex: -1
    property bool systemMenuOpen: false
    property bool controlCenterOpen: false

    function toggleApplicationMenu(index) {
        root.openMenuIndex = root.openMenuIndex === index ? -1 : index;
        root.systemMenuOpen = false;
        root.controlCenterOpen = false;
    }

    // KWM owns window management. Dispatch its existing global shortcuts
    // through a Wayland virtual keyboard so these shell controls work with
    // the currently focused application without adding a second WM API.
    function triggerWindowShortcut(key, modifiers) {
        if (!SystemState.activeToplevel)
            return;

        const command = ["wtype", "-M", "logo"];
        for (const modifier of modifiers)
            command.push("-M", modifier);

        command.push("-k", key);

        for (let i = modifiers.length - 1; i >= 0; i--)
            command.push("-m", modifiers[i]);

        command.push("-m", "logo");
        Quickshell.execDetached({ command: command });
    }

    function statusItemText(id) {
        switch (id) {
        case "network":
            return "Wi-Fi";
        case "audio":
            return SystemState.volumeMuted
                ? "Muted"
                : SystemState.volumeText;
        case "battery":
            return Math.round(SystemState.batteryPercent) + "%";
        default:
            return "";
        }
    }

    function statusItemActive(id) {
        switch (id) {
        case "network":
            return SystemState.networkConnected;
        case "audio":
            return SystemState.volumePercent >= 0 && !SystemState.volumeMuted;
        case "battery":
            return SystemState.batteryReady
                && (SystemState.batteryCharging || SystemState.onBattery);
        default:
            return false;
        }
    }

    function statusItemColor(id) {
        switch (id) {
        case "network":
            return SystemState.networkConnected
                ? Qt.rgba(1, 1, 1, 0.86)
                : Qt.rgba(1, 1, 1, 0.45);
        default:
            return Qt.rgba(1, 1, 1, 0.84);
        }
    }

    function closeOverlays() {
        root.openMenuIndex = -1;
        root.systemMenuOpen = false;
    }

    function openControlCenter() {
        root.closeOverlays();
        root.controlCenterOpen = true;
    }

    function handleStatusItemActivated(id) {
        if (id !== "network" && id !== "battery")
            return;

        if (root.controlCenterOpen) {
            root.controlCenterOpen = false;
            return;
        }

        root.openControlCenter();
    }

    function handleStatusItemPosition(id, ratio) {
        if (id !== "audio")
            return;

        const clamped = Math.max(0, Math.min(1, ratio));
        SystemState.setVolumePercent(clamped * 100);
    }

    function handleStatusItemWheel(id, delta) {
        if (id === "audio")
            SystemState.adjustVolume(delta);
    }

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: config.topInset
        left: config.topHorizontalInset
        right: config.topHorizontalInset
    }

    implicitHeight: config.topSurfaceHeight
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Auto
    aboveWindows: true

    WlrLayershell.namespace: "neodots:top-bar"
    WlrLayershell.layer: WlrLayer.Top

    GlassSurface {
        id: surface

        anchors.fill: parent
        cornerRadius: config.topCornerRadius
        cornerExponent: config.dockCornerExponent
        fillColor: config.surfaceFill
        borderColor: config.surfaceBorder
        borderWidth: config.surfaceBorderWidth
        highlightColor: config.surfaceHighlight
        shadowColor: config.shadowColor
        shadowOpacity: config.shadowOpacity
        shadowOffsetY: config.shadowOffsetY

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: config.topMenuHorizontalPadding
            anchors.rightMargin: config.topMenuHorizontalPadding
            spacing: config.topGroupSpacing

            Row {
                id: leftGroup

                Layout.fillHeight: true
                spacing: config.topItemSpacing

                Rectangle {
                    id: systemButton

                    width: systemText.implicitWidth + config.topItemHorizontalPadding * 2
                    height: config.topControlHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 9
                    color: systemMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : "transparent"

                    Text {
                        id: systemText
                        anchors.centerIn: parent
                        text: "✦"
                        color: "#ffffff"
                        font.pixelSize: 25
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: systemMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            root.openMenuIndex = -1;
                            root.controlCenterOpen = false;
                            root.systemMenuOpen = !root.systemMenuOpen;
                        }
                    }
                }

                Rectangle {
                    width: config.topSeparatorWidth
                    height: config.topSeparatorHeight
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.14)
                }

                // Clearly visible macOS-inspired window controls. The circles
                // stay compact, but each has a larger hit target for reliable clicks.
                Row {
                    id: windowControls

                    readonly property real hitSize: Math.max(config.topControlHeight * 0.76, 22)
                    readonly property real diameter: Math.max(config.topSurfaceHeight * 0.30, 13)

                    anchors.verticalCenter: parent.verticalCenter
                    height: hitSize
                    spacing: config.topSurfaceHeight * 0.055

                    Item {
                        id: floatingButton

                        width: windowControls.hitSize
                        height: windowControls.hitSize

                        Rectangle {
                            width: windowControls.diameter
                            height: width
                            anchors.centerIn: parent
                            radius: width / 2
                            color: floatingMouse.containsMouse ? "#ffd15c" : "#ffbd2e"
                            border.width: 1
                            border.color: floatingMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.50)
                                : Qt.rgba(0, 0, 0, 0.18)
                            opacity: floatingMouse.pressed ? 0.72 : 1
                        }

                        MouseArea {
                            id: floatingMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.triggerWindowShortcut("f", [])
                        }
                    }

                    Item {
                        id: tileButton

                        width: windowControls.hitSize
                        height: windowControls.hitSize

                        Rectangle {
                            width: windowControls.diameter
                            height: width
                            anchors.centerIn: parent
                            radius: width / 2
                            color: tileMouse.containsMouse ? "#4fe16a" : "#28c840"
                            border.width: 1
                            border.color: tileMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.50)
                                : Qt.rgba(0, 0, 0, 0.18)
                            opacity: tileMouse.pressed ? 0.72 : 1
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.triggerWindowShortcut("t", ["alt"])
                        }
                    }
                }

                Rectangle {
                    id: activeAppItem

                    width: activeAppText.implicitWidth
                        + config.topItemHorizontalPadding * 2
                    height: config.topControlHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 9
                    color: activeAppMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.08)
                        : "transparent"

                    Text {
                        id: activeAppText
                        anchors.centerIn: parent
                        text: root.activeAppName
                        color: "#ffffff"
                        font.pointSize: config.uiFontPointSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: activeAppMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                Rectangle {
                    width: config.topSeparatorWidth
                    height: config.topSeparatorHeight
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.10)
                }

                Repeater {
                    id: topMenuRepeater
                    model: root.menuDefinitions

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: menuText.implicitWidth
                            + config.topItemHorizontalPadding * 2
                        height: config.topControlHeight
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 9
                        color: root.openMenuIndex === index || menuMouse.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : "transparent"

                        Text {
                            id: menuText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Qt.rgba(1, 1, 1, 0.84)
                            font.pointSize: config.uiFontPointSize
                            font.weight: root.openMenuIndex === index
                                ? Font.DemiBold
                                : Font.Normal
                        }

                        MouseArea {
                            id: menuMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                if (root.openMenuIndex !== -1
                                    && root.openMenuIndex !== index) {
                                    root.openMenuIndex = index;
                                }
                            }

                            onClicked: root.toggleApplicationMenu(index)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            Row {
                id: rightGroup

                Layout.fillHeight: true
                spacing: 0

                Row {
                    id: statusItemGroup

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: config.topStatusItemSpacing

                    Repeater {
                        id: statusItemRepeater
                        model: config.menuBarStatusItems

                        delegate: StatusItem {
                            required property var modelData

                            text: root.statusItemText(modelData.id)
                            textColor: root.statusItemColor(modelData.id)
                            batteryMode: modelData.id === "battery"
                            batteryPercent: SystemState.batteryPercent
                            batteryCharging: SystemState.batteryCharging
                            fontPointSize: config.uiFontPointSize
                            fontWeight: modelData.id === "network"
                                && SystemState.networkConnected
                                ? Font.DemiBold
                                : Font.Normal
                            controlHeight: config.topControlHeight
                            horizontalPadding: config.topItemHorizontalPadding
                            visibilityMode: modelData.visibilityMode ?? "always"
                            itemEnabled: modelData.enabled !== false
                            active: root.statusItemActive(modelData.id)

                            onActivated:
                                root.handleStatusItemActivated(modelData.id)

                            onPressedAt:
                                ratio => root.handleStatusItemPosition(
                                    modelData.id,
                                    ratio
                                )

                            onMovedAt:
                                (ratio, pressed) => {
                                    if (pressed)
                                        root.handleStatusItemPosition(
                                            modelData.id,
                                            ratio
                                        );
                                }

                            onWheelDelta:
                                delta => root.handleStatusItemWheel(
                                    modelData.id,
                                    delta
                                )
                        }
                    }
                }

                Item {
                    width: config.topSectionSpacing * 0.5
                    height: 1
                }

                Rectangle {
                    width: config.topSeparatorWidth
                    height: config.topSeparatorHeight
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.10)
                }

                Item {
                    width: config.topSectionSpacing
                    height: 1
                }

                Rectangle {
                    id: controlButton

                    width: controlGlyph.implicitWidth
                        + config.topItemHorizontalPadding * 2
                    height: config.topControlHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: config.topControlHeight * 0.28
                    color: controlMouse.containsMouse || root.controlCenterOpen
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : "transparent"

                    // Monochrome, translucent toggle pair inspired by the
                    // macOS Control Center symbol. Geometry follows the
                    // control height rather than fixed pixel dimensions.
                    Item {
                        id: controlGlyph

                        anchors.centerIn: parent
                        implicitWidth: config.topControlHeight * 0.72
                        implicitHeight: config.topControlHeight * 0.58
                        width: implicitWidth
                        height: implicitHeight

                        Rectangle {
                            id: upperTrack

                            x: 0
                            y: controlGlyph.height * 0.14
                            width: controlGlyph.width
                            height: controlGlyph.height * 0.32
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.23)
                        }

                        Rectangle {
                            width: upperTrack.height * 1.18
                            height: width
                            x: upperTrack.width - width
                            y: upperTrack.y + (upperTrack.height - height) / 2
                            radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.94)
                        }

                        Rectangle {
                            id: lowerTrack

                            x: 0
                            y: controlGlyph.height * 0.60
                            width: controlGlyph.width
                            height: controlGlyph.height * 0.32
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.23)
                        }

                        Rectangle {
                            width: lowerTrack.height * 1.18
                            height: width
                            x: 0
                            y: lowerTrack.y + (lowerTrack.height - height) / 2
                            radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.94)
                        }
                    }

                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            root.openMenuIndex = -1;
                            root.systemMenuOpen = false;
                            root.controlCenterOpen = !root.controlCenterOpen;
                        }
                    }
                }

                Item {
                    width: config.topSectionSpacing * 0.5
                    height: 1
                }

                Rectangle {
                    width: dateText.implicitWidth
                        + config.topItemHorizontalPadding * 2
                    height: config.topControlHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 9
                    color: dateMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.08)
                        : "transparent"

                    Text {
                        id: dateText
                        anchors.centerIn: parent
                        text: SystemState.dateTimeText
                        color: "#ffffff"
                        font.pointSize: config.uiFontPointSize
                    }

                    MouseArea {
                        id: dateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
    }

    function applicationMenuAnchorX(index) {
        if (index < 0)
            return 0;

        const item = topMenuRepeater.itemAt(index);
        return item ? item.x - activeAppItem.x : 0;
    }

    ApplicationMenu {
        id: applicationMenu
        anchorItem: activeAppItem
        anchorX: root.applicationMenuAnchorX(root.openMenuIndex)
        menuName: root.openMenuIndex >= 0
            ? root.menuDefinitions[root.openMenuIndex].label
            : ""
        items: root.openMenuIndex >= 0
            ? root.menuDefinitions[root.openMenuIndex].items
            : []
        visible: root.openMenuIndex >= 0

        onVisibleChanged: {
            if (!visible)
                root.openMenuIndex = -1;
        }
    }

    SystemMenu {
        id: systemMenu
        anchorItem: systemButton
        visible: root.systemMenuOpen

        onVisibleChanged: {
            if (!visible)
                root.systemMenuOpen = false;
        }
    }

    ControlCenter {
        id: controlCenter
        anchorItem: controlButton
        visible: root.controlCenterOpen

        onVisibleChanged: {
            if (!visible)
                root.controlCenterOpen = false;
        }
    }
}
