import QtQuick

// Moonlit Hearth live layer. Runs the wallpaper through hearth.frag: falling
// snow, breathing moon halo, drifting cloud veil, hearth-lit windows, chimney
// smoke and frost glints. Per-wallpaper geometry is in wallpaper uv space
// (0..1 across the 2560x1440 image) measured on each plate.
Item {
  id: layer

  required property string stem       // e.g. "0-moonlithearth-hearth"
  required property url wallpaper
  property bool running: false
  property real time: 0

  // Wallpaper → screen mapping for Image.PreserveAspectCrop, in uv.
  readonly property real wallW: 2560
  readonly property real wallH: 1440
  readonly property real k: Math.max(width / wallW, height / wallH)
  readonly property real ux0: (wallW * k - width) / 2 / (wallW * k)
  readonly property real uy0: (wallH * k - height) / 2 / (wallH * k)
  readonly property real usx: width / (wallW * k)
  readonly property real usy: height / (wallH * k)

  // moon: [x, y, radius (fraction of height), halo]; windows: [x0, y0, x1, y1];
  // chimney: [x, y, wind, plume scale]. Measured on the 2560x1440 plates.
  readonly property var scenes: ({
    "0-moonlithearth-hearth":    { moon: [0.705, 0.280, 0.186, 1.0], win0: [0.887, 0.560, 0.925, 0.645], win1: [0.755, 0.585, 0.795, 0.670],
                                   chimney: [0.805, 0.372, 0.30, 1.0], smoke: 1, snow: 0.7 },
    "1-moonlithearth-snowfall":  { moon: [0.155, 0.370, 0.142, 0.8], win0: [0.690, 0.730, 0.720, 0.780], win1: [0.860, 0.730, 0.880, 0.775],
                                   chimney: [0.840, 0.455, 0.35, 0.9], smoke: 1, snow: 1.0 },
    "2-moonlithearth-frostmoon": { moon: [0.235, 0.200, 0.210, 1.0], win0: [0.805, 0.780, 0.830, 0.835], win1: [0.880, 0.780, 0.900, 0.835],
                                   chimney: [0.905, 0.540, 0.25, 0.7], smoke: 1, snow: 0.5 },
    "3-moonlithearth-porch":     { moon: [0.250, 0.220, 0.235, 1.0], win0: [0.590, 0.600, 0.640, 0.740], win1: [0, 0, 0, 0],
                                   chimney: [0, 0, 0, 1], smoke: 0, snow: 0.8 }
  })
  readonly property var scene: scenes[stem] || scenes["0-moonlithearth-hearth"]

  // Map a wallpaper-uv point/rect to screen uv (the shader sees screen uv).
  function px(x) { return (x - ux0) / usx }
  function py(y) { return (y - uy0) / usy }

  Timer {
    interval: 33
    repeat: true
    running: layer.running
    onTriggered: layer.time = (layer.time + interval / 1000) % 3600
  }

  Image {
    id: plate
    anchors.fill: parent
    source: layer.wallpaper
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent
    visible: plate.status === Image.Ready
    property var source: plate
    property real time: layer.time
    property real aspect: width / Math.max(1, height)
    property real snow: layer.scene.snow
    property real smokeOn: layer.scene.smoke
    property vector4d moon: Qt.vector4d(layer.px(layer.scene.moon[0]), layer.py(layer.scene.moon[1]),
                                        layer.scene.moon[2] / layer.usy, layer.scene.moon[3])
    property vector4d win0: Qt.vector4d(layer.px(layer.scene.win0[0]), layer.py(layer.scene.win0[1]),
                                        layer.px(layer.scene.win0[2]), layer.py(layer.scene.win0[3]))
    property vector4d win1: Qt.vector4d(layer.px(layer.scene.win1[0]), layer.py(layer.scene.win1[1]),
                                        layer.px(layer.scene.win1[2]), layer.py(layer.scene.win1[3]))
    property vector4d chimney: Qt.vector4d(layer.px(layer.scene.chimney[0]), layer.py(layer.scene.chimney[1]),
                                           layer.scene.chimney[2], layer.scene.chimney[3])
    property color glowColor: "#f0b35e"
    property color moonColor: "#bcd7f0"
    fragmentShader: Qt.resolvedUrl("hearth.frag.qsb")
  }
}
