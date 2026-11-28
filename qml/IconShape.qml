// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Shapes

// The drawing inside Icon: one 24×24 line icon, scaled by Icon.
Shape {
    id: root
    property color color: "black"
    property real stroke: 2
    property string path: ""
    width: 24
    height: 24
    transformOrigin: Item.TopLeft
    // Render into a texture: smooth edges on the GPU, and correct
    // clipping inside scroll areas.
    layer.enabled: true
    layer.samples: 4
    layer.smooth: true
    ShapePath {
        strokeColor: root.color
        strokeWidth: root.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: root.path }
    }
}
