import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Particles
import SddmComponents 2.0

// Moonlit Hearth SDDM greeter: the Moonlit Hearth lock screen brought to the
// login screen. The wallpaper plate runs through HearthLayer (snow, moon halo,
// lit windows, chimney smoke) behind the moon-and-cabin badge, a glowing
// clock and a password pill with a warm firelight glow. Pick the plate with
// Scene= in theme.conf (0-moonlithearth-hearth, 1-...-snowfall, 2-...-frostmoon,
// 3-...-porch).
Rectangle {
  id: root
  width: 1920
  height: 1080
  color: pal.background

  readonly property string mood: config.Scene || "0-moonlithearth-hearth"

  // Theme colors (colors.toml of moonlit-hearth).
  QtObject {
    id: pal
    readonly property color background: "#0a1424"
    readonly property color foreground: "#d4e3f0"
    readonly property color accent: "#8fbbe0"
    readonly property color urgent: "#d27a6a"
    readonly property color muted: "#5d7590"
    readonly property color hearthGlow: "#f0c47a"
    readonly property color nebula: "#8fbbe0"
    readonly property color glacier: "#e4eef7"
    readonly property color clock: Qt.lighter(foreground, 1.18)
  }

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  readonly property string monoFont: "JetBrainsMono Nerd Font"
  FontLoader { id: cormorant; source: "assets/CormorantGaramond-Italic.ttf" }
  readonly property string displayFont: cormorant.status === FontLoader.Ready ? cormorant.font.family : monoFont

  // --- Login state ----------------------------------------------------------
  property string currentUser: userModel.lastUser
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }
  property bool authenticating: false
  property string failureMessage: ""
  readonly property bool errorState: failureMessage.length > 0

  Connections {
    target: sddm
    function onLoginFailed() {
      root.authenticating = false
      root.failureMessage = "the door is still latched"
      passwordInput.text = ""
      passwordInput.forceActiveFocus()
      shakeAnimation.restart()
      sparkEmitter.burst(14)
    }
    function onLoginSucceeded() {
      root.failureMessage = ""
    }
  }

  function submit() {
    if (passwordInput.text.length === 0 || authenticating) return
    authenticating = true
    sparkEmitter.burst(10)
    sddm.login(currentUser, passwordInput.text, sessionIndex)
  }

  // --- Clocks ---------------------------------------------------------------
  property real t: 0
  property real ringAngle: 0
  property real intro: 0
  property real shake: 0
  property real typingPulse: 0
  property date now: new Date()
  property int lastLength: 0

  Timer {
    interval: 33
    repeat: true
    running: true
    onTriggered: {
      var dt = interval / 1000
      root.t += dt
      var speed = root.authenticating ? 320 : (root.errorState ? 12 : 28)
      root.ringAngle = (root.ringAngle + dt * speed) % 360
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  NumberAnimation on intro { from: 0; to: 1; duration: 1800; easing.type: Easing.OutCubic }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: root; property: "shake"; to: 16; duration: 45; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shake"; to: -13; duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shake"; to: 9; duration: 65; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shake"; to: -5; duration: 60; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shake"; to: 0; duration: 80; easing.type: Easing.OutQuad }
  }

  NumberAnimation {
    id: typingPulseAnimation
    target: root
    property: "typingPulse"
    from: 1
    to: 0
    duration: 700
    easing.type: Easing.OutCubic
  }

  // --- Backdrop -------------------------------------------------------------
  Item {
    id: sky
    anchors.fill: parent
    scale: 1.0 + 0.03 * (0.5 - 0.5 * Math.cos(root.t * 2 * Math.PI / 70))
    opacity: 0.25 + 0.75 * root.intro

    Image {
      id: wallpaper
      anchors.fill: parent
      source: "assets/" + root.mood + ".jpg"
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }

    Loader {
      anchors.fill: parent
      Component.onCompleted: setSource("assets/HearthLayer.qml", {
        stem: root.mood, wallpaper: Qt.resolvedUrl("assets/" + root.mood + ".jpg"), running: true
      })
    }
  }

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.alpha(pal.background, 0.55) }
      GradientStop { position: 0.45; color: root.alpha(pal.background, 0.12) }
      GradientStop { position: 1.0; color: root.alpha(pal.background, 0.55) }
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: root.width / 2; centerY: root.height / 2
        focalX: centerX; focalY: centerY
        centerRadius: Math.min(root.width, root.height) * 0.55
        focalRadius: 0
        GradientStop { position: 0.0; color: root.alpha(pal.background, 0.55) }
        GradientStop { position: 0.6; color: root.alpha(pal.background, 0.18) }
        GradientStop { position: 1.0; color: "transparent" }
      }
      PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: passwordInput.forceActiveFocus()
  }

  // --- Snow ----------------------------------------------------------------
  ParticleSystem { id: particles; anchors.fill: parent }

  ImageParticle {
    system: particles
    groups: ["spark"]
    anchors.fill: parent
    // Keystrokes drop snowflakes that tumble off the field.
    source: "assets/hearth-flake.png"
    color: root.errorState ? pal.urgent : "#eef5fc"
    colorVariation: 0.03
    rotationVariation: 180
    rotationVelocityVariation: 90
    entryEffect: ImageParticle.Fade
  }

  // Big soft flakes drifting down past the centre block.
  ImageParticle {
    system: particles
    groups: ["flake"]
    anchors.fill: parent
    source: "qrc:///particleresources/glowdot.png"
    color: "#e4eef7"
    colorVariation: 0.04
    alpha: 0.75
    entryEffect: ImageParticle.Fade
  }

  Emitter {
    system: particles
    group: "flake"
    x: -parent.width * 0.1
    y: -20
    width: parent.width * 1.2
    height: 10
    emitRate: 6
    lifeSpan: 16000
    lifeSpanVariation: 4000
    size: 14
    sizeVariation: 8
    endSize: 10
    velocity: AngleDirection { angle: 95; angleVariation: 12; magnitude: 70; magnitudeVariation: 30 }
  }

  Wander {
    system: particles
    groups: ["flake"]
    anchors.fill: parent
    xVariance: 60
    pace: 40
  }

  // --- Centre block ---------------------------------------------------------
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -30 + 30 * (1 - root.intro)
    opacity: root.intro
    spacing: 0

    Item {
      id: badgeBox
      anchors.horizontalCenter: parent.horizontalCenter
      readonly property real zoom: 1.3
      width: 170 * zoom
      height: 170 * zoom

      Item {
        width: 170
        height: 170
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 5 * Math.sin(root.t * 0.8)
        scale: badgeBox.zoom

        Rectangle {
          anchors.centerIn: parent
          width: 150; height: 150; radius: 75
          color: "transparent"
          border.width: 10
          border.color: root.alpha(pal.accent, 0.6 + 0.3 * Math.sin(root.t * 1.3))
          layer.enabled: true
          layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 40 }
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
              centerX: 85; centerY: 85
              angle: -root.ringAngle * 1.6
              GradientStop { position: 0.0; color: pal.accent }
              GradientStop { position: 0.3; color: pal.nebula }
              GradientStop { position: 0.55; color: root.alpha(pal.hearthGlow, 0.15) }
              GradientStop { position: 0.8; color: pal.glacier }
              GradientStop { position: 1.0; color: pal.accent }
            }
            PathRectangle { x: 10; y: 10; width: 150; height: 150; radius: 75 }
            PathRectangle { x: 12.5; y: 12.5; width: 145; height: 145; radius: 72.5 }
          }
        }

        Image {
          anchors.centerIn: parent
          width: 138; height: 138
          source: "assets/hearth-badge.png"
          sourceSize: Qt.size(276, 276)
          smooth: true
          mipmap: true
        }
      }
    }

    Item { width: 1; height: 18 }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: "❄   come in from the cold" + (root.currentUser ? ", " + root.currentUser : "") + "   ❄"
      color: root.alpha(pal.foreground, 0.85)
      font.family: root.displayFont
      font.pixelSize: 24
      font.letterSpacing: 1.5
    }

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: clockRow.implicitWidth
      height: clockRow.implicitHeight - 20

      Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 2
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: pal.hearthGlow
          shadowBlur: 1.0
          shadowOpacity: 0.5 + 0.2 * Math.sin(root.t * 0.9)
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          blurMax: 48
        }

        Repeater {
          model: ["HH", ":", "mm"]
          Text {
            textFormat: Text.PlainText
            text: modelData === ":" ? ":" : Qt.formatTime(root.now, modelData)
            color: pal.clock
            opacity: modelData === ":" ? 0.3 + 0.7 * (0.5 + 0.5 * Math.cos(root.t * Math.PI)) : 1
            font.family: root.displayFont
            font.pixelSize: 132
            font.weight: Font.Light
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: Qt.formatDate(root.now, "dddd  ·  d MMMM").toUpperCase()
      color: Qt.lighter(pal.accent, 1.25)
      font.family: root.displayFont
      font.pixelSize: 16
      font.letterSpacing: 6
    }

    Item { width: 1; height: 52 }

    // --- Password field -----------------------------------------------------
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 420 + 60
      height: 62 + 60

      Item {
        id: field
        width: 420
        height: 62
        x: 30 + root.shake
        y: 30
        readonly property real r: height / 2
        readonly property int ring: 2

        // Warm firelight behind the field, swelling as you type.
        Rectangle {
          visible: true
          anchors.centerIn: parent
          width: parent.width + 110
          height: parent.height + 80
          radius: height / 2
          color: root.errorState ? pal.urgent : "#f0b35e"
          opacity: 0.2 + 0.04 * Math.sin(root.t * 2.3) + 0.02 * Math.sin(root.t * 5.7) + 0.25 * root.typingPulse
          layer.enabled: true
          layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          opacity: (root.errorState ? 0.9 : 0.45 + 0.15 * Math.sin(root.t * 1.1)) + 0.5 * root.typingPulse
          layer.enabled: true
          layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 36 }
          ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ringGradient
            PathRectangle { x: -3; y: -3; width: field.width + 6; height: field.height + 6; radius: field.r + 3 }
            PathRectangle { x: 3; y: 3; width: field.width - 6; height: field.height - 6; radius: field.r - 3 }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: field.r
          color: root.alpha(pal.background, 0.72)
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
              id: ringGradient
              centerX: field.width / 2; centerY: field.height / 2
              angle: root.ringAngle
              GradientStop { position: 0.0; color: root.errorState ? pal.urgent : pal.accent }
              GradientStop { position: 0.25; color: root.errorState ? Qt.darker(pal.urgent, 1.6) : pal.nebula }
              GradientStop { position: 0.5; color: root.errorState ? pal.urgent : pal.hearthGlow }
              GradientStop { position: 0.75; color: root.errorState ? Qt.darker(pal.urgent, 1.6) : pal.glacier }
              GradientStop { position: 1.0; color: root.errorState ? pal.urgent : pal.accent }
            }
            PathRectangle { x: 0; y: 0; width: field.width; height: field.height; radius: field.r }
            PathRectangle {
              x: field.ring; y: field.ring
              width: field.width - 2 * field.ring; height: field.height - 2 * field.ring
              radius: field.r - field.ring
            }
          }
        }

        Emitter {
          id: sparkEmitter
          system: particles
          group: "spark"
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: field.r
          anchors.rightMargin: field.r
          y: 0
          height: 4
          enabled: false
          lifeSpan: 2200
          lifeSpanVariation: 400
          size: 15
          sizeVariation: 6
          endSize: 9
          velocity: AngleDirection { angle: 270; angleVariation: 70; magnitude: 45; magnitudeVariation: 20 }
          acceleration: PointDirection { y: 60 }
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.leftMargin: field.r
          anchors.rightMargin: field.r
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          clip: true
          focus: true
          readOnly: root.authenticating
          echoMode: TextInput.Password
          passwordCharacter: "●"
          passwordMaskDelay: 0
          color: pal.clock
          selectionColor: pal.accent
          font.family: root.monoFont
          font.pixelSize: text.length > 0 ? 28 : 23
          font.letterSpacing: text.length > 0 ? 7 : 0
          cursorDelegate: Rectangle {
            width: 2
            color: pal.hearthGlow
            visible: passwordInput.activeFocus && passwordInput.text.length > 0 && !root.authenticating
          }

          onTextChanged: {
            if (text.length > root.lastLength) {
              sparkEmitter.burst(4)
              typingPulseAnimation.restart()
            }
            root.lastLength = text.length
            if (text.length > 0) root.failureMessage = ""
          }

          onAccepted: root.submit()

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              text = ""
              event.accepted = true
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.fill: passwordInput
          text: root.authenticating ? "Checking…" : (root.errorState ? root.failureMessage : "Enter Password")
          visible: passwordInput.text.length === 0
          color: root.errorState ? pal.urgent : root.alpha(pal.foreground, 0.5)
          opacity: root.authenticating ? 0.55 + 0.45 * Math.sin(root.t * 6) : 1
          font.family: root.monoFont
          font.pixelSize: 23
          font.italic: root.errorState
          font.letterSpacing: 1
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: "the hearth is lit" + "   ·   esc to clear"
      color: root.alpha(pal.foreground, 0.35)
      font.family: root.monoFont
      font.pixelSize: 12
      font.letterSpacing: 2
    }
  }

  // --- Power ----------------------------------------------------------------
  Row {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 32
    spacing: 28
    opacity: 0.35 + 0.65 * root.intro * (powerHover.containsMouse || rebootHover.containsMouse ? 1 : 0.5)

    Text {
      text: "󰜉"
      color: rebootHover.containsMouse ? pal.accent : pal.foreground
      font.family: root.monoFont
      font.pixelSize: 22
      visible: sddm.canReboot
      MouseArea { id: rebootHover; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; onClicked: sddm.reboot() }
    }
    Text {
      text: "󰐥"
      color: powerHover.containsMouse ? pal.urgent : pal.foreground
      font.family: root.monoFont
      font.pixelSize: 22
      visible: sddm.canPowerOff
      MouseArea { id: powerHover; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; onClicked: sddm.powerOff() }
    }
  }

  Component.onCompleted: passwordInput.forceActiveFocus()
}
