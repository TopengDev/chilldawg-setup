# /case-study worked examples

Two structure skeletons + one fully worked end-to-end trace. **These are STRUCTURE templates: when actually run, every bracketed value comes from the §2 gathering pass + §2f, never from these examples.** Numbers below are illustrative placeholders, deliberately tagged; do not copy them as facts. Everything here is dash-free per SKILL.md §0.1 (the skill practices what it enforces).

---

## Example A: Pulse POS (whole-product, `--for portfolio`, `--role "fullstack engineer"`)

```markdown
# Pulse: a multi-tenant POS that runs offline-first on cheap Android hardware

**Built solo: a Next.js POS web app + a native Android shell, multi-tenant, live in production for an Indonesian SMB market where the hardware is cheap and the internet drops.**

## Summary
Pulse is a point-of-sale system for small Indonesian retailers. The hard part wasn't the
CRUD, it was making it reliable on low-end Android devices with flaky connectivity, across
multiple tenants, while keeping subscription + role logic correct. Shipped to production;
[needs Christopher: tenant count] businesses use it.

## Problem & context
Indonesian SMBs need POS that works when the internet doesn't, on the cheap Android tablets
they already own. Existing options charge per-user/per-outlet, which punishes growing shops.

## Constraints
- Solo build (I was the only engineer).
- Target devices: low-end Android, limited RAM, intermittent network.
- Chrome blocks PWA-to-localhost (LNA) for hardware (printers/scanners), a real wall.
- Bootstrapped: one VPS, no infra budget.

## Approach
A Next.js multi-tenant web app for the POS surface, wrapped in a native Android (Capacitor +
Kotlin) shell so I could talk to Bluetooth/USB/TCP hardware that the browser sandbox forbids:
the industry-standard POS pattern, reached after PWA bridges hit Chrome's LNA wall.

## Key decisions & trade-offs
- **Capacitor + a Kotlin hardware plugin over a pure PWA.** Chrome's Local Network Access
  block made PWA-to-localhost hardware bridging unreliable; WebView is exempt. Traded "pure
  web, one codebase" for a native shell I now maintain, worth it because hardware access is
  non-negotiable for POS. (Rejected the HTTP-bridge PWA approach after it kept failing.)
- **Subscription gates the owner only; staff inherit via membership.** [why + the trade-off,
  pulled from memory reference_pulse_entitlement_model, via the MEMORY.md index] ...
- **Disabled Serwist navigationPreload to fix flaky OAuth.** navigationPreload double-fetched
  the redirecting OAuth callback, the Google one-time code got reused, roughly 50/50 login
  failures. [the real fix, from memory reference_pulse_sw_oauth_navigationpreload] ...

## What shipped
- Offline order capture + sync; multi-tenant isolation; role-based access; native
  Bluetooth/USB/TCP printing + scanning; subscription/entitlement enforcement.
- Live in production.

## Outcome
- Running in production, used daily by [needs Christopher: real number] retailers.
- [If he gives latency/uptime numbers, they go here, tagged. Else qualitative + honest.]

## Tech stack
Next.js 16 · React 19 · TypeScript · Capacitor · Kotlin · [DB] · Docker · nginx · a VPS

## What I'd do differently
- The native shell is a second codebase to maintain. I'd evaluate whether a thinner native
  layer (hardware-only bridge) could shrink that surface.
- [A real entitlement/sync edge he'd revisit, from §2f.] ...
```

---

## Example B: fitest QA automation (body-of-work, `--for application`, `--role "QA / SDET"`, NDA-aware)

```markdown
# Authoring a large automated test suite for an enterprise banking admin system

**As QA on a banking project (under NDA), I authored and maintained 900+ automated UI test
rows across 27 suites for a web admin system, and helped diagnose a framework-level
Selenium failure that was silently breaking a whole class of tests.**

## Summary
On an enterprise banking engagement I owned test authoring for a complex web admin: dozens of
suites, hundreds of scenarios, with a hard requirement that a human QA team could READ and
maintain them. I also root-caused why a category of row-action/modal tests failed under the
Selenium runner but passed under Playwright.

## Problem & context
A bank's web admin needed broad, maintainable UI test coverage. The team, not just me, had
to keep the suites alive, so readability + stable locators mattered as much as coverage.

## Constraints
- Client under NDA; I'll keep system specifics abstract.
- Human-maintainable was a hard, stated requirement (not automation-optimal complexity).
- Real DBs sat behind a double-jumphost; no direct data access for seeding.

## Key decisions & trade-offs
- **Stable-locator + readable-scenario standard over clever-but-terse automation.** [the real
  authoring standard, from memory reference_fitest_bms_authoring_standard] Traded brevity for
  a suite a non-author can maintain. ...
- **Reframed bug reports from an FE-observable angle.** [why: the QA-scope discipline] ...

## What shipped
- 900+ test rows / 27 suites authored + maintained. [placeholder counts: confirm from the
  fitest artifacts + memory before use]
- A diagnosed, reproducible framework bug (synthetic-event `isTrusted` under chromedriver)
  that unblocked ~74 suites once the infra was fixed. [confirm count]

## Outcome
- [Real coverage/pass-rate numbers IF Christopher confirms; else: "suites adopted by the
  client's QA team", qualitative + honest.]

## Tech stack
[the real test framework] · Selenium / Playwright · [language] · CSV/MD scenario authoring

## What I'd do differently
- I'd push for the human-readability standard to be agreed UP FRONT; we redid suites once
  because the maintainability bar was set late. [a real lesson, from §2f + memory
  feedback_human_first_test_authoring.]
```

Note how both skeletons: name real constraints, give every decision a real trade-off, tag/placeholder every number that isn't yet confirmed, and end on honest reflection. That's the bar.

---

## Fully worked end-to-end trace (`--for application`, illustrative)

The whole pipeline on one compact run. Command shapes are real; outputs are placeholder illustrations tagged as such.

### 1. Invocation

```
/case-study ~/claude/Git/repositories/aenoxa_pos_web --for application --role "senior fullstack engineer (fintech)" --length short
```

Format-gate row locked: application = <= 45 lines + 3-5 line strict-voice blurb, lands in `~/claude/notes/applications/`.

### 2. Gathering pass (§2, illustrative outputs)

```bash
cat package.json                     # [illustrative] next 16.x, react 19.x, serwist, capacitor deps
cloc .                               # [illustrative] 12,204 LOC / 181 files
git -C . shortlog -sn HEAD           # [illustrative] 1 author (solo confirmed); the HEAD is load-bearing: without a revision, shortlog reads stdin in non-interactive shells and returns empty
git -C . log --oneline | wc -l       # [illustrative] 214 commits
grep -rIl -iE 'oauth|offline|idempoten' src | head   # [illustrative] sw.ts, sync/, auth/callback
```

Memory intake, index-first: `~/.claude/memory/MEMORY.md` leads to `reference_pulse_entitlement_model.md` + `reference_pulse_sw_oauth_navigationpreload.md` (the why behind two key decisions). Evidence floor met: deps + LOC + commits + code files = 4 artifacts, 3 types.

### 3. §2f answers (illustrative)

Christopher: "solo build, live, don't publish tenant counts yet." Tenant count becomes a `[needs Christopher]` gap, NOT a number.

### 4. Draft (45 lines, body voice) + cover blurb (strict voice)

Body: the Example A shape compressed to one screen, fintech-signal decisions first (entitlement correctness, OAuth double-fetch root cause, offline sync integrity).

Blurb (strict outreach symbol set, §0.3):

```
built & shipped Pulse: a multi tenant offline first POS (Next.js + Capacitor/Kotlin)
solo: web app + native Android shell + subscription/entitlement enforcement
live at topengdev.com (case study attached)
happy to walk through the offline sync & OAuth root cause work
```

### 5. Ledger written: `~/claude/notes/applications/pulse-fintech.evidence.md`

| # | Claim (verbatim) | Type | Evidence | Status |
|---|---|---|---|---|
| 1 | "12k LOC across 181 files" | scale | cloc run [illustrative] | VERIFIED |
| 2 | "built solo" | attribution | git shortlog -sn HEAD: 1 author | VERIFIED |
| 3 | "live in production" | status | Christopher said, [date] + deploy config grep | CHRISTOPHER |
| 4 | "roughly 50/50 login failures" | metric | memory reference_pulse_sw_oauth_navigationpreload | CHRISTOPHER |

### 6. Verification block run (§0.4)

```bash
FILES=~/claude/notes/applications/pulse-fintech*
grep -rnP "[\x{2013}\x{2014}]" $FILES            # silent
grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]" $FILES   # silent
# V3 filler grep: silent
# V4 secret grep: silent
# V5 /home/christopher grep: silent on the case study + blurb (ledger exempt, private)
```

Skim score: [illustrative] 14/16, none of #4/#5/#6 zero. Pass.

### 7. Land + report (tables, §EXECUTION FLOW step 10)

```bash
mkdir -p ~/claude/notes/applications
```

| Landed file | What | Format row |
|---|---|---|
| `~/claude/notes/applications/pulse-fintech.md` | 1-screen case study + strict blurb | application: 43/45 lines, blurb 4 lines |
| `~/claude/notes/applications/pulse-fintech.evidence.md` | claim-evidence ledger | 4 rows, 0 UNVERIFIED |

| Ledger summary | count |
|---|---|
| VERIFIED | 2 |
| CHRISTOPHER | 2 |
| ESTIMATE / TARGET / UNVERIFIED | 0 |

| Needs Christopher | Where tagged | Suggested source |
|---|---|---|
| tenant count (publish or keep private?) | Outcome section | his call |

One prose line: "Application case study + blurb ready; paste the blurb into the DM, attach or link the 1-screen."
