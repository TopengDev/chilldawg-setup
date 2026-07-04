# X / Twitter launch runbook (Christopher's verified stack)

Reference for launching on X. **The source of truth is the memory `reference_aura_x_account`** (the @aura0g launch account + its hard-won automation learnings). This file distills the launch-relevant constraints and CITES that memory; it does not duplicate it, and the memory is updated independently, so when they disagree, the memory wins. Re-read `reference_aura_x_account` before any real X launch automation.

**All browser mechanics defer to the `/agent-browser` skill.** This runbook does NOT re-document how to drive qutebrowser; it names WHAT is possible and hands the HOW to agent-browser (the multi-port /claim lifecycle, the qb-shoot screenshot fallback, never Playwright MCP, never kill the live browser). If a step here needs the browser, route through agent-browser.

---

## 1. The approval gate (non-negotiable, matches SKILL.md §0.5)

`reference_aura_x_account`: **brand voice NEVER auto-posts without Christopher's approval.** This skill DRAFTS the launch tweet / thread; Christopher fires it. No exception for "just the launch tweet" or "it is ready". Present the exact text + the account it posts from, and wait for his go. A launch tweet is public, irreversible, and reputation-bearing.

## 2. What automates reliably vs what does NOT (verified, `reference_aura_x_account`)

| Action | Status | Note |
|---|---|---|
| A single standalone tweet (text) | **Reliable** | Focus the composer textarea, insert text, post. The workhorse. |
| A single standalone tweet WITH an image (main composer) | **BROKEN as of 2026-06-30** | CDP `setFileInputFiles` regressed to a no-op in qutebrowser 3.7 / QtWebEngine 6.11; `files.length` stays 0. It worked for the original launch hero image but does not now. **Image tweets are currently MANUAL-ONLY.** |
| A native multi-tweet thread (the built-in composer's "+" ) | **Does NOT automate** | The `addButton` + `tweetTextarea_N` indexing goes haywire (stray empty tweets, indices do not map). Do not use. |
| A text thread via a self-reply CHAIN | **Reliable, WITH the harness** | Post tweet 1, then reply to it, then reply to that, each a reliable single post. Requires the beforeunload-bypass harness (§4). |
| An image on a REPLY (thread tweets 2+) | **BROKEN** | X uses a detached / template file input for replies; `setFileInputFiles` leaves it at 0. Reply images are manual-only. Tweet 1 carries the hero image; 2+ are text. |
| Follows | **Reliable, paced** | Click Follow, verify the aria-label flips to "Following". Idempotent (skips already-following). |
| Pin a tweet, read latest, screenshot | **Reliable** | Screenshot via qb-shoot (CDP screenshot can come back blank on heavy pages). |

**Net rule for a launch thread on X:** automate the TEXT via the self-reply chain + the harness; put the ONE hero image on tweet 1 (posted manually if the image-attach is still broken on the day); tweets 2+ are text-only. If images on 2+ are ever wanted, they are manual (delete + repost those by hand).

## 3. The 280-character cap (verified 2026-07-01, `reference_aura_x_account`)

@aura0g is **NOT X Premium**, so a single post caps at **280 X-weighted characters** (a URL counts as 23). A longer draft has the Post button DISABLED (X shows the "write longer posts / Premium" upsell + a maxed char ring). Keep every single @aura0g post <= 280. For a longer message: split into a <= 280 self-reply thread (the §4 chain), or enable Premium. **Always check the Post button is ENABLED before the single click** (the >280 disabled state is silent otherwise).

## 4. The beforeunload-bypass harness (the key reusable piece)

`reference_aura_x_account`: navigating away from a composer holding unsaved text fires a native "Leave page? Changes may not be saved" dialog that BLOCKS the CDP (it is not a permission prompt, so allow-all config does nothing). The fix is a harness that (a) injects, on every new document, a `window.addEventListener` override that drops every `beforeunload` registration, and (b) auto-responds to `Page.javascriptDialogOpening` with accept. With it, navigating between composers no longer hangs and the text-only self-reply chain posts a full thread cleanly. This harness (`x-harness.py` in the aura kit) is the canonical X-action tool; it is the required piece for ANY multi-navigation X automation here. Heavy repeated CDP automation can still WEDGE the qutebrowser CDP (port stops responding); recovery is a browser refresh / restart by Christopher, never kill it out from under him.

## 5. Two safety gates to fold in (verified 2026-07-01, `reference_aura_x_account`)

Before any automated post, verify TWO things (the canonical `x-harness.py` historically lacked both; a gated poster `xctl.py` added them):
1. **Account-identity gate:** confirm the logged-in account is the intended one, read TWO ways (the account-switcher innerText, e.g. `AURA\n@aura0g`, AND the left-nav profile href, e.g. `/aura0g`) BEFORE composing. Posting to whoever is logged in with no check is a real wrong-account risk.
2. **Post-enabled check:** confirm the Post button is enabled before the single click (catches the >280 disabled state, §3).
After posting, verify the tweet is live (read it back + a qb-shoot screenshot; a DOM media-img probe false-negatives on X lazy-load, so the `a[href*='/photo/']` permalink + the screenshot are the reliable signals).

## 6. New-account safety (verified, `reference_aura_x_account` + the kit RUNBOOK)

For a fresh launch account, X is bot-protected; do NOT trip it:
- Drive it through Christopher's REAL authed qutebrowser session (residential IP), never headless.
- No bursts: pace roughly **8 follows on day 1**, then a handful a day; **1 to 2 posts a day**.
- **Profile before posts** (avatar, banner, bio, website set first; an empty profile posting looks like a bot).
- **Verify email + phone** (the #1 anti-flag trust signal).
- No third-party auto-follow / auto-DM tools.

## 7. The @aura0g launch as the grounded example (real numbers, not folklore)

Use this REAL launch as the reference example instead of unsourced case studies (`reference_aura_x_account`):
- Launch account **@aura0g** (no underscore), display name AURA, live + verified 2026-06-29.
- **Launch thread: 6 tweets.** Tweet 1 = hook + the styles-4up hero image, PINNED. Tweets 2 to 6 = text-only reply chain via the harness (per-tweet images on 2 to 6 were not possible, §2).
- **Follows day 1: 8 tier-1 accounts** (the ecosystem majors), paced, no burst.
- Ongoing week-1 engagement ran as a hybrid: a mechanical systemd timer for the pre-written content-calendar posts + tier-2 follows (standalone posts, so images work), and a gated Opus worker for the judgment replies (draft, escalate to Christopher, approve, post).
- A later mainnet announcement was a single standalone text tweet, shortened to <= 280 (§3), Christopher-approved.

This is the shape of a real X launch here: a pinned hero tweet, a text reply-chain thread, paced follows, everything approved before it posts.

---

## Launch-context do / dont

- DO draft the full thread (all tweets) + the hero image spec, show Christopher, let HIM fire it.
- DO keep every post <= 280 and vote-ask-free (SKILL.md §0.4: never "RT/like/vote", mobilize people to look + reply).
- DONT use the native multi-tweet composer (§2) or assume reply-image attach works (§2, currently broken).
- DONT auto-post, auto-burst follows, or drive a headless instance (§6).
- DONT hand-roll browser automation: route every browser step through `/agent-browser` and the harness (§4).
