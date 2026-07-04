# Distribution Reality: channel feasibility for Christopher's own accounts

Progressive-disclosure companion to NON-NEGOTIABLE rule 8. A content strategy that recommends HOW to distribute for Christopher's own brands (Aenoxa, Pulse, AURA, his personal Threads/X) must be grounded in what actually works today, not in what sounds automatable. This file CITES the verified memory records; it does not duplicate them. Read the cited memory for the full detail before you plan a channel tactic that leans on it.

**The one hard guardrail:** a channel mix must NEVER depend on automation that is broken, prohibited, or unbuilt. Posting MECHANICS are out of scope for /content-strategy entirely, they defer to the /agent-browser skill (multi-port claim lifecycle, qb-shoot fallback, never kill the live browser, never Playwright MCP) and to the /threads backlog. This skill plans WHICH channels and WHAT cadence; it does not post, and it does not promise a bot that does not exist.

No em/en dash, no emoji, no invented metrics in anything produced from this file.

---

## Threads (Meta) : posting FEASIBLE-but-unbuilt, DM automation AVOID

**Source of truth: `reference_threads_api` + `feedback_threads_dm_automation_context_bound` (both memory, read them for full detail).**

### Own-account POSTING via the official API: feasible, NOT built, Toper-gated
- The Meta Threads API supports automated own-account posting in DEV mode with no App Review (invite self as a Threads Tester). Scopes `threads_basic` + `threads_content_publish`. Limits: 250 posts per rolling 24h, 500-char per post, max 5 links/post. Free.
- STATUS: NOT built as of the memory. It requires Christopher to create the Meta app + link an IG Business account, plus token-refresh maintenance. So a plan MAY name Threads as a channel, but it must NOT assume an existing posting bot. Flag it as "feasible, needs a build + Toper greenlight".
- There is ALSO a proven live-posting path via qutebrowser CDP (posted to @chilldawg89 2026-06-29): inline composer on the home feed, submit is Ctrl+Enter (a JS click on Post is a no-op). That is a /agent-browser mechanic, cite it, do not re-document it here.

### Threads DM automation: AVOID (context-bound)
- Browser-automating a Threads DM send freezes workers at ~90% context (the /messages page + Lexical editor dump huge DOM per action). Three successive workers failed before sending (2026-05-30).
- DEFAULT: hand Toper the exact verbatim text(s) and let him self-send from his phone (30 seconds, and more authentic for his own outreach anyway). A strategy must NOT schedule "daily automated Threads DMs".
- Product constraints if a DM tactic is planned at all: DM composer hard-caps at 1000 chars (split long messages); a DM to a non-followed account is a message request (up to 3 messages before they accept); NO file/PDF attach in Threads DM (link instead).

### Voice for Threads content
- Public Threads posts use Christopher's NATURAL viral-post voice (normal punctuation, occasional single emoji HE adds), NOT the strict outreach symbol set (`feedback_toper_writing_style`, resolved 2026-06-29). But this skill does not write the post: it briefs /copywriting, which owns the voice.

---

## X / Twitter : text posting works, IMAGE posting BROKEN, 280-char cap

**Source of truth: `reference_aura_x_account` (memory, read it for full detail). Account @aura0g.**

- **Text posting works** via qutebrowser CDP (the beforeunload-bypass harness). A single-tweet self-reply chain can build a thread. This is a /agent-browser mechanic.
- **IMAGE posting is BROKEN** as of 2026-06-30: CDP `setFileInputFiles` regressed to a no-op in qutebrowser 3.7 / QtWebEngine 6.11, and the synthetic-paste fallback also fails (no real-key injector installed on the Wayland box). So X image tweets are MANUAL-ONLY until QtWebEngine is fixed or a key injector is installed. A plan must NOT promise auto-image X posts (this also blocks the mechanical scheduler's image posts).
- **280-char cap**: @aura0g is NOT X Premium, so a single post caps at 280 X-weighted chars (a URL counts as 23). A longer message must be a <=280 self-reply thread or needs Premium. Plan X copy to the 280 budget, or plan a thread.
- **New-account safety**: residential IP only (his real qutebrowser), no bursts, profile-before-posts. A distribution plan for a day-0 account paces posting (1 to 2/day), it does not schedule a blast.

---

## The planning rules that fall out of this

When the strategy includes a distribution/channel section for Christopher's own accounts:

1. **Name the channel and the cadence, not the bot.** "Publish 2 Threads/week + 1 X thread/week, id-first" is a plan. "Auto-DM 50 Threads leads/day" is a fantasy that will freeze workers.
2. **Any automation claim gets a feasibility tag**: `works` (X text, Threads CDP post), `manual-only` (X images, Threads DM send), or `feasible-but-unbuilt` (Threads posting API). Never present `manual-only` or `unbuilt` as if it runs today.
3. **Mechanics defer out.** The moment the plan touches HOW to post (composer, CDP, file input, submit key), stop and point at /agent-browser + the /threads backlog. This skill plans, it does not drive the browser.
4. **Self-send is a valid distribution step.** "Hand Toper the 3 verbatim Threads posts for the week, he posts from his phone" is a legitimate, reliable line in a plan. It is not a cop-out, it is the correct call given the DM/context reality.
5. **Generic-client plans are unaffected.** For a client that runs its own social team with its own scheduler (Buffer, Hootsuite, native scheduling), plan channels and cadence normally; this dossier is specifically about Christopher's own-account automation reality.

---

## Quick-reference feasibility table

| Channel / action | Reality today | Plan may assume | Cite |
|---|---|---|---|
| X (@aura0g) text post / thread | Works (CDP, beforeunload harness) | Yes, paced, <=280/post | reference_aura_x_account |
| X image post | Broken (QtWebEngine 6.11) | Manual-only | reference_aura_x_account |
| Threads own-account post (API) | Feasible, not built, Toper-gated | Feasible-but-unbuilt (needs build) | reference_threads_api |
| Threads own-account post (CDP) | Proven working 2026-06-29 | Mechanic defers to /agent-browser | reference_threads_api |
| Threads DM send (automated) | Freezes workers at ~90% context | No, hand Toper verbatim to self-send | feedback_threads_dm_automation_context_bound |
| Any posting mechanic | Owned by /agent-browser | Route out, do not document here | agent-browser skill |
