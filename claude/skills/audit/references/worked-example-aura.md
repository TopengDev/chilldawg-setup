# Worked Example — the AURA v2 Deep Audit (2026-07-02)

**Load scope: MAIN SESSION ONLY.** This file is progressive-disclosure depth for the operator running `/audit` — it is NEVER loaded into lens/skeptic subagents (they get only `agents/*.md`). It condenses the one real deep run that shaped the current SKILL.md hard rules, so future runs reproduce the pattern instead of reinventing it.

Sources of truth (do not duplicate their full detail here):

- Memory: `project_aura_audit_2026_07_02` (~/.claude/memory/) — the canonical record incl. remediation.
- Memory: `feedback_fable5_dualuse_reroute_gate` — the model-reroute lesson.
- Report artifact: `/tmp/audit-report-aura-v2-20260702-064514.md` (tmpfs — may be gone after a reboot; this volatility is precisely why HR-11 now mandates the durable `~/claude/notes/audits/` path).

## The run in one paragraph

Target: `zerog-smoke` (AURA) @ `0ee06a6` == `origin/v2` — a Solidity/Foundry + Fastify + Ponder + Next.js 15 + Bun-CLI monorepo, audited for hackathon Top-16 submission readiness. 8 parallel max-effort lens agents (quality, security ×2, contract-correctness, dependencies, biz-logic, honesty/overclaim, a11y, performance) + adversarial verification + main's own re-verification of the load-bearing cluster. Outcome: **READY TO SUBMIT — CONDITIONAL on 2 honesty fixes**; 0 Critical / 0 High on security (two passes) and contracts; all must-fixes remediated and pushed within the day (M1–M3).

## Lesson 1 — the honesty lens was the highest-value catch

*Now: `agents/honesty.md` + HR-6 + the Phase 1.5 attach trigger.*

The run had to INVENT an honesty/overclaim lens; it found the only 2 submission-blocking findings:

1. **`/proof` iNFT re-key overclaim** (`web/src/app/proof/page.tsx:320`, `PROOF.md:54`)
   - Claimed: "Agents and Relics are iNFTs / transfer with a re-keyed brain."
   - Code: every live Aura sat on AgentRegistry, whose own source (`AgentRegistry.sol:135`) called its ERC-7857 path a `STUB ... falls back to a standard ERC721 transfer`; Relics were plain ERC-721.
   - One grep disproves the claim.
2. **"Deterministic fallback" false label** (`PROOF.md:37`, `proof/page.tsx:269`)
   - Claimed: the fallback is deterministic.
   - Code: `chat-llm.ts:152-158` — a `claude-haiku` call with NO temperature/seed.
   - One file-read disproves it.

Both sat on a page headed "if a claim cannot be verified right now, it is not on this page" — a jury-facing artifact where an overclaim is a named DQ vector ("misrepresenting what your app does"). Both were S-effort rewords, fixed before submission.

**Reproduce:** evaluate the Phase 1.5 claim-surface trigger on every run; attach `agents/honesty.md` when it fires.

## Lesson 2 — default-to-refuted produced CORRECT downgrades; the tripwire channel preserves the signal

*Now: HR-10 + the `tripwire:` field in `agents/verify.md`.*

The most consequential architecture findings — the **AuraINFT split-brain** (server create flips to the AuraINFT 9-arg sealed mint while `useMint.ts:151` hardcodes AgentRegistry + the 7-arg ABI, and all reads / the Ponder indexer / the memory ownerOf gate stay on AgentRegistry) and the related memory dual-wall — were **refuted-downgraded High→Medium, correctly**:

- The shipped web UI mints on AgentRegistry regardless, and the CLI had no create command.
- So no shipped client honored the flip → the catastrophic outcomes (invisible/colliding agents, cross-owner memory leak) did NOT fire end-to-end.
- The skeptic bias worked exactly as designed.

BUT the report had to hand-annotate "Latent, not active. Real as cutover tripwire." OUTSIDE the schema — because the moment the planned prod cutover moved create to AuraINFT, reads + indexer + memory-gate + web-mint all had to move together or create would break. That annotation became THE durable finding of the audit; it drove the M1 back-out decision (`auraINFT` blanked so `auraInftConfigured()` = false, real address parked behind an env re-enable for the post-cutover flip).

**Reproduce:** skeptics attach `tripwire:` on masked-but-real downgrades; aggregation records them in the Verification → Tripwires sub-list. The downgrade always stands; the arming condition always survives.

## Lesson 3 — the report asserted a FALSE resolved model

*Now: HR-1 + the Phase 2 model-resolution note.*

- The report header said `Lenses run (all on Fable 5, max effort)`.
- Factually false: Fable 5's upstream dual-use classifier silently rerouted the source-code security-audit fleet to Opus BEFORE the prompts reached the model — invisible in-session.
- Confirmed by Christopher (who watched the work get "redirected 5 times") and publicly corroborated.
- The audit's own header violated the audit's proof-over-claim ethos.

**Reproduce:** write only `requested: <model> — resolved model not observable in-session`; request Opus directly for security-heavy audits; defer to what Christopher observes.

## Lesson 4 — in-repo topology notes were verified-wrong

*Now: HR-3 + the HR-4 git ground-truth preflight.*

- `deployed-v2.json`'s `_note_auraINFT` and `WIRING-DECISION.md` both said the AuraINFT wiring was "NOT pushed to v2".
- FALSE — main had to disprove it by hand: `HEAD == origin/v2` with the wiring commits (fd17873/a889b99/693afc7/4837243) on it.
- Had the audit trusted the prose, the split-brain analysis (and the verdict) would have rested on a wrong premise about what code was actually on the audited ref.

**Reproduce:** the Phase-1 git preflight runs before any lens spawn; any topology claim without a git citation auto-downgrades to `theoretical`.

## Lesson 5 — model CVE knowledge missed advisories the native tool caught

*Now: HR-7 + the dependencies-agent tool requirement.*

- The deep dependencies pass (model knowledge + axios denylist) shipped a clean-looking deps bill.
- Days later `npm audit` surfaced **2 Critical (fast-jwt ≤6.2.3 via @fastify/jwt — on the AUTH path) + 2 High (ws)** — the memory's own words: "my audit predated the advisories".
- The denylist did its job (axios@1.14.1/0.30.4 confirmed absent) — but a denylist is not an advisory feed.

**Reproduce:** the dependencies agent runs the ecosystem's native read-only advisory tool as ground truth whenever present; unavailability goes in Coverage & Limits.

## Lesson 6 — the custom type + rubric overlay pattern

*Now: the "Custom lenses & rubric overlays" section + HR-9.*

Nothing in the 6-type taxonomy fit a contracts+server+indexer+web+CLI monorepo, and the user's real question was "ready to SUBMIT?", not a merchant tier. The run improvised well — and the improvisations are now the recipes:

- **Custom type:** the header declared `multi-subsystem web3 monorepo` honestly; the roster was assembled per-subsystem (contracts → security + a custom contract-correctness lens; server → backend-service-shaped lenses; web → web-app-shaped lenses).
- **Custom lens:** contract-correctness was written with the full lens anatomy — pattern checklist / schema with declared dimension / severity guidance / what-NOT-to-report — the 4 parts the Custom Lens recipe now mandates.
- **Rubric overlay:** the bespoke verdict anchored itself: `READY TO SUBMIT — CONDITIONAL ON THE HONESTY FIXES (Merchant-rubric equivalent: Pilot-ready — 0 Critical confirmed, 0 Critical probable, 8 High confirmed/probable)`. It never floated free of the quantified gates.

## Lesson 7 — verified-safe lists carried the positive half of the verdict

*Now: the `verified_safe` requirement in every lens + the Report Gate backing check.*

The "engine is genuinely strong" conclusion was believable ONLY because the lenses returned explicit verified-safe evidence:

- SIWE with single-use nonces; JWT fail-closed in prod.
- Fail-closed TEE mint gate (`generate.ts:236`).
- Pull-payment marketplace with reentrancy guards + CEI; the H-1 settlement-nonce binding.
- Escrow fulfill-XOR-refund invariants; royalty 9% / platform 2.5% verified live.
- Non-custodial signing paths; no secrets in the tree.

A findings-only report would have read uniformly negative and could not have supported "safe to lean on with the jury".

**Reproduce:** every lens returns `verified_safe` (≤8 items, file:line each); strength-asserting verdicts fail the Report Gate without positive evidence in their gating dimensions.

## Post-run epilogue (context for re-audits of AURA)

- Remediation shipped same-day: M1 (`0f4a353` — AuraINFT back-out + all honesty rewords + repo hygiene), M2 (`47b3a00` — demo-latency perf + biz-logic caps/sentinels), M3 (`23b8fda` — deps/supply-chain + quality + a11y). VPS stayed frozen throughout (source-only, zero deploy).
- Deferred at the time: gacha shared-package extraction; 3 contract-source Lows (need redeploy); the fast-jwt/ws advisory bumps (security-critical major auth bump — separate scoped task).
- Orchestration note: one worker hit API 529 mid-fleet; the recovery that worked was re-spawning ONLY the failed worker — now failure-mode playbook (c).
