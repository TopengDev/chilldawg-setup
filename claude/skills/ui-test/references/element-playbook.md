# Element Testing Playbook — hybrid algorithm, matrices, regexes, re-login

Depth companion to SKILL §7.3/§8. Everything here assumes the claimed-port session, the
`wait --load networkidle` discipline, and the hazard classifier ran first.

## 1. The hybrid two-pass algorithm (THE algorithm — full form)

**Why isolation exists at all:** in an SPA, interactions like expand/collapse, tab
switches, and dropdown opens mutate the DOM, making subsequent elements unfindable by
identity. Navigating AWAY and BACK guarantees the page re-renders from scratch with its
default state — no collapsed menus, no open modals, no toggled switches; every isolated
element test starts from a clean slate. **Why not isolate everything:** away-and-back per
element costs 2-3x wall clock, blows the 30-min role budget, and multiplies again under the
theme axis. Hence two passes.

### Pass 0 — inventory + classification (once per page per theme)

```
1. Navigate {baseUrl}{page.path}; agent-browser wait --load networkidle  (fallback: wait 2000)
2. agent-browser snapshot -i -c --json  → parse interactive elements → identity list, count = N
3. Classify every element (SKILL §8.1): SAFE / NAV / FORM / HAZARD-*  → per-class counts
4. Partition SAFE+NAV+FORM into:
   - pass1 set: non-DOM-mutating (links, textboxes, checkboxes, switches, toast-buttons)
   - pass2 set: DOM-churny (expanders, tabs, modal-openers, menus, accordion toggles)
   Heuristic: aria-expanded / aria-haspopup present, or role in {tab, menuitem, combobox},
   or label suggests open/expand/filter → pass2. When unsure → pass2 (safe, just slower).
```

### Pass 1 — single-visit sweep (fast, ~80% of elements)

```
For each element in pass1 set (stable order: snapshot order):
  a. If a previous interaction in this visit mutated the DOM → re-snapshot, re-find by
     identity (type + normalized text + position among same-text siblings)
  b. Interact per the type matrix (§2 below); 5s timeout, 1 retry after 1s
  c. Verify outcome (§3 below); record {index, type, text, class, action, result}
  d. NAV links: click → verify URL changed → agent-browser back → wait --load networkidle
```

### Pass 2 — isolate-per-element (DOM-churny only)

```
For each element in pass2 set:
  a. Navigate to a neutral page (first pages[] entry or /dashboard); wait 1s
  b. Navigate back to {baseUrl}{page.path}; wait --load networkidle
  c. Fresh snapshot (guaranteed default DOM state)
  d. Find element by identity (type + text) at its recorded position
     → not found: SKIPPED(not-refound), continue
  e. Interact per type matrix; verify; record
  f. If the interaction opened a modal/menu: verify it opened (PASS), then close it
     (Cancel / Escape / close button) and re-snapshot to confirm closed — leaving it open
     would contaminate nothing (next element re-navigates) but closing verifies the
     dismiss path for free
5. Report per page: N found, T tested, S skipped (with reasons), M passed, K failed
   → the coverage arithmetic gate: N == T + S  (SKILL §7.3.7)
```

### The >40 trigger

A page with >40 interactive elements MUST use this hybrid (SKILL §3). Under 40 you may
still isolate-everything if the page is extremely churny, but record why — the hybrid is
the default everywhere.

## 2. Element type matrix

| Type | Action | Verification | Notes |
|---|---|---|---|
| `button` | click (AFTER hazard classification) | some visible change (toast/modal/state/nav) | screenshot toast IMMEDIATELY — many auto-dismiss <2s |
| `link` | click | URL changed to expected path | then `back` + `wait --load networkidle` |
| `textbox` | `fill @ref "test123"` | input accepts text, no crash | `fill` clears first; `type` APPENDS — never type into a field that must be replaced |
| `combobox` | **`focus @ref` then `press Enter`** | options appear | Radix/React-Select do NOT open via click or JS — keyboard is the field-verified path (agent-browser §5.2; atlas §13.3 item 7). Plain `<select>`: `select @ref <value>` works |
| `checkbox` | `check @ref` (or click) | checked state flips (`is checked`) | restore original state after verify when in pass 1 |
| `switch` | click | state flips | same restore note |
| `tab` | click | tab content changes | Radix TAB lists click fine via refs |
| `menuitem` | click | menu/submenu appears | pass 2 (DOM-churny) |
| `slider` | SKIP | — | record SKIPPED(unsupported-type) — needs coordinate interaction |
| `colorpicker` | SKIP | — | SKIPPED(unsupported-type) |
| date spinbutton | do NOT fill the a11y spinbuttons | — | React ignores a11y-level fills of the hidden `<input type=date>`; use the native-setter eval (atlas §13.3 item 13) ONLY when a flow needs a date — element-pass just records the widget |
| file-upload trigger | SKIP | — | HAZARD-NATIVE: native OS picker, not CDP-capturable (atlas §13.3 item 14) |

**Filter out before counting:** elements with `disabled` (count as SKIPPED(disabled)),
`aria-hidden="true"`, elements inside hidden containers, and browser-UI artifacts. Disabled
elements are counted-and-skipped (they appear in the arithmetic), invisible ones are not
elements at all.

## 3. Outcome verification order (check in sequence after each interaction)

1. **URL changed?** → navigation. PASS.
2. **Modal/dialog appeared?** → PASS (modal opened). For hazard elements this IS the pass
   condition (confirm guard exists) — then CANCEL per SKILL §8.1.
3. **Toast/notification appeared?** → PASS. Screenshot immediately.
4. **Page content changed?** → PASS.
5. **Element state changed?** (checked/toggled/selected) → PASS.
6. **Nothing happened?** → record exactly `"no visible effect"` — then `is enabled @ref`:
   disabled → reclassify SKIPPED(disabled); enabled → keep as informational, NOT a FAIL
   and NOT a PASS. Never inflate.
7. **Error/crash/404?** → FAIL. Screenshot `.../failures/{page}-element-{i}-{text}.png`.

## 4. Hazard regex lists (EN + ID — SKILL §8.1's trigger column, expanded)

Case-insensitive, matched against the element's accessible name/label + `aria-label` +
`title`. Word-boundary match to avoid false hits ("reset" should not match "presets" —
use `\b` anchors).

```
DESTRUCTIVE:   \b(delete|remove|hapus|clear|reset|wipe|purge|destroy|kosongkan|bersihkan|batalkan semua)\b
IRREVERSIBLE:  \b(send|kirim|pay|bayar|transfer|publish|terbitkan|email|broadcast|checkout|mint|place order|buat pesanan)\b
APPROVE-QUEUE: \b(approve|setujui?|reject|tolak|authorize|otorisasi)\b        → UT-HR-6 applies on top
SESSION:       \b(log ?out|logout|sign out|keluar|end session|akhiri sesi)\b
NATIVE:        \b(print(er)?|cetak|bluetooth|usb|camera|kamera|scan|pair|choose file|pilih file|upload|unggah)\b
ACCOUNT:       \b(suspend|deactivate|nonaktifkan|remove member|hapus anggota|change role|ubah peran|reset password|ganti pin|permission|izin akses)\b
```

Destructive **iconography** counts as a verb match: `aria-label`/name containing
`trash|bin|delete icon|sampah`. Locale-aware matching: when crawling in a non-default
locale, match that locale's strings — or fall back to role+position identity from the
default-locale inventory.

**Guard evidence** (licenses open-then-cancel on real data — SKILL §8.1): `aria-haspopup="dialog"`
on the element, a confirm dialog observed for this element in a prior run/atlas dossier
(`confirmation_required: true`), or the app's design system provably wraps this action class
in confirms. No evidence + real data → SKIP(hazard-unprobed). Clicking to find out is the
failure mode (atlas §6 R3/N13).

## 5. Config-driven re-login recipe (generic — UT-PB-B / mid-run expiry)

Triggered when a crawled page redirects to `login.url`. All values come from config — no
hardcoded UI strings.

```
1. Navigate {baseUrl}{login.url}; wait --load networkidle
2. snapshot -i -c --json → locate login.emailField / login.passwordField / login.submitSelector
   (by selector; fallback: find label "Email" / find label "Password")
3. fill <emailField>  "${!role.emailEnv}"       # fill, NEVER type
   fill <passwordField> "${!role.passwordEnv}"  # no screenshot from here until post-submit (UT-HR-8)
4. click <submitSelector>; wait up to 10s for login.successIndicator
5. If login.tenantSelector: click its match; verify its "then" indicator
   (fresh logins can reset locale AND tenant — re-select BOTH; atlas §13.3 item 6)
6. Verify with one known page (first pages[] entry) before resuming
7. Resume from the page that triggered the redirect — earlier results stand
```

### Labeled Pulse example (NOT generic truth — env refs only)

```
role owner:  emailEnv=PULSE_TEST_EMAIL  passwordEnv=PULSE_TEST_PASSWORD
tenantSelector: { "match": "text:Lancar Jaya", "then": "url:/dashboard" }
session.ttlMinutes: 15        # Pulse JWT TTL — the reason its keep-alive is every 10 min
```

The Alamanda Coffee tenant exists ONLY on the `$PULSE_ALAMANDA_*` (toper289982) account —
verified worker dead-end 2026-06-22. Never mix the accounts; never write either credential
anywhere.

## 6. Snapshot parsing gotchas (field-collected — keep)

- Parse `agent-browser snapshot -i -c --json`: each line yields type, quoted text/label,
  `[ref=eN]`, attributes (`required`, `expanded`, `selected`, `disabled`).
- Element text may contain newlines/extra whitespace — NORMALIZE before identity matching.
- Some elements have no text (icon buttons, bare checkboxes) — match by type + attributes +
  position; check `aria-label` for the hazard regexes before declaring SAFE.
- Duplicate elements with identical text — disambiguate by position index among same-text
  siblings (identity = type + normalized text + occurrence index).
- `combobox` may appear as `combobox "(no text)"` — handle empty text gracefully.
- `@eN` refs are VOLATILE (agent-browser HR-10): never reuse across a DOM mutation;
  re-snapshot or use semantic locators. `find role button click --name X` exists in 0.22.3
  `--help` but is unverified in this env (atlas §13.3 item 12) — on an "Unknown subaction"
  or no-match failure, fall back to snapshot-then-act in the same step.
- Do NOT combine screenshot + eval in one Bash call — exits 144 in this env; split into two
  calls (atlas §13.3 item 11).
- Radix portal modals are invisible to main-document `querySelectorAll` — target
  `document.getElementById('radix-<id>')` for JS assertions; trust the a11y snapshot for
  classification (atlas §13.3 item 15).
- Infinite-scroll pages: bound the inventory to the first viewport + ONE scroll page
  (`agent-browser scroll down 800` once), and note the bound in the report.

## 7. Per-element budget recap (from SKILL §3 — the numbers that govern this file)

5s interaction timeout → exactly 1 retry after 1s → FAIL. 30-min hard/role. >40 elements →
hybrid mandatory. Toast screenshots immediate. Every skip reasoned. `found == tested + skipped`
or the run is INCOMPLETE.
