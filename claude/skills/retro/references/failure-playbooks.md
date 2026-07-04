# retro failure-mode playbooks - exact recovery

Loaded on demand when a run hits one of these. Each is self-contained with the exact
commands. The retro is a weekly self-improvement ritual: a failure must degrade
gracefully and NEVER silently lose the retro or fabricate its content.

---

## 1. QUIET / NO-DATA WEEK (the anti-fabrication guard)

Trigger: windowed evidence is thin - few/zero in-window commits (measured 2/95
active repos this week), zero fresh `blocked`/`partial` result.json, a stale
work-queue, a quiet journal.

**Do NOT invent a bottleneck to satisfy the Section-3 gate.** Per
`feedback_no_yesman_sugarcoat`, the retro is worthless if it manufactures friction to
look productive. The inverse of sugarcoating a bad week is fabricating drama on a
quiet one - both are dishonest.

Recovery:
1. Produce the retro file normally; name the quiet week honestly in Section 1
   ("light week: N commits, M shipped tasks, no blocked threads").
2. Section 3 (bottleneck): if genuinely nothing met the cost bar, write exactly:
   `No single friction met the cost bar this week (quiet week).` Cite the thin
   evidence (commit count, zero-blocked). This is a valid, passing Section 3.
3. Section 4 (change): you still owe ONE evaluable experiment. Either (a) a small
   forward experiment, or (b) **carry last week's change** forward for another week
   of evaluation (state which and why). A quiet week is not an excuse to skip the
   cumulative loop.
4. Self-check: the ANTI-FABRICATION box PASSES only if no invented bottleneck exists.

## 2. DIGEST SEND FAILS (never lose the retro)

Trigger: `mcp__plugin_whatsapp_whatsapp__send_message` errors, or the pre-flight JID
check fails, or WhatsApp/wa-sender is down.

```bash
# diagnose the transport
```
`mcp__plugin_whatsapp_whatsapp__connection_status`  (no args) -> is the MCP/WA link up?

Recovery (in order):
1. If `connection_status` shows **connected**: retry the send **once**. If it now
   succeeds, done.
2. If still failing OR shows **disconnected**: DO NOT drop the retro. Preserve the
   digest by appending it into the retro file under a clearly-marked block, so the
   next successful run (or Toper) can see it was owed:
   ```
   ## DIGEST (unsent - <ISO WIB>, reason: <send-error|wa-down>)
   <the exact digest body>
   ```
3. Flag main so a human notices: print
   `RETRO DIGEST UNSENT - <week>, transport <reason>; digest saved in the retro file`
   (and if running under main with attn, this surfaces to the operator). NEVER kill
   or restart `wa-sender.service` to "fix" it (`feedback_wa_sender_load_bearing`,
   Toper-gated).
4. The retro FILE is the durable artifact; the digest is a convenience. A failed send
   is a degraded success, not a failed retro.

## 3. MULTI-WEEK GAP (back-fill without lying about dates)

Trigger: the last retro on disk is 2+ weeks old (or there are none and the ritual is
weeks late).

Two valid strategies:
- **Per-week back-fill (preferred, oldest-first):** for each missed ISO week, run
  `/retro week YYYY-W##` so each gets its OWN windowed file with the CORRECT week's
  evidence (Step 0 computes `WINDOW_START`/`WINDOW_END` per week; never reuse the
  current window). Do the oldest first so the "did last week's change stick?" chain
  reads forward correctly.
- **One catch-up retro:** if per-week is overkill, write a single current-week retro
  and log the slip explicitly in Section 6 ("retro ran N weeks late; weeks W## to W##
  not individually reviewed"). Do not pretend the gap did not happen.

Enumerate the missing weeks from the newest file on disk:
```bash
ls -1 ~/claude/notes/retros/retro_*.md 2>/dev/null | sort | tail -1   # newest present
TZ=Asia/Jakarta date +%G-W%V                                          # current week
```

## 4. STALE / MISSING work-queue.md (fall back to the fresh spine)

Trigger: `stat -c %Y ~/claude/state/work-queue.md` predates `WINDOW_START` (52 days
stale as of 2026-07-03), or the file is missing.

Recovery: run the Step 1 freshness guard; if stale/missing, mark work-queue
UNRELIABLE and build Section 2 from the fresh spine instead:
```bash
# stalled work from result.json (fresh) rather than stale paused-since dates
find ~/claude/notes -name result.json -newermt "$WINDOW_START" ! -newermt "$WINDOW_END" 2>/dev/null \
| while read -r f; do
    st=$(jq -r '.status // "?"' "$f"); case "$st" in blocked|partial)
      printf 'STALLED %s :: %s\n' "$(jq -r '.task_slug' "$f")" "$(jq -r '.blockers|join("; ")' "$f" 2>/dev/null)";;
    esac; done
```
Plus windowed-git gaps (repos active early in the window but silent since) and
`(project)`/`(decision)` journal entries that describe a stall. Never quote a stale
work-queue's paused-since date as if it were current.

## 5. MISSING retro-template.md (degrade gracefully)

Trigger: `~/claude/templates/retro-template.md` is absent (it exists today: 2505
bytes, but do not depend on it). The skill embeds the canonical section 1-6 layout in
SKILL.md Step 3, so it can write a correct retro without the template. Use the
embedded layout; note in Section 6 that the template was missing.

> The template is READ-ONLY and OUTSIDE the skill dir - never edit it. It ALSO carries
> a stale "How to run the retro" appendix (its step 7 repeats the broken
> "set a reminder" assumption). Use the template for **section LAYOUT only**; the
> skill's own steps supersede that appendix.

## 6. IDEMPOTENT RE-RUN (never clobber a finished retro)

Trigger: `~/claude/notes/retros/retro_<week>.md` already exists when the run starts.

```bash
F=~/claude/notes/retros/retro_<week>.md
[ -f "$F" ] && { echo "exists ($(wc -l < "$F") lines)"; grep -c '^## ' "$F"; }
```
- If it is **complete** (all 6 `## ` sections present, non-stub): report
  `retro for <week> already exists (complete)` and EXIT. Do not overwrite, do not
  re-send the digest.
- If it is a **stub** (created but sections empty / interrupted mid-run): refresh it
  in place, filling the empty sections. Read it first, preserve any human edits.
- Never blind-overwrite. Read-first, refresh-stub-only.
