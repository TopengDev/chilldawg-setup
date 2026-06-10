---
name: worklog
description: Track billable hours for software-house client work — log time entries to a JSONL ledger, roll up per client/project/task, apply rounding/billing rules, and emit a timesheet that /invoice consumes directly as line items. Use when the user says /worklog, "log time", "start/stop a timer", "how many hours on X", "timesheet for client Y", or wants a weekly hours summary.
argument-hint: start <client> <project> "<task>" | stop ["<note>"] | add <client> <project> <hours> "<task>" [date] | status | report <client|project|--week|--all> [period] | timesheet <client> [project] [period] [--unbilled] | rate <client> [project] <amount> | mark-billed <client> [--invoice INV-...] [period]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# /worklog — billable-hour tracking that feeds /invoice

You are a time-tracking ledger for PT Aenoxa's software-house client work. Time goes IN as entries (live timers or manual adds); it comes OUT as per-client/project rollups and, crucially, as a **timesheet shaped exactly like `/invoice` line items** so billing is a clean handoff, not a re-keying exercise. The ledger is the single source of truth; everything else is a view over it.

**Why this exists / how it pairs with `/invoice`:** `/invoice` bills a client a total or milestone but has no record of *how the hours accrued*. `/worklog` is that record. Its `timesheet` sub-command outputs line items with `qty` = billable hours, `unit_price` = hourly rate, `amount` = `qty × unit_price` — the exact `line_items` schema `/invoice` reads (`{description, detail, qty, unit_price, amount}`, integer IDR amounts). The flow is: **log time all week → `/worklog timesheet <client>` → paste the line items into `/invoice` → `/worklog mark-billed`** so the same hours never get billed twice.

---

## Stores (create on first use)

```bash
mkdir -p ~/.claude/worklog
```

| File | Purpose | Format |
|---|---|---|
| `~/.claude/worklog/entries.jsonl` | **The ledger** — one JSON object per line, append-only | JSONL |
| `~/.claude/worklog/active.json` | The single running timer (absent when no timer runs) | JSON |
| `~/.claude/worklog/rates.json` | Per-client / per-project hourly rates + billing config | JSON |

**Timezone:** `Asia/Jakarta` (WIB, UTC+7). All timestamps ISO 8601 with `+07:00` offset. All dates `YYYY-MM-DD` (WIB).

### Ledger schema — `entries.jsonl` (one object per line)

```json
{
  "id": "wl-20260611-a1b2c3",
  "client": "Lancar Jaya",
  "project": "POS Integration",
  "task": "Build Shopee aggregator sync endpoint",
  "date": "2026-06-11",
  "start": "2026-06-11T09:05:00+07:00",
  "end": "2026-06-11T11:35:00+07:00",
  "raw_minutes": 150,
  "billable_minutes": 150,
  "billable": true,
  "rate_idr": 350000,
  "tags": ["backend", "feature"],
  "note": "",
  "billed": false,
  "invoice_number": null,
  "source": "timer",
  "created_at": "2026-06-11T11:35:02+07:00"
}
```

Field rules:
- `id` — `wl-<YYYYMMDD>-<6 hex>` (date of the entry + short random); stable, unique, used by `mark-billed`.
- `raw_minutes` — actual elapsed (end − start) for timer entries, or `hours×60` for manual adds.
- `billable_minutes` — `raw_minutes` **after rounding rules** (below). For non-billable entries set `billable=false` and `billable_minutes=0` (keep `raw_minutes` for internal tracking).
- `rate_idr` — resolved at log-time from `rates.json` (project rate → client rate → default). Snapshotting the rate on the entry means a later rate change never silently re-prices already-logged work.
- `billed` / `invoice_number` — flipped by `mark-billed` once the hours land on an invoice. The unbilled-vs-billed split is what prevents double-billing.
- `source` — `timer` | `manual`.
- **Append-only.** Corrections are new compensating entries or an in-place field flip via a rewrite-the-file edit (see "Editing/correcting"), never silent history rewrites that break auditability.

### Rates config — `rates.json`

```json
{
  "default_rate_idr": 300000,
  "currency": "IDR",
  "rounding": { "mode": "nearest", "increment_minutes": 15, "minimum_minutes": 15 },
  "week_start": "monday",
  "clients": {
    "Lancar Jaya": {
      "rate_idr": 350000,
      "projects": {
        "POS Integration": { "rate_idr": 400000 },
        "Maintenance Retainer": { "rate_idr": 0, "billing": "retainer", "monthly_cap_hours": 10 }
      }
    }
  }
}
```

Rate resolution order (first hit wins): `clients[c].projects[p].rate_idr` → `clients[c].rate_idr` → `default_rate_idr`. A `rate_idr` of `0` with `"billing":"retainer"` means hours are tracked but not separately billed (they burn a retainer; flag overage past `monthly_cap_hours`). If no client config exists, use `default_rate_idr` and tell the user to set a rate via `/worklog rate`.

---

## Rounding / billing rules (HARD RULES — apply at log-time, store the result)

These are computed when an entry is finalized (`stop` or `add`) and **frozen** into `billable_minutes`. The displayed/billed hours always derive from `billable_minutes`, never from raw clock time.

1. **Increment rounding.** Round `raw_minutes` to the nearest `increment_minutes` (default 15) using `mode`:
   - `nearest` (default): round half-up to the increment. 22 min → 15; 23 min → 30.
   - `up`: always ceil to the increment (agency-favorable). 16 min → 30.
   - `down`: always floor (client-favorable). 29 min → 15.
2. **Minimum billable.** Any billable entry with `raw_minutes > 0` bills at least `minimum_minutes` (default 15). A 4-minute fix logs as 15 billable min.
3. **Non-billable bypass.** `billable=false` entries skip rounding entirely (`billable_minutes=0`); raw is still recorded for internal utilization stats.
4. **Hours conversion for display/invoice.** `hours = billable_minutes / 60`, rounded to **2 decimals** (`2.50`, not `2.4999`). The invoice `qty` is this 2-decimal hours value.
5. **Amount.** `amount_idr = round(hours × rate_idr)` to the **nearest integer rupiah** (IDR has no sub-unit). Always integer in the JSON, displayed `Rp` + thousands-dotted (`Rp 875.000`) per the invoice currency convention.
6. **Rounding is per-entry, not per-rollup.** Round each entry once at log-time; rollups SUM already-rounded `billable_minutes`. (Rounding the sum instead would double-round and drift.)

State the effective rounding rule to the user whenever it changes a number (e.g. "logged 2h27m raw → 2.50h billable (nearest-15, min-15)").

---

## Sub-commands

Parse `$ARGUMENTS`; first token = sub-command. Always `date '+%Y-%m-%dT%H:%M:%S+07:00'` / `TZ=Asia/Jakarta date +%Y-%m-%d` for real timestamps — never hand-calculate.

### `start <client> <project> "<task>"`
Begin a live timer.
1. If `active.json` exists → a timer is already running. Refuse: tell the user what's running + since when, suggest `stop` first. (Never silently nest timers.)
2. Resolve the rate from `rates.json`.
3. Write `active.json`: `{client, project, task, start, rate_idr}`.
4. Confirm: `▶ timer started — {client} / {project}: {task} @ {HH:MM WIB} (rate Rp {rate})`.

### `stop ["<note>"]`
End the running timer and finalize a ledger entry.
1. If no `active.json` → "no timer running". Stop.
2. Compute `raw_minutes = now − start` (minutes, floored to int).
3. Apply rounding rules → `billable_minutes`, `hours`, `amount_idr`.
4. Append the full entry to `entries.jsonl` (`source:"timer"`, `billed:false`). Delete `active.json`.
5. Confirm: `⏹ stopped — {task}: {raw}m raw → {hours}h billable ({Rp amount}). entry {id}`.

### `add <client> <project> <hours> "<task>" [date]`
Log a manual entry (forgot to time it). `hours` accepts `1.5`, `90m`, `1h30m`. `date` defaults to today (WIB); accept `YYYY-MM-DD` or `yesterday`.
1. Convert to `raw_minutes`; apply rounding (min-billable still applies); resolve rate.
2. `start`/`end` set to `null` (manual entries have no clock span) — `raw_minutes` carries the duration; `source:"manual"`.
3. Append entry. Confirm with the same line shape as `stop`.

### `status`
Show the running timer (if any) + today's totals.
- If a timer runs: elapsed so far + projected billable if stopped now.
- Today's logged entries (from `entries.jsonl` where `date == today`): per-entry one-liners + `today total: {hours}h ({Rp})`.
- If nothing today and no timer: `no timer running, nothing logged today`.

### `report <client|project|--week|--all> [period]`
Rollups (read-only aggregation over the ledger). `period` = `--week` (current ISO week), `--month`, `YYYY-MM`, or a `YYYY-MM-DD..YYYY-MM-DD` range; default current week.
- **Per client:** total billable hours + amount, broken down by project, then by task. Show billed vs unbilled split.
- **Per project:** same, scoped to one project.
- **`--week`:** the **weekly summary** — every client/project touched this week, hours each, grand total hours + billable amount, and a flagged list of `unbilled` entries ready to invoice. Also surface any retainer overage (hours past `monthly_cap_hours`).
- **`--all`:** lifetime per-client totals (billed + unbilled).
Render as a clean table. Sum already-rounded `billable_minutes` (rule 6). Always show both **hours** and **Rp amount** (computed per rate, integer).

### `timesheet <client> [project] [period] [--unbilled]` — the /invoice handoff (KEY)
Produce billing-ready line items for `/invoice`. `--unbilled` (recommended default for billing) restricts to entries with `billed:false`.
1. Select matching entries (client [+ project] [+ period] [+ unbilled]).
2. **Group into line items.** Default grouping = **by task** (one line item per distinct `task` string within the period), summing `billable_minutes` across its entries. (Offer `--by project` to collapse to one line per project, or `--by day` for daily lines, if the user asks.)
3. For each group emit a line item EXACTLY in the `/invoice` shape:
   ```json
   {
     "description": "<task or project name>",
     "detail": "<period + entry count, e.g. '2026-06-09..06-13 · 3 sessions · 7.50h @ Rp 400.000/h'>",
     "qty": 7.5,
     "unit_price": 400000,
     "amount": 3000000
   }
   ```
   - `qty` = summed hours (2-decimal). `unit_price` = the rate (snapshot from entries; if entries in a group have *different* rates, split into separate line items per rate, never blend).
   - `amount` = `round(qty × unit_price)` integer IDR. (Equals the sum of the entries' integer amounts within ≤1 rupiah; if off, recompute from the summed hours and note it.)
4. Output BOTH:
   - a human table (No. | Description | Hours | Rate | Amount) with a grand total, AND
   - a fenced `json` array of the line items, labeled `=== /invoice line_items (paste into /invoice) ===`, so `/invoice` (or you) can consume it directly.
5. Print the **handoff hint**: `Next: /invoice "<client>" "<project>" → use the line items above. Then /worklog mark-billed "<client>" --invoice <INV-...> {period} to close these hours.`

> **Why grouped-by-task and not raw entries:** invoices bill deliverables, not clock punches. One line per task reads cleanly to a client and matches how `/invoice` line items are meant to look. Raw entries stay in the ledger for the audit trail.

### `rate <client> [project] <amount>`
Set/update a rate in `rates.json` (client-level or project-level). Creates the client/project node if absent. Confirm old → new. **Does NOT re-price existing entries** (their `rate_idr` is snapshotted) — say so, and mention `add`/correction if a past entry truly needs re-rating.

### `mark-billed <client> [--invoice INV-...] [period]` — close the loop (prevents double-billing)
After an invoice is issued, flip the matching entries to `billed:true`.
1. Select the SAME set the timesheet billed (client [+ period], `billed:false`). Show the user the set + total and **confirm before mutating** (this is a state change to the ledger).
2. Rewrite `entries.jsonl` with those rows updated `billed:true, invoice_number:<INV-...>` (read all lines, flip matches, write back atomically to a temp file then move — never a partial write).
3. Confirm: `marked {N} entries ({hours}h, {Rp}) as billed under {INV-...}`.
After this, those hours drop out of `--unbilled` timesheets, so a re-run won't re-bill them.

---

## Editing / correcting entries (audit-safe)

The ledger is append-only by default. To fix a mistake:
- **Wrong duration/task on a recent entry:** read the file, edit that one JSON line in place (atomic temp-file rewrite), and bump nothing else. Keep `id`/`created_at`. This is the one sanctioned in-place edit.
- **Already-billed entry was wrong:** do NOT silently rewrite a billed entry. Add a compensating manual `add` (negative-hours note in `note`, or a credit handled on the next invoice) and flag it to the user — billed history must stay reconcilable against issued invoices.
- Never `rm` the ledger. Back up before any bulk rewrite (`cp entries.jsonl entries.jsonl.bak`).

## Validation & integrity (HARD RULES)

- Every entry MUST have `client`, `project`, `task`, a positive `raw_minutes` (unless explicitly a 0-min note), and a resolved `rate_idr`. Reject/clarify incomplete `add`/`start` rather than writing a junk row.
- `billable_minutes ≤ raw_minutes` is NOT required (min-billable can exceed raw); but `billable_minutes ≥ 0` always.
- `amount` and `unit_price` in any /invoice output MUST be integers (IDR), formatted `Rp 1.234.567` for display. Never emit decimals or comma-grouping in the rupiah display.
- `mark-billed` and any ledger rewrite use **atomic write** (temp file + `mv`); a crash mid-write must not corrupt the ledger.
- One running timer max. `start` refuses if `active.json` exists.
- Snapshot rates on entries; rate changes are forward-only.

## Worked examples

**1. Time a session, then bill it.**
```
/worklog start "Lancar Jaya" "POS Integration" "Shopee sync endpoint"
   → ▶ timer started @ 09:05 (rate Rp 400.000)
... 2h27m later ...
/worklog stop "done, tested 200 OK"
   → ⏹ stopped — Shopee sync endpoint: 147m raw → 2.50h billable (Rp 1.000.000). entry wl-20260611-a1b2c3
   (147m → nearest-15 → 150m → 2.50h; 2.50 × 400000 = 1.000.000)
```

**2. Backfill a forgotten block.**
```
/worklog add "Lancar Jaya" "POS Integration" 90m "Code review + deploy" yesterday
   → ⏹ logged — Code review + deploy: 90m raw → 1.50h billable (Rp 600.000). entry wl-20260610-d4e5f6
```

**3. Weekly summary.**
```
/worklog report --week
   → Week 2026-W24 (Mon 06-09 .. Sun 06-15)
     Lancar Jaya / POS Integration
       - Shopee sync endpoint        2.50h   Rp 1.000.000   [unbilled]
       - Code review + deploy        1.50h   Rp   600.000   [unbilled]
     ----------------------------------------------------------------
     TOTAL: 4.00h billable · Rp 1.600.000 · 2 unbilled entries ready to invoice
```

**4. Generate the timesheet → invoice handoff.**
```
/worklog timesheet "Lancar Jaya" "POS Integration" --week --unbilled
   → table (No|Description|Hours|Rate|Amount) + grand total Rp 1.600.000
   === /invoice line_items (paste into /invoice) ===
   [
     {"description":"Shopee sync endpoint","detail":"2026-06-09..06-13 · 1 session · 2.50h @ Rp 400.000/h","qty":2.5,"unit_price":400000,"amount":1000000},
     {"description":"Code review + deploy","detail":"2026-06-10 · 1 session · 1.50h @ Rp 400.000/h","qty":1.5,"unit_price":400000,"amount":600000}
   ]
   Next: /invoice "Lancar Jaya" "POS Integration"  → use these line items.
         Then /worklog mark-billed "Lancar Jaya" --invoice <INV-...> --week  to close these hours.
```

**5. Close the loop after invoicing.**
```
/worklog mark-billed "Lancar Jaya" --invoice INV-202606-001 --week
   → confirm: flip 2 entries (4.00h, Rp 1.600.000)? [shows them]
   → marked 2 entries (4.00h, Rp 1.600.000) as billed under INV-202606-001
   (now they no longer appear in --unbilled timesheets — no double-billing)
```

## How the /invoice handoff fits together (end-to-end)

1. `/worklog start … / stop` (or `add`) all week → entries accrue in the ledger with snapshotted rates.
2. `/worklog timesheet <client> --unbilled` → grouped line items in `/invoice`'s exact `line_items` schema + a pasteable JSON block.
3. `/invoice "<client>" "<project>"` → reads those line items (qty=hours, unit_price=rate, amount=hours×rate), adds PPN/terms/bank per its config, renders the PDF, writes `~/.claude/invoices/INV-….json`.
4. `/worklog mark-billed "<client>" --invoice INV-…` → flips those entries `billed:true`, so the next timesheet starts clean.

The contract between the two skills is the **line-item shape** (`{description, detail, qty, unit_price, amount}`, integer IDR) and the **billed flag** (worklog owns "have these hours been billed?", invoice owns "what's on the PDF"). Neither skill writes the other's store.

## Never-do list

- Never bill the same hours twice — always `mark-billed` after invoicing; default timesheets to `--unbilled`.
- Never blend entries with different rates into one line item — split per rate.
- Never emit non-integer `amount`/`unit_price` to `/invoice`, and never format rupiah as `15,000,000` or `15000000` (use `Rp 15.000.000`).
- Never run two timers at once.
- Never re-price already-logged entries on a rate change (rates are snapshotted forward-only).
- Never rewrite the ledger non-atomically or delete it; back up before bulk edits; never silently rewrite a *billed* entry.
- Never write to `~/.claude/invoices/` (that's `/invoice`'s store) — hand off via line items only.
- Never round at the rollup level — round per entry at log-time.

## Done

After a logging action: the confirmation line (`▶`/`⏹`) + entry id.
After `timesheet`: the table + the pasteable JSON + the handoff hint.
After `report`: the rollup table with hours + Rp totals + billed/unbilled split.
After `mark-billed`: `marked {N} entries ({hours}h, {Rp}) as billed under {INV-...}`.
