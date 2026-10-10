import QtQuick

QtObject {
    // macOS-like menu bar: the panel itself spans the complete output.
    readonly property real topSurfaceHeight: 46
    readonly property real topInset: 0
    readonly property real topHorizontalInset: 0

    // Keep top-bar text aligned with the terminal's configured point size.
    readonly property real uiFontPointSize: 11.25

    // Top-bar geometry follows the surface size. Individual controls then
    // derive their width from their text/glyph plus proportional padding.
    readonly property real topControlHeightRatio: 0.60
    readonly property real topSurfaceHorizontalPaddingRatio: 0.16
    readonly property real topGroupSpacingRatio: 0.04
    readonly property real topItemSpacingRatio: 0.02
    readonly property real topStatusItemSpacingRatio: 0.02
    readonly property real topSectionSpacingRatio: 0.10
    readonly property real topItemHorizontalPaddingRatio: 0.18
    readonly property real topSeparatorHeightRatio: 0.40
    readonly property real topSeparatorWidthRatio: 0.02

    readonly property real topControlHeight: topSurfaceHeight * topControlHeightRatio
    readonly property real topMenuHorizontalPadding: topSurfaceHeight
        * topSurfaceHorizontalPaddingRatio
    readonly property real topGroupSpacing: topSurfaceHeight * topGroupSpacingRatio
    readonly property real topItemSpacing: topSurfaceHeight * topItemSpacingRatio
    readonly property real topStatusItemSpacing:
        topSurfaceHeight * topStatusItemSpacingRatio
    readonly property real topSectionSpacing:
        topSurfaceHeight * topSectionSpacingRatio
    readonly property real topItemHorizontalPadding: topSurfaceHeight
        * topItemHorizontalPaddingRatio
    readonly property real topSeparatorHeight: topSurfaceHeight
        * topSeparatorHeightRatio
    readonly property real topSeparatorWidth: topSurfaceHeight
        * topSeparatorWidthRatio

    // Apple-inspired menu-bar status collection.
    // Keep an item with visibilityMode "always" to emulate a selected
    // persistent status control. Change it to "active" for "Show When Active"
    // behavior, or set enabled to false to remove it from the collection.
    readonly property var menuBarStatusItems: [
        {
            id: "network",
            visibilityMode: "always",
            enabled: true
        },
        {
            id: "audio",
            visibilityMode: "always",
            enabled: true
        },
        {
            id: "battery",
            visibilityMode: "always",
            enabled: true
        }
    ]

    // Dock remains a separate floating island.
    // The surface height is derived from the target screen height at runtime
    // in Dock.qml: screen height / 14.75.
    readonly property real dockHeightDivisor: 14.75

    // Dock dimensions are proportional/content-driven. No fixed pixel
    // lengths are used for the Dock's icon, slots, gaps, or surface width.
    readonly property real dockIconSizeRatio: 5.0 / 7.0
    readonly property real dockIconSlotPaddingRatio: 0.12
    readonly property real dockSpacingRatio: 0.08
    readonly property real dockSurfaceHorizontalPaddingRatio: 0.14
    readonly property real dockIndicatorSizeRatio: 0.10
    readonly property real dockIndicatorGapRatio: 0.08
    readonly property real dockUtilityRadiusRatio: 0.39
    readonly property real dockHoverCircleRatio: 1.08
    readonly property real dockHoverLabelMarginRatio: 0.16

    // 51% is the design target; Superellipse caps it at half the
    // shorter dimension so the geometry remains valid and continuous.
    readonly property real barCornerRatio: 0.51
    readonly property real topCornerRadius: topSurfaceHeight * barCornerRatio
    readonly property real dockCornerExponent: 4.0
    readonly property real dockMagnificationScale: 1.42
    readonly property real dockMagnificationSpread: 2.6
    readonly property int dockAnimationDuration: 140

    readonly property real surfaceBorderWidth: 1
    readonly property color surfaceFill: Qt.rgba(0.10, 0.11, 0.15, 0.055)
    readonly property color dockFill: Qt.rgba(0.10, 0.11, 0.15, 0.94)
    readonly property color surfaceBorder: Qt.rgba(1, 1, 1, 0.035)
    readonly property color dockBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color surfaceHighlight: Qt.rgba(1, 1, 1, 0.055)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.55)
    readonly property real shadowOpacity: 0.12
    readonly property real shadowOffsetY: 2
}
