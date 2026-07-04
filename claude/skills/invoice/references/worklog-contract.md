# The /worklog → /invoice Contract

`/worklog` is the **time source**; `/invoice` is the **bill**. This file is the
minimal handoff spec so `/invoice` can ingest a timesheet without re-keying.

> **Source of truth: `~/.claude/skills/worklog/SKILL.md`.** That skill OWNS the
> ledger, the rounding rules, and the timesheet format. Do NOT duplicate its
> spec here or re-derive hours/amounts. `/invoice` only *consumes* the line
> items it emits and *reminds* the user to close the loop. Neither skill writes
> the other's store: `/invoice` NEVER writes `~/.claude/worklog/`; `/worklog`
> NEVER writes `~/.claude/invoices/`.

---

## The line_items shape (exact - this is the whole contract)

`/worklog timesheet <client> [project] [period] --unbilled` prints a fenced JSON
array under the header `=== /invoice line_items (paste into /invoice) ===`. Each
element is exactly:

```json
{
  "description": "Shopee sync endpoint",
  "detail": "2026-06-09..06-13 · 1 session · 2.50h @ Rp 400.000/h",
  "qty": 2.5,
  "unit_price": 400000,
  "amount": 1000000
}
```

Field rules `/invoice` relies on (all guaranteed by `/worklog`):

- `description` - the deliverable (grouped by task, not raw clock punches).
- `detail` - human sub-label (period · session count · hours @ rate). Renders as
  the small grey line under the description in the template.
- `qty` - **billable hours, 2-decimal** (e.g. `2.5`, `7.25`). NOT an integer.
- `unit_price` - **integer IDR** hourly rate (snapshotted per entry).
- `amount` - **integer IDR**, `round(qty × unit_price)`. `/invoice` re-verifies
  this equals `qty × unit_price` in its arithmetic gate (see SKILL.md).

`/invoice` ingests the array **verbatim** as its `line_items`, tags each with
`source: "worklog:<id-range or timesheet ref>"` for provenance, and runs them
through the same compute + gate + render path as any other line item.

---

## Close the loop (mandatory - prevents double-billing)

`/worklog` owns the `billed` flag. After `/invoice` issues the PDF for
worklog-sourced items, the user MUST run:

```
/worklog mark-billed "<client>" --invoice <INV-YYYYMM-NNN> [period]
```

This flips those ledger entries to `billed:true`, so the next `--unbilled`
timesheet starts clean and the same hours never bill twice. `/invoice` does not
run this itself (it cannot write the worklog store); it **always prints the
exact command** as the final line of a worklog-sourced run.

---

## The end-to-end flow

1. `/worklog start … / stop` (or `add`) all week → entries accrue with
   snapshotted rates.
2. `/worklog timesheet "<client>" --unbilled` → grouped line items + pasteable
   JSON block.
3. `/invoice "<client>" "<project>"` → paste the block as line items → PPN gated
   by `is_pkp`, PPh 23 memo if the client withholds → compute → gate → render
   PDF → write `~/.claude/invoices/INV-….json` (with `source` provenance).
4. `/worklog mark-billed "<client>" --invoice INV-…` → closes those hours.

> **Note for the harmonizer:** `worklog/SKILL.md:249` says `/invoice` "adds
> PPN/terms/bank per its config." Post-enhancement, `/invoice` PPN is **gated
> behind `is_pkp` (OFF by default)**, not automatically added. That line in
> worklog is slightly stale but harmless (it describes config-driven behavior,
> which is still true). No cross-skill edit made from here.
