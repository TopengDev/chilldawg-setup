---
name: invoice
description: Generate comprehensive, professional invoices as PDF files for software house client billing. Use when the user needs to create an invoice, bill a client, generate a payment request, or says /invoice.
argument-hint: ["Client Name" "Project Name" amount] or [interactive]
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
---

# Invoice Generator

You generate professional, Stripe-quality PDF invoices for PT Aenoxa Teknologi (or the configured company). Invoices are saved as PDF, markdown, and JSON records.

---

## 1. SETUP — Ensure Environment

Before anything else, verify the environment:

```bash
mkdir -p ~/.claude/invoices ~/Documents/invoices
```

### 1.1 Configuration

Check if `~/.claude/invoices/config.json` exists. If it does, read it. If it does NOT exist, create it with this default template:

```json
{
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
    "tax_rate": 0.11,
    "tax_name": "PPN",
    "payment_terms_days": 14,
    "late_fee_percentage": 2,
    "language": "bilingual"
  }
}
```

After creating the template, inform the user: "I've created a config template at `~/.claude/invoices/config.json`. Please update it with your real company details. Proceeding with placeholder values for now."

---

## 2. ARGUMENTS — Parse Input

Parse `$ARGUMENTS` to extract invoice details.

**Supported formats:**

1. **Full arguments**: `/invoice "Client Name" "Project Name" 15000000`
   - First quoted string = client name
   - Second quoted string = project name
   - Number = total amount in IDR (no separators)

2. **Partial arguments**: `/invoice "Client Name"` — ask for remaining details interactively

3. **No arguments**: `/invoice` — gather everything interactively

---

## 3. GATHER DETAILS — Interactive Collection

If any details are missing, ask interactively in batches. Never ask for information you already have from arguments or from previous invoices to the same client.

### Batch 1: Client Details
- **Client company name** — who are we billing?
- **Project name** — what is this invoice for?
- **Client contact person** — name of the person receiving the invoice
- **Client email** — where to send the invoice

### Batch 2: Invoice Details
- **Line items** — ask the user to describe what's being billed. Examples:
  - "Website development - Phase 1 (30% upfront)" — Rp 15.000.000
  - "UI/UX Design - Homepage redesign" — Rp 5.000.000
  - "Monthly maintenance - March 2026" — Rp 3.000.000
  - If user gave a single amount in args, ask for a description of what it covers
- **PO number** — optional, ask if they have one
- **Due date** — default to config's payment_terms_days from today, or ask if they want different terms (7/14/30 days)

### Batch 3: Optional Details (ask briefly)
- **Apply tax/PPN?** — default yes at 11%, ask if they want to exclude it
- **Discount?** — any discount to apply (percentage or fixed amount)
- **Client address** — for the Bill To section (optional, can be left minimal)
- **Client NPWP** — optional, for tax purposes
- **Custom notes** — any additional notes for the invoice

For milestone-based invoicing, if the user says something like "30% upfront for Project X, total 50jt", calculate:
- Line item: "Project X - 30% Upfront Payment"
- Amount: Rp 15.000.000 (30% of 50.000.000)

---

## 4. INVOICE NUMBER — Auto-Generate

Read all JSON files in `~/.claude/invoices/` to determine the next invoice number.

Format: `INV-YYYYMM-NNN` where:
- `YYYY` = current year
- `MM` = current month (zero-padded)
- `NNN` = sequential number within the month (zero-padded to 3 digits, starting at 001)

```bash
ls ~/.claude/invoices/INV-*.json 2>/dev/null | sort | tail -5
```

Logic:
1. Find all invoices for the current month (e.g., `INV-202603-*.json`)
2. Take the highest NNN value
3. Increment by 1
4. If no invoices exist for this month, start at 001

---

## 5. GENERATE INVOICE — HTML Template

Create a temporary HTML file at `/tmp/invoice-{NUMBER}.html` using the template below. Replace all `{{PLACEHOLDER}}` values with actual data.

### Currency Formatting

All IDR amounts must use Indonesian formatting:
- Symbol: `Rp` followed by a space
- Thousands separator: `.` (dot)
- No decimal places for IDR
- Example: `Rp 15.000.000`

Use this JavaScript function in the template for formatting:

```javascript
function formatIDR(amount) {
  return 'Rp ' + amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}
```

### HTML Invoice Template

Generate an HTML file with this structure. The CSS must be embedded (no external stylesheets). The design should be clean, modern, and minimal — inspired by Stripe/Linear invoice aesthetics.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Invoice {{INVOICE_NUMBER}}</title>
<style>
  @page {
    size: A4;
    margin: 0;
  }
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Inter, Roboto, Helvetica, Arial, sans-serif;
    color: #1a1a2e;
    background: #fff;
    font-size: 13px;
    line-height: 1.5;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .invoice-page {
    width: 210mm;
    min-height: 297mm;
    padding: 40px 48px;
    margin: 0 auto;
    position: relative;
    display: flex;
    flex-direction: column;
  }

  /* ---- Header ---- */
  .header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 40px;
    padding-bottom: 24px;
    border-bottom: 2px solid #1a1a2e;
  }
  .company-info h1 {
    font-size: 20px;
    font-weight: 700;
    letter-spacing: -0.3px;
    margin-bottom: 8px;
  }
  .company-info p {
    font-size: 11.5px;
    color: #64748b;
    line-height: 1.6;
  }
  .invoice-title {
    text-align: right;
  }
  .invoice-title h2 {
    font-size: 32px;
    font-weight: 800;
    letter-spacing: -1px;
    color: #1a1a2e;
    text-transform: uppercase;
  }
  .invoice-title .invoice-number {
    font-size: 13px;
    color: #64748b;
    margin-top: 4px;
    font-weight: 500;
  }

  /* ---- Meta Grid ---- */
  .meta-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 32px;
    margin-bottom: 36px;
  }
  .meta-section h3 {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #94a3b8;
    margin-bottom: 10px;
  }
  .meta-section p {
    font-size: 13px;
    line-height: 1.7;
    color: #334155;
  }
  .meta-section p strong {
    color: #1a1a2e;
    font-weight: 600;
  }
  .meta-detail {
    display: flex;
    justify-content: space-between;
    padding: 6px 0;
    border-bottom: 1px solid #f1f5f9;
    font-size: 12.5px;
  }
  .meta-detail .label {
    color: #94a3b8;
    font-weight: 500;
  }
  .meta-detail .value {
    color: #1a1a2e;
    font-weight: 600;
  }

  /* ---- Line Items Table ---- */
  .items-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 24px;
  }
  .items-table thead th {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #94a3b8;
    padding: 12px 16px;
    text-align: left;
    border-bottom: 2px solid #e2e8f0;
  }
  .items-table thead th:last-child,
  .items-table thead th:nth-child(3),
  .items-table thead th:nth-child(4) {
    text-align: right;
  }
  .items-table tbody td {
    padding: 14px 16px;
    border-bottom: 1px solid #f1f5f9;
    font-size: 13px;
    vertical-align: top;
  }
  .items-table tbody td:first-child {
    color: #64748b;
    width: 40px;
    text-align: center;
  }
  .items-table tbody td:nth-child(3),
  .items-table tbody td:nth-child(4),
  .items-table tbody td:last-child {
    text-align: right;
    white-space: nowrap;
  }
  .items-table tbody td:nth-child(2) {
    color: #1a1a2e;
    font-weight: 500;
  }
  .item-desc {
    font-size: 11.5px;
    color: #94a3b8;
    font-weight: 400;
    margin-top: 2px;
  }

  /* ---- Totals ---- */
  .totals-section {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 36px;
  }
  .totals-table {
    width: 300px;
  }
  .totals-row {
    display: flex;
    justify-content: space-between;
    padding: 8px 0;
    font-size: 13px;
    color: #64748b;
  }
  .totals-row .amount {
    font-weight: 600;
    color: #334155;
  }
  .totals-row.discount .amount {
    color: #dc2626;
  }
  .totals-row.grand-total {
    border-top: 2px solid #1a1a2e;
    margin-top: 8px;
    padding-top: 12px;
    font-size: 18px;
    font-weight: 800;
    color: #1a1a2e;
  }
  .totals-row.grand-total .amount {
    color: #1a1a2e;
    font-weight: 800;
  }

  /* ---- Payment Info ---- */
  .payment-section {
    background: #f8fafc;
    border-radius: 8px;
    padding: 24px;
    margin-bottom: 28px;
    border: 1px solid #e2e8f0;
  }
  .payment-section h3 {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #94a3b8;
    margin-bottom: 14px;
  }
  .payment-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .payment-item {
    font-size: 12.5px;
  }
  .payment-item .label {
    color: #94a3b8;
    font-weight: 500;
    font-size: 11px;
  }
  .payment-item .value {
    color: #1a1a2e;
    font-weight: 600;
    margin-top: 2px;
  }

  /* ---- Notes ---- */
  .notes-section {
    margin-bottom: 28px;
  }
  .notes-section h3 {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #94a3b8;
    margin-bottom: 10px;
  }
  .notes-section p {
    font-size: 12px;
    color: #64748b;
    line-height: 1.7;
  }

  /* ---- Footer ---- */
  .footer {
    margin-top: auto;
    padding-top: 20px;
    border-top: 1px solid #e2e8f0;
    text-align: center;
    font-size: 11px;
    color: #94a3b8;
    line-height: 1.8;
  }
  .footer strong {
    color: #64748b;
  }
</style>
</head>
<body>
<div class="invoice-page">

  <!-- HEADER -->
  <div class="header">
    <div class="company-info">
      <h1>{{COMPANY_NAME}}</h1>
      <p>
        {{COMPANY_ADDRESS}}<br>
        {{COMPANY_PHONE}} &middot; {{COMPANY_EMAIL}}<br>
        {{COMPANY_WEBSITE}}<br>
        NPWP: {{COMPANY_NPWP}}
      </p>
    </div>
    <div class="invoice-title">
      <h2>Invoice</h2>
      <div class="invoice-number">{{INVOICE_NUMBER}}</div>
    </div>
  </div>

  <!-- META: Bill To + Invoice Details -->
  <div class="meta-grid">
    <div class="meta-section">
      <h3>Bill To</h3>
      <p>
        <strong>{{CLIENT_NAME}}</strong><br>
        {{CLIENT_ADDRESS}}<br>
        {{CLIENT_CONTACT}}<br>
        {{CLIENT_EMAIL}}
        <!-- If client NPWP: <br>NPWP: {{CLIENT_NPWP}} -->
      </p>
    </div>
    <div class="meta-section">
      <h3>Invoice Details</h3>
      <div class="meta-detail">
        <span class="label">Invoice Number</span>
        <span class="value">{{INVOICE_NUMBER}}</span>
      </div>
      <div class="meta-detail">
        <span class="label">Invoice Date</span>
        <span class="value">{{INVOICE_DATE}}</span>
      </div>
      <div class="meta-detail">
        <span class="label">Due Date</span>
        <span class="value">{{DUE_DATE}}</span>
      </div>
      <div class="meta-detail">
        <span class="label">Payment Terms</span>
        <span class="value">Net {{PAYMENT_TERMS}} days</span>
      </div>
      <!-- If PO number exists:
      <div class="meta-detail">
        <span class="label">PO Number</span>
        <span class="value">{{PO_NUMBER}}</span>
      </div>
      -->
    </div>
  </div>

  <!-- PROJECT REFERENCE -->
  <div class="meta-section" style="margin-bottom: 24px;">
    <h3>Project</h3>
    <p><strong>{{PROJECT_NAME}}</strong></p>
  </div>

  <!-- LINE ITEMS -->
  <table class="items-table">
    <thead>
      <tr>
        <th>No.</th>
        <th>Description</th>
        <th>Qty</th>
        <th>Unit Price</th>
        <th>Amount</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat for each line item: -->
      <tr>
        <td>{{ITEM_NUMBER}}</td>
        <td>
          {{ITEM_DESCRIPTION}}
          <div class="item-desc">{{ITEM_DETAIL}}</div>
        </td>
        <td>{{ITEM_QTY}}</td>
        <td>{{ITEM_UNIT_PRICE}}</td>
        <td>{{ITEM_AMOUNT}}</td>
      </tr>
    </tbody>
  </table>

  <!-- TOTALS -->
  <div class="totals-section">
    <div class="totals-table">
      <div class="totals-row">
        <span>Subtotal</span>
        <span class="amount">{{SUBTOTAL}}</span>
      </div>
      <!-- If discount:
      <div class="totals-row discount">
        <span>Discount ({{DISCOUNT_LABEL}})</span>
        <span class="amount">- {{DISCOUNT_AMOUNT}}</span>
      </div>
      -->
      <!-- If tax:
      <div class="totals-row">
        <span>{{TAX_NAME}} ({{TAX_RATE}}%)</span>
        <span class="amount">{{TAX_AMOUNT}}</span>
      </div>
      -->
      <div class="totals-row grand-total">
        <span>Total</span>
        <span class="amount">{{GRAND_TOTAL}}</span>
      </div>
    </div>
  </div>

  <!-- PAYMENT INFORMATION -->
  <div class="payment-section">
    <h3>Payment Information / Informasi Pembayaran</h3>
    <div class="payment-grid">
      <div class="payment-item">
        <div class="label">Bank</div>
        <div class="value">{{BANK_NAME}}</div>
      </div>
      <div class="payment-item">
        <div class="label">Account Holder / Atas Nama</div>
        <div class="value">{{ACCOUNT_HOLDER}}</div>
      </div>
      <div class="payment-item">
        <div class="label">Account Number / Nomor Rekening</div>
        <div class="value">{{ACCOUNT_NUMBER}}</div>
      </div>
      <div class="payment-item">
        <div class="label">SWIFT Code</div>
        <div class="value">{{SWIFT_CODE}}</div>
      </div>
    </div>
  </div>

  <!-- NOTES & TERMS -->
  <div class="notes-section">
    <h3>Terms & Notes / Syarat & Ketentuan</h3>
    <p>
      Payment is due within {{PAYMENT_TERMS}} days of invoice date.<br>
      Pembayaran jatuh tempo dalam {{PAYMENT_TERMS}} hari dari tanggal faktur.<br><br>
      Late payments are subject to a {{LATE_FEE}}% monthly fee on the outstanding balance.<br>
      Keterlambatan pembayaran dikenakan biaya {{LATE_FEE}}% per bulan dari saldo terutang.
      <!-- If custom notes: <br><br>{{CUSTOM_NOTES}} -->
    </p>
  </div>

  <!-- FOOTER -->
  <div class="footer">
    <strong>Thank you for your business / Terima kasih atas kepercayaan Anda</strong><br>
    {{COMPANY_NAME}} &middot; {{COMPANY_EMAIL}} &middot; {{COMPANY_WEBSITE}}
  </div>

</div>
</body>
</html>
```

**CRITICAL DESIGN RULES:**
- Do NOT add background colors to the whole page — keep it white and clean
- Do NOT use bright/saturated colors — stick to the slate/gray palette defined above
- Do NOT add decorative borders, gradients, or shadows beyond what's in the template
- Keep the typography hierarchy tight: the invoice number and grand total should be the most prominent elements
- All text, tables, and elements must fit within the A4 page with proper margins
- If there are many line items (>8), the content may overflow — in that case add `page-break-inside: avoid` to the totals section
- The HTML must be self-contained with all styles inline or in `<style>` tags — no external resources

### Customization Per Invoice

When generating the HTML, adapt the template based on the actual data:
- If there's no PO number, remove that meta-detail row entirely (don't show empty fields)
- If there's no discount, remove the discount totals row
- If tax is disabled, remove the tax totals row
- If no client NPWP, remove that line from Bill To
- If no custom notes, remove the extra notes paragraph
- Always keep bilingual labels for payment and terms sections

---

## 6. GENERATE PDF — Chrome Headless

Convert the HTML to PDF using Google Chrome in headless mode:

```bash
google-chrome-stable --headless --disable-gpu --no-sandbox --print-to-pdf="/home/christopher/Documents/invoices/{{INVOICE_NUMBER}}.pdf" --no-pdf-header-footer --print-to-pdf-no-header /tmp/invoice-{{INVOICE_NUMBER}}.html 2>/dev/null
```

If `google-chrome-stable` is not available, try these alternatives in order:
1. `google-chrome --headless --disable-gpu --no-sandbox --print-to-pdf=...`
2. `chromium --headless --disable-gpu --no-sandbox --print-to-pdf=...`
3. `npx puppeteer browsers install chrome && node -e "..."` (puppeteer script as last resort)

After generating, verify the PDF exists and has a non-zero file size:
```bash
ls -la ~/Documents/invoices/{{INVOICE_NUMBER}}.pdf
```

If PDF generation fails, inform the user and suggest installing a PDF tool.

Clean up the temp HTML file after successful PDF generation:
```bash
rm /tmp/invoice-{{INVOICE_NUMBER}}.html
```

---

## 7. SAVE RECORDS — JSON and Markdown

### 7.1 JSON Record

Save the invoice data as JSON at `~/.claude/invoices/{{INVOICE_NUMBER}}.json`:

```json
{
  "invoice_number": "INV-202603-001",
  "invoice_date": "2026-03-31",
  "due_date": "2026-04-14",
  "status": "issued",
  "client": {
    "name": "Client Company",
    "address": "Client address",
    "contact": "Contact Person",
    "email": "client@example.com",
    "npwp": null
  },
  "project": "Project Name",
  "po_number": null,
  "line_items": [
    {
      "description": "Item description",
      "detail": "Additional detail",
      "qty": 1,
      "unit_price": 15000000,
      "amount": 15000000
    }
  ],
  "subtotal": 15000000,
  "discount": null,
  "tax_name": "PPN",
  "tax_rate": 0.11,
  "tax_amount": 1650000,
  "grand_total": 16650000,
  "payment_terms_days": 14,
  "currency": "IDR",
  "notes": null,
  "pdf_path": "/home/christopher/Documents/invoices/INV-202603-001.pdf",
  "md_path": "/home/christopher/Documents/invoices/INV-202603-001.md",
  "created_at": "2026-03-31T10:00:00+07:00"
}
```

### 7.2 Markdown Version

Save a markdown version at `~/Documents/invoices/{{INVOICE_NUMBER}}.md`:

```markdown
# INVOICE {{INVOICE_NUMBER}}

**{{COMPANY_NAME}}**
{{COMPANY_ADDRESS}}
{{COMPANY_PHONE}} | {{COMPANY_EMAIL}} | {{COMPANY_WEBSITE}}
NPWP: {{COMPANY_NPWP}}

---

## Bill To

**{{CLIENT_NAME}}**
{{CLIENT_ADDRESS}}
{{CLIENT_CONTACT}} | {{CLIENT_EMAIL}}

---

**Invoice Number:** {{INVOICE_NUMBER}}
**Invoice Date:** {{INVOICE_DATE}}
**Due Date:** {{DUE_DATE}}
**Payment Terms:** Net {{PAYMENT_TERMS}} days
**Project:** {{PROJECT_NAME}}

---

## Line Items

| No. | Description | Qty | Unit Price | Amount |
|-----|-------------|-----|-----------|--------|
| 1 | {{DESCRIPTION}} | {{QTY}} | {{UNIT_PRICE}} | {{AMOUNT}} |

---

| | |
|---|---|
| **Subtotal** | {{SUBTOTAL}} |
| **PPN (11%)** | {{TAX_AMOUNT}} |
| **GRAND TOTAL** | **{{GRAND_TOTAL}}** |

---

## Payment Information

- **Bank:** {{BANK_NAME}}
- **Account Holder:** {{ACCOUNT_HOLDER}}
- **Account Number:** {{ACCOUNT_NUMBER}}
- **SWIFT Code:** {{SWIFT_CODE}}

---

## Terms

Payment is due within {{PAYMENT_TERMS}} days of invoice date.
Late payments are subject to a {{LATE_FEE}}% monthly fee.

---

*Thank you for your business / Terima kasih atas kepercayaan Anda*
```

---

## 8. RECURRING & MILESTONE INVOICES

### Milestone Invoicing

When the user mentions milestones (e.g., "30% upfront", "50% on completion"), handle as follows:

- Ask for the total project value if not given
- Calculate the milestone amount
- Set the line item description to include the milestone reference (e.g., "Website Development - Phase 1: 30% Upfront Payment")
- Store the milestone info in the JSON record for future reference

### Recurring Invoices

When the user says "recurring" or "monthly invoice":

1. Read the most recent invoice for that client from `~/.claude/invoices/`
2. Copy the line items and client details
3. Update the invoice number, dates, and any changed amounts
4. Generate as a new invoice

---

## 9. OUTPUT — Summary

After generating the invoice, print a summary:

```
Invoice Generated Successfully
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Invoice:    {{INVOICE_NUMBER}}
  Client:     {{CLIENT_NAME}}
  Project:    {{PROJECT_NAME}}
  Amount:     {{GRAND_TOTAL}}
  Due:        {{DUE_DATE}}

  PDF:        ~/Documents/invoices/{{INVOICE_NUMBER}}.pdf
  Markdown:   ~/Documents/invoices/{{INVOICE_NUMBER}}.md
  Record:     ~/.claude/invoices/{{INVOICE_NUMBER}}.json
```

---

## RULES

- **Never fabricate client details** — always ask for what you don't know
- **Always verify PDF was generated** — check file exists and size > 0
- **Currency formatting is non-negotiable** — `Rp 15.000.000` not `15000000` or `Rp15,000,000`
- **Invoice numbers must be sequential** — always check existing invoices first
- **Bilingual labels** — payment section and terms must include both English and Indonesian
- **Clean up temp files** — remove the HTML file from /tmp after PDF generation
- **Config values override defaults** — always read config.json before generating
- **All amounts in the JSON record are stored as integers** (no decimals for IDR)
- **Date format in documents**: display as "31 March 2026" or "31 Maret 2026" for Indonesian
- **Date format in JSON**: ISO 8601 (`2026-03-31`)
