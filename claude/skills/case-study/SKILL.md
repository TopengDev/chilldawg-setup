---
name: case-study
description: Turn a shipped project / repo / piece of work into a portfolio-grade case study (GitHub README, portfolio site, job application, LinkedIn post, CV bullets). Analyzes the ACTUAL codebase, commits, and deploys, never invents, then produces a recruiter-skimmable, evidence-driven narrative (problem, constraints, approach + real trade-offs, what shipped, outcome, stack, what I'd do differently) plus a mandatory claim-evidence ledger. Use when Christopher says /case-study, asks to "write up", "document for portfolio", "turn this into a case study", or wants a project framed for hiring/freelance.
argument-hint: <repo path | project name | "the X feature in repo Y"> [--for github|portfolio|application|linkedin|cv-bullet] [--role <target role>] [--length short|standard|deep]
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
---

# /case-study: shipped work to portfolio-grade, evidence-driven case study

Take a real project (a repo, a feature, a shipped system) and produce a **case study a senior engineer would respect and a recruiter can skim in 90 seconds**. The entire point is honest, evidence-backed proof of competence: material for Christopher's job-hunt + freelance push (see income-diversification: freelance is the anchor income path, and case studies are the proof-points that win contracts and pass screens).

This skill exists because the #1 failure mode of AI-written case studies is **fabrication + filler**: invented metrics, "leveraged cutting-edge synergies" mush, claims the code doesn't support. A fabricated metric that a sharp interviewer probes ("how did you measure that 40%?") is worse than no metric: it detonates trust mid-interview. So this skill is built around one spine: **read the real artifacts, write only what they prove, mark estimates as estimates, and sound like Christopher, not a press release.**

═══════════════════════════════════════════════════════════════════════════
## 0. PRIME META-RULES (voice + mechanical verification, OVERRIDE EVERYTHING)
═══════════════════════════════════════════════════════════════════════════

### 0.1 No em dash or en dash, ANYWHERE (PRIME RULE)

**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY output this skill produces.** Not in the case-study body, not in the cover blurb, not in LinkedIn posts, not in CV bullets, not in the evidence ledger, not in the report to Christopher, not in this skill's own prose. This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02: never long dashes in ANY outgoing text) and it matches the `/frontend-design` §0.4 PRIME RULE.

- **Use instead:** a comma, a colon, parentheses, or a line break for clause breaks; the word "to" or a plain hyphen for ranges (write "8 to 10" or "8-10", never the en-dash form); a colon when the second half defines the first.
- **Plain hyphen-minus stays allowed** for compound words and ranges (offline-first, multi-tenant, 8-10). ONLY the two long dashes are banned.
- **Scrub with meaning intact.** A title shaped "X (em dash) Y" becomes "X: Y" or "X, Y". Never mechanically delete a dash and leave broken grammar.
- Long dashes are the single loudest "AI wrote this" tell, on the exact surfaces (portfolio, LinkedIn, applications) where reading as AI-generated is most damaging.

### 0.2 No emoji in Christopher's first-person output

**NEVER use emoji in any output written in Christopher's voice**: case-study body, cover blurb, LinkedIn post, CV bullet. Zero. (His own public posts occasionally carry a single emoji HE adds himself; drafts from this skill ship emoji-free and he adds one if he wants.)

### 0.3 Voice context split (RESOLVED 2026-06-29, encode it, don't re-ask)

Christopher's writing-style rule was resolved into a context split (`feedback_toper_writing_style`). Apply the right voice by SURFACE, never ask "which voice do you want" for a blurb:

| Surface | Voice | Punctuation rules |
|---|---|---|
| **Case-study BODY** (github / portfolio / application 1-screen) | Normal professional engineering prose | Periods and commas are CORRECT here. Only the §0.1 dash ban + §0.2 emoji ban apply. NEVER apply the strict symbol set to the body: it would be unreadable. |
| **Cover blurb (§4.10) + any recruiter-DM text** | STRICT outreach symbol set, ALWAYS | Only these symbols allowed: `@ & + ( ) / * " ' : ; ! ?`. NO period, comma, hyphen, dash, or bullet in prose. Line breaks separate sentences/clauses; `:` for labels/lists; `&` / `+` for joining; `!` `?` for emphasis. Exception: tech names + URLs keep their real punctuation (Next.js, topengdev.com, gRPC). |
| **LinkedIn post** | Natural voice (his real viral-post register) | Normal punctuation, minus em/en dashes, no emoji, max 3 hashtags. Story/insight-first, casual, not an ad. |
| **CV bullet** | Terse verb-first fragments | Normal punctuation minus dashes, no emoji, no first-person pronoun needed. |

Why the split exists: he rejected emoji+comma+dash outreach drafts twice (2026-05-30, @itsmasiam) before clarifying the exact symbol set, then confirmed 2026-06-29 that public posts use his natural voice while outreach stays strict.

**Do / don't pairs (verbatim guardrails):**

- BODY do: `I chose a JSON file store over SQLite for the demo layer.`
- BODY don't: `I chose a JSON-file store (em dash) sidestepping migration risk (em dash)` : the banned glyph is written here as `(em dash)` so this file stays grep-clean; any real long dash in a body fails §0.1.
- BLURB do:
  ```
  built Pulse: an offline first POS for Indonesian retailers
  live at topengdev.com
  happy to walk through the sync design
  ```
- BLURB don't: `I built Pulse, an offline-first POS. It's live in production.` (periods, a comma, and a prose hyphen inside strict-voice context; the apostrophe is fine, the rest is not.)
- LINKEDIN don't: `Excited to share...`, a rocket-emoji opener, a hashtag wall, `Agree? Thoughts?` engagement bait.

### 0.4 VERIFICATION BLOCK (exact commands, ALL must return zero before delivery)

Run every one of these against EVERY file this run produced (case study, blurb, LinkedIn post, CV bullets, evidence ledger). Any hit = NOT done; scrub with meaning intact and re-run until silent.

```bash
# V1: em/en dash (must be silent)
grep -rnP "[\x{2013}\x{2014}]" <produced-files>

# V2: emoji + variation selector (must be silent)
grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]" <produced-files>

# V3: banned filler (must be silent; the alternation is §7's ban list)
grep -rniE '\b(leverag(e|ed|ing)|synerg(y|ies|istic)|cutting.edge|state.of.the.art|best.in.class|world.class|seamless(ly)?|spearheaded|utiliz(e|ed|ing)|passionate about|game.chang(er|ing)|revolutionary|paradigm|blazing.fast|battle.tested|bleeding.edge|next.level|highly performant|enterprise.grade|robust,? scalable|significantly improved|dramatically reduced|greatly enhanced|delv(e|ed|es|ing)|tapestry|testament to|underscore(s|d)?|in today.s fast.paced|it( is|.s) worth noting|excited to share|thrilled to announce|humbled (to|by)|honou?red to announce|very|really|extremely|incredibly|a wide range of|myriad|various features)\b' <produced-files>

# V4: secret / PII patterns (must be silent; if a hit is real, report file + pattern TYPE only, never the value)
grep -rnE 'sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[A-Z0-9]|password=|token=|@s\.whatsapp\.net|(\+?62|0)8[0-9]{7,}' <produced-files>

# V5: internal paths (must be silent in PUBLIC-facing output)
grep -rn '/home/christopher' <produced-files>
```

Notes:
- V3 word boundaries are deliberate ("delivered every package" does not match "very"). If a hit is a legitimate quote of someone else's words, keep the quote, note it in the report.
- The strict-blurb symbol check is a MANUAL eyeball against the §0.3 allowed set (URLs and tech names legitimately contain periods, so a mechanical period-grep false-positives; read the blurb line by line instead).
- V5 applies to public-facing files (github, portfolio, linkedin, cv-bullet, application). The evidence LEDGER may cite local paths: it is a private artifact that never ships.
- These five checks are wired into the DELIVERY GATE and the EXECUTION FLOW. They are boolean and mechanical precisely so context pressure can't erode them.

═══════════════════════════════════════════════════════════════════════════
## NON-NEGOTIABLE RULES (READ FIRST, THESE OVERRIDE EVERYTHING BELOW)
═══════════════════════════════════════════════════════════════════════════

Violating any one of these is a failed case study, not a stylistic choice.

1. **EVIDENCE-DRIVEN ONLY, NEVER FABRICATE.** Every factual claim (a number, a stack choice, a feature, a date, an outcome) must trace to a real artifact you read: a file, a commit, a `package.json` dep, a deploy config, a README, a benchmark, or something Christopher explicitly told you. **If a metric is not real and not provided, OMIT it or mark it `[estimate]` / `[unverified]` with the basis.** No invented percentages, no made-up user counts, no "improved performance by 40%" unless 40% is measured and you can point at where. When in doubt, leave it out: an honest gap beats a fabricated win.

2. **ANTI-GENERIC, KILL THE FILLER.** Banned: "leveraged", "synergies", "cutting-edge", "robust scalable solution", "passionate about", "seamlessly", "best-in-class", "utilized", "spearheaded", "state-of-the-art", "game-changer", "revolutionary", and every other resume cliche in §7. A case study that could describe any project describes none. Force specificity: real names, real numbers, the actual hard decision, the actual constraint. If a sentence would survive being pasted into a stranger's portfolio unchanged, it's too generic: rewrite it with a detail only THIS project has.

3. **RECRUITER-SKIMMABLE STRUCTURE.** A non-technical recruiter must get the gist in ~90 seconds from headers, the one-line summary, the outcome line, and the stack chips alone, WITHOUT reading prose. A technical interviewer must be able to drill into the "Approach & key decisions" section and find real engineering substance. Both audiences, one document: skimmable top layer, deep substrate. Front-load the punch (see §4 template ordering). No wall of text.

4. **CHRISTOPHER'S HONEST VOICE, NO YESMAN, NO HYPE.** Confident but not boastful, technical but not jargon-drunk, honest about trade-offs and limits. This is the no-sugarcoat rule applied to self-promotion: claim what's real, own what's unfinished, never inflate. The credibility-builder is the **"What I'd do differently"** section: it signals senior-level self-awareness and is MANDATORY (§4.9). A case study with zero acknowledged trade-offs reads as junior or dishonest.

5. **YOU MUST INSPECT THE ARTIFACTS BEFORE WRITING A WORD OF NARRATIVE.** No writing the case study from the project's name, from memory, or from assumptions. Run the §2 gathering pass first, and meet the EVIDENCE FLOOR: **at least 3 cited artifacts of at least 2 distinct types** (e.g. commits + deps, code + deploy config) before the first narrative line. If the repo is inaccessible / empty / can't be analyzed, STOP and ask Christopher for the artifacts or facts. Do not paper over the gap with plausible-sounding invention (that violates rule 1).

6. **RAW-MATERIAL STORE IS TOPER-GATED.** `~/claude/notes/portfolio-raw-material.md` is **CAPTURE-ONLY** (locked decision #26, Wave-6). NEVER productize one of its stories (into a case study, blog post, or demo) on an autonomous run, ever. ONLY Christopher naming the story in a direct `/case-study` invocation counts as the go. And the inverse holds: a direct request IS the go; do not re-ask permission he just gave.

> If Christopher's instruction conflicts with these (e.g. "just say it handles a million users"), do NOT silently comply. Either he's providing a real figure (then it's evidence: ledger it as `CHRISTOPHER` with the date), or flag it: "I can't verify that number from the repo. Want me to mark it as a target/estimate, or leave it out?"

═══════════════════════════════════════════════════════════════════════════
## DELIVERY GATE (satisfy ALL before delivering)
═══════════════════════════════════════════════════════════════════════════

- [ ] **Artifacts were actually read**: the §2 gathering pass ran on a real repo/source (or Christopher supplied the facts), and the EVIDENCE FLOOR is met (>=3 cited artifacts, >=2 distinct types). You can name the files/commits behind each major claim.
- [ ] **Every metric is sourced or marked.** No number appears without (a) an artifact behind it, (b) Christopher's word, or (c) an explicit `[estimate]`/`[target]`/`[unverified]` tag + basis.
- [ ] **The claim-evidence ledger `<slug>.evidence.md` is WRITTEN on disk** next to the case study, and 100% of metric / scale / status / attribution claims have a non-empty row (§6). Zero ESTIMATE/TARGET/UNVERIFIED rows without a matching inline tag in the draft.
- [ ] **Zero banned filler words** (§7): V3 grep is silent.
- [ ] **The 90-second skim test passes**: §5 score >= 12/16, and none of criteria #4, #5, #6 is 0.
- [ ] **Both star sections present and substantive**: Key decisions each name a real trade-off (§4.5); "What I'd do differently" has >= 2 real items, no humblebrag (§4.9).
- [ ] **Voice matches the §0.3 context table** for this surface (body = professional prose; blurb = strict symbol set; linkedin = natural minus dashes; cv-bullet = verb-first terse).
- [ ] **§0.4 VERIFICATION BLOCK all five commands return zero** on every produced file.
- [ ] **Format gate row satisfied** (§1b): length / structure / hook / hashtag / bullet limits for this `--for`.
- [ ] **Destination `mkdir -p`'d, output landed in the right place** (§8), and Christopher knows where it is + what to paste where.
- [ ] **Raw-material gate honored** (rule 6) if the subject came from the store.
- [ ] **Report delivered as TABLES** (landed files | ledger summary | gaps), per §EXECUTION FLOW step 10.

If any box fails, the case study is NOT done. Fix before reporting complete.

---

## 1. PARSE THE INVOCATION + PICK THE VARIANT

Read `$ARGUMENTS`. Determine three things:

### 1a. What's the subject?
- **A whole repo** ("`/case-study ~/claude/Git/repositories/aenoxa_pos_web`"): whole-project case study.
- **A feature/subsystem inside a repo** ("the offline-sync in Pulse", "the fitest QA automation"): scoped case study; analyze only that slice but enough surrounding context to frame it.
- **A body of work that isn't one repo** (e.g. "my BMS fitest QA work" spread across suites): narrative case study; gather evidence from wherever it lives (notes, suites, commits, the §2g intake shelf) and frame the *contribution*, not a single codebase. Evidence recipes: `references/evidence-recipes.md`.
- **A raw-material story** (deadman watchdog, orchestration kit, secrets-parity gate): allowed ONLY when Christopher names it directly (rule 6). Story map: `references/evidence-recipes.md`.
- **Ambiguous / no path**: ask "Which repo or piece of work? Point me at a path or name it." Don't guess.

### 1b. What's it FOR? (`--for`, default: ask or infer `portfolio`) : THE FORMAT GATE TABLE

The destination changes tone, length, and format. **Delivering output that violates its format row = not done.**

| `--for` | Audience | Voice (§0.3) | Hard format gates | Lands at (§8) |
|---|---|---|---|---|
| `github` | Engineers browsing the repo | Body | Technical, terse, code-forward markdown, **<= 120 lines**. Written in-repo ONLY with Christopher's nod. | `<repo>/CASE_STUDY.md` |
| `portfolio` | Mixed (recruiter + eng) on his site | Body | Full §4 template, **600-900 words**, chip-row stack, paste-ready. | `~/claude/notes/case-studies/<slug>.md` |
| `application` | A specific hiring manager / client | Body + STRICT blurb | **<= 45 lines** (1 screen) + a **3-5 line cover blurb in the strict outreach voice** (§4.10). Tailored to `--role`. | `~/claude/notes/applications/<company-or-role>-<slug>.md` |
| `linkedin` | Feed skimmers + recruiters | Natural minus dashes, no emoji | **80-180 words**. Hook line FIRST, **<= 12 words**, must survive the ~200-char "see more" fold. **<= 3 hashtags.** Ends with exactly ONE proof link (repo or live URL). No engagement-bait closer. | `~/claude/notes/case-studies/<slug>.linkedin.md` |
| `cv-bullet` | ATS + recruiter scan | Terse verb-first | **<= 2 bullets per project, <= 28 words per bullet.** Verb-first, past tense. **At most ONE number per bullet, and only if ledger-backed.** Read the current CV first (§2g) so bullets don't duplicate or contradict it. | `~/claude/notes/case-studies/<slug>.cv-bullets.md` |

### 1c. How deep? (`--length`, default `standard`; applies to github/portfolio/application; linkedin + cv-bullet carry their own length gates)
- `short`: 1 screen. Summary + problem + 3 key decisions + outcome + stack. For a resume link or `--for application`.
- `standard`: the full template (§4), every section, tight. The default.
- `deep`: full template + an "Architecture" subsection with a real diagram (ASCII or mermaid built from the actual module/service structure) + 1-2 code excerpts of the genuinely interesting bits (pulled verbatim from the repo, not invented).

If `--role` is given (e.g. `--role "senior backend engineer (fintech)"`), bias which decisions/metrics you surface toward that role's signal (a fintech role: emphasize correctness, idempotency, data integrity, security decisions; a frontend role: emphasize UX, perf, design-system decisions). Never fabricate to fit; just *select and order* from what's real.

---

## 2. GATHERING PASS (DO THIS FIRST, this is where the evidence comes from)

**No narrative until this pass is done and the EVIDENCE FLOOR is met** (>=3 cited artifacts, >=2 distinct types). Mirror the `/handover` analyze-the-real-codebase discipline. Work the checklist; capture findings as you go (they become §6 ledger rows).

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
Extract: real project name, what it does, languages/frameworks/major libs (with versions: versions are evidence), notable infra (Docker, CI, queues, DBs), deploy target. Per-stack extended recipes (node/go/python/monorepo): `references/evidence-recipes.md`.

### 2b. Shape & scale of the work (how much, how structured)
```bash
# size signal (real LOC, file count: concrete, honest scale)
cloc . 2>/dev/null || (echo "files:"; find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' -not -path '*/dist/*' -not -path '*/vendor/*' | wc -l)
# directory structure (the architecture, for real)
find . -type d -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' -not -path '*/dist/*' | head -60
```
This grounds scale claims in reality. "A 12k-LOC Next.js app across 180 files" is evidence; "a large-scale application" is filler. (`cloc` may be missing; the `find` fallback is the honest floor.)

### 2c. The story in the commits (the real timeline + the real hard parts)
```bash
git -C <repo> log --oneline -50 2>/dev/null
git -C <repo> log --shortstat --pretty=format:'%h %ad %s' --date=short -30 2>/dev/null
git -C <repo> shortlog -sn HEAD 2>/dev/null       # contribution split (honest about solo vs team)
git -C <repo> log --oneline | wc -l               # total commits = effort signal
```
Commit messages are a goldmine for the **real** problem-to-fix arcs (a `fix:` cluster around one subsystem = a genuine hard problem you solved; that's a key-decision candidate, not invention). **`git shortlog -sn HEAD` is MANDATORY for every repo-backed case study and its output goes in the ledger**: the contribution split keeps you HONEST about what Christopher personally did vs a team (rule 1 + rule 4, never claim a teammate's commits). The `HEAD` is load-bearing: without an explicit revision, `shortlog` reads log data from stdin in non-interactive shells (exactly this runtime) and returns EMPTY with exit 0, silently no-oping the attribution firewall (verified live 2026-07-02).

### 2d. The interesting engineering (the substance interviewers probe)
Hunt for the genuinely non-trivial parts; these become §4.5 "key decisions":
```bash
# the gnarly bits: auth, payments, sync, concurrency, migrations, caching, queues
grep -rIl -iE 'webhook|idempoten|migration|race|retr(y|ies)|cache|queue|cron|oauth|encrypt|websocket|offline|reconcil' <repo>/src 2>/dev/null | head
# config/env shape (integration surface: what it talks to)
cat <repo>/.env.example <repo>/.env.sample 2>/dev/null
```
Read the actual implementation of 2-4 of these. The "approach & key decisions" section is only credible if you understood the real code.

**Cross-reference memory, index-first (HARD RULE: never guess memory filenames).** Start from `~/.claude/memory/MEMORY.md` and follow the index to the file. Christopher's memory repo has deep project context: e.g. `project_aenoxa_pos_web.md`, `reference_pulse_sw_oauth_navigationpreload.md`, `reference_pulse_entitlement_model.md`, `reference_fitest_bms_authoring_standard.md`. Use it for the *why* behind decisions, but PII stays out of the public case study (§3). (Two older citations under other names were verified dead 2026-07-02; the index is the durable lookup path, filenames drift.)

### 2e. What shipped / is it live (outcome evidence, not aspiration)
```bash
# deploy reality: is it actually running? where?
grep -rIE 'topengdev|aenoxa|vercel|fly|railway|render' <repo> --include=*.json --include=*.ts --include=*.yml 2>/dev/null | head
```
- Is it deployed? URL? (A live URL is the strongest outcome proof: verify it resolves if you can, but don't over-invest; note "live at X" only if true.)
- Tests / CI present? (Green CI is an outcome signal.)
- Real users / tenants? **Only if Christopher confirms.** Never infer user numbers from code.

### 2f. Ask Christopher for the non-code facts (the things the repo CANNOT tell you)
The repo gives you the *what* and *how*. It usually cannot give you: the **business context**, the **real outcome/metrics**, the **constraints he was under**, and **why it mattered**. Ask a tight batch (don't interrogate; 3-6 targeted questions):
- "What problem/pain did this solve, and for whom?"
- "Any real numbers I can use? (users, tenants, latency, time saved, error-rate, revenue, load handled.) If none, that's fine, I'll keep it qualitative."
- "What were the hard constraints? (deadline, solo build, no budget, legacy system, device/offline, a specific client demand.)"
- "Is it live / in production / did it ship? Where?"
- "Solo or team, and which parts were yours?" (keeps attribution honest.)
- "Anything you're NOT proud of / would redo?" (feeds §4.9 authentically.)

If he's asleep/unavailable (autonomous run), write everything the artifacts DO support, and **explicitly mark the gaps** (`[needs Christopher: real user count]`) rather than inventing; he fills them on review. Every gap also becomes a row in the report's gaps table. Never fabricate to avoid a blank.

### 2g. INTAKE SOURCES (the non-repo evidence shelf, verified real 2026-07-02)

| Source | Path | What it gives you | Hard rules |
|---|---|---|---|
| **Raw-material store** | `~/claude/notes/portfolio-raw-material.md` | 3 pre-digested engineering stories, each already in problem / insight / why-portfolio-worthy shape: W1 liveness-armed deadman + out-of-band alerting + dotfiles CI; W3 multi-agent orchestration resilience kit; W5 leak-safe secrets-parity gate + age-over-sops | **CAPTURE-ONLY, Toper-gated** (rule 6). Read freely for context; productize only on direct request. Story map + angles: `references/evidence-recipes.md` |
| **Memory index** | `~/.claude/memory/MEMORY.md` | The lookup path into ALL project context memories | Index-first, ALWAYS. Never guess a memory filename (they drift). |
| **CV directory** | `~/Dropbox/Documents/Christopher/cv/` | The current CV, for `cv-bullet` consistency + `application` framing | **NEVER hardcode a CV filename.** `ls -t` the dir and take the newest `Resume*.pdf` by mtime (as of 2026-07-02 that is `Resume-2026-updated.pdf`; the older `Resume 2026.pdf` also survives there). **NEVER source a CV from `~/Downloads`**: it holds OTHER people's CVs + hiremeup `analysis_*` outputs. |
| **Portfolio site data** | `~/claude/Git/repositories/christopher-portfolio/src/lib/data.ts` | What's ALREADY publicly claimed on topengdev.com (featured: Pulse, AURA, ExecFi; plus the more-projects list) | Read-only input. New claims must not contradict what the live site says. This is NOT an output destination (§8 trap). |
| **Task notes + initiatives** | `~/claude/notes/<task-dirs>/`, `~/claude/notes/initiatives/` (e.g. `dev-job-outreach.md`) | Body-of-work evidence: briefs, STATE.md, report.md per task | Cite the specific file per claim in the ledger. |

---

## 3. PRIVACY & SECURITY PASS (before anything public)

A public case study is an attack surface and a leak risk. Before writing:

- **No secrets, ever.** No keys, tokens, passwords, internal hostnames, IPs, JIDs, phone numbers, `secrets.env` contents, or `.env` values. The §0.4 V4 grep runs on every produced file. If a hit is real, report **file + pattern type only, never the value** (not even partially redacted).
- **No PII.** Christopher's memory repo + notes contain real names (Suryadi, Hezkiel, Ryan, Laurel, client names) and private business context. **NEVER name a real person, coworker, or client (Ryan, Laurel, Suryadi, ISI, BRI, BMS, BCAS, or any contact) in public output without Christopher's explicit ok.** Generalize: "a recruiter", "an enterprise banking client (under NDA)", "my co-founder", not real names.
- **NDA / client-confidential work** (e.g. ISI/BRI/BMS fitest, BCAS): frame the *contribution and skills* abstractly; never expose the client's internal system details, screenshots, or anything that would breach confidentiality. When unsure whether something is shareable, ask Christopher or default to the generalized version.
- **Strip internal paths**: `/home/christopher/...` and repo-internal structure that reveals nothing useful and looks unprofessional (§0.4 V5 grep).

If the case study is `--for application` to a *specific* trusted recipient and Christopher okays naming a client, that's his call; default is generalized.

---

## 4. THE OUTPUT TEMPLATE (the case study structure)

Order is deliberate: front-loaded for the 90-second skim (rule 3). Sections scale by `--length` (short drops 4.6-4.8 detail; deep adds architecture + code). `linkedin` and `cv-bullet` do NOT use this template; they compress its §4.1 + §4.7 essence under their §1b format rows.

### 4.0 Title + one-line hook
`# <Project>: <what it is> for <whom>` then a single bold line that states the result or the essence. The recruiter reads THIS first. (Title separator is a colon or comma, never a long dash: §0.1.)
> *Good:* "**A multi-tenant POS that runs offline-first on cheap Android hardware**, built solo, live in production."
> *Bad:* "A robust, scalable solution leveraging modern technologies." (filler, banned.)

### 4.1 Summary (TL;DR, 2-3 sentences, skimmable)
The whole story compressed: what, why it was hard, what shipped, outcome. If someone reads only this, they understand the project and that you can build.

### 4.2 Problem & context
What problem, for whom, why it mattered. Concrete. The pain in the user's/business's terms. 2-4 sentences. (Sourced from §2f, not invented.)

### 4.3 Constraints
The real boundaries that shaped the work; these make the engineering *impressive* by showing what you optimized against. Solo build? Hard deadline? Zero budget / one cheap VPS? Offline/low-end devices? Legacy system? Regulatory? A specific client mandate? List the real ones (§2f). Constraints are where senior judgment shows; never pad with fake ones.

### 4.4 Approach (the strategy, briefly)
The high-level shape of the solution + WHY this shape. Architecture in a sentence or two (`deep` mode: promote to a real diagram from §2b). Not a feature list: the *thinking*.

### 4.5 Key decisions & trade-offs (STAR SECTION: the technical heart interviewers drill)
3-5 real decisions, each as: **Decision, why, the trade-off you accepted, (the real alternative you rejected).** This is where engineering credibility lives. Pull these from the actual code/commits (§2c, §2d). Each must be a decision THIS project actually faced.
> *Shape:* "**Chose a JSON-file store over SQLite for the demo layer.** Sidestepped native-binding + migration risk in Alpine containers and kept the deploy dependency-free; traded real query power + concurrency safety, acceptable because the demo is single-writer seed data. (Rejected Prisma+SQLite: the migration/native-build fragility wasn't worth it for a throwaway demo.)"

Every decision must name a **real** trade-off. A decision with no downside is either trivial or you're not being honest (rule 4). Vague "chose the best tool for the job" is banned: name the tool, the reason, the cost.

### 4.6 What shipped
Concrete deliverables: the actual features/capabilities that exist and work (verified in §2). Bullet list, specific. "Offline order capture with conflict-resolution sync", not "various features". Note live URL / production status if real.

### 4.7 Outcome / results
The payoff, in evidence. **Real metrics if they exist** (§2e/2f): latency, users, tenants, load, error-rate, time saved, money. **If no hard numbers, go qualitative and honest** ("shipped to production and used daily by the team"; "passed the client's UAT first round"): a truthful qualitative outcome beats a fabricated quantitative one (rule 1). Tag any estimate (`~50 tenants [estimate]`, `target: <100ms p95 [not yet measured]`).

### 4.8 Tech stack (skimmable chips)
A clean, scannable list/table of the real stack from §2a: languages, frameworks, infra, notable libs. With versions where they signal currency (Next 16, React 19). The recruiter's eyes land here; make it a glanceable chip row, not a paragraph.

### 4.9 What I'd do differently (STAR SECTION, MANDATORY: the senior-signal)
2-4 honest reflections: what you'd change, what you under-built, a trade-off you'd revisit, a scaling cliff you see, debt you knowingly took. This is the single strongest credibility move in the whole document: it proves self-awareness and that you understand the system's limits, which is exactly what separates senior from junior. **Never skip it. Never make it fake-humble** ("I'd add even MORE tests" is a humblebrag, banned). Real: "The JSON store won't survive concurrent writers. For a real product I'd move to Postgres with proper migrations from day one." (Sourced honestly, often straight from §2f's "what aren't you proud of".)

### 4.10 (`--for application` only) Cover blurb
A 3-5 line paragraph Christopher can paste into an application / DM / cover note, **ALWAYS in the strict outreach symbol set (§0.3, no exceptions, do not ask which voice)**, that points at this case study as the proof-point. Tailored to `--role`. This is the bridge between `/case-study` and `/outreach`: the outreach message leads with a proof-point; this is that proof-point, packaged and already voice-correct.

### Voice rules (apply throughout)
- **First person, past tense, active.** "I built", "I chose", "I traded": Christopher's own work, owned plainly.
- **Confident, not boastful.** State what's real and let it stand. No "I'm passionate about", no "world-class", no exclamation-pile.
- **Specific over impressive-sounding.** A real detail (a number, a name, a constraint) beats any adjective.
- **Honest about limits.** Trade-offs and "what I'd do differently" are features, not weaknesses.
- **Per-surface punctuation is governed by §0.3.** Body = normal professional prose (periods and commas correct). Blurb = strict symbol set, always. LinkedIn = natural minus dashes. Everything = zero long dashes (§0.1), zero emoji (§0.2).

---

## 5. SKIMMABILITY SCORING (run before delivery, rule 3 enforcement)

Score the draft 0-2 on each. **Ship only at >= 12/16.** Below that, restructure.

| # | Criterion | 0 | 1 | 2 |
|---|---|---|---|---|
| 1 | 90-sec skim conveys the story (headers+summary+outcome+stack alone) | needs full read | mostly | yes |
| 2 | Punch is front-loaded (title + summary land the result) | buried | partial | nailed |
| 3 | Key-decisions section has real engineering substance | generic | some | drillable depth |
| 4 | Every metric is sourced or tagged | fabricated/bare | mostly | all clean |
| 5 | Zero banned filler words (§7) | several | 1-2 | none |
| 6 | "What I'd do differently" is real + substantive | missing/fake | thin | genuine |
| 7 | Stack is a glanceable chip row, not prose | paragraph | mixed | clean chips |
| 8 | Voice = confident + honest, no hype | hype/boast | mixed | dialed |

If any of #4, #5, #6 scores 0: automatic fail regardless of total (those are non-negotiables 1, 2, 4). Fix and re-score.

**Scoring vs boolean gates:** the mechanical checks (dash grep, emoji grep, ledger completeness, format-gate row, secret grep) are SEPARATE boolean gates in the DELIVERY GATE, deliberately NOT part of this score, so a high skim score can never average away a mechanical failure.

---

## 6. CLAIM-EVIDENCE LEDGER (mandatory artifact, rule 1 enforcement)

The §6 audit is no longer a mental pass: it produces a file. **Write `<slug>.evidence.md` next to the case study, every run.** It is the machine-checkable proof the fabrication firewall executed, and it powers later interview prep (Christopher can re-verify any claim without redoing the gathering pass). The ledger is a PRIVATE artifact: it may cite local paths and it never ships publicly.

### Schema (one row per factual claim)

```markdown
# Evidence ledger: <slug>
Generated by /case-study on <date>. Draft: <path to case study>.

| # | Claim (verbatim from draft) | Type | Evidence | Status |
|---|---|---|---|---|
| 1 | "12k-LOC Next.js app across 180 files" | scale | cloc output, run <date>: 12,204 LOC / 181 files | VERIFIED |
| 2 | "live in production at topengdev.com" | status | curl -sI https://topengdev.com (HTTP 200, <date>) | VERIFIED |
| 3 | "~50 tenants" | metric | Christopher said, 2026-07-02 | CHRISTOPHER |
| 4 | "built solo" | attribution | git shortlog -sn HEAD: 1 author | VERIFIED |
| 5 | "target: <100ms p95" | metric | not yet measured, tagged [target] in draft | TARGET |
```

- **Type:** `metric` | `stack` | `feature` | `scale` | `status` | `attribution`.
- **Evidence:** a `file:line`, a commit hash, a command + captured output summary, `Christopher said, <date>`, or a memory file name. Non-empty, always.
- **Status:** `VERIFIED` (you saw the artifact) | `CHRISTOPHER` (his word, dated; **never upgrade to VERIFIED**) | `ESTIMATE` | `TARGET` | `UNVERIFIED`.

### Ledger gates
- 100% of **metric, scale, status, and attribution** claims in the draft have a non-empty ledger row.
- Every `ESTIMATE` / `TARGET` / `UNVERIFIED` row has a matching inline tag in the draft (`[estimate]` / `[target]` / `[unverified]`). A tag in only one place = gate fail.
- `cv-bullet` mode may use a **minimal ledger**: one row per number used (so a quick CV request stays quick and never gets bypassed).
- Any claim that can't get a row: **delete it or tag it.** This pass is the firewall against the fabrication failure mode. Do it every time.

### Required backing per claim type (the audit standard)

| Claim type | Required backing |
|---|---|
| A number/metric | An artifact (benchmark, config, `wc`, commit count) OR Christopher's word OR an `[estimate]`/`[target]`/`[unverified]` tag + basis |
| A stack/lib choice | Present in `package.json`/lockfile/imports (§2a) |
| A feature "shipped" | The code for it exists + works (§2d/2e) |
| Scale ("X users/tenants") | Christopher confirmed it: NEVER inferred from code |
| "Live in production" | A real, resolving deploy (§2e) |
| A teammate-vs-solo claim | `git shortlog -sn HEAD` (§2c): never claim others' work |

---

## 7. BANNED FILLER (anti-generic, rule 2)

Run the §0.4 V3 grep on the draft and kill every hit (replace with a project-specific detail or cut):

**Resume cliches:** leveraged, leverage, synergy/synergies, cutting-edge, state-of-the-art, best-in-class, world-class, robust scalable solution, seamlessly/seamless, spearheaded, utilized/utilize, passionate about, game-changer, revolutionary, paradigm, "next-level", "blazing-fast" (unless you measured it), "highly performant" (unless measured), "enterprise-grade" (unless it literally is), "battle-tested", "bleeding edge".

**Empty intensifiers:** very, really, extremely, incredibly, super, a lot of, numerous, various (as in "various features"), "a wide range of", "myriad".

**Vague-strength claims with no evidence:** "significantly improved", "dramatically reduced", "greatly enhanced", "optimized performance": all BANNED unless paired with a real measured number.

**The tells of AI-generated prose:** "In today's fast-paced world", "It's worth noting that", "delve into", "tapestry", "testament to", "underscore", decorative dash triplets (moot anyway: §0.1 bans the glyphs outright).

**LinkedIn slop (applies to `--for linkedin`):** "Excited to share", "Thrilled to announce", "Humbled to/by", "Honored to announce", rocket-emoji or any emoji opener (§0.2 bans them all), hashtag walls (> 3), "I'm a passionate developer" framing, engagement-bait closers ("Agree?", "Thoughts?", "Who else has felt this?").

**CV-bullet slop (applies to `--for cv-bullet`):** dynamic, results-driven, detail-oriented, proven track record, team player, self-starter, go-getter, "responsible for" (use the verb for what you DID instead).

Replacement discipline: every time you delete a filler word, the fix is a **concrete detail this project actually has**, not a different adjective.

---

## 8. WHERE OUTPUTS LAND (corrected map, verified against the real environment 2026-07-02)

**ALWAYS `mkdir -p` the destination before Write** (neither notes dir exists by default):

```bash
mkdir -p ~/claude/notes/case-studies ~/claude/notes/applications
```

| `--for` | Default location | Notes |
|---|---|---|
| `github` | `<repo>/CASE_STUDY.md` (or fold into `README.md` if Christopher wants) | Lives with the code. In-repo write ONLY with Christopher's nod; commits go through `/commit`, never raw git. |
| `portfolio` | `~/claude/notes/case-studies/<slug>.md` | The case study is INPUT for a later site integration (see trap below). Also emit a short paste-blurb. |
| `application` | `~/claude/notes/applications/<company-or-role>-<slug>.md` | The 1-screen version + the §4.10 strict-voice cover blurb, tailored to that role. |
| `linkedin` | `~/claude/notes/case-studies/<slug>.linkedin.md` | Post text only, ready to paste. |
| `cv-bullet` | `~/claude/notes/case-studies/<slug>.cv-bullets.md` | Bullets + their minimal ledger rows inline. |
| (every run) | `<same dir>/<slug>.evidence.md` | The §6 ledger, next to the main output. Private, never ships. |

### THE PORTFOLIO-INTEGRATION TRAP (do not fall in)

**NEVER write case-study markdown into the christopher-portfolio repo expecting it to render.** Per `reference_portfolio_deployment` (2026-06-28) + repo inspection (2026-07-02): the site is a **hardcoded static single-page Next.js export**. Sections live in `src/components/sections/{Hero,FeaturedProjects,MoreProjects,Impact,WorkExperience,Stack,Positioning,Contact}.tsx`; project data in `src/lib/data.ts`; live at apex `topengdev.com`, nginx static from `/var/www/christopher-portfolio` behind Cloudflare; deploys via `./deploy.sh` at the repo root (tar + ssh; **rsync is NOT installed on the VPS**). There is **NO `content/` dir and NO markdown pipeline**: a dropped `.md` silently never renders, then gets reported as "landed on the portfolio", a false-done.

- DO: land the case study in `~/claude/notes/case-studies/` and OFFER a `src/lib/data.ts` diff as a separate, Christopher-gated follow-up task (`/frontend-design` owns site work; `/commit` + `./deploy.sh` ship it).
- DON'T: write into the repo, claim the site was updated, SSH to the VPS, or run `deploy.sh` from this skill.

Always:
- Confirm the repo's actual layout before writing INTO it (don't clobber an existing `README.md`: append or write `CASE_STUDY.md`, and only with Christopher's nod).
- Write the file, then **tell Christopher exactly where it is and what to paste where** ("CASE_STUDY.md in the repo root; the 3-line blurb at the bottom is ready to drop into a LinkedIn DM").
- If autonomous + the destination is ambiguous, default to `~/claude/notes/case-studies/<slug>.md` and flag it for him to relocate.

---

## 9. WORKED EXAMPLES + EXTENDED RECIPES (references/, progressive disclosure)

- `references/worked-examples.md`: two structure skeletons (Example A: Pulse, whole-product portfolio; Example B: fitest QA, body-of-work + NDA-aware application) plus ONE fully worked end-to-end trace (invocation, gathering outputs, ledger, draft, verification-block run, landed files, report table). **Skeleton numbers are deliberately placeholder-tagged illustrations; never copy them as facts.**
- `references/evidence-recipes.md`: per-stack gathering recipes (node/go/python/monorepo), body-of-work evidence hunting (notes dirs, memory index, fitest artifacts), and the raw-material story map (the 3 stories + their case-study angles, behind the rule 6 gate).

The bar both skeletons set: name real constraints, give every decision a real trade-off, tag/placeholder every number that isn't yet confirmed, end on honest reflection.

**Progressive-disclosure boundary: rules, gates, the verification block, the format table, and the gathering pass live in THIS file only.** references/ holds examples and recipes. A gate that is not in SKILL.md at invocation time effectively does not exist; never move one out.

---

## 10. FAILURE MODES (what makes a case study bad + the recovery playbook)

| Failure mode | Smell | Fix / recovery |
|---|---|---|
| **Fabricated metrics** | "Improved performance by 40%", "10,000 users" with no source | Source it (§6) or tag `[estimate]`/cut. The cardinal sin (rule 1). |
| **Generic filler** | "leveraged cutting-edge tech to build a robust scalable solution" | §0.4 V3 grep + replace each hit with a project-specific detail (§7). |
| **Feature-list-as-narrative** | A bullet dump of every feature, no story, no decisions | Lead with problem, approach, decisions; features are §4.6, not the whole thing. |
| **No trade-offs** | Every decision sounds free + obviously correct | Name the real cost of each (§4.5); add §4.9. A trade-off-free case study reads junior. |
| **Wall of text** | Recruiter can't skim; no hierarchy | Restructure to the template; front-load; chip the stack (§5). |
| **Claiming team work as solo** | "I built X" where `shortlog` shows a team | `git shortlog -sn HEAD` (§2c); attribute honestly (rule 4); ledger the split. |
| **Leaking secrets/PII/NDA** | Real names, client identities, keys, internal infra | §3 pass + §0.4 V4/V5 greps; generalize; report hits as file + pattern type only. |
| **Aspirational-as-shipped** | "Supports millions of users" for a thing never load-tested | §6: "shipped" needs working code; "scale" needs proof or a `[target]` tag. |
| **Humblebrag reflection** | "I'd add even more tests / make it even more robust" | §4.9 must be a REAL limitation, not a flex. |
| **Repo inaccessible / empty** | Path 404s, zero commits, or nothing readable | STOP (rule 5). Ask Christopher for the path or the facts. Never paper over with plausible invention. |
| **Christopher AFK on an autonomous run** | §2f questions unanswered | Draft with `[needs Christopher: X]` markers, list every gap in the report's gaps table, NEVER fill with plausible values. |
| **Body-of-work with no single repo** | Nothing to `git log` | Evidence recipe: raw-material stories (rule 6 gate), MEMORY.md index lookups, `~/claude/notes/<task-dirs>`, fitest suite counts. Each claim cites its specific source in the ledger. Recipes: `references/evidence-recipes.md`. |
| **Portfolio-integration trap** | Case-study .md written into christopher-portfolio, "site updated" reported | §8 trap box. Land in notes; offer a `src/lib/data.ts` diff as a follow-up; never claim the site changed. |
| **Christopher supplies an unverifiable number** | "just say ~50 tenants" | Ledger it as `CHRISTOPHER` with `Christopher said, <date>`. Usable evidence, but NEVER upgraded to VERIFIED. |

---

## EXECUTION FLOW

1. **Parse** the invocation: subject + `--for` + `--length` + `--role` (§1). Ask if the subject is ambiguous. Lock the §1b format-gate row for this run.
2. **Gate check** (rule 6): if the subject is a raw-material story, confirm Christopher named it in THIS direct invocation. Autonomous productizing = hard stop.
3. **Gather**: run the §2 artifact pass on the real repo/source + the §2g intake shelf. NO narrative until the evidence floor is met (>=3 artifacts, >=2 types). Capture sources as you go; they become ledger rows.
4. **Ask Christopher** the §2f non-code questions (or mark gaps if he's unavailable; never invent).
5. **Privacy pass** (§3): note what must be generalized/redacted.
6. **Draft** to the §4 template (or the linkedin/cv-bullet format row), in the §0.3 voice for this surface, every claim traceable.
7. **Ledger**: write `<slug>.evidence.md` (§6); every metric/scale/status/attribution claim gets a row; tags match.
8. **Audit + score**: §5 skim score >= 12/16 with #4/#5/#6 nonzero, then run the §0.4 VERIFICATION BLOCK (all five commands, every produced file, all silent).
9. **Land**: `mkdir -p` the destination, write the files per §8, satisfy the format-gate row. Never into the portfolio repo (§8 trap).
10. **Report as TABLES** (`feedback_visual_structured_docs`): (a) landed-files table (path | what | format row), (b) ledger summary (row counts by status + any UNVERIFIED list), (c) `[needs Christopher]` gaps table (gap | where tagged | suggested source). Prose: one line of narrative, max.

## COMPOSES WITH

- **/outreach** consumes the §4.10 cover blurb as its proof-point (already strict-voice, paste-ready).
- **/frontend-design** owns portfolio-site integration (the `src/lib/data.ts` + section-component edit + `./deploy.sh` ship): a separate Christopher-gated task that takes the case study as input.
- **/commit** for landing any in-repo `CASE_STUDY.md` (commit-skill enforced; never raw `git commit`).

Remember: this is a proof-of-competence artifact for Christopher's livelihood. Its credibility is its entire value, and credibility comes from being *verifiably true and specific*, not impressive-sounding. A sharp interviewer who can't poke a hole in it is the goal. Write the truest, most specific version, and let the real work speak.
