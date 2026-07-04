# references/bast-guide.md: the bilingual BAST + Indonesian conventions

The BAST (Berita Acara Serah Terima) is the highest-stakes document in the package: a formal Indonesian handover certificate that both parties sign, and whose signing **triggers the final 30% payment and starts the warranty** (`project_software_house` Phase 4). It earns a dedicated reference. SKILL.md section 3 owns the PDF verify gate; this file owns the template, the Indonesian conventions, and the fill discipline.

Hard rules that apply here (from SKILL.md section 0):
- **Bilingual**: Indonesian primary, English secondary (non-negotiable rule 8).
- **Identity from config, never hardcoded** (rule 0.4): Pihak Pertama is read from `~/.claude/invoices/config.json` `company.{name,address,phone,email,npwp}`. Never print the raw config values into chat; write them into the BAST file only.
- **No em or en dash** anywhere (rule 0.1).
- **Signable PDF** is the deliverable (SKILL.md section 3); the markdown below is the render source.
- **Commercial terms** (warranty length, SLA) are Suryadi's remit: pre-fill the house default marked `[TO CONFIRM: Suryadi]`, never invent final contract language.

---

## 1. Indonesian BAST conventions (get these right, a client notices)

| Element | Convention | How to fill |
|---|---|---|
| **Nomor** (document number) | `NNN/BAST/ROMAN-MONTH/YEAR`, e.g. `001/BAST/VII/2026` | Roman month (I to XII): Jan=I ... Jul=VII ... Dec=XII. Sequence is the client's / Aenoxa's registry; if unknown, leave `NNN` as a fill-line, do not invent a specific number. |
| **Para Pihak** (the parties) | Pihak Pertama = the party HANDING OVER (Developer / Aenoxa); Pihak Kedua = the party RECEIVING (Klien) | Pihak Pertama identity from config; Pihak Kedua from `$ARGUMENTS` / `[TO CONFIRM]`. |
| **Materai** | A single materai tempel or e-materai of Rp 10.000 (materai 10000) is affixed on the signature of the binding party, and the signature crosses it | Mark the placement in the signature block: `[Materai Rp 10.000]` above the Pihak Pertama signature line. The physical / e-materai is applied by the human at signing, not by this skill. |
| **Rangkap** | `dibuat dalam rangkap 2 (dua), masing-masing mempunyai kekuatan hukum yang sama` | Keep this legal-force clause verbatim (two originals, equal legal force). |
| **Tanggal** | Written date, `TZ=Asia/Jakarta` | Use today's date at generation; the signing date is filled by hand. |
| **Masa Garansi** | Warranty starts at signing, house default 30 to 60 days | House defaults marked `[TO CONFIRM: Suryadi]` (rule 0.4). |
| **Lingkup Pekerjaan** | References the underlying agreement (SOW / contract) number + date | If the `/proposal` or contract number is known, cite it; else a fill-line. |

---

## 2. The bilingual BAST template (render source for bast.pdf)

Fill every `{...}` from config + the section 1 deliverables analysis. Blank `_______` fill-lines are legitimate (signed by hand). Do NOT leave a `{PROJECT_NAME}` style placeholder unfilled (V4 fails it).

```markdown
# BERITA ACARA SERAH TERIMA PEKERJAAN
## WORK HANDOVER CERTIFICATE

**Nomor / Number**: {NNN}/BAST/{ROMAN_MONTH}/{YEAR}
**Tanggal / Date**: {today, e.g. 3 Juli 2026}

---

## PARA PIHAK / PARTIES

### Pihak Pertama / First Party (Pengembang / Developer)
| | |
|---|---|
| Nama / Name | {config company.name} |
| Alamat / Address | {config company.address} |
| Telepon / Phone | {config company.phone} |
| Email | {config company.email} |
| NPWP | {config company.npwp, or "-" if empty} |
| Diwakili oleh / Represented by | _________________________ |
| Jabatan / Position | _________________________ |

### Pihak Kedua / Second Party (Klien / Client)
| | |
|---|---|
| Nama / Name | {CLIENT from $ARGUMENTS, else [TO CONFIRM]} |
| Alamat / Address | _________________________ |
| Diwakili oleh / Represented by | _________________________ |
| Jabatan / Position | _________________________ |

---

## LINGKUP PEKERJAAN / SCOPE OF WORK

Pengembangan aplikasi **{PROJECT_NAME}** sebagaimana tertuang dalam perjanjian kerja / SOW nomor {SOW_NO, else "_______________"} tanggal {SOW_DATE, else "_______________"}.

Development of the **{PROJECT_NAME}** application as stated in work agreement / SOW number {SOW_NO} dated {SOW_DATE}.

---

## DAFTAR DELIVERABLES / DELIVERABLES CHECKLIST

| No | Deliverable | Deskripsi / Description | Status | Paraf / Initials |
|----|-------------|------------------------|--------|------------------|
{One row per real deliverable from the section 1 analysis (the features + the doc package). Then the standard closing rows:}
| A | Source Code | Akses penuh repositori / Full repository access | Selesai / Complete | _______ |
| B | Dokumentasi / Documentation | Paket dokumentasi handover / Handover documentation package | Selesai / Complete | _______ |
| C | Akses & Kredensial / Access & Credentials | Peta kredensial + akses server / Credentials map + server access | Selesai / Complete | _______ |
| D | Basis Data / Database | Skema + migrasi / Schema and migrations | Selesai / Complete | _______ |
| E | Pelatihan / Training | Sesi pelatihan terekam / Recorded training session | {Selesai / Complete, or [TO CONFIRM]} | _______ |

---

## DOKUMEN YANG DISERAHKAN / DOCUMENTS HANDED OVER

| No | Dokumen / Document | Format | Lokasi / Location |
|----|-------------------|--------|-------------------|
| 1 | Ringkasan Handover / Handover Summary | Markdown | docs/handover/handover.md |
| 2 | Dokumentasi Arsitektur / Architecture | Markdown | docs/handover/architecture.md |
| 3 | Dokumentasi API / API Documentation | Markdown | docs/handover/api.md |
| 4 | Panduan Deployment / Deployment Guide | Markdown | docs/handover/deployment.md |
| 5 | Panduan Pengguna / User Guide | Markdown | docs/handover/user-guide.md |
| 6 | Peta Kredensial / Credentials Map | Markdown | docs/handover/credentials.md |
| 7 | Panduan Pemeliharaan / Maintenance Guide | Markdown | docs/handover/maintenance.md |
| 8 | Berita Acara / This Certificate | PDF | docs/handover/bast.pdf |

---

## MASA GARANSI / WARRANTY PERIOD

Masa garansi dimulai sejak tanggal penandatanganan Berita Acara ini selama **30 sampai 60 (tiga puluh sampai enam puluh) hari** [TO CONFIRM: Suryadi].

The warranty period starts from the date this Certificate is signed, for **30 to 60 days** [TO CONFIRM: Suryadi].

### Cakupan Garansi / Coverage
- Perbaikan bug / Bug fixes
- Perbaikan keamanan kritis / Critical security patches
- Waktu respons 24 jam untuk isu kritis / 24hr response for critical issues [TO CONFIRM: Suryadi]

### Tidak Termasuk / Not Covered
- Penambahan fitur baru / New feature additions
- Perubahan requirement / Requirement changes
- Kerusakan akibat modifikasi pihak ketiga / Damage from third-party modifications
- Force majeure

---

## PERNYATAAN SERAH TERIMA / HANDOVER DECLARATION

Dengan ditandatanganinya Berita Acara ini, Pihak Pertama menyerahkan dan Pihak Kedua menerima seluruh deliverables sebagaimana tercantum di atas dalam keadaan baik dan lengkap.

By signing this Certificate, the First Party hands over and the Second Party accepts all deliverables listed above in good and complete condition.

---

## TANDA TANGAN / SIGNATURES

| | Pihak Pertama / First Party | Pihak Kedua / Second Party |
|---|---|---|
| | [Materai Rp 10.000] | |
| Tanda Tangan / Signature | | |
| Nama / Name | _________________________ | _________________________ |
| Jabatan / Position | _________________________ | _________________________ |
| Tanggal / Date | _________________________ | _________________________ |
| Stempel / Company Stamp | | |

---

*Dokumen ini dibuat dalam rangkap 2 (dua), masing-masing mempunyai kekuatan hukum yang sama.*
*This document is made in 2 (two) copies, each having equal legal force.*
```

---

## 3. Rendering the BAST to a signable PDF

The BAST is diagram-free (no Mermaid), so it renders cleanly through Chrome-headless. Use the self-contained HTML template in `references/render-pipeline.md` (typography floors honored, serif register appropriate for a legal document), then the verified command + G3 verify from SKILL.md section 3:

```bash
PDF="docs/handover/bast.pdf"
google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header \
  "$HTML" 2>/tmp/bast.chrome.log
RC=$?
pages=$(pdfinfo "$PDF" 2>/dev/null | awk '/^Pages:/{print $2}')
[ "$RC" -eq 0 ] && [ -s "$PDF" ] && [ "${pages:-0}" -ge 1 ] \
  && echo "BAST PDF OK: $(stat -c%s "$PDF") bytes, ${pages} page(s)" \
  || echo "BAST PDF FAIL"
```

If the client will edit / redline the BAST before signing, also produce a docx (`pandoc docs/handover/bast.md -o docs/handover/bast.docx`, works with no LaTeX). Verified live on this box 2026-07-03: a bilingual BAST HTML produced a valid 1-page PDF (Chrome 144), pandoc produced a valid docx, and the soffice docx-to-pdf route worked as the fallback.

**Run the SKILL.md section 0.5 verification block on `bast.md` and the BAST HTML before claiming done.** A dash or a leaked secret in the render source lands in the signed PDF. The BAST is the worst possible surface for either.

---

## 4. On sign: the /invoice handoff

Handover GENERATES the certificate; it does not bill. When Christopher confirms both parties signed the BAST, the final 30% milestone bills via `/invoice` (the 30/40/30 schedule, `project_software_house` Phase 4: BAST sign triggers final payment + warranty start). SKILL.md section 6 prints the exact handoff command. Do not attempt to bill from this skill.
