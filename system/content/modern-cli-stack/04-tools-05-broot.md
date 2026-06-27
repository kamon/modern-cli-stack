\newpage

## 5. broot — Tree Navigator With Search

**Browse and search a directory tree from the terminal. Faster than `tree`, smarter than `find`.**

Interactive terminal file manager. Move around a project without leaving
the keyboard. Shows a tree, supports fuzzy search, lets you run commands
on the selected file or directory.

### Install

```bash
# macOS
brew install broot

# Linux / WSL
cargo install broot        # if you have cargo
# Or download from https://github.com/Canop/broot/releases
```

Run `broot --install` on first launch to set up `Ctrl+B` shell integration.

### Before / After

- **Before:** `cd ~/projects && ls && cd project-a && ls && cd .. && cd project-b`
  to find a file you forgot the path of.
- **After:** Press `Ctrl+B`, type 3 letters, Enter to jump there.

### Common operations

```bash
broot                       # launch in current directory
broot ~/Downloads           # launch with a specific path
broot --print               # print tree without interactive UI
```

Inside broot:
- Type to filter (fuzzy search across filenames)
- `Enter` on a directory: cd into it
- `?` for full help

**Try this:** `broot` in a project directory. Type partial file names.
Press `Ctrl+→` to multi-select. Run `:copy_to /tmp` on the selection.