import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Particles
import qs.Commons
import qs.Ui

// Moonlit Hearth login intro. Plays once per boot (marker in $XDG_RUNTIME_DIR),
// so shell restarts don't replay it. Timeline, ~5.6 s:
//   night fades into the live hearth scene while the view settles from a
//   slow zoom; snow falls and gets pulled into the centre; the moon-and-cabin
//   badge blooms out of it inside a drawn ring; "Moonlit Hearth" fades in;
//   then an iris with a moonlight rim opens from the badge onto the desktop.
//   Everything is unloaded afterwards (zero cost).
// Replay: `omarchy-shell -q intro play`.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  readonly property string markerPath: runtimeDir + "/moonlit-hearth-intro-done"
  readonly property string currentBackgroundLink: home + "/.local/state/omarchy/current/background"
  readonly property string userName: Quickshell.env("USER") || ""

  readonly property color snow: "#e4eef7"
  readonly property color nebula: "#8fbbe0"
  readonly property color glacier: "#f0c47a"
  readonly property string sceneStem: {
    var name = backgroundPath.substring(backgroundPath.lastIndexOf("/") + 1)
    return name.replace(/\.[^.]+$/, "")
  }

  // Bundled Cormorant Garamond; falls back to the shell font if it can't load.
  FontLoader { id: cormorant; source: Qt.resolvedUrl("fonts/CormorantGaramond-Italic.ttf") }
  readonly property string displayFont: cormorant.status === FontLoader.Ready ? cormorant.font.family : Style.font.family

  property string backgroundPath: ""
  property bool playing: false
  property bool wantPlay: false
  property real t: 0
  property real sky: 0
  property real gather: 0
  property real badgeIn: 0
  property real textIn: 0
  property real iris: 0
  property date now: new Date()


  function play() {
    if (playing) return
    wantPlay = true
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function start() {
    wantPlay = false
    now = new Date()
    t = 0; sky = 0; gather = 0; badgeIn = 0; textIn = 0; iris = 0
    playing = true
    timeline.restart()
  }

  Process {
    id: firstRunProc
    command: ["sh", "-c", "[ -e \"$1\" ] && exit 1; touch \"$1\"", "sh", root.markerPath]
    onExited: function(code) { if (code === 0) root.play() }
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: {
        root.backgroundPath = String(text || "").trim()
        if (root.wantPlay) root.start()
      }
    }
  }

  IpcHandler {
    target: "intro"

    function play(): void {
      root.play()
    }

    function stop(): void {
      timeline.stop()
      root.playing = false
    }
  }

  Component.onCompleted: firstRunProc.running = true

  Timer {
    interval: 16
    repeat: true
    running: root.playing
    onTriggered: root.t += interval / 1000
  }

  SequentialAnimation {
    id: timeline

    ParallelAnimation {
      NumberAnimation { target: root; property: "sky"; from: 0; to: 1; duration: 1500; easing.type: Easing.OutCubic }
      SequentialAnimation {
        PauseAnimation { duration: 450 }
        NumberAnimation { target: root; property: "gather"; from: 0; to: 1; duration: 1300; easing.type: Easing.InOutQuad }
      }
      SequentialAnimation {
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: root; property: "badgeIn"; from: 0; to: 1; duration: 900; easing.type: Easing.OutBack }
      }
      SequentialAnimation {
        PauseAnimation { duration: 2100 }
        NumberAnimation { target: root; property: "textIn"; from: 0; to: 1; duration: 1000; easing.type: Easing.OutCubic }
      }
    }
    PauseAnimation { duration: 1100 }
    NumberAnimation { target: root; property: "iris"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutCubic }
    ScriptAction { script: root.playing = false }
  }

  Loader {
    active: root.playing

    sourceComponent: Variants {
      model: Quickshell.screens

      PanelWindow {
        id: panel
        required property var modelData

        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-intro"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Click-through: the desktop is usable the moment it shows.
        mask: Region {}

        readonly property real cx: width / 2
        readonly property real cy: height / 2 - 40
        readonly property real irisRadius: root.iris * Math.hypot(width, height) * 0.62

        Item {
          id: scene
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: irisMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.08
          }

          Rectangle {
            anchors.fill: parent
            color: Color.background
          }

          // Hearth scene, settling from a slow zoom as it fades in.
          Item {
            anchors.fill: parent
            opacity: root.sky
            scale: 1.12 - 0.12 * root.sky

            Image {
              id: wallpaper
              anchors.fill: parent
              source: root.backgroundPath ? Util.fileUrl(root.backgroundPath) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
            }

            Loader {
              anchors.fill: parent
              active: root.backgroundPath.indexOf("moonlithearth") !== -1
              sourceComponent: HearthLayer {
                stem: root.sceneStem
                wallpaper: Util.fileUrl(root.backgroundPath)
                running: root.playing
              }
            }
          }

          // Night scrim that lifts as the badge arrives.
          Rectangle {
            anchors.fill: parent
            color: Color.background
            opacity: 0.45 - 0.2 * root.badgeIn
          }

          // --- Snow: falls from the top, gets drawn into the centre ---------
          ParticleSystem {
            id: particles
            anchors.fill: parent
          }

          ImageParticle {
            system: particles
            anchors.fill: parent
            source: "qrc:///particleresources/glowdot.png"
            color: root.snow
            colorVariation: 0.08
            alpha: 0.95
            entryEffect: ImageParticle.Fade
          }

          Emitter {
            id: snowfall
            system: particles
            x: 0
            y: 0
            width: parent.width
            height: parent.height * 0.3
            enabled: root.sky > 0.15 && root.badgeIn < 0.6
            emitRate: 45
            lifeSpan: 3200
            lifeSpanVariation: 800
            size: 14
            sizeVariation: 8
            endSize: 8
            velocity: AngleDirection { angle: 90; angleVariation: 35; magnitude: 40; magnitudeVariation: 25 }
          }

          Attractor {
            system: particles
            anchors.fill: parent
            pointX: panel.cx
            pointY: panel.cy
            affectedParameter: Attractor.Velocity
            proportionalToDistance: Attractor.Linear
            strength: 2.4 * root.gather
          }

          // Flakes that reach the badge are absorbed into it.
          Age {
            system: particles
            x: panel.cx - 55
            y: panel.cy - 55
            width: 110
            height: 110
            lifeLeft: 250
            once: true
          }

          Wander {
            system: particles
            anchors.fill: parent
            xVariance: 30
            yVariance: 20
            pace: 60
          }

          // Bloom when the badge is born out of the gathered light.
          Rectangle {
            x: panel.cx - width / 2
            y: panel.cy - height / 2
            width: 120 + 520 * root.badgeIn
            height: width
            radius: width / 2
            color: root.snow
            opacity: root.badgeIn > 0 ? 0.5 * Math.max(0, 1 - root.badgeIn * 1.4) : 0
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
          }

          // --- Badge + greeting ---------------------------------------------
          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: panel.cy - 85
            spacing: 0
            opacity: Math.max(0, 1 - root.iris * 1.6)
            scale: 1 + 0.25 * root.iris
            transformOrigin: Item.Top

            Item {
              id: badgeBox
              anchors.horizontalCenter: parent.horizontalCenter
              width: 170
              height: 170
              opacity: Math.min(1, root.badgeIn)
              scale: (0.55 + 0.45 * root.badgeIn) * 1.3

              Rectangle {
                anchors.centerIn: parent
                width: 150; height: 150; radius: 75
                color: "transparent"
                border.width: 10
                border.color: Util.alpha(Color.accent, 0.6 + 0.3 * Math.sin(root.t * 2.2))
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 40 }
              }

              // Aurora ring that draws itself around the badge.
              Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  strokeColor: "transparent"
                  fillGradient: ConicalGradient {
                    centerX: 85; centerY: 85
                    angle: -root.t * 60
                    GradientStop { position: 0.0; color: Color.accent }
                    GradientStop { position: 0.3; color: root.nebula }
                    GradientStop { position: 0.55; color: root.snow }
                    GradientStop { position: 0.8; color: root.glacier }
                    GradientStop { position: 1.0; color: Color.accent }
                  }
                  // A 3px band: outer arc forward, inner arc back.
                  PathAngleArc {
                    moveToStart: true
                    centerX: 85; centerY: 85
                    radiusX: 77.5; radiusY: 77.5
                    startAngle: -90
                    sweepAngle: 359.9 * Math.min(1, root.badgeIn)
                  }
                  PathAngleArc {
                    moveToStart: false
                    centerX: 85; centerY: 85
                    radiusX: 74.5; radiusY: 74.5
                    startAngle: -90 + 359.9 * Math.min(1, root.badgeIn)
                    sweepAngle: -359.9 * Math.min(1, root.badgeIn)
                  }
                }
              }

              Image {
                anchors.centerIn: parent
                width: 138; height: 138
                source: Qt.resolvedUrl("hearth-badge.png")
                sourceSize: Qt.size(276, 276)
                smooth: true
                mipmap: true
              }
            }

            Item { width: 1; height: 26 + 85 * 0.3 }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: "Moonlit Hearth"
              color: Qt.lighter(Color.foreground, 1.18)
              font.family: root.displayFont
              font.pixelSize: 66
              font.italic: true
              font.weight: Font.Light
              font.letterSpacing: 2 + 14 * (1 - root.textIn)
              opacity: root.textIn
              layer.enabled: true
              layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.snow
                shadowBlur: 1.0
                shadowOpacity: 0.55 + 0.2 * Math.sin(root.t * 2.4)
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
              }
            }

            Item { width: 1; height: 10 }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: "❄   come in from the cold" + (root.userName ? ", " + root.userName : "") + "   ❄"
              color: Util.alpha(Color.foreground, 0.8)
              font.family: root.displayFont
              font.pixelSize: 16
              font.letterSpacing: 5
              opacity: Math.max(0, root.textIn * 1.4 - 0.4)
            }
          }
        }

        // Iris mask: opaque everywhere except a growing hole at the badge.
        Item {
          id: irisMask
          anchors.fill: parent
          visible: false
          layer.enabled: true

          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: "white"
              strokeColor: "transparent"
              fillRule: ShapePath.OddEvenFill
              PathRectangle { x: -2; y: -2; width: panel.width + 4; height: panel.height + 4 }
              PathAngleArc {
                moveToStart: true
                centerX: panel.cx; centerY: panel.cy
                radiusX: panel.irisRadius; radiusY: panel.irisRadius
                startAngle: 0; sweepAngle: 360
              }
            }
          }
        }

        // Glowing moonlight rim riding the iris edge.
        Rectangle {
          x: panel.cx - width / 2
          y: panel.cy - height / 2
          width: panel.irisRadius * 2
          height: width
          radius: width / 2
          visible: root.iris > 0 && root.iris < 1
          color: "transparent"
          border.width: 4
          border.color: root.snow
          opacity: Math.min(1, root.iris * 6) * (1 - root.iris)
          layer.enabled: visible
          layer.effect: MultiEffect {
            blurEnabled: true; blur: 0.6; blurMax: 24
            shadowEnabled: true; shadowColor: root.snow; shadowBlur: 1.0; shadowOpacity: 0.9
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
          }
        }
      }
    }
  }
}
