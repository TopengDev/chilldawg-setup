# systemd `--user` units (tracked)

> **Note:** Before this directory existed, the live `--user` timers/services in
> `~/.config/systemd/user/` (daily-brief, signal-trader-bridge, reminder-check,
> wa-sender, wa-behavior-learn, macro-news) were **NOT tracked in this repo**.
> This dir starts tracking them. Only `journal-audit.*` is committed here so far;
> the others should be back-filled in a follow-up. Flag raised by task #160.

## journal-audit (memory-consolidation loop)

Runs `~/.claude/scripts/journal-audit.py --apply` daily at **04:00 WIB** to
promote state-bearing entries from `~/.claude/memory/journal.md` into canonical
memory files. See `~/claude/notes/adopt-journal-audit-2026-05-30/`.

- `journal-audit.service` — oneshot; reads the API key from `~/.claude/secrets.env`
  (the key is **not** stored in the unit). Logs to
  `~/.local/share/journal-audit/run.log`.
- `journal-audit.timer` — daily 04:00 Asia/Jakarta, `Persistent=true`.

### Status: BUILT but DISABLED ⚠️

Deliberately **not enabled**. Toper reviews the dry-run promotion sample
(`report.md` in the task notes dir) first. The live run mutates the memory store
(conservatively — only adds/appends, backs up first), so enabling is a separate,
explicit go.

### To enable (only after Toper signs off on the dry-run)

```bash
# copy the tracked units to the live location if not already there
cp config/systemd/user/journal-audit.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now journal-audit.timer
systemctl --user list-timers journal-audit.timer   # confirm next run
```

### To preview without enabling

```bash
python3 ~/.claude/scripts/journal-audit.py --dry-run   # safe: operates on a copy
```

### To run a live audit once by hand (after sign-off)

```bash
python3 ~/.claude/scripts/journal-audit.py --apply
```
