# OmaLeaf Notes

OmaLeaf is a local-first Markdown notes library for Omarchy. Its MVP focuses on the part that simple scratchpads miss: a calm, information-rich note list that makes old notes easy to find again.

## MVP

- Three-pane categories, note list, and Markdown editor
- Preview rows grouped by recency
- Full-text, incremental search
- Pinning, folders, Trash, and restore
- Debounced atomic autosave
- Keyboard and mouse navigation
- Omarchy theme-aware floating panel and optional bar widget
- Plain Markdown files under `~/.local/share/omaleaf/notes/`

## Install from this checkout

```bash
cd omaleaf
omarchy plugin add "$PWD" --enable
omarchy bar put io.github.agata.omaleaf --section right
```

The plugin keeps notes outside its installation directory. Removing or reinstalling the plugin does not delete user notes.

## Keyboard

| Shortcut | Action |
| --- | --- |
| `Ctrl+N` | New note |
| `Ctrl+F` or `/` | Search notes |
| `Ctrl+P` | Pin/unpin selected note |
| `Ctrl+S` | Save now |
| `Ctrl+Delete` | Move selected note to Trash |
| `Up` / `Down` | Select previous/next note while the list has focus |
| `Enter` | Focus the editor |
| `Escape` | Clear search, then close |

## Development data directory

Set `OMALEAF_DATA_DIR` when exercising the backend without touching real notes:

```bash
OMALEAF_DATA_DIR=/tmp/omaleaf-test ./scripts/omaleaf-store list
```
