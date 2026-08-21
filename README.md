# OmaNano Notes

OmaNano is a local-first Markdown notes library for Omarchy. Its MVP focuses on the part that simple scratchpads miss: a calm, information-rich note list that makes old notes easy to find again.

## MVP

- Three-pane categories, note list, and Markdown editor
- Preview rows grouped by recency
- Empty-list call to action for creating the first note
- Full-text, incremental search
- Pinning, folders, Trash, and restore
- Debounced atomic autosave
- Subtle Markdown highlighting for headings, lists, tasks, code, and URLs
- Keyboard and mouse navigation
- Omarchy theme-aware floating panel and optional bar widget
- Accent-aware selected categories and note rows
- Open the complete library as a normal Hyprland tiled window
- Detach the selected note into a separate Hyprland tiled window
- Plain Markdown files under `~/.local/share/omanano/notes/`

## Install from this checkout

```bash
cd omanano
omarchy plugin add "$PWD" --enable
omarchy bar put io.github.agata.omanano --section right
```

The plugin keeps notes outside its installation directory. Removing or reinstalling the plugin does not delete user notes.

## Keyboard

| Shortcut | Action |
| --- | --- |
| `Ctrl+N` | New note |
| `Ctrl+F` or `/` | Search notes |
| `Ctrl+P` | Pin/unpin selected note |
| `Ctrl+S` | Save now |
| `Ctrl+Enter` | Detach the selected note into a separate tiled window |
| `Ctrl+Shift+Enter` | Open the complete OmaNano library in a normal tiled window |
| `Ctrl+click` | Open a URL under the pointer |
| `Ctrl+Delete` | Move selected note to Trash |
| `Up` / `Down` | Select previous/next note while the list has focus |
| `Enter` | Focus the editor |
| `Escape` | Clear search, then close |

Use **Open in window** in the header when you want the complete library as a regular Hyprland tiled window. Use **Detach note** to keep that library open while moving the selected note into its own tiled editor. When detaching from the Waybar panel, the temporary panel closes after the note window appears.

## Development data directory

Set `OMANANO_DATA_DIR` when exercising the backend without touching real notes:

```bash
OMANANO_DATA_DIR=/tmp/omanano-test ./scripts/omanano-store list
```
