# daily-brief delivery architecture (connection-free via wa-sender)

Deep-dive on HOW the scheduled brief reaches Toper's phone, WHY the old design
silently failed for 3+ nights, and the exact (Toper-gated) systemd change that
closes it. SKILL.md is the executable contract; this file is the mechanism truth.

---

## The delivery path (what actually happens)

```
systemd timer (06:00 / 21:00 WIB)
      |  launches headless `claude -p "/daily-brief {mode}"`  (NO whatsapp plugin)
      v
/daily-brief  composes the message from  ~/.claude/tasks/*.md
                                          ~/claude/state/work-queue.md
                                          Google Calendar (list_events)
      |  writes the body to a temp file, then calls
      v
scripts/brief-enqueue.sh  --  flock-guarded, APPEND-ONLY single line
      |  {"to":"$TOPER_WA_JID","message":"...","kind":"daily-brief","ts":<epoch>}
      v
wa-sender queue  ~/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl
      |  drained every tick by the always-on
      v
wa-sender.service (Bun + Baileys, ONE linked device)  -->  WhatsApp  -->  Toper
```

The brief NEVER opens its own WhatsApp connection. It hands one line to the
daemon that already owns the single Baileys session. This is the same
connection-free pattern the freshly-enhanced `/remindme` uses (its durable jsonl
row is drained the same way), and the same pattern `/wa-behavior-learn` uses
(reads the store directly, no plugin). Cite: `feedback_whatsapp_single_session_rule.md`,
`reference_wa_behavior_learn_headless.md`, `reference_signal_trader_notif_bridge.md`.

---

## Verified queue facts (2026-07-03, live)

- **Path:** `~/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl`
- **Schema (exact live keys):** `{"to": <jid>, "message": <text>, "kind": <label>, "ts": <epoch number>}`.
  Confirmed by `tail | jq keys` -> `["kind","message","to","ts"]`; `ts` is a JSON number.
- **Multi-producer:** signal-trader writes many kinds here (`signal_arrived`, `trade_opened`,
  `crash`, `loop_digest`, `market-events`, ...). Our label `kind:"daily-brief"` is clean and unused.
- **Recipient format:** every one of the last 500 lines targets `<digits>@s.whatsapp.net`
  (phone-format). wa-sender's proven transport surface is the phone JID, NOT `@lid`.
- **wa-sender.service:** `systemctl --user` unit, `active (running)`, enabled. Its own unit
  `Docs=` points at `feedback_wa_sender_load_bearing.md`, i.e. the box itself flags it load-bearing.

### Load-bearing constraints (hard, non-negotiable)

1. **APPEND-ONLY.** wa-sender tracks an in-memory BYTE offset into the queue. Truncating or
   rewriting the file desyncs the offset and DROPS the next real notification
   (`reference_signal_trader_notif_bridge.md`). `brief-enqueue.sh` only ever `>>`-appends.
2. **NEVER kill or restart wa-sender** to "fix" a delivery problem. It delivers ALL
   signal-trader trade events; a restart is Toper-gated (`feedback_wa_sender_load_bearing.md`:
   26 hours of silent trade-event loss the one time it went down).
3. **Backlog is not replayed on restart.** wa-sender seeds its offset to the file size at
   startup, so rows enqueued while it was down are audit log only, not delivered. If a still-relevant
   brief was enqueued during an outage, re-enqueue it once wa-sender is back (do not expect a replay).
4. **Do not touch other producers' lines.** Read-only except the skill's own single append.

---

## Why the OLD design broke (the outage this rewrite fixes)

The pre-rewrite systemd units carried TWO house-rule violations that together forked a
second WhatsApp connection and fought main's always-on session:

```
Environment=WHATSAPP=1
ExecStart=... claude ... --dangerously-load-development-channels plugin:whatsapp@TopengDev ... -p "/daily-brief {mode}" ...
```

- `plugin:whatsapp@TopengDev` in a second headless `claude` opens its OWN Baileys/WhatsApp-Web
  socket. Two clients on one linked-device credential -> a **`conflict` stream error**, the
  socket flaps `conflict, reconnecting in 5s` <-> `connected`, and every send is rejected even
  when `connection_status` momentarily reads `connected`.
- `WHATSAPP=1` additionally subscribes the throwaway session to main's inbound feed, so during
  each run main can MISS Toper's messages (`feedback_whatsapp_single_session_rule.md`).

This is exactly the anti-pattern `feedback_whatsapp_single_session_rule.md` (Update 2026-06-01:
"Do NOT spawn a competing claude with WHATSAPP=1 or any WhatsApp MCP from a systemd unit") and
`reference_wa_behavior_learn_headless.md` ("a standalone headless run opens its own Baileys
connection, colliding with the always-on main session") both forbid.

### The evidence (from ~/.local/share/daily-brief/log/)

```
evening 2026-06-30  sent=no   conflict/reconnect loop, status reports connected but send rejects
evening 2026-07-01  sent=no   WhatsApp not connected despite connection_status=connected
evening 2026-07-02  sent=no   3 attempts, 'conflict, reconnecting in 5s' flap loop (another session holds WA creds)
morning 2026-07-01  sent=no   ERROR=whatsapp_conflict_not_connected
morning 2026-07-02  sent=no   3 attempts over ~40s, {connected:false, status:"conflict, reconnecting in 5s"}
```

evening-systemd.log self-diagnosed it: *"a 'conflict' stream error means two clients are connected
with the same WhatsApp credentials, this matches the known WHATSAPP=1 multi-session failure mode."*
The evening idempotency lock froze at `2026-06-29 21:00` (lock only writes on success), i.e. no
evening brief actually delivered for days. The 3-attempt MCP retry just burned ~40s and still failed.

**Do NOT** treat the conflict as a transient to retry-loop, and **NEVER** kill main's WhatsApp
daemon to force a send slot. The root cause is architectural (second Baileys), and the fix is to
stop opening one: deliver connection-free.

---

## The fix: corrected systemd units (TOPER-GATED apply step)

These are paste-ready. The change is **surgical**: remove the two whatsapp-specific lines, add one
hardening line. Everything else (PATH, TZ, attn, `-d channel` debug filter, timeout, logs) is
preserved verbatim. Applying them is a behavior change to files OUTSIDE the skill dir, so it is
Toper-gated: present these, let Toper apply.

### `~/.config/systemd/user/daily-brief-morning.service`

```ini
[Unit]
Description=Daily Morning Brief (06:00 WIB) - tasks + calendar, connection-free WA via wa-sender
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/home/christopher/claude
Environment=HOME=/home/christopher
Environment=PATH=/home/christopher/.nvm/versions/node/v22.16.0/bin:/home/linuxbrew/.linuxbrew/bin:/home/christopher/.bun/bin:/home/christopher/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=TZ=Asia/Jakarta
UnsetEnvironment=WHATSAPP
ExecStart=/home/christopher/.local/bin/claude --dangerously-skip-permissions --dangerously-load-development-channels plugin:attn@s0nderlabs -d channel -p "/daily-brief morning" --max-turns 30
StandardOutput=append:/home/christopher/.local/share/daily-brief/log/morning-systemd.log
StandardError=append:/home/christopher/.local/share/daily-brief/log/morning-systemd.log
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

The evening unit is identical with `evening` substituted for `morning` in Description, ExecStart
prompt, and both log paths (leave the timers untouched; only the two `.service` files change).

### What changed vs the broken units (exactly 3 edits)

| Edit | Old | New | Why |
|---|---|---|---|
| 1 | `Environment=WHATSAPP=1` | (line deleted) | Stops subscribing the throwaway session to main's inbound feed. |
| 2 | `... plugin:whatsapp@TopengDev ...` in ExecStart | (flag deleted) | Stops the second Baileys socket = kills the `conflict` flap. |
| 3 | (none) | `UnsetEnvironment=WHATSAPP` | Belt-and-suspenders vs env-inheritance leak (verified real systemd directive). |

Notes:
- `WHATSAPP` is NOT in the `--user` manager env (verified `systemctl --user show-environment`), so
  edit 1 alone is sufficient; edit 3 is cheap hardening.
- The Google Calendar MCP is account-provided, NOT a dev-channel plugin, so dropping
  `plugin:whatsapp` does NOT affect calendar reads (recent runs logged `calendar_auth=yes` and
  delivered real events without the unit ever loading a calendar plugin).
- `plugin:attn@s0nderlabs` is kept so the headless run can report a DEGRADED result up to main.
  It does not conflict with WhatsApp. It is optional; delivery does not depend on it.
- `-d channel` is `--debug` with the `channel` filter (a debug log category). Harmless, preserved.

### Apply + verify + rollback (for the human)

```bash
# Back up first
cp ~/.config/systemd/user/daily-brief-morning.service{,.bak-$(date +%F)}
cp ~/.config/systemd/user/daily-brief-evening.service{,.bak-$(date +%F)}
# ... edit the two .service files per above ...
systemctl --user daemon-reload
# Prove it end-to-end WITHOUT waiting for 06:00: a real run enqueues + delivers via wa-sender
systemctl --user start daily-brief-morning.service
tail -n 3 ~/.local/share/daily-brief/log/morning-$(TZ=Asia/Jakarta date +%F).log   # expect sent=yes delivery_path=wa-sender
# Rollback if needed
cp ~/.config/systemd/user/daily-brief-morning.service.bak-$(date +%F) ~/.config/systemd/user/daily-brief-morning.service
systemctl --user daemon-reload
```

Because the SKILL now delivers via wa-sender regardless, the brief already stops depending on the
whatsapp plugin the moment SKILL.md ships; the unit edit additionally stops the second-Baileys
side effect (main's inbound theft during each run). Both matter; the unit edit is the belt.

---

## Alternative transport: poke-main (documented, not the default)

Instead of a headless run + queue append, a timer could instead POKE the live main session to run
`/daily-brief {mode}` inside it (via `tmux send-keys` or an attn trigger), and main sends through
its already-connected WhatsApp MCP. This is the "poke the main session" redesign
`reference_wa_behavior_learn_headless.md` and `feedback_whatsapp_single_session_rule.md` (Update
2026-06-01) describe as the clean alternative for timer-triggered WhatsApp skills.

Trade-off vs the wa-sender queue path:
- Poke-main needs main to be ALIVE and WhatsApp-active at 06:00 / 21:00; if main is down, no brief.
- wa-sender is a systemd service that is always up (delivers overnight trades), so the queue path
  is more robust for an unattended schedule. **The wa-sender queue path is the default.**
- If Toper prefers a single WhatsApp surface AND main is reliably up at those hours, poke-main is a
  valid swap. Either way, NEVER a second headless `claude` with the whatsapp plugin.

---

## Two-JID reconciliation (why the recipient changed)

Both of these JIDs reach Toper (both are him, per `whatsapp_style_toper.md`):

| JID | Format | Used by | Transport |
|---|---|---|---|
| `$TOPER_WA_JID` | phone | `/standup`, `/remindme`, wa-sender producers | wa-sender queue (this skill now) + MCP |
| `$TOPER_WA_LID` | LID | the OLD daily-brief MCP-send path | whatsapp MCP only |

The old daily-brief sent to the LID via the whatsapp MCP. The connection-free wa-sender transport
only delivers to the phone JID in practice (all 500 recent queue lines are phone-format; no verified
`@lid`-over-wa-sender path exists). So moving to wa-sender FORCES the phone JID, which also
**converges** daily-brief onto the same surface `/standup` uses. `/standup`'s reconciliation note
called this out as the desired end-state if Toper ever wanted one channel: "make daily-brief
deliver on the standup surface". That convergence is now the default. It is a recipient-surface
change; if Toper specifically wants the LID surface back, that requires the poke-main + MCP path
(and an explicit decision), NOT an unverified `@lid` shoved through wa-sender.
