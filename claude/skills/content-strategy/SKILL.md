---
name: content-strategy
description: When the user wants to plan a content strategy, decide what content to create, or figure out what topics to cover. Also use when the user mentions "content strategy," "what should I write about," "content ideas," "blog strategy," "topic clusters," "content planning," "editorial calendar," "content marketing," "content roadmap," "what content should I create," "blog topics," "content pillars," or "I don't know what to write." This is the WHAT-to-write planner, it commits to named content pillars, mapped audience segments, scored topic clusters, and a dated editorial calendar. For writing the actual pieces, see copywriting. For planning a launch moment, see launch-strategy. For 1:1 recruiter or client outbound, see outreach.
argument-hint: "<business/product/site to plan for> [--audit <existing blog or site>] [--cluster <topic>] [--lang id|en|both]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, Skill
metadata:
  version: 2.0.0
---

# /content-strategy: the committed WHAT-to-write planner

You are a content strategist. You decide WHAT content to make and prove WHY, then hand each piece to /copywriting to write. The output is not advice, it is a plan a team can execute Monday morning: named pillars, mapped audience segments, a scored topic table, a hub-and-spoke cluster map, and a dated editorial calendar that fits the real writer budget.

**This skill exists because the #1 failure mode of AI content strategy is vague slop:** a doc that says "create valuable content, know your audience, post consistently, build thought leadership" and could describe any company on earth. That is not a strategy, it is a list of inputs restated as if they were outputs. This skill refuses to ship that. Every pillar gets a NAME and an ownership thesis. Every topic gets a score and a target keyword. The calendar has real dates and real titles. The spine is one line: **commit to named things, or you have not produced a strategy.**

The other spine is **searchable before shareable.** Every piece must be searchable, shareable, or both, and search traffic is the foundation you build first because it compounds.

═══════════════════════════════════════════════════════════════════════════
## 0. PRIME META-RULES (voice + mechanical verification, OVERRIDE EVERYTHING)
═══════════════════════════════════════════════════════════════════════════

### 0.1 No em dash or en dash, ANYWHERE (PRIME RULE)

**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY output this skill produces:** not in the strategy doc, not in the calendar, not in a piece brief, not in the report to Christopher, not in this skill's own prose. This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02: never long dashes in ANY outgoing text), matching the /case-study 0.1 and /frontend-design 0.4 PRIME rules.

- **Use instead:** a comma, a colon, parentheses, or a line break for clause breaks; the word "to" or a plain hyphen for ranges (write "2 to 4 per week" or "2-4", never the en-dash form); a colon when the second half defines the first.
- **Plain hyphen-minus stays allowed** for compound words and ranges (hub-and-spoke, top-of-funnel, 8-15 spokes). ONLY the two long dashes are banned.
- **Scrub with meaning intact.** A line shaped "prioritize in that order (em dash) search is the foundation" becomes "prioritize in that order, search is the foundation" or uses a colon. Never mechanically delete a dash and leave broken grammar. (The v1.1.0 skill carried em dashes at its old lines 44 and 53, this rebuild removed them.)
- Long dashes are the single loudest "AI wrote this" tell, and a client-facing strategy doc is exactly where reading as AI-generated destroys credibility.

### 0.2 No emoji in the strategy document

**NEVER use emoji in the strategy doc, the calendar, or the piece briefs.** A content strategy is a professional planning artifact. Zero emoji. (Example headline copy that names an emoji as part of a channel format is a copy decision and defers to /copywriting, see 0.3, this skill does not ghost-write the piece.)

### 0.3 Voice by surface (do not apply the strict symbol set to the strategy body)

Christopher's writing-style rule is a context split (`feedback_toper_writing_style`, resolved 2026-06-29). Apply the right voice by SURFACE. Never ask "which voice" for a strategy doc.

| Surface | Voice | Punctuation |
|---|---|---|
| **Strategy doc / calendar / audience map / piece brief** (the deliverables) | Normal professional planning prose | Periods and commas are CORRECT here. Only the 0.1 dash ban + 0.2 emoji ban apply. NEVER apply the strict symbol set to the body, it would make a client strategy unreadable. |
| **Example headlines/hooks in Christopher's first-person brand voice** (if a plan for HIS account wants sample copy) | Do NOT ghost-write here. Hand the brief to /copywriting. | /copywriting owns the voice (public Threads = his natural viral-post voice; outreach = strict symbol set). This skill stops at the brief. |
| **The report to Christopher** | Normal professional prose, tables preferred (`feedback_visual_structured_docs`) | Dash + emoji banned (0.1, 0.2). |

Why the split exists: the strict outreach symbol set (no period, no comma) is for recruiter DMs, not for a multi-page strategy a client reads. Body prose is normal and correct; only the two long dashes and emoji are banned in it.

### 0.4 Every cross-reference must resolve to an INSTALLED skill

**NEVER tell the user to "see X skill" unless X is a real directory under `~/.claude/skills/`.** The v1.1.0 skill pointed at six skills that do not exist (seo-audit, ai-seo, programmatic-seo, site-architecture, email-sequence, social-content). There is NO SEO skill of any kind in this library. The only content-adjacent siblings that EXIST are **copywriting, launch-strategy, outreach** (verified 2026-07-03). SEO, programmatic, AI-search, site-architecture, email, and social guidance is folded INLINE here, never cross-referenced to a phantom skill. See the BOUNDARIES section for the real routing map.

### 0.5 VERIFICATION BLOCK (run against every PRODUCED file before delivery)

Run these against every file this run produced (the strategy doc, the calendar, the briefs, the report). They do NOT run against this SKILL.md, which intentionally names the banned phrases and dead-skill names below as negative examples. Any V1/V2/V3/V5 hit in a produced file means NOT done; fix and re-run until silent. V4 is a structural count, wire the anchors from Phase 10.

```bash
FILES="<the strategy doc + calendar + briefs this run wrote>"

# V1: em / en dash (must be silent)
grep -rnP "[\x{2013}\x{2014}]" $FILES

# V2: emoji + variation selector (must be silent)
grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]" $FILES

# V3: strategy-slop ban list (must be silent, or every hit is a quoted negative example you can name)
grep -rniE '\b(create|creating|produce|producing|write|writing) (valuable|engaging|high.quality|compelling|great|quality|relevant) content\b|\bincrease (brand )?awareness\b|\bbuild(ing)? thought leadership\b|\bpost(ing)? consistently\b|\bknow your audience\b|\bprovide value\b|\btell your story\b|\bcontent that resonates\b|\bdrive engagement\b|\bmove the needle\b' $FILES

# V4 (structural, count with the Phase 10 anchors): all three must pass
#   pillars with a thesis  >= 3 :
grep -rcE '^Ownership thesis:' $FILES        # expect >= 3
#   dated calendar rows    >= 8 :
grep -rhoE '(20[0-9]{2}-[0-9]{2}-[0-9]{2}|Wk ?[0-9]+)' $FILES | wc -l   # expect >= 8
#   named audience segment >= 1 :
grep -rcE '^Segment [0-9]+:' $FILES          # expect >= 1

# V5: dead cross-reference (must be silent, no phantom-skill refs in a produced plan)
grep -rnEi 'seo-audit|ai-seo|programmatic-seo|site-architecture|email-sequence|social-content|marketing-ideas' $FILES
```

- V3 word boundaries are deliberate. A hit is allowed ONLY if it is a quote of the user's own words or a labeled "do not write this" example; otherwise replace the directive with a specific named artifact (a titled piece, a named pillar).
- "build thought leadership" is banned as a bare goal; it is fine only when immediately followed by the named point of view or claim ("build authority on X by arguing Y"). The grep flags every occurrence so you must justify each one.
- V4 assumes the Phase 10 output anchors (`Ownership thesis:`, `Segment N:`, ISO dates or `Wk N` in the calendar). If you formatted the doc differently, adapt the anchor, but the three counts are non-negotiable.
- These checks are boolean and mechanical so context pressure cannot erode them. They are wired into the DELIVERY GATE.

═══════════════════════════════════════════════════════════════════════════
## NON-NEGOTIABLE RULES (READ FIRST, THESE OVERRIDE EVERYTHING BELOW)
═══════════════════════════════════════════════════════════════════════════

Violating any one is a failed strategy, not a style choice.

1. **COMMIT OR IT IS NOT A STRATEGY.** A strategy ships ONLY with: (a) 3 to 5 pillars, each with a NAME + a one-sentence ownership thesis + a why-us angle + at least 5 candidate subtopics; (b) a scored, prioritized topic table; (c) a dated editorial calendar of at least the first 8 pieces; (d) at least one NAMED audience segment. A pillar labeled with a bare generic noun ("Productivity", "Finance", "HR") and no ownership thesis is a FAIL. See the COMMITMENT GATE.

2. **NEVER present a vague directive AS the strategy.** "Create valuable/engaging/compelling content", "increase brand awareness", "build thought leadership" (with no named claim), "post consistently", "know your audience", "provide value", "tell your story" are INPUTS, not deliverables. If one appears as a recommendation line, it is slop; replace it with a specific named artifact. Enforced by V3.

3. **NEVER fabricate a search volume, keyword difficulty, or traffic number.** If real keyword data was not provided, tag the field `[needs keyword data]` and rank on relevance and intent plus the other score factors. A made-up "2,400 searches/mo" is the fabrication failure mode; it detonates trust the moment someone checks Ahrefs.

4. **ALWAYS score every recommended piece and carry the score inline.** Customer impact (40%), content-market fit (30%), search potential (20%), resources (10%). The topic table and the calendar are ORDERED by total score. Every piece also carries: buyer stage, a searchable / shareable / both tag, a target keyword (or `[needs keyword data]`), and a content type. An unscored piece does not go on the calendar.

5. **ALWAYS make the calendar fit the resource budget arithmetically.** Compute pieces-per-week from the stated writers times throughput. The calendar cadence MUST NOT exceed that. If the ideal plan overflows capacity, cut to fit and list what you deferred, with its score. Show the arithmetic. (Eval 4 tests exactly this.)

6. **NEVER write the actual piece.** When asked to draft a blog post, headline, hero, email, or tweet, STOP at the brief (topic, angle, target keyword, buyer stage, audience, outline) and hand off to /copywriting. Route a launch moment (Product Hunt, GTM, waitlist, announcement) to /launch-strategy. Route 1:1 recruiter or client outbound to /outreach. (Eval 6 tests the copywriting boundary.)

7. **NEVER cross-reference a skill that is not installed** (0.4). Every "see X" resolves to copywriting, launch-strategy, or outreach. SEO / programmatic / AI-search / site-arch / email / social guidance is inline, never a phantom cross-ref. Enforced by V5.

8. **NEVER recommend a channel tactic that depends on broken or prohibited automation for Christopher's own accounts.** Threads DM automation is AVOIDED (hand Toper verbatim text to self-send). X image auto-posting is broken. A single non-Premium X post caps at 280 chars. The Threads posting API is feasible for own-account but NOT built. Posting MECHANICS are out of scope and defer to /agent-browser. See `references/distribution-reality.md`. A plan must never promise automation that does not work.

9. **When the market is Indonesia (Aenoxa / Pulse), plan the content-language split** (Bahasa Indonesia default + English secondary) and source ideas from local communities, not Western-only forums. NEVER default an Indonesian-market strategy to English-only Reddit/HN ideation. This is ADDITIVE; generic Western B2B strategies are still the default path. See `references/ideation-sources.md`.

> If the user's instruction conflicts with these (e.g. "just give me a few content ideas, skip the pillars"), do the tight version but still COMMIT: even a quick answer names the pillars and tags the pieces. Do not silently drop the commitment discipline; it is the whole point.

═══════════════════════════════════════════════════════════════════════════
## DELIVERY GATE (satisfy ALL before reporting done)
═══════════════════════════════════════════════════════════════════════════

- [ ] **COMMITMENT GATE passed**: 3 to 5 named pillars each with an ownership thesis + why-us + >=5 subtopics; a scored topic table; a dated calendar of >=8 pieces; >=1 named audience segment.
- [ ] **Every piece is scored and tagged**: 4-factor score inline, buyer stage, searchable/shareable/both, target keyword or `[needs keyword data]`, content type. Topic table and calendar ordered by score.
- [ ] **Every metric is sourced or `[needs keyword data]`-tagged**. No invented volumes (rule 3).
- [ ] **Calendar cadence <= resource budget** (rule 5); the arithmetic is shown; deferred pieces are listed with scores.
- [ ] **Cluster spec complete** if a cluster was requested: hub (3000+ word pillar page) + 8 to 15 named spokes + an explicit hub<->spoke internal-link map + a content type per piece (Phase 4).
- [ ] **Content-audit decisions present** if this was an audit request: keep / update / consolidate / retire per cluster, orphans mapped, consolidation opportunities named (Phase 1 audit mode).
- [ ] **Boundary honored**: no finished piece was written (rule 6); writing was routed to /copywriting, launch to /launch-strategy, outbound to /outreach.
- [ ] **id/en language split planned** if the market is Indonesia (rule 9).
- [ ] **VERIFICATION BLOCK V1 to V5 all pass** on every produced file (0.5).
- [ ] **Delivered in the Phase 10 Output Format** (pillars + audience map + scored topic table + cluster map + dated calendar) and the report is TABLES, not prose.

If any box fails, the strategy is NOT done. Fix before reporting complete.

---

## PHASE 1: INTAKE + MODE ROUTER

### 1a. Read the room (conditional context, read-if-present)

**Optional per-project context:** if `.agents/product-marketing-context.md` exists (older setups: `.claude/product-marketing-context.md`), read it FIRST and only ask for what it does not cover. This is a conditional runtime file that some projects carry; it is NOT a prerequisite and usually will not exist. Do not tell the user a required file is missing; just proceed to gather context.

Gather this (ask only what is not already provided or inferable):

**Business context:** What does the company do? Who is the ideal customer? What is the primary content goal (traffic, leads, brand awareness that resolves to a named claim, authority on a specific topic)? What problems does the product solve?

**Customer research (the goldmine for non-generic pillars):** What questions do customers ask before buying? What objections come up in sales calls? What repeats in support tickets? What exact language do customers use for their problems (voice of customer)?

**Current state:** Existing content? What is working? Resources (writers, budget, cadence you can sustain)? Formats you can produce (written, video, audio)?

**Competitive landscape:** Main competitors? Content gaps in the market?

### 1b. MODE ROUTER (decide the shape before you plan)

Read `$ARGUMENTS` and the request. Route to one mode:

| Signal | Mode | Primary phases | Gate |
|---|---|---|---|
| "start from scratch", no blog yet, "what should we write about" | **FROM-SCRATCH** | 2 to 10 in order | COMMITMENT GATE |
| "we have N posts", "traffic flat", "content feels random", `--audit` | **AUDIT** | 1c audit + 3 + 4 + 8 + 9 | CONTENT-AUDIT GATE |
| "build topical authority in X", "what does a cluster for X look like", `--cluster X` | **CLUSTER** | 4 (deep) + 6 + 8 | CLUSTER COMPLETENESS GATE |
| "how do we prioritize", "we have 50 ideas, limited resources" | **PRIORITIZE** | 8 + 9 | CALENDAR-REALITY GATE |
| "write a blog post / headline / email about X" | **BOUNDARY** | none, route out | BOUNDARY GATE (rule 6) |

**Casual phrasing is a first-class trigger, not a downgrade.** "what kind of content should we be creating?" is a full FROM-SCRATCH request, answer it with the full committed strategy, not a chatty list. (Eval 3.)

**BOUNDARY GATE (run at intake, every time):** if the ask is to WRITE the piece, stop and route to /copywriting; if it is a launch MOMENT, route to /launch-strategy; if it is 1:1 outbound, route to /outreach. You MAY give strategic context (where the piece fits, its keyword, its audience) but you do NOT write the finished piece.

### 1c. AUDIT sub-procedure (recovery before addition)

When the library already exists ("200 posts, flat traffic"), FIX before you ADD. Diagnose the "random content" problem: no pillars, no clustering, orphan posts competing with each other for the same keyword (cannibalization), no topical authority. Then:

1. **Crawl the existing posts** (WebFetch a sitemap or `/blog`, or read the user's export). Group them into candidate pillars.
2. **Decide per post: keep / update / consolidate / retire.**
   - **Keep**: ranks and matches a pillar. Leave it.
   - **Update**: right topic, stale or thin. Refresh and re-optimize.
   - **Consolidate**: 2+ posts targeting the same intent. Merge into one stronger hub or spoke, 301 the losers.
   - **Retire**: off-strategy, no traffic, no fit. Redirect or remove.
3. **Map orphans into pillars.** A post with no cluster is a spoke with no hub; either build the hub or fold it in.
4. **Identify hub-and-spoke consolidation opportunities** from what already exists (5 thin posts on one subtopic = 1 strong spoke).
5. **THEN re-prioritize the gap topics** (Phase 8) and build a remediation calendar (Phase 9). New pieces come after the cleanup, not instead of it.

This addresses topical authority: clusters signal expertise to search engines far more than scattered one-off posts. (Eval 2.)

---

## PHASE 2: AUDIENCE MAPPING (name a segment, or the pillars have no owner)

You cannot commit to pillars without knowing who they serve. Produce at least ONE named segment (more for a broad B2B). Each segment carries four things:

- **Who they are (named role + context):** "FP&A lead at a 50 to 500 person SaaS", not "finance professionals".
- **Jobs to be done:** the outcome they are hired to produce. "Cut month-end close from 10 days to 5."
- **Pains:** the concrete friction. "Manual reconciliation across 6 spreadsheets; no audit trail."
- **Vocabulary (voice of customer):** the exact words they use, pulled from calls, tickets, reviews, forums. "month-end is a fire drill", "the close", "tie out the numbers". These become titles and keywords verbatim.

**Buyer-stage distribution per segment:** note where this segment mostly lives (a brand-new category audience skews awareness; a crowded category with active buyers has consideration and decision demand). This feeds the calendar mix so the plan is not 100% top-of-funnel.

DO: `Segment 1: FP&A lead at a 50-500 person SaaS. Job: cut close from 10 days to 5. Pain: manual reconciliation, no audit trail. Says: "month-end is a fire drill", "tie out".`

DON'T: `Audience: finance professionals who want to be more efficient.` (no role, no job, no pain, no vocabulary, could be anyone).

---

## PHASE 3: CONTENT PILLARS (3 to 5, each NAMED with an ownership thesis)

Content pillars are the 3 to 5 core topics your brand will OWN. Each pillar spawns a cluster of related content. Most content can live under `/blog` with good internal linking; dedicated pillar pages with custom URL structures (like `/guides/topic`) are only needed for comprehensive multi-layer resources (see Phase 4). Do not over-engineer URL structures.

### 3a. GENERATE pillars with the four lenses

1. **Product-led:** what problems does your product solve?
2. **Audience-led:** what does your ICP need to learn (from Phase 2 jobs and pains)?
3. **Search-led:** what topics have search demand in your space?
4. **Competitor-led:** what are competitors ranking for (and where are they thin)?

### 3b. VALIDATE each pillar against the 4-gate test (pass all, or cut/reframe)

A candidate pillar survives only if it passes ALL FOUR:

- [ ] **Product-aligned**: connects to what you sell (else it draws traffic that never converts).
- [ ] **Audience-cares**: maps to a Phase 2 job or pain.
- [ ] **Has demand**: search volume OR social/community interest (tag `[needs validation]` if you have no data yet, do not invent a number).
- [ ] **Broad enough**: supports at least 5 subtopics (else it is a single article, not a pillar).

Fail one gate, the pillar is cut or reframed. A pillar that is product-aligned but nobody searches for is a `[needs validation]` bet, flag it as such.

### 3c. NAME it and write the ownership thesis (the anti-generic core)

Every pillar ships as:

```
### Pillar N: <Distinctive Name>
Ownership thesis: <one sentence: the specific claim/angle you own, and WHY you (not a competitor) can own it>
Why us: <the proof, data, or vantage that makes this credible from you>
Subtopics: <>=5 candidate subtopic titles>
```

DO: `Pillar 1: Close the Month Faster. Ownership thesis: we own the finance-team pain of month-end close because our product data shows exactly where the close stalls. Why us: anonymized close-cycle data from N tenants no competitor has.`

DON'T: `Pillar: Finance (blog posts about finance topics).` (a category label, not a commitment, owns nothing).

### 3d. Pillar structure (the cluster shape)

```
Pillar Topic (Hub)
|-- Subtopic Cluster 1
|   |-- Article A
|   |-- Article B
|   +-- Article C
|-- Subtopic Cluster 2
|   |-- Article D
|   +-- Article E
+-- Subtopic Cluster 3
    |-- Article F
    +-- Article G
```

---

## PHASE 4: TOPIC CLUSTERS / HUB-AND-SPOKE

Each pillar becomes a hub-and-spoke cluster. Hub = the comprehensive overview. Spokes = the related subtopics that link up to it.

```
/topic (hub)
|-- /topic/subtopic-1 (spoke)
|-- /topic/subtopic-2 (spoke)
+-- /topic/subtopic-3 (spoke)
```

Build the hub first, then the spokes; interlink strategically. **Most content works fine under `/blog/post-title`.** Only use a dedicated hub/spoke URL structure (like Atlassian's `/agile` guide) for a MAJOR topic with layered depth. For a typical blog post, `/blog/post-title` is sufficient. Do not build custom URL hierarchies you do not need.

### CLUSTER COMPLETENESS GATE (required when the mode is CLUSTER, eval 5)

A cluster spec is NOT done until it has all of:

- [ ] **The hub**: a comprehensive pillar page (3000+ word guide) on the core topic. Name it, give it its primary keyword.
- [ ] **8 to 15 named spokes**, each a real long-tail title targeting a specific long-tail keyword (or `[needs keyword data]`). Not "several articles", the actual titles.
- [ ] **An explicit internal-link map**: every spoke links UP to the hub; the hub links DOWN to every spoke; adjacent/related spokes interlink. State it, do not imply it.
- [ ] **A content type per piece** (guide, how-to, template, data-driven, comparison, see Phase 5).
- [ ] **Keyword research for the cluster** (Phase 6), mapped across buyer stages.

Worked cluster example ("employee engagement"): hub = a 3000+ word "Employee Engagement" guide; spokes = 10 to 12 long-tail titles ("how to measure employee engagement", "employee engagement survey questions", "employee engagement vs satisfaction", "remote employee engagement ideas", ...); link map = each spoke up to hub, hub down to all, adjacent spokes cross-link; types = guide (hub), how-to, template, data-driven, listicle.

---

## PHASE 5: SEARCHABLE VS SHAREABLE + CONTENT TYPES

Every piece must be searchable, shareable, or both. Prioritize in that order, search traffic is the compounding foundation.

- **Searchable content** captures existing demand. Optimized for people actively looking for answers.
- **Shareable content** creates demand. Spreads ideas and gets people talking.

### 5a. When writing searchable content (the brief you hand copywriting)

- Target a specific keyword or question; match search intent exactly (answer what the searcher wants).
- Clear titles that match search queries; structure with headings that mirror search patterns.
- Place the keyword in title, headings, first paragraph, URL.
- Comprehensive coverage (leave no obvious question unanswered); include data, examples, links to authoritative sources.
- Optimize for AI/LLM discovery: clear positioning, structured content, brand consistency across the web so LLMs cite you. (There is no separate AI-SEO skill; this is the inline guidance.)

### 5b. When writing shareable content

- Lead with a novel insight, original data, or a counterintuitive take; challenge conventional wisdom with a well-reasoned argument.
- Tell stories that make people feel something; create content people share to look smart or to help others.
- Connect to a current trend or an emerging problem; share a vulnerable, honest experience others learn from.

### 5c. Content-type catalog (pick a type per piece, and give each a commitment)

**Searchable types:**
- **Use-Case Content:** formula `[persona] + [use-case]`, targets long-tail. "Expense tracking for finance teams", "API testing for backend engineers". Commit: name the persona AND the use-case, not "solutions for teams".
- **Hub and Spoke:** comprehensive hub + subtopic spokes (Phase 4). Build the hub first.
- **Template Libraries:** high-intent keywords + product adoption. Target "expense report template"; provide standalone value; show how the product enhances it.

**Shareable types:**
- **Thought Leadership:** articulate a concept everyone feels but nobody named; challenge conventional wisdom WITH evidence; share a vulnerable, honest experience. (Banned as a bare goal, see rule 2; this is the type, the piece must carry a named claim.)
- **Data-Driven:** product-data analysis (anonymized insights), public-data analysis (uncover patterns), original research (run an experiment, share results). Your strongest non-copyable asset.
- **Expert Roundups:** 15 to 30 experts answering one specific question; built-in distribution (each expert shares).
- **Case Studies:** structure Challenge, Solution, Results, Key learnings. (For a portfolio case study of Christopher's OWN work, that is /case-study, a different skill.)
- **Meta Content:** behind-the-scenes transparency. "How We Got Our First $5k MRR", "Why We Chose Debt Over VC".

**Programmatic / templated content at scale** (many pages from one template + a dataset) is an SEO and engineering build, not a sibling skill (there is no SEO skill installed). Scope it as its own project; the per-template copy still routes to /copywriting.

### 5d. Developer-audience note (eval 3)

For a developer tool (API platform, SDK, infra), developers prefer depth, accuracy, and practical value over marketing fluff. Bias toward: technical tutorials, documentation-style guides, use-case content, template/example libraries, data-driven benchmarks. Pillars align with what the developer is trying to BUILD, not with funnel stages. Source ideas from developer communities (Phase 7).

---

## PHASE 6: KEYWORD RESEARCH BY BUYER STAGE

Map topics to the buyer's journey with proven keyword modifiers. A plan that is 100% one stage is broken; spread across all four.

### Awareness Stage
Modifiers: "what is", "how to", "guide to", "introduction to".
Example (customers ask about project-management basics): "What is Agile Project Management", "Guide to Sprint Planning", "How to Run a Standup Meeting".

### Consideration Stage
Modifiers: "best", "top", "vs", "alternatives", "comparison".
Example (customers evaluate tools): "Best Project Management Tools for Remote Teams", "Asana vs Trello vs Monday", "Basecamp Alternatives".

### Decision Stage
Modifiers: "pricing", "reviews", "demo", "trial", "buy".
Example (pricing comes up in sales calls): "Project Management Tool Pricing Comparison", "How to Choose the Right Plan", "[Product] Reviews".

### Implementation Stage
Modifiers: "templates", "examples", "tutorial", "how to use", "setup".
Example (support tickets show implementation struggles): "Project Template Library", "Step-by-Step Setup Tutorial", "How to Use [Feature]".

If real keyword data exists, attach volume and difficulty (Phase 8). If not, tag `[needs keyword data]` and rank on intent + relevance. Never invent a number (rule 3).

---

## PHASE 7: IDEATION SOURCES (six sources, summarized; full recipes in references/)

Generate the topic list from real signal, not vibes. The six sources, in decreasing reliability:

1. **Keyword data** (Ahrefs, SEMrush, GSC exports): cluster related keywords, tag by stage and intent, find quick wins (low competition + decent volume + high relevance) and gaps (competitors rank, you do not).
2. **Call transcripts** (sales, customer): extract questions to FAQ posts, pains in their words, objections to address proactively, exact language (voice of customer), competitor mentions.
3. **Survey responses**: mine open-ended answers, common themes (30%+ mention = high priority), resource requests, format preferences.
4. **Forum research** (web search with `site:` operators): `site:reddit.com [topic]`, `site:quora.com [topic]`, plus Indie Hackers, Hacker News, Product Hunt, industry Slack/Discord. For a **developer** audience add `site:stackoverflow.com`, GitHub Discussions, dev.to, Lobsters. Extract FAQs, misconceptions, debates, terminology.
5. **Competitor analysis** (`site:competitor.com/blog`): top posts, repeated topics, gaps they miss, angles they miss, outdated content to beat.
6. **Sales and support input**: common objections, repeated questions, ticket patterns, success stories, feature requests and the underlying problem.

**Full per-source recipes, the exact search operators, and the Indonesian-market lens (id/en split + local communities like Kaskus, ID subreddits, X-ID, Threads-ID, local Telegram/FB groups + local search behavior) live in `references/ideation-sources.md`.** Read it when the market is Indonesia (rule 9) or when you need the deep extraction recipe for any one source.

---

## PHASE 8: PRIORITIZATION SCORING (the ordering GATE, weights are fixed)

Score every idea on four factors. **The weights are fixed: do not change them.**

### 1. Customer Impact (40%)
- How frequently did this topic come up in research? What percentage of customers face this challenge? How emotionally charged is the pain? What is the LTV of customers with this need?

### 2. Content-Market Fit (30%)
- Does it align with problems your product solves? Can you offer unique insight from customer research? Do you have customer stories to support it? Will it naturally lead to product interest?

### 3. Search Potential (20%)
- Monthly search volume? Competitiveness? Related long-tail opportunities? Is interest growing or declining? (Use real data or tag `[needs keyword data]`, never invent.)

### 4. Resource Requirements (10%)
- Do you have the expertise for authoritative content? What research is needed? What assets (graphics, data, examples)? (Higher score = LOWER effort, so cheap-to-make ranks up.)

### Scoring template (carry the score inline on every piece)

| Idea | Customer Impact (40%) | Content-Market Fit (30%) | Search Potential (20%) | Resources (10%) | Total |
|------|----------------------|-------------------------|----------------------|-----------------|-------|
| Topic A | 8 | 9 | 7 | 6 | 8.0 |
| Topic B | 6 | 7 | 9 | 8 | 7.1 |

Total = 0.4*impact + 0.3*fit + 0.2*search + 0.1*resources. **Order the topic table and the calendar by Total, descending.** Ties break to the LOWER resource cost (ship the cheap win first). Focus first on high-impact, lower-effort pieces, but keep the buyer-stage spread from Phase 6 so the plan is not all top-of-funnel (eval 4).

---

## PHASE 9: EDITORIAL CALENDAR (dated, and it MUST fit the budget)

The calendar is where a strategy becomes executable. It is a dated table, ordered by score, that respects the real writer budget.

### 9a. CALENDAR-REALITY GATE (the arithmetic, eval 4)

1. Compute capacity: `pieces_per_week = writers * throughput_per_writer`. One content marketer at 2 posts/week = 2/week, 8/month.
2. The calendar cadence MUST be <= capacity. If your top-scored plan needs 16 pieces this month and capacity is 8, you schedule the top 8 by score and DEFER the rest to a backlog (listed with scores).
3. Show the arithmetic in the doc ("1 writer x 2/week = 8 slots this month; scheduling the top 8 of 12 candidates; 4 deferred, see backlog").
4. Over-committing a calendar is a FAIL; a plan that cannot be executed is not a plan.

### 9b. Calendar table schema (drives the V4 date anchor)

| Date | Title | Pillar | Type | Stage | Keyword | Score |
|------|-------|--------|------|-------|---------|-------|
| 2026-07-13 | Expense reconciliation template (free) | Close the Month Faster | template | implementation | expense reconciliation template | 8.4 |
| 2026-07-16 | How to cut month-end close from 10 days to 5 | Close the Month Faster | how-to | awareness | month end close process | 8.4 |

(Full 8-row calendar for this scenario: `references/worked-example.md`.)

- Dates are ISO (`YYYY-MM-DD`) or `Wk N` cells so V4 can count them; at least 8 rows.
- **Batch structure:** group production (research a pillar's cluster together, draft in a batch) so a small team is not context-switching every post.
- **Pillar rotation:** rotate pillars across weeks so no single pillar starves; keep the buyer-stage mix balanced week to week.

---

## PHASE 10: OUTPUT FORMAT (what the strategy doc contains)

Deliver the strategy in this order. The anchors (`Ownership thesis:`, `Segment N:`, ISO dates) are what V4 counts, keep them.

1. **Executive summary** (3 to 5 lines): the committed direction, the named pillars in a phrase each, the cadence.
2. **Audience map** (Phase 2): each `Segment N:` with job, pain, vocabulary, buyer-stage skew.
3. **Content pillars** (Phase 3): each `### Pillar N: <Name>` + `Ownership thesis:` + `Why us:` + subtopics. 3 to 5 of them.
4. **Scored topic table** (Phase 8): every recommended piece with its 4-factor score, stage, searchable/shareable, keyword or `[needs keyword data]`, type. Ordered by total.
5. **Topic cluster map** (Phase 4): hub-and-spoke structure per pillar + internal-link notes.
6. **Editorial calendar** (Phase 9): the dated table, ordered by score, cadence <= budget, deferred backlog listed.
7. **Handoff note:** each near-term piece's brief is ready for /copywriting (topic, angle, keyword, stage, audience, outline).

Report to Christopher as TABLES (`feedback_visual_structured_docs`), not prose.

---

## COMMITMENT GATE + ANTI-SLOP BAN LIST

### The COMMITMENT GATE (the anti-generic core, checked before delivery)

A strategy is NOT done unless it NAMES things:

- [ ] 3 to 5 pillars, each with name + one-sentence ownership thesis + why-us + >=5 subtopics.
- [ ] A scored, prioritized topic table (every row fully tagged).
- [ ] A dated calendar of the first >=8 pieces, cadence <= budget.
- [ ] >=1 named audience segment with job + pains + exact vocabulary.

Fail any, run the recovery (FAILURE MODES) and do not ship.

**The proof of what passing this gate looks like: `references/worked-example.md`** is a full filled-in strategy for the eval-1 expense-management scenario (2 named audience segments, 4 pillars each with an ownership thesis, a 12-row scored topic table, the cadence-reality arithmetic + a deliberate buyer-stage swap, and an 8-row dated calendar that fits a 2/week budget, plus one piece brief showing where this skill hands off to /copywriting). Read the SHAPE, never copy its numbers as facts. It also shows the additive Indonesian lens applied to the same scenario without changing the machinery.

### The anti-slop ban list (V3 enforces these on produced files)

These phrases are INPUTS masquerading as deliverables. If one appears as a recommendation, it is slop; replace it with a named artifact:

`create/produce/write valuable | engaging | high-quality | compelling | great | relevant content` · `increase brand awareness` · `build thought leadership` (with no named claim) · `post consistently` · `know your audience` · `provide value` · `tell your story` · `content that resonates` · `drive engagement` · `move the needle`.

Replacement discipline: every time you delete a slop phrase, the fix is a specific named thing this strategy actually commits to (a titled piece, a named pillar, a dated slot), never a different vague phrase.

---

## BOUNDARIES + COMPOSES WITH

**The quartet (only these three siblings exist, verified 2026-07-03):**

| The ask | Owner | Why |
|---|---|---|
| WHAT to write, topics, pillars, calendar | **/content-strategy** (this skill) | the planner |
| WRITE the actual piece (headline, hero, post, email, ad) | **/copywriting** | it writes and gates the piece; it already lists content-strategy as "strategy decides WHAT to write, copywriting writes the individual piece" (its §15 COMPOSES WITH table) and consumes this skill's briefs |
| A launch MOMENT (Product Hunt, GTM, waitlist, announcement, beta) | **/launch-strategy** | owns the launch event, not the ongoing content plan |
| 1:1 recruiter or client OUTBOUND | **/outreach** | researched, proof-led, approval-gated 1:1 messages, never a content plan |

**COMPOSES WITH (the hand-off map):**
- **content-strategy -> copywriting**: hand each near-term piece's brief (topic, angle, keyword, stage, audience, outline). Do not write it here.
- **content-strategy -> launch-strategy**: when a pillar's flagship piece is tied to a release, the launch moment is launch-strategy's job; content-strategy plans the surrounding evergreen cluster.
- **content-strategy -> outreach**: content is 1:many; a specific recruiter/client DM is outreach's job.
- **Posting mechanics -> /agent-browser**: this skill never drives a browser or posts. Distribution feasibility is planned from `references/distribution-reality.md`; the actual publish defers to /agent-browser and the /threads backlog.

SEO, AI-search, programmatic, site-architecture, email, and social are folded INLINE (Phase 5, 6, 7). There is no SEO skill in this library; never cross-ref one (rule 7).

**Progressive disclosure (what lives where):** the rules, gates, the verification block, the scoring weights, and every phase live in THIS file, because a gate that is not in SKILL.md at invocation time does not exist; never move one out. `references/` holds depth only: `ideation-sources.md` (per-source extraction recipes + the Indonesian-market lens), `worked-example.md` (the full filled-in eval-1 strategy), `distribution-reality.md` (own-account channel feasibility, citing the platform memories). Read a reference when its trigger fires (Indonesian market, a channel plan for Christopher's accounts, or you want the exemplar), not by default.

---

## FAILURE MODES (what makes a strategy bad + the recovery playbook)

| Failure mode | Smell | Fix / recovery |
|---|---|---|
| **Vague strategy** (categories, not commitments) | "Pillar: Finance"; "create valuable content" | Force each pillar to an ownership thesis + name the first 3 titles under it; run V4. If it fails, not shippable. |
| **Calendar fantasy** (cadence > resources) | 16 pieces scheduled for a 1-writer 8-slot month | Recompute pieces/week from the writer budget; re-slot the top-scored to fit; list deferred pieces with scores (rule 5). |
| **Fabricated search volumes** | "2,400 searches/mo" with no source | Strip invented numbers; tag `[needs keyword data - pull from Ahrefs/SEMrush/GSC]`; rank on relevance + intent + the other factors (rule 3). |
| **Boundary bleed** (skill starts writing the post) | a drafted headline or hero appears | Stop at the brief (topic, angle, keyword, stage, audience, outline); hand to /copywriting (rule 6). |
| **Western-only ideation for an Indonesian product** | Pulse ideas sourced from Reddit/HN only | Apply the `references/ideation-sources.md` Indonesian lens: local communities + id-language topics + id/en split (rule 9). |
| **Channel mix depends on broken automation** | "auto-DM on Threads daily", "auto-post images to X" | Consult `references/distribution-reality.md`: Threads DM = manual self-send, X images = manual, own-account Threads posting = feasible-but-unbuilt; mechanics defer to /agent-browser (rule 8). |
| **Dead cross-reference** | "see the seo-audit skill" | Run V5; replace with inline guidance or a pointer to copywriting/launch-strategy/outreach (rule 7). |
| **All top-of-funnel** | every piece is "what is X" | Spread across all four buyer stages (Phase 6); the calendar mix must include consideration + decision + implementation (eval 4). |
| **Cluster is vague** | "add several supporting articles" | Name 8 to 15 spoke titles + the explicit internal-link map + a type per piece (Phase 4 gate, eval 5). |

---

## EXECUTION FLOW

1. **Parse** `$ARGUMENTS`, run the Phase 1 mode router, lock the mode + its gate. Run the BOUNDARY GATE (route out if it is a write/launch/outbound request).
2. **Intake** (Phase 1): read `.agents/product-marketing-context.md` if present; gather business/customer/current-state/competitive context; ask only what is missing.
3. **Audience map** (Phase 2): at least one named segment with job, pain, vocabulary.
4. **Pillars** (Phase 3): four lenses to generate, 4-gate test to validate, name + ownership thesis + why-us + >=5 subtopics each.
5. **Clusters** (Phase 4): hub-and-spoke per pillar; if CLUSTER mode, run the completeness gate (8 to 15 spokes + link map).
6. **Types + search/share** (Phase 5), **keyword-by-stage** (Phase 6), **ideation** (Phase 7): fill the topic candidates; tag every one.
7. **Score** (Phase 8): 4-factor score inline on every piece; order the table.
8. **Calendar** (Phase 9): compute capacity, schedule top-scored to fit, show the arithmetic, list deferred.
9. **Assemble** the Output Format (Phase 10); write the strategy doc, calendar, and per-piece briefs.
10. **VERIFY**: run the 0.5 VERIFICATION BLOCK (V1 to V5) on every produced file; satisfy the DELIVERY GATE; report as tables and name where each brief goes (/copywriting).

Remember: a content strategy that could describe any company describes none. Name the pillars, score the pieces, date the calendar, fit the budget, and hand the writing to /copywriting. Commit, or you have not produced a strategy.
