// SPDX-License-Identifier: GPL-3.0-only
//
// Neodots - Translucent glass panel surface used by shell components.
//
// Copyright (C) 2026 kaayzouee
// Author: https://github.com/kaayzouee
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
// Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <https://www.gnu.org/licenses/>.

import QtQuick

Item {
    id: root

    default property alias contentData: content.data

    property real cornerRadius: 24
    property real cornerExponent: 4.0
    property color fillColor: Qt.rgba(0.10, 0.11, 0.15, 0.92)
    property color borderColor: Qt.rgba(1, 1, 1, 0.10)
    property real borderWidth: 1
    property color highlightColor: Qt.rgba(1, 1, 1, 0.10)
    property color shadowColor: Qt.rgba(0, 0, 0, 0.55)
    property real shadowOpacity: 0.28
    property real shadowOffsetY: 5
    property int pathSamplesPerCorner: 20

    Superellipse {
        id: shadow

        x: 0
        y: root.shadowOffsetY
        width: root.width
        height: root.height
        cornerRadius: root.cornerRadius
        exponent: root.cornerExponent
        samplesPerCorner: root.pathSamplesPerCorner
        fillColor: root.shadowColor
        opacity: root.shadowOpacity
    }

    Superellipse {
        id: surface

        anchors.fill: parent
        cornerRadius: root.cornerRadius
        exponent: root.cornerExponent
        samplesPerCorner: root.pathSamplesPerCorner
        fillColor: root.fillColor
        strokeColor: root.borderColor
        strokeWidth: root.borderWidth
    }

    Superellipse {
        id: highlight

        x: root.borderWidth * 0.5
        y: root.borderWidth * 0.5
        width: Math.max(0, root.width - root.borderWidth)
        height: Math.max(0, root.height - root.borderWidth)
        cornerRadius: Math.max(0, root.cornerRadius - root.borderWidth * 0.5)
        exponent: root.cornerExponent
        samplesPerCorner: root.pathSamplesPerCorner
        fillColor: "transparent"
        strokeColor: root.highlightColor
        strokeWidth: 1
        opacity: 0.65
    }

    Item {
        id: content

        anchors.fill: parent
    }
}
