# Ideation Sources: deep recipes + the Indonesian-market lens

Progressive-disclosure companion to Phase 7 of SKILL.md. The six sources are summarized in the skill; this file holds the extraction recipes, the exact search operators, and the additive Indonesian-market lens (invoked when the market is Indonesia, rule 9). Everything here obeys the PRIME rules: no em/en dash, no emoji, and no invented metrics (tag `[needs keyword data]`).

The reliability order is deliberate. Sources 1 to 3 are your OWN signal (highest trust: real customers, real words). Sources 4 to 5 are public signal (good for volume and validation). Source 6 is your team's memory. Mine the top of the list first.

---

## 1. Keyword data (Ahrefs / SEMrush / GSC exports)

The strongest input when it exists, because it carries real demand numbers. If the user hands you an export:

- **Cluster** related keywords into candidate pillars (group by shared head term + intent).
- **Tag each** by buyer stage (Phase 6 modifiers) and search intent (informational, commercial, transactional).
- **Find quick wins**: low keyword difficulty + decent volume + high relevance to what you sell. These are the first calendar slots.
- **Find gaps**: keywords a competitor ranks for that you do not (content-gap report in Ahrefs/SEMrush). Each gap is a candidate piece.
- **GSC-specific**: pull queries where you rank position 5 to 15 (page 1 to 2 edge). A refresh on an existing post that is "almost there" beats a new post from zero (this is a core AUDIT-mode move).

Output as a prioritized table:

| Keyword | Volume | Difficulty | Buyer Stage | Content Type | Priority |
|---|---|---|---|---|---|

If NO export was provided, do NOT invent volumes. Tag the Volume and Difficulty columns `[needs keyword data]` and rank on relevance + intent + the Phase 8 non-search factors until real data arrives.

---

## 2. Call transcripts (sales + customer calls)

Sales and support calls are voice-of-customer gold: the exact words, the real objections, the emotional charge. If the user provides transcripts (or Gong/Fireflies exports), extract:

- **Questions asked** to FAQ posts or awareness-stage articles ("how do I do X before I buy").
- **Pain points** in the customer's own words (these become titles verbatim; do not paraphrase into marketing-speak).
- **Objections** to address proactively in consideration/decision content.
- **Language patterns** (the vocabulary that feeds Phase 2 segments and Phase 6 keywords).
- **Competitor mentions**: what they compared you to (feeds comparison/alternative pieces).

Output each idea WITH its supporting quote, so the strategy is traceable to a real customer, not a guess.

---

## 3. Survey responses

If the user has survey data (NPS open-ends, onboarding surveys, exit surveys):

- **Open-ended responses**: the topics AND the language people volunteer unprompted.
- **Common themes**: a theme mentioned by 30%+ of respondents is a high-priority pillar candidate.
- **Resource requests**: "I wish there was a guide to X" is a pre-validated piece.
- **Format preferences**: whether they want written guides, video, templates, calculators.

---

## 4. Forum research (web search with site: operators)

Use WebSearch with `site:` operators to find what real people ask, in their words, at volume. This is the fastest cold-start source when you have no first-party data yet.

- **Reddit**: `site:reddit.com [topic]`. Read top posts in the relevant subreddits; harvest questions and frustrations from comments; upvotes validate what resonates.
- **Quora**: `site:quora.com [topic]`. Most-followed questions + highly upvoted answers.
- **Others**: Indie Hackers, Hacker News (`site:news.ycombinator.com`), Product Hunt, industry Slack/Discord archives.

**Developer audience (eval 3):** add `site:stackoverflow.com [topic]`, GitHub Discussions and issues (`site:github.com [topic] discussions`), dev.to (`site:dev.to`), and Lobsters. Developers ask precise, high-intent questions; a Stack Overflow question with 50k views is a validated tutorial topic. Bias the content types toward technical tutorials, doc-style guides, and benchmark/data pieces, not marketing posts.

Extract from every forum pass: recurring FAQs, common misconceptions, active debates (two-sided = shareable content), the specific problems people are solving, and the terminology they use.

---

## 5. Competitor analysis (site: operators)

- **Find their content**: `site:competitor.com/blog` (or `/resources`, `/guides`).
- **Analyze**: top-performing posts (comments, shares, backlinks if you have Ahrefs), topics they cover repeatedly (their bet), gaps they have not covered, their case studies (customer problems, use cases, results), their content structure (pillars, categories, formats).
- **Identify opportunities**: topics you can cover deeper or better, angles they miss, outdated posts you can beat with a fresher, more comprehensive piece.

Competitor content tells you the shape of proven demand in your exact category. Do not copy it; find the gap and the better angle.

---

## 6. Sales and support input (your team's memory)

Ask the customer-facing team directly:

- Common objections (feeds decision-stage content).
- Repeated questions (feeds FAQ + awareness content).
- Support-ticket patterns (a ticket cluster = an implementation-stage piece that deflects tickets).
- Success stories (feeds case studies + data-driven content).
- Feature requests, and the underlying problem behind each (the problem is the content topic, not the feature).

---

## THE INDONESIAN-MARKET LENS (additive, invoke when the market is Indonesia)

For Aenoxa / Pulse and any Indonesia-first product, the Western-forum default is wrong on two axes: language and communities. This lens is ADDITIVE, it does not replace sources 1 to 6, it re-points them. Generic Western B2B strategies keep the default path.

### A. Content-language split (id default, en secondary)

The house default for the Aenoxa ecosystem is Bahasa Indonesia first, English second (mirrors the website i18n default of `id` default + `en`). Content is not a website, but the same market bias applies. Plan the split explicitly:

- **Bahasa Indonesia (default):** bottom-of-funnel + local-intent + community-driven pieces. The buyer searches and reads in Indonesian; the decision-stage and how-to content should be id-first. Product terms often stay English inside Indonesian sentences (code-switching is normal, "cara setup Pulse POS", "fitur inventory"), match how the audience actually types.
- **English (secondary):** category-defining thought leadership, investor/partner-facing pieces, and topics where the searchable demand is genuinely English (developer tooling, some SaaS categories). Do not force-translate; write English where the demand and the reader are English.
- **Per-pillar tag:** in the Output Format, tag each pillar and each calendar row with `lang: id | en | both` so the plan is executable by a bilingual team. `both` means a transcreated pair (route to /copywriting, which is bilingual id+en and transcreates rather than translates), not a machine translation.

### B. Local search behavior

- Indonesian search queries skew toward "cara ..." (how to), "harga ..." (price), "... vs ...", "aplikasi ... terbaik" (best app for ...), and heavy long-tail in Bahasa. The Phase 6 modifiers have id equivalents: awareness "apa itu / cara", consideration "terbaik / vs / alternatif", decision "harga / review / demo", implementation "template / tutorial / cara pakai".
- Mobile-first and price-sensitive: decision-stage content that answers "harga" and "vs competitor" converts hard.
- WhatsApp is the dominant channel; "shareable" content in Indonesia often means WA-forwardable (an infographic, a checklist, a short thread), not a Reddit-style long essay.

### C. Local community source list (replace the Western forums for ideation)

Re-point source 4 to where Indonesians actually discuss:

- **Kaskus** (`site:kaskus.co.id [topic]`): the largest ID forum, strong for consumer + SMB topics.
- **Indonesian subreddits**: r/indonesia, r/finansial (personal finance), r/indonesia-specific niche subs (`site:reddit.com/r/indonesia [topic]`). Bilingual but heavily id.
- **X-ID (Twitter Indonesia)**: local threads and "menfess" accounts surface real pains and trending debates in a niche.
- **Threads-ID**: growing, especially for younger + creator audiences (see `references/distribution-reality.md` for the posting-feasibility reality; ideation via read-only search is fine).
- **Local Telegram + Facebook groups**: SMB-owner groups, industry-specific (F&B owners, retail, UMKM), where operational pains are discussed candidly. Search summaries surface topics even without joining.
- **Product-specific**: for Pulse (POS for Indonesian retailers), the pains live in UMKM and retail-owner communities, not Indie Hackers. Source there.

### D. Do not do

- Do NOT source an Indonesian-market strategy from English-only Reddit/HN and call it done (rule 9 failure mode).
- Do NOT machine-translate an English pillar into Indonesian and ship it as the id plan; transcreate (route pieces to /copywriting).
- Do NOT invent local search volumes any more than English ones; `[needs keyword data]` applies to id keywords too (GSC + Ahrefs cover Indonesia).
