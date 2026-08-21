import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ShellRoot {
  id: root

  readonly property string notePath: Quickshell.env("OMANANO_NOTE_PATH")
  readonly property string noteTitle: Quickshell.env("OMANANO_NOTE_TITLE") || "Note"
  readonly property color backgroundColor: Quickshell.env("OMANANO_BACKGROUND") || "#202020"
  readonly property color foregroundColor: Quickshell.env("OMANANO_FOREGROUND") || "#f2f2f2"
  readonly property color accentColor: Quickshell.env("OMANANO_ACCENT") || "#7aa2f7"
  property bool loading: true
  property bool dirty: false

  function alpha(colorValue, opacity) {
    return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, opacity)
  }

  function save() {
    if (loading || !dirty || !notePath) return
    saveTimer.stop()
    noteFile.setText(editor.text)
    dirty = false
  }

  FileView {
    id: noteFile
    path: root.notePath
    atomicWrites: true
    printErrors: true
    onLoaded: {
      root.loading = true
      editor.text = text() || ""
      editor.cursorPosition = 0
      root.dirty = false
      root.loading = false
      Qt.callLater(function() { editor.forceActiveFocus() })
    }
  }

  Timer { id: saveTimer; interval: 420; onTriggered: root.save() }

  FloatingWindow {
    id: window
    visible: true
    title: "OmaNano — " + root.noteTitle
    color: root.backgroundColor
    implicitWidth: 760
    implicitHeight: 720
    minimumSize: Qt.size(480, 360)
    onVisibleChanged: if (!visible) root.save()

    Shortcut { sequence: "Ctrl+S"; onActivated: root.save() }

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 12

      Row {
        width: parent.width
        height: 46
        spacing: 12

        Column {
          width: parent.width - status.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Text { width: parent.width; text: root.noteTitle; color: root.foregroundColor; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
          Text { width: parent.width; text: "Markdown note · Ctrl+click links"; color: root.alpha(root.foregroundColor, 0.55); font.pixelSize: 13; elide: Text.ElideRight }
        }
        Text { id: status; anchors.verticalCenter: parent.verticalCenter; text: saveTimer.running ? "Saving…" : "Saved"; color: saveTimer.running ? root.accentColor : root.alpha(root.foregroundColor, 0.55); font.pixelSize: 13 }
      }

      Rectangle { width: parent.width; height: 1; color: root.alpha(root.foregroundColor, 0.18) }

      ScrollView {
        width: parent.width
        height: parent.height - y
        clip: true

        MarkdownEditor {
          id: editor
          width: parent.width
          selectByMouse: true
          wrapMode: TextEdit.Wrap
          foregroundColor: root.foregroundColor
          accentColor: root.accentColor
          font.family: "monospace"
          font.pixelSize: 16
          leftPadding: 10
          rightPadding: 10
          topPadding: 10
          bottomPadding: 24
          placeholderText: "Start writing Markdown…"
          placeholderTextColor: root.alpha(root.foregroundColor, 0.32)
          onTextChanged: {
            if (!root.loading) {
              root.dirty = true
              saveTimer.restart()
            }
          }
        }
      }
    }
  }
}
