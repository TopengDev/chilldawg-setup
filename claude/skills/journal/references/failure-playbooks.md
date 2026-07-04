# Failure playbooks: exact recovery recipes

Read this when the loop misbehaves. Each recipe maps to a row in SKILL.md §7. All commands are non-mutating unless explicitly marked LIVE. Never edit the canonical scripts; never hand-edit journal.md or MEMORY.md.

---

## 1. "journal not found" (journal-add.sh exit 1)

**Cause:** `~/.claude/memory/journal.md` was deleted, moved, or rotated. The appender does NOT bootstrap it (verified: it exits 1 if the file is absent).

**Recovery:** recreate the file with a header plus the `## Entries` marker, then re-run. The audit only needs the marker and conforming entry lines; the header is human documentation. Use this dash-clean template. It deliberately OMITS the "or by hand following the format" blessing that the live header still carries (journal.md line 33) and that SKILL.md §0.2 warns against, because hand-appending is the silent-drop failure mode:

```bash
cat > ~/.claude/memory/journal.md <<'EOF'
# Journal, append-only activity log

This file is the append-only capture layer of the memory-consolidation loop.
A daily audit (~/.claude/scripts/journal-audit.py, systemd timer at 04:00 WIB)
reads new entries and promotes the state-bearing ones into canonical
~/.claude/memory files.

NEVER edit or delete existing entries. Append ONLY, and ONLY via
~/.claude/scripts/journal-add.sh (it stamps the time and writes the exact
format the audit parses). The high-water mark in
~/.claude/memory/.journal-audit-state.json tracks what has been audited;
editing history breaks idempotency.

## Entry format

- [<ISO-8601 timestamp with +07:00 offset>] (<tag>) <one-line summary>
  <optional 2-space-indented continuation lines>

tag is exactly one of: decision, feedback, project, reference, ephemeral

## Entries
EOF
```

Then verify and append:
```bash
~/.claude/skills/journal/scripts/journal-lint.sh            # expect OK (no entries yet)
~/.claude/scripts/journal-add.sh project "recreated journal.md after it went missing"
```

Note: if a backup exists (`~/.claude/memory-backups/memory-<stamp>.tar.gz`), you can instead extract the previous `journal.md` from the newest tar to preserve old entries. Extract to a temp dir and copy only journal.md; do not blow away the live memory dir.

---

## 2. Lint flags a malformed block

**Cause:** a hand-edit, a worker dump, or a paste violated the entry format. The audit's parser skips it, so it is INERT (never promoted). Verified instance: the `## 2026-06-23 AURA Phase 4` block.

**You CANNOT fix it in place.** The journal is append-only and editing history breaks idempotency (SKILL.md §0.4). Two safe moves:

1. Re-append each stranded fact CORRECTLY so it promotes on the next audit:
   ```bash
   ~/.claude/scripts/journal-add.sh <tag> "<the fact, one line>" ["<detail>"]
   ```
2. Leave the inert text where it is. It does no harm (the parser ignores it) and removing it would be a history rewrite.

Re-run the lint to confirm no NEW malformed lines were introduced:
```bash
~/.claude/skills/journal/scripts/journal-lint.sh
```

---

## 3. Entries not promoting / high-water stuck

Work this ladder in order; stop at the first that explains it.

**(a) Is the entry `ephemeral`?** Ephemeral entries are pre-filtered to SKIP by design. That is not a bug. If it should promote, re-append it with the correct tag.

**(b) Is it back-dated (timestamp at or below the high-water)?** Check:
```bash
cat ~/.claude/memory/.journal-audit-state.json     # note last_audited_ts
```
An entry stamped at or before `last_audited_ts` is never processed. Only `journal-add.sh` (which stamps NOW) avoids this. If someone hand-stamped a past time, re-append via the script.

**(c) Is it non-conforming (invisible to the parser)?** Run the lint (playbook 2). A malformed line is not an entry at all.

**(d) Did the audit error?** Check the log:
```bash
grep -E 'FATAL|ERROR|WARN' ~/.local/share/journal-audit/audit.log | tail -20
```
A `FATAL: LLM HTTP 401` means the API key did not resolve. Confirm `ANTHROPIC_API_KEY` is in the environment or present in `~/.claude/secrets.env` (do NOT print its value; just confirm the line exists):
```bash
grep -c '^[^#]*ANTHROPIC_API_KEY' ~/.claude/secrets.env   # expect >= 1
```

**Manual safe re-run (only after the above):**
```bash
# 1. PREVIEW (writes nothing; makes a paid sonnet-4-6 call if candidates exist)
python3 ~/.claude/scripts/journal-audit.py --dry-run

# 2. Only if the preview is correct, LIVE (backup, promote, advance high-water)
python3 ~/.claude/scripts/journal-audit.py --apply

# Optional: reprocess a specific window (overrides the high-water floor)
python3 ~/.claude/scripts/journal-audit.py --apply --since 2026-06-01T00:00:00+07:00
```
A live run is reversible (it tars the memory dir first) but it DOES mutate the tracked, auto-pushed store. Preview first, always.

---

## 4. Orphan reindex FATAL (24000-byte cap)

**Symptom in the log:** `WARN: orphan re-index failed: | FATAL: cannot fit index under 24000 bytes ... N entries`.

**This is OUT of the journal skill's scope.** It is a memory-store scaling limit in `gen-memory-index.py`, not a journal problem. Do:
- NOT hand-edit `MEMORY.md` (auto-generated; edits are overwritten).
- NOT try to prune memory files to shrink the index (that is a `/remember clean` decision, Toper-gated).
- Surface it to Toper via standup or the loop-digest. The root fix is his call: raise the cap (`gen-memory-index.py --cap <bigger>`) or shard more namespaces out of MEMORY.md into `indexes/` (the `contact`/`credential`/`project` shards already exist).

Context: a steady non-zero `orphan safety-net: N -> N` line is NOT this failure and is largely expected (it counts sharded files the detector does not scan; see loop-internals.md). Only an actual `FATAL` is the escalation trigger.

---

## 5. A secret value landed in an entry

**Reality:** `journal.md` is git-tracked and pushed within about 30 minutes by `memory-autopush.timer`. Assume the value is already committed and pushed the moment you notice.

**Do:**
- Report to Toper: the file (`~/.claude/memory/journal.md`), the line number, and the pattern TYPE only (for example "an API-key-shaped token", "a WhatsApp JID"). NEVER print, paste, or partially redact the actual value, anywhere.
- Flag that a rotation may be needed (Toper's call).
- Do NOT hand-delete the line to "clean up". That is a history rewrite (append-only invariant), it does not un-push the value, and it is a larger, Toper-gated operation.

**Prevent next time:** run the SKILL.md §5.2 secret self-scan on the summary and detail BEFORE every append.

---

## 6. Quick command index

```bash
# capture (the everyday path)
~/.claude/scripts/journal-add.sh <tag> "<summary>" ["<detail>"]

# integrity + health (read-only)
~/.claude/skills/journal/scripts/journal-lint.sh
cat ~/.claude/memory/.journal-audit-state.json
tail -20 ~/.local/share/journal-audit/audit.log

# preview / manual audit (dry-run is safe but paid if candidates exist; --apply is LIVE)
python3 ~/.claude/scripts/journal-audit.py --dry-run
python3 ~/.claude/scripts/journal-audit.py --apply
```
