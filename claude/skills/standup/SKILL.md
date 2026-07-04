---
name: standup
description: Generate and send Christopher's structured twice-daily standup ritual as a WhatsApp DM to Toper, morning (yesterday-closed, today-commitments, pending decisions + a real 1h auto-default) or evening (shipped, blocked, tomorrow-first-thing, open-thread count). On-demand counterpart to the scheduled /daily-brief. Use when the user says /standup, "do the standup", "send standup", or when main borrows the standup body.
argument-hint: morning|evening [--dry-run] [--force]
allowed-tools: Read, Glob, Grep, Bash, CronCreate, CronList, CronDelete, mcp__plugin_whatsapp_whatsapp__check_number, mcp__plugin_whatsapp_whatsapp__list_chats, mcp__plugin_whatsapp_whatsapp__get_chat_info, mcp__plugin_whatsapp_whatsapp__send_message
---

# /standup, the twice-daily accountability ritual (on demand)

One-shot skill. Compresses a day's state into a scannable WhatsApp DM (Toper reads it in 30 seconds), arms the 1h decision default when the morning has open decisions, then exits. This is the **ritual** half of the standup system (`feedback_daily_standup` + `~/claude/templates/standup-template.md`). It is sourced from the same truth-files as `/daily-brief` but differs in **shape, transport, and trigger**, see "How this differs from /daily-brief", they are NOT duplicates.

**Recipient JID (send here):** `$TOPER_WA_JID` (Toper SUPERUSER, phone-format). standup delivers over the **live WhatsApp MCP** (`send_message`, needs main's WA connection, so main-session-only, Step 1a). `/daily-brief` now sends to this SAME phone JID but **connection-free via the wa-sender queue**, its rewrite converged both rituals onto one surface, so the recipient is no longer the differentiator (transport + trigger + shape are, see the table). The old `$TOPER_WA_LID` is daily-brief's LEGACY MCP target (same person, `feedback_whatsapp_lid_vs_phone_jid`), not a live divergence. Verify the JID fresh via `list_chats` before every send, never hand-type or fuzzy-match it (`feedback_whatsapp_no_random_messaging`).
**Timezone:** `Asia/Jakarta` (WIB, UTC+7). Do ALL time math in WIB. The host clock IS WIB (verified `date +%Z` returns WIB / +0700), so `date` fields feed cron directly with no conversion.

---

## How this differs from /daily-brief (read first, this is why this skill exists)

`/daily-brief` and `/standup` are **complementary, not redundant.** Do not collapse one into the other.

| Axis | `/daily-brief` | `/standup` (this skill) |
|---|---|---|
| Trigger | Scheduled: systemd timers 06:00 + 21:00 WIB | On demand: Toper or main invokes it |
| Shape | Calendar-forward: TODAY events, NEXT-7-DAYS highlights, tasks-due, open threads | Accountability-forward: yesterday-closed, today-commitments, **pending decisions + a real 1h auto-default**, blockers, tomorrow-first-thing |
| Transport | Connection-free: appends to the wa-sender queue (`events.jsonl`), no WhatsApp socket, headless-safe | Live WhatsApp MCP `send_message`, needs main's WA connection (main-session-only) |
| Recipient | `$TOPER_WA_JID` (via wa-sender; `@lid` is its LEGACY MCP target) | `$TOPER_WA_JID` (via MCP), the SAME surface now |
| Unique content | 7-day calendar highlights, OAuth bootstrap | the `❓ nunggu lu mutusin` + `⏰ default in 1h` decision block that ACTUALLY arms a timer (absent from daily-brief) |
| Bullet char | `• ` (Unicode bullet) | `- ` (ASCII hyphen), the one deliberate glyph difference |
| Source-of-truth | `~/.claude/tasks/*.md` + Google Calendar + `~/claude/state/work-queue.md` | `~/claude/state/work-queue.md` + `~/.claude/tasks/*.md` + `~/claude/state/decisions.log` + recent worker `report.md`/`result.json` |

**Bright line:** daily-brief answers *"what is on my plate + my calendar"*; standup answers *"what got done, what I am committing to, and what I need you to decide."* The decision-deadline block (`feedback_decision_deadline_1h`) is the standup's reason to exist and is absent from daily-brief.

## Sibling boundaries (which ritual skill to invoke)

| Skill | Cadence | Audience + register | Job |
|---|---|---|---|
| `/standup` (this) | Twice daily, on demand | Toper, casual Bahasa, phone JID | Daily internal state snapshot + the 1h decision default |
| `/daily-brief` | Scheduled 06:00/21:00 | Toper, casual Bahasa, phone JID via wa-sender queue | Calendar-forward brief (may borrow standup's body via `--dry-run`) |
| `/retro` | Weekly Sunday | Toper, casual Bahasa, phone JID | Cumulative: ONE bottleneck, ONE change, did-last-week-stick |
| `/status-report` | Weekly, per project | Client, professional English | Client-facing project progress report |

If the ask is "map what got done + decide" today, that is standup. If it is "one bottleneck, one change for the week", that is retro. If it is "client update", that is status-report.

## Delegation seam (the daily-brief composition contract)

`/standup` is delegation-READY: with `--dry-run` it runs the full pipeline and prints the formatted body between `=== DRY RUN START ===` / `=== DRY RUN END ===` WITHOUT touching WhatsApp and WITHOUT arming the wake, so a caller can borrow the exact body and send it on its own transport.

**`/daily-brief` IS the documented consumer** (verified: daily-brief/SKILL.md carries a "Composition with /standup, the contract to preserve" section). The sanctioned handoff, so daily-brief never re-implements standup's decision-deadline logic:

1. daily-brief runs `/standup {mode} --dry-run`.
2. It captures the text between the two banners.
3. **daily-brief OWNS the send**, it enqueues that body on its own wa-sender path. `/standup` NEVER touches WhatsApp in this path (dry-run prints only, arms nothing).
4. **NEVER also fire a standup standalone SEND in the same window**, that is the double-send both skills forbid. One message, from daily-brief.

daily-brief still renders its OWN calendar-forward brief by default and only folds in the accountability body when it wants the decision block, so the two are complementary, not duplicated. This is the contract the steer says to preserve: keep the `--dry-run` seam intact and side-effect-free (no send, no arm) so daily-brief can rely on it.

---

## Step 0, parse arguments

`$ARGUMENTS` is `morning`, `evening`, optionally with `--dry-run` and/or `--force`.

- `mode` = first token (`morning` | `evening`). If missing or unrecognized, print `usage: /standup morning|evening [--dry-run] [--force]` and **exit 1**. Never guess the mode.
- `dry_run` = true if `--dry-run` appears anywhere, OR env `STANDUP_DRY_RUN=1`.
- `force` = true if `--force` appears anywhere (overrides the skip-guard, see Step 1).

In dry-run: run the full pipeline EXCEPT the WhatsApp send AND the 1h arm; print the final body between `=== DRY RUN START ===` / `=== DRY RUN END ===`.

## Step 1, anchor the clock + skip-guard + worker-send guardrail (HARD RULES)

Anchor to the real WIB clock, never hand-calculate:

```bash
date '+now: %Y-%m-%d %H:%M %Z (epoch %s, dow %u)'   # dow: 1=Mon .. 7=Sun
TZ=Asia/Jakarta date +"%Y-%m-%d"                      # today (WIB)
TZ=Asia/Jakarta date -d "yesterday" +"%Y-%m-%d"      # yesterday (WIB)
```

### 1a. Worker-send guardrail (HARD RULE, `feedback_whatsapp_single_session_rule`)

**SEND only from a context that legitimately owns WhatsApp: the main command-center session (launched with `WHATSAPP=1`).** A spawned worker that sends WA spawns a second Baileys daemon and drops main's connection (verified incident 2026-06-15, main's WA dropped ~5x in 20min). So:

```bash
[ "${WHATSAPP:-}" = "1" ] || echo "not main: forcing dry-run (worker/non-main context)"
```

- If `WHATSAPP` is not `1` (worker or any non-main session), **force `dry_run=true`**, print the body, and end with `HANDOFF, give this body to main to send`. Never call `send_message` from a worker.
- The daily-brief path borrows the body via `--dry-run` (it owns its own connection-free enqueue), so standup's own live-MCP SEND never needs to run outside main. If you truly are a legitimate non-main sender, that is a Toper-level exception, not a default.

### 1b. Skip-if-just-messaged guard (HARD RULE, dual-JID aware)

Per `feedback_daily_standup`: do NOT send a standup if Toper messaged main in the last ~60 min, it is redundant noise and erodes the ritual. Check the cheapest signal first:

1. If invoked from main with a recent inbound `<channel source="...whatsapp...">` from Toper in the current session context, SKIP.
2. Else read the most recent Toper inbound timestamp via `mcp__plugin_whatsapp_whatsapp__list_chats` and compare to now-60min. **Check BOTH of Toper's JID formats** (`$TOPER_WA_JID` AND `$TOPER_WA_LID`), a hit on either means he is present (`feedback_whatsapp_lid_vs_phone_jid`). **NEVER** match on WA display name (his profile name may not read "Toper").
3. If you cannot determine recency across either JID, **do not skip** (send). A missed standup is worse than a redundant one only when Toper is definitely present; when unknown, send.

When skipping: print `SKIP, Toper messaged within the last hour, standup suppressed` and **exit 0** without sending. Skip is silent to Toper (no "I am skipping" message). **On a morning skip with pending decisions:** the decisions do NOT vanish, note them in the session output so main raises them live or they carry to the next slot.

> **Override:** an explicit `/standup` invocation by Toper, or `--force`, never skips. Treat either as "send regardless".

## Step 2, gather the source data (read-only, degrade gracefully)

Read the truth-files. Be defensive: any missing file degrades to empty, never crashes. As each bullet is built, run it through the **Secret/PII scrub** (Step 3.5) before it enters the body.

**A. Work queue + staleness gate**, `~/claude/state/work-queue.md` (the canonical kanban). Parse the markdown tables. NOTE: in the LIVE file the `## Paused ...` section headers use a long-dash separator (daily-brief quotes them verbatim, same source, do not drift); the comma form shown below is kept dash-clean for THIS skill, so match each section on its stable words (`In-flight`, `Paused` + `awaiting Toper decision`, `Paused` + `awaiting external`, `Recently shipped`), NEVER on the punctuation, so the parse still hits the real header:
- `## In-flight (worker actively running)` to in-flight workers (`Name`, `State`).
- `## Paused, awaiting Toper decision` to pending decisions (`Name`, `What's needed`), these are the open decisions surfaced in `❓`.
- `## Paused, awaiting external ...` to external blocks (`Name`, `What's blocking`).
- `## Recently shipped` to candidate closed/shipped rows for the window.

Skip header + separator rows; skip rows whose first cell is `_(none)_`, empty, or `~~strikethrough~~`-only. Truncate cell values to ~60 chars with `...`. `open_threads_n` = in-flight + paused-decision + paused-external counts. Missing file, all empty, `open_threads_n=0`, continue.

**STALENESS GATE (do not assert emptiness as truth on a stale file):**
```bash
WQ=~/claude/state/work-queue.md
date -r "$WQ" '+%Y-%m-%d'                              # last-modified date
find "$WQ" -mtime +"${WQ_STALE_DAYS:-3}" -print        # nonempty output = STALE
```
If STALE (mtime older than `WQ_STALE_DAYS`, default 3): do NOT present `_(none)_` as "nothing happening". Phrase gaps as `(work-queue stale sejak <date>, mungkin gak lengkap)` and CROSS-CHECK `~/claude/notes/*/result.json` modified within the window (source D) as a second source before concluding a list is empty.

**B. Tasks**, Glob `~/.claude/tasks/*.md` (exclude `INDEX.md`, `archive/`). For each, read frontmatter `project:` (fallback filename) + parse `## NOW`/`## NEXT`/`## WAITING`/`## Completed`. Task line: `- [ ] desc ... \`YYYY-MM-DD\``.
- Morning `today_commitments` = open `[ ]` under `## NOW` (cap 3, prefer dated-today then highest-tier).
- Morning `yesterday_closed` = items in `## Completed` with a yesterday date, OR `## Recently shipped` work-queue rows dated yesterday (cap 3).
- Evening `shipped_today` = `## Completed`/recently-shipped rows dated today.

**C. Decisions log**, `~/claude/state/decisions.log` (append-only, header `ISO timestamp | decision-key | default-taken | reason | overridden? (y/n + when)`). Used to (a) avoid re-surfacing a decision already defaulted/resolved, and (b) match the append format for the 1h default. The **pending decisions themselves come from work-queue** `## Paused, awaiting Toper decision`; decisions.log is the RESOLVED audit trail.

**D. Recent worker outcomes**, scan `~/claude/notes/*/report.md` and `~/claude/notes/*/result.json` modified within the window (yesterday to now for morning, today for evening) for shipped/blocked signal. `result.json` is the machine-readable source (schema `{task_slug, status(done|blocked|partial), summary, deliverables[], evidence[], blockers[], followups[], staged_for_human[]}`), prefer it. Validate when unsure, **flag-first**:
```bash
~/.claude/scripts/result-schema.sh --validate ~/claude/notes/<task-dir>    # dir resolves to dir/result.json; exit 0 ok / 1 invalid / 2 usage
```
On exit 1 (invalid), fall back to that task's `report.md` prose or skip the row, never fabricate. Map `status:done` to shipped; `status:blocked`/`partial` with `blockers[]` to blocked. Cap each list at the template max.

**E. wake-priority consult (morning only, READ-ONLY, fail-open).** Consult the loop's priority model to enrich the "hari ini" / first-thing line, NEVER `--consume`:
```bash
~/.claude/scripts/wake-priority.sh --json     # exit 0=P2 idle, 1=P1 handle-next, 2=P0 act-now
```
Path is `~/.claude/scripts/` (NOT `~/claude/scripts/`, CLAUDE.md misstates it; the executable lives at `~/.claude/scripts/wake-priority.sh`). It emits `{priority, tier_exit, reason, detail, cadence_*}`. If exit is 1/2 and `detail` names something concrete, you MAY add ONE soft line (e.g. surface the top pending priority in "hari ini"). On a WEEKDAY morning also allow one soft note that the paid-work window (Ryan/BMS ~08:00-11:00 WIB) is near. If the script is absent or errors, degrade SILENTLY (skip enrichment). Never let it override the honest task-derived commitments and never let it fabricate a bullet.

## Step 3, format the message (EXACT templates, 1h, dash-clean)

SKILL.md is the AUTHORITATIVE rendering spec. `~/claude/templates/standup-template.md` is origin/voice only and is **STALE** (it still says `4h` and contains em dashes); follow THIS file, not the template's literals. WhatsApp formatting: `*bold*`, bullets are `- ` (ASCII hyphen, NOT `•`), preserve blank lines, no `#` headers.

### Morning (run ~7am WIB)

```
🌅 standup pagi {YYYY-MM-DD}

✅ kemaren closed:
- {bullet 1}
- {bullet 2}
- {bullet 3}

🎯 hari ini:
- {commitment 1}
- {commitment 2}

❓ nunggu lu mutusin:
- {Q1: short context + options or default}
- {Q2: ...}

⏰ kalo gak balas dalam 1h, gw default:
- {Q1: default X}
- {Q2: default Y}
(logged ke ~/claude/state/decisions.log)
```

- `kemaren closed` <= 3 bullets. If nothing closed, write `- (gak ada yang closed kemaren)`, be honest, do not pad (`feedback_no_yesman_sugarcoat`).
- `hari ini` 1 to 3 commitments.
- If there are **no** pending decisions, DROP both the `❓` and `⏰` blocks entirely.
- The `⏰` block lists ONLY the auto-defaultable decisions (see Step 3.5 classification). BLOCKING carve-outs appear in `❓` phrased `- {Q}: BLOCKING, butuh konfirmasi lu (no auto-default)` and are NOT in `⏰`.
- The deadline is **1h** and it is REAL: Step 4 arms it. Never print the `⏰` line without arming (or without the `butuh jawaban lu` fallback if arming is impossible).

### Evening (run ~7pm WIB)

```
🌙 standup malem {YYYY-MM-DD}

✅ shipped hari ini:
- {bullet 1}
- {bullet 2}

🚧 stuck / blocked:
- {name}: {blocker reason}

🌅 besok pagi pertama:
- {one concrete thing}

📋 open threads: {open_threads_n} total (lihat ~/claude/state/work-queue.md)
```

- If nothing shipped, say so honestly (`- (gak ada yang shipped hari ini)`), do not fabricate.
- If nothing blocked, DROP the `🚧` block.
- Blocker separator is `:` or `,`, NEVER a spaced em dash (no em/en dash anywhere).
- `besok pagi pertama` = exactly ONE concrete thing (top `## NOW` task or the most urgent paused-decision).
- ALWAYS keep the `📋 open threads` line even at 0 (it is the link to truth-source).

## Step 3.5, HARD RULES (the gates the skill exists to enforce)

### Emoji whitelist gate
The structural set is EXACTLY `{🌅 🌙 ✅ 🎯 ❓ ⏰ 🚧 📋}`, Toper-greenlit LABELS for standup format only (`standup-template.md` + `feedback_daily_standup`). Any OTHER emoji anywhere in the body = REJECT and rewrite. These are separate from the conversational allowlist `🤣🙏😭🥲😁`, which is BANNED in standup body text.

### Voice + no-dash gate (`feedback_bahasa_natural`, `feedback_no_long_hyphens` PRIME rule)
- Casual Bahasa Indonesia, real-friend register. Short sentences. No corporate-speak, no eager phrasing.
- **No em/en dash anywhere.** Use a comma or colon. The `-` in `- {bullet}` is a list marker (fine); the ASCII hyphen in compound words (`e2e`, `real-time`, `co-id`) is fine; the em dash (U+2014) and en dash (U+2013) are BANNED.
- **Blocking self-check on the rendered body before send:**
  ```bash
  printf '%s' "$BODY" | grep -nP '[\x{2014}\x{2013}]'    # MUST print nothing
  ```
  Any match, rewrite that line with a comma/colon, re-run, only send at zero.

### Secret/PII scrub gate (never forward a secret into a third-party channel)
Before a bullet enters the body, screen it. Block + redact any substring matching:
- JWT: `eyJ[A-Za-z0-9_-]{10,}`
- long random hex/base64 run (>= 24 chars): `[0-9a-fA-F]{32,}` or `[A-Za-z0-9+/]{24,}={0,2}`
- assignment prefixes: `(?i)(api[_-]?key|token|password|passwd|secret|bearer)\s*[:=]\s*\S+`
- customer PII from work-queue / result.json rows: emails `[\w.+-]+@[\w-]+\.[A-Za-z]{2,}` and phone numbers.

On a hit: OMIT the offending substring (replace with a redacted note like `[token redacted]` or `customer (email omitted)`) and note only the pattern TYPE, never the value. A hit blocks that BULLET, never the whole standup. The standup is a status snapshot, not a data export, so anonymize customer identifiers by default. (Known live example: `~/claude/state/work-queue.md` "Recently shipped" carries a customer email in a shipped row, it must never reach the body.) Blocking pre-send self-check on the rendered body:
```bash
printf '%s' "$BODY" | grep -nEi 'eyJ[A-Za-z0-9_-]{10,}|[0-9a-fA-F]{32,}|(api[_-]?key|token|secret|password|bearer)[[:space:]]*[:=]|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}'
# MUST print nothing before send
```

### Anti-slop ban-list gate (`feedback_no_yesman_sugarcoat`)
REJECT + rewrite any bullet that is generic filler. Banned tokens/shapes: `making progress`, `various tasks`, `several things`, `stuff`, `misc`, `working on it`, `progress on X` with no artifact, and adjective-only bullets. **Every closed/shipped bullet MUST name a concrete artifact: a task name, a commit SHA, a ticket ID, or a count.** A bullet that names nothing FAILS. Honesty over padding: if nothing closed/shipped, write the honest empty line, do NOT invent rows.

### Decision-classification gate (feeds `❓`, `⏰`, and Step 4)
Classify EACH pending decision before rendering:
- **Auto-defaultable** (low-stakes, easiest-to-reverse): which worker to spawn next, naming, formatting, scope calls WITHIN an already-approved task. Gets a conservative default line in `⏰` AND is armed in Step 4.
- **BLOCKING** (`feedback_decision_deadline_1h` hard exceptions): money / invoices / payments, push-to-prod / deploy-to-client, anything destructive (delete, force-push, drop, kill prod), anything touching an external relationship (client email, contract, third-party commitment). Gets NO default line; phrased `- {Q}: BLOCKING, butuh konfirmasi lu (no auto-default)`; **EXCLUDED from the Step 4 wake.** Never auto-default a BLOCKING decision, wait for Toper.

## Step 4, arm the 1h decision default (morning + real-send only, carve-out-aware)

This is the skill's core value: the `⏰` line is a PROMISE and this step makes it fire. `feedback_time_promise_scheduling` is explicit, main is reactive with NO internal clock, "I will check the clock in an hour" ALWAYS slips silently. So a printed `⏰` line without an armed timer is vaporware, do not ship it.

**Arm ONLY when ALL hold:** `mode == morning` AND NOT dry-run AND NOT worker-context AND the auto-defaultable decision set is non-empty. Otherwise skip this step (no wake).

**Mechanism (verified in this harness).** `CronCreate` is the only scheduler present (5-field cron `M H DoM Mon DoW` in host-local time); its `durable` flag is a documented no-op (jobs are session-only), which is FINE for a 1h same-session horizon. Compute the now+1h fire time from the host clock (host IS WIB, so no conversion) and pin a one-shot:

```bash
FIELDS=$(date -d '+1 hour' '+%-M %-H %-d %-m')   # e.g. "23 10 3 7" -> cron "23 10 3 7 *"
```
Use the `%-` (no-pad) form, NOT `%M %H %d %m`: zero-padded single-digit fields (`08`, `09`) can misparse as invalid octal in a cron parser. Verified: GNU `date` supports `%-` padding-suppression on this host.
Before arming, `CronList` and check for an existing `[STANDUP-1H-DEFAULT id=<today>]` job; if present, do NOT double-arm. Otherwise:

```
CronCreate(
  cron="<M> <H> <DoM> <Mon> *",   # the four FIELDS above + " *"
  recurring=false,                # one-shot, auto-deletes after it fires
  prompt="[STANDUP-1H-DEFAULT id=<YYYY-MM-DD>] 1h decision deadline reached for today's morning standup. Pending auto-defaultable decisions + their conservative defaults: <embed each decision-key + default verbatim>. FIRST re-read ~/claude/state/decisions.log AND recent WA inbound across BOTH Toper JIDs ($TOPER_WA_JID and $TOPER_WA_LID) to see if Toper already answered any key. For EACH key still unresolved: append one line to ~/claude/state/decisions.log in the format '<ISO ts> | <decision-key> | default-taken: <X> | reason: 1h standup deadline, no reply | overridden: n' and proceed on the default. For any key Toper answered: honor his answer and append an 'overridden: y' line instead. Then send ONE short WA line to $TOPER_WA_JID summarizing what was defaulted (verify the JID via list_chats first). Idempotent: if a key is already resolved in decisions.log, skip it. This covers ONLY the listed keys, never a money/prod/destructive/external decision.")
```

Verify it armed: `CronList` should show the job. Print `wake armed: <id>, fires ~<HH:MM WIB>`. The self-contained prompt embeds the exact keys + defaults so the fired run needs no re-derivation, and the decisions.log + WA re-check makes it safe if Toper answered in the meantime.

**Caveats (do not over-promise):**
- Session-only: the wake rides on main staying alive for the hour. If main restarts within the hour, the job is gone; the decision simply waits for Toper or re-surfaces at the next standup. Acceptable for a 1h low-stakes horizon; do NOT use this path for anything days out (that needs the Google Calendar MCP, out of scope here).
- Fires only while main's REPL is IDLE (per CronCreate: jobs fire when not mid-query). If main is mid-turn at the fire minute, it fires the moment main goes idle, plus a small deterministic scheduler jitter. Negligible for a 1h low-stakes default.
- If `CronCreate` is unavailable in your harness, do NOT print an unbacked `⏰` line. Phrase the decisions in `❓` as `butuh jawaban lu` with no auto-default and note main must track manually. Never hallucinate a scheduling flag.
- `ScheduleWakeup` is referenced by CLAUDE.md/`feedback_time_promise_scheduling` but is NOT present in this tool set. If a future harness exposes it you MAY use it (one-shot ~3600s), but feature-detect first; `CronCreate` one-shot above is the verified path.
- NEVER arm in dry-run, from a worker, or for a BLOCKING carve-out.

## Step 5, pre-send gate + send (or dry-run print)

**PRE-SEND GATE, ALL must pass or refuse and exit 1.** Print the gate result line before sending.

- [ ] `mode` in {morning, evening}.
- [ ] Recipient JID verified via `list_chats` / `get_chat_info` and equals `$TOPER_WA_JID` (standalone path). JID copied from the fresh `list_chats` response, NEVER typed from memory, NEVER a fuzzy name match (`feedback_whatsapp_no_random_messaging`).
- [ ] Body <= 20 lines AND <= ~1200 chars.
- [ ] em/en dash count == 0 (grep proof from Step 3.5).
- [ ] secret/PII pattern count == 0 (grep proof from Step 3.5).
- [ ] Only the 8 structural emojis present, zero conversational emoji.
- [ ] No fabricated/padded rows (every closed/shipped bullet names a task, SHA, ticket, or count).
- [ ] dry-run-vs-send path correct (worker context, forced dry-run).
- [ ] If (morning AND non-empty `⏰` block AND real-send): the 1h wake is armed (`CronList` shows the job) OR the `butuh jawaban lu` fallback is in use.

Then:
- **If dry-run:** print the body between `=== DRY RUN START ===` / `=== DRY RUN END ===`. Do NOT call WhatsApp, do NOT arm. (This is the seam a caller borrows.)
- **If not dry-run:** call `mcp__plugin_whatsapp_whatsapp__send_message` to `$TOPER_WA_JID` with the body. Param names vary (`jid`/`recipient`/`to`, `message`/`text`/`body`), inspect the schema at call-time. **Verify the return** (`feedback_verify_after_write`): on error, retry ONCE; if still failing, surface the failure and **exit 1**, do NOT write the log as sent, do NOT silently drop.

## Step 6, log

Append one line to `~/.local/share/standup/log/{mode}-{YYYY-MM-DD}.log` (create the dir if missing, it does not exist yet):

```
[YYYY-MM-DD HH:MM WIB] {mode} standup, closed={n} commit={n} pending_decisions={n} blocked={n} open_threads={n} armed={yes|no|n/a} sent={yes|no|dry-run|skipped}
```

## Worked examples

**Example A, `/standup morning`, Wed 2026-06-11 07:00 WIB, with an armed 1h wake.**
Sources: work-queue `## Recently shipped` has 2 rows dated yesterday (`pulse-receipt-i18n`, `signal-trader-ocr`); tasks `## NOW` has `fix CM 500 on Berkah`, `re-run suite 818`; work-queue `## Paused, awaiting Toper decision` has `fitest-batches-6-7` ("Go" to spawn batch 6), an auto-defaultable scope call. Body:
```
🌅 standup pagi 2026-06-11

✅ kemaren closed:
- pulse receipt i18n (4 commits, blm dipush)
- signal-trader OCR hardening (e6cd05a)

🎯 hari ini:
- fix CM 500 di Berkah+Pustaka
- re-run suite 818 abis fix Abdul

❓ nunggu lu mutusin:
- spawn batch 6 fitest? (User M-Banking 20pg, est 80min)

⏰ kalo gak balas dalam 1h, gw default:
- batch 6: gw spawn pake brief batch-5
(logged ke ~/claude/state/decisions.log)
```
Then Step 4 arms one-shot `CronCreate(cron="7 8 11 6 *", recurring=false, prompt="[STANDUP-1H-DEFAULT id=2026-06-11] ... batch 6 -> spawn via batch-5 brief ...")` (no-pad fields), prints `wake armed: <id>, fires ~08:00 WIB`. Gate passes (0 dashes, 0 secrets, 12 lines, JID verified, wake armed). Sent.

**Example B, `/standup evening`, Wed 2026-06-11 21:00 WIB, nothing blocked.** work-queue 3 open threads, shipped 1 thing today. Body:
```
🌙 standup malem 2026-06-11

✅ shipped hari ini:
- 3 fitest tickets difile (Berkah/Pustaka 500, SubPopup 422, Promo regression)

🌅 besok pagi pertama:
- nunggu Ryan re-run 818 + review tickets

📋 open threads: 3 total (lihat ~/claude/state/work-queue.md)
```
(No `🚧` block, nothing blocked. No `⏰`, evening never arms.)

**Example C, `/standup morning` but Toper messaged main 12 min ago.** Step 1b finds a Toper inbound (either JID) within 60min. Print `SKIP, Toper messaged within the last hour, standup suppressed`, exit 0, nothing sent, nothing armed. Note the one pending `fitest-batches-6-7` decision in session output so main raises it live (it does not vanish on a skip).

**Example D, `/standup morning` with a BLOCKING decision (no auto-default).** work-queue paused-decision is `pulse-prod-deploy-cogs-v2` ("toggle COGS_ALGO=v2 in prod?"), a push-to-prod carve-out. It renders in `❓` only, no `⏰` line, and is EXCLUDED from the wake:
```
❓ nunggu lu mutusin:
- toggle COGS_ALGO=v2 di prod?: BLOCKING, butuh konfirmasi lu (no auto-default)
```
If it were the ONLY pending decision, the `⏰` block is dropped entirely and Step 4 arms nothing.

## Failure-mode playbook (exact recovery)

| Failure | Recovery |
|---|---|
| WA `send_message` returns an error | Re-call ONCE. Still failing, print the failure + exit 1. Do NOT log as sent, do NOT drop silently (`feedback_verify_after_write`). |
| `list_chats` empty / recency undeterminable | Do NOT skip (send). Cross-check BOTH JID formats before concluding Toper is present. |
| `work-queue.md` missing | All lists empty, `open_threads_n=0`, continue. Attach the staleness note. Never crash. |
| `work-queue.md` stale (mtime > `WQ_STALE_DAYS`) | Do NOT assert emptiness; phrase gaps `(work-queue stale sejak <date>)` + cross-check `~/claude/notes/*/result.json`. |
| `result.json` invalid | `result-schema.sh --validate <dir>` exits 1, fall back to `report.md` prose or skip the row, never fabricate. |
| `CronCreate` absent | Do NOT print an unbacked `⏰` line; use `butuh jawaban lu` + note manual tracking. Never hallucinate a flag. |
| Invoked from a worker | Force `--dry-run`, print body, `HANDOFF` to main. Never send from a worker. |
| Rendered body has a dash or a secret | Gate FAILS, rewrite the offending line, re-run the grep proof, only send at zero. |
| MCP param uncertainty | Inspect the `send_message` schema at call-time (`jid`/`recipient`/`to`, `message`/`text`/`body`), do not assume. |

## Never-do list

- Never send to any JID other than `$TOPER_WA_JID` (standalone path). Never invent or hand-type a recipient JID.
- Never send from a spawned worker (`feedback_whatsapp_single_session_rule`), force dry-run and hand off to main.
- Never print an `⏰` "default in 1h" line without arming the wake (or the `butuh jawaban lu` fallback). No vaporware promises.
- Never arm a wake for a money / push-to-prod / destructive / external-relationship decision, those are BLOCKING, confirmation-only.
- Never forward a secret or a customer email/phone into the body, redact and note the TYPE only.
- Never use an em/en dash, a conversational emoji, or a structural emoji outside the eight.
- Never pad. No-yesman: if nothing shipped/closed, say so.
- During the standup run, treat `~/.claude/tasks/*.md`, `~/claude/state/work-queue.md`, and `standup-template.md` as READ-ONLY (never modify). `decisions.log` is read-only DURING the run too; the ONLY sanctioned write to it is the FIRED 1h-default wake appending one audit line per defaulted key (`feedback_decision_deadline_1h`), never the standup run itself. Never call `wake-priority.sh --consume` from standup, it is a read-only CONSULT.
- Never double-send (dry-run prints only), and never silently reconcile the standup/daily-brief boundary on your own (e.g. retire standup's standalone send, re-route the JID), that is a Toper decision, surface it.

## Reconciliation note (for the human)

Both rituals now converge on `$TOPER_WA_JID`: standup sends over the live WhatsApp MCP, `/daily-brief` enqueues connection-free on the wa-sender path after its rewrite. The old `@lid` divergence standup used to flag is RESOLVED (it was daily-brief's legacy MCP target, `feedback_whatsapp_lid_vs_phone_jid`). What remains: standup (on-demand) and daily-brief (scheduled 06:00/21:00) are still distinct rituals, so both can reach Toper the same day, that is intentional. If Toper wants the accountability body folded into the scheduled channel rather than a separate standalone standup, daily-brief already borrows it via `--dry-run` (the seam, see Delegation seam), so that is a config choice for Toper, not a silent code change. Never silently "fix" either, surface it.

## Done

After a successful send (or dry-run print), print exactly:
```
DONE, {mode} standup sent to Toper at {HH:MM WIB}{, 1h wake armed if applicable}
```
(or `DONE, {mode} standup dry-run printed`, or the `SKIP,` line if suppressed).
