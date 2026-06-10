---
name: standup
description: Generate and send Christopher's structured twice-daily standup ritual as a WhatsApp DM to Toper — morning (yesterday-closed → today-commitments → pending decisions + 1h defaults) or evening (shipped → blocked → tomorrow-first-thing → open-thread count). On-demand counterpart to the scheduled /daily-brief. Use when the user says /standup, "do the standup", "send standup", or daily-brief delegates the standup body.
argument-hint: morning|evening [--dry-run]
allowed-tools: Read, Glob, Grep, Bash, mcp__plugin_whatsapp_whatsapp__check_number, mcp__plugin_whatsapp_whatsapp__list_chats, mcp__plugin_whatsapp_whatsapp__send_message
---

# /standup — the twice-daily accountability ritual (on demand)

One-shot skill. Compresses a day's state into a <20-line WhatsApp DM that Toper scans in 30 seconds, then exits. This is the **ritual** half of the standup system (per `feedback_daily_standup` + `~/claude/templates/standup-template.md`). It is sourced from the same truth-files as `/daily-brief` but has a **different shape and a different recipient** — see "How this differs from /daily-brief" below; they are NOT duplicates.

**Recipient JID:** `62817712289@s.whatsapp.net` (Toper SUPERUSER — the standup-template + `feedback_daily_standup` target). This is **deliberately different** from `/daily-brief`'s `107838240207070@lid`; see Reconciliation note at the bottom — flag it to Toper if both fire, don't silently "fix" it.
**Timezone:** `Asia/Jakarta` (WIB = UTC+7). Do ALL time math in WIB.

---

## How this differs from /daily-brief (read first — this is why this skill exists)

`/daily-brief` and `/standup` are **complementary, not redundant.** Do not collapse one into the other.

| Axis | `/daily-brief` | `/standup` (this skill) |
|---|---|---|
| Trigger | **Scheduled** — systemd timers 06:00 + 21:00 WIB | **On demand** — Toper or main invokes it; or daily-brief delegates the body |
| Shape | Calendar-forward: TODAY events, NEXT-7-DAYS highlights, tasks-due, open threads | **Accountability-forward**: yesterday-closed, today-commitments, **pending decisions + 1h auto-defaults**, blockers, tomorrow-first-thing |
| Recipient | `107838240207070@lid` | `62817712289@s.whatsapp.net` |
| Unique content | 7-day calendar highlights; OAuth-prompt bootstrap | the `❓ nunggu lu mutusin` + `⏰ default in 1h` decision-deadline block (NOT in daily-brief); explicit yesterday-closed accountability |
| Source-of-truth | `~/.claude/tasks/*.md` + Google Calendar + `~/claude/state/work-queue.md` | `~/claude/state/work-queue.md` + `~/.claude/tasks/*.md` + `~/claude/state/decisions.log` + recent worker `report.md`/`result.json` |

**Bright line:** daily-brief answers *"what's on my plate + my calendar"*; standup answers *"what got done, what I'm committing to, and what I need you to decide."* The decision-deadline block (`feedback_decision_deadline_4h`, tightened to **1h**) is the standup's reason to exist and is absent from daily-brief.

**Composition:** `/daily-brief` MAY call this skill to render the standup body instead of duplicating the format. If it does, daily-brief owns the send (to its own JID) and passes `--dry-run` here to get the formatted text. When invoked standalone, `/standup` owns its own send to the standup JID. Never double-send: if `--dry-run` is set, this skill prints and never calls WhatsApp.

---

## Step 0 — parse arguments

`$ARGUMENTS` is `morning`, `evening`, `morning --dry-run`, or `evening --dry-run`.

- `mode` = first token (`morning` | `evening`). If missing/unrecognized → print usage `usage: /standup morning|evening [--dry-run]` and **exit 1**. Never guess the mode.
- `dry_run` = true if `--dry-run` appears anywhere, OR env `STANDUP_DRY_RUN=1`.

In dry-run: run the full pipeline EXCEPT the WhatsApp send; print the final body between `=== DRY RUN START ===` / `=== DRY RUN END ===`.

## Step 1 — anchor the clock + skip-if-just-messaged guard (HARD RULE)

Anchor to the real WIB clock — never hand-calculate:

```bash
date '+now: %Y-%m-%d %H:%M %Z (epoch %s, dow %u)'   # dow: 1=Mon … 7=Sun
TZ=Asia/Jakarta date +"%Y-%m-%d"                      # today (WIB)
TZ=Asia/Jakarta date -d "yesterday" +"%Y-%m-%d"      # yesterday (WIB)
```

**HARD RULE — skip if Toper is clearly watching.** Per `feedback_daily_standup`: do NOT send a standup if Toper messaged main in the last ~60 min — the standup is redundant noise and erodes the ritual's signal. Check, in order, the cheapest signal available:

1. If invoked from main with a recent inbound `<channel source="...whatsapp...">` from Toper in the current session context → SKIP.
2. Else read the most recent Toper inbound timestamp via `mcp__plugin_whatsapp_whatsapp__list_chats` (or a recent-messages read) and compare to now-60min.
3. If you cannot determine recency at all → **do not skip** (a missed standup is worse than a redundant one only when Toper is definitely present; when unknown, send).

When skipping, print `SKIP — Toper messaged within the last hour, standup suppressed` and **exit 0** without sending. Skip is silent to Toper (no "I'm skipping" message).

> **Override:** if Toper explicitly invoked `/standup` himself, never skip — an explicit request overrides the just-messaged guard. (`--force` also overrides: treat any `--force` token as "send regardless".)

## Step 2 — gather the source data

Read the truth-files. Be defensive — any missing file degrades gracefully, never crashes.

**A. Work queue** — `~/claude/state/work-queue.md` (the canonical kanban). Parse the markdown tables:
- `## In-flight (worker actively running)` → in-flight workers (`Name`, `State`).
- `## Paused — awaiting Toper decision` → pending decisions (`Name`, `What's needed`).
- `## Paused — awaiting external …` → external blocks (`Name`, `What's blocking`).
- `## Recently shipped` (if present) → candidate "closed/shipped" rows for the time window.
Skip header + separator rows, skip rows whose first cell is `_(none)_`/empty/`~~strikethrough~~`-only. Truncate cell values to ~60 chars with `…`. `open_threads_n` = in-flight + paused-decision + paused-external counts. Missing file → all empty, `open_threads_n=0`, continue.

**B. Tasks** — Glob `~/.claude/tasks/*.md` (exclude `INDEX.md`, `archive/`). For each, read frontmatter `project:` (fallback filename) + parse `## NOW`/`## NEXT`/`## WAITING`/`## Completed`. Task line: `- [ ] desc … \`YYYY-MM-DD\``.
- Morning `today_commitments` = open `[ ]` under `## NOW` (cap 3, prefer dated-today then highest-tier).
- Morning `yesterday_closed` = items moved to `## Completed` with a yesterday date, OR `## Recently shipped` work-queue rows dated yesterday (cap 3).
- Evening `shipped_today` = `## Completed`/recently-shipped rows dated today.

**C. Decisions log** — `~/claude/state/decisions.log` (append-only `TIMESTAMP | slug | … | overridden: y/n`). Used to (a) avoid re-surfacing a decision already defaulted, and (b) confirm the format of the morning default block. The **pending decisions** themselves come from work-queue `## Paused — awaiting Toper decision` (those are the open ones); decisions.log is the *resolved* audit trail.

**D. Recent worker outcomes** — scan `~/claude/notes/*/report.md` and `~/claude/notes/*/result.json` modified within the window (yesterday→now for morning, today for evening) for shipped/blocked signal. `result.json` (schema `{status, summary, deliverables[], blockers[]}`) is the machine-readable source — prefer it; validate with `~/.claude/scripts/result-schema.sh <file> --validate` if unsure. Map `status:done` → shipped, `status:blocked`/`partial` with `blockers[]` → blocked. Cap each list at the template max.

## Step 3 — format the message (EXACT templates — no deviation)

These mirror `~/claude/templates/standup-template.md` verbatim. Do not invent fields, do not pad. WhatsApp formatting: `*bold*`, bullets are `- ` (the standup-template uses `- `, NOT `•` — this is the one place the bullet char differs from daily-brief), preserve blank lines, no `#` headers.

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
- {Q1 → default X}
- {Q2 → default Y}
(logged ke ~/claude/state/decisions.log)
```

- `kemaren closed` ≤ 3 bullets. If nothing closed, write `- (gak ada yang closed kemaren)` — be honest, don't pad (`feedback_no_yesman_sugarcoat`).
- `hari ini` 1–3 commitments.
- If there are **no** pending decisions, DROP both the `❓` and `⏰` blocks entirely.
- The decision deadline is **1h** (`feedback_decision_deadline_4h` was tightened from 4h to 1h). HARD exceptions where the 1h-default rule does NOT apply: money / push-to-prod / destructive / external relationships — for those, never state an auto-default; instead phrase as `- {Q}: BLOCKING, butuh konfirmasi lu (no auto-default)`.

### Evening (run ~7pm WIB)

```
🌙 standup malem {YYYY-MM-DD}

✅ shipped hari ini:
- {bullet 1}
- {bullet 2}

🚧 stuck / blocked:
- {name} — {blocker reason}

🌅 besok pagi pertama:
- {one concrete thing}

📋 open threads: {open_threads_n} total — lihat ~/claude/state/work-queue.md
```

- If nothing shipped → say so honestly (`- (gak ada yang shipped hari ini)`), don't fabricate.
- If nothing blocked → DROP the `🚧` block.
- `besok pagi pertama` = exactly ONE concrete thing (pull the top NOW task or the most urgent paused-decision).
- Always keep the `📋 open threads` line (it's the link to truth-source even at 0).

### Emoji discipline (HARD RULE)

The structural emojis `🌅 🌙 ✅ 🎯 ❓ ⏰ 🚧 📋` are **labels, explicitly greenlit by Toper for standup format only** (per `standup-template.md` + `feedback_daily_standup`). They are SEPARATE from the conversational emoji allowlist (`🤣🙏😭🥲😁`). Do NOT use any conversational/reaction emoji in standup body text. Do NOT add structural emojis beyond the eight listed.

### Voice (HARD RULE)

- Casual Bahasa Indonesia, real-friend register (`feedback_bahasa_natural`). Short sentences. No corporate-speak, no eager phrasing.
- **No em/en dashes anywhere** (`feedback_no_long_hyphens`) — use a comma. The `-` in `- {bullet}` is a list marker, fine; never use `—`/`–` in prose.
- Blunt accuracy over cheerful coverage (`feedback_no_yesman_sugarcoat`). "Stuck because X" beats "challenging due to Y".

## Step 4 — send (or dry-run print)

**Pre-flight (HARD RULE, `feedback_whatsapp_no_random_messaging`):** before any send, verify the JID via `mcp__plugin_whatsapp_whatsapp__check_number` or `list_chats`. `62817712289@s.whatsapp.net` is whitelisted but the verify-habit stays. NEVER fuzzy-match a contact name; send only to the exact JID.

- **If dry-run:** print the body between `=== DRY RUN START ===` / `=== DRY RUN END ===`. Do NOT call WhatsApp. (This is the path `/daily-brief` uses to borrow the body.)
- **If not dry-run:** call `mcp__plugin_whatsapp_whatsapp__send_message` to `62817712289@s.whatsapp.net` with the formatted body. Param names vary (`jid`/`recipient`/`to`, `message`/`text`/`body`) — inspect the schema at call-time. **Verify the return** (`feedback_verify_after_write`): if it errored, retry once, then surface the failure (exit 1) rather than silently dropping.

## Step 5 — log

Append one line to `~/.local/share/standup/log/{mode}-{YYYY-MM-DD}.log` (create dir if missing):

```
[YYYY-MM-DD HH:MM WIB] {mode} standup — closed={n} commit={n} pending_decisions={n} blocked={n} open_threads={n} sent={yes|no|dry-run|skipped}
```

## Worked examples

**Example A — `/standup morning`, now Wed 2026-06-11 07:00 WIB.**
Sources: work-queue `## Recently shipped` has 2 rows dated yesterday (`pulse-receipt-i18n shipped`, `signal-trader-ocr shipped`); tasks `## NOW` has `fix CM 500 on Berkah`, `re-run suite 818`; work-queue `## Paused — awaiting Toper decision` has `fitest-batches-6-7 — "Go" to spawn batch 6`. → Body:
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
- batch 6 -> gw spawn pake brief batch-5
(logged ke ~/claude/state/decisions.log)
```

**Example B — `/standup evening`, now Wed 2026-06-11 21:00 WIB, nothing blocked.** work-queue 3 open threads, today shipped 1 thing. → Body:
```
🌙 standup malem 2026-06-11

✅ shipped hari ini:
- 3 fitest tickets difile (Berkah/Pustaka 500, SubPopup 422, Promo regression)

🌅 besok pagi pertama:
- nunggu Ryan re-run 818 + review tickets

📋 open threads: 3 total — lihat ~/claude/state/work-queue.md
```
(no `🚧` block because nothing blocked.)

**Example C — `/standup morning` but Toper messaged main 12 min ago.** → `SKIP — Toper messaged within the last hour, standup suppressed`, exit 0, nothing sent.

**Example D — `/daily-brief` delegating the body.** daily-brief calls `/standup morning --dry-run`, captures the text between the DRY RUN banners, and sends it itself to `107838240207070@lid`. This skill never touches WhatsApp in that path.

## Never-do list

- Never send to any JID other than `62817712289@s.whatsapp.net` (standalone path). Never invent a recipient.
- Never modify `~/.claude/tasks/*.md`, `~/claude/state/work-queue.md`, or `decisions.log` — read-only.
- Never pad. No-yesman: if nothing shipped/closed, say so.
- Never use conversational emoji or any structural emoji outside the eight greenlit ones.
- Never double-send: dry-run prints only.
- Never state an auto-default for money / push-to-prod / destructive / external-relationship decisions — those are BLOCKING, confirmation-only.
- Never "fix" the recipient-JID difference vs daily-brief on your own — that's a reconciliation question for Toper (see below).

## Reconciliation note (for the human)

The standup ritual (`feedback_daily_standup` + `standup-template.md`) targets `62817712289@s.whatsapp.net`; `/daily-brief` targets `107838240207070@lid`. Both are Toper. If the scheduled daily-brief and a manual/scheduled standup both fire, Toper gets two messages on two JID surfaces. This is intentional today (they're different rituals) but if Toper wants ONE channel, the fix is to make daily-brief delegate the standup body (see "Composition") and retire the standalone send — a one-line decision for Toper, not a silent code change.

## Done

After a successful send (or dry-run print), print exactly:
```
DONE — {mode} standup sent to Toper at {HH:MM WIB}
```
(or `DONE — {mode} standup dry-run printed`, or the `SKIP —` line if suppressed).
