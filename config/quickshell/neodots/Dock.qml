pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "./components"
import "./services"

PanelWindow { // qmllint disable uncreatable-type
    id: root

    BarConfig {
        id: config
    }

    property int hoveredIndex: -1
    property int activationTagIndex: 1
    property var activationTarget: null
    property var dockApps: []

    // The requested bottom-bar size is proportional to the target monitor's
    // height, not its width. For example: 1800 / 14.75 = 122.03 px.
    readonly property real dockSurfaceHeight: root.screen
        ? root.screen.height / config.dockHeightDivisor
        : 0
    readonly property real dockIconSize: dockSurfaceHeight
        * config.dockIconSizeRatio
    readonly property real dockIconSlotWidth: dockIconSize
        + dockIconSize * config.dockIconSlotPaddingRatio * 2
    readonly property real dockSpacing: dockIconSize
        * config.dockSpacingRatio
    readonly property real dockSurfaceHorizontalPadding: dockIconSize
        * config.dockSurfaceHorizontalPaddingRatio
    readonly property real dockIndicatorSize: dockIconSize
        * config.dockIndicatorSizeRatio
    readonly property real dockIndicatorGap: dockIconSize
        * config.dockIndicatorGapRatio
    readonly property real dockUtilityRadius: dockIconSize
        * config.dockUtilityRadiusRatio
    readonly property real dockHoverCircleSize: dockIconSize
        * config.dockHoverCircleRatio
    readonly property real dockHoverLabelMargin: dockIconSize
        * config.dockHoverLabelMarginRatio
    readonly property real dockCornerRadius: dockSurfaceHeight
        * config.barCornerRatio

    Timer {
        id: activationTimer

        interval: 90
        repeat: true

        onTriggered: root.tryNextActivationTag()
    }

    // App IDs can arrive just after a toplevel is inserted. Reconcile
    // periodically as a fallback, without rebuilding delegates when nothing
    // has changed.
    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: root.refreshDockApps()
    }

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins.bottom: root.dockIndicatorSize

    implicitHeight: dockSurfaceHeight
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Auto
    aboveWindows: true

    WlrLayershell.namespace: "neodots:dock"
    WlrLayershell.layer: WlrLayer.Top

    Component.onCompleted: root.refreshDockApps()

    Connections {
        target: ToplevelManager.toplevels

        function onObjectInsertedPost() {
            root.refreshDockApps();
        }

        function onObjectRemovedPost() {
            root.refreshDockApps();
        }
    }

    function normalizedIdentifier(value) {
        return String(value || "")
            .toLowerCase()
            .replace(/\.desktop$/, "")
            .replace(/[^a-z0-9]/g, "");
    }

    function desktopEntryForAppId(appId) {
        const target = root.normalizedIdentifier(appId);
        const entries = DesktopEntries.applications.values;

        let entry = entries.find(candidate =>
            root.normalizedIdentifier(candidate.startupClass) === target
        );
        if (entry)
            return entry;

        entry = entries.find(candidate =>
            root.normalizedIdentifier(candidate.id) === target
        );
        if (entry)
            return entry;

        // Some applications publish a reverse-DNS app ID while their desktop
        // entry uses a short startup class (for example, Code / VS Code).
        entry = entries.find(candidate => {
            const startupClass = root.normalizedIdentifier(candidate.startupClass);
            return startupClass.length >= 4 && target.endsWith(startupClass);
        });
        if (entry)
            return entry;

        return DesktopEntries.heuristicLookup(appId) || null;
    }

    function isCatalogAppId(appId) {
        const normalizedAppId = String(appId || "").toLowerCase();

        return AppCatalog.apps.some(app => {
            if (app.role === "Launchpad")
                return false;

            const matchers = app.matches || [];
            if (matchers.some(matcher =>
                normalizedAppId.includes(String(matcher).toLowerCase())
            )) {
                return true;
            }

            const entryIds = [app.entry?.id, app.entry?.startupClass]
                .filter(value => Boolean(value));
            return entryIds.some(value => {
                const normalizedEntryId = String(value).toLowerCase()
                    .replace(/\.desktop$/, "");
                return normalizedAppId === normalizedEntryId
                    || normalizedAppId.endsWith("." + normalizedEntryId);
            });
        });
    }

    function displayNameForAppId(appId, entry) {
        if (entry?.name)
            return entry.name;

        const normalized = root.normalizedIdentifier(appId);
        if (["code", "codeoss", "orgcodeoss", "vscode", "visualstudiocode", "comvisualstudiocode", "commicrosoftvscode"].includes(normalized))
            return "Visual Studio Code";

        const lastPart = String(appId || "Application").split(/[./]/).pop();
        return lastPart.replace(/[-_]+/g, " ")
            .replace(/\b\w/g, character => character.toUpperCase());
    }

    function fallbackIconForAppId(appId, entry) {
        if (entry?.icon)
            return entry.icon;

        const normalized = root.normalizedIdentifier(appId);
        if (["code", "codeoss", "orgcodeoss", "vscode", "visualstudiocode", "comvisualstudiocode", "commicrosoftvscode"].includes(normalized))
            return "code";

        return "application-x-executable";
    }

    function dockAppKey(app) {
        if (app.dynamic)
            return "running:" + root.normalizedIdentifier(app.matches?.[0] || app.role);

        return "catalog:" + app.role;
    }

    function refreshDockApps() {
        const catalogApps = AppCatalog.apps.filter(app => app.role !== "Launchpad");
        const launchpadApps = AppCatalog.apps.filter(app => app.role === "Launchpad");
        const dynamicApps = [];
        const seen = {};

        for (const app of catalogApps) {
            const key = root.normalizedIdentifier(
                app.entry?.startupClass || app.entry?.id || app.matches?.[0] || app.role
            );
            if (key)
                seen[key] = true;
        }

        for (const toplevel of ToplevelManager.toplevels.values) {
            const appId = String(toplevel.appId || "").trim();
            if (!appId || root.isCatalogAppId(appId))
                continue;

            const entry = root.desktopEntryForAppId(appId);
            const key = root.normalizedIdentifier(
                entry?.startupClass || entry?.id || appId
            );
            if (!key || seen[key])
                continue;

            seen[key] = true;
            dynamicApps.push({
                role: root.displayNameForAppId(appId, entry),
                name: root.displayNameForAppId(appId, entry),
                entry: entry,
                iconSource: "",
                fallbackIcon: root.fallbackIconForAppId(appId, entry),
                fallbackCommand: entry?.command || [appId],
                matches: [appId],
                dynamic: true
            });
        }

        const nextApps = catalogApps.concat(dynamicApps, launchpadApps);
        const currentApps = root.dockApps || [];
        if (currentApps.length === nextApps.length
            && currentApps.every((app, index) =>
                root.dockAppKey(app) === root.dockAppKey(nextApps[index])
            )) {
            return;
        }

        root.dockApps = nextApps;
    }

    function matchingToplevels(app) {
        const matchers = app.matches || [];
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const appId = (toplevel.appId || "").toLowerCase();
            return matchers.some(matcher => appId.includes(matcher.toLowerCase()));
        });
    }

    function isRunning(app) {
        return matchingToplevels(app).length > 0;
    }

    function isActive(app) {
        return matchingToplevels(app).some(toplevel => toplevel.activated);
    }

    function activateApplication(app) {
        const matches = matchingToplevels(app);
        if (matches.length === 0) {
            launchApplication(app);
            return;
        }

        const preferred = matches.find(toplevel => toplevel.activated) || matches[0];
        root.activationTarget = preferred;

        if (preferred.activated) {
            preferred.activate();
            return;
        }

        root.activationTagIndex = 1;

        if (root.screen?.name) {
            Quickshell.execDetached({
                command: ["riverctl", "focus-output", root.screen.name]
            });
        }

        activationTimer.restart();
    }

    function tryNextActivationTag() {
        const target = root.activationTarget;

        if (!target) {
            activationTimer.stop();
            return;
        }

        if (target.activated) {
            activationTimer.stop();
            root.activationTarget = null;
            return;
        }

        if (root.activationTagIndex > 9) {
            // Last resort: expose all tags briefly and ask the compositor to
            // activate the existing toplevel. This is the "pop it up" fallback.
            Quickshell.execDetached({
                command: ["riverctl", "set-focused-tags", "4294967295"]
            });
            target.activate();
            activationTimer.stop();
            root.activationTarget = null;
            return;
        }

        const mask = 2 ** (root.activationTagIndex - 1);

        Quickshell.execDetached({
            command: ["riverctl", "set-focused-tags", String(mask)]
        });

        root.activationTagIndex += 1;
        target.activate();
    }

    function launchApplication(app) {
        if (app.role === "Launchpad") {
            Quickshell.execDetached({
                command: app.fallbackCommand
            });
            return;
        }

        if (app.entry) {
            app.entry.execute();
            return;
        }

        Quickshell.execDetached({
            command: app.fallbackCommand
        });
    }

    GlassSurface {
        id: surface

        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }

        width: Math.min(
            parent.width,
            dockContent.implicitWidth + root.dockSurfaceHorizontalPadding * 2
        )
        height: dockSurfaceHeight
        cornerRadius: root.dockCornerRadius
        cornerExponent: config.dockCornerExponent
        fillColor: config.dockFill
        borderColor: config.dockBorder
        borderWidth: config.surfaceBorderWidth
        highlightColor: config.surfaceHighlight
        shadowColor: config.shadowColor
        shadowOpacity: config.shadowOpacity
        shadowOffsetY: config.shadowOffsetY

        Row {
            id: dockContent

            anchors.centerIn: parent
            height: root.dockSurfaceHeight
            spacing: root.dockSpacing

            Repeater {
                model: root.dockApps

                delegate: DockIcon {
                    required property var modelData
                    required property int index

                    app: modelData
                    dockIndex: index
                    hoveredIndex: root.hoveredIndex
                    dockRoot: root
                    dockConfig: config
                    dockIconSize: root.dockIconSize
                    dockIconSlotWidth: root.dockIconSlotWidth
                    dockIndicatorSize: root.dockIndicatorSize
                    dockIndicatorGap: root.dockIndicatorGap
                    dockHoverCircleSize: root.dockHoverCircleSize
                    dockHoverLabelMargin: root.dockHoverLabelMargin
                    running: root.isRunning(modelData)
                    active: root.isActive(modelData)

                    onActivateRequested: root.activateApplication(modelData)
                }
            }

            Rectangle {
                width: root.dockIconSize * 0.02
                height: root.dockIconSize * 0.96
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.18)
            }

            // Utility slots use the same runtime-derived dimensions as app
            // icons, so the group remains stable when applications change.
            Rectangle {
                width: root.dockIconSlotWidth
                height: root.dockSurfaceHeight
                radius: root.dockUtilityRadius
                color: downloadsMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: root.dockIconSize
                    source: "file://" + Quickshell.shellPath("assets/icons/mactahoe/folder-download.svg")
                }

                Text {
                    visible: downloadsMouse.containsMouse
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: root.dockHoverLabelMargin
                    text: "Downloads"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: downloadsMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: root.hoveredIndex = -1
                    onExited: root.hoveredIndex = -1
                    onClicked: Quickshell.execDetached({
                        command: ["thunar", Quickshell.env("HOME") + "/Downloads"]
                    })
                }
            }

            Rectangle {
                width: root.dockIconSlotWidth
                height: root.dockSurfaceHeight
                radius: root.dockUtilityRadius
                color: trashMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: root.dockIconSize
                    source: "file://" + Quickshell.shellPath("assets/icons/mactahoe/user-trash.svg")
                }

                Text {
                    visible: trashMouse.containsMouse
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: root.dockHoverLabelMargin
                    text: "Trash"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: trashMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: root.hoveredIndex = -1
                    onExited: root.hoveredIndex = -1
                    onClicked: Quickshell.execDetached({
                        command: ["thunar", "trash:///"]
                    })
                }
            }
        }
    }
}
