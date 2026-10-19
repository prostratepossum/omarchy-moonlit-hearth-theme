import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Particles
import Quickshell
import qs.Commons
import qs.Ui

// Moonlit Hearth lock screen: the live hearth scene (same HearthLayer as the
// desktop background plugin), the moon-and-cabin badge in a turning ring, a
// glowing clock, and a pill password field with a warm firelight glow. Snow
// drifts down the screen; each keystroke drops a few snowflakes off the field.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 420
  readonly property int fieldHeight: 62
  readonly property int ringThickness: 2
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.05)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.2)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.3)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0

  // Everything animated runs only while this view is actually on screen
  // (the hidden preview instance stays idle).
  readonly property bool active: loadBackground
  readonly property bool liveSky: active && backgroundPath.indexOf("moonlithearth") !== -1
  readonly property string sceneStem: {
    var name = backgroundPath.substring(backgroundPath.lastIndexOf("/") + 1)
    return name.replace(/\.[^.]+$/, "")
  }
  readonly property var lines: [
    "come in from the cold",
    "the hearth is lit",
    "snow on the roof, fire within",
    "rest a while",
    "the moon keeps watch"
  ]
  property int line: 0

  // Bundled Cormorant Garamond; falls back to the shell font if it can't load.
  FontLoader { id: cormorant; source: Qt.resolvedUrl("fonts/CormorantGaramond-Italic.ttf") }
  readonly property string displayFont: cormorant.status === FontLoader.Ready ? cormorant.font.family : Style.font.family

  // Moonlit Hearth palette: hearth amber, moonlight, snow.
  readonly property color hearthGlow: "#f0c47a"
  readonly property color nebula: "#8fbbe0"
  readonly property color glacier: "#e4eef7"
  readonly property color clockColor: Qt.lighter(Color.foreground, 1.18)
  readonly property string userName: Quickshell.env("USER") || ""

  property real t: 0
  property real ringAngle: 0
  property real intro: 0
  property real shake: 0
  property real typingPulse: 0
  property date now: new Date()
  property int lastLength: 0

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function greeting() {
    return lines[line % lines.length]
  }

  function playIntro() {
    line = Math.floor(Math.random() * lines.length)
    intro = 0
    introAnimation.restart()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onActiveChanged: if (active) playIntro()
  onFailureMessageChanged: {
    if (failureMessage.length > 0) {
      shakeAnimation.restart()
      sparkEmitter.burst(14)
    }
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    if (active) playIntro()
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  // Shared ~30 fps clock for the sky shader, ring rotation and floating bits.
  Timer {
    interval: 33
    repeat: true
    running: root.active
    onTriggered: {
      var dt = interval / 1000
      root.t += dt
      var speed = root.authenticatingPassword ? 320 : (root.errorState ? 12 : 28)
      root.ringAngle = (root.ringAngle + dt * speed) % 360
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.active
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  NumberAnimation {
    id: introAnimation
    target: root
    property: "intro"
    from: 0
    to: 1
    duration: 1400
    easing.type: Easing.OutCubic
  }

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

  Rectangle {
    anchors.fill: parent
    color: Color.background

    // --- Sky ---------------------------------------------------------------
    // Very slow breathing zoom; HearthLayer adds snow, the moon halo, the lit
    // windows and chimney smoke on moonlithearth wallpapers.
    Item {
      id: sky
      anchors.fill: parent
      scale: 1.0 + 0.03 * (0.5 - 0.5 * Math.cos(root.t * 2 * Math.PI / 70))
      opacity: 0.25 + 0.75 * root.intro

      Image {
        id: wallpaper
        anchors.fill: parent
        source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }

      Loader {
        anchors.fill: parent
        active: root.liveSky
        sourceComponent: HearthLayer {
          stem: root.sceneStem
          wallpaper: root.fileUrl(root.backgroundPath)
          running: root.active
        }
      }
    }

    // Night scrim: darker overhead and at the foot so the text reads, the
    // moon and cabin still shine through the middle.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Util.alpha(Color.background, 0.55) }
        GradientStop { position: 0.45; color: Util.alpha(Color.background, 0.12) }
        GradientStop { position: 1.0; color: Util.alpha(Color.background, 0.55) }
      }
    }

    // Soft pool of shadow behind the centre block.
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
          GradientStop { position: 0.0; color: Util.alpha(Color.background, 0.55) }
          GradientStop { position: 0.6; color: Util.alpha(Color.background, 0.18) }
          GradientStop { position: 1.0; color: "transparent" }
        }
        PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // --- Snow --------------------------------------------------------------
    ParticleSystem {
      id: particles
      anchors.fill: parent
      running: root.active
    }

    // Big soft flakes drifting down past the centre block.
    ImageParticle {
      system: particles
      groups: ["ambient"]
      anchors.fill: parent
      source: "qrc:///particleresources/glowdot.png"
      color: root.glacier
      colorVariation: 0.04
      alpha: 0.75
      entryEffect: ImageParticle.Fade
    }

    // Keystroke snowflakes: they tumble off the field and drift back down.
    ImageParticle {
      system: particles
      groups: ["spark"]
      anchors.fill: parent
      source: Qt.resolvedUrl("hearth-flake.png")
      color: root.errorState ? Color.urgent : "#eef5fc"
      colorVariation: 0.03
      rotationVariation: 180
      rotationVelocityVariation: 90
      entryEffect: ImageParticle.Fade
    }

    Emitter {
      system: particles
      group: "ambient"
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
      groups: ["ambient"]
      anchors.fill: parent
      xVariance: 60
      pace: 40
    }

    // --- Centre block ------------------------------------------------------
    Column {
      id: centre
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -30 + 30 * (1 - root.intro)
      opacity: root.intro
      spacing: 0

      // Moon-and-cabin badge in a counter-turning halo, gently floating.
      Item {
        id: badgeBox
        anchors.horizontalCenter: parent.horizontalCenter
        width: 170 * 1.3
        height: 170 * 1.3

        Item {
          id: badgeFloat
          width: 170
          height: 170
          scale: 1.3
          anchors.horizontalCenter: parent.horizontalCenter
          y: (parent.height - height) / 2
          transform: Translate { y: 5 * Math.sin(root.t * 0.8) }

          Rectangle {
            anchors.centerIn: parent
            width: 150; height: 150; radius: 75
            color: "transparent"
            border.width: 10
            border.color: Util.alpha(Color.accent, 0.6 + 0.3 * Math.sin(root.t * 1.3))
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
                GradientStop { position: 0.0; color: Color.accent }
                GradientStop { position: 0.3; color: root.nebula }
                GradientStop { position: 0.55; color: Util.alpha(root.hearthGlow, 0.15) }
                GradientStop { position: 0.8; color: root.glacier }
                GradientStop { position: 1.0; color: Color.accent }
              }
              PathRectangle { x: 10; y: 10; width: 150; height: 150; radius: 75 }
              PathRectangle { x: 12.5; y: 12.5; width: 145; height: 145; radius: 72.5 }
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
      }

      Item { width: 1; height: 18 }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "❄   " + root.greeting() + "   ❄"
        color: Util.alpha(Color.foreground, 0.85)
        font.family: root.displayFont
        font.pixelSize: 22
        font.italic: true
        font.letterSpacing: 1.5
      }

      // Clock: hours and minutes with a slowly breathing colon and a
      // hearth glow under the numerals.
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
            shadowColor: root.hearthGlow
            shadowBlur: 1.0
            shadowOpacity: 0.5 + 0.2 * Math.sin(root.t * 0.9)
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 48
          }

          Text {
            textFormat: Text.PlainText
            text: Qt.formatTime(root.now, "HH")
            color: root.clockColor
            font.family: root.displayFont
            font.pixelSize: 132
            font.weight: Font.Light
          }
          Text {
            textFormat: Text.PlainText
            text: ":"
            color: root.clockColor
            opacity: 0.3 + 0.7 * (0.5 + 0.5 * Math.cos(root.t * Math.PI))
            font.family: root.displayFont
            font.pixelSize: 132
            font.weight: Font.Light
          }
          Text {
            textFormat: Text.PlainText
            text: Qt.formatTime(root.now, "mm")
            color: root.clockColor
            font.family: root.displayFont
            font.pixelSize: 132
            font.weight: Font.Light
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatDate(root.now, "dddd  ·  d MMMM").toUpperCase()
        color: Qt.lighter(Color.accent, 1.25)
        font.family: root.displayFont
        font.pixelSize: 16
        font.letterSpacing: 6
      }

      Item { width: 1; height: 52 }

      // --- Password field --------------------------------------------------
      Item {
        id: fieldBox
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth + 60
        height: root.fieldHeight + 60

        Item {
          id: field
          width: root.fieldWidth
          height: root.fieldHeight
          x: 30 + root.shake
          y: 30
          readonly property real r: height / 2

          // A warm firelight glow behind the field that flickers softly and
          // swells a little with each keystroke.
          Rectangle {
            anchors.centerIn: parent
            width: parent.width + 110
            height: parent.height + 80
            radius: height / 2
            color: root.errorState ? Color.urgent : "#f0b35e"
            opacity: 0.2 + 0.04 * Math.sin(root.t * 2.3) + 0.02 * Math.sin(root.t * 5.7) + 0.25 * root.typingPulse
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
          }

          // Blurred copy of the ring = halo; flares on each keystroke.
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
            color: Util.alpha(Color.background, 0.72)
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
                GradientStop { position: 0.0; color: root.errorState ? Color.urgent : Color.accent }
                GradientStop { position: 0.25; color: root.errorState ? Qt.darker(Color.urgent, 1.6) : root.nebula }
                GradientStop { position: 0.5; color: root.errorState ? Color.urgent : root.hearthGlow }
                GradientStop { position: 0.75; color: root.errorState ? Qt.darker(Color.urgent, 1.6) : root.glacier }
                GradientStop { position: 1.0; color: root.errorState ? Color.urgent : Color.accent }
              }
              PathRectangle { x: 0; y: 0; width: field.width; height: field.height; radius: field.r }
              PathRectangle {
                x: root.ringThickness; y: root.ringThickness
                width: field.width - 2 * root.ringThickness; height: field.height - 2 * root.ringThickness
                radius: field.r - root.ringThickness
              }
            }
          }

          // Keystroke sparks leave from the field's top edge.
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
            anchors.leftMargin: field.r + root.fingerprintReserve
            anchors.rightMargin: field.r + root.fingerprintReserve
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            color: root.clockColor
            selectionColor: Color.lock.selection
            selectedTextColor: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
            font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
            cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
            cursorDelegate: Rectangle {
              width: 2
              color: root.hearthGlow
              visible: passwordInput.cursorVisible
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > root.lastLength) {
                sparkEmitter.burst(4)
                typingPulseAnimation.restart()
              }
              root.lastLength = text.length
              if (text.length > 0) {
                root.wakeRequested()
              }
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) {
                sparkEmitter.burst(10)
                root.submitPassword(submitted)
              }
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
            visible: passwordInput.text.length === 0
            color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
            opacity: root.authenticatingPassword ? 0.55 + 0.45 * Math.sin(root.t * 6) : 1
            font.family: Style.font.family
            font.pixelSize: root.fieldFontSize
            font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
            font.letterSpacing: 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          Text {
            id: fingerprintIcon
            objectName: "fingerprintIndicator"
            anchors.right: parent.right
            anchors.rightMargin: field.r - 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: "󰈷"
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: Math.round(root.fieldFontSize * 1.1)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "enter to unlock   ·   esc to clear"
        color: Util.alpha(Color.foreground, 0.35)
        font.family: Style.font.family
        font.pixelSize: 12
        font.letterSpacing: 2
      }
    }
  }
}
