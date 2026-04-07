---
name: tmux
description: Control tmux windows and panes for testing, running commands, and orchestrating multi-session workflows. Use when the user needs to run commands in other terminals, test across sessions, or orchestrate multiple agents.
allowed-tools: Bash, Read
---

# tmux — Terminal Multiplexer Control

Gives Claude Code full control over tmux windows and panes for testing, running commands, and orchestrating multi-session workflows.

## Core operations

### 1. Orientation — find yourself
```bash
echo "$TMUX_PANE"
tmux list-panes -a -F '#S:#I.#P #D #W' | grep "$TMUX_PANE"
tmux list-windows -F '#I:#W (#{window_panes} panes)'
```

### 2. Read — observe other windows/panes
```bash
tmux capture-pane -t :N -p              # visible area
tmux capture-pane -t :N -p -S -100     # last 100 lines
tmux capture-pane -t main:4.2 -p       # specific pane
```

### 3. Send — type into other windows/panes
```bash
tmux send-keys -t :N "echo hello" Enter
tmux send-keys -t :N C-c               # Ctrl+C
```
Always sleep after send-keys, then capture-pane to read results.

### 4. Create — new windows and panes
```bash
tmux new-window -t main -n "test" -c "/path"
tmux split-window -t :N -h             # horizontal split
tmux split-window -t :N -v             # vertical split
```

## Key Patterns

**Test loop:** code in window X, test in X+1. Send test command, sleep, capture-pane, iterate.

**Dev server + test:** start blocking server in one window, curl/test from another, C-c when done.

**Multi-agent:** create window with 3 panes, start agents in each, send-keys to command them, capture-pane to read responses.

**Claude session control:** send-keys 'i' to enter insert mode, send prompt, sleep 30-60s, capture-pane to read response.

## Spawning Claude Sessions

When launching a new Claude Code session in a tmux window, **always** include `--add-dir ~/claude` so the session has access to the main memory, CLAUDE.md, and project context — even when running from a subdirectory like a repo.

```bash
# Correct — has memory access from any cwd
claude --dangerously-skip-permissions --add-dir ~/claude

# Wrong — loses memory if cwd is not ~/claude
claude --dangerously-skip-permissions
```

Also remember: do NOT use `claude -p "$(cat file.txt)"` — special characters break shell expansion. Use interactive mode and send the prompt via send-keys instead.

## Rules
1. Never operate on windows you don't own — always list-windows first
2. Never kill your own window — check $TMUX_PANE first
3. Sleep after send-keys (1s for simple cmds, 15-60s for Claude)
4. Clean up windows you created when done
5. Read before writing — capture-pane to check state first
