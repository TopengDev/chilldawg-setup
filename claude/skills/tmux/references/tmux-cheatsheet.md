# tmux 3.6b, verified subcommand cheatsheet

Every synopsis below is copied from `man tmux` on the installed `tmux 3.6b` (`/usr/bin/tmux`), then
annotated with the flags this skill actually uses and one house example. If you need a flag not
listed here, re-verify it against `man tmux` before using it, never guess (CLAUDE.md: don't
hallucinate APIs). Regenerate any synopsis with, e.g., `MANWIDTH=200 man tmux | grep -A3 'capture-pane \['`.

Target syntax recap (what follows `-t`): `:N` = window N in current session · `sess:win.pane` (e.g.
`main:4.2`) · `0:worker-name` = session 0, window named `worker-name` (house worker form) · `%N` =
unique pane id (`#{pane_id}`) · `@N` = unique window id (`#{window_id}`). Stable ids (`%N`/`@N`)
survive index renumbering; prefer them in scripts.

---

## Reading

### capture-pane (alias capturep)
```
capture-pane [-aepPqCJMN] [-b buffer-name] [-E end-line] [-S start-line] [-t target-pane]
```
- `-p` write to stdout (else it goes to a buffer). This is the flag you want for reads.
- `-e` include escape sequences for text/background attributes. THE ghost-text detector: pipe to
  `cat -v` and look for faint `[2m` / `[0;2m` on the input line (HR-6).
- `-J` preserve trailing spaces AND join wrapped lines (implies `-T`). Use for long log lines.
- `-N` preserve trailing spaces (without joining). `-T` ignores trailing empty positions.
- `-C` escape non-printable chars as octal `\xxx`. `-a` alternate screen (no history). `-M` mode
  screen. `-q` quiet (suppress the no-alternate-screen error).
- `-S start` / `-E end`: `0` = first VISIBLE line, negative = into history, `-` to `-S` = start of
  history. `-b <name>` names the destination buffer when NOT using `-p`.
- House: `tmux capture-pane -t 0:worker -p -J -S -200` (last 200 history lines, wraps joined).

---

## Sending keys

### send-keys (alias send)
```
send-keys [-FHKlMRX] [-c target-client] [-N repeat-count] [-t target-pane] [key ...]
```
- Each `key` arg is a key NAME (`C-a`, `Enter`, `Escape`, `C-c`, `C-u`, `NPage`) UNLESS it is not
  recognized, in which case it is sent as a literal series of characters.
- `-l` disables key-name lookup and sends literal UTF-8. Use when literal text could collide with a
  key name (e.g. the bare word `Enter`): `send-keys -l 'Enter'`.
- `-H` each key is a hex ASCII code. `-M` pass a mouse event. `-X` send a copy-mode command.
  `-N` repeat count, `-F` expand `#{...}` formats in args, `-R` reset terminal state.
- There is NO `-p` flag on send-keys (that belongs to paste-buffer). No `-p` means send-keys cannot
  do bracketed paste, which is exactly why long text goes through load-buffer/paste-buffer.
- House: `tmux send-keys -t 0:build 'pnpm test' Enter` · clear input: `tmux send-keys -t 0:w C-u`.

---

## Buffers (the reliable long-paste path)

### load-buffer (alias loadb)
```
load-buffer [-w] [-b buffer-name] [-t target-client] path
```
- `path` may be `-` to read from stdin. `-b <name>` sets a NAMED buffer (HR-4, defeats the parallel
  race). `-w` also copies to the system clipboard (rarely wanted for a worker paste).
- House: `tmux load-buffer -b b_worker - < /path/brief.md`.

### paste-buffer (alias pasteb)
```
paste-buffer [-dpr] [-b buffer-name] [-s separator] [-t target-pane]
```
- `-p` bracketed paste: Claude Code sees one `[Pasted text #N]` event (reliable). USE IT for briefs.
- `-d` delete the buffer after pasting (use for briefs that carry a secret, HR-13).
- `-r` do not replace LF with CR. `-b <name>` the source buffer, `-s` a custom line separator.
- House: `tmux paste-buffer -p -b b_worker -t 0:worker` · secret brief: add `-d`.

### set-buffer (alias setb) / delete-buffer (alias deleteb)
```
set-buffer    [-aw] [-b buffer-name] [-t target-client] [-n new-buffer-name] data
delete-buffer [-b buffer-name]
```
- `set-buffer -b <name> 'text'` sets a buffer from an inline string (small pastes without a file).
- `delete-buffer -b <name>` removes a named buffer (cleanup after a secret-bearing paste if you did
  not use `paste-buffer -d`). With no `-b`, deletes the most-recent auto-named buffer.

---

## Windows and panes

### new-window (alias neww)
```
new-window [-abdkPS] [-c start-directory] [-e environment] [-F format] [-n window-name]
           [-t target-window] [shell-command [argument ...]]
```
- `-n <name>` name the window. `-c <dir>` set its cwd. `-d` create without switching to it.
  `-a`/`-b` insert after/before the target index. `-k` kill an existing window at the target index.
  `-P` print the new window's info (with `-F` format). `-e K=V` set an env var in the new window.
- House: `tmux new-window -t 0 -n scratch -c /home/christopher/claude`.

### split-window (alias splitw)
```
split-window [-bdfhIvPZ] [-c start-directory] [-e environment] [-F format] [-l size]
             [-t target-pane] [shell-command [argument ...]]
```
- `-h` left|right split, `-v` top/bottom (default if neither). `-l <size>` size the new pane (e.g.
  `-l 40%` or `-l 80`). `-d` do not switch focus. `-b` place the new pane before the target.
  `-f` full-height/width split. `-Z` zoom. For the OPERATOR's own split-view only (not agents, HR-15).
- House: `tmux split-window -t :1 -h` (code left, logs right).

### kill-window (alias killw)
```
kill-window [-a] [-t target-window]
```
- Kills the target window (and unlinks it from every session). `-a` kills ALL windows EXCEPT `-t`
  (dangerous, rarely what you want). ALWAYS resolve your own `window_id` first (HR-2) so `-t` is
  never you. House: `tmux kill-window -t 0:scratch`.

### select-window (alias selectw)
```
select-window [-lnpT] [-t target-window]
```
- Switch the active window: `-n` next, `-p` previous, `-l` last, `-T` toggle. `-t` an explicit
  target. Read-only-ish (changes focus, not content). Rarely needed for headless orchestration.

---

## Introspection / formats

### list-panes (alias lsp) / list-windows (alias lsw)
```
list-panes   [-as] [-F format] [-f filter] [-t target]
list-windows [-a]  [-F format] [-f filter] [-t target-session]
```
- `-a` every pane/window on the SERVER (ignores `-t`). `-s` (list-panes) treats target as a session.
  `-F` a format string, `-f` a filter format (keep rows where it evaluates true).
- House map: `tmux list-panes -a -F '#S:#I.#P #D #{window_id} #W #{pane_current_command}'`.

### display-message (alias display)
```
display-message [-aCIlNpv] [-c target-client] [-d delay] [-t target-pane] [message]
```
- `-p` print the (format-expanded) message to STDOUT instead of the status line. This is the
  read-a-format primitive. `-a` list client info, `-v` verbose logging.
- House who-am-I: `tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_index} #{window_id} #{window_name}'`.

### has-session (alias has)
```
has-session [-t target-session]
```
- Exit 1 if the session does not exist, exit 0 if it does. Guard before targeting a session.
  House: `tmux has-session -t 0 2>/dev/null && echo "session 0 live"`.

### wait-for (alias wait)
```
wait-for [-L | -S | -U] channel
```
- Cross-client synchronization primitive: a client blocks on `wait-for <channel>` until another runs
  `wait-for -S <channel>` (signal). `-L`/`-U` lock/unlock a channel. Niche for headless orchestration
  (the pipeline uses sleeps + capture-assert, not wait-for), documented for completeness.

---

## FORMAT variables (verified present in `man tmux`, use with `-F` / `display-message -p`)

| Short | Long form | Meaning |
|---|---|---|
| `#S` | `#{session_name}` | session name |
| `#I` | `#{window_index}` | window index (renumbers) |
| `#W` | `#{window_name}` | window name |
| `#P` | `#{pane_index}` | pane index (renumbers) |
| `#D` | `#{pane_id}` | unique pane id `%N` (stable) |
| `--` | `#{window_id}` | unique window id `@N` (stable) |
| `--` | `#{window_panes}` | pane count in the window |
| `--` | `#{window_active}` / `#{pane_active}` | 1 if active, else 0 |
| `--` | `#{pane_pid}` | PID of the pane's foreground process (its shell) |
| `--` | `#{pane_current_command}` | command running in the pane |
| `--` | `#{pane_dead}` | 1 if the pane's process has exited |
| `--` | `#{pane_title}` | pane title |

To inspect a REPL's real process state for the wedge check (HR-9): get the pane's pid with
`tmux display-message -p -t 0:<w> '#{pane_pid}'`, then `ps` its process tree and read the STAT
column (`S` sleeping, `T` stopped, `Z` zombie). `#{pane_dead}` = 1 means the process already exited
(the window is a husk, kill + respawn).
