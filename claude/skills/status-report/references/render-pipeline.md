# references/render-pipeline.md: optional PDF / docx render (verified, self-contained)

Progressive-disclosure companion to `SKILL.md` §8. The load-bearing rules (Chrome is the only PDF route, pandoc-PDF is banned, verify-before-claim, typography floors) live in SKILL.md; this file is the full self-contained recipe + a status-report HTML template + the failure playbook. Every command was verified live on this box on 2026-07-03.

Rendering is OPT-IN (`--pdf` / `--docx`). Markdown is the fast weekly default. Do not render unless asked.

---

## 1. The toolchain, as it actually is (verified 2026-07-03)

| Tool | Status | Use it for |
|---|---|---|
| `google-chrome-stable` | INSTALLED `/usr/bin/google-chrome-stable` (Chrome 144.0.7559.59) | **primary: HTML -> PDF** |
| `google-chrome` | present `/opt/google/chrome/google-chrome` | fallback for HTML -> PDF |
| `chromium` | ABSENT | (nothing) |
| `pandoc` | INSTALLED (3.5) | **md -> docx** only, works with no LaTeX. NEVER md -> pdf |
| `soffice` / `libreoffice` | INSTALLED (LibreOffice 26.x) | docx -> pdf safety net |
| `pdfinfo` | INSTALLED | PDF verify (page count) |
| `qpdf` | INSTALLED | PDF verify fallback |
| `pdflatex` / `xelatex` / `lualatex` / `tectonic` | ALL ABSENT | this is why `pandoc md -o pdf` fails |
| `weasyprint` / `wkhtmltopdf` / `mmdc` | ALL ABSENT | do not reference |

**The one BANNED command:** `pandoc <file>.md -o <file>.pdf`. It fails with `pdflatex not found` because no LaTeX engine (and no weasyprint/wkhtmltopdf) is installed. The pre-rebuild skill did not render at all; do not regress into pandoc-PDF.

This is the same verified pipeline `/proposal`, `/handover`, and `/invoice` use. Reproduced here (not cited) because a SKILL's reference files must be self-contained.

---

## 2. Format decision

| Client situation | Produce | Why |
|---|---|---|
| A quick weekly update Christopher will read + forward | markdown (default) | fastest, no render needed |
| A polished report to attach in an email to the client | **PDF** (Chrome-headless) | fixed layout, looks final, cannot be accidentally edited |
| Client wants to comment / redline | **docx** (`pandoc md -o docx`) | Word is what SMB clients mark up in |

Markdown is always kept (it is the render source and the archive).

---

## 3. The pipeline, step by step

### 3a. Chrome-headless HTML -> PDF (PRIMARY, verified)

```bash
HTML="/tmp/status-${UNTIL}.html"
PDF="${REPORT_DIR}/status-report-${UNTIL}.pdf"
# ... write $HTML from the template in section 5, filling the placeholders ...

google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header \
  "$HTML" 2>/tmp/status-chrome.log
chrome_exit=$?
```

- `--no-pdf-header-footer` + `--print-to-pdf-no-header` strip Chrome's default `file:///tmp/...` header and the date footer (you do not want a temp path printed on a client document).
- `--no-sandbox` is required in this headless environment.
- Page size and margins come from the template `@page` rule (A4), not a CLI flag.

### 3b. Fallback chain if the primary binary is missing

```bash
render_pdf() {
  local html="$1" pdf="$2"
  for bin in google-chrome-stable google-chrome chromium; do
    if command -v "$bin" >/dev/null 2>&1; then
      "$bin" --headless --disable-gpu --no-sandbox \
        --print-to-pdf="$pdf" --no-pdf-header-footer --print-to-pdf-no-header "$html" 2>/dev/null
      [ -s "$pdf" ] && { echo "rendered with $bin"; return 0; }
    fi
  done
  return 1   # no chrome variant -> docx route (3d) + soffice PDF safety net (3e)
}
```

### 3c. VERIFY GATE (never claim a PDF you did not confirm)

```bash
if [ "$chrome_exit" -eq 0 ] && test -s "$PDF" && pdfinfo "$PDF" | grep -q '^Pages: *[1-9]'; then
  echo "PDF OK ($(pdfinfo "$PDF" | awk '/^Pages:/{print $2}') pages, $(stat -c%s "$PDF") bytes)"
  rm -f "$HTML"                      # remove the temp source only AFTER the PDF is confirmed
else
  echo "PDF FAILED: deliver the markdown, report the render failure honestly, do NOT claim a PDF"
fi
```

`qpdf --show-npages "$PDF"` is a fallback page-count check if `pdfinfo` is ever unavailable. All three checks (exit 0, non-empty, pages >= 1) must pass; this is DELIVERY-GATE render verification.

### 3d. Client-editable docx (works with NO LaTeX, verified)

```bash
DOCX="${REPORT_DIR}/status-report-${UNTIL}.docx"
pandoc "${REPORT_DIR}/status-report-${UNTIL}.md" -o "$DOCX"
[ -s "$DOCX" ] && echo "docx OK ($(stat -c%s "$DOCX") bytes)"
```

### 3e. soffice PDF safety net (only if every Chrome variant failed)

```bash
soffice --headless --convert-to pdf --outdir "$REPORT_DIR" "$DOCX"
# inherits Word's default look; prefer the Chrome route for the client-facing PDF, keep this as the net
```

---

## 4. Run the VERIFICATION BLOCK on the render source too

Before rendering, run SKILL §9 V1-V4 over `$FILES="$MD $HTML"`. A dash, a leaked token, or a `/home/...` path in the HTML source lands in the PDF. Fix in the markdown, regenerate the HTML, re-verify, then render.

---

## 5. The status-report HTML template (self-contained, typography floors honored)

Fill `{{...}}` from the report data. Body 12.5px, all weights >= 500, sans body for a clean status-report register. **Monospace appears NOWHERE** (a status report has no code/diagram surface; `feedback_no_monospace_unless_archetype`). No sub-12px text (`feedback_ui_typography_floors`). No em/en dash, no emoji in any filled value. Health badges are color-coded but also carry the word (never color alone).

```html
<!DOCTYPE html>
<html lang="{{LANG}}">
<head>
<meta charset="UTF-8">
<title>Status Report {{PROJECT_NAME}} {{UNTIL}}</title>
<style>
  @page { size: A4; margin: 18mm 16mm; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Helvetica Neue', Arial, sans-serif;
    color: #1a1f2b; font-size: 12.5px; font-weight: 500; line-height: 1.6;
    -webkit-print-color-adjust: exact; print-color-adjust: exact;
  }
  h1 { font-size: 26px; font-weight: 700; letter-spacing: -0.3px; line-height: 1.2; }
  h2 { font-size: 17px; font-weight: 700; margin: 24px 0 10px; padding-bottom: 6px;
       border-bottom: 2px solid #1a1f2b; }
  h3 { font-size: 14px; font-weight: 600; margin: 14px 0 6px; }
  p  { margin: 8px 0; }
  strong { font-weight: 700; }
  ul, ol { margin: 8px 0 8px 20px; }
  li { margin: 4px 0; }
  .meta { margin: 14px 0 6px; font-size: 12.5px; }
  .meta div { padding: 2px 0; }
  .meta .label { display: inline-block; width: 130px; color: #5a6472; font-weight: 600; }
  .summary { background: #f6f8fa; border-left: 3px solid #3a4250; border-radius: 4px;
             padding: 12px 16px; margin: 12px 0; }
  table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 12px; }
  th { text-align: left; font-weight: 700; padding: 8px 10px; background: #f2f4f7;
       border-bottom: 2px solid #d4d9e0; }
  td { padding: 7px 10px; border-bottom: 1px solid #e6e9ee; vertical-align: top; }
  .badge { display: inline-block; padding: 2px 9px; border-radius: 10px; font-weight: 700; font-size: 11.5px; }
  .ok   { background: #e4f5ea; color: #1c6b3a; }   /* On Track / Passing */
  .warn { background: #fdf3e0; color: #8a5a12; }   /* At Risk */
  .bad  { background: #fbe6e6; color: #9a2626; }   /* Delayed / Failing */
  .action { background: #fff6e5; border: 1px solid #e0b352; border-radius: 6px;
            padding: 4px 10px; font-weight: 700; }
  .section { page-break-inside: avoid; }
  .note { color: #5a6472; font-size: 11.5px; }     /* still >= the floor, muted for provenance notes */
</style>
</head>
<body>
  <h1>{{PROJECT_NAME}}: Weekly Status Report</h1>
  <div class="meta">
    <div><span class="label">Client</span> {{CLIENT_NAME}}</div>
    <div><span class="label">Report period</span> {{SINCE}} to {{UNTIL}}</div>
    <div><span class="label">Prepared for</span> {{RECIPIENT}}</div>
    <div><span class="label">Prepared by</span> {{COMPANY_NAME}}</div>
    <div><span class="label">Date</span> {{DATE}}</div>
  </div>

  <div class="section">
    <h2>Executive summary</h2>
    <div class="summary">{{EXEC_SUMMARY}}</div>
  </div>

  <div class="section">
    <h2>Project health</h2>
    <table>
      <tr><th>Indicator</th><th>Status</th></tr>
      <tr><td>Overall status</td><td><span class="badge {{OVERALL_CLASS}}">{{OVERALL}}</span></td></tr>
      <tr><td>Milestone progress</td><td>{{MILESTONE}}</td></tr>
      <tr><td>Open items needing attention</td><td>{{OPEN_ITEMS}}</td></tr>
      <tr><td>Build / deployment</td><td><span class="badge {{BUILD_CLASS}}">{{BUILD}}</span></td></tr>
    </table>
  </div>

  <div class="section">
    <h2>Completed this week</h2>
    {{COMPLETED_BLOCKS}}   <!-- h3 area headings + outcome bullets, from SKILL §5 -->
  </div>

  <!-- In progress / Planned next / Blockers (omit-empty) / Decisions needed / Development activity / Next milestone
       each as its own .section, per the SKILL §5 template. Omit any section with no real content. -->
</body>
</html>
```

Notes:
- Use HTML entities (`&amp;`) not raw glyphs; keeps the source grep-clean.
- The health badge carries BOTH color and the word, so a color-blind reader or a grayscale print still reads the status.
- `.note` (11.5px) is the ONE muted size, used only for an inline provenance note; the report BODY stays >= 12px. If you dislike the exception, drop the note inline at 12px instead.
- Wrap a wide activity/risk table in its own `.section` so `page-break-inside: avoid` keeps it intact.

---

## 6. Failure playbook (exact recovery)

| Symptom | Cause | Recovery |
|---|---|---|
| `pdflatex not found` | someone ran `pandoc md -o pdf` | STOP that path; Chrome-headless (3a). Banned for a reason. |
| PDF 0 bytes / absent after the chrome call | bad HTML path or missing binary | run the 3b fallback chain; if all chrome variants fail, docx (3d) + soffice PDF (3e). |
| every chrome variant fails | no chrome on the box | `pandoc md -o docx` then `soffice --headless --convert-to pdf`; deliver that PDF + docx, note the route. |
| both chrome AND soffice fail | unusual | deliver **markdown + docx**, tell Christopher the PDF step needs a renderer, NEVER claim a PDF that does not exist. |
| PDF header shows a file path | missing header flags | re-run with both `--no-pdf-header-footer --print-to-pdf-no-header` (3a). |
| labels look tiny / cheap | sub-12px text | this template sits at 12px+; do not lower it (`feedback_ui_typography_floors`). |
| mono creeping in | default mono-labeling habit | a status report has no code surface; mono NOWHERE here (`feedback_no_monospace_unless_archetype`). |

The invariant: **verify the artifact exists and is non-empty before you claim it.** An honest "the PDF step needs a renderer, here is the docx" beats a false "PDF generated".
