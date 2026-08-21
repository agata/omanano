import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.agata.omanano"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("shell" in target) target.shell = root.bar ? root.bar.shell : null
    if ("hostWidget" in target) target.hostWidget = root
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open("")
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggleNotes() {
    if (!panelLoader.item) return
    if (opened) close()
    else open()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰎞"
    tooltipText: "OmaNano Notes"
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.toggleNotes()
    }
  }
}
