---
name: wa-behavior-learn
description: Learn how each WhatsApp contact writes (their tone, slang, emoji, sentence shape) by reading the local WhatsApp SQLite store read-only, then writing one tone-matching memory file per contact. Connection-free, needs no WhatsApp plugin, safe to run daily headless. Use when Toper says /wa-behavior-learn or asks to refresh communication-style profiles.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# WhatsApp Behavior Learning

Reads recent WhatsApp chat history for each 1:1 contact straight from the local
SQLite store (READ-ONLY), analyzes how THAT person writes, and writes or updates
one per-contact style memory file (`whatsapp_style_<slug>.md`) so future replies
can match their voice. Built to run daily, headless, with no live WhatsApp
connection.

This skill is a memory PRODUCER. It never sends a message and never reads a
message live. It is the "how they write" half of the contact memory system.

> This skill is chilldawg-local (machine-specific) and is deliberately EXCLUDED
> from pi-setup (pi is Telegram-only). Absolute machine paths below are correct
> and intended, not placeholders.

---

## 0. WHY THIS SKILL EXISTS (read this once, it changes how you run)

The daily runner is `wa-behavior-learn.service`, which invokes
`claude --dangerously-skip-permissions -p "/wa-behavior-learn" --max-turns 50`.
That headless `-p` process does **not** load the WhatsApp plugin. The single
Baileys/WhatsApp socket is held only by the live main session, so in the cron run
`mcp__plugin_whatsapp_whatsapp__*` (list_chats / list_contacts / read_messages)
**do not exist**. This is not a bug to fix mid-run. It is the runtime.

Two dead ends this caused (both verified, in `journal.md`):
- 2026-05-31: MCP tools absent, the run aborted with nothing to read.
- 2026-06-02: confirmed again headless; the fix was to read the SQLite store directly.

So this skill is **SQLite-only and connection-free**. It reads two on-disk stores
read-only and never needs WhatsApp to be connected. See the failure playbook
(`references/failure-playbook.md`) for the full history, the systemd fragility,
and the "poke the main session" runner redesign (a followup that lives OUTSIDE
this skill dir).

---

## 1. PURPOSE + BOUNDARIES

**Purpose.** Keep a fresh, accurate, per-contact tone-matching profile for every
active 1:1 WhatsApp contact, so any session that later replies to that person
(via `/whatsapp`, WhatsApp auto-reply, etc.) can sound like a real reply from
Christopher, not a generic bot.

**Boundaries (do not blur these):**

| System | Owns | This skill's relationship |
|---|---|---|
| `/whatsapp` skill | LIVE send / read / manage messages | Different job. That skill talks; this skill only reads history and learns. Never send from here. |
| `whatsapp_style_<slug>.md` | HOW a person writes (voice, slang, emoji, phrasing) | **This skill writes these.** They are the deliverable. |
| `contact_<slug>.md` | WHO a person is (identity, phone JID, tier, whitelist status, relationship) | Read-only input for boundary. Cross-link it, never copy its facts into a style file. |
| memory auto-index | Placing files into `indexes/contact.md` | Driven by frontmatter `namespace`. This skill supplies correct frontmatter; it never hand-edits an index. |
| `user_christopher.md` / `feedback_toper_writing_style.md` | Christopher's OWN voice | Never profile Christopher here. We learn how OTHERS write so we can reply AS Christopher. |

Some people have BOTH a `contact_<slug>.md` and a `whatsapp_style_<slug>.md`
(e.g. kenny, kenken, suryadi) and both share `namespace: contact`. The split is
strict: identity/tier/JID live in `contact_`, deep voice lives in
`whatsapp_style_`. Full tier taxonomy + cross-link convention:
`references/tiers-and-boundaries.md`.

---

## 2. CRITICAL META-RULES (the prime directives, never violated)

1. **CONNECTION-FREE.** Never call `mcp__plugin_whatsapp_whatsapp__*`. They are
   absent at runtime. Read SQLite directly. `allowed-tools` is exactly
   `Read, Write, Edit, Glob, Grep, Bash` for this reason.
2. **READ-ONLY on the databases, ALWAYS.** Both stores are WAL-written by live
   processes. Snapshot-copy them, or open `file:...?mode=ro`. NEVER open them
   read-write. A corrupted `app.db` is Toper's real chat history.
3. **FRESHNESS GATE BEFORE PROFILING.** Compute how fresh the data is and pick
   the source by the decision table (section 3). Never run a blind
   `timestamp >= now-7d` against a store that may be days stale.
4. **DEDUP BY PHONE JID, never by display name.** Push/display names lie (Cece's
   own name showed as "vella" and minted a duplicate profile). Resolve identity
   to a phone JID first, then slug.
5. **REDACTION HARD-GATE on every quoted message.** `~/.claude/memory` is
   auto-pushed to a git remote on a schedule. A quoted OTP / password / account
   number / address / token URL becomes a committed, pushed leak. Gate every quote.
6. **NEVER hand-edit `MEMORY.md` or anything under `memory/indexes/`.** Indexing
   is auto-generated from frontmatter by `gen-memory-index.py`. Your only indexing
   duty is correct frontmatter.
7. **NO em-dash or en-dash** anywhere in this skill, its references, or any
   profile you generate. Use commas, parentheses, or a period. House PRIME rule.

---

## 3. PREFLIGHT + FRESHNESS GATE (blocking, top of every run)

Run this before any analysis. It is the single most load-bearing part of the
skill: it tells you WHICH store to trust and HOW fresh it is. Exact queries live
in `references/sql-cookbook.md`; the shape is:

```bash
set -u
APP="$HOME/.local/share/whatsapp-tui/app.db"          # PRIMARY (phone-JID keyed)
MSG="$HOME/.config/whatsapp-mcp/messages.db"          # FALLBACK (LID-fragmented)
command -v sqlite3 >/dev/null || { echo "PREFLIGHT ABORT: sqlite3 missing"; exit 1; }

# 1. Snapshot both stores (db + -wal + -shm) so every query reads a consistent,
#    lock-free copy and the live DBs are never touched. Copy is a pure read.
WORK="$(mktemp -d)"
for db in "$APP" "$MSG"; do
  for ext in "" "-wal" "-shm"; do
    [ -f "${db}${ext}" ] && cp "${db}${ext}" "$WORK/$(basename "$db")${ext}" 2>/dev/null
  done
done
APPS="$WORK/app.db"; MSGS="$WORK/messages.db"
[ -s "$APPS" ] || [ -s "$MSGS" ] || { echo "PREFLIGHT ABORT: no readable DB"; exit 1; }

# 2. Freshness signals
now=$(date +%s)
appMax=$(sqlite3 "$APPS" "SELECT COALESCE(MAX(timestamp),0) FROM messages;" 2>/dev/null || echo 0)
msgMax=$(sqlite3 "$MSGS" "SELECT COALESCE(MAX(timestamp),0) FROM messages;" 2>/dev/null || echo 0)
WAPID=$(cat "$HOME/.local/share/whatsapp-tui/wa.pid" 2>/dev/null)
if [ -n "$WAPID" ] && ps -p "$WAPID" -o comm= >/dev/null 2>&1; then wa_alive=1; else wa_alive=0; fi
```

Then apply the **SOURCE DECISION TABLE** (all thresholds are hard):

| Condition (checked in order) | Source | Recency window anchor | Report |
|---|---|---|---|
| `wa_alive=1` AND `now-appMax <= 48h` | **app.db** | `now - 7d` | VERDICT: app.db fresh |
| app.db stale AND `msgMax-appMax > 24h` | **messages.db + @lid->phone merge** | `msgMax - 7d` | WARN: app.db stale, using fresher messages.db (LID-merged) |
| app.db stale AND `msgMax-appMax <= 24h` | **app.db** | `appMax - 7d` | WARN: data is N days old, relaunch `wa` to resync app.db |

"app.db stale" = `wa_alive=0` OR `now-appMax > 48h`. 48h = 172800, 24h = 86400,
7d = 604800 (seconds). If ONLY messages.db exists, take the messages.db row.

**Emit a one-line VERDICT and never skip it.** Worked example using today's real
values (wa_alive=0, app.db 3 days stale, messages.db fresher by >24h, so Row 2
fires and the window anchors on msgMax-7d):
```
VERDICT source=messages.db appMax=2026-06-30T04:08 msgMax=2026-07-03T07:44 wa_alive=0 window_from=2026-06-26 note="app.db 3d stale, messages.db fresher, using @lid->phone merge"
```

> Why this table exists (verified 2026-07-03). app.db (phone-JID keyed, matches
> slugs) is the RIGHT primary, but it is only fresh while Toper's `wa` TUI runs.
> That day: `wa` was dead, `wa.pid` was stale, app.db newest message was
> 2026-06-30 (3 days old), while messages.db was live to 2026-07-03 07:44 but its
> recent 1:1 activity was LID-keyed (5 `@lid` chats vs 1 phone chat in the same
> window). A blind `now-7d` on app.db would have profiled an empty window; blind
> messages.db use would mis-slug by `@lid`. The gate resolves this every run. It
> INVERTS the older memory that said "app.db is always the fresher one" -- which
> DB is fresher flips with whether `wa` is running, so compute it, never assume.

---

## 4. PROCEDURE

### Step A: Build the active set (rank + threshold)

From the chosen source, over the chosen window, count each 1:1 contact's OWN
qualifying messages and keep only real signal. Qualifying = `from_me=0`, text
non-empty, `type IN ('conversation','extendedTextMessage')` (app.db) or
`message_type IN (...)` on `content` (messages.db), 1:1 only, skip-registry
applied (section 7). Rank by count, profile only contacts with **>= 5**
qualifying messages, and **cap at the top 20 per run** to bound turns. Everything
below 5, or skipped, is logged as a gap (not a file). Full query:
`references/sql-cookbook.md`.

Expect a single-digit-to-low-double-digit active set per 7-day window. A recent
real run yielded 6 contacts, top contact 88 messages, tapering to ~16. The set
moves run to run, which is exactly why the freshness gate anchors the window.

### Step B: Resolve identity to a phone JID (dedup key)

For each candidate `chat_jid`:
- If it is already a phone JID (`...@s.whatsapp.net`), that is the identity.
- If it is an `@lid` (only on the messages.db path), resolve it to a phone JID
  BEFORE anything else. Precedence (verified): `app.db.contacts.lid` (most
  complete) -> `app.db.chats.lid_jid` -> `messages.db.contacts` phone. If it
  resolves to NOTHING, **skip it and log a gap. NEVER slug a profile from a raw
  `@lid`.** Merge recipe: `references/sql-cookbook.md`.
- Re-apply the skip registry on the RESOLVED phone (the first recent `@lid` in
  the store is often Toper-self).

The phone JID is the dedup key. Derive the human name from `contacts.name` /
`notify` / `push_name` / `chats.name`, but the FILE IDENTITY is the phone. If a
`whatsapp_style_*.md` already covers this phone (check existing files and their
frontmatter `entities`/`aliases`/JID), **UPDATE that file. Never mint a second
push-name-keyed file for a person who already has one** (the vella -> cece
duplicate).

### Step C: Fetch their messages

Pull that person's last ~50 qualifying messages (`from_me=0`, text types,
non-empty), newest first. See the per-contact fetch in the cookbook. Analyze only
THEIR messages. Christopher's messages (`from_me=1`) are context at most, never
part of the style extraction.

### Step D: Extract style (rubric, anti-generic)

Fill the 9 style dimensions using the **extraction rubric**: each dimension must
be backed by **>= 2 observed instances** or be written literally as "insufficient
data". List the ACTUAL tokens observed (their real slang, their real emoji, their
real catchphrases), never vague category words. "Casual and friendly" with no
tokens is a FAIL. Full rubric + the 9 dimensions + a filled worked example:
`references/style-schema.md`.

The 9 dimensions: Language, Message length & structure, Tone, Slang &
abbreviations, Emoji & reactions, Common phrases, Punctuation, Response patterns,
Topics.

### Step E: Write or MERGE the profile

Write `~/.claude/memory/whatsapp_style_<slug>.md` with the exact memory
frontmatter (section 6 + `references/style-schema.md`). If the file exists,
**MERGE**: keep still-true observations, add new ones, append a dated "Recent
observations" note, bump `updated`. Never blow away prior hard-won notes.

Every quoted example message passes the **REDACTION GATE** first (section 6). If
an otherwise-perfect example trips the filter, paraphrase the style instead of
quoting.

### Step F: Indexing (frontmatter only)

Do NOT touch `MEMORY.md` or `indexes/`. A new `whatsapp_style_*.md` with
`namespace: contact` is auto-filed into `indexes/contact.md` by the memory
PostToolUse hook, which debounce-runs `gen-memory-index.py`. Optionally, at the
very end, you MAY verify indexing with the write-nothing check:
```bash
python3 "$HOME/.claude/scripts/gen-memory-index.py" --check   # asserts, writes nothing
```
Do not run it argless from here (that regenerates live index files as a side
effect; leave that to the hook).

### Step G: Clean up + report

`rm -rf "$WORK"` the snapshot dir. Print the RUN LEDGER (section 9).

---

## 5. HARD RULES (NEVER / ALWAYS, with triggers)

1. **NEVER** call `mcp__plugin_whatsapp_whatsapp__*`. **ALWAYS** read SQLite. If a
   WhatsApp tool "is not found", that is EXPECTED (headless), not an error to
   recover from.
2. **ALWAYS** access every DB read-only (snapshot copy, or `file:...?mode=ro`
   with a busy-timeout). **NEVER** open `app.db` or `messages.db` read-write.
3. **ALWAYS** run the freshness gate and pick the source from the decision table
   before profiling. **NEVER** profile a stale window silently; emit the WARN.
4. **ALWAYS** treat `app.db` as PRIMARY when fresh (phone-JID keyed = matches
   slugs). Use `messages.db` ONLY as a caveated fallback, and ONLY with an
   explicit `@lid`->phone merge. **NEVER** slug a profile from a raw `@lid`.
5. **NEVER** create a profile for a skip-registry JID (section 7): Toper-self
   (phone `$TOPER_WA_PHONE` AND lid `$TOPER_WA_LID`), system/AI noise
   `628XXXXXXXXXX`, `status@broadcast`, any `%@g.us` group. 1:1 humans only.
6. **ALWAYS** dedup by phone JID. If a phone already has a `whatsapp_style_` file,
   UPDATE it. **NEVER** mint a new push-name-keyed profile duplicating an existing
   person.
7. **ALWAYS** analyze only their messages (`from_me=0`, text types, non-empty).
   **NEVER** fold Christopher's own messages into the style analysis.
8. **NEVER** write a profile from `< 5` of their qualifying messages. Mark
   thin-data, skip the file, report it as a gap.
9. **ALWAYS** MERGE an existing profile (keep + add + bump `updated`). **NEVER**
   overwrite prior notes.
10. **ALWAYS** write memory frontmatter with `namespace: contact` (+ the full key
    set, section 6). **NEVER** use `type: reference` (it mis-routes the auto-index).
11. **NEVER** hand-edit `MEMORY.md` or `memory/indexes/*`. Frontmatter is the only
    lever; the generator owns the indexes.
12. **REDACTION GATE, HARD:** before quoting any message, strip or refuse OTP /
    verification codes, password-labelled strings, long digit runs
    (account / card / NIK), full street addresses, and token-bearing URLs, plus
    raw phone numbers. Trip the filter -> paraphrase, do not quote.
13. **NEVER** use an em-dash or en-dash. Commas, parentheses, periods only.

---

## 6. ENFORCEMENT SYSTEMS

### 6.1 Output frontmatter schema (the exact keys)

Every profile MUST open with this block (worked example in
`references/style-schema.md`):
```yaml
---
name: whatsapp_style_<slug>          # = filename stem
title: <Human Name>                  # display title
namespace: contact                   # REQUIRED. routes into indexes/contact.md. never `type: reference`
tier: 1
description: <=150 chars, dense, names the ONE signature trait   # becomes the index line
tags: [whatsapp, style, <slug>, <relationship>]
entities: [<Name>, Christopher, <phone JID or key nouns>]
aliases: [whatsapp-style-<slug>, <nicknames they use / go by>]
trigger_keywords: [<their real catchphrases + slang tokens>]
hypothetical_questions:
- How do I reply to <Name> in their style?
created: <YYYY-MM-DD>                 # preserve on update
updated: <YYYY-MM-DD>                 # = today on every write
---
```
The memory validator (`memory-write-validate.sh`, a fail-open PostToolUse hook)
requires `name` + `description` + (`namespace` OR `type`). `type: reference`
would technically pass that check, but the auto-indexer groups by `namespace` and
shards `contact` into `indexes/contact.md`, so `namespace: contact` is
mandatory for the file to be found. The `description` is anti-generic: write it
like the real ones ("'peng' suffix on every message, chill brotherly register" /
"third-person 'ado' self-ref, heavy phonetic spelling"), never "communication
style profile for X".

### 6.2 Redaction filter (run against every candidate quote)

Refuse the quote (paraphrase instead) if it matches any of:
- OTP / verification code context: "kode" / "OTP" / "verifikasi" near a 4-8 digit run.
- Password / credential context: "pw", "password", "sandi", "kata sandi", "pin".
- Long digit run `>= 10 digits` (bank rekening, card, NIK/KTP 16-digit).
- Full street address: "Jl", "jalan", "RT", "RW", "kelurahan", "blok".
- Token-bearing URL: `?token=`, `?otp=`, reset/magic links, shortened login links.
- Raw phone number (`62...` / `08...`). The validator also flags these as PII.

This mirrors the validator's own secret/PII patterns (sk-ant-, ghp_, AKIA, AIza,
xox, PEM, literal `password=`, Indonesian phones). Belt and suspenders: the
validator is fail-open and cannot block, so YOU are the real gate.

### 6.3 Self-verify checklist (ALL must pass before "done")

- [ ] VERDICT line emitted (source + appMax + msgMax + wa_alive + window).
- [ ] Only `from_me=0` messages were analyzed.
- [ ] Skip registry applied (self phone+lid, noise, broadcast, groups).
- [ ] Every written profile has `>= 5` backing messages, `>= 2` instances per
      non-"insufficient data" dimension, and named real tokens (no vague slop).
- [ ] Dedup-by-phone honored; no new duplicate of an existing person.
- [ ] Every quoted example passed the redaction filter.
- [ ] Frontmatter present, `namespace: contact`, `description <= 150` chars,
      `updated` = today; re-read each file to confirm.
- [ ] No `MEMORY.md` / `indexes/` hand-edit.
- [ ] RUN LEDGER printed: created / updated / left-untouched / gaps.
- [ ] Snapshot `$WORK` removed.

---

## 7. SKIP REGISTRY (never profile these)

| JID pattern | Who / what | Why skip |
|---|---|---|
| `$TOPER_WA_JID` | Toper-self (phone) | We reply AS him, never mirror him |
| `$TOPER_WA_LID` | Toper-self (lid) | Same person, LID form |
| `628XXXXXXXXXX@s.whatsapp.net` | System / AI noise ("Chill Claude") | Not a human contact (6000+ noise msgs) |
| `status@broadcast` | Status broadcast | Not a 1:1 chat |
| `%@g.us` | Any group | 1:1 only |

Apply as a SQL predicate on the raw `chat_jid` AND again on any `@lid` after it
resolves to a phone. The reusable predicate is in `references/sql-cookbook.md`.

---

## 8. QUICK FAILURE TABLE (full playbook: references/failure-playbook.md)

| Symptom | Fast diagnosis | Recovery (one line) |
|---|---|---|
| WhatsApp MCP tools "not found" | Headless `-p` run, no plugin | EXPECTED. Proceed via sqlite3, do not reconnect. |
| app.db window is empty / days old | `wa` TUI dead, `wa.pid` stale | Decision table already switched you to messages.db or anchored on appMax; emit the WARN. |
| DB locked / busy | Live WAL writer | You are on a snapshot copy, so this should not happen; if it does, re-copy, never open rw. |
| Schema drift (missing column) | `pragma_table_info` differs | Degrade (skip that dimension), note it, do not abort. |
| Contact has only media / < 5 texts | thin-data | Skip the file, log a gap, never fabricate. |
| messages.db shows 2 msgs, app.db thousands | LID split | Prefer app.db; on the fallback path do the `@lid`->phone merge first. |
| Service `failed`, log says "session limit" | Runner ate the Anthropic quota | Runner-level (outside this skill). `Persistent=true` re-fires; see playbook + the "poke main" redesign. |
| Main's WhatsApp drops after the run | A 2nd Baileys daemon spawned | Staying SQLite-only prevents it; kill the cron run's daemon, never main's / wa-sender. See playbook. |

---

## 9. RUN LEDGER (print at end, captured in /tmp/wa-behavior-learn.log)

Print a compact, dated block to stdout so the next run and Toper can see churn:
```
=== wa-behavior-learn RUN <YYYY-MM-DD HH:MM WIB> ===
VERDICT: source=<db> appMax=<ts> msgMax=<ts> wa_alive=<0|1> window_from=<date> note=<...>
CREATED:   whatsapp_style_<slug> (<n> msgs), ...
UPDATED:   whatsapp_style_<slug> (<n> new msgs), ...
UNTOUCHED: <slug> (no new data since <date>), ...
GAPS:      <name/jid> (<n> msgs, thin) | <@lid> (unresolvable) | ...
CHECKS:    from_me=0 only [ok] | skip-registry [ok] | redaction [ok] | frontmatter [ok] | no-index-edit [ok]
```
The service appends stdout to `/tmp/wa-behavior-learn.log`; that log IS the run
report. Do not write a separate ledger file, and do not auto-append to
`journal.md`.

---

## References (load on demand, progressive disclosure)

- **`references/sql-cookbook.md`**, load when you need the exact READ-ONLY SQL:
  both schemas (verified), the skip predicate, freshness queries, the active-set
  query, per-contact fetch, the `@lid`->phone merge, snapshot commands.
- **`references/style-schema.md`**, load when writing a profile: the full
  frontmatter schema, the 9-dimension body template, the extraction rubric with
  minimum-evidence counts, and a filled before/after worked example.
- **`references/failure-playbook.md`**, load when anything is off: every failure
  mode with exact diagnostic + recovery commands, the systemd/runner fragility,
  and the "poke the main session" redesign followup (outside this skill dir).
- **`references/tiers-and-boundaries.md`**, load for the tier taxonomy
  (family / close-friend / coworker / vendor), how tier gates whether auto-reply
  even applies, and the `whatsapp_style_` vs `contact_` cross-link convention.
