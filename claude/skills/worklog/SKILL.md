---
name: worklog
description: Track billable hours for software-house client work by logging time entries to a JSONL ledger, rolling up per client/project/task, applying rounding and billing rules, and emitting a timesheet that /invoice consumes directly as line items. Use when the user says /worklog, "log time", "start/stop a timer", "how many hours on X", "timesheet for client Y", or wants a weekly hours summary.
argument-hint: start <client> <project> "<task>" [--nb] | stop ["<note>"] | add <client> <project> <hours> "<task>" [date] [--nb] | status | report <client|project|--week|--all> [period] | timesheet <client> [project] [period] [--unbilled] | rate <client> [project] <amount> | mark-billed <client> (--timesheet <ref> | [--invoice INV-...] [period]) | edit <id> <field>=<value>
allowed-tools: Bash, Read, Write, Glob, Grep
---

# /worklog: billable-hour tracking that feeds /invoice

You are a time-tracking ledger for PT Aenoxa's software-house client work. Time goes IN as entries (live timers or manual adds); it comes OUT as per-client / per-project rollups and, crucially, as a **timesheet shaped EXACTLY like `/invoice` line items** so billing is a clean handoff, not a re-keying exercise. The ledger is the single source of truth; every report is a view over it.

**Why this exists / how it pairs with `/invoice`:** `/invoice` bills a client a total or a milestone but keeps no record of *how the hours accrued*. `/worklog` is that record. Its `timesheet` sub-command outputs line items whose `qty` = billable hours, `unit_price` = hourly rate, `amount` = `ROUND_HALF_UP(qty x unit_price)`: the exact `line_items` schema `/invoice` ingests verbatim. The flow is **log time all week, then `/worklog timesheet <client> --unbilled`, then paste the block into `/invoice`, then `/worklog mark-billed`** so the same hours never bill twice.

> **This skill OWNS the contract.** `/invoice`'s `references/worklog-contract.md` names `worklog/SKILL.md` as the source of truth for the ledger, the rounding rules, and the timesheet shape. Section 4 below is authoritative: `/invoice` only consumes what this skill emits. Keep it exact.

## 0. PRIME RULES (read before any sub-command)

These four rules outrank convenience everywhere in this skill. Violating any one produces either a client-facing error or a silently wrong invoice.

1. **THE ARITHMETIC RULE (load-bearing).** Every emitted line item's `amount` MUST equal `ROUND_HALF_UP(Decimal(qty) x Decimal(unit_price))` computed from the EXACT 2-decimal `qty` you emit. `/invoice`'s `compute.py` re-derives every line the same way and **refuses to render (exit 2)** on any mismatch. NEVER use Python `round()` / banker's rounding, NEVER `printf %.0f`, NEVER the sum of per-entry amounts. Section 2 gives the one command. Section 4 gives the pre-emit self-check. This is the single most common way to break the pipeline.

2. **THE SHAPE RULE.** The timesheet emits a fenced JSON array under the header string, byte for byte:
   `=== /invoice line_items (paste into /invoice) ===`
   Each element is exactly `{description, detail, qty, unit_price, amount}`, in that order, no more fields, no fewer. `qty` is 2-decimal hours (NOT an integer). `unit_price` and `amount` are integer IDR. `/invoice` ingests the array verbatim; adding, renaming, or reordering a field breaks ingestion.

3. **THE CLOSE-THE-LOOP RULE.** Timesheets default to `--unbilled`. `mark-billed` binds to a **timesheet snapshot** (`entry_ids[]`), never to a loose period guess. Billing the same hours twice, or letting late-logged hours vanish from `--unbilled`, is the worst failure this skill can produce. Section 3 (`timesheet`, `mark-billed`) and Section 4 enforce the binding.

4. **THE DASH RULE (house PRIME RULE, mirrors `/frontend-design` 0.4).** NEVER emit an em-dash or an en-dash, not in a confirmation string, not in a `description` or `detail` (which render onto the client's invoice PDF), not anywhere. Use a colon, a comma, parentheses, a middot, or the plain hyphen-minus. `detail` uses a middot separator and `..` for date ranges. Scan your own output before printing:
   ```bash
   grep -nP "[\x{2013}\x{2014}]" <file-or-string>   # must return nothing
   ```

**Working references:** deep recipes, the full failure-mode playbook (exact recovery commands), the non-round-rate reconciliation proof, and the retainer / multi-rate / rate-change walkthroughs live in `references/recipes.md`. SKILL.md is self-sufficient for the contract; read `recipes.md` when a scenario below points there.

---

## 1. Stores (create on first use)

The store is greenfield: create it lazily on the first write, never assume it exists.

```bash
mkdir -p ~/.claude/worklog ~/.claude/worklog/timesheets
```

| File | Purpose | Format |
|---|---|---|
| `~/.claude/worklog/entries.jsonl` | **The ledger**: one JSON object per line, append-only audit trail | JSONL |
| `~/.claude/worklog/active.json` | The single running timer (absent when no timer runs) | JSON |
| `~/.claude/worklog/rates.json` | Per-client / per-project hourly rates + billing config | JSON |
| `~/.claude/worklog/timesheets/<ref>.json` | **Snapshot manifest** written by `timesheet`; `mark-billed` binds to it | JSON |
| `~/.claude/worklog/.lock` | flock target for read-modify-rewrite critical sections | lockfile |

`worklog` owns ONLY `~/.claude/worklog/`. It NEVER writes `~/.claude/invoices/` (that is `/invoice`'s store) and NEVER writes `~/claude/notes/portfolio-raw-material.md` (Section 5).

**Timezone: `Asia/Jakarta` (WIB, UTC+7).** All timestamps ISO 8601 with the `+07:00` offset; all dates `YYYY-MM-DD` (WIB). Always shell out for real time, never hand-calculate:
```bash
TZ=Asia/Jakarta date '+%Y-%m-%dT%H:%M:%S+07:00'   # 2026-07-03T09:05:27+07:00  (timestamps)
TZ=Asia/Jakarta date +%Y-%m-%d                     # 2026-07-03                 (dates)
TZ=Asia/Jakarta date +%G-W%V                        # 2026-W27  (ISO week, %G pairs with %V; Monday start)
TZ=Asia/Jakarta date -d 'yesterday' +%Y-%m-%d       # backfill dates
```

### 1.1 Ledger schema, `entries.jsonl` (one compact object per line)

```json
{"id":"wl-20260703-a1b2c3","client":"Lancar Jaya","project":"POS Integration","task":"Build Shopee aggregator sync endpoint","date":"2026-07-03","start":"2026-07-03T09:05:00+07:00","end":"2026-07-03T11:35:00+07:00","raw_minutes":150,"billable_minutes":150,"billable":true,"rate_idr":400000,"tags":["backend","feature"],"note":"","billed":false,"invoice_number":null,"timesheet_ref":null,"source":"timer","created_at":"2026-07-03T11:35:02+07:00"}
```

Store each entry as ONE line of compact JSON (use `jq -cn`, never pretty-printed): a JSONL line must not contain a raw newline. Field rules:

- `id`: `wl-<YYYYMMDD>-<6 hex>`, the entry's date plus a short random. Generate the hex with `openssl rand -hex 3` (xxd is NOT installed on this box; do not use it). On the astronomically rare collision (grep the id in the ledger first), regenerate.
- `date`: the **START date** (WIB) of the work, always. A timer that starts 23:30 and stops 00:40 belongs to the START date; flag the midnight crossing (Section 6).
- `raw_minutes`: actual elapsed (end minus start, floored to int) for timers, or `hours x 60` for manual adds.
- `billable_minutes`: `raw_minutes` **after the rounding rules** (Section 2). For a non-billable entry set `billable:false` and `billable_minutes:0` (keep `raw_minutes` for internal utilization stats).
- `billable`: `true` normally; `false` for `--nb` entries (skips rounding, contributes 0 to invoices).
- `rate_idr`: resolved at log-time from `rates.json` (project rate, then client rate, then default) and **snapshotted onto the entry**. A later rate change never silently re-prices already-logged work.
- `tags`: array of lowercase tags, populated from `#tag` tokens in the task string and from `--tag <t>` (Section 3). `#portfolio` powers the Section 5 nudge.
- `billed` / `invoice_number` / `timesheet_ref`: flipped by `mark-billed` when the hours land on an invoice. The unbilled-vs-billed split is what prevents double-billing.
- `source`: `timer` | `manual`.
- **Append-only.** Corrections are a compensating entry or the sanctioned single-field `edit` (Section 3), never a silent history rewrite that breaks auditability.

### 1.2 Rates config, `rates.json`

```json
{
  "default_rate_idr": 300000,
  "currency": "IDR",
  "rounding": { "mode": "nearest", "increment_minutes": 15, "minimum_minutes": 15 },
  "max_session_hours": 8,
  "week_start": "monday",
  "clients": {
    "Lancar Jaya": {
      "rate_idr": 350000,
      "projects": {
        "POS Integration": { "rate_idr": 400000 },
        "Maintenance Retainer": { "rate_idr": 0, "billing": "retainer", "monthly_cap_hours": 10, "overage_rate_idr": 350000 }
      }
    }
  }
}
```

**Rate resolution (first hit wins):** `clients[c].projects[p].rate_idr`, then `clients[c].rate_idr`, then `default_rate_idr`. If no client config exists, use `default_rate_idr` and tell the user to set one via `/worklog rate`.

**Retainer:** a project with `rate_idr:0` and `"billing":"retainer"` means in-cap hours are tracked but not separately billed (they burn the retainer). See Section 2.5 for the exact in-cap-vs-overage handling; the retainer overage bills at `overage_rate_idr`.

Write `rates.json` atomically (jq + temp + mv, Section 6); it is small but you never want a half-written config.

---

## 2. Rounding and billing (HARD RULES, applied at log-time, frozen into the entry)

These are computed once when an entry is finalized (`stop` or `add`) and **frozen** into `billable_minutes`. Displayed and billed hours always derive from `billable_minutes`, never from raw clock time. State the effective rule to the user whenever it changes a number ("logged 2h27m raw, 2.50h billable, nearest-15 min-15").

**Rule 1: Increment rounding.** Round `raw_minutes` to the nearest `increment_minutes` (default 15) using `mode`:
- `nearest` (default): round half UP to the increment.
- `up`: always ceil to the increment (agency-favorable).
- `down`: always floor to the increment (client-favorable).

**Rule 2: Minimum billable.** Any billable entry with `raw_minutes > 0` bills at least `minimum_minutes` (default 15). A 4-minute fix logs as 15 billable minutes. The minimum applies AFTER the mode (so `down` on a 4-min entry still floors to 0 then bumps to the 15 minimum).

**Rule 3: Non-billable bypass.** `billable:false` entries skip rounding entirely (`billable_minutes:0`); raw is still recorded for utilization.

**Rule 4: Hours conversion.** `hours = billable_minutes / 60`, rounded to **exactly 2 decimals** (`2.50`, not `2.4999`). The invoice `qty` is this 2-decimal value.

**Rule 5: Amount (THE ARITHMETIC RULE, Section 0.1).** `amount = ROUND_HALF_UP(Decimal(qty) x Decimal(unit_price))`, integer IDR, using the exact 2-decimal `qty`. This is a **must-equal invariant**, not an approximation. The one command (mirrors `compute.py`'s `rhu()`):
```bash
python3 -c "import sys;from decimal import Decimal,ROUND_HALF_UP;q,u=sys.argv[1],sys.argv[2];print(int((Decimal(q)*Decimal(u)).quantize(Decimal('1'),rounding=ROUND_HALF_UP)))" 2.50 400000
# 1000000
```
For rates that are multiples of 100 (Christopher's 300000 / 350000 / 400000) `qty x unit_price` is always integer, so the mode is invisible. For any non-round rate (a negotiated 366667/h, a retainer overage) it hits a `.5` boundary where banker's rounding and half-up differ by 1 rupiah, and `compute.py` takes half-up. NEVER derive `amount` from `round()` or from summing per-entry amounts. Proof and worked non-round example: `references/recipes.md`.

**Rule 6: Round per-entry, never per-rollup.** Round each entry once at log-time; rollups and timesheets SUM already-rounded `billable_minutes`, then compute one `amount` per line item via Rule 5 from the summed 2-decimal hours. Rounding the sum a second time would double-round and drift.

### 2.1 Minute-rounding worked table (unambiguous, verified)

`increment=15`, `minimum=15`:

| raw | nearest | up | down |
|---|---|---|---|
| 4   | 15  | 15  | 15  (floor 0, min bumps to 15) |
| 22  | 15  | 30  | 15  |
| 23  | 30  | 30  | 15  |
| 29  | 30  | 30  | 15  |
| 90  | 90  | 90  | 90  |
| 147 | 150 | 150 | 135 |

Half-up boundary: `22 -> 15`, `23 -> 30` (nearest mode). The minimum bump: `4 -> 15` in all three modes because a billable entry with raw > 0 never bills below the minimum.

### 2.5 Retainer handling (exact)

A retainer project (`rate_idr:0`, `billing:retainer`, `monthly_cap_hours`, `overage_rate_idr`) splits per **calendar month**:

- **In-cap hours** (cumulative month-to-date `<= monthly_cap_hours`): tracked as normal entries (`billable:true`, real `billable_minutes`, `rate_idr:0`). They are **EXCLUDED from every billable view**: the timesheet line items, the `report` ready-to-invoice list, AND the bare-period `mark-billed` set (a rate-0 line would be amount-0 noise on the client PDF, and sweeping them into an invoice mislabels retainer time as billed). `report` and `status` surface them separately as "retainer utilization X/10h this month".
- **Overage hours** (the portion past `monthly_cap_hours` in that calendar month): billed as a single dedicated line item `description: "Retainer overage"` at `overage_rate_idr`. If `overage_rate_idr` is absent, fall back to the client rate, then the default rate, and STATE which fallback you used.
- The cap is per calendar month even though `report` and `timesheet` often run weekly; compute month-to-date retainer hours when deciding in-cap vs overage. Worked example in `references/recipes.md`.

---

## 3. Sub-commands

Parse `$ARGUMENTS`; the first token is the sub-command. `--nb` / `--non-billable` and `--tag <t>` may appear on `start` / `add`. A `#tag` token inside the task string is also captured as a tag (and stripped from the stored task text if it is a trailing bare tag).

### `start <client> <project> "<task>" [--nb] [--tag <t>]`
Begin a live timer.
1. If `active.json` exists, a timer is already running. **Refuse:** tell the user what is running and since when, suggest `stop` first. NEVER silently nest timers.
2. Resolve the rate from `rates.json` (0 for a retainer project).
3. Write `active.json`: `{client, project, task, start, rate_idr, billable, tags}` (`billable:false` if `--nb`). This is a single small file: write via temp + mv.
4. Confirm: `timer started: {client} / {project}: {task} @ {HH:MM WIB} (rate Rp {rate})`. For `--nb`: append `[non-billable]`.

### `stop ["<note>"]`
End the running timer and finalize a ledger entry.
1. If no `active.json`, print "no timer running" and stop.
2. Compute `raw_minutes = now - start` (minutes, floored to int).
3. **Timer sanity gate (Section 6):** if `raw_minutes > max_session_hours*60` (default 8h) OR the span crosses a WIB midnight, do NOT auto-finalize. Show the elapsed time and require explicit confirm or a corrected duration.
4. Apply the rounding rules (Section 2) to get `billable_minutes`, `hours`, `amount`. For `--nb` entries skip rounding.
5. Append the full entry to `entries.jsonl` (`source:"timer"`, `billed:false`, `date` = START date). Delete `active.json`.
6. Confirm: `stopped: {task}: {raw}m raw, {hours}h billable ({Rp amount}). entry {id}`.

### `add <client> <project> <hours> "<task>" [date] [--nb] [--tag <t>]`
Log a manual entry (forgot to time it). `hours` accepts `1.5`, `90m`, `1h30m`. `date` defaults to today (WIB); accepts `YYYY-MM-DD` or `yesterday`. A **negative** `hours` (e.g. `-1h`) is allowed ONLY as a flagged compensating credit against an already-billed mistake (the one signed-entry exception, Section 6; recipe G4). It never applies to normal logging, and its negative `amount` reduces the next invoice as its own line.
1. Convert to `raw_minutes`; apply rounding (the minimum still applies); resolve and snapshot the rate.
2. `start` / `end` set to `null` (manual entries have no clock span); `raw_minutes` carries the duration; `source:"manual"`.
3. Append the entry. Confirm with the same shape as `stop`.

### `status`
Show the running timer (if any) plus today's totals.
- If a timer runs: elapsed so far + projected billable if stopped now. **If elapsed already exceeds `max_session_hours` OR the start date is not today, flag it STALE** and offer discard or a corrected manual `add` (Section 6, orphaned-timer recovery).
- Today's entries (`date == today`): per-entry one-liners + `today total: {hours}h ({Rp})`.
- Surface month-to-date retainer utilization for any retainer project touched today.
- If nothing today and no timer: `no timer running, nothing logged today`.

### `report <client|project|--week|--all> [period]`
Read-only rollups over the ledger. `period` = `--week` (current ISO week), `--month`, `YYYY-MM`, or a `YYYY-MM-DD..YYYY-MM-DD` range; default current week.
- **Per client:** total billable hours + amount, broken down by project then task, with the billed-vs-unbilled split.
- **Per project:** the same, scoped to one project.
- **`--week`:** the weekly summary: every client/project touched this week, hours each, grand total hours + billable amount, and a flagged list of `unbilled` entries ready to invoice. Surface any retainer overage and in-cap utilization.
- **`--all`:** lifetime per-client totals (billed + unbilled).
Render a clean table. SUM already-rounded `billable_minutes` (Rule 6). Show both **hours** and **Rp** (integer, dot-thousands). Never mutate the ledger from `report`.

### `timesheet <client> [project] [period] [--unbilled] [--by task|project|day]` (the /invoice handoff, KEY)
Produce billing-ready line items for `/invoice` AND a snapshot manifest that binds `mark-billed`. `--unbilled` (the billing default) restricts to `billed:false` entries.
1. Select matching entries (client, then optional project / period / unbilled). **Exclude in-cap retainer hours** (Section 2.5); if there is retainer overage this month, add it as its own line.
2. **Group into line items.** Default `--by task` (one line per distinct `task` within the period), summing `billable_minutes`. `--by project` collapses to one line per project; `--by day` gives daily lines. If entries in a group carry **different `rate_idr`, SPLIT into one line per rate**: never blend rates into a single line (each line must independently satisfy Rule 5).
3. For each group compute `qty` (summed 2-decimal hours, Rule 4) and `amount` (Rule 5 from that `qty`). Emit each line EXACTLY in the contract shape (Section 4).
4. **Run the pre-emit self-check (Section 4.2) before printing.** If any line fails, fix it; do NOT emit a failing array.
5. **Write the snapshot manifest** `~/.claude/worklog/timesheets/<ref>.json` (Section 4.3), where `<ref> = ts-<YYYYMMDD>-<6hex>`, capturing the exact `entry_ids[]` that back these lines. Print `<ref>`.
6. Output BOTH:
   - a human table (No. | Description | Hours | Rate | Amount) with a grand total, AND
   - the fenced JSON array under `=== /invoice line_items (paste into /invoice) ===`.
7. Print the handoff hint, including the snapshot ref:
   `Next: /invoice "<client>" "<project>" using the line items above. Then: /worklog mark-billed "<client>" --timesheet <ref> --invoice <INV-...> to close these exact hours.`

> **Why grouped-by-task, not raw entries:** invoices bill deliverables, not clock punches. One line per task reads cleanly to a client and matches how `/invoice` line items look. Raw entries stay in the ledger for the audit trail; the snapshot records which entry ids back each timesheet.

### `rate <client> [project] <amount>`
Set or update a rate in `rates.json` (client-level or project-level); creates the node if absent. Write atomically (jq + temp + mv). Confirm old to new. **Does NOT re-price existing entries** (their `rate_idr` is snapshotted): say so, and mention that a past entry needing a genuine re-rate takes a compensating `add` or an `edit` (with a note).

### `mark-billed <client> (--timesheet <ref> | [--invoice INV-...] [period])` (close the loop, Section 0.3)
Flip the invoiced entries to `billed:true`. **Prefer `--timesheet <ref>`**: it flips EXACTLY the `entry_ids[]` in that snapshot, which is idempotent and cannot over-flip.
1. **`--timesheet <ref>` (preferred):** read `timesheets/<ref>.json`, target its `entry_ids[]`. Show the set + totals; confirm; flip.
2. **Bare period (fallback, guarded):** compute the current unbilled billable set for client + period (EXCLUDE rate-0 in-cap retainer entries, Section 2.5: they are not invoice line items). If a snapshot for that client + period exists, print a **DIFF** (invoiced snapshot set vs current unbilled set). If the counts differ, REFUSE to auto-flip and require explicit confirmation naming the delta (this is exactly the late-logged-hours trap in `references/recipes.md`). If no snapshot exists, show the full set and require explicit confirm.
3. Flip via flock + jq + temp + mv (Section 6): set `billed:true`, `invoice_number:<INV-...>`, `timesheet_ref:<ref>` on the targeted ids. NEVER a partial or non-atomic write.
4. **Reconciliation invariant:** print the total hours and Rp flipped under this INV. This number MUST equal the invoice's worklog-sourced total; surface it so the user can cross-check against the issued invoice.
5. Confirm: `marked {N} entries ({hours}h, {Rp}) as billed under {INV-...}`. Those hours now drop out of `--unbilled`, so a re-run cannot re-bill them.

### `edit <id> <field>=<value>` (sanctioned single-field correction)
Correct a mistake on a NOT-yet-billed entry (wrong duration, task, date, billable flag). Read the ledger, flip that one field on that one `id` (keep `id` and `created_at`), and if the field affects money (`raw_minutes`, `billable_minutes`, `rate_idr`, `billable`), recompute the derived fields per Section 2 and say so. Use flock + jq + temp + mv (Section 6).
- If the entry is `billed:true`, REFUSE: an already-billed entry is not silently rewritten. Add a compensating `add` (negative-hours note or next-invoice credit) and flag it, so billed history stays reconcilable against issued invoices (Section 6, correcting-a-billed-entry).

---

## 4. The /invoice timesheet contract (AUTHORITATIVE)

This section is the contract `/invoice` depends on. `references/worklog-contract.md` in the invoice skill points here as source of truth; keep this exact.

### 4.1 The line-item shape (the whole contract)

Header string, byte for byte (load-bearing, identical across worklog / invoice / the contract file):
```
=== /invoice line_items (paste into /invoice) ===
```
Under it, a fenced `json` array. Each element is exactly:
```json
{
  "description": "Shopee sync endpoint",
  "detail": "2026-06-09..06-13 · 1 session · 2.50h @ Rp 400.000/h",
  "qty": 2.5,
  "unit_price": 400000,
  "amount": 1000000
}
```
- `description`: the deliverable (grouped by task). Dash-free (Section 0.4).
- `detail`: human sub-label `period · session count · hours @ rate`, middot-separated, `..` for date ranges, dash-free. Renders as the grey sub-line on the invoice.
- `qty`: **billable hours, 2-decimal** (`2.5`, `7.25`). NOT an integer.
- `unit_price`: **integer IDR** hourly rate (snapshotted).
- `amount`: **integer IDR**, `ROUND_HALF_UP(qty x unit_price)` (Rule 5). `/invoice` re-verifies this exact equality and refuses to render on mismatch.

IDR display anywhere in the human table uses `Rp` + space + dot-thousands + no decimals, mirroring `compute.py`'s `rp()`:
```bash
python3 -c "import sys;n=int(sys.argv[1]);print('Rp ' + '{:,.0f}'.format(n).replace(',', '.'))" 875000   # Rp 875.000
```
NEVER `15,000,000`, NEVER `15000000`, NEVER decimals in the rupiah display.

### 4.2 PRE-EMIT self-check (run before printing the array)

Do NOT depend on `/invoice`'s file at runtime; recompute each line the way `compute.py` does, inline. Write your candidate line_items array to a file, then run this against it (the program comes from the heredoc, the array from the file argument, so do NOT try to pipe the array on stdin):
```bash
python3 - /tmp/wl_lines.json <<'PY'
import sys, json
from decimal import Decimal, ROUND_HALF_UP
def rhu(x): return int(Decimal(str(x)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
li = json.load(open(sys.argv[1]))
bad = 0
req = {"description", "detail", "qty", "unit_price", "amount"}
for i, l in enumerate(li):
    if set(l) != req:
        print(f"LINE {i}: shape drift, keys={sorted(set(l))} need {sorted(req)}"); bad += 1; continue
    if not (isinstance(l["unit_price"], int) and isinstance(l["amount"], int)):
        print(f"LINE {i}: unit_price/amount must be integers"); bad += 1
    want = rhu(Decimal(str(l["qty"])) * Decimal(str(l["unit_price"])))
    if want != int(l["amount"]):
        print(f"LINE {i} ({l['description']}): amount={l['amount']} but ROUND_HALF_UP({l['qty']} x {l['unit_price']})={want}, WOULD FAIL /invoice exit 2"); bad += 1
print("PRE-EMIT SELF-CHECK: ALL PASS" if not bad else f"PRE-EMIT SELF-CHECK: {bad} PROBLEM(S), DO NOT EMIT")
sys.exit(1 if bad else 0)
PY
```
It is byte-exact with the real gate: an `amount` of `550000` for `1.5 x 366667` fails here AND is rejected by `compute.py` (exit 2); `550001` passes both. When a line fails, recompute `amount` via Rule 5; do NOT fudge `qty`.

### 4.3 Snapshot manifest (binds mark-billed)

`timesheet` writes `~/.claude/worklog/timesheets/<ref>.json`:
```json
{
  "ref": "ts-20260703-9c1a4f",
  "client": "Lancar Jaya",
  "project": "POS Integration",
  "period": "2026-W27",
  "entry_ids": ["wl-20260703-a1b2c3", "wl-20260703-d4e5f6"],
  "total_hours": 4.00,
  "total_idr": 1600000,
  "created_at": "2026-07-03T17:02:10+07:00"
}
```
`mark-billed --timesheet <ref>` flips EXACTLY `entry_ids[]`. This is the close-the-loop binding: whatever entries backed the invoiced timesheet are the entries that get marked, regardless of what was logged afterward. `/invoice` tags its ingested items `source: "worklog:<ref>"` for provenance.

### 4.4 The store-separation invariant

The contract between the two skills is the **line-item shape** plus the **billed flag**: worklog owns "have these hours been billed?", invoice owns "what is on the PDF". `/worklog` NEVER writes `~/.claude/invoices/`; `/invoice` NEVER writes `~/.claude/worklog/`. After issuing a worklog-sourced PDF, `/invoice` prints the exact `mark-billed` command back (it cannot run it, since it cannot write this store): the user runs it here to close the loop. `/invoice` gates PPN behind `is_pkp` (off by default) and adds a PPh 23 memo when the client withholds, plus terms and bank per its config; worklog does no tax math.

---

## 5. Boundaries (what worklog is NOT)

- **`/invoice`** consumes worklog's timesheet as line items and owns the PDF, tax, and terms. worklog never renders an invoice, never computes PPN/PPh, never writes the invoice store. It hands off via the line-item block and closes via `mark-billed`.
- **`/tasks`** is Christopher's PERSONAL, human-owned todo layer. It explicitly routes "billable client hours" here (`tasks/SKILL.md`). Do NOT track client billable time as a personal task, and do NOT log personal todos as billable entries. Different layers, different owners.
- **`/standup`** and **`/daily-brief`** are the daily narrative sent to Christopher over WhatsApp. A standup MAY READ today's logged hours (via `report`), but worklog itself NEVER sends WhatsApp and never sets `WHATSAPP=1` (main-session-only rule). worklog produces numbers; standup narrates them.
- **`/journal`** is the append-only memory activity log (durable facts, decisions). worklog is a billing ledger, not a memory journal: do not conflate a time entry with a journal entry.
- **worklog is NOT the harness 3-tier delegated-worker hierarchy** (initiatives / tasks / STATE.md). That tracks agent work; worklog tracks billable human hours. Never file a worker task or triage item in the ledger.
- **Portfolio capture (tie-in, capture-only, Toper-gated):** when a logged task carries `#portfolio` OR its text matches signal words (`root cause`, `novel`, `orchestration`, `new pattern`, `debug`, `architecture`), SURFACE a one-line nudge after confirming the entry: `worth a portfolio story? capture via /journal or append to ~/claude/notes/portfolio-raw-material.md`. **HARD RULE: worklog NEVER writes that file.** It is a capture-only store and productizing is a locked Toper-gated decision (`reference_portfolio_raw_material`). The nudge is a pointer, never an auto-write, never more than one line.

---

## 6. Validation and integrity (HARD RULES)

- **Every entry MUST have** `client`, `project`, `task`, a `raw_minutes`, and a resolved `rate_idr`. Reject or clarify an incomplete `add` / `start` rather than writing a junk row. `raw_minutes` is **positive** for real work (a 0-min entry needs an explicit note). The **only** entry allowed a negative `raw_minutes` / `billable_minutes` is a flagged compensating **credit** (Section 3 `add`; recipe G4), whose negative `amount` reduces the next invoice; the minimum-bump (Rule 2) never applies to it because that rule is scoped to `raw_minutes > 0`. Otherwise `billable_minutes >= 0` (and `billable_minutes <= raw_minutes` is NOT required; the minimum can exceed raw).
- **entries.jsonl is NEVER touched by the Write tool.** Appends use shell `>>` of a single compact `jq -cn` line (atomic under PIPE_BUF, 4096 bytes; a JSONL entry is well under that, so an append needs no lock). Read-modify-rewrites (`mark-billed`, `edit`) use **flock + temp + mv**:
  ```bash
  flock -x ~/.claude/worklog/.lock bash -c '
    tmp=$(mktemp)
    jq -c "<transform>" ~/.claude/worklog/entries.jsonl > "$tmp" && mv "$tmp" ~/.claude/worklog/entries.jsonl
  '
  ```
  The temp + mv makes the replace atomic (a crash mid-write cannot leave a partial ledger); the flock guards against a second session appending during the rewrite window. `active.json`, `rates.json`, and `timesheets/<ref>.json` are single small files (Write or temp+mv both fine); only the append-only ledger has the never-Write rule.
- **Back up before any bulk rewrite:** `cp ~/.claude/worklog/entries.jsonl ~/.claude/worklog/entries.jsonl.bak`. Never `rm` the ledger.
- **One running timer max.** `start` refuses if `active.json` exists. Never nest timers.
- **Timer sanity cap.** On `stop` (and in `status`), if elapsed exceeds `max_session_hours` (default 8h) OR the span crosses a WIB midnight, do NOT auto-finalize a huge phantom entry: show the elapsed time and require explicit confirm or a corrected duration. An orphaned `active.json` (left after a reboot, start-date not today) is flagged STALE by `status` with discard-or-manual-add options (recovery in `references/recipes.md`).
- **`entry.date` = START date (WIB)**, always; midnight-crossing spans are flagged.
- **Rates are forward-only.** Snapshot `rate_idr` on the entry at log-time; a rate change never re-prices logged entries.
- **Amount and unit_price are integers** in any `/invoice` output, displayed `Rp 1.234.567`. Never decimals, never comma-grouping.

---

## 7. Never-do list

- NEVER emit a line where `amount != ROUND_HALF_UP(qty x unit_price)` (Rule 5). It makes `/invoice` refuse to render (exit 2).
- NEVER derive `amount` from `round()` / banker's / `%.0f` / the sum of per-entry amounts. Only the Decimal ROUND_HALF_UP command.
- NEVER add, rename, or reorder a field in the line-item shape; `/invoice` ingests it verbatim.
- NEVER blend entries with different `rate_idr` into one line item; split per rate.
- NEVER bill in-cap retainer hours as line items (rate 0, off the billable timesheet); overage bills at `overage_rate_idr`.
- NEVER bill the same hours twice: default timesheets to `--unbilled`, bind `mark-billed` to a snapshot, and diff-then-confirm on any bare-period flip.
- NEVER auto-finalize a timer past `max_session_hours` or across midnight without explicit confirm.
- NEVER run two timers at once; NEVER silently nest.
- NEVER rewrite `entries.jsonl` with the Write tool or non-atomically; NEVER `rm` it; NEVER silently rewrite a `billed:true` entry.
- NEVER re-price already-logged entries on a rate change (rates are snapshotted forward-only).
- NEVER write `~/.claude/invoices/` (that is `/invoice`'s store) or `~/claude/notes/portfolio-raw-material.md` (capture-only, Toper-gated).
- NEVER use an em-dash or en-dash in any emitted string (confirmations AND client-facing description/detail).
- NEVER format rupiah as `15,000,000` or `15000000`; always `Rp 15.000.000`.

---

## 8. Done

- After a logging action: the confirmation line + entry `id` (+ the portfolio nudge if triggered).
- After `timesheet`: the human table + the pasteable JSON array (pre-emit-checked) + the snapshot `<ref>` + the handoff hint naming `mark-billed --timesheet <ref>`.
- After `report`: the rollup table with hours + Rp totals + billed/unbilled split + retainer utilization.
- After `mark-billed`: `marked {N} entries ({hours}h, {Rp}) as billed under {INV-...}` + the reconciliation total to cross-check against the invoice.
- Scan every emitted block for em/en dashes (Section 0.4) before printing.

Full worked recipes, the failure-mode playbook with exact recovery commands, the non-round-rate reconciliation proof, and the retainer / multi-rate / rate-change walkthroughs: **`references/recipes.md`**.
