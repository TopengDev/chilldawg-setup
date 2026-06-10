---
name: case-study
description: Turn a shipped project / repo / piece of work into a portfolio-grade case study (for GitHub README, portfolio site, or a job application). Analyzes the ACTUAL codebase, commits, and deploys — never invents — then produces a recruiter-skimmable, evidence-driven narrative (problem → constraints → approach + real trade-offs → what shipped → outcome → stack → what I'd do differently). Use when Christopher says /case-study, asks to "write up", "document for portfolio", "turn this into a case study", or wants a project framed for hiring/freelance.
argument-hint: <repo path | project name | "the X feature in repo Y"> [--for github|portfolio|application] [--role <target role>] [--length short|standard|deep]
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
---

# /case-study — shipped work → portfolio-grade, evidence-driven case study

Take a real project (a repo, a feature, a shipped system) and produce a **case study a senior engineer would respect and a recruiter can skim in 90 seconds**. The entire point is honest, evidence-backed proof of competence — material for Christopher's job-hunt + freelance push (see income-diversification: freelance is the anchor income path, and case studies are the proof-points that win contracts and pass screens).

This skill exists because the #1 failure mode of AI-written case studies is **fabrication + filler** — invented metrics, "leveraged cutting-edge synergies" mush, claims the code doesn't support. A fabricated metric that a sharp interviewer probes ("how did you measure that 40%?") is worse than no metric: it detonates trust mid-interview. So this skill is built around one spine: **read the real artifacts, write only what they prove, mark estimates as estimates, and sound like Christopher — not a press release.**

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES — READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

Violating any one of these is a failed case study, not a stylistic choice.

1. **EVIDENCE-DRIVEN ONLY — NEVER FABRICATE.** Every factual claim (a number, a stack choice, a feature, a date, an outcome) must trace to a real artifact you read: a file, a commit, a `package.json` dep, a deploy config, a README, a benchmark, or something Christopher explicitly told you. **If a metric is not real and not provided, OMIT it or mark it `[estimate]` / `[unverified]` with the basis.** No invented percentages, no made-up user counts, no "improved performance by 40%" unless 40% is measured and you can point at where. When in doubt, leave it out — an honest gap beats a fabricated win.

2. **ANTI-GENERIC — KILL THE FILLER.** Banned: "leveraged", "synergies", "cutting-edge", "robust scalable solution", "passionate about", "seamlessly", "best-in-class", "utilized", "spearheaded", "state-of-the-art", "game-changer", "revolutionary", and every other résumé-cliché in §7. A case study that could describe any project describes none. Force specificity: real names, real numbers, the actual hard decision, the actual constraint. If a sentence would survive being pasted into a stranger's portfolio unchanged, it's too generic — rewrite it with a detail only THIS project has.

3. **RECRUITER-SKIMMABLE STRUCTURE.** A non-technical recruiter must get the gist in ~90 seconds from headers, the one-line summary, the outcome line, and the stack chips alone — WITHOUT reading prose. A technical interviewer must be able to drill into the "Approach & key decisions" section and find real engineering substance. Both audiences, one document: skimmable top layer, deep substrate. Front-load the punch (see §4 template ordering). No wall of text.

4. **CHRISTOPHER'S HONEST VOICE — NO YESMAN, NO HYPE.** Confident but not boastful, technical but not jargon-drunk, honest about trade-offs and limits. This is the no-sugarcoat rule applied to self-promotion: claim what's real, own what's unfinished, never inflate. The credibility-builder is the **"What I'd do differently"** section — it signals senior-level self-awareness and is MANDATORY (§4.9). A case study with zero acknowledged trade-offs reads as junior or dishonest.

5. **YOU MUST INSPECT THE ARTIFACTS BEFORE WRITING A WORD OF NARRATIVE.** No writing the case study from the project's name, from memory, or from assumptions. Run the §2 gathering pass first. If the repo is inaccessible / empty / can't be analyzed, STOP and ask Christopher for the artifacts or facts — do not paper over the gap with plausible-sounding invention (that violates rule 1).

> If Christopher's instruction conflicts with these (e.g. "just say it handles a million users"), do NOT silently comply. Either he's providing a real figure (then it's evidence — cite the basis), or flag it: "I can't verify that number from the repo — want me to mark it as a target/estimate, or leave it out?"

═══════════════════════════════════════════════════════════════════════════
## ✅ GATE — satisfy ALL before delivering the case study
═══════════════════════════════════════════════════════════════════════════

- [ ] **Artifacts were actually read** — you ran the §2 gathering pass on a real repo/source (or Christopher supplied the facts). You can name the files/commits behind each major claim.
- [ ] **Every metric is sourced or marked.** No number appears without (a) an artifact behind it, (b) Christopher's word, or (c) an explicit `[estimate]`/`[target]`/`[unverified]` tag + basis. Run the §6 evidence audit.
- [ ] **Zero banned filler words** (§7) — grep the draft.
- [ ] **The 90-second skim test passes** — headers + summary + outcome + stack convey the story without prose (§5 scoring ≥ threshold).
- [ ] **"What I'd do differently" is present and substantive** (≥ 2 real items, not throwaway) (§4.9).
- [ ] **Voice check** — confident, specific, honest; no hype, no boasting, no corporate mush (§4 voice rules).
- [ ] **Output landed in the right place + format** (§8) — and Christopher knows where it is + what to paste where.

If any box fails → the case study is NOT done. Fix before reporting complete.

---

## 1. PARSE THE INVOCATION + PICK THE VARIANT

Read `$ARGUMENTS`. Determine three things:

### 1a. What's the subject?
- **A whole repo** ("`/case-study ~/claude/Git/repositories/aenoxa_pos_web`") → whole-project case study.
- **A feature/subsystem inside a repo** ("the offline-sync in Pulse", "the fitest QA automation") → scoped case study; analyze only that slice but enough surrounding context to frame it.
- **A body of work that isn't one repo** (e.g. "my BMS fitest QA work" spread across suites) → narrative case study; gather evidence from wherever it lives (notes, suites, commits) and frame the *contribution*, not a single codebase.
- **Ambiguous / no path** → ask: "Which repo or piece of work? Point me at a path or name it." Don't guess.

### 1b. What's it FOR? (`--for`, default: ask or infer `portfolio`)
The destination changes tone, length, and format:

| `--for` | Audience | Tone | Length | Format |
|---|---|---|---|---|
| `github` | Engineers browsing the repo | Technical, terse, code-forward | Short–standard | Markdown → `README.md` or `CASE_STUDY.md` in-repo |
| `portfolio` | Mixed (recruiter + eng) on a personal site | Polished, narrative, skimmable | Standard | Markdown → portfolio content file; may include a copy-paste blurb |
| `application` | A specific hiring manager / client for a specific role | Tailored to that role's signal | Short (1 screen) + a 3-line cover blurb | Markdown + a tight cover paragraph (see §4.10) |

### 1c. How deep? (`--length`, default `standard`)
- `short` — 1 screen. Summary + problem + 3 key decisions + outcome + stack. For a résumé link or `--for application`.
- `standard` — the full template (§4), every section, tight. The default.
- `deep` — full template + an "Architecture" subsection with a real diagram (ASCII or mermaid built from the actual module/service structure) + 1–2 code excerpts of the genuinely interesting bits (pulled verbatim from the repo, not invented).

If `--role` is given (e.g. `--role "senior backend engineer (fintech)"`), bias which decisions/metrics you surface toward that role's signal (a fintech role → emphasize correctness, idempotency, data integrity, security decisions; a frontend role → emphasize UX, perf, design-system decisions). Never fabricate to fit — just *select and order* from what's real.

---

## 2. GATHERING PASS (DO THIS FIRST — this is where the evidence comes from)

**No narrative until this pass is done.** Mirror the `/handover` analyze-the-real-codebase discipline. Work the checklist; capture findings as you go (you'll cite them later).

### 2a. Identity & stack (what is this, built with what)
Read whichever exist:
```bash
# stack + deps + scripts
cat package.json 2>/dev/null; cat pnpm-lock.yaml 2>/dev/null | head -5
cat pyproject.toml requirements.txt Pipfile 2>/dev/null
cat go.mod Cargo.toml composer.json Gemfile 2>/dev/null
cat README.md CLAUDE.md 2>/dev/null
cat docker-compose.y*ml Dockerfile 2>/dev/null
ls .github/workflows/ 2>/dev/null
```
Extract: real project name, what it does, languages/frameworks/major libs (with versions — versions are evidence), notable infra (Docker, CI, queues, DBs), deploy target.

### 2b. Shape & scale of the work (how much, how structured)
```bash
# size signal (real LOC, file count — concrete, honest scale)
cloc . 2>/dev/null || (echo "files:"; find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' -not -path '*/dist/*' -not -path '*/vendor/*' | wc -l)
# directory structure (the architecture, for real)
find . -type d -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' -not -path '*/dist/*' | head -60
```
This grounds scale claims in reality. "A 12k-LOC Next.js app across 180 files" is evidence; "a large-scale application" is filler.

### 2c. The story in the commits (the real timeline + the real hard parts)
```bash
git -C <repo> log --oneline -50 2>/dev/null
git -C <repo> log --shortstat --pretty=format:'%h %ad %s' --date=short -30 2>/dev/null
git -C <repo> shortlog -sn 2>/dev/null            # contribution split (honest about solo vs team)
git -C <repo> log --oneline | wc -l               # total commits = effort signal
```
Commit messages are a goldmine for the **real** problem→fix arcs (a `fix:` cluster around one subsystem = a genuine hard problem you solved — that's a key-decision candidate, not invention). The contribution split (`shortlog -sn`) keeps you HONEST about what Christopher personally did vs a team (rule 1 + rule 4 — never claim a teammate's commits).

### 2d. The interesting engineering (the substance interviewers probe)
Hunt for the genuinely non-trivial parts — these become §4.5 "key decisions":
```bash
# the gnarly bits: auth, payments, sync, concurrency, migrations, caching, queues
grep -rIl -iE 'webhook|idempoten|migration|race|retr(y|ies)|cache|queue|cron|oauth|encrypt|websocket|offline|reconcil' <repo>/src 2>/dev/null | head
# config/env shape (integration surface — what it talks to)
cat <repo>/.env.example <repo>/.env.sample 2>/dev/null
```
Read the actual implementation of 2–4 of these. The "approach & key decisions" section is only credible if you understood the real code. **Cross-reference memory** — Christopher's `~/.claude/memory/` (now a private repo) has deep project context (e.g. `project_aenoxa_pos_web.md`, `pulse-sw-navigationpreload-oauth-doublefetch.md`, the fitest entries). Use it for the *why* behind decisions, but PII stays out of the public case study (see §3).

### 2e. What shipped / is it live (outcome evidence, not aspiration)
```bash
# deploy reality: is it actually running? where?
grep -rIE 'topengdev|aenoxa|vercel|fly|railway|render' <repo> --include=*.json --include=*.ts --include=*.yml 2>/dev/null | head
```
- Is it deployed? URL? (A live URL is the strongest outcome proof — verify it resolves if you can, but don't over-invest; note "live at X" only if true.)
- Tests / CI present? (green CI is an outcome signal.)
- Real users / tenants? **Only if Christopher confirms** — never infer user numbers from code.

### 2f. Ask Christopher for the non-code facts (the things the repo CANNOT tell you)
The repo gives you the *what* and *how*. It usually cannot give you: the **business context**, the **real outcome/metrics**, the **constraints he was under**, and **why it mattered**. Ask a tight batch (don't interrogate — 3–6 targeted questions):
- "What problem/pain did this solve, and for whom?"
- "Any real numbers I can use? (users, tenants, latency, time saved, error-rate, revenue, load handled.) If none, that's fine — I'll keep it qualitative."
- "What were the hard constraints? (deadline, solo build, no budget, legacy system, device/offline, a specific client demand.)"
- "Is it live / in production / did it ship? Where?"
- "Solo or team — and which parts were yours?" (keeps attribution honest.)
- "Anything you're NOT proud of / would redo?" (feeds §4.9 authentically.)

If he's asleep/unavailable (autonomous run), write everything the artifacts DO support, and **explicitly mark the gaps** (`[needs Christopher: real user count]`) rather than inventing — he fills them on review. Never fabricate to avoid a blank.

---

## 3. PRIVACY & SECURITY PASS (before anything public)

A public case study is an attack surface and a leak risk. Before writing:

- **No secrets, ever.** No keys, tokens, passwords, internal hostnames, IPs, JIDs, phone numbers, `secrets.env` contents, or `.env` values. Grep your own draft for `sk-`, `password`, `token`, `$VPS_HOST`, `@s.whatsapp.net`, real phone numbers.
- **No PII** — Christopher's memory repo + notes contain real names (Suryadi, Hezkiel, Ryan, Laurel, client names) and private business context. The public case study must not expose people's names, private client identities, or internal infra without permission. Generalize: "a recruiter", "an enterprise banking client (under NDA)", "my co-founder" — not real names.
- **NDA / client-confidential work** (e.g. ISI/BRI/BMS fitest, BCAS) — frame the *contribution and skills* abstractly; never expose the client's internal system details, screenshots, or anything that would breach confidentiality. When unsure whether something is shareable, ask Christopher or default to the generalized version.
- **Strip internal paths** — `/home/christopher/...`, repo-internal structure that reveals nothing useful and looks unprofessional.

If the case study is `--for application` to a *specific* trusted recipient and Christopher okays naming a client, that's his call — default is generalized.

---

## 4. THE OUTPUT TEMPLATE (the case study structure)

Order is deliberate — front-loaded for the 90-second skim (rule 3). Sections scale by `--length` (short drops 4.6–4.8 detail; deep adds architecture + code).

### 4.0 Title + one-line hook
`# <Project> — <what it is> for <whom>` then a single bold line that states the result or the essence. The recruiter reads THIS first.
> *Good:* "**A multi-tenant POS that runs offline-first on cheap Android hardware** — built solo, live in production."
> *Bad:* "A robust, scalable solution leveraging modern technologies." (filler — banned.)

### 4.1 Summary (TL;DR — 2–3 sentences, skimmable)
The whole story compressed: what, why it was hard, what shipped, outcome. If someone reads only this, they understand the project and that you can build.

### 4.2 Problem & context
What problem, for whom, why it mattered. Concrete. The pain in the user's/business's terms. 2–4 sentences. (Sourced from §2f, not invented.)

### 4.3 Constraints
The real boundaries that shaped the work — these make the engineering *impressive* by showing what you optimized against. Solo build? Hard deadline? Zero budget / one cheap VPS? Offline/low-end devices? Legacy system? Regulatory? A specific client mandate? List the real ones (§2f). Constraints are where senior judgment shows; never pad with fake ones.

### 4.4 Approach (the strategy, briefly)
The high-level shape of the solution + WHY this shape. Architecture in a sentence or two (`deep` mode: promote to a real diagram from §2b). Not a feature list — the *thinking*.

### 4.5 Key decisions & trade-offs ⭐ (the technical heart — what interviewers drill)
3–5 real decisions, each as: **Decision → why → the trade-off you accepted → (the real alternative you rejected).** This is where engineering credibility lives. Pull these from the actual code/commits (§2c, §2d). Each must be a decision THIS project actually faced.
> *Shape:* "**Chose a JSON-file store over SQLite for the demo layer.** Sidestepped native-binding + migration risk in Alpine containers and kept the deploy dependency-free; traded real query power + concurrency safety, acceptable because the demo is single-writer seed data. (Rejected Prisma+SQLite — the migration/native-build fragility wasn't worth it for a throwaway demo.)"

Every decision must name a **real** trade-off. A decision with no downside is either trivial or you're not being honest (rule 4). Vague "chose the best tool for the job" is banned — name the tool, the reason, the cost.

### 4.6 What shipped
Concrete deliverables — the actual features/capabilities that exist and work (verified in §2). Bullet list, specific. "Offline order capture with conflict-resolution sync", not "various features". Note live URL / production status if real.

### 4.7 Outcome / results
The payoff, in evidence. **Real metrics if they exist** (§2e/2f) — latency, users, tenants, load, error-rate, time saved, money. **If no hard numbers, go qualitative and honest** ("shipped to production and used daily by the team"; "passed the client's UAT first round") — a truthful qualitative outcome beats a fabricated quantitative one (rule 1). Tag any estimate (`~50 tenants [estimate]`, `target: <100ms p95 [not yet measured]`).

### 4.8 Tech stack (skimmable chips)
A clean, scannable list/table of the real stack from §2a — languages, frameworks, infra, notable libs. With versions where they signal currency (Next 16, React 19). The recruiter's eyes land here; make it a glanceable chip row, not a paragraph.

### 4.9 What I'd do differently ⭐ (MANDATORY — the senior-signal)
2–4 honest reflections: what you'd change, what you under-built, a trade-off you'd revisit, a scaling cliff you see, debt you knowingly took. This is the single strongest credibility move in the whole document — it proves self-awareness and that you understand the system's limits, which is exactly what separates senior from junior. **Never skip it. Never make it fake-humble** ("I'd add even MORE tests" is a humblebrag, banned). Real: "The JSON store won't survive concurrent writers — for a real product I'd move to Postgres with proper migrations from day one." (Sourced honestly, often straight from §2f's "what aren't you proud of".)

### 4.10 (`--for application` only) Cover blurb
A 3–5 line paragraph Christopher can paste into an application / DM / cover note, in HIS voice (see §4 voice rules + the writing-style note below), that points at this case study as the proof-point. Tailored to `--role`. This is the bridge between `/case-study` and `/outreach` — the outreach message leads with a proof-point; this is that proof-point, packaged.

### Voice rules (apply throughout)
- **First person, past tense, active.** "I built", "I chose", "I traded" — Christopher's own work, owned plainly.
- **Confident, not boastful.** State what's real and let it stand. No "I'm passionate about", no "world-class", no exclamation-pile.
- **Specific over impressive-sounding.** A real detail (a number, a name, a constraint) beats any adjective.
- **Honest about limits.** Trade-offs and "what I'd do differently" are features, not weaknesses.
- **Note on Christopher's stylized voice:** for prose written as Christopher in his *personal* register (a portfolio "about"-style blurb, an outreach cover line — esp. §4.10), he has a specific stylistic preference (no emoji; a restricted punctuation set — line breaks instead of periods/commas/dashes; tech names kept intact). His memory carries the exact rule (`feedback_toper_writing_style`). The case-study BODY is normal technical prose (use normal punctuation — it must read as professional engineering writing); the stylistic constraint applies to the §4.10 cover blurb / first-person personal-voice lines IF he wants it. When in doubt for a cover blurb, ask which voice; default the technical body to standard, clean prose.

---

## 5. SKIMMABILITY SCORING (run before delivery — rule 3 enforcement)

Score the draft 0–2 on each. **Ship only at ≥ 12/16.** Below that, restructure.

| # | Criterion | 0 | 1 | 2 |
|---|---|---|---|---|
| 1 | 90-sec skim conveys the story (headers+summary+outcome+stack alone) | needs full read | mostly | yes |
| 2 | Punch is front-loaded (title + summary land the result) | buried | partial | nailed |
| 3 | Key-decisions section has real engineering substance | generic | some | drillable depth |
| 4 | Every metric is sourced or tagged | fabricated/bare | mostly | all clean |
| 5 | Zero banned filler words (§7) | several | 1–2 | none |
| 6 | "What I'd do differently" is real + substantive | missing/fake | thin | genuine |
| 7 | Stack is a glanceable chip row, not prose | paragraph | mixed | clean chips |
| 8 | Voice = confident + honest, no hype | hype/boast | mixed | dialed |

If any of #4, #5, #6 scores 0 → automatic fail regardless of total (those are the non-negotiables 1, 2, 4). Fix and re-score.

---

## 6. EVIDENCE AUDIT (run before delivery — rule 1 enforcement)

Go through the finished draft claim by claim. For EACH factual statement, confirm a source:

| Claim type | Required backing |
|---|---|
| A number/metric | An artifact (benchmark, config, `wc`, commit count) OR Christopher's word OR a `[estimate]`/`[target]`/`[unverified]` tag + basis |
| A stack/lib choice | Present in `package.json`/lockfile/imports (§2a) |
| A feature "shipped" | The code for it exists + works (§2d/2e) |
| Scale ("X users/tenants") | Christopher confirmed it — NEVER inferred from code |
| "Live in production" | A real, resolving deploy (§2e) |
| A teammate-vs-solo claim | `git shortlog -sn` (§2c) — never claim others' work |

Any claim that fails this audit: **delete it or tag it.** This pass is the firewall against the fabrication failure mode. Do it every time.

---

## 7. BANNED FILLER (anti-generic — rule 2)

Grep the draft for these and kill every one (replace with a project-specific detail or cut):

**Résumé clichés:** leveraged, leverage, synergy/synergies, cutting-edge, state-of-the-art, best-in-class, world-class, robust scalable solution, seamlessly/seamless, spearheaded, utilized/utilize, passionate about, game-changer, revolutionary, paradigm, "next-level", "blazing-fast" (unless you measured it), "highly performant" (unless measured), "enterprise-grade" (unless it literally is), "battle-tested", "bleeding/bleeding edge".

**Empty intensifiers:** very, really, extremely, incredibly, super, a lot of, numerous, various (as in "various features"), "a wide range of", "myriad".

**Vague-strength claims with no evidence:** "significantly improved", "dramatically reduced", "greatly enhanced", "optimized performance" — all BANNED unless paired with a real measured number.

**The tells of AI-generated prose:** "In today's fast-paced world", "It's worth noting that", "delve into", "tapestry", "testament to", "underscore", em-dash-stuffed triplets used decoratively.

Replacement discipline: every time you delete a filler word, the fix is a **concrete detail this project actually has** — not a different adjective.

---

## 8. WHERE OUTPUTS LAND

| `--for` | Default location | Notes |
|---|---|---|
| `github` | `<repo>/CASE_STUDY.md` (or fold into `README.md` if Christopher wants) | Lives with the code; engineers find it on the repo |
| `portfolio` | `~/claude/Git/repositories/<portfolio-repo>/content/case-studies/<slug>.md` if a portfolio repo exists, else `~/claude/notes/case-studies/<slug>.md` | Christopher ports into his portfolio site; also emit a short paste-blurb |
| `application` | `~/claude/notes/applications/<company-or-role>-<slug>.md` | The 1-screen version + the §4.10 cover blurb, tailored to that role |

Always:
- Confirm the repo's actual layout before writing INTO it (don't clobber an existing `README.md` — append or write `CASE_STUDY.md`, and only with Christopher's nod).
- Write the file, then **tell Christopher exactly where it is and what to paste where** ("CASE_STUDY.md in the repo root; the 3-line blurb at the bottom is ready to drop into a LinkedIn DM").
- If autonomous + the destination is ambiguous, default to `~/claude/notes/case-studies/<slug>.md` and flag it for him to relocate.

---

## 9. WORKED-EXAMPLE SKELETONS

Two skeletons showing the shape + the honesty discipline. **These are STRUCTURE templates — when actually run, every bracketed value comes from the §2 gathering pass + §2f, never from these examples.** (Numbers below are illustrative placeholders, deliberately tagged — do not copy them as facts.)

### Example A — Pulse POS (whole-product, `--for portfolio`, `--role "fullstack engineer"`)

```markdown
# Pulse — a multi-tenant POS that runs offline-first on cheap Android hardware

**Built solo: a Next.js POS web app + a native Android shell, multi-tenant, live in production for an Indonesian SMB market where the hardware is cheap and the internet drops.**

## Summary
Pulse is a point-of-sale system for small Indonesian retailers. The hard part wasn't the
CRUD — it was making it reliable on low-end Android devices with flaky connectivity, across
multiple tenants, while keeping subscription + role logic correct. Shipped to production;
[needs Christopher: tenant count] businesses use it.

## Problem & context
Indonesian SMBs need POS that works when the internet doesn't, on the cheap Android tablets
they already own. Existing options charge per-user/per-outlet, which punishes growing shops.

## Constraints
- Solo build (I was the only engineer).
- Target devices: low-end Android — limited RAM, intermittent network.
- Chrome blocks PWA→localhost (LNA) for hardware (printers/scanners) — a real wall.
- Bootstrapped: one VPS, no infra budget.

## Approach
A Next.js multi-tenant web app for the POS surface, wrapped in a native Android (Capacitor +
Kotlin) shell so I could talk to Bluetooth/USB/TCP hardware that the browser sandbox forbids —
the industry-standard POS pattern, reached after PWA bridges hit Chrome's LNA wall.

## Key decisions & trade-offs
- **Capacitor + a Kotlin hardware plugin over a pure PWA.** Chrome's Local Network Access
  block made PWA→localhost hardware bridging unreliable; WebView is exempt. Traded "pure web,
  one codebase" for a native shell I now maintain — worth it because hardware access is
  non-negotiable for POS. (Rejected the HTTP-bridge PWA approach after it kept failing.)
- **Subscription gates the owner only; staff inherit via membership.** [why + the trade-off,
  pulled from project_pulse_entitlement_model] ...
- **Disabled Serwist navigationPreload to fix flaky OAuth.** navigationPreload double-fetched
  the redirecting OAuth callback → Google one-time code reused → ~50/50 login failures. [the
  real fix, from the navigationpreload-oauth memory] ...

## What shipped
- Offline order capture + sync; multi-tenant isolation; role-based access; native
  Bluetooth/USB/TCP printing + scanning; subscription/entitlement enforcement.
- Live in production.

## Outcome
- Running in production, used daily by [needs Christopher: real number] retailers.
- [If he gives latency/uptime numbers → here, tagged. Else qualitative + honest.]

## Tech stack
Next.js 16 · React 19 · TypeScript · Capacitor · Kotlin · [DB] · Docker · nginx · a VPS

## What I'd do differently
- The native shell is a second codebase to maintain — I'd evaluate whether a thinner native
  layer (hardware-only bridge) could shrink that surface.
- [A real entitlement/sync edge he'd revisit, from §2f.] ...
```

### Example B — fitest QA automation (body-of-work, `--for application`, `--role "QA / SDET"`, NDA-aware)

```markdown
# Authoring a large automated test suite for an enterprise banking admin system

**As QA on a banking project (under NDA), I authored and maintained 900+ automated UI test
rows across 27 suites for a web admin system — and helped diagnose a framework-level
Selenium failure that was silently breaking a whole class of tests.**

## Summary
On an enterprise banking engagement I owned test authoring for a complex web admin: dozens of
suites, hundreds of scenarios, with a hard requirement that a human QA team could READ and
maintain them. I also root-caused why a category of row-action/modal tests failed under the
Selenium runner but passed under Playwright.

## Problem & context
A bank's web admin needed broad, maintainable UI test coverage. The team — not just me — had
to keep the suites alive, so readability + stable locators mattered as much as coverage.

## Constraints
- Client under NDA — I'll keep system specifics abstract.
- Human-maintainable was a hard, stated requirement (not automation-optimal complexity).
- Real DBs sat behind a double-jumphost; no direct data access for seeding.

## Key decisions & trade-offs
- **Stable-locator + readable-scenario standard over clever-but-terse automation.** [the real
  authoring standard, from reference_fitest_bms_authoring_standard] — traded brevity for a
  suite a non-author can maintain. ...
- **Reframed bug reports from an FE-observable angle.** [why — the QA-scope discipline] ...

## What shipped
- 900+ test rows / 27 suites authored + maintained.
- A diagnosed, reproducible framework bug (synthetic-event `isTrusted` under chromedriver) that
  unblocked ~74 suites once the infra was fixed.

## Outcome
- [Real coverage/pass-rate numbers IF Christopher confirms; else: "suites adopted by the
  client's QA team", qualitative + honest.]

## Tech stack
[the real test framework] · Selenium / Playwright · [language] · CSV/MD scenario authoring

## What I'd do differently
- I'd push for the human-readability standard to be agreed UP FRONT — we redid suites once
  because the maintainability bar was set late. [a real lesson, from §2f.]
```

Note how both: name real constraints, give every decision a real trade-off, tag/placeholder every number that isn't yet confirmed, and end on honest reflection. That's the bar.

---

## 10. FAILURE MODES (what makes a case study bad — avoid all)

| Failure mode | Smell | Fix |
|---|---|---|
| **Fabricated metrics** | "Improved performance by 40%", "10,000 users" with no source | Source it (§6) or tag `[estimate]`/cut. The cardinal sin (rule 1). |
| **Generic filler** | "leveraged cutting-edge tech to build a robust scalable solution" | §7 grep + replace each with a project-specific detail. |
| **Feature-list-as-narrative** | A bullet dump of every feature, no story, no decisions | Lead with problem→approach→decisions; features are §4.6, not the whole thing. |
| **No trade-offs** | Every decision sounds free + obviously correct | Name the real cost of each (§4.5); add §4.9. A trade-off-free case study reads junior. |
| **Wall of text** | Recruiter can't skim; no hierarchy | Restructure to the template; front-load; chip the stack (§5). |
| **Claiming team work as solo** | "I built X" where `shortlog` shows a team | `git shortlog -sn` (§2c); attribute honestly (rule 4). |
| **Leaking secrets/PII/NDA** | Real names, client identities, keys, internal infra | §3 pass; generalize; grep for secrets. |
| **Aspirational-as-shipped** | "Supports millions of users" for a thing that's never been load-tested | §6: "shipped" needs working code; "scale" needs proof or a `[target]` tag. |
| **Humblebrag reflection** | "I'd add even more tests / make it even more robust" | §4.9 must be a REAL limitation, not a flex. |

---

## EXECUTION FLOW

1. **Parse** the invocation → subject + `--for` + `--length` + `--role` (§1). Ask if the subject is ambiguous.
2. **Gather** — run the §2 artifact pass on the real repo/source. NO narrative yet. Capture sources as you go.
3. **Ask Christopher** the §2f non-code questions (or mark gaps if he's unavailable — never invent).
4. **Privacy pass** (§3) — note what must be generalized/redacted.
5. **Draft** the case study to the §4 template, in his honest voice, every claim traceable.
6. **Audit** — §6 evidence audit (every metric sourced/tagged) + §7 filler grep + §5 skim score (≥12/16; #4/#5/#6 not zero).
7. **Land** the file in the right place + format (§8); tell Christopher where it is and what to paste where.
8. **Report** — what you analyzed (which repo/commits), the case study path, and any `[needs Christopher]` gaps he should fill.

Remember: this is a proof-of-competence artifact for Christopher's livelihood. Its credibility is its entire value — and credibility comes from being *verifiably true and specific*, not impressive-sounding. A sharp interviewer who can't poke a hole in it is the goal. Write the truest, most specific version — and let the real work speak.
