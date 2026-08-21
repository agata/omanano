import QtQuick
import QtQuick.Controls

TextArea {
  id: root

  property color foregroundColor: "#f2f2f2"
  property color accentColor: "#7aa2f7"
  property color mutedColor: root.alpha(foregroundColor, 0.52)

  function alpha(colorValue, opacity) {
    return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, opacity)
  }

  function hexColor(colorValue) {
    function channel(value) {
      var output = Math.round(value * 255).toString(16)
      return output.length < 2 ? "0" + output : output
    }
    return "#" + channel(colorValue.r) + channel(colorValue.g) + channel(colorValue.b)
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
  }

  function preserveIndent(value) {
    var match = String(value || "").match(/^[\t ]+/)
    if (!match) return value
    var indent = match[0].replace(/\t/g, "    ").replace(/ /g, "&nbsp;")
    return indent + value.slice(match[0].length)
  }

  function inlineHighlight(value) {
    var source = String(value || "")
    var output = ""
    var cursor = 0
    var tokenPattern = /`[^`\n]+`|https?:\/\/[^\s<>()]+/g
    var match
    while ((match = tokenPattern.exec(source)) !== null) {
      output += escapeHtml(source.slice(cursor, match.index))
      var token = match[0]
      if (token.charAt(0) === "`") {
        output += "<span style=\"color:" + hexColor(accentColor) + ";\">" + escapeHtml(token) + "</span>"
      } else {
        var trailing = token.match(/[.,;:!?\]\}]+$/)
        var suffix = trailing ? trailing[0] : ""
        var url = suffix ? token.slice(0, -suffix.length) : token
        output += "<span style=\"color:" + hexColor(accentColor) + "; text-decoration:underline;\">" + escapeHtml(url) + "</span>" + escapeHtml(suffix)
      }
      cursor = match.index + token.length
    }
    output += escapeHtml(source.slice(cursor))
    return preserveIndent(output)
  }

  function highlightedMarkdown(value) {
    var lines = String(value || "").split("\n")
    var output = []
    var inCodeBlock = false
    var accent = hexColor(accentColor)
    var muted = hexColor(mutedColor)
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var fence = line.match(/^(\s*)(```|~~~)/)
      if (fence) {
        output.push(preserveIndent(escapeHtml(line.slice(0, fence[1].length)))
          + "<span style=\"color:" + accent + ";\">" + escapeHtml(line.slice(fence[1].length)) + "</span>")
        inCodeBlock = !inCodeBlock
        continue
      }
      if (inCodeBlock) {
        output.push("<span style=\"color:" + muted + ";\">" + preserveIndent(escapeHtml(line)) + "</span>")
        continue
      }

      var heading = line.match(/^(\s{0,3})(#{1,6})(\s+)(.*)$/)
      if (heading) {
        output.push(preserveIndent(escapeHtml(heading[1]))
          + "<span style=\"color:" + accent + ";\">" + escapeHtml(heading[2]) + "</span>"
          + escapeHtml(heading[3])
          + "<span style=\"color:" + hexColor(foregroundColor) + "; font-weight:600;\">" + inlineHighlight(heading[4]) + "</span>")
        continue
      }

      var task = line.match(/^(\s*[-*+]\s+)(\[[ xX]\])(\s*)/)
      if (task) {
        var taskLength = task[1].length + task[2].length + task[3].length
        output.push(preserveIndent(escapeHtml(task[1]))
          + "<span style=\"color:" + accent + "; font-weight:600;\">" + escapeHtml(task[2]) + "</span>"
          + escapeHtml(task[3]) + inlineHighlight(line.slice(taskLength)))
        continue
      }

      var marker = line.match(/^(\s*)([-*+]|\d+\.|>)(\s+)/)
      if (marker) {
        var markerLength = marker[1].length + marker[2].length + marker[3].length
        output.push(preserveIndent(escapeHtml(marker[1]))
          + "<span style=\"color:" + accent + ";\">" + escapeHtml(marker[2]) + "</span>"
          + escapeHtml(marker[3]) + inlineHighlight(line.slice(markerLength)))
        continue
      }

      output.push(inlineHighlight(line))
    }
    return output.join("<br/>")
  }

  function urlAtPosition(position) {
    var source = String(text || "")
    var pattern = /https?:\/\/[^\s<>()]+/g
    var match
    while ((match = pattern.exec(source)) !== null) {
      var url = match[0].replace(/[.,;:!?\]\}]+$/, "")
      if (position >= match.index && position <= match.index + url.length) return url
    }
    return ""
  }

  // IME preedit text is not part of `text` until conversion is committed, so
  // the syntax layer cannot render it. Temporarily reveal the native editor
  // while composing; the highlighted layer returns immediately on commit.
  color: inputMethodComposing ? foregroundColor : "transparent"
  selectedTextColor: foregroundColor
  selectionColor: alpha(accentColor, 0.5)

  cursorDelegate: Rectangle {
    width: 1
    color: root.accentColor
  }

  background: Item {
    opacity: root.inputMethodComposing ? 0 : 1

    Text {
      x: root.leftPadding
      y: root.topPadding
      width: Math.max(0, root.width - root.leftPadding - root.rightPadding)
      text: root.highlightedMarkdown(root.text)
      textFormat: Text.RichText
      wrapMode: Text.Wrap
      color: root.foregroundColor
      font.family: root.font.family
      font.pixelSize: root.font.pixelSize
      lineHeight: 1
      lineHeightMode: Text.ProportionalHeight
    }
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    acceptedModifiers: Qt.ControlModifier
    onTapped: function(eventPoint) {
      var position = root.positionAt(eventPoint.position.x, eventPoint.position.y)
      var url = root.urlAtPosition(position)
      if (url) Qt.openUrlExternally(url)
    }
  }
}
