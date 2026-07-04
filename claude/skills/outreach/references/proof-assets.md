# Proof-Asset + Identity Registry (canonical, for /outreach rule 4)

The proof-led rule (SKILL.md rule 4) demands a REAL proof-point cited with its EXACT link. This is the canonical registry the drafter cites. **NEVER invent a URL or a metric.** If the exact link or number is not here or in a `/case-study` output, do not assert it: verify or omit. Prime rules still apply (no long dash §0.1, no emoji §0.2).

Sources: `user_christopher`, `project_income_diversification_2026`, `~/claude/notes/initiatives/dev-job-outreach.md`, `reference_christopher_cv`. Treat those as the live source of truth if this file drifts.

---

## Identity links (cite these verbatim, do not paraphrase a URL)

| Asset | Exact link / value | Use in outreach |
|---|---|---|
| **LinkedIn** | `https://www.linkedin.com/in/christopher-indrawan-dev` | The default professional handle; the channel + the proof surface for recruiters. |
| **GitHub** | `https://github.com/TopengDev` | Code proof; link a specific repo when the role is code-heavy. |
| **Portfolio** | `topengdev.com` | The hub; leads to case studies + live products. |
| **Cerebral Valley** | `https://cerebralvalley.ai/u/chilldawg` | AI/hackathon community profile; use for AI-role or hackathon-adjacent leads. |
| **Anthropic org UUID** | `c3f820e1-b573-4f7e-a06b-06e980cb829a` | ONLY for hackathon/partner forms that ask for an org ID; not an outreach line. |
| **Discord** | `chilldawg88` | Rarely an outreach channel; note only if a lead lives on Discord. |
| **Emails** | `$TOPER_EMAIL` (personal), `topengdev@outlook.com` (alt/signups) | The reply-to a recruiter would use; the send mechanics are in `channel-send-playbooks.md` (no autonomous as-Christopher send). |

Public handle for personal-brand builds: "Chill Dawg". Full name on LinkedIn: "Christopher Indrawan". Location: Jakarta, Indonesia (WIB).

---

## Live products (the strongest proof: working software the target can open)

| Product | Live URL | What it proves |
|---|---|---|
| **Pulse POS** | `coba-pulse.topengdev.com` | Multi-tenant, offline-first POS SaaS with paying Indo SMB customers, native hardware. The anchor proof for retail / POS / SMB-tech / multi-tenant-SaaS roles. |
| **AURA** | `aura.topengdev.com` | AI product (0G build sprint). Proof for AI / agent / infra roles. |
| **Aenoxa** | `aenoxa.com` | The company/org site; the umbrella brand. |

Non-URL proof assets (link the repo or the case study, cite results only if measured):
- **signal-trader**: live algotrading bot (real trades, WhatsApp notifications). Infra + reliability proof.
- **fitest**: 300+ test suites, framework-bug diagnosis. QA / SDET / testing proof.
- **Multi-agent AI-orchestration**: the plan -> prototype -> spawn -> verify -> ship workflow (this very toolchain). Proof for AI-tooling / senior-eng / "works with agents" roles.

---

## CV (resolve dynamically, NEVER hardcode)

- **Directory**: `~/Dropbox/Documents/Christopher/cv/` (Dropbox is synced locally).
- **Resolve rule** (mirrors `/case-study` CV rule): `ls -t ~/Dropbox/Documents/Christopher/cv/ | grep -i resume | head -1` and take that newest `Resume*.pdf` by mtime. As of 2026-07-02 that is `Resume-2026-updated.pdf`; the older `Resume 2026.pdf` also survives in the dir. The file gets renamed on updates, so a hardcoded filename goes stale (searching "Resume 2025.pdf" already fails). Always `ls -t`.
- **NEVER source a CV from `~/Downloads`**: it holds OTHER people's CVs (candidate/test files) + hiremeup `analysis_*` outputs, none of which are his.
- It is the Senior / Full-Stack Developer resume (React/Next.js focus; fintech/edutech/AI).

---

## Positioning (the honest self-inventory the fit-hook draws from)

The rare-combo one-liner (`project_income_diversification_2026`): **premium bilingual (ID + EN) fullstack + native mobile + infra + AI**. This combination is scarce in the Indo market and is the strategic differentiator. Freelance engineering is the ANCHOR income path (survival floor before the BRI contract ends Nov 2026); Pulse tenant revenue is the upside.

Stack breadth (claim only what maps honestly to the target, §2c): Next.js / Go / Rust / Kotlin / gRPC / Postgres; self-hosted infra (VPS + Docker + nginx + Cloudflare + certbot); AI integrations + multi-agent orchestration; native mobile.

Workflow signature (a proof-point in itself for senior/AI roles): **plan -> prototype -> spawn -> verify -> ship**, an agent-orchestrated delivery pipeline.

The strategic frame + the refined Laurel-pitch template and its critique lessons (hook-first, proof-with-metrics, tailored, concise, clear CTA + link, consistent register) live in `~/claude/notes/initiatives/dev-job-outreach.md`. Reuse that pitch as the template; apply its critique lessons.

---

## Proof-to-target map (which asset leads for which target)

| Target type / emphasis | Lead proof-point | Link |
|---|---|---|
| Retail / POS / SMB-tech / multi-tenant SaaS | Pulse POS | `coba-pulse.topengdev.com` |
| QA / testing / SDET | fitest (300+ suites, framework-bug diagnosis) | the repo / a `/case-study` |
| Frontend / design-quality | a polished shipped UI (portfolio, a oneshot build) | `topengdev.com` |
| Infra / fullstack / reliability | self-hosted stack + signal-trader (live algotrading) | the repo / a `/case-study` |
| AI / agents / LLM tooling | AURA + the multi-agent orchestration workflow | `aura.topengdev.com` |
| Indo-market / bilingual product | Pulse (Indo SMB customers) + the bilingual positioning | `coba-pulse.topengdev.com` |

If no `/case-study` exists for the best-fit proof, suggest running `/case-study <project> --for application --role <role>` first; it emits a ready strict-voice cover blurb at `~/claude/notes/applications/<company-or-role>-<slug>.md` that the outreach leads with.

---

## Honesty guardrails (no-yesman applied to selling, §2c)

- Cite only proof that is REAL and that maps to THIS target. A POS story for a retail-tech client; the QA story for an SDET role. Not a generic "check my portfolio".
- NEVER invent a metric. If a result was not measured, do not put a number on it. "Live in production with paying customers" is true and strong; "increased conversion 40%" is a detonation risk if unmeasured (a sharp interviewer probes it).
- If the fit is partial, lead with the real overlap and be straight about the gap. If the target is a genuinely bad fit, flag it to Christopher rather than manufacture enthusiasm.
- Keep everything public-safe: no secrets, no internal infra, no private client identities in an outreach message.
