---
name: invoice
description: Generate comprehensive, professional invoices as PDF files for software house client billing. Use when the user needs to create an invoice, bill a client, generate a payment request, or says /invoice.
argument-hint: '["Client Name" "Project Name" amount] | [paste /worklog line_items] | list | mark-paid INV-... | void INV-... | [interactive]'
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
---

# /invoice - Software-House Client Billing

You produce a Stripe/Linear-grade **commercial invoice** PDF that bills an
**external client** for software-house work, from config-driven company identity
and verified, deterministic money math. Every invoice is triple-saved (PDF + MD +
JSON record). This skill is the **bill** at the end of the delivery triad.

This file is the operational contract. Encyclopedic depth lives in `references/`
(read on demand, never all at once):

| Reference | Read when |
|---|---|
| `references/compute.py` | ALWAYS - the deterministic money engine (you call it) |
| `references/invoice-template.html` | At render time (§8) |
| `references/id-tax.md` | Any tax question: PPN mechanism, PPh 23, Faktur Pajak, NPWP, dates |
| `references/worklog-contract.md` | Ingesting a `/worklog` timesheet (§3) |

Absolute paths: prefix with `/home/christopher/.claude/skills/invoice/`.

---

## 0. BOUNDARY - what this skill is and is NOT

**The delivery triad (do not blur these):**

```
/proposal --> pre-sales: scope, quote, SOW (what we WILL do, for how much)
/worklog  --> time source: billable hours ledger (how the hours accrued)
/invoice  --> THE BILL: the commercial invoice that requests payment
```

- **This is CLIENT billing (external, one-off / milestone / retainer).** It bills
  a client company for a software-house engagement.
- **This is NOT `aenoxa_billing`.** `aenoxa_billing` (:50054) is the internal
  Pulse SaaS money system (tenant subscriptions / plans / invoices / payments via
  DuitKu / entitlements, `Money int64` IDR). It is a **completely separate
  system**. NEVER wire this skill to it, its schema, or its DB. Neither reads nor
  writes the other. (Ref: memory `reference_billing_tenantid_is_user_id`,
  `reference_aenoxa_ecosystem_recon`.)
- **This produces a COMMERCIAL INVOICE, not a Faktur Pajak.** A Faktur Pajak is
  the legal tax document, issued only by a PKP through Coretax e-Faktur. This PDF
  never replaces it. (See `references/id-tax.md` §4.)
- **Provenance is upstream:** every line item comes from `/worklog` (billable
  hours) or an explicit scope/milestone (`/proposal` SOW). This skill NEVER
  invents line items or amounts.

---

## 1. HARD RULES (NEVER / ALWAYS - the spine)

These are non-negotiable. A violation is a defect, not a style choice.

**Tax & legitimacy**
- **NEVER apply PPN unless `is_pkp == true` AND a real (non-placeholder) company
  NPWP is set.** PPN defaults OFF; the interactive PPN question defaults to NO.
  A non-PKP charging PPN collects a tax it cannot remit (see §6, id-tax §1-2).
- **NEVER present PPh 23 as the vendor's own deduction to remit.** It is withheld
  BY THE CLIENT. Render it ONLY as an informational net-payable memo (2% with
  NPWP, 4% without; base = tax_base excl-PPN). (id-tax §3.)
- **NEVER call the output a Faktur Pajak.** If `is_pkp`, tell the user to issue
  the Faktur Pajak separately via Coretax e-Faktur.

**Identity & provenance**
- **NEVER emit an invoice while any legal/payment identity field is a
  placeholder** (default `PT Aenoxa Teknologi`, any `XX…`/`+62 XXX`/`XXXX-XXX-XXX`
  mask). Refuse and point the user to `~/.claude/invoices/config.json` (§2, §4).
- **NEVER fabricate client details or line items.** Each line item MUST trace to
  `source: worklog:<id-range>` OR `source: scope:<SOW/milestone ref>`. No source
  tag → the item does not exist.
- **NEVER conflate with `aenoxa_billing`; NEVER write to `~/.claude/worklog/`.**

**Money math**
- **NEVER hand-compute or hand-format money.** ALWAYS run
  `references/compute.py`; the rendered totals MUST byte-equal its `*_fmt`
  outputs. No browser JS formatting, no mental arithmetic.
- **ALWAYS pass the arithmetic gate before render:** `subtotal == Σ(line.amount)`;
  `tax_base == subtotal - discount`; `ppn == round_half_up(tax_base × rate)`;
  `grand_total == tax_base + ppn`. `compute.py` enforces these and exits non-zero
  on mismatch. Abort render on any non-zero exit; show the diff.
- **Currency is fixed:** display `Rp 15.000.000` (dot thousands, no decimals).
  `unit_price`/`amount` are integer IDR; `qty` may be a 2-decimal hours value.

**Output & PDF**
- **PDF uses a FRESH headless `google-chrome-stable` instance ONLY.** NEVER attach
  to the live qutebrowser (`localhost:9222`) and NEVER use the `/agent-browser`
  skill for PDF gen - per that skill's HR-2, the qutebrowser is Christopher's live
  browser and is never touched/killed. A throwaway `--print-to-pdf` Chrome is a
  separate process and does not touch it. (§9.)
- **ALWAYS verify the PDF after generation:** exit 0 AND file exists AND size > 0
  AND page-count ≥ 1. NEVER report success on a 0-byte or absent PDF.

**Close the loop**
- **When line items came from `/worklog`, ALWAYS end with the exact reminder:**
  `/worklog mark-billed "<client>" --invoice <INV-...> [period]` (prevents
  double-billing). This skill cannot flip the worklog `billed` flag itself.

**Numbering**
- **Invoice numbers are per-month sequential `INV-YYYYMM-NNN`.** ALWAYS scan
  `~/.claude/invoices/INV-<targetYYYYMM>-*.json` for the current max before
  assigning (§7).

---

## 2. SETUP & CONFIG

### 2.1 Ensure dirs (idempotent)

```bash
mkdir -p ~/.claude/invoices ~/Documents/invoices
```

- `~/.claude/invoices/` - JSON records + config (the source of truth).
- `~/Documents/invoices/` - human deliverables (PDF + MD).

### 2.2 Config - read, then merge-in new defaults (never overwrite)

Config lives at `~/.claude/invoices/config.json` and is **live user state**
(shared with `/proposal`). Read it first. It is **backward-compatible**: an
existing file may lack the newer fields.

**Full current schema** (additive fields marked NEW):

```json
{
  "entity_mode": "perorangan",
  "company": {
    "name": "PT Aenoxa Teknologi",
    "address": "Jakarta, Indonesia",
    "phone": "+62 XXX-XXXX-XXXX",
    "email": "billing@aenoxa.com",
    "website": "https://aenoxa.com",
    "npwp": "XX.XXX.XXX.X-XXX.XXX"
  },
  "bank": {
    "name": "Bank Central Asia (BCA)",
    "account_holder": "PT Aenoxa Teknologi",
    "account_number": "XXXX-XXX-XXX",
    "swift_code": "CENAIDJA"
  },
  "defaults": {
    "currency": "IDR",
    "currency_symbol": "Rp",
    "is_pkp": false,
    "tax_name": "PPN",
    "tax_rate": 0.11,
    "ppn": {
      "effective_rate": 0.11,
      "formal_rate": 0.12,
      "mechanism": "DPP Nilai Lain 11/12 (PMK 131/2024 + PMK 11/2025)",
      "last_verified": "2026-07"
    },
    "pph23": { "enabled": false, "rate": 0.02, "client_withholds": true },
    "payment_terms_days": 14,
    "late_fee_percentage": 2,
    "language": "bilingual"
  }
}
```

Field meaning (the ones that gate behavior):
- **`entity_mode`** NEW - `perorangan` (individual; company block = personal
  identity, NPWP is the 16-digit NIK-based individual NPWP or omitted) or `badan`
  (a real registered PT with NPWP Badan). Default `perorangan` - the operator's
  current reality (PT Aenoxa postponed; memory `project_pt_aenoxa`).
- **`defaults.is_pkp`** NEW - the PPN gate. `false` by default. PPN can ONLY apply
  when `true` AND NPWP is real (HARD RULE §1).
- **`defaults.tax_rate` / `defaults.ppn.effective_rate`** - the effective PPN rate
  (11% via DPP Nilai Lain). Kept for backward-compat; treat as a moving target
  (id-tax §2). `ppn.last_verified` stamps when it was last confirmed.
- **`defaults.pph23`** NEW - the withholding memo. `enabled:false` default; `rate`
  0.02 (with NPWP) / 0.04 (no NPWP); `client_withholds` = whether this client
  deducts it.

**Merge rule (HARD):** if the file exists, KEEP every existing value; only ADD
absent NEW keys with their defaults. Never silently overwrite a value the user set
(especially real company/bank details). Write the merged file back only if you
actually added keys, and tell the user which keys you added.

If the file does NOT exist, create it from the schema above and tell the user:
"Created config template at `~/.claude/invoices/config.json`. Fill in your real
identity + bank details before issuing (the skill refuses to render with
placeholders)."

### 2.3 Placeholder detection (the identity gate - §4 uses this)

A field is a **placeholder** (renders the invoice illegitimate) if it matches
`[Xx]{2,}` (two+ consecutive X) OR equals a known template default. Check with:

```bash
python3 - "$(cat ~/.claude/invoices/config.json)" <<'PY'
import sys, json, re
cfg = json.loads(sys.argv[1])
DEF_NAMES = {"PT Aenoxa Teknologi"}
def ph(v):  # is this a placeholder?
    return v is None or v == "" or bool(re.search(r"[Xx]{2,}", str(v))) or str(v) in DEF_NAMES
c, b = cfg.get("company", {}), cfg.get("bank", {})
hard = {
  "company.name": c.get("name"), "company.phone": c.get("phone"),
  "bank.account_holder": b.get("account_holder"),
  "bank.account_number": b.get("account_number"),
}
bad = {k: v for k, v in hard.items() if ph(v)}
npwp_ph = ph(c.get("npwp"))
is_pkp = cfg.get("defaults", {}).get("is_pkp", False)
print(json.dumps({"blocking": bad, "npwp_placeholder": npwp_ph, "is_pkp": is_pkp}))
PY
```

- Any key in `blocking` → **refuse to render** (name / phone / account holder /
  account number are needed for ANY payable invoice).
- `npwp_placeholder && is_pkp` → **refuse** (PPN needs a real NPWP).
- `npwp_placeholder && !is_pkp` → allowed, but **OMIT the NPWP line** from the PDF
  (never print a fake tax ID; a perorangan non-PKP may legitimately have none).

---

## 3. INPUT - arguments, `/worklog` ingestion, interactive

Parse `$ARGUMENTS`. First token may be a **sub-command**: `list`, `mark-paid`,
`void` (→ §11). Otherwise it is invoice creation.

### 3.1 Argument forms (creation)

1. **Full:** `/invoice "Client Name" "Project Name" 15000000` - client, project,
   single total in IDR (no separators).
2. **Partial:** `/invoice "Client Name"` - ask for the rest.
3. **None:** `/invoice` - gather interactively (§3.3).
4. **Pasted `/worklog` line items** (the primary flow) - §3.2.

### 3.2 Ingesting a `/worklog` timesheet (PRIMARY flow)

`/worklog timesheet "<client>" --unbilled` emits a fenced JSON array under
`=== /invoice line_items (paste into /invoice) ===`. When the user pastes it:

1. **Validate shape** - each element is `{description, detail?, qty, unit_price,
   amount}`, `qty` a 2-decimal hours number, `unit_price`/`amount` integer IDR.
   (Full contract: `references/worklog-contract.md`.)
2. **Tag provenance** - set `source: "worklog:<timesheet ref or id-range>"` on
   each item. This satisfies the provenance HARD RULE.
3. Carry `qty` through verbatim (do NOT round hours to integers - a 2.50h line
   stays 2.50). `compute.py` re-verifies `amount == round(qty × unit_price)`.
4. After issuing, print the `mark-billed` reminder (HARD RULE §1).

Do NOT re-key hours by hand and do NOT read `~/.claude/worklog/` - consume the
pasted block only.

### 3.3 Interactive gather (only what's missing - never re-ask known facts)

Ask in batches; skip anything already supplied or on a prior invoice to the same
client (scan `~/.claude/invoices/*.json`).

- **Batch 1 - Client:** company name · project · contact person · email ·
  (address + client NPWP optional).
- **Batch 2 - Line items:** each item's description + amount, with its
  **provenance** (worklog or explicit scope/milestone). If the user gave a single
  lump total, ask what scope it covers and tag `source: scope:<ref>`. PO number
  (optional). Due date (default `payment_terms_days` from today, or 7/14/30).
- **Batch 3 - Tax & extras (brief):**
  - **Apply PPN?** default **NO**. Only offer YES if `is_pkp==true` AND NPWP real;
    otherwise state PPN is off because non-PKP (id-tax §1).
  - **Client withholds PPh 23?** (typical for corporate/badan clients). If yes,
    set the memo (rate 2% with NPWP / 4% without).
  - Discount (fixed IDR or `%`). Custom notes.

For milestone shorthand ("30% upfront of 50jt"), compute the amount
(0.30 × 50.000.000 = 15.000.000) and set the description to the milestone
(`"<Project> - 30% Upfront Payment"`), `source: scope:<milestone ref>` (§12).

---

## 4. PRE-ISSUE GATE (ALL must pass before any PDF render)

Run this checklist. **Any FAIL → stop with the specific remedy; do not render.**

| # | Gate | Pass condition | On fail |
|---|---|---|---|
| 1 | **config-real** | §2.3 returns empty `blocking`; NPWP handled per rule | Print the placeholder fields + `~/.claude/invoices/config.json`; refuse |
| 2 | **provenance** | every line item has a `source` (`worklog:` or `scope:`) | Name the unsourced item; ask for its source; refuse |
| 3 | **arithmetic** | `compute.py` exits 0 | Show its stderr diff; fix the offending line; re-run; refuse until 0 |
| 4 | **tax-legitimacy** | PPN present ONLY if `is_pkp==true` AND NPWP real | Turn PPN off; recompute; note why (non-PKP) |
| 5 | **number-continuity** | INV sequence scanned for the target month (§7) | Re-scan before assigning |

Only when 1-5 all pass do you proceed to §5 render.

---

## 5. MONEY COMPUTE CONTRACT (deterministic - the ONLY math step)

All totals + all IDR formatting come from `references/compute.py`. You NEVER
compute or format money yourself.

**Call it** with the input assembled from line items + config flags:

```bash
cat > /tmp/inv-input-<NUMBER>.json <<'JSON'
{
  "line_items": [
    {"description":"Shopee sync endpoint","detail":"3 sessions · 2.50h","qty":2.5,"unit_price":400000,"amount":1000000},
    {"description":"Code review + deploy","qty":1.5,"unit_price":400000,"amount":600000}
  ],
  "discount": 0,
  "apply_ppn": false,
  "ppn_rate": 0.11,
  "tax_name": "PPN",
  "apply_pph23": true,
  "pph23_rate": 0.02
}
JSON
python3 /home/christopher/.claude/skills/invoice/references/compute.py \
  < /tmp/inv-input-<NUMBER>.json > /tmp/inv-totals-<NUMBER>.json
echo "compute_exit=$?"
cat /tmp/inv-totals-<NUMBER>.json
```

**Contract:**
- Inputs: `line_items[]` + `{discount, apply_ppn, ppn_rate, tax_name, apply_pph23,
  pph23_rate}`. `discount` is `0` | integer IDR | `{"pct": N}`.
- Outputs (integers IDR + `*_fmt` display strings): `subtotal, discount, tax_base,
  ppn_amount, grand_total, pph23_amount, net_payable`.
- **Fixed tax order:** `tax_base = subtotal - discount`; PPN on `tax_base`; PPh 23
  memo base = `tax_base` (DPP excl-PPN). Rounding = ROUND_HALF_UP to integer
  rupiah (not banker's - verified).
- **Exit codes:** `0` ok · `2` a line's `amount ≠ qty×unit_price` · `3` internal
  self-check failed · `4` malformed input. **On any non-zero, DO NOT RENDER** -
  surface the stderr diff and fix the input (§14).

The IDR format is `"Rp " + "{:,.0f}".format(n).replace(",",".")` → `Rp
15.000.000`. It exists only inside `compute.py`; do not reimplement it.

Substitute ONLY these `*_fmt` outputs into the template. The rendered
`{{SUBTOTAL}}`, `{{TAX_AMOUNT}}`, `{{GRAND_TOTAL}}`, `{{PPH23_AMOUNT}}`,
`{{NET_PAYABLE}}` MUST byte-equal `subtotal_fmt`, `ppn_amount_fmt`,
`grand_total_fmt`, `pph23_amount_fmt`, `net_payable_fmt`.

---

## 6. TAX DECISION TABLE (2 flags → what shows)

Two booleans decide the entire tax presentation: `is_pkp` (may we charge PPN?)
and `client_withholds` (does the client deduct PPh 23?).

| is_pkp | client withholds PPh 23 | PPN line | PPh 23 memo | grand_total | net_payable line |
|:---:|:---:|:---:|:---:|---|:---:|
| Y | Y | shown | shown | subtotal + PPN | shown (grand - PPh23) |
| Y | N | shown | - | subtotal + PPN | - |
| N | Y | - | shown | = subtotal (no PPN) | shown (grand - PPh23) |
| N | N | - | - | = subtotal | - |

- **Row 3 is the operator's current default reality** (perorangan, non-PKP,
  billing a corporate client that withholds).
- **Row 4** is a perorangan billing an individual / non-withholder.
- `compute.py` renders exactly this: `apply_ppn` follows `is_pkp`; `apply_pph23`
  follows `client_withholds`.

**Set `apply_ppn` and `apply_pph23` in the compute input to match the row.** Full
mechanism, rates, sources, and the moving-target caveat: `references/id-tax.md`.

---

## 7. INVOICE NUMBER (per-month sequential)

Format `INV-YYYYMM-NNN`: `YYYY`+`MM` = the invoice's month (usually today WIB;
if back-dating, the back-dated month), `NNN` = zero-padded sequence within THAT
month starting `001`.

```bash
TARGET=$(TZ=Asia/Jakarta date +%Y%m)   # or the back-dated YYYYMM
python3 - "$TARGET" <<'PY'
import sys, glob, os, re
target = sys.argv[1]
mx = 0
for f in glob.glob(os.path.expanduser(f"~/.claude/invoices/INV-{target}-*.json")):
    m = re.search(rf"INV-{target}-(\d+)\.json$", os.path.basename(f))
    if m: mx = max(mx, int(m.group(1)))
print(f"INV-{target}-{mx+1:03d}")
PY
```

Scan the **target month specifically** (a `ls | sort | tail` over all months can
miss the current-month max when back-dating). If none exist for the month → `001`.

---

## 8. RENDER (fill the template - never rewrite it)

1. **Read** `references/invoice-template.html`. It is the verified Stripe/Linear
   A4 design; do NOT redesign it. Its header comment carries the placeholder
   legend, the customization rules, and the print-typography carve-out.
2. **Substitute** every `{{PLACEHOLDER}}`: company from config, client from input,
   line items (repeat the `<tr>`), and **all money from the `*_fmt` compute
   outputs** (§5). Dates per `references/id-tax.md` §6 (human `D MMMM YYYY` in the
   client's locale; ID month names for ID clients).
3. **Drop rows that don't apply** (per the template's CUSTOMIZATION list): no PO →
   remove that row; no discount → remove it; PPN off → remove the tax row; PPh 23
   off → remove BOTH memo + net-payable rows; NPWP placeholder/empty → remove the
   NPWP line; no custom notes → remove that paragraph. **Always keep the bilingual
   EN/ID** payment + terms labels (Indonesia market - non-negotiable).
4. **Write** the filled HTML to a temp file: `/tmp/invoice-<NUMBER>.html`.

**Print-document typography carve-out (documented, not a violation):** the house
UI floor (≥12px, weight ≥500, no Inter/Roboto) is a SCREEN rule. This is a dense
PRINT A4 doc: labels may be 10-11px caps, secondary text weight 400, and the
neutral system font stack (Inter/Roboto as fallbacks) is deliberate so the invoice
renders identically anywhere. Carve-out floor: no print text < 9px; primary
content (client name, amounts, grand total) ≥ 12px; grand total is the largest
element. Keep it; do not "fix" sizes up.

---

## 9. PDF VERIFY GATE (fresh headless Chrome + hard verification)

Generate with a FRESH headless `google-chrome-stable` (verified v144; the live
qutebrowser is NEVER touched - HARD RULE §1). **Capture stderr - do not
`2>/dev/null`** (Chrome prints "N bytes written to file …" there, a useful success
signal, and errors too):

```bash
OUT="$HOME/Documents/invoices/<NUMBER>.pdf"
google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$OUT" --no-pdf-header-footer --print-to-pdf-no-header \
  /tmp/invoice-<NUMBER>.html 2>/tmp/invoice-<NUMBER>.chrome.log
RC=$?
echo "chrome_exit=$RC"; cat /tmp/invoice-<NUMBER>.chrome.log
```

Fallback (only if `google-chrome-stable` is genuinely absent): the same flags with
`/opt/google/chrome/google-chrome`. Nothing else is installed on this box
(chromium / weasyprint / wkhtmltopdf absent; pandoc has NO LaTeX engine, so
md→pdf is NOT viable - do not chase them; §14).

**Verify (ALL must hold - else it is NOT done, §14):**

```bash
pages=$(pdfinfo "$OUT" 2>/dev/null | awk '/^Pages:/{print $2}')
[ "$RC" -eq 0 ] && [ -s "$OUT" ] && [ "${pages:-0}" -ge 1 ] \
  && echo "PDF OK - $(stat -c%s "$OUT") bytes, ${pages} page(s)" \
  || echo "PDF FAIL - rc=$RC size=$(stat -c%s "$OUT" 2>/dev/null || echo 0) pages=${pages:-0}"
```

`pdfinfo` (poppler) is the page-count tool; `qpdf --show-npages "$OUT"` or `file
"$OUT"` (reports "N page(s)") are fallbacks if pdfinfo is missing. On success,
clean up temp files:

```bash
rm -f /tmp/invoice-<NUMBER>.html /tmp/inv-input-<NUMBER>.json /tmp/inv-totals-<NUMBER>.json /tmp/invoice-<NUMBER>.chrome.log
```

---

## 10. SAVE RECORDS (JSON + MD + integrity re-read)

### 10.1 JSON record → `~/.claude/invoices/<NUMBER>.json`

Store computed values (from `compute.py`) + provenance + status:

```json
{
  "invoice_number": "INV-202607-001",
  "invoice_date": "2026-07-03",
  "due_date": "2026-07-17",
  "status": "issued",
  "entity_mode": "perorangan",
  "is_pkp": false,
  "client": { "name": "Client Co", "address": null, "contact": "PIC", "email": "pic@client.com", "npwp": null },
  "project": "Project Name",
  "po_number": null,
  "line_items": [
    { "description": "Shopee sync endpoint", "detail": "3 sessions · 2.50h", "qty": 2.5, "unit_price": 400000, "amount": 1000000, "source": "worklog:2026-06-09..06-13" }
  ],
  "subtotal": 1600000,
  "discount": 0,
  "tax_base": 1600000,
  "tax_name": "PPN",
  "ppn_rate": 0.11,
  "ppn_amount": 0,
  "grand_total": 1600000,
  "pph23_rate": 0.02,
  "pph23_amount": 32000,
  "net_payable": 1568000,
  "payment_terms_days": 14,
  "currency": "IDR",
  "notes": null,
  "pdf_path": "/home/christopher/Documents/invoices/INV-202607-001.pdf",
  "md_path": "/home/christopher/Documents/invoices/INV-202607-001.md",
  "created_at": "2026-07-03T10:00:00+07:00"
}
```

- Every `line_items[]` entry carries its `source` (provenance ledger).
- Money fields are the integers from `compute.py` (never re-typed by hand).
- `status` ∈ `issued | paid | void` (§11).

### 10.2 Markdown → `~/Documents/invoices/<NUMBER>.md`

A plain-text mirror (same header/bill-to/line-items/totals/payment/terms). Include
the PPh 23 memo + net-payable line ONLY when the memo applies. Use the same
`*_fmt` strings. (Structure identical to the PDF; MD is for quick reading + grep.)

### 10.3 Output-integrity check (before printing success)

Re-read the JSON you just wrote and assert it matches the computed values:

```bash
python3 - "<NUMBER>" <<'PY'
import sys, json, os
n = sys.argv[1]
r = json.load(open(os.path.expanduser(f"~/.claude/invoices/{n}.json")))
assert r["subtotal"] == sum(li["amount"] for li in r["line_items"]), "subtotal drift"
assert r["tax_base"] == r["subtotal"] - r["discount"], "tax_base drift"
assert r["grand_total"] == r["tax_base"] + r["ppn_amount"], "grand_total drift"
assert r["net_payable"] == r["grand_total"] - r["pph23_amount"], "net_payable drift"
assert all("source" in li for li in r["line_items"]), "a line item lost its source"
assert os.path.exists(r["pdf_path"]) and os.path.getsize(r["pdf_path"]) > 0, "pdf missing/empty"
print("record integrity OK")
PY
```

If it fails, the invoice is NOT done - fix before the summary (§15).

---

## 11. STATUS LIFECYCLE & RECEIVABLES (sub-commands)

The JSON records ARE the receivables ledger. Lightweight ops over
`~/.claude/invoices/*.json`:

- **`/invoice list [--unpaid | --all] [client]`** - table of invoices (No · date ·
  client · grand_total · status · due). `--unpaid` = `status=="issued"`; flag any
  past-due (`due_date < today`, status still `issued`) as **OVERDUE**. Read-only.
- **`/invoice mark-paid INV-YYYYMM-NNN [date]`** - set `status:"paid"`,
  `paid_at:<date>`. Confirm the invoice + amount before writing. Atomic write
  (temp file + `mv`), never partial.
- **`/invoice void INV-YYYYMM-NNN "<reason>"`** - set `status:"void"`,
  `void_reason`. NEVER delete the record or renumber (audit trail). A voided
  number is retired, not reused.

These mutate only the invoice JSON, never `/worklog`. (Deep AR aging beyond
overdue-flagging is out of scope - the ledger + `list --unpaid` is the view.)

---

## 12. MILESTONE & RECURRING

**Milestone (software-house 30/40/30 framework).** For staged project billing,
each invoice bills ONE milestone as a scope-sourced line item:

- `"<Project> - Milestone 2 (40% on mid-sprint)"`, amount from the SOW,
  `source: scope:<SOW ref>` (no worklog trace, but explicit scope provenance).
- Store the milestone (pct + trigger) in the JSON `notes`/line detail for the next
  invoice. Same compute → gate → render → verify path.

**Recurring / monthly.** Read the most recent invoice for that client
(`~/.claude/invoices/`), copy client + line-item shape, update the number, dates,
and any changed amounts, then run the full path. If re-invoicing the same
client + period, **warn about double-bill risk and require confirmation** (§14).

---

## 13. WORKED RECIPES

**Recipe A - worklog → invoice (PRIMARY, non-PKP default).**
1. User pastes the `=== /invoice line_items ===` JSON from `/worklog timesheet
   "<client>" --unbilled`.
2. Validate shape (§3.2) → tag each `source: worklog:<ref>`.
3. Config: `is_pkp=false` → `apply_ppn=false`. Client is a corporate withholder →
   `apply_pph23=true, rate 0.02`.
4. `compute.py` → arithmetic gate passes → PRE-ISSUE GATE (§4) all green.
5. Assign `INV-YYYYMM-NNN` (§7) → render (§8) → PDF verify (§9) → save JSON/MD
   (§10).
6. **Print:** `/worklog mark-billed "<client>" --invoice <INV-...> [period]`.

**Recipe B - milestone invoice (30/40/30, scope-sourced).**
Scope line `"Project X - Milestone 2 (40%)"`, amount from SOW,
`source: scope:<SOW#>`. No worklog. Same compute/gate/render/verify. No
mark-billed reminder (not worklog-sourced).

**Recipe C - perorangan non-PKP with PPh 23 memo (current reality).**
Company block = personal identity, NPWP omitted or 16-digit NIK-based. `is_pkp
=false` → no PPN. Corporate client withholds → memo shows `Total 10.000.000 -
PPh 23 (2%) 200.000 = Net payable 9.800.000`. Explicitly NOT a Faktur Pajak. If
NPWP is a placeholder, the NPWP line is dropped from the PDF (§2.3).

---

## 14. FAILURE PLAYBOOK (symptom → exact recovery)

- **Placeholder config (gate 1 fail).** Refuse to render. Print each still-
  placeholder field + `~/.claude/invoices/config.json`. Recovery: user fills real
  values → re-run §2.3 until `blocking` is empty.
- **Unsourced line item (gate 2 fail).** Name it, ask for `worklog:` or `scope:`
  provenance, refuse until tagged. Never invent a source.
- **Arithmetic mismatch (`compute.py` exit 2/3).** Do NOT render. Show the stderr
  diff (it names the line + stated vs recomputed amount). Fix the offending
  `amount`/`qty`/`unit_price`, re-run compute until exit 0.
- **Chrome missing.** `command -v google-chrome-stable || command -v
  google-chrome`. If both absent, print: *"PDF engine not found - install
  google-chrome-stable (chromium / weasyprint / wkhtmltopdf are NOT on this
  box)."* Do NOT chase pandoc/puppeteer (no LaTeX engine → pandoc md→pdf can't
  make a PDF here).
- **0-byte / absent PDF (verify gate fail).** Re-run the Chrome command and READ
  `/tmp/invoice-<NUMBER>.chrome.log` (you kept stderr). Common causes: bad HTML
  path, missing `--no-sandbox` in a restricted env, or the HTML never got written.
  Fix and regenerate; never report success on a failed verify.
- **Content overflow (>~8 line items, totals orphaned).** The template's totals /
  payment / notes blocks already carry `page-break-inside:avoid`. Re-verify
  page-count and that the grand total isn't stranded alone on page 2; if it is,
  trim line-item detail text or split the invoice.
- **Double-bill risk.** Re-invoicing the same client+period → warn, require
  confirmation, and always emit the `mark-billed` reminder so worklog closes those
  hours.
- **Tax uncertainty.** Rate/objek unclear or high-value invoice → read
  `references/id-tax.md`, re-verify against the current PMK, flag the assumption to
  the user. Never bill a guessed rate silently.

---

## 15. OUTPUT - success summary

Only after §4 gate + §9 verify + §10 integrity all pass:

```
Invoice Generated
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Invoice:    {{INVOICE_NUMBER}}   ({{ENTITY_MODE}}, {{PKP_LABEL}})
  Client:     {{CLIENT_NAME}}
  Project:    {{PROJECT_NAME}}
  Total:      {{GRAND_TOTAL}}
  {{#if pph23}}Net payable: {{NET_PAYABLE}}  (after PPh 23 {{RATE}}% withheld by client){{/if}}
  Due:        {{DUE_DATE}}

  PDF:        ~/Documents/invoices/{{INVOICE_NUMBER}}.pdf   ({{BYTES}} bytes, {{PAGES}}p)
  Markdown:   ~/Documents/invoices/{{INVOICE_NUMBER}}.md
  Record:     ~/.claude/invoices/{{INVOICE_NUMBER}}.json

{{#if worklog_sourced}}Next: /worklog mark-billed "{{CLIENT_NAME}}" --invoice {{INVOICE_NUMBER}} [period]{{/if}}
{{#if is_pkp}}Note: this is a COMMERCIAL invoice. Issue the Faktur Pajak separately via Coretax e-Faktur.{{/if}}
```

Always show the `mark-billed` line for worklog-sourced invoices, and the Faktur
Pajak note when `is_pkp`.

---

## 16. RULES RECAP (never-do)

- **Never** apply PPN unless `is_pkp` + real NPWP; PPN defaults OFF (id-tax §1-2).
- **Never** present PPh 23 as a vendor deduction - it's a client-withholding memo.
- **Never** call the output a Faktur Pajak.
- **Never** render with a placeholder identity/bank field; never hardcode
  `PT Aenoxa Teknologi` - identity is config-driven.
- **Never** invent a line item or amount; every item is `worklog:` or `scope:`
  sourced.
- **Never** hand-compute or hand-format money - `compute.py` only; totals must
  byte-equal its output; abort render on any non-zero exit.
- **Never** touch the live qutebrowser / `/agent-browser` for PDF gen; fresh
  headless Chrome only.
- **Never** report success on a 0-byte / absent / 0-page PDF.
- **Never** conflate with `aenoxa_billing`; never write to `~/.claude/worklog/`.
- **Always** currency `Rp 15.000.000`; integer `unit_price`/`amount`; `qty` may be
  2-decimal hours.
- **Always** per-month `INV-YYYYMM-NNN`, scanned for the target month.
- **Always** bilingual EN/ID payment + terms labels.
- **Always** clean up `/tmp` artifacts after a verified PDF.
- **Always** the `mark-billed` reminder for worklog-sourced invoices.
- **Dates:** human `D MMMM YYYY` (ID month names for ID clients), JSON ISO 8601.
