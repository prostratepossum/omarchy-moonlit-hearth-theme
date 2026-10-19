import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// Moonlit Hearth clicks: small, slow and quiet.
//   left   a snowflake turns as it drifts down and to the left
//   right  the same, drifting right
//   middle a faint frost ring and a few settling motes
// clickwatch.py reports button presses; the overlay window only exists while
// a burst is playing and is click-through, and nothing plays over fullscreen
// windows (games, video). Toggle: `omarchy-shell -q clicks toggle`.
Item {
  id: root

  readonly property color snow: "#e4eef7"
  readonly property color frost: "#d4e3f0"

  property bool enabled: true
  property int maxBursts: 12
  readonly property string helper: String(Qt.resolvedUrl("clickwatch.py")).replace(/^file:\/\//, "")

  ListModel { id: bursts }
  property int nextId: 0

  function spawn(button, gx, gy) {
    if (!enabled || bursts.count >= maxBursts) return
    bursts.append({ bid: nextId++, button: button, gx: gx, gy: gy, born: Date.now() })
  }

  function finish(bid) {
    for (var i = 0; i < bursts.count; i++) {
      if (bursts.get(i).bid === bid) { bursts.remove(i); return }
    }
  }

  Process {
    id: watcher
    running: root.enabled
    command: ["setpriv", "--pdeathsig", "TERM", "/usr/bin/python3", root.helper]
    // Exit code 3 = python-evdev missing; retrying would not help.
    onExited: function(code) { if (root.enabled && code !== 3) restartTimer.restart() }
    stdout: SplitParser {
      onRead: function(line) {
        var p = String(line).trim().split(" ")
        if (p.length === 3) root.spawn(p[0], Number(p[1]), Number(p[2]))
      }
    }
  }

  // A crashed or unplugged watcher comes back on its own.
  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: if (root.enabled && !watcher.running) watcher.running = true
  }

  IpcHandler {
    target: "clicks"
    function toggle(): void { root.enabled = !root.enabled }
    function setEnabled(on: bool): void { root.enabled = on }
    function test(): void {
      var s = Quickshell.screens[0]
      root.spawn("L", s.x + s.width / 2, s.y + s.height / 2)
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
      readonly property bool covered: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)

      function mine(gx, gy) {
        return gx >= modelData.x && gx < modelData.x + modelData.width
          && gy >= modelData.y && gy < modelData.y + modelData.height
      }

      screen: modelData
      visible: bursts.count > 0
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "moonlit-hearth-clicks"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      Repeater {
        model: bursts

        delegate: Loader {
          id: slot
          required property int bid
          required property string button
          required property real gx
          required property real gy

          active: panel.mine(gx, gy) && !panel.covered
          x: gx - panel.modelData.x
          y: gy - panel.modelData.y
          onActiveChanged: if (!active) root.finish(bid)
          Component.onCompleted: if (!active) Qt.callLater(root.finish, bid)

          sourceComponent: slot.button === "M" ? frostBurst : flakeBurst

          Component {
            id: flakeBurst
            Burst {
              rings: 0
              life: 1700
              onDone: root.finish(slot.bid)
              Snowflake { drift: slot.button === "R" ? 1 : -1 }
            }
          }

          Component {
            id: frostBurst
            Burst {
              ringColor: Qt.rgba(0.83, 0.89, 0.94, 0.55)
              life: 1700
              onDone: root.finish(slot.bid)
              Repeater {
                model: 5
                Mote {
                  required property int index
                  x0: (index - 2) * 6 + (Math.random() - 0.5) * 6
                  fall: 14 + Math.random() * 14
                  delay: Math.random() * 220
                }
              }
            }
          }
        }
      }
    }
  }

  // --- building blocks -----------------------------------------------------

  component Burst: Item {
    id: burst
    property color ringColor: "white"
    property int rings: 1
    signal done()
    default property alias content: holder.data

    Repeater {
      model: burst.rings
      Rectangle {
        required property int index
        property real r: 0
        x: -r; y: -r
        width: r * 2; height: r * 2
        radius: r
        color: "transparent"
        border.width: 1.6
        border.color: burst.ringColor
        opacity: 0
        SequentialAnimation on r {
          PauseAnimation { duration: index * 120 }
          NumberAnimation { from: 3; to: 26 + index * 6; duration: 520; easing.type: Easing.OutCubic }
        }
        SequentialAnimation on opacity {
          PauseAnimation { duration: index * 120 }
          NumberAnimation { from: 0.85; to: 0; duration: 520; easing.type: Easing.InQuad }
        }
      }
    }

    Item { id: holder }

    property int life: 1100
    Timer { interval: burst.life; running: true; onTriggered: burst.done() }
  }

  // A snowflake, turning slowly as it drifts down.
  component Snowflake: Item {
    id: sf
    property real drift: 1
    property real p: 0
    x: sf.drift * 16 * p + 4 * Math.sin(p * 7)
    y: 26 * p
    opacity: p < 0.12 ? p / 0.12 * 0.85 : 0.85 * (1 - Math.pow((p - 0.12) / 0.88, 1.5))
    Text {
      text: "❄"
      textFormat: Text.PlainText
      color: root.snow
      font.pixelSize: 17
      x: -width / 2; y: -height / 2
      rotation: sf.drift * 90 * sf.p
      style: Text.Outline
      styleColor: Qt.rgba(0.04, 0.08, 0.14, 0.35)
    }
    NumberAnimation on p { from: 0; to: 1; duration: 1600; easing.type: Easing.OutSine }
  }

  // Frost motes that settle slowly downward.
  component Mote: Rectangle {
    id: mote
    property real x0: 0
    property real fall: 24
    property int delay: 0
    property real p: 0
    width: 2.2; height: 2.2; radius: 1.1
    color: root.frost
    x: x0 + 3 * Math.sin(p * 5 + x0) - 1.1
    y: -4 + fall * p - 1.1
    opacity: p <= 0 ? 0 : 0.55 * Math.sin(Math.PI * Math.min(1, p * 1.1))
    SequentialAnimation on p {
      PauseAnimation { duration: mote.delay }
      NumberAnimation { from: 0; to: 1; duration: 1400; easing.type: Easing.OutQuad }
    }
  }
}
