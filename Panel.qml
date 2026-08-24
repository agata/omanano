import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var hostWidget: null
  property var bar: null
  property var anchorItem: null
  property var manifest: null
  property bool opened: false
  property bool appWindowOpened: false
  property var notes: []
  property var folders: []
  property string selectedId: ""
  property string category: "all"
  property string searchText: ""
  property string statusText: "Ready"
  property bool editorLoading: false
  property bool editorDirty: false
  property bool suppressFileChange: false
  property bool folderEditing: false
  property bool deleteArmed: false
  property string pendingAction: ""
  property string pendingSelectId: ""
  property string pendingReadId: ""
  property string loadedNoteId: ""
  property bool editorTooLarge: false
  property int maxNoteBytes: 1024 * 1024

  readonly property string pluginId: "io.github.agata.omanano"
  readonly property string home: Quickshell.env("HOME")
  readonly property string dataRoot: home + "/.local/share/omanano"
  readonly property string pluginDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : home + "/.config/omarchy/plugins/" + pluginId
  readonly property string storePath: pluginDir + "/scripts/omanano-store"
  readonly property var selectedNote: findNote(selectedId)
  readonly property var visibleNotes: filteredNotes()
  readonly property var folderOptions: buildFolderOptions()

  function open(_payloadJson) {
    if (appWindowOpened) {
      appWindow.minimized = false
      return
    }
    opened = true
    deleteArmed = false
    refreshNotes()
    Qt.callLater(function() { noteList.forceActiveFocus() })
  }

  function close() {
    flushSave()
    opened = false
  }

  function openLibraryInWindow() {
    flushSave()
    opened = false
    appWindowOpened = true
    deleteArmed = false
    refreshNotes()
    Qt.callLater(function() {
      noteList.forceActiveFocus()
    })
  }

  function closeLibraryWindow() {
    flushSave()
    appWindowOpened = false
  }

  function requestClose() {
    if (appWindowOpened) {
      closeLibraryWindow()
      return
    }
    if (hostWidget && typeof hostWidget.close === "function") hostWidget.close()
    else if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function handleEscape() {
    if (folderEditing) {
      folderEditing = false
      folderField.text = ""
      noteList.forceActiveFocus()
    } else if (searchText) {
      searchField.text = ""
      searchText = ""
      noteList.forceActiveFocus()
    } else {
      requestClose()
    }
  }

  function findNote(id) {
    for (var i = 0; i < notes.length; i++) {
      if (String(notes[i].id) === String(id)) return notes[i]
    }
    return null
  }

  function plainSnippet(content) {
    var lines = String(content || "").split("\n")
    var useful = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line === "---") continue
      line = line.replace(/^#{1,6}\s+/, "").replace(/^[-*+]\s+(\[[ xX]\]\s*)?/, "").replace(/[`*_~]/g, "").trim()
      if (line) useful.push(line)
      if (useful.join(" ").length > 220) break
    }
    return useful.length > 1 ? useful.slice(1).join(" ").slice(0, 180) : ""
  }

  function inferredTitle(content) {
    var lines = String(content || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim().replace(/^#{1,6}\s+/, "").replace(/^[-*+]\s+(\[[ xX]\]\s*)?/, "").replace(/[`*_~]/g, "").trim()
      if (line && line !== "---") return line.slice(0, 120)
    }
    return "Untitled"
  }

  function groupFor(note) {
    if (note.trashed) return "TRASH"
    if (note.pinned) return "PINNED"
    var now = new Date()
    var midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    var modified = Number(note.modified || 0)
    if (modified >= midnight) return "TODAY"
    if (modified >= midnight - 6 * 86400000) return "PREVIOUS 7 DAYS"
    return "OLDER"
  }

  function filteredNotes() {
    var query = String(searchText || "").trim().toLocaleLowerCase()
    var output = []
    var todayStart = new Date()
    todayStart = new Date(todayStart.getFullYear(), todayStart.getMonth(), todayStart.getDate()).getTime()
    for (var i = 0; i < notes.length; i++) {
      var note = notes[i]
      var include = false
      if (category === "trash") include = !!note.trashed
      else if (note.trashed) include = false
      else if (category === "all") include = true
      else if (category === "pinned") include = !!note.pinned
      else if (category === "today") include = Number(note.modified || 0) >= todayStart
      else if (category.indexOf("folder:") === 0) include = String(note.folder || "") === category.slice(7)
      if (!include) continue
      if (query) {
        var haystack = (String(note.title || "") + "\n" + String(note.snippet || "") + "\n" + String(note.folder || "")).toLocaleLowerCase()
        if (haystack.indexOf(query) < 0) continue
      }
      var copy = {}
      for (var key in note) copy[key] = note[key]
      copy.group = groupFor(note)
      output.push(copy)
    }
    return output
  }

  function buildFolderOptions() {
    var result = [{ label: "Inbox", value: "" }]
    for (var i = 0; i < folders.length; i++) result.push({ label: String(folders[i]), value: String(folders[i]) })
    return result
  }

  function categoryLabel() {
    if (category === "all") return "All Notes"
    if (category === "pinned") return "Pinned"
    if (category === "today") return "Today"
    if (category === "trash") return "Trash"
    if (category.indexOf("folder:") === 0) return category.slice(7)
    return "Notes"
  }

  function relativeTime(milliseconds) {
    var value = Number(milliseconds || 0)
    var date = new Date(value)
    var now = new Date()
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    if (value >= today) return Qt.formatTime(date, "HH:mm")
    var yesterday = today - 86400000
    if (value >= yesterday) return "Yesterday"
    if (date.getFullYear() === now.getFullYear()) return Qt.formatDate(date, "MMM d")
    return Qt.formatDate(date, "yyyy-MM-dd")
  }

  function selectCategory(nextCategory) {
    category = String(nextCategory)
    deleteArmed = false
    Qt.callLater(function() {
      if (visibleNotes.length > 0) selectNote(String(visibleNotes[0].id))
      else selectNote("")
      noteList.forceActiveFocus()
    })
  }

  function selectNote(id) {
    if (String(id) === selectedId) return
    flushSave()
    selectedId = String(id || "")
    deleteArmed = false
    loadEditor()
  }

  function loadEditor() {
    editorLoading = true
    editor.text = ""
    editor.cursorPosition = 0
    editorDirty = false
    loadedNoteId = ""
    editorTooLarge = false
    editorLoading = false
    if (!selectedNote) return
    if (selectedNote.tooLarge) {
      editorTooLarge = true
      statusText = "This note is too large to open safely"
      return
    }
    pendingReadId = selectedId
    startPendingRead()
  }

  function startPendingRead() {
    if (readProcess.running || !pendingReadId) return
    var note = findNote(pendingReadId)
    if (!note) {
      pendingReadId = ""
      return
    }
    readProcess.requestedId = pendingReadId
    readProcess.requestedTrashed = !!note.trashed
    pendingReadId = ""
    readProcess.outputText = ""
    var command = [storePath, "read", readProcess.requestedId]
    if (readProcess.requestedTrashed) command.push("--trashed")
    readProcess.command = command
    readProcess.running = true
  }

  function ensureVisibleSelection() {
    if (selectedVisibleIndex() >= 0) return
    if (visibleNotes.length > 0) selectNote(String(visibleNotes[0].id))
    else selectNote("")
  }

  function selectedVisibleIndex() {
    for (var i = 0; i < visibleNotes.length; i++) {
      if (String(visibleNotes[i].id) === selectedId) return i
    }
    return -1
  }

  function moveSelection(delta) {
    if (visibleNotes.length === 0) return
    var index = selectedVisibleIndex()
    if (index < 0) index = delta < 0 ? 0 : -1
    index = Math.max(0, Math.min(visibleNotes.length - 1, index + delta))
    selectNote(String(visibleNotes[index].id))
    noteList.positionViewAtIndex(index, ListView.Contain)
  }

  function updateNoteInMemory(id, content) {
    if (!findNote(id)) return
    var next = []
    for (var i = 0; i < notes.length; i++) {
      var item = notes[i]
      if (String(item.id) === String(id)) {
        var copy = {}
        for (var key in item) copy[key] = item[key]
        copy.title = inferredTitle(content)
        copy.snippet = plainSnippet(content)
        copy.modified = Date.now()
        copy.openTasks = (String(content).match(/^\s*[-*+]\s+\[ \]/gm) || []).length
        next.push(copy)
      } else next.push(item)
    }
    notes = next
  }

  function flushSave() {
    if (editorLoading || editorTooLarge || loadedNoteId !== selectedId || !editorDirty || !selectedNote || selectedNote.trashed) return
    saveTimer.stop()
    suppressFileChange = true
    noteFile.setText(editor.text)
    updateNoteInMemory(selectedId, editor.text)
    editorDirty = false
    statusText = "Saved"
    suppressTimer.restart()
  }

  function detachSelectedNote() {
    if (!selectedNote || selectedNote.trashed) return
    if (selectedNote.tooLarge) {
      statusText = "This note is too large to detach safely"
      return
    }
    flushSave()
    detachedLaunchProcess.command = [
      pluginDir + "/scripts/omanano-window",
      dataRoot + "/notes/" + String(selectedNote.id),
      String(selectedNote.id),
      String(selectedNote.title),
      String(Color.popups.background),
      String(Color.foreground),
      String(Color.accent)
    ]
    detachedLaunchProcess.running = true
    if (opened) detachOverlayCloseTimer.restart()
  }

  function refreshNotes() {
    if (listProcess.running) return
    listProcess.outputText = ""
    listProcess.command = [storePath, "list"]
    listProcess.running = true
    statusText = notes.length ? statusText : "Loading notes…"
  }

  function runAction(name, args, selectResult) {
    if (actionProcess.running) return
    flushSave()
    pendingAction = name
    pendingSelectId = selectResult ? "@result" : ""
    actionProcess.outputText = ""
    actionProcess.command = [storePath].concat(args)
    actionProcess.running = true
  }

  function createNote() {
    var folder = category.indexOf("folder:") === 0 ? category.slice(7) : ""
    runAction("create", ["create", "--folder", folder], true)
  }

  function togglePin() {
    if (!selectedNote || selectedNote.trashed) return
    runAction("pin", ["pin", selectedId], false)
  }

  function requestTrash() {
    if (!selectedNote || selectedNote.trashed) return
    if (!deleteArmed) {
      deleteArmed = true
      deleteTimer.restart()
      statusText = "Press Trash again to move “" + selectedNote.title + "” to Trash"
      return
    }
    runAction("trash", ["trash", selectedId], false)
    selectedId = ""
    deleteArmed = false
  }

  function restoreSelected() {
    if (!selectedNote || !selectedNote.trashed) return
    runAction("restore", ["restore", selectedId], true)
  }

  function requestPermanentDelete() {
    if (!selectedNote || !selectedNote.trashed) return
    if (!deleteArmed) {
      deleteArmed = true
      deleteTimer.restart()
      statusText = "Press Delete forever again; this cannot be undone"
      return
    }
    runAction("delete", ["delete", selectedId], false)
    selectedId = ""
    deleteArmed = false
  }

  function createFolder() {
    var name = String(folderField.text || "").trim()
    if (!name) return
    runAction("create-folder", ["create-folder", name], false)
    folderEditing = false
    folderField.text = ""
  }

  function moveSelectedTo(folder) {
    if (!selectedNote || selectedNote.trashed || String(selectedNote.folder || "") === String(folder || "")) return
    runAction("move", ["move", selectedId, "--folder", String(folder || "")], true)
  }

  Timer { id: saveTimer; interval: 420; onTriggered: root.flushSave() }
  Timer { id: suppressTimer; interval: 800; onTriggered: root.suppressFileChange = false }
  Timer { id: deleteTimer; interval: 3200; onTriggered: root.deleteArmed = false }
  Timer { id: detachOverlayCloseTimer; interval: 180; onTriggered: root.requestClose() }
  Timer { id: pollTimer; interval: 4000; repeat: true; running: root.opened || root.appWindowOpened; onTriggered: if (!editor.activeFocus && !saveTimer.running) root.refreshNotes() }

  FileView {
    id: noteFile
    path: root.selectedNote
      ? root.dataRoot + (root.selectedNote.trashed ? "/trash/" : "/notes/") + String(root.selectedNote.id)
      : ""
    watchChanges: true
    atomicWrites: true
    preload: false
    blockAllReads: true
    printErrors: false
    onFileChanged: {
      if (root.suppressFileChange) root.suppressFileChange = false
      else if (!editor.activeFocus && !saveTimer.running) root.refreshNotes()
    }
  }

  Process {
    id: listProcess
    property string outputText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: listProcess.outputText = String(text || "").trim() }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message) root.statusText = message
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.statusText = root.statusText || "Could not load notes"
        return
      }
      try {
        var result = JSON.parse(listProcess.outputText || "{}")
        var previousId = root.selectedId
        root.notes = Array.isArray(result.notes) ? result.notes : []
        root.folders = Array.isArray(result.folders) ? result.folders : []
        root.maxNoteBytes = Math.max(1, Number(result.maxNoteBytes || root.maxNoteBytes))
        var wanted = root.pendingSelectId
        root.pendingSelectId = ""
        if (wanted && wanted !== "@result") root.selectedId = wanted
        if (!root.findNote(root.selectedId)) {
          var entries = root.filteredNotes()
          root.selectedId = entries.length ? String(entries[0].id) : ""
        }
        if (root.selectedId !== previousId || !editor.activeFocus || !root.selectedNote) root.loadEditor()
        var visibleCount = root.notes.filter(function(note) { return !note.trashed }).length
        root.statusText = visibleCount + " notes" + (result.notesTruncated || result.foldersTruncated ? " · Library limit reached" : "")
      } catch (error) {
        root.statusText = "Could not read the notes index"
      }
    }
  }

  Process {
    id: readProcess
    property string requestedId: ""
    property bool requestedTrashed: false
    property string outputText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: readProcess.outputText = String(text || "").trim() }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message && readProcess.requestedId === root.selectedId) root.statusText = message
      }
    }
    onExited: function(exitCode) {
      var requestedId = readProcess.requestedId
      if (exitCode === 0) {
        try {
          var result = JSON.parse(readProcess.outputText || "{}")
          if (requestedId === root.selectedId) {
            root.editorLoading = true
            root.editorTooLarge = !!result.tooLarge
            root.loadedNoteId = result.tooLarge ? "" : requestedId
            editor.text = result.tooLarge ? "" : String(result.content || "")
            editor.cursorPosition = 0
            root.editorDirty = false
            root.editorLoading = false
            root.statusText = result.tooLarge
              ? "This note is larger than " + Math.ceil(Number(result.maxBytes || root.maxNoteBytes) / 1048576) + " MiB"
              : "Loaded"
          }
        } catch (_error) {
          if (requestedId === root.selectedId) root.statusText = "Could not read this note"
        }
      } else if (requestedId === root.selectedId) {
        root.statusText = "Could not load this note"
      }
      root.startPendingRead()
    }
  }

  Process { id: detachedLaunchProcess }

  Process {
    id: actionProcess
    property string outputText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: actionProcess.outputText = String(text || "").trim() }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message) root.statusText = message
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.statusText = "Action failed" + (root.statusText ? " · " + root.statusText : "")
        root.pendingSelectId = ""
        return
      }
      try {
        var result = JSON.parse(actionProcess.outputText || "{}")
        if (root.pendingSelectId === "@result" && result.id) root.pendingSelectId = String(result.id)
        else root.pendingSelectId = root.selectedId
        if (root.pendingAction === "create-folder" && result.folder) root.category = "folder:" + String(result.folder)
      } catch (_error) {
        root.pendingSelectId = root.selectedId
      }
      root.statusText = "Updated"
      root.refreshNotes()
    }
  }

  KeyboardPanel {
    id: window
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget
    open: root.opened
    centerOnBar: true
    focusTarget: noteList
    padding: Style.space(16)
    contentWidth: window.fittedContentWidth(Style.space(1240))
    contentHeight: window.cappedContentHeight(Style.space(780))

    Item { id: panelHost; anchors.fill: parent }
  }

  FloatingWindow {
    id: appWindow
    visible: root.appWindowOpened
    title: "OmaNano Notes"
    color: Color.popups.background
    implicitWidth: Style.space(1240)
    implicitHeight: Style.space(780)
    minimumSize: Qt.size(Style.space(760), Style.space(520))
    onVisibleChanged: if (!visible && root.appWindowOpened) root.closeLibraryWindow()

    Item {
      id: appWindowHost
      anchors.fill: parent
      anchors.margins: Style.space(16)
    }
  }

  Item {
    id: libraryView
    parent: root.appWindowOpened ? appWindowHost : panelHost
    anchors.fill: parent

    Shortcut { sequence: "Escape"; onActivated: root.handleEscape() }
    Shortcut { sequence: "Ctrl+N"; onActivated: root.createNote() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { searchField.forceActiveFocus(); searchField.selectAll() } }
    Shortcut { sequence: "Ctrl+P"; onActivated: root.togglePin() }
    Shortcut { sequence: "Ctrl+S"; onActivated: { saveTimer.restart(); root.flushSave() } }
    Shortcut { sequence: "Ctrl+Shift+Return"; onActivated: root.openLibraryInWindow() }
    Shortcut { sequence: "Ctrl+Return"; onActivated: root.detachSelectedNote() }
    Shortcut { sequence: "Ctrl+Delete"; onActivated: root.requestTrash() }

    Column {
      anchors.fill: parent
      spacing: Style.space(10)

        Row {
          width: parent.width
          height: Style.space(48)
          spacing: Style.space(12)

          Column {
            width: parent.width - headerActions.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: "OMANANO  /  " + root.categoryLabel().toUpperCase()
              textFormat: Text.PlainText
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: "Find the note first. Writing stays simple."
              color: Util.alpha(Color.foreground, 0.56)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
          Row {
            id: headerActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(7)
            Button {
              visible: !root.appWindowOpened
              text: "Open in window"
              tooltipText: "Open the complete OmaNano library as a normal tiled window"
              onClicked: root.openLibraryInWindow()
            }
            Button { id: newButton; text: "New note"; iconText: "+"; active: true; onClicked: root.createNote() }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(Color.foreground, 0.18) }

        Row {
          width: parent.width
          height: parent.height - y - statusBar.height - parent.spacing
          spacing: Style.space(10)

          BorderSurface {
            id: sidebar
            width: Math.max(Style.space(170), Math.min(Style.space(210), parent.width * 0.17))
            height: parent.height
            color: Util.alpha(Color.foreground, 0.024)
            borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(4)

              Text { text: "LIBRARY"; color: Util.alpha(Color.foreground, 0.52); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              CategoryButton { label: "All Notes"; count: root.notes.filter(function(n) { return !n.trashed }).length; selected: root.category === "all"; onActivated: root.selectCategory("all") }
              CategoryButton { label: "Pinned"; count: root.notes.filter(function(n) { return !n.trashed && n.pinned }).length; selected: root.category === "pinned"; onActivated: root.selectCategory("pinned") }
              CategoryButton { label: "Today"; count: -1; selected: root.category === "today"; onActivated: root.selectCategory("today") }

              Item { width: 1; height: Style.space(7) }
              Row {
                width: parent.width
                height: Style.space(24)
                Text { width: parent.width - addFolderButton.width; anchors.verticalCenter: parent.verticalCenter; text: "FOLDERS"; color: Util.alpha(Color.foreground, 0.52); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Button { id: addFolderButton; text: "+"; tooltipText: "New folder"; onClicked: { root.folderEditing = true; Qt.callLater(function() { folderField.forceActiveFocus() }) } }
              }

              CategoryButton { label: "Inbox"; count: root.notes.filter(function(n) { return !n.trashed && !n.folder }).length; selected: root.category === "folder:"; onActivated: root.selectCategory("folder:") }
              Repeater {
                model: root.folders
                delegate: CategoryButton {
                  required property var modelData
                  label: String(modelData)
                  count: root.notes.filter(function(n) { return !n.trashed && String(n.folder || "") === String(modelData) }).length
                  selected: root.category === "folder:" + String(modelData)
                  onActivated: root.selectCategory("folder:" + String(modelData))
                }
              }

              TextField {
                id: folderField
                visible: root.folderEditing
                width: parent.width
                placeholderText: "Folder name"
                placeholderTextColor: Util.alpha(Color.foreground, 0.32)
                onAccepted: root.createFolder()
                Keys.onEscapePressed: function(event) { root.handleEscape(); event.accepted = true }
              }

              Item { width: 1; height: Math.max(0, parent.height - y - trashButton.height) }
              CategoryButton { id: trashButton; label: "Trash"; count: root.notes.filter(function(n) { return n.trashed }).length; selected: root.category === "trash"; onActivated: root.selectCategory("trash") }
            }
          }

          BorderSurface {
            id: listPane
            width: Math.max(Style.space(300), Math.min(Style.space(360), parent.width * 0.30))
            height: parent.height
            color: Util.alpha(Color.foreground, 0.018)
            borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(7)

              TextField {
                id: searchField
                width: parent.width
                placeholderText: "Search title or content"
                placeholderTextColor: Util.alpha(Color.foreground, 0.32)
                onTextChanged: {
                  root.searchText = text
                  Qt.callLater(function() { root.ensureVisibleSelection() })
                }
                Keys.onEscapePressed: function(event) { root.handleEscape(); event.accepted = true }
              }

              ListView {
                id: noteList
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: Style.space(3)
                model: root.visibleNotes
                section.property: "group"
                section.criteria: ViewSection.FullString
                section.delegate: Text {
                  required property string section
                  width: noteList.width
                  height: Style.space(28)
                  verticalAlignment: Text.AlignVCenter
                  text: section
                  textFormat: Text.PlainText
                  color: Util.alpha(Color.foreground, 0.48)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { root.moveSelection(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { root.moveSelection(1); event.accepted = true }
                  else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { editor.forceActiveFocus(); event.accepted = true }
                  else if (event.text === "/") { searchField.forceActiveFocus(); event.accepted = true }
                }

                delegate: BorderSurface {
                  id: noteRow
                  required property var modelData
                  required property int index
                  readonly property bool rowSelected: String(modelData.id) === root.selectedId
                  width: noteList.width
                  height: Style.space(76)
                  color: rowSelected
                    ? Style.selectedAccentFill
                    : rowMouse.containsMouse
                      ? Style.hoverFillFor(Color.foreground, Color.accent)
                      : "transparent"
                  borderSpec: rowSelected
                    ? Border.controlSpec("selected", Color.accent, Color.accent)
                    : rowMouse.containsMouse
                      ? Border.controlSpec("hover-cursor", Color.foreground, Color.accent)
                      : Border.none
                  radius: Style.cornerRadius

                  Rectangle {
                    visible: noteRow.rowSelected
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Style.space(3)
                    color: Color.accent
                  }

                  Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(3)
                    Row {
                      width: parent.width
                      spacing: Style.space(6)
                      Text { visible: !!noteRow.modelData.pinned; text: "◆"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                      Text { width: parent.width - x - rowDate.width; text: String(noteRow.modelData.title || "Untitled"); textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: noteRow.rowSelected; elide: Text.ElideRight }
                      Text { id: rowDate; text: root.relativeTime(noteRow.modelData.modified); color: Util.alpha(Color.foreground, 0.48); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                    }
                    Text { width: parent.width; text: String(noteRow.modelData.snippet || "No additional text"); textFormat: Text.PlainText; color: Util.alpha(Color.foreground, 0.58); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                    Row {
                      spacing: Style.space(9)
                      Text { visible: String(noteRow.modelData.folder || "") !== ""; text: String(noteRow.modelData.folder); textFormat: Text.PlainText; color: Util.alpha(Color.foreground, 0.46); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                      Text { visible: Number(noteRow.modelData.openTasks || 0) > 0; text: "☐ " + Number(noteRow.modelData.openTasks); color: Util.alpha(Color.foreground, 0.54); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                    }
                  }
                  MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.selectNote(String(noteRow.modelData.id)); noteList.forceActiveFocus() }
                    onDoubleClicked: { root.selectNote(String(noteRow.modelData.id)); editor.forceActiveFocus() }
                  }
                }

                Column {
                  visible: root.visibleNotes.length === 0 && !root.searchText && root.category !== "trash"
                  anchors.centerIn: parent
                  width: parent.width - Style.space(28)
                  spacing: Style.space(10)
                  Text {
                    width: parent.width
                    text: "No notes here yet"
                    horizontalAlignment: Text.AlignHCenter
                    color: Util.alpha(Color.foreground, 0.5)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Button { anchors.horizontalCenter: parent.horizontalCenter; text: "Create a note"; iconText: "+"; active: true; onClicked: root.createNote() }
                }

                Text {
                  visible: root.visibleNotes.length === 0 && (root.searchText || root.category === "trash")
                  anchors.centerIn: parent
                  width: parent.width - Style.space(28)
                  text: root.searchText ? "No notes match this search" : "Trash is empty"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                  color: Util.alpha(Color.foreground, 0.46)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          BorderSurface {
            id: editorPane
            width: parent.width - x
            height: parent.height
            color: Util.alpha(Color.foreground, 0.024)
            borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Row {
                width: parent.width
                height: Style.space(38)
                spacing: Style.space(7)
                Column {
                  width: parent.width - editorActions.width - parent.spacing
                  anchors.verticalCenter: parent.verticalCenter
                  Text { width: parent.width; text: root.selectedNote ? String(root.selectedNote.title) : "No note selected"; textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; elide: Text.ElideRight }
                  Text { width: parent.width; text: root.selectedNote ? (root.selectedNote.folder ? String(root.selectedNote.folder) : "Inbox") + " · " + root.relativeTime(root.selectedNote.modified) : "Choose a note from the list"; textFormat: Text.PlainText; color: Util.alpha(Color.foreground, 0.5); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                }
                Row {
                  id: editorActions
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(5)
                  Button { visible: root.selectedNote && !root.selectedNote.trashed; text: "Detach note"; foreground: Util.alpha(Color.foreground, 0.62); horizontalPadding: Style.space(8); verticalPadding: Style.space(5); tooltipText: "Detach this note into a separate tiled window"; onClicked: root.detachSelectedNote() }
                  Button { visible: root.selectedNote && !root.selectedNote.trashed; text: root.selectedNote && root.selectedNote.pinned ? "Unpin" : "Pin"; foreground: Util.alpha(Color.foreground, 0.58); horizontalPadding: Style.space(8); verticalPadding: Style.space(5); onClicked: root.togglePin() }
                  Button { visible: root.selectedNote && !root.selectedNote.trashed; text: root.deleteArmed ? "Confirm Trash" : "Trash"; foreground: root.deleteArmed ? Color.urgent : Util.alpha(Color.foreground, 0.52); horizontalPadding: Style.space(8); verticalPadding: Style.space(5); onClicked: root.requestTrash() }
                  Button { visible: root.selectedNote && root.selectedNote.trashed; text: "Restore"; foreground: Util.alpha(Color.foreground, 0.62); horizontalPadding: Style.space(8); verticalPadding: Style.space(5); onClicked: root.restoreSelected() }
                  Button { visible: root.selectedNote && root.selectedNote.trashed; text: root.deleteArmed ? "Confirm delete" : "Delete forever"; foreground: root.deleteArmed ? Color.urgent : Util.alpha(Color.foreground, 0.52); horizontalPadding: Style.space(8); verticalPadding: Style.space(5); onClicked: root.requestPermanentDelete() }
                }
              }

              Row {
                visible: root.selectedNote && !root.selectedNote.trashed
                width: parent.width
                height: Style.space(28)
                spacing: Style.space(7)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Folder"; color: Util.alpha(Color.foreground, 0.4); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                PlainTextDropdown {
                  property bool pointerInside: false
                  width: Style.space(150)
                  rowHeight: Style.space(28)
                  showLabel: false
                  foreground: Util.alpha(Color.foreground, 0.62)
                  background: "transparent"
                  opacity: popupOpen || pointerInside ? 1 : 0.62
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                  onHovered: function(hovered) { pointerInside = hovered }
                  options: root.folderOptions
                  value: root.selectedNote ? String(root.selectedNote.folder || "") : ""
                  onChanged: function(value) { root.moveSelectedTo(value) }
                }
                Item { width: Math.max(0, parent.width - x); height: 1 }
              }

              Rectangle { width: parent.width; height: 1; color: Util.alpha(Color.foreground, 0.13) }

              ScrollView {
                width: parent.width
                height: parent.height - y
                clip: true

                MarkdownEditor {
                  id: editor
                  width: parent.width
                  enabled: root.selectedNote !== null && !root.selectedNote.trashed && !root.editorTooLarge && root.loadedNoteId === root.selectedId
                  readOnly: root.selectedNote ? !!root.selectedNote.trashed : true
                  selectByMouse: true
                  wrapMode: TextEdit.Wrap
                  foregroundColor: enabled || readOnly ? Color.foreground : Util.alpha(Color.foreground, 0.38)
                  accentColor: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  leftPadding: Style.space(10)
                  rightPadding: Style.space(10)
                  topPadding: Style.space(10)
                  bottomPadding: Style.space(20)
                  placeholderText: root.editorTooLarge
                    ? "This note is too large to edit safely in OmaNano."
                    : root.selectedNote
                      ? (root.loadedNoteId === root.selectedId ? "Start writing Markdown…" : "Loading note…")
                      : "Select or create a note"
                  placeholderTextColor: Util.alpha(Color.foreground, 0.3)
                  onTextChanged: {
                    if (!root.editorLoading && !root.editorTooLarge && root.loadedNoteId === root.selectedId && root.selectedNote && !root.selectedNote.trashed) {
                      root.editorDirty = true
                      root.statusText = "Saving…"
                      saveTimer.restart()
                    }
                  }
                }
              }
            }
          }
        }

        Row {
          id: statusBar
          width: parent.width
          height: Style.space(22)
          spacing: Style.space(8)
          Rectangle { width: Style.space(7); height: width; radius: width / 2; anchors.verticalCenter: parent.verticalCenter; color: saveTimer.running ? Color.accent : Color.foreground; opacity: saveTimer.running ? 1 : 0.32 }
          Text { width: parent.width - Style.space(18); anchors.verticalCenter: parent.verticalCenter; text: root.statusText + "  ·  Ctrl+N New  ·  Ctrl+F Search  ·  Ctrl+Enter Detach  ·  Ctrl+Shift+Enter App  ·  Ctrl+click links"; textFormat: Text.PlainText; color: Util.alpha(Color.foreground, 0.56); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        }
    }
  }

  component CategoryButton: BorderSurface {
    id: categoryButton
    property string label: ""
    property int count: -1
    property bool selected: false
    signal activated()
    width: parent ? parent.width : Style.space(160)
    height: Style.space(34)
    color: selected
      ? Style.selectedAccentFill
      : categoryMouse.containsMouse
        ? Style.hoverFillFor(Color.foreground, Color.accent)
        : "transparent"
    borderSpec: selected ? Border.controlSpec("selected", Color.accent, Color.accent) : Border.none
    radius: Style.cornerRadius
    Rectangle {
      visible: categoryButton.selected
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Style.space(3)
      color: Color.accent
    }
    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(9)
      anchors.rightMargin: Style.space(9)
      spacing: Style.space(6)
      Text { width: parent.width - (categoryCount.visible ? categoryCount.width : 0); anchors.verticalCenter: parent.verticalCenter; text: categoryButton.label; textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: categoryButton.selected; elide: Text.ElideRight }
      Text { id: categoryCount; visible: categoryButton.count >= 0; anchors.verticalCenter: parent.verticalCenter; text: String(categoryButton.count); color: Util.alpha(Color.foreground, 0.48); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
    }
    MouseArea { id: categoryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: categoryButton.activated() }
  }
}
