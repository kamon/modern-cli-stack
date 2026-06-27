\newpage

# Putting It All Together

A junior dev joins a new repo. They need to find where auth is
implemented, fix a bug, run tests, commit, push, open a PR.

With default tools: 8 shell windows, lots of clicking, context lost
between steps.

With the stack:

1. `z repo` -> jump to project (zoxide)
2. `git checkout -b fix/auth-bug && lazygit` -> visual branch management
3. `rg "authenticate"` -> find the function in 0.2s (ripgrep)
4. `bat src/auth.py` -> see it highlighted (bat)
5. Edit, then `git diff` -> delta renders it beautifully
6. `lazygit` -> stage, commit, push
7. `gh pr create` -> open PR from terminal
8. Done. The whole flow stays in one terminal tab.

## Three "cheatcodes"

| Shortcut | What it does |
|---|---|
| `Ctrl+R` | Search shell history (fzf + atuin) |
| `Ctrl+T` | Find a file (fzf) |
| `Alt+C` | cd into a directory (fzf) |

Bind these once with fzf's installer (`~/.fzf/install`) and they become
muscle memory.

## One more shortcut: `Ctrl+B`

After `broot --install`, `Ctrl+B` opens a tree navigator in the current
directory. Type to filter, `Enter` to jump, `Esc` to leave.

Where the cheatcodes above handle **finding one thing**, broot handles
**exploring a project**. When you don't know what you're looking for
— "show me all the config files" or "I forgot where that lives" —
`Ctrl+B` is faster than chaining `find` and `ls`.

If you do know the term (like "authenticate"), stick with `rg`. Use `Ctrl+B`
when you're browsing without a search query — orienting yourself in an
unfamiliar codebase, comparing a few files, or picking which of several
matches to open next.
