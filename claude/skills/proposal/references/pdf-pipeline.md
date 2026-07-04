# references/pdf-pipeline.md: the verified proposal render pipeline

Progressive-disclosure companion to `SKILL.md` section 5. The load-bearing rules (Chrome-headless is the path, verify-before-claim, typography floors) live in SKILL.md; this file carries the full recipe, the HTML template, and the failure playbook.

Every command here was verified live on this box on 2026-07-03. Do not substitute an unverified tool.

---

## 1. The toolchain, as it actually is (verified 2026-07-03)

| Tool | Status | Use it for |
|---|---|---|
| `google-chrome-stable` | INSTALLED `/usr/bin/google-chrome-stable` (Chrome 144.0.7559.59) | **primary: HTML -> PDF** |
| `google-chrome` | present `/opt/google/chrome/google-chrome` | fallback 1 for HTML -> PDF |
| `chromium` | check with `command -v chromium` | fallback 2 |
| `pandoc` | INSTALLED `~/.local/bin/pandoc` (3.5) | **md -> docx** (works, no LaTeX). NEVER md -> pdf |
| `soffice` / `libreoffice` | INSTALLED `/usr/bin` (LibreOffice 26.2) | docx -> pdf (second PDF route) |
| `md-to-pdf` | ABSENT | do not reference |
| `pdflatex` / `xelatex` / `lualatex` / `tectonic` / `typst` | ALL ABSENT | why `pandoc md -o pdf` fails |
| `weasyprint` / `wkhtmltopdf` / `prince` | ALL ABSENT | do not reference |
| python3 `markdown`, `reportlab` | importable | a last-resort HTML-build or PDF path if ever needed |

**The one command that is BANNED:** `pandoc file.md -o file.pdf`. It fails with `pdflatex not found. Please select a different --pdf-engine or install pdflatex` because no LaTeX engine (and no weasyprint/wkhtmltopdf) is installed. The previous version of this skill documented exactly this broken path as its only PDF instruction.

---

## 2. Format decision: which output when

| Client situation | Produce | Why |
|---|---|---|
| Standard proposal to sign | **PDF** (Chrome-headless) | Fixed layout, looks final, cannot be accidentally edited |
| Client will redline / edit the scope | **docx** (`pandoc md -o docx`) + PDF | Word is what SMB clients edit in |
| Client wants both | PDF + docx | PDF to read, docx to mark up |
| Internal draft for Suryadi to review commercial terms | md + PDF | fast, and Suryadi edits the commercial section |

Always produce the PDF. Add the docx when the client edits. The markdown is always kept (it is the render source and the archive).

---

## 3. The pipeline, step by step

### 3a. Write the proposal markdown

Assemble per `references/section-library.md`. Keep it at `~/Documents/proposals/<PROP>.md` (or `./proposals/<PROP>.md` in a project dir).

### 3b. Render a self-contained HTML (the template is section 5 below)

Fill the template placeholders from the proposal data. All CSS inline, no external fonts/images/scripts (Chrome headless will not fetch remote assets reliably and you want determinism). Write to a temp file:

```bash
HTML="/tmp/proposal-${PROP}.html"     # temp render source
PDF="$HOME/Documents/proposals/${PROP}.pdf"
# ... write $HTML from the template ...
```

### 3c. Chrome headless HTML -> PDF (PRIMARY, verified)

Identical flags to `/invoice` section 9, verified to produce a valid PDF here:

```bash
google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header \
  "$HTML" 2>/dev/null
```

- `--no-pdf-header-footer` and `--print-to-pdf-no-header` strip Chrome's default date/URL header and footer (you do not want "file:///tmp/..." printed on a client proposal).
- `--no-sandbox` is required in this headless environment.
- Page size and margins come from the template `@page` rule (A4), not from a CLI flag.

### 3d. Fallback chain if the primary binary is missing

```bash
render_pdf() {
  local html="$1" pdf="$2"
  for bin in google-chrome-stable google-chrome chromium; do
    if command -v "$bin" >/dev/null 2>&1; then
      "$bin" --headless --disable-gpu --no-sandbox \
        --print-to-pdf="$pdf" --no-pdf-header-footer --print-to-pdf-no-header \
        "$html" 2>/dev/null
      [ -s "$pdf" ] && { echo "rendered with $bin"; return 0; }
    fi
  done
  return 1   # no chrome variant worked -> go to the docx route (3e) and the playbook (section 6)
}
```

### 3e. Client-editable docx (verified: works with NO LaTeX)

```bash
DOCX="$HOME/Documents/proposals/${PROP}.docx"
pandoc "$HOME/Documents/proposals/${PROP}.md" -o "$DOCX"
[ -s "$DOCX" ] && echo "docx OK ($(stat -c%s "$DOCX") bytes)"
```

Optional second PDF route through LibreOffice (useful if every Chrome variant fails):

```bash
soffice --headless --convert-to pdf --outdir "$HOME/Documents/proposals" "$DOCX"
# produces ~/Documents/proposals/<PROP>.pdf from the docx
```

The Chrome route gives you full control of the design (the template CSS); the soffice route inherits Word's default look. Prefer Chrome for the client-facing PDF; keep soffice as the safety net.

### 3f. VERIFY, then clean up

```bash
test -s "$PDF" && stat -c '%n %s bytes' "$PDF" || { echo "FAIL: no PDF"; exit 1; }   # V7
rm -f "$HTML"   # remove the temp render source only AFTER the PDF is confirmed
```

NEVER report a PDF as produced without the `test -s` passing. This is DELIVERY-GATE V7.

---

## 4. Run the VERIFICATION BLOCK on the produced files

Before delivery, run SKILL.md section 0.4 V1 to V7 over `$FILES="$MD $HTML $DOCX"` (the client-facing set). The HTML render source counts (a dash or emoji in it lands in the PDF). Fix any hit in the markdown, re-render, re-verify.

---

## 5. The HTML template (self-contained, typography floors honored)

Fill `{{...}}` from the proposal data. Body 12.5px, all weights >= 500, serif body for a proposal register (not `/invoice`'s slate labels). Monospace appears ONLY inside `.code` / `.arch` blocks (architecture diagrams / code), never for labels (`feedback_no_monospace_unless_archetype`). No sub-12px text anywhere (`feedback_ui_typography_floors`; do NOT copy `/invoice`'s 10 to 11px label sizing). No em/en dash, no emoji in any filled value.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Proposal {{PROP_NUMBER}} - {{PROJECT_NAME}}</title>
<style>
  @page { size: A4; margin: 18mm 16mm; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: Georgia, 'Times New Roman', serif;
    color: #1a1f2b;
    font-size: 12.5px;          /* >= 12px floor */
    font-weight: 500;           /* >= 500 floor */
    line-height: 1.6;
    -webkit-print-color-adjust: exact; print-color-adjust: exact;
  }
  h1 { font-size: 30px; font-weight: 700; letter-spacing: -0.4px; line-height: 1.15; }
  h2 { font-size: 19px; font-weight: 700; margin: 26px 0 10px; padding-bottom: 6px;
       border-bottom: 2px solid #1a1f2b; }
  h3 { font-size: 15px; font-weight: 600; margin: 18px 0 8px; }
  p  { margin: 8px 0; }
  strong { font-weight: 700; }
  ul, ol { margin: 8px 0 8px 20px; }
  li { margin: 4px 0; }
  /* cover */
  .cover { height: 235mm; display: flex; flex-direction: column; justify-content: center;
           page-break-after: always; }
  .cover .eyebrow { font-size: 12px; font-weight: 600; letter-spacing: 2px;
                    text-transform: uppercase; color: #5a6472; margin-bottom: 14px; }
  .cover .sub { font-size: 16px; font-weight: 600; color: #3a4250; margin-top: 10px; }
  .cover .meta { margin-top: 40px; font-size: 13px; }
  .cover .meta div { padding: 3px 0; }
  .cover .meta .label { display: inline-block; width: 130px; color: #5a6472; font-weight: 600; }
  /* tables */
  table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 12px; }
  th { text-align: left; font-weight: 700; padding: 8px 10px; background: #f2f4f7;
       border-bottom: 2px solid #d4d9e0; font-size: 12px; }
  td { padding: 7px 10px; border-bottom: 1px solid #e6e9ee; vertical-align: top; }
  .num { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; }
  /* totals emphasis */
  tr.total td { font-weight: 700; border-top: 2px solid #1a1f2b; font-size: 13px; }
  /* draft banner for commercial/legal clauses (rule 5) */
  .draft-banner { background: #fff6e5; border: 1px solid #e0b352; border-radius: 6px;
                  padding: 10px 14px; margin: 14px 0; font-size: 12px; font-weight: 600;
                  color: #7a5a12; }
  /* blockquote for formal terms */
  blockquote { border-left: 3px solid #c4ccd6; padding: 6px 0 6px 14px; margin: 10px 0;
               color: #3a4250; }
  /* mono ONLY inside a real code/architecture surface (archetype-gated) */
  .code, .arch { font-family: 'DejaVu Sans Mono', 'Courier New', monospace;
                 font-size: 12px; font-weight: 500; background: #f6f8fa;
                 border: 1px solid #e6e9ee; border-radius: 6px; padding: 12px;
                 white-space: pre; overflow-x: auto; line-height: 1.45; }
  .section { page-break-inside: avoid; }
</style>
</head>
<body>
  <!-- COVER -->
  <div class="cover">
    <div class="eyebrow">Technical Proposal &amp; Statement of Work</div>
    <h1>{{PROJECT_NAME}}</h1>
    <div class="sub">Prepared for {{CLIENT_NAME}}</div>
    <div class="meta">
      <div><span class="label">Prepared by</span> {{COMPANY_NAME}}</div>
      <div><span class="label">Proposal no.</span> {{PROP_NUMBER}}</div>
      <div><span class="label">Date</span> {{DATE}}</div>
      <div><span class="label">Valid until</span> {{VALID_UNTIL}}</div>
      <div><span class="label">Version</span> {{VERSION}}</div>
      <div><span class="label">Engagement</span> {{ENGAGEMENT_TYPE}}</div>
    </div>
  </div>

  <!-- BODY: repeat .section blocks per section-library.md -->
  <div class="section">
    <h2>1. Executive Summary</h2>
    <p>{{EXEC_SUMMARY}}</p>
  </div>

  <!-- ... scope, tech approach, timeline, team, investment, deliverables, warranty, maintenance ... -->

  <!-- Commercial / legal clauses ALWAYS under the draft banner (rule 5) -->
  <div class="section">
    <h2>9. Commercial Terms (Draft)</h2>
    <div class="draft-banner">
      DRAFT terms, to be confirmed by Suryadi / counsel. This proposal covers technical
      scope; commercial, IP, and confidentiality terms are finalized in the contract.
    </div>
    <blockquote>{{DRAFT_TERMS}}</blockquote>
  </div>
</body>
</html>
```

Notes:
- Use HTML entities (`&amp;`, `&middot;`) not raw glyphs where a special character is needed; keeps the source grep-clean.
- If the investment table has many rows and the totals split across a page break, the `.section` `page-break-inside: avoid` keeps a block intact; wrap the totals in their own `.section` if needed.
- The cover height (235mm) fills an A4 page minus the 18mm top/bottom margins; adjust if you add a logo band.

---

## 6. Failure playbook (exact recovery)

| Symptom | Cause | Recovery |
|---|---|---|
| `pdflatex not found` | someone ran `pandoc md -o pdf` | STOP that path; use Chrome-headless (3c). It is banned for a reason. |
| PDF file is 0 bytes / absent after the chrome call | bad HTML path, or the binary is missing | run the 3d fallback chain; if all chrome variants fail, go docx (3e) + `soffice` PDF. |
| every chrome variant fails | no chrome on the box | `pandoc md -o docx` then `soffice --headless --convert-to pdf`; deliver that PDF + the docx, and note the render route in the report. |
| both chrome AND soffice fail | unusual | deliver the **HTML + docx**, tell Christopher the PDF step needs a working renderer, NEVER claim a PDF that does not exist. |
| PDF renders but header shows a file path | missing `--no-pdf-header-footer` | re-run with both header flags (3c). |
| labels look tiny / cheap | copied `/invoice` CSS (10-11px) | this template sits at 12px+; do not lower it. |
| mono creeping into labels | default mono-labeling habit | mono only in `.code`/`.arch`; labels use the serif/sans (section 5, `feedback_no_monospace_unless_archetype`). |

The invariant across all of it: **verify the artifact exists and is non-empty before you claim it** (V7). An honest "the PDF step needs a renderer, here is the docx" beats a false "PDF generated".
