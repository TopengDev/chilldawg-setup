# Web3 / hackathon launch playbook

Reference for the SKILL.md §2 `hackathon-submission` and `web3-app` launch types. A hackathon launch is fundamentally NOT a Product Hunt launch: the timeline is anchored by a hard external date, the primary artifact is a demo video + a judge-facing evidence package (not a PH gallery), and the community vote comes AFTER a merit round, so reach is a LATE lever, not the opener.

This file CITES `reference_aura_zerocup_strategy` (the fully worked 0G Zero Cup case, Christopher's live context) and `reference_web3_hackathon_sources` (discovery platforms). The memories are the source of truth and are updated independently; re-read them for the live bracket state before acting. Bracket dates below are the 0G Zero Cup's specifics as of 2026-07-01; the PATTERNS generalize, the dates do not.

---

## 1. The two-phase structure (jury first, vote later)

The load-bearing insight (`reference_aura_zerocup_strategy`): a bracketed web3 hackathon typically runs **merit / jury rounds first, and a community VOTE only starts in the later rounds.** In the 0G Zero Cup, the group stage through R16 (down to the Top 8) is JURY-judged on merit; the community vote only starts at the quarterfinal (Top 4) and runs through the final.

What this means for the launch sequence:
- **To survive the early rounds you win on MERIT, not reach.** Near-zero community following does not bite until the vote rounds. Do not burn early energy on vote mobilization; spend it on the build + the jury artifacts.
- **Community mobilization is the VOTE-round lever.** Start building / warming the audience so it is ready WHEN the vote opens (in the Zero Cup, "start mobilizing by the R16 date for the QF vote"), not before, and never as a substitute for merit in the jury rounds.
- Know exactly which rounds are jury vs vote for YOUR hackathon before planning; the split decides where every unit of effort goes.

## 2. The code-lock date IS the hard T-0

`reference_aura_zerocup_strategy`: the hackathon's **code-lock / final-submission date is the real T-0 for ALL build work** (in the Zero Cup, one build rides from the quarterfinal through the final, so everything must land before the Jul-8 lock). This is different from a SaaS launch where you pick your own date.
- Treat the code-lock as an immovable T-0 in the SKILL.md §5 checklist. Every build + evidence + video row hangs off it and must complete BEFORE it.
- Schedule it hard (SKILL.md §5c): a hackathon code-lock is exactly the kind of weeks-out deadline that needs the durable Google Calendar reminder, not a session-only cron. (Verified pattern: the AURA Zero Cup knockout reminders Jun-27 to Jul-19 were set on Google Calendar for this reason.)
- After the lock, build energy shifts to the jury/vote presentation, not the code.

## 3. The demo video is the #1 jury artifact

`reference_aura_zerocup_strategy`: "Demo video = the #1 jury artifact." A jury skims fast; a tight, real demo that shows the product working (real output, the wow moment, the honest receipts) is what moves the merit score more than any amount of copy. In the Zero Cup the winning move was a polished demo leading with the actual differentiator (real art + the royalty loop + the provable-provenance climax).
- Prioritize the demo video's production quality; it is the deliverable, not an afterthought. The build is a delegated creative task (video production is not planned in prose here; delegate it).
- Lead the video with the ONE thing no rival has, and end on the concrete proof (on-chain receipts, the working flow), not a features montage.

## 4. Build a judge-facing evidence package

`reference_aura_zerocup_strategy` (highest-ROI move before a cut): a **proof deck / evidence package for the jury** that makes the merit legible: the primitives you actually use, mainnet vs testnet status, the on-chain transaction receipts, and the one hard technical claim that is code-true and verifiable. Juries reward what they can verify; a claim with a tx hash beats a claim with an adjective.
- Assemble it as a launch artifact with the demo video (SKILL.md §5, hackathon rows replace the PH rows).
- Every claim in it must be code-true and source-readable. In a source-reading jury, an OVERCLAIM (a mock presented as real, a "TEE" that is a centralized relay) is weaponizable against you; a rival can expose it in one grep. Harden your own source honesty to the cleanest rival's bar before submission.

## 5. DO NOT frame opponents as weak / abandoned in jury-facing material

`reference_aura_zerocup_strategy` (explicit): **DO NOT frame any opponent as abandoned or weak in jury-facing material.** If the opponents are live and verifiable, a false "they did not ship" backfires and reads as an aggressor. Beat them on your own axes (breadth, the real differentiator, verifiability depth), not by talking them down.
- A precise, fact-based, screenshot-backed technical contrast (e.g. "our guard enforces X where the competing approach only stores a UUID") is fair and defensible IF it is literally code-true. A vague "they are worse" is not.
- Misrepresenting what YOUR app does is itself a DQ vector (alongside vote-rigging). Frame precisely; overclaiming your own product is as disqualifying as attacking theirs.

## 6. The vote round: mobilize to LOOK, never to vote-rig

When the community vote opens (the later rounds):
- Mobilize your warmed audience to **look at the product + engage** on the merits, exactly as SKILL.md §0.4 requires. **Never script "vote for us"**, vote-rigging is a named DQ vector (`reference_aura_zerocup_strategy`).
- The vote round rewards the WATCHABLE / shareable artifact (in a creative-vs-infra matchup, the visual art out-shares a dashboard). Lead the vote-round push with the most shareable proof.
- This is where the community reach you deprioritized in the jury rounds finally pays off, so it must be warm and ready by the time the vote opens.

## 7. Discovery sources (where these hackathons live)

`reference_web3_hackathon_sources` (partial + growing list Christopher maintains):
- **HackQuest**: web3 dev-learning + hackathon platform.
- **DoraHacks**: major global web3 hackathon + grant / BUIDL platform.
- **Encode Club**: web3 education + hackathons / bootcamps / accelerators.
- **X (Twitter)**: hackathon announcements + discovery via web3 accounts.

---

## Hackathon launch checklist shape (replaces the PH rows in SKILL.md §5)

| T-minus | Item | Owner | Depends-on | Done-when | M/O |
|---|---|---|---|---|---|
| T-lock minus N | Land all build work before the code-lock | You / Ship | - | Everything merged into the submission branch, verified | M |
| T-lock minus N | Harden source honesty (kill any mock/overclaim in view) | You | build | A source self-audit is clean; no weaponizable overclaim | M |
| T-lock minus 3 | Produce the demo video (the #1 jury artifact, §3) | Creative (delegated) | build | Video renders, leads with the differentiator, ends on real proof | M |
| T-lock minus 2 | Assemble the judge-facing evidence package (§4) | You | build | Proof deck with primitives + on-chain receipts, every claim code-true | M |
| T-lock | Submit (pick the WIRED + deepest commit, not a stale default branch) | You (Christopher fires) | all above | Submission live on the right commit | M |
| Jury round | Presentation leads with the differentiator; precise, no opponent-bashing (§5) | You | evidence pkg | Jury-facing material is fact-checked + DQ-safe | M |
| Vote round opens | Mobilize the warm audience to LOOK + engage (never vote-rig, §6) | You (Christopher fires) | audience warmed | Shareable proof pushed; zero vote-ask copy (V5) | M (vote rounds) |

Every dated row is scheduled durably (SKILL.md §5c, Google Calendar for the weeks-out bracket dates). Every public push is a DRAFT Christopher fires (§0.5) and is vote-ask-free (§0.4).
