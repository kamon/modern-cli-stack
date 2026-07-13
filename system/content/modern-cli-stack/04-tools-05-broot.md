\newpage

## 5. broot — Tree Navigator With Search

**Browse and search a directory tree from the terminal. Faster than `tree`, smarter than `find`.**

Interactive terminal file manager. Move around a project without leaving
the keyboard. Shows a tree, supports fuzzy search, lets you run commands
on the selected file or directory.

broot ships as one binary. The first time you run it, it will offer to
install a small shell function called `br` and patch your shell init
file. Both launch the TUI; `br` also lets broot change your shell's
working directory when you quit. If you only browse without the
cd-on-exit feature, `broot` is enough. If you want the directory-change
behavior, use `br`.

### Install

```bash
# macOS
brew install broot

# Linux / WSL
cargo install broot        # if you have cargo
# Or download from https://github.com/Canop/broot/releases
```

Run `broot --install` to set up the `br` shell function. Run it once
interactively. If broot was installed by a setup script that ran it
non-interactively, the auto-prompt may have been skipped — this
command forces the install. After it runs, `br` is available for
cd-to-exit and the rest of the TUI works the same as `broot`.

### Before / After

- **Before:** `cd ~/projects && ls && cd project-a && ls && cd .. && cd project-b`
  to find a file you forgot the path of.
- **After:** Run `br` from the prompt. Type partial file names. The
  tree filters as you type, narrow further with more characters, and
  press `Enter` to cd into a directory.

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
Press `Ctrl-G` to stage a file. Run `:copy_to /tmp` on the selection.
