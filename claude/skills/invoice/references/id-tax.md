# Indonesian Tax Reality for Client Invoicing

Progressive-disclosure reference for `/invoice`. The SKILL.md TAX DECISION TABLE
is the operational contract; this file explains the WHY and carries the
moving-target caveats. **Tax rules change; treat every rate here as
verify-before-billing, not timeless truth.**

> **Last verified: 2026-07** against pajak.go.id and the PMK sources cited
> below. If today is materially later, or a line item is high-value, re-verify
> the rate against the current PMK before issuing. Flag any assumption to the
> user rather than silently billing a stale rate.

> **Scope note.** This is guidance for a software house billing external
> clients. It is NOT tax advice and NOT a substitute for a konsultan pajak on a
> real filing. When money or legal exposure is real, tell the user to confirm
> with their accountant.

---

## 1. The operator's default reality (2026): perorangan, non-PKP

Per memory `project_pt_aenoxa`, PT Aenoxa formation is **POSTPONED** (decided
2026-04-17). As of this writing the operator bills as an **individual
(perorangan)**, is **NOT a PKP** (Pengusaha Kena Pajak), and has **no NPWP
Badan**. That single fact drives the tax defaults:

- **PPN OFF by default.** Only a PKP may charge PPN and issue a Faktur Pajak. A
  non-PKP charging PPN is collecting a tax it cannot legally remit and the
  client cannot credit. So `is_pkp` defaults to `false` and the PPN question
  defaults to NO.
- **PPh 23 still applies to the operator's invoices** when the client is a
  corporate (badan) withholder, because PPh 23 is withheld by the *client*, not
  charged by the vendor (see §3). It reduces the cash received, so the invoice
  should show it as a net-payable memo.

If/when PT Aenoxa forms and registers as PKP, flip `is_pkp` to `true` in config
and the PPN path turns on. Until then, non-PKP is the truth.

---

## 2. PPN (VAT) - 12% formal, 11% effective

### The mechanism (this is the confusing part)

- The **formal PPN rate is 12%** (UU HPP, effective 2025-01-01).
- For **most non-luxury goods and services**, the government applies an
  **effective 11%** via a **DPP Nilai Lain** (an "other tax base"): the taxable
  base is set to **11/12 of the transaction value**, then 12% is applied to
  that base. `12% × (11/12) = 11%` effective. Sources: **PMK 131/2024** and
  **PMK 11/2025**.
- Net effect for ordinary software-dev services: the PPN you compute is
  **effectively 11%** of the invoice value. That is why config keeps
  `effective_rate: 0.11` as the number used in the compute step.
- A **2025+ Faktur Pajak** shows the DPP Nilai Lain arithmetic (base = 11/12 ×
  value, then 12%). The commercial invoice this skill renders only needs to
  show the effective PPN line; the formal DPP calc belongs on the Faktur Pajak.

### Moving target (flag this)

There is **active 2026 political discussion** (e.g. Menkeu-level statements)
about adjusting the rate/mechanism. Do **not** hardcode 11% as permanent. The
skill treats `effective_rate` as a config value with a `last_verified` stamp,
and this file is the place to re-confirm it. If policy shifts, update
`config.defaults.ppn.effective_rate` + `last_verified`, not the code.

### PKP prerequisite

You may only turn PPN on if **both**: `is_pkp == true` AND a **real,
non-placeholder company NPWP** is set. PKP registration is generally required
once annual turnover crosses the small-business threshold (commonly cited at
Rp 4.8 billion/year), or voluntarily. Below it, staying non-PKP is normal.

---

## 3. PPh 23 - withholding on services (the net-payable surprise)

### What it is

**PPh Pasal 23** is an **income-tax withholding the CLIENT deducts** when paying
a vendor for certain services (jasa). Software development / technical services
(jasa teknik / jasa lain) fall in scope (jasa lain enumerated under **PMK
141/2015** and its successors).

- **Rate: 2%** of the DPP (the service fee **excluding PPN**).
- **Rate: 4%** (i.e. 2% × 200% uplift) **if the vendor has no NPWP.** Having a
  valid NPWP halves the withholding, a concrete reason for the operator to hold
  and quote an NPWP.
- **Base = the gross service value excluding PPN** (in this skill: `tax_base`,
  the subtotal minus any discount, before PPN).
- **The client withholds and remits it**, then issues the vendor a **bukti
  potong** via **e-Bupot Unifikasi**. The vendor later credits that against its
  own annual income tax. It is **NOT** a tax the vendor charges or remits.

### Why the invoice must show it

Without it, the "Total" misrepresents cash. Example: bill Rp 10.000.000 of dev
work to a corporate client, non-PKP vendor with NPWP:

```
Subtotal / Total ............ Rp 10.000.000
Less: PPh 23 (2%) withheld ... - Rp   200.000   (client remits this to DJP)
Net payable to vendor ....... Rp  9.800.000   (what actually hits the bank)
```

So the invoice renders PPh 23 as an **informational memo + net-payable line**,
never as a vendor-side deduction the vendor pays. The **arithmetic Total is
unchanged**; the memo just tells both sides what will transfer.

### When it does NOT apply

- Client is an **individual / non-withholder** (many small clients) → no PPh 23;
  they pay the full Total.
- The engagement is structured as goods/licences rather than jasa (rare here).
- When unsure whether a given client withholds, **ask** rather than assume.

---

## 4. Commercial invoice vs Faktur Pajak (do not conflate)

| | This skill's output | Faktur Pajak |
|---|---|---|
| What | A **commercial invoice** (a bill / tagihan) | The **legal tax invoice** for PPN |
| Who issues | Anyone billing a client | **Only a PKP** |
| How | This skill (HTML → PDF) | **Coretax e-Faktur** (DJP system), with an NSFP number |
| Purpose | Request payment, state terms | Evidence PPN was charged, lets client credit input PPN |

**HARD:** never label this PDF a Faktur Pajak. If `is_pkp`, the user must ALSO
issue the real Faktur Pajak through Coretax e-Faktur separately; this commercial
invoice does not replace it. State that in the run summary when `is_pkp`.

---

## 5. NPWP format - 16-digit (Coretax era)

- Indonesia migrated from the legacy **15-digit** NPWP to a **16-digit** NPWP
  under the Coretax rollout (2024-2025).
- **Individuals (perorangan):** the 16-digit NPWP is **NIK-aligned** (the KTP
  NIK is the 16-digit NPWP).
- **Badan (companies):** the old 15-digit NPWP is carried into 16 digits
  (commonly a leading `0` prepended).
- The old placeholder mask `XX.XXX.XXX.X-XXX.XXX` is the **legacy 15-digit**
  format and is stale. Use a 16-digit value.
- **Exact display formatting (dotted vs plain 16 digits) - verify with the
  user.** Practice varies during the transition. Do not invent a mask; ask, or
  print what the user provides verbatim.

---

## 6. Dates & locale

### Month-name map (ID)

| # | English | Indonesian |
|---|---|---|
| 01 | January | Januari |
| 02 | February | Februari |
| 03 | March | Maret |
| 04 | April | April |
| 05 | May | Mei |
| 06 | June | Juni |
| 07 | July | Juli |
| 08 | August | Agustus |
| 09 | September | September |
| 10 | October | Oktober |
| 11 | November | November |
| 12 | December | Desember |

### Per-field date rule (one canonical format each, no mixing)

- **On the rendered PDF/MD (human-facing):** `D MMMM YYYY`. Use the Indonesian
  month name when the client is Indonesian (default market), else English.
  Example: `31 Maret 2026` (ID) or `31 March 2026` (EN). Pick one per invoice by
  client locale and use it for BOTH invoice date and due date.
- **In the JSON record (machine):** ISO 8601 `YYYY-MM-DD` always, regardless of
  display locale. Timestamps carry `+07:00` (WIB).
- **Never** get real dates by hand-calculation. Use
  `TZ=Asia/Jakarta date +%Y-%m-%d` for today and compute the due date by adding
  `payment_terms_days` (see SKILL.md).

---

## 7. Source pointers (re-verify here)

- **pajak.go.id** - DJP official; PPN mechanism, PPh 23 tarif & objek, NPWP 16
  digit / Coretax, e-Bupot Unifikasi, e-Faktur.
- **PMK 131/2024** + **PMK 11/2025** - PPN 12% formal + DPP Nilai Lain 11/12
  (effective 11%).
- **PMK 141/2015** - jasa lain objek PPh 23 (includes technical/IT services).
- **UU HPP (UU 7/2021)** - the 12% PPN basis.

Cross-check at least the PPN effective rate and the PPh 23 objek before a
high-value or first-time-for-a-new-client invoice. Update `last_verified` in
config + the stamp at the top of this file when you do.
