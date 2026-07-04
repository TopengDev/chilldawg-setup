# /worklog recipes, reconciliation proofs, and the failure-mode playbook

Depth companion to `SKILL.md`. Every command here is verified on this box (openssl 3.6.2, flock util-linux 2.42.1, jq 1.8.1, python3 3.14.5; xxd is NOT installed). SKILL.md is self-sufficient for the `/invoice` contract; read this when a section there points you here. Dash-free throughout (SKILL.md Section 0.4).

Paths assume `WL=~/.claude/worklog`. Create it lazily: `mkdir -p "$WL" "$WL/timesheets"`.

---

## A. Command primitives (the verified building blocks)

**A1. Entry id.** `wl-<YYYYMMDD>-<6 hex>`. The date is the START date (WIB).
```bash
id="wl-$(TZ=Asia/Jakarta date +%Y%m%d)-$(openssl rand -hex 3)"    # e.g. wl-20260703-a1b2c3
grep -q "\"$id\"" "$WL/entries.jsonl" 2>/dev/null && id="wl-$(TZ=Asia/Jakarta date +%Y%m%d)-$(openssl rand -hex 3)"   # regen on the rare collision
```
`openssl rand -hex 3` yields 6 hex chars. Do NOT use xxd (not installed).

**A2. Atomic append (the ONLY way a new entry enters the ledger).** One compact line via `jq -cn`, appended with `>>`. Atomic under PIPE_BUF (4096 bytes; an entry is far smaller), so an append needs no lock.
```bash
jq -cn --arg id "$id" --arg c "Lancar Jaya" --arg p "POS Integration" \
  --arg t "Shopee sync endpoint" --arg d "$(TZ=Asia/Jakarta date +%Y-%m-%d)" \
  --argjson raw 150 --argjson bm 150 --argjson rate 400000 \
  --arg ca "$(TZ=Asia/Jakarta date '+%Y-%m-%dT%H:%M:%S+07:00')" \
  '{id:$id,client:$c,project:$p,task:$t,date:$d,start:null,end:null,raw_minutes:$raw,
    billable_minutes:$bm,billable:true,rate_idr:$rate,tags:[],note:"",billed:false,
    invoice_number:null,timesheet_ref:null,source:"manual",created_at:$ca}' >> "$WL/entries.jsonl"
```
NEVER write `entries.jsonl` with the Write tool (non-atomic, corrupts on crash).

**A3. Atomic read-modify-rewrite (mark-billed, edit).** flock + jq + temp + mv. Pass the target id set through a FILE via `--slurpfile` so there is no nested-quote hell and no shell interpolation into jq:
```bash
jq '.entry_ids' "$WL/timesheets/<ref>.json" > /tmp/wl_ids.json     # the ids to flip
flock -x "$WL/.lock" bash <<'EOF'
tmp=$(mktemp)
jq -c --slurpfile ids /tmp/wl_ids.json --arg inv "INV-202607-001" --arg ref "<ref>" '
  ($ids[0]) as $set
  | if (.id as $i | $set | index($i)) then .billed=true | .invoice_number=$inv | .timesheet_ref=$ref
    else . end
' ~/.claude/worklog/entries.jsonl > "$tmp" && mv "$tmp" ~/.claude/worklog/entries.jsonl
EOF
```
The quoted heredoc (`<<'EOF'`) stops the shell touching jq's `$set` / `$i` / `$ids`; the dynamic id list arrives via `--slurpfile` (reads the file), and only literal strings go through `--arg`. temp + mv makes the replace atomic; flock serializes against a second session.

**A4. Period math.** Always shell out, never hand-calculate.
```bash
TZ=Asia/Jakarta date +%G-W%V                       # current ISO week, e.g. 2026-W27  (%G pairs with %V)
TZ=Asia/Jakarta date -d '2026-07-03' +%G-W%V       # ISO week of a given date
TZ=Asia/Jakarta date -d '2026-07-03' +%Y-%m        # calendar month (retainer cap boundary)
TZ=Asia/Jakarta date -d 'yesterday' +%Y-%m-%d      # backfill date
```

**A5. Amount and IDR display (mirror compute.py exactly).**
```bash
# amount = ROUND_HALF_UP(qty x unit_price), integer IDR
python3 -c "import sys;from decimal import Decimal,ROUND_HALF_UP;q,u=sys.argv[1],sys.argv[2];print(int((Decimal(q)*Decimal(u)).quantize(Decimal('1'),rounding=ROUND_HALF_UP)))" 2.50 400000   # 1000000
# display: Rp + space + dot-thousands + no decimals
python3 -c "import sys;n=int(sys.argv[1]);print('Rp ' + '{:,.0f}'.format(n).replace(',', '.'))" 1000000        # Rp 1.000.000
```

---

## B. End-to-end: log a week, invoice it, close the loop

```
# Monday: time a live session
/worklog start "Lancar Jaya" "POS Integration" "Shopee sync endpoint"
   timer started: Lancar Jaya / POS Integration: Shopee sync endpoint @ 09:05 WIB (rate Rp 400.000)
... 2h27m later ...
/worklog stop "done, tested 200 OK"
   stopped: Shopee sync endpoint: 147m raw, 2.50h billable (Rp 1.000.000). entry wl-20260703-a1b2c3
   (147m, nearest-15, 150m, 2.50h; 2.50 x 400000 = 1.000.000)

# Tuesday: backfill a forgotten block
/worklog add "Lancar Jaya" "POS Integration" 90m "Code review + deploy" yesterday
   logged: Code review + deploy: 90m raw, 1.50h billable (Rp 600.000). entry wl-20260702-d4e5f6

# Friday: weekly summary, then the invoice handoff
/worklog report --week
   Week 2026-W27 (Mon 06-29 .. Sun 07-05)
     Lancar Jaya / POS Integration
       Shopee sync endpoint     2.50h   Rp 1.000.000   [unbilled]
       Code review + deploy     1.50h   Rp   600.000   [unbilled]
     TOTAL: 4.00h billable, Rp 1.600.000, 2 unbilled entries ready to invoice

/worklog timesheet "Lancar Jaya" "POS Integration" --week --unbilled
   (human table + grand total Rp 1.600.000)
   snapshot ts-20260703-9c1a4f written (entry_ids: [wl-20260703-a1b2c3, wl-20260702-d4e5f6])
   === /invoice line_items (paste into /invoice) ===
   [
     {"description":"Shopee sync endpoint","detail":"2026-06-29..07-03 · 1 session · 2.50h @ Rp 400.000/h","qty":2.5,"unit_price":400000,"amount":1000000},
     {"description":"Code review + deploy","detail":"2026-07-02 · 1 session · 1.50h @ Rp 400.000/h","qty":1.5,"unit_price":400000,"amount":600000}
   ]
   Next: /invoice "Lancar Jaya" "POS Integration" using the lines above.
         Then: /worklog mark-billed "Lancar Jaya" --timesheet ts-20260703-9c1a4f --invoice <INV-...>

# after /invoice issues INV-202607-001, close the loop, bound to the snapshot
/worklog mark-billed "Lancar Jaya" --timesheet ts-20260703-9c1a4f --invoice INV-202607-001
   confirm: flip 2 entries (4.00h, Rp 1.600.000)? [shows them]
   marked 2 entries (4.00h, Rp 1.600.000) as billed under INV-202607-001
   reconciliation: 4.00h / Rp 1.600.000 flipped, cross-check against the invoice total.
```

---

## C. The arithmetic reconciliation deep-dive (why ROUND_HALF_UP, not round())

`/invoice`'s `compute.py` re-derives every line as `amount == ROUND_HALF_UP(Decimal(qty) x Decimal(unit_price))` and **refuses to render (exit 2)** on a mismatch. For rates that are multiples of 100 (300000 / 350000 / 400000) `qty x unit_price` is always an integer, so the rounding mode is invisible and any method appears to work. The bug is LATENT until a non-round rate appears (a negotiated hourly, a retainer overage split off an odd monthly figure).

**Worked non-round proof (verified):** an overage rate of Rp 366.667/h, 1.50h logged.
```
1.50 x 366667 = 550000.50   (exact)
ROUND_HALF_UP -> 550001      <- what compute.py demands
python round()  -> 550000    <- banker's / float, differs by 1 rupiah
```
Emit `amount: 550000` and `/invoice` returns exit 2 and will NOT render. Emit `550001` and it renders. Same lesson in compute.py's own self-check vector C: `15000150 x 0.11 = 1650016.5`, and it asserts `1650017` (half-up), NOT banker's `1650016`.

**Pre-emit self-check (run before printing any line_items array).** The canonical checker is SKILL.md Section 4.2; run it against a file holding your candidate array (the program comes from the heredoc, the array from the file arg, so the array does NOT go on stdin). It is byte-exact with the real gate: `550000` fails here AND at compute.py; `550001` passes both.
```bash
# write the candidate line_items array to /tmp/wl_lines.json first, then:
python3 - /tmp/wl_lines.json <<'PY'
import sys, json
from decimal import Decimal, ROUND_HALF_UP
def rhu(x): return int(Decimal(str(x)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
li = json.load(open(sys.argv[1]))
bad = 0
req = {"description", "detail", "qty", "unit_price", "amount"}
for i, l in enumerate(li):
    if set(l) != req:
        print(f"LINE {i}: shape drift {sorted(set(l))} need {sorted(req)}"); bad += 1; continue
    want = rhu(Decimal(str(l["qty"])) * Decimal(str(l["unit_price"])))
    if want != int(l["amount"]):
        print(f"LINE {i} ({l['description']}): amount={l['amount']} but half-up={want}, EXIT-2 at /invoice"); bad += 1
print("PASS" if not bad else f"{bad} PROBLEM(S), DO NOT EMIT"); sys.exit(1 if bad else 0)
PY
```
When a line fails, recompute `amount` from the emitted 2-decimal `qty` via Rule 5. NEVER nudge `qty` to make the product land round, and NEVER sum per-entry amounts to form the line amount (that path drifts because each entry was already rounded).

---

## D. Multi-rate split (never blend rates into one line)

Two tasks on one project at different snapshotted rates cannot share a line item, because a single `amount` cannot satisfy Rule 5 for two rates. Split per rate, one line each:
```
Backend work   2.50h @ Rp 400.000/h  -> amount 1.000.000
Frontend work  1.50h @ Rp 350.000/h  -> amount   525.000
```
```json
[
  {"description":"Backend: sync endpoint","detail":"2026-W27 · 2 sessions · 2.50h @ Rp 400.000/h","qty":2.5,"unit_price":400000,"amount":1000000},
  {"description":"Frontend: order UI","detail":"2026-W27 · 1 session · 1.50h @ Rp 350.000/h","qty":1.5,"unit_price":350000,"amount":525000}
]
```
Each line independently satisfies `amount == ROUND_HALF_UP(qty x unit_price)`. If the two rates happened to be equal you MAY merge them by task grouping, but never merge distinct rates.

---

## E. Rate change mid-project (forward-only)

`/worklog rate "Lancar Jaya" "POS Integration" 450000` updates `rates.json` (atomically) and applies ONLY to entries logged AFTER the change. Existing entries keep their snapshotted `rate_idr`. A timesheet spanning the change therefore SPLITS by rate automatically (Section D). If a past entry genuinely must be re-rated (a retro price agreement), do it explicitly:
```
/worklog edit wl-20260701-xxxxxx rate_idr=450000     # recomputes amount, states the change; refuses if already billed
```
and say so in the timesheet detail. Never silently mass-re-price history.

---

## F. Retainer overage worked example

Config: `Maintenance Retainer` = `{rate_idr:0, billing:"retainer", monthly_cap_hours:10, overage_rate_idr:350000}`. In July the client logs 13h.
- **In-cap: 10h.** Tracked as normal entries (`rate_idr:0`), EXCLUDED from the billable timesheet (a rate-0 line is amount-0 noise on the PDF). `report` / `status` show "retainer utilization 10/10h this month".
- **Overage: 3h** (the portion past the monthly cap). One dedicated line:
```json
{"description":"Retainer overage","detail":"July 2026 · 3.00h past 10h cap @ Rp 350.000/h","qty":3.0,"unit_price":350000,"amount":1050000}
```
The cap is per CALENDAR MONTH; compute month-to-date retainer hours (`date -d <d> +%Y-%m` to bucket) when deciding in-cap vs overage, even though the timesheet may run weekly. If `overage_rate_idr` is absent, fall back to the client rate, then the default, and STATE which fallback you used.

---

## G. Failure-mode playbook (exact recovery commands)

**G1. Runaway timer (forgot to stop, elapsed huge).** `stop`'s sanity gate (elapsed > `max_session_hours`*60, default 8h, or a midnight crossing) blocks auto-finalize. Recover by logging the REAL duration, not the phantom clock span:
```bash
rm -f "$WL/active.json"                                            # discard the runaway timer
/worklog add "Lancar Jaya" "POS Integration" 2h30m "Shopee sync endpoint"   # log the real time you worked
```

**G2. Orphaned active.json after a reboot.** `status` flags it STALE (start-date not today, or elapsed absurd). It is a stale intent, not real work:
```bash
cat "$WL/active.json"          # inspect what it claims (client/project/task/start)
rm -f "$WL/active.json"        # discard, then /worklog add the real duration if any work happened
```

**G3. mark-billed over-flip recovery (late-logged hours got swept).** The trap: run a weekly timesheet (10 entries) and invoice INV-001, then log 2 more same-client same-week entries, then a bare-period `mark-billed --week` flips all 12 under INV-001. The 2 late entries are now marked billed but were never invoiced, so they vanish from `--unbilled`: lost revenue. Prevention is the snapshot binding (`mark-billed --timesheet <ref>` flips exactly the invoiced ids). To DETECT a mismatch before flipping, diff current-unbilled against the snapshot:
```bash
jq -s --arg c "Lancar Jaya" 'map(select(.client==$c and .billed==false) | .id)' "$WL/entries.jsonl" > /tmp/wl_cur.json
jq --slurpfile snap <(jq '.entry_ids' "$WL/timesheets/<ref>.json") \
   '{current:., snapshot:$snap[0], extra_not_in_snapshot:(map(select(. as $i | ($snap[0]|index($i))|not)))}' /tmp/wl_cur.json
```
`extra_not_in_snapshot` are the late-logged ids: they belong to the NEXT invoice, not this one. To UNDO an over-flip, back up and flip the wrongly-billed ids back:
```bash
cp "$WL/entries.jsonl" "$WL/entries.jsonl.bak"
echo '["wl-20260703-ccc333"]' > /tmp/wl_wrong.json                 # the ids that should not have been billed
flock -x "$WL/.lock" bash <<'EOF'
tmp=$(mktemp)
jq -c --slurpfile ids /tmp/wl_wrong.json '
  ($ids[0]) as $set
  | if (.id as $i | $set | index($i)) then .billed=false | .invoice_number=null | .timesheet_ref=null
    else . end
' ~/.claude/worklog/entries.jsonl > "$tmp" && mv "$tmp" ~/.claude/worklog/entries.jsonl
EOF
```
Verified: this leaves the genuinely-invoiced ids billed and returns only the wrong ones to `--unbilled`.

**G4. Correcting an already-billed entry.** NEVER silently rewrite a `billed:true` entry (it must stay reconcilable against the issued invoice). `edit` refuses on billed entries. Instead add a compensating entry and flag it:
```bash
# billed 3.00h but only 2.00h were real: credit 1.00h back on the NEXT invoice
/worklog add "Lancar Jaya" "POS Integration" -1h "Credit: over-logged on INV-202607-001"
```
Handle the credit as a negative line or a discount on the next `/invoice`, and tell the user the billed history is intentionally left intact.

**G5. Ledger backup before any bulk operation.** `cp "$WL/entries.jsonl" "$WL/entries.jsonl.bak"`. Never `rm` the ledger. If a rewrite produced garbage, restore from `.bak`.

---

## H. Portfolio capture tie-in (opt-in, capture-only, Toper-gated)

When a logged task carries `#portfolio` OR its text matches signal words (`root cause`, `novel`, `orchestration`, `new pattern`, `debug`, `architecture`), surface ONE line after the entry confirmation:
```
worth a portfolio story? capture via /journal or append to ~/claude/notes/portfolio-raw-material.md
```
That store is capture-only and productizing it is a locked Toper-gated decision (`reference_portfolio_raw_material`). **HARD RULE: worklog NEVER writes that file** and never auto-captures. The nudge is a pointer the user acts on, nothing more. `#tag` tokens in the task string (and `--tag <t>`) populate the entry's `tags[]`, which is what the nudge keys on.
