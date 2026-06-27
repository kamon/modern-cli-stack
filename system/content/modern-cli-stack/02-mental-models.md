\newpage

# Mental Models (Read This First)

Before installing anything, understand these four concepts. Every tool in this
PDF depends on them.

## What "the terminal" actually is

- **The shell** (Bash) is a program that interprets text commands.
- **Your terminal app** (Terminal.app, iTerm2, Windows Terminal, GNOME
  Terminal) is the *window* that runs the shell.
- **Prompt:** `$` means the shell is ready for input.

## Pipes: the most important idea in Unix

The `|` character takes the **output** of one command and feeds it as
**input** to the next.

```bash
cat file.txt | grep "error" | wc -l
```

Read it left to right: *take the file -> keep only lines with "error" ->
count them.* Assembly line. Each station does one thing.

## Exit codes: silent signals

Every command returns a number when it finishes.

- `0` = success
- anything else = something went wrong

```bash
command1 && command2   # run command2 only if command1 succeeded
command1 || command2   # run command2 only if command1 failed
```

## Streams: stdin, stdout, stderr

- **stdin** — input (keyboard, or previous command's pipe)
- **stdout** — normal output (screen, or next command's pipe)
- **stderr** — errors (also screen, but a separate stream)

```bash
ls > files.txt          # redirect stdout to a file
ls /nonexistent 2> errors.txt   # redirect stderr to a file
```

**For definitions of these terms and more, see Appendix B: Glossary.**
