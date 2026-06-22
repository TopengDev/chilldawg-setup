---
name: copywriting
description: "Turns a brief into copy that survives a hard quality gate. Every sentence faces 3 rules (can I visualize it / falsify it / can nobody else say it), the 2-second test, and a per-line audit table that must PASS before anything ships. 3 modes: full (5-phase studio), quick (audit+rewrite pasted copy), panel (parallel multi-angle writers then judge). Bilingual ID+EN (transcreated, not translated), anti-slop EN+ID ban list, stateful per-brand voice bank, emits a copy spec for /artifex. Shorthand: /copy. Use when Toper says /copywriting or /copy, asks to write or sharpen a headline / hero / landing / ad / email / push / tweet / billboard / CTA, or says copy reads generic / like AI / weak / off-brand."
argument-hint: "[full|quick|panel] [what to write], e.g. /copywriting full hero headline for Pulse POS landing (ID+EN)"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, Skill, Agent
---

# /copywriting (shorthand /copy): quality-gated copy, not generated copy

> **Most copy tools generate. This one ARGUES, then refuses to ship a line that does not earn its place.** The engine is one idea, stated three ways and cut to the best, then run through a hard audit gate. The output is copy a competitor literally cannot sign.

The method is Harry Dry's (Marketing Examples), as taught in "Learn Copywriting in 76 Minutes" on David Perell's *How I Write*, fused with the copywriting canon (Ogilvy, Hopkins, Schwartz, Sugarman, Caples, Halbert, Hormozi, Wiebe). The core is a 3-question test applied to **every sentence**, wrapped in an artifex-style gate that blocks shipping until the copy passes.

`/copy` is the documented shorthand for this same skill (there is no separate alias dir; both names route here).

---

## ⛔ NON-NEGOTIABLE RULES: READ FIRST, THESE OVERRIDE EVERYTHING BELOW

These are HARD rules. Violating one is failed copy, not a stylistic choice. If anything below appears to conflict, the NON-NEGOTIABLE wins.

| # | Rule | Enforcement |
|---|---|---|
| **N1** | **Every sentence faces the 3 rules: visualize / falsify / nobody-else.** 2+ nos on a line means rewrite or cut it. | The Audit Gate (§7). The build does not ship until every line passes. |
| **N2** | **The 2-second test.** If the core message is not clear in "one Mississippi, two Mississippi," it fails. Clarity is the floor, not a bonus. | Audit Gate (§7), check `<=2sec`. |
| **N3** | **Specificity over superlatives. Point, do not talk.** Facts and numbers, never unfalsifiable adjectives. "Reads on the tube," not "intelligent." | Anti-slop scan (§8) auto-flags adjective-soup. |
| **N4** | **One idea, one reader, one action** (the Rule of One). "and" on a landing line is almost always a leak. | Audit Gate check (§7); the 5-phase pipeline forces a single idea in Phase 2. |
| **N5** | **Small and believable beats big and hollow.** "1% to 2% conversion" lands; "become a millionaire" fails. Sincerity is mandatory: you must believe the claim. | Anti-slop (§8) auto-fails unbelievable claims. |
| **N6** | **Rewrite, do not write. Produce N variants and cut, never one precious draft.** You cannot write simply, you can only rewrite simply. | Phase 4 requires 3+ variants per line before the gate. |
| **N7** | **Anti-slop. No AI-default phrasing, EN or ID.** No "seamless / world-class / elevate / unlock," no "solusi terbaik / terpercaya / berkualitas tinggi." | The Anti-Slop Hard-Ban scan (§8), instant fail on any hit. |
| **N8** | **No em-dash or en-dash, ever, in any copy or any output of this skill.** Use a comma, a colon, parentheses, or a line break. (Toper's hard style rule. A copy skill that emits the AI-default em-dash is self-refuting.) | §8 hard-ban; scan every line before shipping. |
| **N9** | **ID copy is transcreated, not translated.** The 3 rules must hold independently in Indonesian. A falsifiable, visual ID line is NOT a literal translation of the EN one. | §9 bilingual rules. |
| **N10** | **Copy and design are one.** When copy lives on a page / deck / ad, emit a copy spec (hierarchy, char counts, emphasis) and hand off to `/artifex`. Never ship copy blind to its layout. | §10 handoff. |

### The failure this skill exists to prevent

AI writes copy by prediction: "gumming together long strips of words already set in order by somebody else" (Orwell, quoted by Harry Dry as the exact description of what AI does). The result is the slop voice everyone now recognizes: *"In today's fast-paced world, our seamless, world-class platform empowers you to unlock your potential and elevate your business to the next level."* Every word is unfalsifiable, nothing is visualizable, and a thousand competitors could sign it word for word. It fails all 3 rules on every line.

> A good writer arranges words and ideas in a way that has NOT been laid out before. A robot lays them out in a way that, quite literally, HAS been laid out before. This skill exists to force the first and gate out the second. Taste, conviction, and lived specificity are the three things the slop voice cannot fake, and they are exactly what the gate checks for.

---

## 1. THE PRINCIPLE: why copy is the whole game

> **Strip the wrapper, the copy, and the branding off two products and they do roughly the same thing. The copy is the differentiator, and it is the one thing a competitor cannot copy.**

- **Snickers vs Fuse.** Snickers ("you're not you when you're hungry") is the best-selling bar in the world. The Fuse bar ("only to be eaten wearing rubber-soled shoes") was discontinued in 2006. Same product class. Opposite copy. Opposite fate.
- **Copywriting is arguing.** The conclusion is to buy your product. Your job is to build the best argument, and a small believable claim beats a big one. "I am not saying learn copywriting and become a millionaire. I am saying you can move conversions from 1% to 2%. That is believable. It is sincere."
- **It is the art of simple communication, not manipulation.** Not fishbait, not psychology-hacking. You are trying to say something true, capture attention in one image, tell a story, make it delightful.
- **Copy that cannot be copied.** Hinge: "designed to be deleted," the app you delete when you finally fall in love. No other dating app can say that. Hinge owns the phrase. That is the target for every brief: a line only this brand, in this moment, could sign.

This is the WHY. The 3 rules (§2) are the HOW.

---

## 2. THE SPINE: the 3 rules, applied to every sentence

> "Can I visualize it? Can I falsify it? Can nobody else say this? Three nos, you have probably written rubbish. Three yeses, you are onto something." (Harry Dry)

**The teaching contrast (the video's own example):**

| Line | Visualize? | Falsify? | Nobody-else? | Verdict |
|---|---|---|---|---|
| "Don't just get a job. Change an entire industry." (a real recruitment ad) | No (cannot see "change an industry") | No (not provable) | No (any company could sign it) | **3 nos: rubbish** |
| "New Balance, worn by supermodels in London and dads in Ohio." | Yes (you see the supermodel AND the barbecue dad) | Yes (it is true) | Yes (only New Balance: supermodels are not in Reebok, Ohio dads are not in Prada) | **3 yeses: onto something** |

### Rule 1: Can I visualize it? (concrete beats abstract)
"If you cannot visualize it, you will not remember it." Listeners remember "charging pitbull, muscley Irishman, leg of lamb" and forget "seamless transition, better way." Abstract means you cannot drop it on your foot.
**Technique, ZOOM IN:** write the abstract word, then keep asking "what do I actually mean?" until you hit a concrete object. *"Regain fitness" then "what is regain?" off the couch then "what is fitness?" running, how far? 5K* lands on **"Couch to 5K"**, one of the most-downloaded fitness programs ever.

### Rule 2: Can I falsify it? (true/false beats subjective)
A sentence that is true or false puts your head on the chopping block, and that makes people sit up. Galileo got house arrest for "the earth spins around the sun." "The earth has a harmonious connection with a celestial object" would have gotten him a beer down the pub.
**Technique, DON'T TALK ONLY POINT:** subjective ("good-looking, intelligent, funny") gets a shrug. Falsifiable ("6 foot 2, looks like Ryan Gosling, reads on the tube") is real. Selling gold? Do not say "great investment." Point at the 50-year gold chart, the family's secure stash, "how much gold does Warren Buffett hold?" It takes work. That is why it is better.

### Rule 3: Can nobody else say it? (differentiation)
"Never write an ad a competitor can sign" (Jim Durfey). It forces you to look deeper at what you are selling. **Volvo:** "Your car has five numbers on the speedometer. Volvo has six. One could get the impression the people who made your car lack a little confidence." Only Volvo can say it, and the visual (count the dials) aligns with the line.

### The 2-second sanity check that sits over all three
**"One Mississippi, two Mississippi."** Sometimes you know more in 2 seconds than in 2 hours. Show the line. If getting it takes longer than 2 seconds, it fails, no matter how clever it is. This is the instant-clarity gate (N2).

---

## 3. USAGE: the 3 modes

```
/copywriting quick  <paste or brief>   audit + rewrite existing copy fast. 2-3 questions max, infer the rest. 3 variants + the audit table. (~5-10 min)
/copywriting full   <brief>            the 5-phase studio (§6): interrogate reader, find the one thing, choose the frame, draft+rewrite, audit+ship. DEFAULT. (~20-40 min)
/copywriting panel  <flagship brief>   parallel writers from different lenses (§6.P) then a judge scores all against the gate and synthesizes a winner. For a hero headline / launch line / a batch. (token-heavy)
```

**Picking the mode (and skip-ahead robustness):**
- User pastes copy and says "make this better / sharper / less generic" then route to **quick** automatically, even if no mode was named. Do not make a quick ask pay the full 5-phase tax.
- A real brief for new copy with an audience and an offer then **full**.
- A flagship single line (the homepage hero, a tagline, a billboard) or a batch of 10+ items where exploration pays off then **panel**.
- No mode named and the ask is a normal new-copy request then default to **full**, but compress discovery if the brief already answers it (skip questions you already know).

**Mode is a depth dial, not three different methods.** All three share the spine (§2), the anti-slop bans (§8), and the same Audit Gate (§7). quick skips discovery; panel parallelizes the drafting. The gate is identical in all three.

---

## 4. INPUTS the skill interrogates for (graceful defaults if absent)

Ask only for what changes the copy, and never more than the mode allows (quick = 2-3 questions, full = as needed, never an interrogation). Infer the rest from the brief + the voice bank (§11).

| Input | Why it matters | Default if absent |
|---|---|---|
| **Asset + channel** (headline / hero / landing section / ad / email / push / tweet / billboard / button) | Sets length, framework, which rule dominates (§5b). | Infer from the brief; if truly unknown, assume **headline**. |
| **Audience + awareness stage** (Schwartz: unaware to most-aware) | Selects the framework and the headline strategy. | Assume **problem-aware** (the most common landing case). |
| **Market sophistication** (how many rivals made this claim before) | Decides direct-claim vs mechanism vs identification. | Assume **stage 3** (claim it via a mechanism, not a bald superlative). |
| **The offer / product** (features to ladder into meaning; the value-equation terms) | Raw material for the one idea. | Pull from the voice bank or the brief; ask if there is nothing. |
| **The one desired action** | The argument's conclusion (N4). | Infer the single most likely CTA; state the assumption. |
| **Voice-of-customer raw material** (reviews, support tickets, competitor copy) | The best copy is FOUND not written. Mine their exact words. | Skip if none, note that VoC mining was unavailable. |
| **The enemy** (a rival approach / a belief / a competitor) | Conflict is what makes copy land (§5, T8). | Infer the status-quo the product replaces. |
| **Constraints** (brand voice, banned words, length cap, **language ID / EN / both**) | Hard guardrails. | Load from the voice bank (§11). Language default per §9. |
| **Existing copy** (if rewriting/auditing) | Routes to quick mode. | If present and the ask is "improve," go straight to audit+rewrite. |

> **Robustness:** missing inputs degrade gracefully. The skill still produces audited copy from whatever is given, and **names every assumption it had to make** in the output rationale. It never stalls waiting for a perfect brief. A bare `/copy make this punchier <paste>` skips straight to quick.

---

## 5. THE CRAFT TOOLBOX (the moves you write FROM)

Every rewrite pass reaches into this toolbox. Name the technique you are applying, the way `/artifex` names a section technique. Do not improvise "make it punchy."

| # | Technique | What it does | Worked example |
|---|---|---|---|
| **C1** | **Zoom-in** | abstract to concrete by asking "what do I actually mean?" | Regain fitness becomes "Couch to 5K" |
| **C2** | **Don't talk, only point** | replace adjectives with pointable facts | "reads on the tube," the 50-year gold chart |
| **C3** | **Facts as foundation** | "If in doubt, give me a fact. Behind a fact there is a story." A fact guarantees you say something. Start there, then build. | Heinz "even when it is not Heinz, it is Heinz"; Tiger Woods "averages 11 fairways, today 7" beats "didn't want it bad enough" |
| **C4** | **Precision** | a number is precise; vague words are not (Orwell: modern writing does not pick words for meaning) | "It takes 3.1 seconds to read this ad, the same time a Model S does 0 to 60" |
| **C5** | **Metonymy / visual substitution** | swap the literal word for a visual one | iPod "1,000 songs in your pocket," not "media player" |
| **C6** | **Make them feel smart** | flatter the reader's self-image | "The sport sedan for people who inherited brains instead of wealth" |
| **C7** | **Comparison to the known** | explain the new via the familiar; pick the concrete comparison word | Cybertruck "tougher than an F-150, faster than a Porsche 911" ("tougher" beats "better") |
| **C8** | **Conflict / enemy** | hinge on a "but" without writing "but"; we judge things relatively. 3 enemy types: a rival approach, a belief, a competitor | Loom is not "an easier screen recorder," it is "async video messaging" vs "remote communication sucks" |
| **C9** | **Reframe the cost** | turn a cost into a saving; expand the timeframe to make a number land | "You will spend 22,000 hours of your career writing. Spend two learning to do it well." |
| **C10** | **Slippery slide** | each line's only job is to get the next line read (Sugarman) | "It takes 3.1 seconds to read this ad..." pulls you to "...0 to 60" |
| **C11** | **One element** | strip to the single load-bearing element; if it works with just one, you win (Neil French) | "I never read The Economist. Management trainee, aged 42." No picture, no logo |
| **C12** | **One idea** | the strength of an idea is inversely proportional to its scope; "and" on a landing line is a leak | Hiut Denim: "We make jeans." |

> **The operating loop is rewrite, not write (N6).** You cannot write simply, you can only rewrite simply. Copy-paste the same line and rewrite it 4 to 5 ways. Benefits: each pass refines, the freedom to do it wrong unlocks originality, and showing variants gets you better feedback ("use THAT sentence, put it in THAT paragraph"). The "Throw money and pray / Learn copywriting" ad took ~25 rewrites over 2 to 3 days. Bleed the ink dry.
>
> **The paragraph-burrito test:** a paragraph should be throwable, it should not come apart in the air. Pull one sentence out. A good paragraph BREAKS. If you can remove a sentence and it still works, that sentence should not have been there (Kaplan's Law: any words not working for you are working against you).

### 5b. Which rule dominates per asset
Different assets stress different rules. Lead with the dominant one.

| Asset | Length | Lead framework | Rule that dominates |
|---|---|---|---|
| **Headline** | 3 to 12 words | 4 U's / Rule of One; generate many then cut (Caples) | Rule 3 (nobody-else) + 2-second |
| **Hero** (headline + 1 line + CTA) | headline + one support line + button | 4Ps / AIDA-attention | Rule 1 (visualize) + 2-second |
| **Landing section** | one idea per section | PAS / FAB / PASTOR by section role | N4 one-idea ("and" is a leak) |
| **Ad** (social / display) | hook + one conflict + CTA | PAS, conflict-first | Rule 2 (falsify) + C8 conflict |
| **Email** | subject + one-idea body + one CTA | PAS / PASTOR; first line short (Sugarman) | C10 slippery slide |
| **Push** | under ~10 words | one falsifiable fact + one action | Rule 2 (no clickbait, must be true) |
| **Tweet / X** | one idea, fact-led | open loop used honestly | C10 slippery first line |
| **Billboard** | under ~7 words | one visual idea | 2-second test IS the gate (read at 60mph) |
| **Button / CTA** | 2 to 5 words | verb + specific outcome | Rule 1 (never "Submit" / "Learn more") |

Deeper per-asset templates (landing + headline are the deepest): `reference.md` §A.

---

## 6. THE 5-PHASE PIPELINE (full mode)

Each phase maps to a source. quick mode runs Phases 4 to 5 only. panel runs Phase 4 in parallel (§6.P).

1. **INTERROGATE THE READER (Who).** Audience + awareness stage + sophistication; mine voice-of-customer for their exact words; name the enemy. *(Schwartz, Wiebe, Halbert, Collier.)* Output: a one-line reader portrait + 3 to 5 real customer phrases + the enemy.
2. **FIND THE ONE THING (What).** The single idea or claim. Pressure-test the offer with the value equation (Dream Outcome x Perceived Likelihood) / (Time Delay x Effort & Sacrifice). Ask "what can ONLY we say?" *(Hormozi, Rule 3.)* Output: one sentence, the thing a competitor cannot sign.
3. **CHOOSE THE FRAME.** Pick the scaffold by awareness stage + asset (AIDA / PAS / PASTOR / FAB / 4Ps, §canon). Pick a headline formula. *(B1.)* Output: named framework + why.
4. **DRAFT then REWRITE (variants).** Write the copy, then 3 to 20 rewrites applying the toolbox (§5). Generate many headlines (Caples), cut to the best. *(A4/A5.)* Output: 3+ audited candidates per line.
5. **AUDIT GATE then TIGHTEN then SHIP (§7).** Fill the per-line table, cut every non-working word, read it aloud, run the burrito test. Emit the winner + runner-ups + the filled audit table + rationale. *(The hard gate; Abbott read-aloud.)*

### 6.P: panel mode (Phase 4 parallelized)
For flagship lines or batches, spawn parallel writer agents, each from a DISTINCT lens, then judge and synthesize:

- **Lens A, PAS / conflict-first** (lead with the enemy, agitate, resolve).
- **Lens B, Ogilvy big-idea** (one research-grounded big idea, headline-primacy).
- **Lens C, VoC-literal** (build the line almost entirely from mined customer phrases).
- **Lens D, Schwartz-mechanism** (name the unique mechanism, for sophisticated markets).

Each lens returns its best 2 to 3 candidates with a self-audit. A **judge pass** scores every candidate against the Audit Gate (§7) and synthesizes the winner, grafting the strongest line from each (exactly Harry's "use THAT sentence, put it in THAT one"). 

> **Robustness:** if parallel agents are unavailable in the current context, panel degrades to **sequential multi-lens drafting** in one pass (write all four lenses yourself, then judge), never a silent drop to a single draft. Log that it ran sequentially.

---

## 7. ★ THE AUDIT GATE: the hard gate (run before shipping ANY line)

**This is the centerpiece. No copy ships until this PASSES.** It is the mechanism that makes the slop voice impossible. Two layers run here: a binary **Anti-Slop Hard-Ban scan** (§8, any hit is an instant fail) and the scored **per-line table** below.

### The per-line table (fill it for EVERY line that ships)

| Line | Visualize? | Falsify? | Nobody-else? | <=2sec? | Kaplan (every word works?) | Verdict |
|---|---|---|---|---|---|---|
| (each headline / sentence / CTA on its own row) | Y/N | Y/N | Y/N | Y/N | Y/N | PASS / REWRITE / CUT |

**Scoring:**
- **2 or more nos across {visualize, falsify, nobody-else} then REWRITE or CUT the line.** No exceptions, no "but it sounds nice."
- **`<=2sec` = No then REWRITE** regardless of the other columns. Clarity is the floor (N2).
- **Kaplan = No** (a word is not pulling its weight) then cut the word and re-score.
- A line ships only when it is **PASS**: at least 2 of the 3 rules are yes, ideally all 3, AND `<=2sec` is yes AND Kaplan is yes.

### Plus three reads the table does not capture
1. **Read it aloud** (Abbott). If you stumble, the reader will. Fix the rhythm.
2. **The burrito test** (§5). Pull each sentence. The paragraph should break. If it survives, the sentence was dead weight, cut it.
3. **The sincerity check** (N5). Do you actually believe this claim? If not, the reader will not either. Shrink the claim until it is true.

### The gate
> **PASS = zero Anti-Slop Hard-Ban hits (§8), AND every shipping line is PASS in the table, AND it survives read-aloud + burrito + sincerity.** Anything else is NOT cleared to ship. Rewrite (do not "push through") and re-run. Pushing a failing line through is exactly how the slop voice gets out the door.

Emit the filled table as part of the output (§ output format). It is the proof the copy is sharp before anyone reads the body.

### Worked micro-audit (a real before/after)

```
Brief: hero line for a screen-recording tool.

DRAFT:  "The seamless way to communicate better with your team."
Audit:  visualize No (cannot see "communicate better") · falsify No (unprovable) ·
        nobody-else No (any tool could sign it) · <=2sec Yes · Kaplan No ("seamless" dead)
        → 3 nos + a dead word → CUT.

REWRITE (apply C8 conflict + C5 metonymy):
        "Meetings that should have been a video."
Audit:  visualize Yes (you see the pointless meeting) · falsify Yes (it is a real claim
        about a real swap) · nobody-else Yes (owns the async-video wedge) · <=2sec Yes ·
        Kaplan Yes (no word removable) → PASS.
VERDICT: ship the rewrite, kill the draft.
```

---

## 8. ANTI-SLOP: the hard bans (EN + ID), instant fail on any hit

> Not scored, binary. ANY hit auto-FAILS the audit regardless of the table. Scan FIRST. The full lists live in `reference.md` §C; the load-bearing tells are here.

### EN hard-bans
- **Unfalsifiable adjectives / empty intensifiers:** seamless, world-class, cutting-edge, robust, powerful, elevate, unlock, revolutionize, game-changing, next-level, best-in-class, supercharge, effortless, "delightful" (as a claim), innovative, leverage, synergy, holistic, turnkey, "solutions."
- **Hollow openers:** "In today's fast-paced world...," "Imagine a world where...," "We are excited to announce...," "It is not just X, it is Y" (unless genuinely earned), "Whether you are X or Y..."
- **Triadic AI cadence:** the rule-of-three padding ("fast, simple, and secure"). One idea (N4), not a list of three vibes.
- **Em-dash / en-dash:** banned outright (N8). Comma, colon, parentheses, or line break instead.
- **Big unbelievable claims:** "become a millionaire," "10x overnight." Fails Rule 2 + sincerity (N5).
- **Anything a competitor could sign** (Rule 3): auto-flag and rewrite.

### ID hard-bans (transcreated, because translating the EN list misses the local slop voice)
- **Empty superlatives:** "solusi terbaik," "terpercaya," "berkualitas tinggi," "harga terjangkau," "pelayanan memuaskan," "nomor satu," "terdepan," "terlengkap," "profesional dan amanah," "sudah berpengalaman bertahun-tahun."
- **Hollow openers:** "Di era digital seperti sekarang ini...," "Seperti yang kita ketahui bersama...," "Tidak bisa dipungkiri...".
- **Generic CTA mush:** "Hubungi kami sekarang juga!," "Jangan sampai ketinggalan!" with no falsifiable reason.

### The positive test (must PASS, the inverse of the bans)
A line is good when it: is **see-able** (Rule 1), is **true** (Rule 2), is **ours-only** (Rule 3), carries **one idea** (N4), rests on **a real fact** (C3), and is **sincere** (N5). North star: *a good writer arranges words in a way that has not been laid out before.*

---

## 9. BILINGUAL: ID + EN, transcreated not translated

Aenoxa / Pulse is Indonesia-first, so Aenoxa-facing copy ships **id (default) + en**. Personal / global work defaults to **en**, add id on request. Infer from context; if genuinely unclear, ask once.

**Hard rules (N9):**
- ID copy is **transcreated**. The 3 rules must hold IN INDONESIAN. A falsifiable, visual ID line is its own original, not a literal rendering of the EN one. The cultural specificity localizes: "dads in Ohio" becomes a concrete Indonesian image (a warung owner in Bandung, a kasir at 2pm rush), not a literal translation.
- **Each language is audited in its own §7 table.** An EN line that passes does not get a free pass for its ID counterpart; run the gate twice.
- Apply the **ID anti-slop list** (§8), not a translation of the EN one.
- Output **ID and EN side by side** (§ output), each with its own audit row, so Toper can see both originals.
- Keep proper nouns / product names / tech terms intact in both (Pulse, POS, Next.js).

---

## 10. OUTPUT FORMAT + the /artifex copy-spec handoff

### Output block (every run emits this)
```
## <asset> for <brand/context>

### Recommended
<the winning line(s), clearly marked>          [ID]  <line>   [EN] <line>

### Runner-ups (2 to 4)
1. <variant>   2. <variant>   ...

### Audit table
<the filled §7 table, one row per shipping line, per language>

### Rationale (1 to 2 lines)
Framework: <name> · Awareness stage: <stage> · Why this wins: <the one reason>
Assumptions made (robustness): <any input that was inferred, not given>

### → Copy spec for /artifex   (only for on-page / on-deck / on-ad assets)
<the spec below>
```

### The copy spec (loose handoff, decision: loose now, tight call-through later)
`/copywriting` owns the words, `/artifex` owns the page. They must round-trip, not run blind (N10). Emit a spec `/artifex` can build to:

```
COPY SPEC
- hierarchy:   H1 (hero) / H2 (subhead) / body / CTA / eyebrow-or-marker
- per-line:    text · char-count · max-line-length · emphasis (which word carries the weight)
- the motif:   the one repeatable phrase/word /artifex should thread across sections (N6 motif feeds artifex N6)
- tone token:  e.g. "warm-direct, fact-led, zero adjectives"
- language:    ID / EN / both (and which is primary on the page)
- do-not:      the banned words for this brand (from the voice bank §11)
```

> **Future step (documented, not built now):** the tight call-through, `/artifex` calls `/copywriting` for on-page strings (so artifex stops shipping lorem/placeholder copy), and `/copywriting` requests layout constraints back. Build it once both skills are stable. For now: clean spec, human pastes it into `/artifex`.

---

## 11. THE STATEFUL VOICE BANK (the skill learns each brand)

This skill is **stateful** (the stateful-domain-skill pattern): it owns a per-brand voice bank so it does not re-learn a brand's voice every invocation.

- **Location:** `~/.claude/skills/copywriting/voice-banks/<brand-slug>.md` (e.g. `pulse.md`, `aenoxa.md`). Template: `voice-bank-template.md`.
- **Recall-on-invoke (first action of every run):** detect the brand from the brief, then READ its voice bank if it exists and load: brand voice, banned words, the VoC phrase library, proven lines, the enemy. If none exists, run first-run: create one from what the brief gives you.
- **Update-on-exit (last action of every run):** append what was learned, new VoC phrases mined, lines that passed the gate (proven), new banned words Toper flagged, any voice correction. Writes are append-style and idempotent so a mid-run abort cannot corrupt it.
- **Treat recalled state as possibly stale:** verify a stored "fact" still holds before leaning on it, the same discipline as session memory.

**Voice bank schema** (full template in `voice-bank-template.md`):
```
---
brand: <slug>   primary-language: id|en|both   updated: <date>
---
## Voice           (3 to 5 adjectives + 1 line of "sounds like / never sounds like")
## Banned words    (brand-specific, on top of the §8 global list)
## VoC library     (real customer phrases, mined, quoted verbatim, with source)
## The enemy       (the status quo / belief / competitor this brand argues against)
## Proven lines    (copy that passed the gate + shipped, reusable as motif anchors)
## Awareness note  (where this brand's typical reader sits on Schwartz's scale)
```

---

## 12. THE CANON (condensed, a selectable toolkit)

The frameworks are interchangeable scaffolds chosen by audience-awareness. The 3 rules (§2) are the sentence-level gate that operates INSIDE whichever scaffold you pick. "Pick a framework" and "pass the 3 rules" are two distinct phases (3 and 5). Deep dives + the per-great "exact idea to borrow" live in `reference.md` §B.

### Frameworks (the skeletons, pick by awareness stage + asset)
| Framework | Shape | Best for |
|---|---|---|
| **AIDA** | Attention, Interest, Desire, Action | universal default, ads, landings |
| **PAS** | Problem, Agitate, Solution | short pain-driven copy, cold audiences |
| **PASTOR** | Problem, Amplify, Story, Transformation, Offer, Response | long-form sales pages, warm nurture |
| **FAB** | Features, Advantages, Benefits | feature-aware buyers |
| **4Ps** | Promise, Picture, Proof, Push | warm audiences, emotional arcs |
| **4 U's** | Useful, Urgent, Unique, Ultra-specific | headline QA (this IS the 3 rules in headline form) |

### The greats (the one idea to borrow from each)
- **Ogilvy:** the headline is most of the dollar (he put it at 80 cents); the Big Idea; research first. The Rolls-Royce "at 60mph the loudest noise is the electric clock" is the taste exemplar.
- **Hopkins** (*Scientific Advertising*, 1923): specifics over superlatives. "Platitudes and generalities roll off the human understanding like water from a duck." Actual figures are not discounted. This IS "point, don't talk," a century early.
- **Schwartz** (*Breakthrough Advertising*, 1966): copy CHANNELS existing desire, it cannot create it. The **5 Stages of Awareness** (unaware to most-aware) select your headline strategy. The **5 Stages of Market Sophistication** decide direct-claim vs mechanism vs identification. This is "who are you talking to" made rigorous, the single most valuable canon-add.
- **Sugarman:** the **slippery slide**, each element's only job is to get the next one read; first sentence short; sell on emotion, justify with logic.
- **Halbert:** the **starving crowd**, market demand beats product and copy. "Who is hungry for this?" precedes writing.
- **Caples:** headlines win on self-interest / news / curiosity. "They Laughed When I Sat Down at the Piano..." (US School of Music, c.1925). Write dozens of headlines, then test.
- **Abbott:** storytelling + integrity; words are servants of the argument; read it aloud; a cliche trash-bin.
- **Wiebe / Copyhackers (modern VoC):** the best copy is FOUND not written. Mine reviews, tickets, sales calls for the customer's exact words. The "so what / says who" tests.
- **Hormozi (modern offer):** the **Value Equation** = (Dream Outcome x Perceived Likelihood) / (Time Delay x Effort & Sacrifice). Pressure-test the offer before writing.
- **Curiosity gap** (Loewenstein, 1994): a perceived information gap creates a need to fill. Use the open loop HONESTLY, guarded by Rule 2 falsifiability + sincerity, never clickbait.

---

## 13. ROBUSTNESS (degrade gracefully, never stall)

- **Missing inputs:** produce audited copy from whatever is given; name every assumption in the rationale; never block on a perfect brief (§4).
- **No voice bank yet:** first-run path, create one from the brief (§11).
- **No VoC material:** proceed on the brief + canon; note VoC mining was unavailable (the copy is weaker without it, say so).
- **panel without parallel agents:** degrade to sequential multi-lens, never a silent single draft (§6.P).
- **quick on a vague paste:** audit + 3 rewrites is always possible; ask at most 1 clarifying question.
- **Language ambiguous:** default per §9 and state it, or ask once.
- **The gate still runs in every degraded path.** Robustness reduces inputs, never the §7 gate. A fast or under-briefed run still ships only PASS lines.

---

## 14. EXECUTION FLOW

1. **Detect mode + brand.** Parse `full|quick|panel` (default full; auto-quick on a paste-and-improve). Read the brand voice bank (§11 recall-on-invoke).
2. **Frame.** Confirm asset + channel, audience + awareness stage, the one desired action, language (§4, §9). Ask only what changes the copy, within the mode's question budget.
3. **(full) Phases 1 to 3.** Interrogate the reader, find the one thing, choose the frame (§6). Mine VoC if available.
4. **Draft then rewrite (Phase 4 / §6.P for panel).** 3+ variants per line, applying named toolbox moves (§5). Generate many headlines, cut.
5. **★ Run the Audit Gate (§7).** Anti-slop scan first (§8), then the per-line table, then read-aloud + burrito + sincerity. REWRITE failures, do not push through. Run it once per language (§9).
6. **Emit the output block (§10).** Winner + runner-ups + the filled audit table(s) + rationale + assumptions. Add the copy spec for on-page assets.
7. **Update the voice bank (§11 update-on-exit).** Append new VoC, proven lines, voice corrections.
8. **Hand off (N10).** For on-page / on-deck / on-ad copy, point Toper to `/artifex` with the copy spec.

> Do not hold back on the rewrites, the depth is in pass 15, not pass 1. But the discipline is that the quality is GATED, not asserted. Copy that passes the audit beats copy you only claim is good.

---

## 15. COMPOSES WITH

| Skill | How /copywriting plugs in |
|---|---|
| **/artifex** | The design counterpart. `/copywriting` emits the **copy spec** (§10); `/artifex` builds the page to it (and stops shipping lorem). Loose handoff now, tight call-through later. The copy's motif (N6) feeds artifex's motif rule (its N6). |
| **/frontend-design** | Same handoff as artifex for SAFE/production pages. The copy spec drops into the page's content slots. |
| **/pitch-deck** | Deck narrative lines (hook, problem, CTA) run through this gate before the deck is built, so no slop line survives to the slide. |
| **/oneshot-webapp** | The webapp's hero + section copy is written here first (gated, bilingual where Aenoxa), then the spec feeds the build. |
| **/content-strategy** | Strategy decides WHAT to write; `/copywriting` writes the individual piece and gates it. |
| **/outreach** | Outreach drafts the message; for a high-stakes line, run it through the gate. (Respects outreach's draft-for-approval, never auto-sends.) |

---

## 16. ATTRIBUTION + SOURCES

- **Primary method:** "Learn Copywriting in 76 Minutes, Harry Dry," *How I Write* with David Perell (guest Harry Dry of Marketing Examples). https://www.youtube.com/watch?v=TUMjnmfsPeM . The 3 rules, the toolbox, the rewrite loop, and the anti-AI argument are his (transcribed, high-confidence).
- **Canon:** Ogilvy (*Confessions of an Advertising Man*, *Ogilvy on Advertising*); Hopkins (*Scientific Advertising*, 1923); Schwartz (*Breakthrough Advertising*, 1966); Sugarman (*The Adweek Copywriting Handbook*); Caples (*Tested Advertising Methods*); Halbert (*The Boron Letters*); Collier; Abbott (AMV); Sullivan (*Hey Whipple, Squeeze This*); Hormozi (*$100M Offers*); Wiebe / Copyhackers (VoC); Loewenstein (information-gap, 1994). Publication years for Hopkins 1923, Schwartz 1966, and the Hormozi formula were web-verified at authoring; other dates/wordings are attributed to their originators rather than asserted as exact.
- **House pattern:** modeled on `~/.claude/skills/artifex/SKILL.md` (the non-negotiable spine + hard audit gate + numbered technique library) and `~/.claude/skills/qa/SKILL.md` (the quick/full mode split).
- **Honors:** the no-em-dash style rule (N8), the skill-authoring-robustness bar, the stateful-domain-skill pattern, and the Aenoxa i18n default.

> Deeper material (full canon dives, per-asset deep templates, the complete anti-slop word lists, the headline-formula library) is in `reference.md`. The voice-bank format is in `voice-bank-template.md`.
