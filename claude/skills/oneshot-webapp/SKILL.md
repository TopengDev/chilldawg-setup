---
name: oneshot-webapp
description: One-shot a pitch-grade web app or landing page from a brief and deploy it live to a <slug>.topengdev.com subdomain. Next.js + Tailwind + shadcn, designed via /frontend-design SAFE preset (Japanese Minimal, Warm Craft, Editorial Luxury, Soft Structuralism), light-only, no dark, then docker + nginx + certbot on the VPS. Use when Toper says /oneshot-webapp, asks to build+deploy a pitch demo / recruiter demo / topengdev site, or main handles a build request from Laurel (Bithour recruiter). A UserPromptSubmit hook auto-injects the non-negotiables on invocation.
argument-hint: <brief - what to build, who it's for, any market/language/feature requirements>
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, WebFetch
---

# /oneshot-webapp - brief -> pitch-grade web app -> live subdomain

Take a brief and, in a SINGLE session, produce a polished, real-feeling web app or landing page and
deploy it live at `https://<slug>.topengdev.com`. This codifies the proven Selaras / `bithour-ops-pm`
/ Alamanda builds (2026-05-29). The output must look like a real product a paying client would ship,
NOT a generic AI scaffold. This is a **load-bearing** skill: it runs Toper's live recruiter/pitch
demos (Bithour interviews, Laurel build-on-demand), so a botched build is a botched first impression.

Progressive disclosure: this file is the whole procedure + the gates. Encyclopedic depth lives in
`references/` (deploy mechanics, failure playbooks, the LLM recipe). Read a reference only when a step
needs it. All prose here is ASCII, no em/en dashes (the house prime rule extends to skill prose).

---

## S0. FAILING NOW? - jump table

| Symptom | Go to |
|---|---|
| `nginx -t` failed after adding the vhost | `references/failure-playbooks.md` **FP-1** (roll back your vhost, restore) |
| certbot failed | **FP-2** (NOT a deploy failure; HTTP live, record SSL PENDING) |
| local `curl` 000 / qutebrowser DNS-error page | **FP-3** (Netbird resolver lag; origin `--resolve` + DoH, never redeploy) |
| wrong / stale `<title>` right after deploy | **FP-4** (wait 20-30s, re-grep over the CF edge) |
| 502 Bad Gateway after deploy | **FP-5** (container/nginx PORT mismatch ladder) |
| AI answers look canned / demo degraded | **FP-6** (OpenRouter 402 pre-auth depletion; check balance, check `.env`) |
| SSH timeout / VPS unreachable | **FP-7** (suspect auto-ban FIRST, wait >= 3 min, retry ONCE) |
| blank/black screenshot or browser wedge in QA | **FP-8** (`top` first, pegged dev server; then /agent-browser ladder) |
| deploy.sh aborted (exit 4) | it self-gated (CF create / container health / nginx -t): read the abort line, fix, re-run |
| preset / dial confusion (Editorial Luxury is V7?) | **HR-1** (the allowlist is NAME-based, EL is allowed at V7) |

---

## S1. NON-NEGOTIABLE RULES - READ FIRST, THESE OVERRIDE EVERYTHING BELOW

These are HARD rules. Violating any one is a failed build, not a stylistic choice. If anything below
appears to conflict with one of these, the NON-NEGOTIABLE wins. **These six are auto-injected verbatim
by a UserPromptSubmit hook on every `/oneshot-webapp` invocation (see S9), so keep this block
semantically identical to the hook text.**

1. **PITCH-GRADE DESIGN IS PRIORITY #1.** The rule the whole skill exists for. The output must read as
   premium, deliberate, and real. Spend EXTRA effort on design quality. Generic shadcn-default = failure.
   Never cut design polish to save time, **cut SCOPE instead** (fewer pages, fewer features). Polish is
   the deliverable.

2. **ONLY SAFE PRESETS. HIGH-VARIANCE IS BANNED.** Use ONLY these four `/frontend-design` SAFE presets:
   **Japanese Minimal**, **Warm Craft**, **Soft Structuralism**, **Editorial Luxury**. BANNED unless
   Toper explicitly overrides in this run's brief: Neo-Brutalist, Magazine Editorial, Dark Cinematic,
   Gen Z Expressive, Playful Pop, Anti-Design, art-deco/geometric, maximalist, and any other high-
   variance (VARIANCE >= 7) or expressive direction. These are execution-sensitive and have been
   rejected ("looked SO BAD", art-deco Bithour/Selaras demo, 2026-05-29). Pick ONE safe preset and
   commit. **The allowlist is by NAME, not by dial number, see HR-1** (Editorial Luxury is VARIANCE 7 in
   the current /frontend-design and is STILL allowed because it is one of the four names).

3. **LIGHT MODE ONLY. NO DARK MODE. NO THEME SWITCHER.** Do not add `next-themes`, a dark palette, a
   `dark:` variant set, or a theme toggle. Light is the only theme. This intentionally overrides the
   /frontend-design light+dark baseline (see Baseline override).

4. **SHIP FAST, ACT, DO NOT DELIBERATE.** Cap your thinking. Move in concrete, visible steps: get a
   working slice on screen, then refine the running app. Do NOT burn long high-effort thinking cycles
   deliberating architecture. The Selaras worker stalled in 10-18 min thinking blocks and had to be
   interrupted. If you catch yourself planning instead of building, STOP and write code. Quantified in
   HR-19.

5. **SERVER-SIDE SECRETS ONLY + MANDATORY DETERMINISTIC LLM FALLBACK.** If the demo uses an LLM/API:
   the key lives in container env (`~/apps/<slug>/.env`, chmod 600), never client-side, never
   `NEXT_PUBLIC_`, never baked into the image. The model is called server-side only (route handler /
   server action). And you MUST ship a deterministic fallback for the exact demo scenario so the live
   demo NEVER breaks if the API fails / runs out of credit / times out. Recipe: `references/llm-demo-recipe.md`.

6. **DEPLOY TO `<slug>.topengdev.com`.** Final live URL is always `https://<slug>.topengdev.com` (a
   clean, short, hyphenated slug). Not aenoxa.com, not a raw IP, not localhost. Per-subdomain Cloudflare
   A record (no `*.topengdev.com` wildcard), HTTPS via certbot behind nginx + Cloudflare.

> If the brief breaks one of these (e.g. "make it dark mode", "use a bold brutalist look"), do NOT
> silently comply. Either it is Toper explicitly overriding (rules 2/3 allow an explicit Toper override,
> honor it and LOG it in the report), or flag the conflict. Default = obey the non-negotiables.

### Baseline override (you are intentionally departing from /frontend-design defaults)

`/frontend-design` MANDATES an i18n + light/dark baseline for Aenoxa-ecosystem sites. **This skill
overrides that** for one-shot pitch demos, on Toper's explicit standing directive: **light mode only,
no dark, no switcher** (NR 3), and **single locale** in the brief's language (no next-intl unless the
brief needs 2+ languages). This override is deliberate, not an oversight. **Note it explicitly in every
report** (as the Selaras build did). Softening it re-opens the failure class in reverse.

---

## S2. Boundaries - who owns what (cite, never duplicate)

| Skill | Relationship to oneshot | Hard boundary |
|---|---|---|
| **/frontend-design** | Drives the design in Phase 2 (SAFE preset, light-only). oneshot is its documented ship-fast exception. | Its §5.5 yield clause relaxes the signature-3D-moment + motion-DEPTH for oneshot, but the UNIVERSAL floors still apply with NO exception (HR-2/3/4): §0.4 no-dash rendered copy, §0.6 weight >= 500 + size >= 12px, mono Terminal-only, serif banned for dashboard UIs, §5.5 Tier 1 motion FLOOR. Its i18n + dark baseline is the ONE thing oneshot overrides. |
| **/artifex** | The high-variance immersive sibling. Its N0 hard-bans itself from oneshot territory. | NEVER reach for /artifex on a oneshot brief without a VERBATIM Toper override ("go immersive", "award-caliber", or naming `/artifex`). "Make it impressive for the recruiter" is NOT an override (HR-5). Named failure: 2026-05-29 Selaras art-deco. If overridden, /artifex still honors oneshot's light-only + server-side-secrets + deploy rules. |
| **/deploy-landing** | Sibling deploy skill for ALREADY-BUILT Next.js landings to `*-landing-page.aenoxa.com` (tar-over-ssh + nginx + certbot, pm2 STOP-gated). It CITES oneshot's `deploy.sh` as its proven docker lineage. | Different domain + stack. oneshot owns `<slug>.topengdev.com` pitch demos (docker) end to end; never route a topengdev demo through /deploy-landing, never route an aenoxa landing through here. |
| **/cloudflare-dns** | The canonical multi-zone DNS authority (aenoxa.com + topengdev.com, same zone id, VERIFIED writable). It BLESSES deploy.sh's single automated proxied create (its S3). | deploy.sh owns the ONE automated idempotent create. EVERY manual DNS op (verify / repair / delete / audit / propagation check) routes to /cloudflare-dns and its gates (HR-14). Never hand-roll CF API calls for manual work here. |
| **/agent-browser** | The ONLY sanctioned browser path for all screenshot/QA evidence. | ALL browser evidence goes through it (HR-16): never Playwright MCP (hook-banned), never `tab new` as primary (exit 144, use `/claim?url=`), qb-shoot ladder for blank shots, DPR trim only on `--full`, `top` first if it wedges, never kill the live browser. |
| **/next-best-practices** | Framework mechanics reference (dual-gated 15.x/16.x). | Consult it for App Router conventions/route-handlers/caching instead of training data; let the real `next build` compiler be the source of truth (HR + Phase 1). |
| **/ship** | Git push + CI pipeline. | oneshot NEVER routes deploy through /ship (that is git+CI only). oneshot SSHes to the VPS; /ship never does. Commit only via the /commit skill if Toper asks. |

---

## S3. HARD RULES (HR-1 .. HR-19)

The enforcement layer beneath the six NRs. Each is a NEVER/ALWAYS with a concrete trigger.

- **HR-1 (name-based allowlist).** ALWAYS treat the SAFE preset allowlist as NAME-based: Japanese
  Minimal / Warm Craft / Soft Structuralism / Editorial Luxury are allowed regardless of their current
  /frontend-design dial numbers. Editorial Luxury is VARIANCE 7 today and is STILL allowed. The
  `VARIANCE >= 7 BANNED` phrasing applies to every direction NOT on the four-name list. NEVER admit any
  other archetype (including Technical Editorial, VARIANCE 5) without Toper's explicit brief-level
  approval, a low variance number does NOT qualify a non-listed archetype.

- **HR-2 (no dashes in rendered copy).** NEVER render an em dash or en dash in ANY copy the demo ships:
  headlines, subheads, microcopy, CTAs, errors, empty/loading states, seed data, 404, tooltips, labels.
  /frontend-design §0.4 applies on oneshot with NO exception. GATE 2 greps the two glyphs across
  `app/ components/ lib/ data/ messages/` and requires ZERO hits.

- **HR-3 (typography floors).** NEVER ship rendered text below font-weight 500 or below 12px.
  `font-thin` / `font-extralight` / `font-light` / `font-normal` are FORBIDDEN classes; `text-[10px]` /
  `text-[11px]` are FORBIDDEN sizes. Airiness comes from size, spacing, and color, never a frail weight
  (/frontend-design §0.6). GATE 2 greps for these.

- **HR-4 (mono + serif discipline).** NEVER use a monospace face outside a literal terminal/console/
  code-block component; NEVER as labels/eyebrows/metadata (none of the four safe presets is a mono
  archetype). NEVER a serif headline on a dashboard/software-UI demo (serif is for landing/editorial
  vibes only). The "technical" feel comes from tracked-uppercase small-caps sans + tabular figures, not
  a code face (/frontend-design DD-1, line 598).

- **HR-5 (artifex boundary).** NEVER invoke /artifex on a oneshot brief without a VERBATIM override:
  "go immersive", "award-caliber", or Toper naming `/artifex`. "Make it impressive for the recruiter"
  is NOT an override (mirrors artifex N0; named failure 2026-05-29 Selaras art-deco).

- **HR-6 (secret hygiene).** NEVER print or log `$VPS_PASSWORD`, `$CLOUDFLARE_API_TOKEN`, or `$VPS_HOST`
  (the origin IP is a secret; the orange cloud exists to hide it). ALWAYS `sshpass -e` with `SSHPASS`
  exported, never `sshpass -p` (argv is visible in `ps`). NEVER `set -x` around any command that
  composes the password.

- **HR-7 (non-interactive sudo).** NEVER run plain `sudo` over non-interactive SSH (fails "a terminal is
  required"). ALWAYS the rsudo pattern: `echo "$VPS_PASSWORD" | sudo -S -p '' <cmd>`. NEVER
  `sudo tee <<heredoc` (stdin clash with `sudo -S`); ALWAYS scp to `/tmp` then `rsudo cp`.

- **HR-8 (no rsync on the VPS).** NEVER rsync to the VPS (no rsync on the box, verified 2026-05-29 +
  re-confirmed 2026-07-03). ALWAYS tar-over-ssh with the exclude set `node_modules .next .git data .env
  .env.local`. deploy.sh does this automatically.

- **HR-9 (nginx reload discipline).** NEVER reload nginx except as the single chain
  `nginx -t && nginx -s reload`. On `nginx -t` failure ALWAYS remove your vhost + symlink and reload to
  restore, never leave nginx broken (FP-1).

- **HR-10 (env preservation on re-deploy).** NEVER let a re-deploy destroy the remote
  `~/apps/<slug>/.env`. The re-run either re-uploads `--env` or preserves the existing `.env` across the
  source wipe. A missing env on an AI demo silently degrades it to permanent fallback mode (FP-6).
  deploy.sh preserves it now; if you deploy by hand, preserve it too.

- **HR-11 (bounded docker logs).** NEVER stream `docker logs` / `docker events` through timeout-wrapped
  or backgrounded SSH (orphaned streams peg dockerd ~1 core EACH, verified 2026-06-02/15/19; the local
  hook `block-docker-logs-over-ssh.sh` backstops this). Bounded foreground `docker logs --tail 50
  --since 10m` only, then sweep leaked streams with `ps -eo pid,etime,args | grep 'docker logs'`.

- **HR-12 (gentle connect).** ALWAYS connect gently: `ConnectTimeout=12`, ONE retry after >= 3 minutes
  on timeout, NEVER port-scan or ping-flood the VPS (aggressive probing triggers a temporary auto-ban,
  verified 2026-05-30; FP-7).

- **HR-13 (resolver-lag truth order).** NEVER interpret a local `000` / DNS-error / qutebrowser DNS page
  as a deploy failure (the Netbird resolver `100.64.0.2` lags public DNS by minutes; the browser
  uses the same resolver). Truth order: origin `curl --resolve` > public DoH > (never) local resolver.
  NEVER use `dig`/`host`/`nslookup` (not installed on this box). FP-3.

- **HR-14 (DNS ownership split).** NEVER hand-roll Cloudflare API calls for manual DNS work
  (verify/repair/delete/audit): `/cloudflare-dns` owns that path with its gates. deploy.sh owns the ONE
  automated idempotent create (proxied:true, class A per /cloudflare-dns S3, which explicitly blesses
  it). NEVER create a wildcard record.

- **HR-15 (LLM fallback + 402).** If the demo uses an LLM: ALWAYS wire the deterministic fallback to
  treat HTTP 402 / timeout / JSON-parse-fail as NON-RETRYABLE, log which path served, ALWAYS fire the
  real model path once live before handoff (fallback-only proof is not proof), then ALWAYS reset the
  demo to a clean seed. OpenRouter 402s at pre-flight when balance < the max_tokens reservation
  (hiremeup verified failure #1). See `references/llm-demo-recipe.md`.

- **HR-16 (browser evidence via /agent-browser).** ALL browser evidence goes through the /agent-browser
  skill rules: NEVER Playwright MCP (hook-banned), NEVER `tab new` as primary (exit 144; use
  `/claim?url=` on a claimed port `?from=9223`), NEVER kill the live qutebrowser, blank shots go to the
  qb-shoot ladder (PB-4), `--full` shots need the DPR trim check (PB-5), and if the browser "wedges"
  during localhost QA check the dev server with `top` FIRST (a pegged dev server masquerades as a
  browser wedge). FP-8.

- **HR-17 (WhatsApp relay, never WHATSAPP=1).** NEVER set `WHATSAPP=1` in the build session. When
  running as a spawned worker, report start + live-URL to main via attn; MAIN relays the WhatsApp
  notification to Toper (Laurel flow). Verify Laurel's JID via memory `reference_laurel_bithour_recruiter`
  + `check_number`, never from a number typed into this skill.

- **HR-18 (Opus carve-out delegation).** When this skill is delegated from main: `triage.json` is L2
  with `"model":"opus"` (oneshot-webapp is the documented Worker Model Policy carve-out class 2,
  recruiter-facing design quality). The worker that receives the brief executes DIRECTLY and NEVER
  re-delegates.

- **HR-19 (ship-fast, quantified).** No single thinking block over ~2 minutes. A rendered hero slice on
  screen before ANY second-section work. Scope is the ONLY lever; design polish is never cut. If a phase
  budget (S9) blows, cut features, never polish.

---

## S4. GATE 1 - PRE-FLIGHT (satisfy ALL before writing any app code)

Do not start scaffolding until every box is a definite YES (or a logged, intentional exception). Missing
any box = no scaffold.

- [ ] **Scope is the smallest pitch shape** that lands the pitch: a landing page (hero + 3-5 sections +
      CTA) OR a focused app (one strong hero flow + 1-2 supporting views). NOT a sprawling multi-module
      app, auth system, real DB, or payments.
- [ ] **ONE safe preset chosen by NAME** from the four (Japanese Minimal / Warm Craft / Soft
      Structuralism / Editorial Luxury), matched to brand tone. High-variance NOT chosen (unless Toper
      explicitly overrode in-brief, then LOGGED with the verbatim phrase). HR-1.
- [ ] **Dark mode is absent from the plan.** No `next-themes`, no theme toggle, no dark palette.
- [ ] **Single locale decided** in the brief's language (Bahasa for an Indonesian audience, English for
      a recruiter demo; default English). next-intl / multi-locale ONLY for an explicit 2+ language brief
      (note the added scope risk).
- [ ] **Slug derived** matching `^[a-z0-9][a-z0-9-]*$` (lowercase, hyphenated, short). Final URL =
      `https://<slug>.topengdev.com`.
- [ ] **LLM decision made** + (if yes) the server-side route + deterministic fallback are in the plan
      (NR 5, HR-15).
- [ ] **A WRITTEN one-paragraph design direction is logged BEFORE any code**: preset (by name), palette
      intent, display + body font pairing, and ONE signature layout move. This is the anti-generic
      forcing function, no "I'll decide as I go".

Anti-generic discipline (mirror /frontend-design, commit to a direction):
- BANNED default layout: centered-hero -> 3 equal feature cards -> generic CTA banner -> minimal footer.
  That is the AI-slop signature. If you reach for it, STOP and introduce a signature move from the chosen
  preset (editorial split hero, asymmetric bento, offset section, typographic statement, a real product
  mock/screenshot region).
- Typography: a DISTINCTIVE display + body pairing. NEVER plain Inter/Roboto/Arial as the headline face.
  Serif is banned for dashboard/software UIs (HR-4).
- Color: ONE cohesive intentional palette with a real accent, NOT gray-on-gray, NOT default shadcn
  slate. Tokens as CSS variables in `globals.css` (`--bg --fg --accent --surface --border ...`). Never
  hardcode colors in components.
- Commit, do not hedge. A timid blend of three directions reads as generic; under-committing is the #1
  way a build looks AI-made.

---

## S5. Workflow - Phases 0 to 3 (build), then GATE 2 -> deploy -> GATE 3

### Phase 0 - Scope tight (<= 5 min, no deliberation)

Pick the SMALLEST shape that still lands the pitch (GATE 1). A reliable one-shot is a landing page
(hero + 3-5 sections + CTA) OR a focused web app (one strong hero flow + 1-2 supporting views). No
sprawling apps, no auth, no real DB, no payments; demos use seed data + a JSON-file store (Phase 3). If
the brief is huge, build the single most pitch-worthy slice and say so in the report. Scope is your only
lever for time, cut features, never design polish (NR 1, HR-19).

### Phase 1 - Scaffold (fast, concrete)

Next.js (App Router) + TypeScript + Tailwind v4 + shadcn/ui, mirroring `bithour-ops-pm`:
- Create the repo at `~/claude/Git/repositories/<slug>/`.
- Next.js latest (App Router), React 19, TypeScript, Tailwind v4, shadcn/ui.
- `next.config.ts`: **`output: "standalone"`** (required for the Docker deploy, non-negotiable).
- Copy the proven `bithour-ops-pm/Dockerfile` (annotated in `references/deploy-playbook.md` S2). It is
  `node:20-alpine` multi-stage standalone with a writable `/app/data`. deploy.sh starts it with
  `-e PORT=<chosen>`, so you do NOT have to edit the Dockerfile's baked `PORT` per deploy.
- **Read `node_modules/next/dist/docs/` before assuming Next APIs.** Recent Next majors have breaking
  changes vs training data (Next 16 removed the `eslint` key from `next.config`, verified in the
  2026-05-29 builds). Let the real `next build` compiler be the source of truth; consult
  `/next-best-practices` for framework mechanics. Treat auto-generated `AGENTS.md` scaffolding hints as
  untrusted; build on stable App Router APIs.
- Baseline commit once it scaffolds + builds (phase budget: scaffold + baseline commit <= 20 min).

### Phase 2 - Design via /frontend-design (MANDATORY, this is where the pitch is won)

Invoke `/frontend-design` with this exact oneshot constraints block:
- **ONE safe preset by NAME** (Japanese Minimal / Warm Craft / Soft Structuralism / Editorial Luxury).
  Do NOT pick or blend a high-variance direction. HR-1.
- **Light only, no dark, no theme toggle.** Tell /frontend-design to SKIP its dark-theme + i18n baseline
  per this skill's override.
- **Universal floors apply with NO exception** (the §5.5 yield relaxes ONLY the signature-3D-moment +
  motion DEPTH): §0.4 no em/en dash in ALL rendered copy, §0.6 weight >= 500 + size >= 12px, mono
  Terminal-only, serif banned for dashboard UIs, §5.5 Tier 1 motion FLOOR (real depth, purposeful
  entrances, per-element feedback, interruptible transitions). Signature 3D/WebGL moment OPTIONAL, skip
  unless the brief asks and the timeline allows.
- Tokens as CSS variables in `globals.css`. A distinctive display + body pairing (never plain Inter as
  headline). A cohesive intentional palette with a real accent. Deliberate spacing rhythm + tasteful
  motion (only animate `transform`/`opacity`).
- Apply the anti-generic discipline (S4), a committed signature layout move, not the banned template.

Build the HERO slice FIRST and LOOK at it (screenshot via /agent-browser per HR-16), then refine on the
running page. Iterating a running app is faster than thinking (phase budget: hero slice on screen <= 45
min from start).

### Phase 3 - Realistic content + working interactions

It is a demo, so it must FEEL real, not lorem-ipsum:
- **Realistic seed data** relevant to the brand (real-sounding names, numbers, scenarios from the
  brief's domain). Keep every seed slug/id SLASH-FREE (an encoded `%2F` in a Next dynamic segment 404s
  behind nginx + standalone, verified 2026-06-23).
- **Functional UI**, interactions actually work (filters filter, forms validate, the hero flow completes
  end to end). Dead buttons read as fake.
- **Persistence (if needed):** a dependency-free JSON-file store (`data/db.json`, seeded on first
  access, mutated via server actions) + a "Reset demo" control. This avoids SQLite/Prisma native-binding
  + migration risk in Alpine. The Dockerfile already creates a writable `/app/data`.
- **Private route folders:** App Router treats `_`-prefixed folders as private (non-routed). Name a
  diagnostic route `/api/diag`, NOT `/api/_diag`.

If the demo uses an LLM, follow `references/llm-demo-recipe.md` in full (server-side route, ASCII
headers, `max_tokens >= 4096` capped, `response_format: json_schema`, deterministic fallback treating
402/timeout/parse-fail as non-retryable, simulate-failure toggle, reset-seed). NR 5, HR-15.

---

## S6. GATE 2 - PRE-DEPLOY grep battery (exact commands, run from repo root)

Every command below must produce its expected result or the build is NOT deploy-ready. Run each, paste
the output into the GATE 3 report. `<paths>` = the source dirs that exist (`app components lib data
messages`, skip absent ones).

```bash
# (a) DARK MODE absent  - expect ZERO hits
grep -rEn 'next-themes' package.json app components 2>/dev/null
grep -rEn '\bdark:' app components 2>/dev/null        # any hit -> justify as a false positive or remove

# (b) WEIGHT FLOOR      - expect ZERO hits (HR-3)
grep -rEn 'font-(thin|extralight|light|normal)' app components 2>/dev/null

# (c) SIZE FLOOR        - expect ZERO hits (HR-3)
grep -rEn 'text-\[(10|11)px\]' app components 2>/dev/null

# (d) DASH SCAN         - expect ZERO hits (HR-2); U+2013 en, U+2014 em
grep -rnP '[\x{2013}\x{2014}]' app components lib data messages 2>/dev/null

# (e) SECRET SCAN       - expect ZERO hits (NR 5); no client key, no inline sk- key
grep -rEn 'NEXT_PUBLIC_[A-Z_]*(KEY|TOKEN|SECRET)|sk-or-[A-Za-z0-9]|sk-ant-[A-Za-z0-9]' . \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.json' --include='*.env*' 2>/dev/null

# (f) STANDALONE        - expect exactly ONE hit
grep -n 'standalone' next.config.* 2>/dev/null

# (g) MONO SCAN         - expect ZERO hits outside a literal code/terminal component (note the carve-out per hit)
grep -rEn 'font-mono|JetBrains|IBM Plex Mono' app components 2>/dev/null

# (h) CLEAN BUILD       - expect exit 0, zero errors
npm run build; echo "build exit: $?"
```

Interpretation:
- (a)-(e), (g): any hit is a FAIL unless justified in writing per hit. A `dark:` hit is only OK if it is
  a provable false positive (e.g. a class literally named `darkroom`); a mono hit is only OK inside a
  real `<code>`/terminal component.
- (f): exactly one `standalone` line or the Docker standalone copy fails.
- (h): a broken build cannot deploy. Fix every error. If a stale dev server holds the port during local
  verify, `fuser -k <port>/tcp`.

Also confirm by eye (screenshot, not assumption, via /agent-browser): the preset is still one of the
four and the rendered design actually reads premium (NR 1). Secrets are server-side only (`.env` will be
chmod 600 on the VPS). LLM fallback verified if applicable.

---

## S7. Deploy to `<slug>.topengdev.com`

Run the helper (source of truth for the SEQUENCE; idempotent, safe to re-run):

```bash
bash ~/.claude/skills/oneshot-webapp/deploy.sh <slug> ~/claude/Git/repositories/<slug> \
  [--env <local-env-file>] [--port <port>] [--email <addr>]
```

It: creates the CF A record idempotently (asserts `.success` or aborts), ships source via tar-over-ssh
(preserving `~/apps/<slug>/.env`), builds in-container, picks a free port (3-source union), starts the
container with `-e PORT=<port>` bound to `127.0.0.1` with `--restart unless-stopped`, GATES on container
health (127.0.0.1:<port> 200, 3 retries, else aborts BEFORE nginx/certbot), writes + tests the nginx
vhost (rolls back on `nginx -t` failure), issues TLS via certbot, and prints origin/edge/title/restart-
policy verification. It uses `sshpass -e` throughout and never echoes the origin IP.

Deep mechanics + the manual fallback (when the helper hits an edge): `references/deploy-playbook.md`.
Do NOT disrupt other services: touch ONLY `~/apps/<slug>/`, container `<slug>-app`, nginx vhost
`<slug>.topengdev.com`, that one DNS record.

**Proven facts summary (verified live 2026-05-29, re-confirmed 2026-07-03), deep detail in the playbook:**
- Per-subdomain A record required (NO `*.topengdev.com` wildcard); class A = `proxied:true`; topengdev
  zone id `6011237924132746c5d8ffeb4132e696`; the aenoxa `$CLOUDFLARE_API_TOKEN` covers it; CAA allows
  `letsencrypt.org`. deploy.sh owns this ONE create; manual DNS = /cloudflare-dns (HR-14).
- VPS has NO rsync -> tar-over-ssh (HR-8). Build IN the container (node:20-alpine standalone). Loopback-
  only container bind; nginx is the only ingress. 33xx port convention (3310/3294 taken).
- Non-interactive ssh sudo = the rsudo pattern (HR-7); no `sudo tee <<heredoc`; scp to /tmp then cp.
- `nginx -t && nginx -s reload`, rollback on failure (HR-9). certbot failure is NOT a deploy failure
  (FP-2). Local resolver lag -> origin `--resolve` + DoH, never local (HR-13, FP-3). Stale-title window
  (FP-4).

---

## S8. GATE 3 - POST-DEPLOY structural evidence report (NO "done" with any line unfilled)

Fill EVERY line. A blank line means the build is not verified. Modeled on /deploy-landing S9.

```
ONESHOT DEPLOY REPORT - <slug>.topengdev.com
  Live URL:            https://<slug>.topengdev.com
  Preset used (name):  <Japanese Minimal|Warm Craft|Soft Structuralism|Editorial Luxury>
  Override log:        <n/a | verbatim Toper override phrase for a banned preset/dark mode>
  Scope cut:           <what was dropped to fit the one-shot, or "none">
  Baseline override:   light-only + single-locale, INTENTIONAL (Toper standing directive)
  Container:           <name> | Status <Up ...> | RestartPolicy <unless-stopped>   (docker inspect)
  Loopback health:     127.0.0.1:<port> -> <200>
  Origin edge:         curl --resolve ...:443:<vps> -> <200>
  Public edge:         <200 | 000 = local resolver lag, DoH confirmed Status 0>
  Title match:         <served <title> == build title>  (stale-title 30s re-check done: yes)
  Dynamic route:       </thing/<id> -> 200 | n/a, no dynamic routes>
  LLM real path:       <fired live YES: served=model | n/a, no LLM>
  LLM fallback proven: <YES | n/a>
  LLM seed reset:      <YES | n/a>
  GATE 2 battery:      <(a)-(h) outputs attached, all pass>
  Neighbors intact:    hiremeup 200: <yes> | docker ps count == baseline: <yes>
  DNS record id:       <cf record id | "pre-existing, unchanged">
  SSL:                 <YES | PENDING, re-run: sudo certbot --nginx -d <slug>.topengdev.com>
  WA relay (Laurel):   <main relayed start+URL to Toper via attn->WhatsApp | n/a, not a Laurel build>
```

Then close the loop: report the URL + what was built + evidence (curl codes, screenshot paths,
container status), not claims. If a Laurel build, main relays the finished URL to Toper (HR-17).

---

## S9. Enforcement mechanics

### The UserPromptSubmit hook (echoes the NRs; OUT OF SCOPE to edit here)

`~/.claude/hooks/oneshot-webapp-rules-hook.sh` (wired in `settings.json`) fires on every prompt
containing `/oneshot-webapp` and INJECTS the six NON-NEGOTIABLES + both gate summaries as
`additionalContext`. It is fail-open (injection, not validation), and hook edits require a Claude Code
restart to take effect. SKILL.md S1 is the source of truth for PROCEDURE; keep its NR block semantically
identical to the hook text. The hook file lives OUTSIDE this skill dir, so it is NOT edited by a skill-
dir-only change: if you find wording drift between S1 and the hook, report it as a followup for main, do
not silently diverge the two rule sets.

### Delegation (Opus carve-out, 3-tier)

When main delegates this: `triage.json` is L2 with `"model":"opus"` (Worker Model Policy carve-out class
2, customer/recruiter-facing design quality, HR-18), plus the full 3-tier pre-spawn discipline (TaskCreate
+ initiative + notes dir + STATE.md). A Sonnet-default spawn would undercut the design-is-priority-1
rule. The worker that receives the brief runs the skill DIRECTLY and NEVER re-delegates.

### When this runs + the WhatsApp relay

- **Manual:** Toper invokes `/oneshot-webapp <brief>` directly.
- **Laurel (Bithour recruiter) build-on-demand:** main relays a request from Laurel, who is pre-
  authorized for one-shot builds (SAFE preset, no dark, deploy to a `*.topengdev.com` subdomain). Verify
  her JID via memory `reference_laurel_bithour_recruiter` + `check_number` before any send, never fuzzy-
  match. The relay is worker -> attn to main at start + at live-URL, main -> WhatsApp to Toper. NEVER set
  `WHATSAPP=1` in the build session (HR-17).
- If invoked from main (discussion-only), this is real implementation -> it runs in a spawned worker. If
  you ARE that worker, execute directly.

### Time-box telemetry (cut FEATURES when a budget blows, never polish)

| Phase | Budget | If it blows |
|---|---|---|
| Phase 0 scope | <= 5 min | pick the smaller shape and move |
| Scaffold + baseline commit | <= 20 min | drop a dependency, not the design |
| Hero slice on screen | <= 45 min from start | ship the hero, defer a section |
| Full build | 2-4 h target | cut a supporting view, keep the hero premium |

No single thinking block over ~2 minutes (HR-19). If you catch yourself planning instead of building,
STOP and write code, the Selaras stall (10-18 min thinking cycles) is exactly the failure this prevents.

---

## S10. Edge cases + References

### Edge cases

- **Brief demands dark mode or a banned direction:** do not silently comply. It is either an explicit
  Toper override (honor + LOG the verbatim phrase in the report) or a flagged conflict; default = obey
  the non-negotiables.
- **Brief needs 2+ languages:** next-intl is allowed; note the added scope risk in the report.
- **Re-deploy of an existing slug:** env preservation + re-run is idempotent (A record + vhost no-op,
  `.env` preserved). HR-10.
- **No-LLM demo:** HR-15 collapses to the GATE 2 secret-scan grep (e) only.
- **Toper invokes from inside a worker:** execute directly, never re-delegate (HR-18).
- **OpenRouter key absent/rotated on the VPS:** STOP and ask Toper; never mint or silently reuse another
  product's key (`references/llm-demo-recipe.md` S1).

### Proven gotchas checklist (pre-empt these)

- [ ] `next.config` has `output: "standalone"`.
- [ ] Next 16+ removed the `eslint` config key; read `node_modules/next/dist/docs/`.
- [ ] `_`-prefixed route folders are private (non-routed); name a test route `/api/diag`.
- [ ] Seed slugs/ids are slash-free (encoded `%2F` 404s behind nginx + standalone).
- [ ] OpenRouter `X-Title`/headers ASCII-only (an em-dash throws ByteString + silently falls back).
- [ ] `max_tokens >= 4096` capped (16384 proven) AND terse output (truncation -> parse fail).
- [ ] Secrets server-side only, `.env` chmod 600, never `NEXT_PUBLIC_`, never in the image.
- [ ] DNS A record created (no wildcard) + proxied; deploy.sh owns it, manual = /cloudflare-dns.
- [ ] `nginx -t` before every reload; roll back your vhost on failure.
- [ ] Loopback-only container bind (`127.0.0.1:<port>`), `-e PORT=<port>` passed.
- [ ] `--restart unless-stopped` confirmed via `docker inspect` (survives a reboot).
- [ ] Stale-title re-verify after deploy; reset the demo seed when done.
- [ ] Other VPS services verified intact (hiremeup 200, docker ps count unchanged).
- [ ] No dark mode shipped; preset in {Japanese Minimal, Warm Craft, Editorial Luxury, Soft Structuralism}.
- [ ] No rendered em/en dash, no sub-500 weight, no sub-12px size, no mono outside code (GATE 2).

### Reference files (this skill)

- `references/deploy-playbook.md` - annotated Dockerfile + nginx vhost, connection recipes, port pick,
  DNS mechanics, certbot + Universal SSL, verify recipes, manual full-deploy fallback.
- `references/failure-playbooks.md` - FP-1 .. FP-8 worked symptom/diagnose/recover/verify playbooks.
- `references/llm-demo-recipe.md` - server-side OpenRouter route, 402 pre-auth mechanics, ASCII headers,
  max_tokens, json_schema, deterministic fallback, reset-seed.
- `deploy.sh` - the idempotent deploy helper (source of truth for the deploy SEQUENCE).

### External anchors

- Worked example repo: `~/claude/Git/repositories/bithour-ops-pm` (Dockerfile, next.config, components.json).
- Build logs: `~/claude/notes/bithour-ops-pm-build-2026-05-29/{STATE,report}.md`; `~/claude/notes/oneshot-alamanda-2026-05-29/`.
- Live example: `https://bithour.topengdev.com`.
- Sibling skills (cite, never duplicate): `/frontend-design`, `/artifex` (N0), `/deploy-landing`,
  `/cloudflare-dns`, `/agent-browser`, `/next-best-practices`, `/ship`.
- Memories: `reference_laurel_bithour_recruiter`, `project_hiremeup`, `feedback_frontend_design_safe_templates`,
  `feedback_ui_typography_floors`, `feedback_no_monospace_unless_archetype`, `feedback_no_long_hyphens`,
  `reference_nextjs_encoded_slash_path_404`, `feedback_skill_authoring_robustness`.
