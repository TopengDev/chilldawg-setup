# Product Hunt 2026: the mechanics encyclopedia

Deep reference for the SKILL.md §6 gate. Every claim here is tagged with how it was verified and when. **Platform mechanics change. Before any real launch, re-verify the load-bearing rows against the official source (producthunt.com/launch, and the Help Center Community Guidelines + Featuring Guidelines).** This file was compiled 2026-07 from the official PH guide + Community Guidelines + Featuring Guidelines, cross-referenced against 10+ current third-party guides (smollaunch, getlaunchlist, screenhance, dub.co, waitlister, poindeo, tooljunction, fmerian/awesome-product-hunt, dev.to 30x-winner). Third-party guides agree on the big mechanics and diverge on the exact benchmark numbers (flagged below).

Verification tags used:
- `[PH-OFFICIAL 2026-07]` = stated on producthunt.com or its Help Center.
- `[GUIDES 2026-07]` = consistent across multiple current third-party guides.
- `[VARIES]` = third-party guides disagree; treat as a range, never a promise.

---

## 1. The 24-hour race and the fixed 12:01 AM PT start

- `[PH-OFFICIAL 2026-07]` A Product Hunt "day" is 12:00 AM to 11:59 PM **Pacific Time**. Every launch goes live at **12:01 AM PT** and runs a full 24h to 11:59 PM PT. There is **no option to launch later in the day**. PH does NOT adjust for your time zone.
- `[PH-OFFICIAL 2026-07]` You can **schedule a launch up to about 1 month ahead**.
- `[GUIDES 2026-07]` Launching at, say, 11 PM PT gives you 1 hour to compete against products that had all day. Always take the 12:01 AM PT slot for a serious launch.
- **WIB conversion (Christopher context):** 12:01 AM PST is about 15:01 WIB the same day; 12:01 AM PDT (US daylight time, roughly Mar to Nov) is about 14:01 WIB. Confirm which US offset is in effect for the launch date and schedule the reminder precisely (SKILL.md §5c). A PH launch day runs through the Jakarta night.

## 2. The first ~4 hours (hidden counts, randomized homepage)

- `[GUIDES 2026-07]` For roughly the **first 4 hours** of the day, PH **hides upvote counts** and **sorts the homepage randomly**, described as giving products "a more distributed chance at exposure early". Counts become visible around **4 AM PT**, when the visible ranking competition begins.
- Implication: you are flying blind on the number for the first 4h, but the votes and engagement still register. Do not panic at a hidden count; keep the velocity up.

## 3. First-hours velocity is the dominant signal

- `[GUIDES 2026-07]` The algorithm rewards a fast, **accelerating** curve in the first ~6 hours. A rough working target from multiple guides: **200+ upvotes and 30+ comments in the first 6 hours**, which is the window where the algorithm sets the initial ranking.
- `[GUIDES 2026-07]` Products that reach the top early **tend to stay there** the rest of the day (position is sticky).
- `[GUIDES 2026-07]` **Even spacing beats one spike.** A launch that gets 200 in hour 1 then crawls to 600 by end of day ranks LOWER than one that paces steadily; the algorithm asks "is this accelerating or decelerating?". A "wave" structure (a push around 12 AM, another around 7 AM, another around 2 PM PT) consistently outperforms a single midnight blast.
- `[GUIDES 2026-07]` Respond to **every comment within ~30 minutes** through the active window.

## 4. Featured vs All (the traffic gate that surprises people)

- `[GUIDES 2026-07]` PH has two tabs: **Featured** and **All**. **Only Featured launches appear on the homepage AND in the mobile app.** A launch stuck in "All" has near-zero organic reach no matter how many upvotes it gets; visitors have to deliberately click over to "All" and most do not.
- `[PH-OFFICIAL 2026-07, Featuring Guidelines]` **Not every product is featured**, PH manually curates, providing extra context "does not guarantee that your product will be featured", and "in the vast majority of cases, our featuring decisions are final".
- The brutal implication (multiple guides): makers prepare for weeks, line up supporters, get real upvotes, and then discover they were never featured, so the traffic they drove only benefited PH. **Design for the featuring criteria (§5) from the start; do not assume featuring.**

## 5. The 4 Featured criteria (official)

`[PH-OFFICIAL 2026-07, Featuring Guidelines]` Featured launches are evaluated on four qualities, and a launch does NOT need to score high on all four, it often spikes on one or two:
- **Useful**: practical benefit for users.
- **Novel**: an innovative or unique approach.
- **High Craft**: well-designed and delightful.
- **Creative**: fun, engaging, or imaginative.

Hard requirements: the product must be **digital**, **currently live / available** (no vaporware), and **differentiated** (PH explicitly excludes "minimal, undifferentiated products" focused mainly on quick monetization). By the time a product appears on the site it has been "thoroughly evaluated multiple times".

Design move: pick the ONE criterion the product hits hardest and make the product page + gallery + tagline lead with it.

## 6. Weighted votes and the anti-gaming filters

- `[GUIDES 2026-07]` The ranking is roughly **weighted upvotes over time-velocity**, with multipliers and penalties. An upvote from an established account (5-year-old, has hunted products, follows you, votes in the first hour) is worth roughly **5 to 10x** a brand-new account's upvote.
- `[GUIDES 2026-07]` **Newbie filter:** accounts created within ~72h of a launch are often shadow-filtered, the visible count may rise but the leaderboard rank does not move.
- `[GUIDES 2026-07]` **Lurker penalty:** an account that only ever logs in to vote for one product then vanishes gets devalued as a "suspicious social signal".
- Why this matters for the plan: this is the mechanical reason you **prime real PH-active supporters weeks ahead** (SKILL.md §6c) instead of blasting a cold list on the day. Cold day-0 accounts are the exact profile the filters discount.

## 7. Asking for upvotes is banned (the one that gets you removed)

- `[PH-OFFICIAL 2026-07, Community Guidelines]` "Mass messaging users, asking for upvotes, using bots, incentivizing upvotes, and any other form of artificially increasing activity on your contribution is not acceptable." Gaming may result in "the removal of your contribution(s) and the loss of contribution access".
- `[GUIDES 2026-07]` Asking for upvotes (in DMs, on X, in the maker comment, or by email) is the single behavior that consistently gets posts removed or shadowbanned. Ask for **comments, feedback, or to "check it out"** instead.
- This is SKILL.md §0.4, a HARD RULE, enforced by V5. Share the launch link freely; never attach "upvote us" to it.

## 8. The day-of-week tradeoff

- `[GUIDES 2026-07, VARIES on emphasis]` Two schools, pick by goal:
  - **Tuesday / Wednesday / Thursday** = the most traffic, but also the most competition (OpenAI, Google, Perplexity and other big players tend to drop then).
  - **Friday / Saturday / Sunday** = less traffic, but a higher chance of the **#1-of-the-day** badge.
  - The explicit tradeoff a guide names: a Tuesday launch ranking #6 with ~600 upvotes generates more raw traffic than a Sunday launch ranking #1 with ~400. So choose Tuesday for max raw traffic even at a lower rank, or a weekend for the #1 badge.
- `[GUIDES 2026-07]` Secondary badge angles: launching Monday leaves more days to chase the **weekly** badge; launching early in the month maximizes exposure for the **monthly** badge; February tends to be more competitive than summer months.

## 9. Relaunch cooldown

- `[GUIDES 2026-07]` Roughly **one launch per version** (v1, v2, v3), about **6 months apart**. You can launch distinct products or major features separately.
- `[GUIDES 2026-07]` An earlier relaunch is possible **if the product changed substantially**: submit a request explaining the significant changes and PH reviews it. Relaunches get rejected when the change was not significant (the "wow effect" is gone) or the product does not comply with the rules.
- Planning implication: you do not get infinite PH shots. Do not spend the slot on a half-ready product, and do not re-launch the same thing hoping for a different result (SKILL.md §8 flop tree).

## 10. Benchmarks (a RANGE, never a promise) `[VARIES]`

Third-party guides disagree; the honest version is a wide range with real variance by day and source:
- One set of 2025 to early-2026 figures: top-5 of the day roughly **500 to 900** upvotes on weekdays, **300 to 500** on weekends; **#1 of the day** roughly **1,200 to 1,800**.
- Another 2026 figure: **#1 of the day** typically **500 to 1,200**, distribution varies by day.
- Net: quote these ONLY as "a rough range, varies by day and source, re-check current", tag any number `[range, source-dated]`, and never build a plan that promises a specific count. The 2026 shift (below) also means raw count matters less than it used to.

## 11. The 2026 algorithm shift: engagement over raw upvotes

- `[GUIDES 2026-07]` Multiple 2026 guides report the algorithm now weights **comments, maker replies, thread depth, time-on-page, and bringing NEW users to PH** more than raw upvote count. It rewards deep engagement and a "hockey stick" acceleration, and it specifically values launches that bring **new** members to the platform.
- Planning implication: optimize for a real conversation on the page (answer every comment, seed genuine discussion), not a vanity number. Bringing your owned audience to PH as new active members is worth more than a pile of drive-by votes.

## 12. Hunter vs self-launch `[GUIDES 2026-07]`

- Historically a well-connected "hunter" launching on your behalf carried weight. Current guidance: a hunter with a large, PH-active following can still help early velocity, but self-launching is fully normal and often better because you control the timing, the maker comment, and the narrative. If you use a hunter, it must be a genuine relationship, not a paid vote-ring (which the anti-gaming filters + §7 ban catch). Do not treat "get a big hunter" as a substitute for a primed supporter base and a featured-worthy product.

## 13. A recommended launch-day timeline (illustrative, adapt) `[GUIDES 2026-07]`

All times PT (convert to WIB for coverage, §1):
- 12:01 AM: go live.
- 12:02 AM: post the maker's first comment (context + the one thing it does + who for; NO vote-ask).
- 12:05 AM: email the waitlist / owned list ("we just launched, come see + tell us what you think").
- 12:15 AM: post the launch thread on X + link.
- 1:00 AM: honest Show-post in a relevant community (Indie Hackers, a fitting subreddit).
- 6:00 AM to 7:00 AM: second X update (early traction), a LinkedIn post.
- 2:00 PM: a mid-day wave push to keep the curve accelerating (§3).
- 9:00 PM: a thank-you thread.
- 11:45 PM: a closing comment on the PH page.

This is the "wave" structure (§3), not a single blast. Every one of these is a DRAFT for Christopher to fire (SKILL.md §0.5), and every one is vote-ask-free (§7).

---

## Quick re-verify checklist (run before a real PH launch)

1. Is 12:01 AM PT still the fixed start, and is the Featured/All homepage split still in effect? (producthunt.com/launch)
2. Do the Community Guidelines still ban asking for upvotes? (Help Center Community Guidelines)
3. Are the 4 featuring criteria still Useful / Novel / High Craft / Creative? (Help Center Featuring Guidelines)
4. Has the relaunch cooldown or the day-of-week dynamic shifted? (current guides)
5. Update any benchmark you cite to the current range. Re-tag with the new date.
