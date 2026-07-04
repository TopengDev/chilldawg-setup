# references/render-pipeline.md: the handover render deltas

Progressive-disclosure companion to `SKILL.md` section 3. The **canonical** Chrome-headless HTML-to-PDF recipe is `/proposal` `references/pdf-pipeline.md` (the toolchain table, the fallback chain, the failure playbook); cite it, do not fork it. This file documents only the handover-specific deltas: the bilingual BAST HTML template, the multi-document format decision, and Mermaid-in-PDF handling. Every command below is either verified in the proposal reference or smoke-tested here on 2026-07-03.

---

## 1. Toolchain (verified 2026-07-03, matches the proposal reference)

| Tool | Status | Use for |
|---|---|---|
| `google-chrome-stable` | INSTALLED `/usr/bin/google-chrome-stable` (Chrome 144) | **primary: HTML to PDF** |
| `google-chrome` | present `/opt/google/chrome/google-chrome` | fallback 1 |
| `chromium` | ABSENT | (would be fallback 2) |
| `pandoc` | INSTALLED `~/.local/bin/pandoc` (3.5) | **md to docx** (no LaTeX). NEVER md to pdf |
| `soffice` / LibreOffice | INSTALLED `/usr/bin/soffice` (26.2) | docx to pdf (second PDF route) |
| `pdfinfo` | INSTALLED `/usr/bin/pdfinfo` (poppler 26.05) | PDF page-count verify |
| `qpdf` | INSTALLED `/usr/bin/qpdf` (12.3) | page-count fallback (`--show-npages`) |
| `mmdc` (mermaid-cli) | ABSENT | why Mermaid does not rasterize in the PDF path (section 4) |
| `pdflatex` / `xelatex` / `tectonic` / `typst` | ALL ABSENT | why `pandoc md -o pdf` fails |
| `weasyprint` / `wkhtmltopdf` / `md-to-pdf` | ALL ABSENT | do not reference |

**BANNED:** `pandoc file.md -o file.pdf` (no LaTeX engine). Chrome-headless is the only PDF route.

---

## 2. Which output when (the format decision, SKILL.md G5)

| Document | Format | Why |
|---|---|---|
| architecture / api / deployment / maintenance | **markdown** | dev audience; Mermaid renders in GitHub / VS Code; do not PDF (Mermaid would go raw, section 4) |
| user-guide | markdown | end-user doc, screenshots via /agent-browser later |
| credentials | markdown | never PDF a secrets MAP into wider circulation than needed |
| **BAST** | markdown source + **PDF** (mandatory) | the signable legal certificate |
| handover summary | markdown (+ PDF if `--pdf-summary`) | diagram-free tables, renders cleanly |
| README | markdown | navigation |

---

## 3. The self-contained BAST HTML template (typography floors honored)

Fill `{{...}}` from the BAST markdown data (config identity + deliverables). All CSS inline, no remote fonts / images / scripts (Chrome headless will not reliably fetch remote assets, and you want determinism). Serif register suits a legal document.

**Typography floors** (`feedback_ui_typography_floors` + `feedback_no_monospace_unless_archetype`): body >= 12px, every text element weight >= 500. Monospace ONLY inside a code / architecture-diagram block, never for labels. **Do NOT copy `/invoice`'s CSS**: its label styles are 10 to 11px (a deliberate dense-print carve-out for invoices, below the 12px floor). A BAST is a signed legal document a human reads and keeps; keep it at/above 12px.

```html
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<title>BAST {{NOMOR}} - {{PROJECT_NAME}}</title>
<style>
  @page { size: A4; margin: 20mm 18mm; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: Georgia, 'Times New Roman', serif;
    color: #1a1f2b;
    font-size: 12.5px;        /* >= 12px floor */
    font-weight: 500;         /* >= 500 floor */
    line-height: 1.6;
    -webkit-print-color-adjust: exact; print-color-adjust: exact;
  }
  h1 { font-size: 20px; font-weight: 700; text-align: center; line-height: 1.25; }
  h2 { font-size: 15px; font-weight: 700; margin: 22px 0 8px; padding-bottom: 5px;
       border-bottom: 2px solid #1a1f2b; }
  h3 { font-size: 13px; font-weight: 600; margin: 14px 0 6px; }
  p  { margin: 7px 0; }
  em { font-style: italic; }
  table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: 12px; }
  th { text-align: left; font-weight: 700; padding: 7px 9px; background: #f2f4f7;
       border: 1px solid #d4d9e0; font-size: 12px; }
  td { padding: 7px 9px; border: 1px solid #e6e9ee; vertical-align: top; }
  .subtitle { font-size: 14px; font-weight: 600; text-align: center; margin-top: 2px; }
  .meta { margin: 14px 0; font-size: 12.5px; }
  .sign-block { margin-top: 36px; page-break-inside: avoid; }
  .sign-block td { height: 26px; }
  .materai { color: #5a6472; font-weight: 600; font-size: 12px; }  /* >= 12px floor */
  .legal-force { margin-top: 22px; font-style: italic; text-align: center;
                 color: #3a4250; font-size: 12px; }  /* rangkap-2 legal-force clause, real body text, >= 12px floor */
  .confirm { color: #7a5a12; font-weight: 600; }   /* the [TO CONFIRM: Suryadi] marker */
  .section { page-break-inside: avoid; }
</style>
</head>
<body>
  <h1>BERITA ACARA SERAH TERIMA PEKERJAAN</h1>
  <div class="subtitle">Work Handover Certificate</div>
  <div class="meta">
    <div><strong>Nomor / Number:</strong> {{NOMOR}}</div>
    <div><strong>Tanggal / Date:</strong> {{TANGGAL}}</div>
  </div>

  <!-- Para Pihak, Lingkup, Daftar Deliverables, Dokumen, Masa Garansi,
       Pernyataan: each a <div class="section"> with the bilingual content
       from references/bast-guide.md section 2 -->

  <div class="section sign-block">
    <h2>Tanda Tangan / Signatures</h2>
    <table>
      <tr><th></th><th>Pihak Pertama / First Party</th><th>Pihak Kedua / Second Party</th></tr>
      <tr><td>Materai</td><td class="materai">[Materai Rp 10.000]</td><td></td></tr>
      <tr><td>Tanda Tangan / Signature</td><td></td><td></td></tr>
      <tr><td>Nama / Name</td><td></td><td></td></tr>
      <tr><td>Jabatan / Position</td><td></td><td></td></tr>
      <tr><td>Tanggal / Date</td><td></td><td></td></tr>
      <tr><td>Stempel / Stamp</td><td></td><td></td></tr>
    </table>
  </div>

  <p class="legal-force">Dokumen ini dibuat dalam rangkap 2 (dua), masing-masing mempunyai kekuatan hukum yang sama. This document is made in 2 (two) copies, each having equal legal force.</p>
</body>
</html>
```

Use HTML entities (`&amp;`) not raw glyphs where a special character is needed, so the source stays grep-clean (no accidental dash / emoji).

---

## 4. Mermaid in a PDF (the honest answer)

`mmdc` is ABSENT and Chrome-headless renders a ```mermaid fence as **raw code text**, not a diagram. So:

- **DEFAULT (the resolution):** diagram-bearing docs (architecture, api, deployment) **stay markdown** and are never rendered to PDF. Mermaid renders in the GitHub / VS Code viewers the dev audience uses. The BAST and the optional handover summary are **diagram-free by design**, so their PDFs are clean. This is why the format decision (section 2) exists.
- **Escape hatch (only if a diagram MUST appear in a PDF):** inline the mermaid.js UMD bundle into the HTML and let Chrome rasterize the SVG before print. This is NOT verified live on this box and it requires bundling the library OFFLINE (Chrome headless will not fetch a remote `<script src>` under the determinism constraint, and it may need a render delay before `--print-to-pdf`). Treat it as an unverified option, not a recipe: prefer keeping the diagram doc in markdown.

---

## 5. Verify, then clean up

```bash
test -s "$PDF" && pages=$(pdfinfo "$PDF" 2>/dev/null | awk '/^Pages:/{print $2}') \
  && [ "${pages:-0}" -ge 1 ] && echo "PDF OK ($(stat -c%s "$PDF") bytes, ${pages} pg)" \
  || echo "FAIL"                          # qpdf --show-npages "$PDF" is the pages fallback
rm -f "$HTML" /tmp/bast-*.chrome.log       # remove temp render source only AFTER the PDF is confirmed
```

NEVER report a PDF as produced without `test -s` + a page count passing (SKILL.md G3). An honest "the PDF step needs a working renderer, here is the docx" beats a false "PDF generated".
