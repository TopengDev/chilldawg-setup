---
name: journal
description: Append a tagged, timestamped breadcrumb to the append-only activity journal (~/.claude/memory/journal.md), the zero-friction capture layer that a daily 04:00 WIB audit promotes into canonical memory. Fire it mid-flow when a decision, a preference or correction, a durable project fact, or a reference happens, or when the user says /journal. For a deliberate canonical write use /remember, for billable time use /worklog.
allowed-tools: Bash, Read
---

# /journal: capture a tagged breadcrumb into the memory-consolidation loop

`/journal` is the **zero-friction capture layer** of a memory-consolidation loop. You fire it mid-flow, WITHOUT stopping to craft frontmatter, the moment a state-bearing thing happens. It appends one tagged, timestamped line to `~/.claude/memory/journal.md`. A daily audit reads the new lines and PROMOTES the keepers into canonical `~/.claude/memory/<type>_<slug>.md` files, so nothing worth keeping drops between sessions.

Be honest about the niche. If you are going to stop and write proper frontmatter anyway, that is `/remember` (the deliberate canonical writer), not `/journal`. In practice most memory files today ARE written directly by `/remember`, and the journal capture path has gone quiet (see §1, the loop is real but currently idle). `/journal` earns its keep as the ONE breadcrumb you can drop without breaking flow: a decision made in passing, a correction Toper just voiced, a durable fact you noticed. Drop it, keep working, let the 04:00 audit do the careful classification.

This skill has NO browser automation and nothing to defer to `/agent-browser`.

═══════════════════════════════════════════════════════════════════════════
## 0. PRIME RULES (OVERRIDE EVERYTHING BELOW)
═══════════════════════════════════════════════════════════════════════════

Seven hard rules. Each has a verified reason. Violating one is a failed journal call, not a style choice.

### 0.1 No em dash or en dash, ANYWHERE (PRIME)
NEVER emit an em dash (U+2014) or en dash (U+2013): not in an entry, not in this SKILL.md, not in the report to Toper. A journal entry gets promoted near-verbatim into a canonical memory file, so a dash in a summary PROPAGATES into the store and violates Toper's hard house rule (`feedback_no_long_hyphens`, 2026-06-02). Use a comma, a colon, parentheses, or "to" for ranges. The plain hyphen-minus in compounds (offline-first, real-time, aenoxa-pos-minio-1) stays fine.

### 0.2 ALWAYS the script, NEVER hand-edit journal.md
ALWAYS append via `~/.claude/scripts/journal-add.sh`. NEVER hand-edit or hand-append `journal.md`, and NEVER trust the journal.md header line that says "or by hand following the format" (it is wrong, and it is what invited the failure below). Verified failure: the `## 2026-06-23 AURA Phase 4` block (9 hand-pasted lines, a `##` header plus 8 plain bullets, lines 54 to 62 of journal.md) does NOT match the audit's entry regex, so the parser never sees it; its `[[project_aura_svg_xss_fix]]` target was never created (the XSS content survived only by luck in two other files). A hand-appended line is INERT: silently never promoted.

### 0.3 NEVER a secret VALUE (this file is git-tracked and auto-pushed)
NEVER put a secret value in an entry. Reference its LOCATION only (`$VAR in secrets.env`, "the token in secrets.env"). Stakes are higher than they look: `journal.md` is a symlink into the `chilldawg-setup` dotfiles repo, and `memory-autopush.timer` commits and pushes the memory dir every :00 and :30. A leaked value is not just local, it is committed and pushed within 30 minutes. Run the §5 secret self-scan before every append. If you find a real secret already in the data, report the file plus the pattern TYPE only, never the value.

### 0.4 NEVER back-date or reorder entries (high-water idempotency)
NEVER pass a hand-crafted past timestamp and never reorder the file. The audit tracks a high-water mark (the newest timestamp it has already processed); an entry stamped at or before that mark is NEVER promoted. Only `journal-add.sh`, which stamps NOW in Asia/Jakarta, is safe. Reordering or editing history breaks the idempotency the whole loop depends on.

### 0.5 ONE fact per entry
The summary is a SINGLE line (aim for 140 chars or fewer) carrying one fact. Put nuance in the optional detail arg (rendered as 2-space-indented continuation lines). Two facts crammed into one summary means the audit promotes a muddled memory or drops half of it.

### 0.6 Pick the MOST SPECIFIC tag; `ephemeral` is not a lazy default
Choose from the §2 tag table. `ephemeral` is the ONLY tag the audit pre-filters to SKIP. Use it for genuine noise you still want as a breadcrumb, NEVER as an escape hatch to avoid choosing. A real fact mis-tagged `ephemeral` is a fact deliberately thrown away.

### 0.7 Route the fact to the RIGHT skill
`/journal` is not the only memory surface. Before appending, confirm the fact belongs here and not in a sibling (full table in §4):
- Billable client time goes to `/worklog` (a JSONL hours ledger that feeds `/invoice`), NEVER a journal entry.
- A durable fact you are deliberately writing NOW with full frontmatter goes to `/remember`, not `/journal`.
- A person fact or a credential-location fact: prefer `/remember` (its `contact` and `credential` namespaces are UNREACHABLE from any journal tag, see §2 mapping).

═══════════════════════════════════════════════════════════════════════════
## 1. WHAT THE LOOP IS (and its honest current state)
═══════════════════════════════════════════════════════════════════════════

```
  YOU (mid-session)                    DAILY 04:00 WIB (systemd --apply, LIVE)
  ────────────────                     ──────────────────────────────────────
  journal-add.sh <tag> "…"  ──append──►  journal.md  ──read new entries──►  journal-audit.py
                                                                              │  (claude-sonnet-4-6)
                                                                              ├─ PROMOTE state-bearing
                                                                              │    entries -> ~/.claude/memory/<type>_<slug>.md
                                                                              │    + append to MEMORY.md index
                                                                              ├─ SKIP ephemeral + non-durable
                                                                              └─ advance high-water mark
```

**Verified paths and mechanics** (deep dive: `references/loop-internals.md`):
- Appender: `~/.claude/scripts/journal-add.sh` (do not edit; it is the canonical loop infra).
- Journal: `~/.claude/memory/journal.md` (symlinked into `chilldawg-setup`, auto-pushed, see §0.3).
- Audit: `~/.claude/scripts/journal-audit.py`. DEFAULT is a safe dry-run; the daily timer runs it with `--apply` (LIVE: backup, promote, advance high-water).
- Timer: `journal-audit.timer`, `OnCalendar=*-*-* 04:00:00 Asia/Jakarta`, `Persistent=true`. The service runs `python3 journal-audit.py --apply`. So the daily run genuinely mutates the store.
- The audit is conservative (create-if-absent else append, never destructive overwrite), reversible (tar backup before any write), idempotent (high-water), and fail-safe (restore-on-error).
- This loop REPLACES auto-dream, which stays OFF (`feedback_memory_consolidation_loop`, `reference_auto_dream`). Do not enable `autoDreamEnabled`.

**Honest current state (verified 2026-07-03, do not overclaim the loop):**
- The capture path is IDLE. The high-water is frozen at `2026-06-15T07:54:59`; the audit has logged "9 total, 0 un-audited, 0 candidates" on every run since. Nobody has journaled a conforming entry in weeks; direct `/remember` writes now dominate. The audit's own source comment concedes this: "most memory files are now written DIRECTLY ... and never flow through journal.md."
- So the audit's now-primary job is a SECOND function most callers do not know exists: an **orphan safety-net** that reindexes directly-written memory files into `MEMORY.md` on every run. It is imperfect (the logged orphan count is inflated by intended sharding, and it hit a real `--cap` ceiling once). Full mechanics and the health-check are in §5 and `references/loop-internals.md`.
- Takeaway: journaling is a habit worth keeping (the breadcrumb the audit can still promote), but do not describe the loop as a busy pipeline. It is a quiet, working safety-net with an idle capture front-end.

═══════════════════════════════════════════════════════════════════════════
## 2. WHEN TO JOURNAL
═══════════════════════════════════════════════════════════════════════════

**Decision tree (run it in your head before appending):**
1. Is it billable client time? -> `/worklog`, STOP.
2. Are you deliberately writing a durable fact NOW, with frontmatter, on Toper's explicit "remember this"? -> `/remember`, STOP.
3. Is it a person or a credential-location? -> prefer `/remember` (contact/credential namespaces). A journal `reference` works but lands as type `reference`, not as a contact/credential record.
4. Would it be LOST between sessions and is worth recalling later? -> journal it with the most-specific tag below.
5. Is it in-flight noise you want only as a breadcrumb? -> `ephemeral` (the audit will skip it).
6. None of the above (truly trivial, self-evident, or derivable from code/git)? -> do not journal it.

### Tag decision table (pick the MOST specific, §0.6)

| Tag | Use for | Example trigger |
|---|---|---|
| `decision` | A choice was made: direction, architecture, strategy, "we do X not Y" | "Switched signal-trader to Strategy E" |
| `feedback` | A preference or correction Toper voiced about how you work | "Toper prefers hard-block over warn for git hooks" |
| `project` | A durable fact about ongoing work: a goal, a constraint, a state change, an env quirk | "wa-behavior-learn.service PATH omits ~/.bun/bin, MCP fails" |
| `reference` | A pointer to a person, tool, resource, credential LOCATION, repo, endpoint | "Pulse MinIO bucket = product-images on aenoxa-pos-minio-1" |
| `ephemeral` | Transient status you want as a breadcrumb; the audit SKIPS it | "Spawned worker X, attn round-trip verified" |

### Tag to promoted-type mapping (the tags are NOT 1:1 with memory types)

The audit's valid memory types are `user | feedback | project | reference` (verified: `VALID_TYPES` in journal-audit.py). The journal tags do NOT map cleanly onto them:

| Journal tag | Promotes as memory type | Note |
|---|---|---|
| `decision` | project OR feedback (LLM re-classifies) | There is NO "decision" memory type. The audit re-types it. |
| `feedback` | feedback | Clean pass-through. |
| `project` | project | Clean pass-through. |
| `reference` | reference | Clean pass-through. A person/credential still lands as `reference`, not `contact`/`credential`. |
| `ephemeral` | (nothing) | Pre-filtered to SKIP. Never promoted. |
| (unreachable) | user, contact, credential | NO journal tag reaches these. `user` here is /remember's `identity` namespace (stored as `user_*.md`); route people via `contact`, secret-locations via `credential`. All via `/remember` (§4). |

Implication: for a person or a credential fact you want retrievable under the right namespace, use `/remember`. A journal `reference` is a coarse fallback.

═══════════════════════════════════════════════════════════════════════════
## 3. HOW TO USE
═══════════════════════════════════════════════════════════════════════════

Call the deterministic appender. It timestamps (Asia/Jakarta), validates the tag, and writes the exact format the audit parses:

```bash
~/.claude/scripts/journal-add.sh <tag> "<one-line summary>" ["<optional detail>"]
```

### One worked example per tag (matched to what it promotes to)

```bash
# decision  -> promotes as project or feedback (LLM re-types it)
~/.claude/scripts/journal-add.sh decision "Switched signal-trader to Strategy E (100% close at TP5, BE-trail at TP3)"

# feedback  -> promotes as feedback, with detail on the continuation line
~/.claude/scripts/journal-add.sh feedback "Toper prefers hard-block over warn for git hooks" \
  "Came up while dropping the redundant tsc-check hook (#159)."

# project   -> promotes as project (a durable, state-bearing fact)
~/.claude/scripts/journal-add.sh project "aenoxa_pos_web offline sync uses last-write-wins keyed on updated_at"

# reference -> promotes as reference (a person/credential is a coarse fit, prefer /remember)
~/.claude/scripts/journal-add.sh reference "Pulse MinIO bucket = product-images on container aenoxa-pos-minio-1"

# ephemeral -> the audit SKIPS this (breadcrumb only)
~/.claude/scripts/journal-add.sh ephemeral "Spawned worker adopt-journal-audit; attn round-trip verified"
```

### On success it echoes exactly:
```
journaled [<ts>] (<tag>) <summary>
```
The entry is now queued for the next 04:00 audit.

### Exit codes (verified against journal-add.sh)
| Exit | Meaning | Fix |
|---|---|---|
| 0 | Appended. | Assert the `journaled [...]` echo (§6). |
| 64 | Missing or empty tag/summary, OR an invalid tag. | Valid tags: `decision feedback project reference ephemeral`. Re-run with a valid tag plus a non-empty summary. |
| 1 | `journal.md` does not exist. The appender does NOT create it. | See §7 and `references/failure-playbooks.md`: recreate the header plus spec block first, then re-run. |

Edge note: the appender's tag check is `grep -qw "$tag"` against the valid list, so the tag is treated as a regex. Pass a literal tag from the table; do not pass regex metacharacters (a tag like `p.oject` could false-match).

═══════════════════════════════════════════════════════════════════════════
## 4. BOUNDARY: journal vs remember vs worklog
═══════════════════════════════════════════════════════════════════════════

Three sibling skills touch persistence. Route by the bright-line test, do not overload `/journal`.

| Skill | Is | Store | Bright-line test |
|---|---|---|---|
| `/journal` | Zero-friction in-session breadcrumb; the audit decides later | `~/.claude/memory/journal.md` (append-only log) | "Something state-bearing just happened and I do not want to stop to write frontmatter." |
| `/remember` | Deliberate canonical write, full schema-v2 frontmatter, 6 namespaces (identity/feedback/project/reference/contact/credential), direct Write + index regen | `~/.claude/memory/<ns>_<topic>.md` plus MEMORY.md/shards | "I am deliberately persisting a durable fact NOW, and I want it retrievable and correctly namespaced." |
| `/worklog` | Billable-hours ledger feeding `/invoice` | `~/.claude/worklog/entries.jsonl` | "This is time on client work (hours, money), not a memory." |

Do NOT duplicate `/remember`. If Toper says "remember X", that is `/remember`. `/journal` is the continuous low-friction capture that the daily audit consolidates.

═══════════════════════════════════════════════════════════════════════════
## 5. ENFORCEMENT (gates, scans, health-check)
═══════════════════════════════════════════════════════════════════════════

### 5.1 Pre-append gate (ALL 5 must pass before calling journal-add.sh)
1. **One fact?** The summary carries exactly one fact (§0.5). Nuance moves to the detail arg.
2. **Most-specific tag?** Chosen from the §2 table, not a lazy `ephemeral` (§0.6).
3. **Secret self-scan ran, clean?** No secret value present (§0.3, recipe below).
4. **One line, keyword-bearing?** Summary is a single line, about 140 chars or fewer, and carries a concrete retrieval keyword (summaries seed BM25 retrieval on promotion, so a low-signal summary is hard to find later).
5. **Using the script?** You are calling `journal-add.sh`, never hand-editing (§0.2).

### 5.2 Secret self-scan (run on the summary + detail BEFORE appending)
```bash
printf '%s\n%s\n' "$summary" "$detail" | grep -nEi \
  'sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[A-Z0-9]|-----BEGIN|(api[_-]?key|password|secret|token|bearer)[=: ]|(\+?62|0)8[0-9]{7,}' \
  && echo "STOP: secret-shaped text. Reference its LOCATION instead (e.g. \$VAR in secrets.env)." \
  || echo "secret-scan clean"
```
A hit means STOP and rewrite to reference the location (§0.3). This matters because the entry is auto-committed and pushed.

### 5.3 Format lint (detect a hand-edit / silent-drop, §0.2)
Zero-file baseline (scoped to the entries region, so the spec block is not false-flagged):
```bash
awk '/^## Entries/{e=1;next} e && NF && !/^  / && !/^- \[[^]]+\] \([a-z]+\)/{print NR": "$0}' \
  ~/.claude/memory/journal.md
```
Any output = a malformed, INERT block the audit cannot see. Codified equivalent (exit 1 on any malformed line, exit 2 if the journal is missing):
```bash
~/.claude/skills/journal/scripts/journal-lint.sh
```
Run it whenever a hand-edit is suspected. You CANNOT fix a flagged line in place (append-only); re-append the fact correctly so it promotes, and leave the inert text (§7).

### 5.4 Loop health-check rubric (is the loop actually working?)
Read two things:
```bash
cat  ~/.claude/memory/.journal-audit-state.json            # is last_audited_ts advancing?
tail -20 ~/.local/share/journal-audit/audit.log            # candidates? orphan-net? FATAL?
```
Classify:
- **GREEN**: high-water advanced within about a day of the newest conforming entry, and no FATAL in the log.
- **YELLOW**: high-water stale but no errors. This is the NORMAL idle state when nobody has journaled (the loop is fine, just quiet). Also run the §5.3 lint: a stale high-water plus a malformed block present is a real silent-drop, escalate to §7.
- **RED**: a `FATAL` in the log (for example the 2026-06-24 `cannot fit index under 24000 bytes` cap error), OR conforming un-audited entries are pending yet the high-water will not advance. Go to `references/failure-playbooks.md`.

Note on the orphan count: the log line `orphan safety-net: ... N -> N orphans` is INFLATED and a steady non-zero N is largely expected, not N lost files. The detector compares on-disk files against `MEMORY.md` only, while the store deliberately shards the `contact`/`credential`/`project` namespaces into `indexes/*.md` (verified: 61 sharded files, 0 of them linked in MEMORY.md, and the orphan list is led by exactly those). Those files also stay BM25-retrievable (`memory-retrieve.py` scans files directly). The actionable signal is a `FATAL`, not the raw orphan number. Full explanation: `references/loop-internals.md`.

═══════════════════════════════════════════════════════════════════════════
## 6. VERIFY (after every append)
═══════════════════════════════════════════════════════════════════════════

- Assert the exact echo `journaled [<ts>] (<tag>) <summary>` and exit 0. No echo or a non-zero exit means it did not land (check §3 exit codes).
- The entry is now queued for the next 04:00 `--apply` audit. To PREVIEW what would promote, run `journal-audit.py --dry-run`. WARNING: a dry-run writes nothing and does not advance the high-water, but it DOES make a paid claude-sonnet-4-6 API call if there are candidate entries. Do not run it in a loop.
- Optional integrity check: run the §5.3 lint to confirm the file still fully conforms.

═══════════════════════════════════════════════════════════════════════════
## 7. FAILURE PLAYBOOKS (quick reference; full recipes in references/)
═══════════════════════════════════════════════════════════════════════════

| Symptom | Cause | First move (full recipe: `references/failure-playbooks.md`) |
|---|---|---|
| `journal not found` (exit 1) | journal.md deleted or rotated; appender does NOT auto-create | Recreate the header plus Entry-format spec block (template in the playbook), then re-run journal-add.sh. |
| Lint flags a malformed block | A hand-edit or worker dump violated the format; it is inert | Do NOT fix in place. Re-append the fact via journal-add.sh so it promotes; leave the inert text. |
| Entries not promoting / high-water stuck | ephemeral tag, OR back-dated (at/below high-water), OR audit errored, OR API key unresolved | Diagnose ladder in the playbook. Preview with `--dry-run`; only if correct, `--apply` (or `--since <ISO_TS>` to reprocess a window). |
| Orphan reindex `FATAL` (24000-byte cap) | Memory-store scaling limit, OUT of journal scope | Do NOT hand-edit MEMORY.md (auto-generated). Surface to Toper (standup/loop-digest): root fix is `gen-memory-index.py --cap` or further sharding. |
| Secret-shaped text in an entry | §0.3 slip | Value is already pushed. Report file plus pattern TYPE only (never the value) and flag rotation to Toper. |

**Do / Don't (verbatim guardrails):**
- DO fire `/journal` mid-flow without stopping. DON'T stop to craft frontmatter (that is `/remember`).
- DO tag genuine noise `ephemeral`. DON'T use `ephemeral` to dodge choosing a real tag.
- DO put nuance in the detail arg. DON'T cram a second fact into the summary.
- DO reference a credential's location. DON'T paste its value.
- DO let the 04:00 audit classify. DON'T hand-edit journal.md to "help" it.

## PROGRESSIVE DISCLOSURE

Rules, gates, the pre-append checks, the lint, and the health-check live in THIS file (loaded whole at invocation). Encyclopedic depth lives in `references/` and is read on demand:
- `references/loop-internals.md`: full audit mechanics (dry-run vs --apply, model + API key sourcing, high-water state, VALID_TYPES vs tags, backups/logs, the orphan safety-net + gen-memory-index `--cap` + sharding reality, what "0 candidates" means, the symlink + autopush).
- `references/failure-playbooks.md`: exact recovery recipes for every §7 row.

Do NOT fork or edit the canonical scripts (`journal-add.sh`, `journal-audit.py`, `gen-memory-index.py`). This skill references them; the only script it owns is `scripts/journal-lint.sh`.
