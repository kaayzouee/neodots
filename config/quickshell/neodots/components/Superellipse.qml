import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real cornerRadius: 24
    property real exponent: 4.0
    property int samplesPerCorner: 20

    readonly property real effectiveRadius: Math.max(
        0,
        Math.min(root.cornerRadius, Math.min(root.width, root.height) / 2)
    )

    function superCoordinate(value) {
        const exponentPower = 2 / Math.max(2, root.exponent);
        return Math.sign(value) * Math.pow(Math.abs(value), exponentPower);
    }

    function pointOnCorner(centerX, centerY, radius, angle) {
        return Qt.point(
            centerX + radius * root.superCoordinate(Math.cos(angle)),
            centerY + radius * root.superCoordinate(Math.sin(angle))
        );
    }

    function appendCorner(parts, centerX, centerY, startAngle, endAngle, first) {
        const radius = root.effectiveRadius;
        const count = Math.max(4, root.samplesPerCorner);

        for (let i = first ? 0 : 1; i <= count; ++i) {
            const t = i / count;
            const angle = startAngle + (endAngle - startAngle) * t;
            const point = root.pointOnCorner(centerX, centerY, radius, angle);
            parts.push(
                (parts.length === 0 ? "M " : " L ")
                + point.x.toFixed(3)
                + " "
                + point.y.toFixed(3)
            );
        }
    }

    readonly property string pathData: {
        const width = Math.max(0, root.width);
        const height = Math.max(0, root.height);
        const radius = root.effectiveRadius;

        if (width <= 0 || height <= 0) {
            return "M 0 0";
        }

        if (radius <= 0) {
            return "M 0 0 L " + width + " 0 L "
                + width + " " + height + " L 0 " + height + " Z";
        }

        const parts = [];
        parts.push("M " + radius.toFixed(3) + " 0");
        parts.push("L " + (width - radius).toFixed(3) + " 0");

        root.appendCorner(parts, width - radius, radius, -Math.PI / 2, 0, false);

        parts.push("L " + width.toFixed(3) + " " + (height - radius).toFixed(3));
        root.appendCorner(parts, width - radius, height - radius, 0, Math.PI / 2, false);

        parts.push("L " + radius.toFixed(3) + " " + height.toFixed(3));
        root.appendCorner(parts, radius, height - radius, Math.PI / 2, Math.PI, false);

        parts.push("L 0 " + radius.toFixed(3));
        root.appendCorner(parts, radius, radius, Math.PI, Math.PI * 1.5, false);

        parts.push("Z");
        return parts.join("");
    }

    Shape {
        anchors.fill: parent

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.pathData
            }
        }
    }
}
