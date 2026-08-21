import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.agata.omaleaf"

  function toggleNotes() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function")
      root.bar.shell.toggle(root.moduleName, "{}")
    else if (root.bar)
      root.bar.run("omarchy-shell shell toggle " + root.moduleName + " '{}'")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "󰎞" : "󰎞 Notes"
    tooltipText: "OmaLeaf Notes"
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.toggleNotes()
    }
  }
}
