# Worked example: market-events-calendar (the only verified end-to-end /ideate proof)

This is the real flow that `/ideate` reproduces, run by hand in June 2026 before this skill existed. Every phase below actually happened. Source of record: `~/claude/notes/initiatives/market-events-calendar.md` + `~/claude/notes/initiatives/market-events-calendar-plan.md`. Cite this when you need to show a reader what "good" looks like at each phase; do not invent variations.

Outcome shipped: a standalone market-events system that maintains a calendar of scheduled market-moving events (macro + crypto-native), renders an interactive TUI, sends WhatsApp reminders + post-event analysis, and persists everything as an ML-ready dataset for a future algo-trading bot. Status today: BUILD COMPLETE + AUDITED + HARDENED, all 4 phases live on the VPS, in OPERATE/OBSERVE mode.

---

## Phase 0: Triage -> L3

The idea was a new standalone system, deployed to the VPS (shared infra), touching the load-bearing wa-sender queue, multi-day, and the seed of a future trading dataset. Multiple L3 triggers: new standalone repo, touches existing infra, multi-milestone, high-stakes data. Classified **L3** and the full gate ran. (Had this been mis-triaged L2, the sign-off + prototype gates would have been skipped and the wa-sender non-disturbance invariant might not have been surfaced up front.)

---

## Phase 1: Discovery (12 questions across all 7 dimensions)

The `>=10`-question floor was cleared with **12** clarifying questions, and Toper's answers locked 12 scoping decisions on 2026-06-12:

1. Runs on the VPS (explicit deployment authorization). 2. SQLite. 3. Default asset basket (BTC, ETH, OKX alts, DXY, ES, NQ, gold, oil, US10Y). 4. Default 4-message WA cadence for tier-1 events. 5. Tiering yes (tier-1 = FOMC/CPI/NFP/big unlocks/SEC rulings; the rest calendar-only). 6. Full interactive TUI (not grid-print). 7. Free sources only. 8. LLM narrative OK (Sonnet via the Anthropic key). 9. WIB display. 10. Backfill in v1. 11. Fully standalone first (NO signal-trader coupling yet; the blackout filter is a fast-follow needing separate authorization). 12. Listings monitoring in v1 (a Toper override that widened scope).

Dimension coverage was complete: value prop (an ML-ready event-outcome dataset), users (Toper + a future bot), flows + failure states (event capture -> actual -> surprise z -> narrative -> WA, with health alerts on source drift), business model (n/a, internal tool), constraints (VPS, free sources, WIB, do-not-disturb signal-trader), competitive landscape (paid calendars like TradingEconomics vs free FF/BLS), and the **riskiest assumption** (below). The docs written: `01-vision`, `02-validation` (GO), `03-scope` (the P1-P4 phase roadmap), `04-architecture` (one VPS service + a tiny local relay + a textual TUI over ssh).

The core design decision recorded in the decisions log: **dataset-first**. The calendar, TUI, and WA are views over an event-outcome DB; every event is a labeled training example (event type, surprise) -> (instant reaction, whipsaw?, durable direction).

---

## Phase 2: Prototype-First gate (a dedicated recon worker, PASS with reshaping findings)

The riskiest assumptions were about the **free data sources**: would they return the fields needed, from the VPS IP, without geoblocks, and could the wa-sender queue be reused safely. This was real work, so it was delegated to a **dedicated recon worker** (`market-events-prototype-2026-06-12`, its own task dir, `triage.json` `level:L2`, STATE.md + brief), which wrote a `report.md` + `result.json` with a verdict table. Every source was tested from BOTH the local box and the VPS.

The recon PASSED overall but returned findings that **reshaped the plan** (this is the whole point of prototyping before planning):

- **Kominfo DNS-poisons Binance/Upbit/Coinbase/Deribit on BOTH boxes** (not OKX). A DoH + pinned-IP bypass was verified 200 on all four, so the bypass was baked into those fetchers from the start rather than discovered mid-build.
- **TradFi free intraday history is depth-limited** (1m = 8d, 5m = 60d, 1h = 730d, 1d = max), so 1m TradFi reactions are only collectable FORWARD; backfill runs at 1h/1d. Crypto 1m goes back to 2017 via Binance vision dumps.
- **No free feed carries macro actuals** (FF never fills them; the TradingEconomics guest endpoint is dead, 410). Actuals come from the BLS API (works from the VPS, 20y backfill), and consensus must be self-archived from FF weekly, so archiving had to start day 1 (time-sensitive).
- **Cloudflare 403s the VPS on exactly Farside + the DefiLlama unlocks page** (both fine locally). Solution: a local-fetch -> VPS relay for those two sources only.
- **Yahoo needs curl_cffi chrome impersonation** (TLS-fingerprint block on both networks). CNBC restQuote is the plain-curl live-quote workhorse from the VPS.
- **WA reuse path validated:** append JSONL `{"to","message"}` to the wa-sender queue (append-only contract, never truncate), but this needs Toper's OK as the one touchpoint with existing infra.
- textual 8.2.7 headless Pilot test PASSED (SVG evidence); Stooq is dead; the DefiLlama unlocks API is now paid (402), but the page `__NEXT_DATA__` still carries 332 protocols with %supply + historical events.

Every one of these became a planning input. A plan written without this recon would have assumed reachable sources and a working Yahoo, and would have been wrong on at least four counts.

---

## Phase 3: Plan + sign-off (presented, then explicit approval with 4 decisions)

The plan (`market-events-calendar-plan.md`) turned the scope + recon findings into **four sequential, verify-gated milestones** (P1-P4), each independently shippable, each with an evidence-based GATE, none starting until the previous gate passed. The plan cited the recon findings directly (DoH bypass, relay for the 2 blocked sources, curl_cffi for Yahoo, archive-from-day-1).

The plan was PRESENTED, and Toper signed off "approved" on 2026-06-12 with **four decisions** recorded in the initiative decisions log:
1. Reuse the wa-sender queue (append-only JSONL, its designed interface).
2. systemd `--user` units on the VPS (new units only, touches nothing existing).
3. curl_cffi proceeds on the VPS (inside the project venv only).
4. The local relay (a systemd timer pushing 2 small JSON files/day to the VPS `incoming/`).

Only after those words did `signoff` flip to `true`. The L3 sign-off gate closed with all 5 boxes `[x]`.

---

## Phase 4 + 5: Emit artifacts + delegate the fleet (P1 -> P2 -> P3 -> P4, serial)

The initiative file, the plan file, and four per-milestone task dirs were created, each with its own `triage.json` + `STATE.md` + `brief.md`. The four build milestones were then delegated as **spawned background workers, serially**, because each built on the last (the dependency graph was a chain, not a fan-out). One phase's verification gate had to PASS before the next worker was spawned.

- **P1 (foundation + stop-losing-data, task #230):** repo/venv/schema/config + systemd units; FF fetcher + weekly raw archive; Fed FOMC fetcher; BLS actuals grabber; snapshotter (OKX + CNBC); tier-1 T-30m WA reminder. GATE 6/6 PASS: next-week events in the DB with consensus, a snapshot fired on a real event, a WA reminder landed on Toper's phone, `systemctl --user status` clean, and the signal-trader non-disturbance invariant held (the WA queue file is `market-events.jsonl`, a SEPARATE file from signal-trader's own `events.jsonl`, both code-verified single-file consumers).
- **P2 (outcomes + analysis, task #231):** surprise z (causal population-vs-sample stdev with honest NULLs), reactions + whipsaw computation, Sonnet narratives (raw HTTP, ~$0.005 each, deterministic fallback, key in the VPS `.env` chmod 600), full 4-message cadence, health alerts. GATE 6/6.
- **P3 (crypto-native, task #232):** the local relay (Farside + DefiLlama), unlock events with %supply, Deribit expiry + max-pain, ETF flow dailies, listings pollers with DoH bypass. GATE 8/8. **P3 survived a mid-checkpoint session-limit death and resumed cleanly** (see below).
- **P4 (backfill + TUI, task #233, FINAL):** 20y BLS backfill, FOMC archive, Binance 1m dumps, Yahoo 1h/1d via curl_cffi, DefiLlama historical unlocks, retroactive reaction labels, the textual TUI + a local `events` ssh wrapper. **P4 also survived a weekly-limit death and resumed cleanly.**

### The resume-after-death proof (why STATE.md checkpoints matter)

Both P3 and P4 hit a session limit mid-milestone and died. Neither redid its work. Each was resumed from its last verified `STATE.md` checkpoint via the RESUME preamble, trusting the `[x]` checkpoints, re-verifying the last one cheaply, and continuing from the first `[ ]`. This is the model, not an exception: a build worker that dies is expected to resume, and the checkpoint journal makes that safe.

One failure mode worth remembering surfaced here: a worker's internal background-wait once fabricated future-dated output. The fix was foreground verification (a real snapshotter wake was watched live) rather than trusting the worker's self-report. Verify with evidence, never claims.

---

## Phase 6: /audit (data system) and Phase 7: ship + operate

The build was audited on 2026-06-15. (Historically the run used the older multi-lens roster: biz-logic/security/perf/quality/deps. For a data system like this one TODAY, `/audit` auto-selects the **data-pipeline** roster, core-3 = data-integrity, reliability, security, which is the right lens set for a dataset-is-the-product system.) Verdict: 0 Critical, 0 data-loss; pilot-ready live, not-yet-ready for real-money algo training until the data-integrity fixes landed.

Four data-integrity blockers were fed back as **delegated fix tasks** (#234 fix + #235 deploy, commit `06d7ba7`), then re-verified:
1. Surprise z used population stdev where sample was correct (was inflating z ~2x at small n; the live analyze timer self-corrects stored z as the archive deepens).
2. OKX fetch went concurrent with an enforced 15s budget (was up to 60s sequential, risking a miss of the 90s T0 window), including the ThreadPoolExecutor `__exit__` join footgun.
3. Snapshotter capture-cycle annotation + a new `test_snapshotter.py` (14 tests).
4. The notifier commits its ledger BEFORE the WA enqueue (the crash window flipped to a safe recorded-but-unsent state).

Deploy verified: 9 units green, cadence intact (0 spurious sends), signal-trader byte-identical (sha256 match), snapshotter live on the concurrent OKX path. Tests grew 98 -> 123.

The initiative moved to **OPERATE/OBSERVE** mode rather than being closed, with live watch items (the first real tier-1 events: Vana unlock, Spark, FOMC). The ML success criterion is LIVE: per-event-type whipsaw stats from real data (NFP 37.6% whipsaw / CPI 25% / FOMC 27%), which measured the brief's "the first instant candle is often a fakeout" thesis rather than leaving it anecdotal.

---

## What this example teaches each phase

- **Triage:** a new standalone system touching shared infra is L3 by default; the round-up saved the wa-sender invariant.
- **Discovery:** 12 questions, all 7 dimensions, a named riskiest assumption. Dataset-first was a decision, not an accident.
- **Prototype:** a dedicated recon worker with a verdict table found 4+ constraints (geoblocks, history-depth limits, missing macro actuals, Cloudflare 403s) that reshaped the plan BEFORE a line of build code.
- **Plan + sign-off:** the plan cited the recon; sign-off carried 4 concrete infra decisions; `signoff` flipped only on the word "approved".
- **Delegate:** 4 serial verify-gated workers; each gate PASSED before the next spawned; 2 of 4 died and resumed cleanly from STATE.md.
- **Audit:** blockers became delegated fix tasks, re-verified, never shipped on an open Critical.
- **Ship + operate:** evidence-gated deploy (sha256 non-disturbance proof), then OPERATE mode with live watch items.
