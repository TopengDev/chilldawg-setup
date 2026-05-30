---
name: journal
description: Append a tagged, timestamped entry to the append-only activity journal (~/.claude/memory/journal.md) so the daily memory-consolidation audit can later promote state-bearing facts to canonical memory. Use when something worth remembering happens (a decision, a preference/correction, a durable project fact, a reference) or when the user says /journal.
allowed-tools: Bash
---

# /journal — capture an activity-log entry

Appends one entry to the **append-only** activity journal at
`~/.claude/memory/journal.md`. A daily audit
(`~/.claude/scripts/journal-audit.py`, run by a systemd timer ~04:00 WIB) later
reads the un-audited entries and **promotes** the state-bearing ones into
canonical `~/.claude/memory/<type>_<slug>.md` files — so nothing worth keeping
silently drops between sessions. This is the *capture* half of that loop; the
audit is the *consolidate* half.

This is the lightweight, in-session counterpart to the `/remember` skill:
`/journal` is a fast append you do continuously as things happen; the daily
audit does the careful classification + deduped promotion. Prefer `/journal`
mid-session; the audit upgrades the keepers automatically.

## When to journal

Append an entry the moment any of these happen — don't wait to be asked:

- **decision** — a choice was made (direction, architecture, strategy, a "we'll do X not Y")
- **feedback** — Toper expressed a preference or correction about how I should work
- **project** — a durable fact about ongoing work: a goal, a constraint, a state change, a HEAD/commit, an env quirk
- **reference** — a pointer to a person, tool, resource, credential location, repo, endpoint
- **ephemeral** — transient status / chatter you want logged but the audit should NOT promote (it will skip these)

If it would be lost between sessions and is worth recalling later → journal it
(decision/feedback/project/reference). If it's just in-flight noise but you want
a breadcrumb → tag it `ephemeral`.

## How to use

Call the deterministic appender — it timestamps (Asia/Jakarta), validates the
tag, and writes the exact format the audit parses:

```bash
~/.claude/scripts/journal-add.sh <tag> "<one-line summary>" ["<optional detail>"]
```

### Examples

```bash
# a decision
~/.claude/scripts/journal-add.sh decision "Switched signal-trader to Strategy E (100% TP5 + BE-trail at TP3)"

# feedback from Toper, with detail
~/.claude/scripts/journal-add.sh feedback "Toper prefers hard-block over warn for git hooks" \
  "Came up while dropping the redundant tsc-check hook (#159)."

# a durable project fact
~/.claude/scripts/journal-add.sh project "chilldawg-setup at HEAD d366c16, pushed to origin/main, tree clean"

# a reference pointer
~/.claude/scripts/journal-add.sh reference "Pulse MinIO bucket = product-images on container aenoxa-pos-minio-1"

# breadcrumb the audit should skip
~/.claude/scripts/journal-add.sh ephemeral "Spawned worker adopt-journal-audit; attn round-trip verified"
```

## Rules

1. **One fact per entry.** Keep the summary to a single line; put nuance in the detail arg.
2. **Pick the most specific tag.** decision/feedback/project/reference get promoted; ephemeral is skipped.
3. **Never hand-edit past entries** in journal.md — append only. The audit tracks a high-water timestamp; rewriting history breaks idempotency.
4. **Don't duplicate /remember.** If Toper explicitly asks to "remember X" as a durable fact right now, `/remember` (write the memory file directly) is fine. Use `/journal` for the continuous, low-friction capture that the daily audit consolidates.
5. **Never put secrets in an entry** — reference where a credential lives (e.g. "$VAR in secrets.env"), never the value.

## Verify

After appending, the script echoes `journaled [ts] (tag) summary`. The entry is
now queued for the next daily audit (or run `journal-audit.py --dry-run` to
preview what it would promote).
