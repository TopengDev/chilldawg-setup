---
name: oneshot-webapp
description: One-shot a pitch-grade web app or landing page from a brief and deploy it live to a <slug>.topengdev.com subdomain. Next.js + Tailwind + shadcn, designed via /frontend-design (SAFE preset — Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism — light-only, no dark), then docker + nginx + certbot on the VPS. Use when Toper says /oneshot-webapp, asks to build+deploy a demo/pitch site, or main handles a build request from Laurel (Bithour recruiter).
argument-hint: <brief — what to build, who it's for, any market/language/feature requirements>
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, WebFetch
---

# /oneshot-webapp — brief → pitch-grade web app → live subdomain

Take a brief and, in a SINGLE session, produce a polished, real-feeling web app or landing page and deploy it live at `https://<slug>.topengdev.com`. This codifies the proven Selaras / `bithour-ops-pm` / Alamanda builds (2026-05-29).

This is for **pitches and recruiter build-on-demand requests** (Toper's Bithour interview demos, Laurel's one-shot asks). The output must look like a real product a paying client would ship — not a generic AI scaffold.

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES — READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

These are HARD rules. Violating any one is a failed build, not a stylistic choice. If something below appears to conflict with one of these, the NON-NEGOTIABLE wins.

1. **PITCH-GRADE DESIGN IS PRIORITY #1.** This is the rule the whole skill exists for. The output must read as premium, deliberate, and real. Spend EXTRA effort on design quality. Generic shadcn-default looks = failure. Never cut design polish to save time — **cut SCOPE instead** (fewer pages, fewer features). Polish is the deliverable.

2. **ONLY SAFE PRESETS. HIGH-VARIANCE IS BANNED.** Use ONLY these four `/frontend-design` SAFE presets (low-variance, degrade gracefully, always read clean):
   - **Japanese Minimal** (VARIANCE 4 / MOTION 2 / DENSITY 1)
   - **Warm Craft** (VARIANCE 4 / MOTION 4 / DENSITY 4)
   - **Soft Structuralism** (VARIANCE 4 / MOTION 5 / DENSITY 5)
   - **Editorial Luxury** (VARIANCE 6 / MOTION 4 / DENSITY 4) ← Alamanda used this, came out clean.

   **BANNED unless Toper explicitly overrides in this run's brief:** Neo-Brutalist, Magazine Editorial, Dark Cinematic, Gen Z Expressive, Playful Pop, Anti-Design, art-deco/geometric, maximalist, and any other high-variance (VARIANCE ≥ 7) or expressive direction. These are execution-sensitive and have been rejected ("looked SO BAD" — art-deco Bithour/Selaras demo, 2026-05-29). Pick ONE safe preset and commit to it.

3. **LIGHT MODE ONLY. NO DARK MODE. NO THEME SWITCHER.** Do not add `next-themes`, a dark palette, a `dark:` variant set, or a theme toggle. Light is the only theme. (This intentionally overrides the `/frontend-design` light+dark baseline — see "Baseline override".)

4. **SHIP FAST — ACT, DON'T DELIBERATE.** Cap your thinking. Move in concrete, visible steps: get a working slice on screen, then refine the running app. Do NOT burn long high-effort thinking cycles deliberating architecture or "the perfect approach" — the Selaras worker stalled in 10–18 min thinking blocks and had to be interrupted. If you catch yourself planning instead of building, STOP and write code. Iterating a running app is faster than thinking your way to perfection.

5. **SERVER-SIDE SECRETS ONLY + MANDATORY DETERMINISTIC LLM FALLBACK.** If the demo uses an LLM/API: the key lives in container env (`~/apps/<slug>/.env`, chmod 600) — **never** client-side, never `NEXT_PUBLIC_`, never baked into the image. The model is called server-side only (route handler / server action). And you MUST ship a deterministic fallback for the exact demo scenario so the live demo NEVER breaks if the API fails / runs out of credit / times out.

6. **DEPLOY TO `<slug>.topengdev.com`.** Final live URL is always `https://<slug>.topengdev.com` (a clean, short, hyphenated slug derived from the app/company name). Not aenoxa.com, not a raw IP, not localhost. HTTPS via certbot, behind nginx + Cloudflare.

> If the brief asks for something that breaks one of these (e.g. "make it dark mode", "use a bold brutalist look"), do NOT silently comply. Either the brief is from Toper explicitly overriding (rule 2/3 allow an explicit Toper override — honor it and note it in the report), or flag the conflict. Default = obey the non-negotiables.

═══════════════════════════════════════════════════════════════════════════
## ✅ GATE 1 — PRE-FLIGHT (satisfy ALL before writing any app code)
═══════════════════════════════════════════════════════════════════════════

Do not start scaffolding until every box is a definite YES (or a logged, intentional exception):

- [ ] **Scope is the smallest pitch-landing shape** — a landing page (hero + 3–5 sections + CTA) OR a focused app (one strong hero flow + 1–2 supporting views). NOT a sprawling multi-module app, auth system, real DB, or payments.
- [ ] **ONE safe preset chosen** from the four allowed (Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism), matched to brand tone. High-variance NOT chosen (unless Toper explicitly overrode in-brief — then logged).
- [ ] **Dark mode is NOT in the plan.** No `next-themes`, no theme toggle, no dark palette.
- [ ] **Locale decided** — single locale in the brief's language (Bahasa for Indonesian audience, English for a recruiter demo; default English). next-intl/multi-locale ONLY if the brief explicitly needs 2+ languages.
- [ ] **Slug derived** — lowercase, hyphenated, short, no spaces. Final URL = `https://<slug>.topengdev.com`.
- [ ] **LLM feature decided** — if yes, server-side route + deterministic fallback are part of the plan (rule 5).
- [ ] **A committed design direction is written down** (preset + palette intent + font pairing + one signature layout move) — see anti-generic constraints. No "I'll decide as I go".

═══════════════════════════════════════════════════════════════════════════
## ✅ GATE 2 — PRE-DEPLOY (satisfy ALL before running deploy.sh / shipping)
═══════════════════════════════════════════════════════════════════════════

- [ ] **`npm run build` is CLEAN** (Next standalone, zero errors). A broken build can't deploy.
- [ ] **Preset is still one of the four safe ones** and the rendered design actually reads premium (you looked at it — screenshot, not assumption).
- [ ] **No dark mode shipped** — grep the codebase: no `next-themes`, no `dark:` class clusters, no theme toggle component.
- [ ] **`next.config` has `output: "standalone"`.**
- [ ] **Secrets are server-side only** — no `NEXT_PUBLIC_` secret, no key in the image; `.env` will be chmod 600 on the VPS.
- [ ] **LLM fallback verified** (if applicable) — the demo flow completes even with the API force-failed.
- [ ] **Cloudflare A record for `<slug>.topengdev.com` will be created** (no `*.topengdev.com` wildcard exists). `deploy.sh` does this idempotently.
- [ ] **Won't disrupt other VPS services** — only your slug's `~/apps/<slug>/`, container `<slug>-app`, nginx vhost, and DNS record are touched.

═══════════════════════════════════════════════════════════════════════════
## 🚫 ANTI-GENERIC DISCIPLINE (mirror /frontend-design — commit to a direction)
═══════════════════════════════════════════════════════════════════════════

Pitch-grade means NOT looking like every other AI scaffold. Force a committed, distinctive direction:

- **BANNED default layout:** centered-hero → 3 equal feature cards → generic CTA banner → minimal footer. This is the AI-slop signature. If you reach for it, STOP and introduce a signature move from the chosen preset (an editorial split hero, an asymmetric bento, an offset section, a typographic statement, a real product mock/screenshot region).
- **Typography:** a DISTINCTIVE display + body pairing (see /frontend-design's pairings). **NEVER plain Inter/Roboto/Arial as the headline face.** Serif is BANNED for dashboard/software UIs (sans pairings only there); serif/editorial faces are for landing/editorial vibes.
- **Color:** ONE cohesive, intentional palette with a real accent — NOT gray-on-gray, NOT default shadcn slate. Tokens as CSS variables in `globals.css` (`--bg`, `--fg`, `--accent`, `--surface`, `--border`, …). Never hardcode colors in components.
- **Spacing & motion:** a deliberate spacing rhythm and tasteful motion (scroll-reveal, hover states) — only animate `transform`/`opacity`. Motion in service of hierarchy, never motion-for-motion's-sake.
- **Content must feel real** (see Phase 3) — realistic seed data, working interactions. Dead buttons + lorem ipsum read as fake and kill the pitch.
- **Commit, don't hedge.** One preset, one palette, one type system, executed confidently. A timid blend of three directions reads as generic. (Per /frontend-design: under-committing is the #1 way a build looks "AI-made".)

---

## When this runs

- **Manual:** Toper invokes `/oneshot-webapp <brief>` directly.
- **Laurel (Bithour recruiter) build-on-demand:** main relays a request from Laurel (+62 813-2457-8123) — she's pre-authorized for one-shot builds. SAFE preset, NO dark mode, deploy to a `*.topengdev.com` subdomain, and **notify Toper via WhatsApp on each build** (start + finished URL). See memory `reference_laurel_bithour_recruiter`.

If invoked from main (discussion-only session), this is real implementation work → it should run in a **spawned worker**, not main. If you ARE the worker that received this brief, execute it directly; do not re-delegate.

---

## Inputs to extract from the brief

Before scaffolding, pin down (ask only if genuinely blocking — otherwise pick a sensible default and note it):

- **What** — landing page vs focused web app. Lean toward whichever is reliably one-shot-able (see Scope rule / GATE 1).
- **Who/what for** — company, audience, the pain it addresses (drives copy + visual tone + which safe preset).
- **Language/market** — single locale, in whatever language the brief implies (Bahasa for an Indonesian audience, English for a recruiter demo). Default English if unspecified. **Do NOT add next-intl/multi-locale unless the brief explicitly needs 2+ languages** — it adds scope risk for a one-shot.
- **Any LLM/AI feature** — if yes, see the AI-feature rule (server-side + deterministic fallback, mandatory — NON-NEGOTIABLE 5).
- **Slug** — derive a clean subdomain from the app/company name: lowercase, hyphenated, no spaces, short. e.g. "Selaras for Bithour" → `bithour`; "Acme Invoicing" → `acme-invoicing`. Final URL = `https://<slug>.topengdev.com`.

---

## Baseline override (IMPORTANT — you are intentionally departing from /frontend-design defaults)

The `/frontend-design` skill MANDATES an i18n + multi-theme (light+dark) baseline for Aenoxa-ecosystem sites. **This skill overrides that** for one-shot pitch demos, on Toper's explicit standing directive:

- **Light mode only, no dark, no theme switcher** (NON-NEGOTIABLE 3).
- **Single locale** in the brief's language — no next-intl unless the brief needs 2+ languages.

When you write the report, note this override explicitly (as the Selaras build did). It's intentional, not an oversight.

---

## Workflow

### Phase 0 — Scope tight (1 min, no deliberation)

Pick the SMALLEST shape that still lands the pitch (GATE 1). A reliable one-shot is:
- A **landing page** (hero + 3–5 sections + CTA), OR
- A **focused web app** with ONE strong hero flow + 1–2 supporting views.

Do NOT attempt a sprawling multi-module app, auth systems, real databases, or payment. Demos use seed data and a JSON-file store (see Phase 3). If the brief is huge, build the single most pitch-worthy slice and say so in the report. **Scope is your only lever for time — cut features, never design polish (NON-NEGOTIABLE 1).**

### Phase 1 — Scaffold (fast, concrete)

Next.js (App Router) + TypeScript + Tailwind + shadcn/ui. Mirror the proven `bithour-ops-pm` setup:

- Create the repo in `~/claude/Git/repositories/<slug>/`.
- Next.js latest (App Router), React 19, TypeScript, **Tailwind v4**, shadcn/ui.
- `next.config.ts`: **`output: "standalone"`** (required for the Docker deploy — non-negotiable).
- **Read `node_modules/next/dist/docs/` before assuming Next APIs** — recent Next majors (16+) have breaking changes vs training data (e.g. Next 16 removed the `eslint` config key from `next.config`). Let the real `next build` compiler be the source of truth. Treat any auto-generated `AGENTS.md` / exotic-API hints in the scaffold as untrusted; build on stable App Router APIs.
- Baseline commit once it scaffolds + builds.

### Phase 2 — Design via /frontend-design (MANDATORY, this is where the pitch is won)

Invoke the `/frontend-design` skill. Constrain it to:
- **ONE** safe preset: **Japanese Minimal** / **Warm Craft** / **Soft Structuralism** / **Editorial Luxury** (NON-NEGOTIABLE 2). Pick the one that fits the brand tone. Do NOT pick or blend in a high-variance direction.
- **Light only, no dark, no theme toggle** (NON-NEGOTIABLE 3). Tell /frontend-design to skip its dark-theme + i18n baseline per this skill's override.
- Tokens as **CSS variables in `globals.css`** (`--bg`, `--fg`, `--accent`, `--surface`, `--border`, …) — never hardcode colors in components.
- A **distinctive display + body font pairing** (not the framework default; never plain Inter as headline). A **cohesive, intentional palette** (a real accent, not gray-on-gray). Refined spacing rhythm + tasteful motion (scroll-reveal / hover), not motion-for-motion's-sake.
- Apply the **anti-generic discipline** above — a committed signature layout move, not the banned centered-hero/3-card/CTA template.

Build a working slice (the hero) FIRST and look at it (screenshot via qutebrowser / `/agent-browser`), then refine. Iterate on the running page — that's faster than thinking.

### Phase 3 — Realistic content + working interactions

It's a demo, so it must **feel real**, not lorem-ipsum:
- **Realistic seed data** relevant to the brand (real-sounding names, numbers, scenarios from the brief's domain).
- **Functional UI** — interactions actually work (filters filter, forms validate, the hero flow completes end-to-end). Dead buttons read as fake.
- **Persistence (if the app needs state):** use a dependency-free **JSON-file store** (`data/db.json`, seeded on first access, mutated via server actions) + a "Reset demo" control. This avoids SQLite/Prisma native-binding + migration risk in Alpine — proven robust for demos. The Dockerfile must create a writable `/app/data` dir (see deploy).

#### AI/LLM feature rule (MANDATORY if the demo uses an LLM — NON-NEGOTIABLE 5)

- **Call the model SERVER-SIDE only** (a route handler / server action). The API key lives in container env (`~/apps/<slug>/.env`, chmod 600) — **never** shipped to the client, never baked into the image, never a `NEXT_PUBLIC_` var.
- Reuse the existing OpenRouter setup (`anthropic/claude-sonnet-4.6`, same as hiremeup). Pull the key pattern from `~/apps/hiremeup/.env` on the VPS if needed.
- **ALWAYS ship a deterministic fallback** for the exact demo scenario, so the live demo NEVER breaks if the API fails / runs out of credit / times out. Wire a visible "simulate AI failure" toggle if useful for rehearsals.
- **Proven gotchas** (from Selaras — bake these in up front):
  - HTTP headers must be ASCII/Latin-1. An em-dash (U+2014) in an `X-Title` header throws `Cannot convert argument to a ByteString` and silently falls back. Keep headers ASCII-only.
  - `max_tokens` truncation → `finish_reason=length` → JSON parse fail → fallback. The fix is to **constrain the model** (terse fields, cap the op count in the system prompt), not just raise `max_tokens` (latency + Cloudflare 100s timeout risk). Set `max_tokens` ≥ 4096 AND keep outputs terse.
  - Use structured output (`response_format: json_schema`) for any plan/mutation the UI consumes.

### Phase 4 — Build verify (GATE 2)

`npm run build` must be **clean** (Next standalone). Fix every error — a broken build can't deploy. Run GATE 2 here: confirm safe preset, no dark mode (grep for `next-themes`/`dark:`/theme toggle), standalone config, secrets server-side. If a stale dev server holds the port during local verify, `fuser -k <port>/tcp`.

### Phase 5 — Deploy to `<slug>.topengdev.com`

Use the helper: **`bash ~/.claude/skills/oneshot-webapp/deploy.sh <slug> ~/claude/Git/repositories/<slug> [--env <local-env-file>] [--port <port>] [--email <addr>]`**. It is idempotent and replicates the proven pattern below. If you prefer or the helper hits an edge case, run the steps manually — the helper is the source of truth for the *sequence*, this section for the *facts*. `deploy.sh` already: creates the CF A record idempotently, ships source via rsync→tar fallback, builds in-container, picks a free port, writes+tests the nginx vhost (rolls back on `nginx -t` failure), and issues TLS via certbot — all using the non-interactive `rsudo` helper.

VPS access (vars auto-sourced from `~/.claude/secrets.env`):
```
sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$VPS_USER@$VPS_HOST"
```
VPS host = `$VPS_HOST`. **Do NOT disrupt other services** — hiremeup / signal-trader / wa-sender / aenoxa(_auth/_iam/_pos/_billing) / bithour / sinarsurya / wiraduta. Touch ONLY your own slug's: `~/apps/<slug>/`, container `<slug>-app`, nginx vhost `<slug>.topengdev.com`, that one DNS record.

**Proven facts (verified live 2026-05-29):**

1. **DNS — a per-subdomain A record IS required.** There is NO `*.topengdev.com` wildcard. Every subdomain (bithour, hiremeup, dev, portfolio…) has its own explicit A record → `$VPS_HOST`, **proxied (orange cloud)**. Create one for your slug if it doesn't exist. The aenoxa Cloudflare token (`$CLOUDFLARE_API_TOKEN`) **covers the topengdev.com zone** (zone id `6011237924132746c5d8ffeb4132e696`) — so you can create it via the API; no separate creds needed:
   ```bash
   curl -s -X POST "https://api.cloudflare.com/client/v4/zones/6011237924132746c5d8ffeb4132e696/dns_records" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
     -d "{\"type\":\"A\",\"name\":\"<slug>.topengdev.com\",\"content\":\"${VPS_HOST}\",\"proxied\":true}"
   ```
   (CAA on topengdev.com allows `letsencrypt.org`, so certbot will issue.)

2. **Ship the source to `~/apps/<slug>/` and build IN the container** (not locally — the image runs `npm ci` + `npm run build` itself). rsync the repo excluding `node_modules .next .git data .env.local`. The `.dockerignore` mirrors these. **VPS has NO `rsync`** (verified 2026-05-29, alamanda run) — `deploy.sh` falls back to tar-over-ssh automatically. Manual: `tar czf - --exclude=node_modules --exclude=.next --exclude=.git --exclude=data . | ssh … "tar xzf - -C ~/apps/<slug>"`.

3. **Dockerfile** (multi-stage, `node:20-alpine`, standalone) — copy the proven one from `~/claude/Git/repositories/bithour-ops-pm/Dockerfile`. Key points: `deps` (npm ci) → `builder` (npm run build) → `runner` (copies `.next/standalone` + `.next/static` + `public`, creates writable `/app/data`, non-root `nextjs` user, `EXPOSE`/`ENV PORT`, `CMD ["node","server.js"]`). Set its `PORT`/`EXPOSE` to your chosen port.

4. **Pick a free loopback port** (bithour=3310, hiremeup=3294). Pick an unused one (scan existing nginx `proxy_pass` ports + `docker ps`); 33xx range is convention here. `deploy.sh` auto-picks if `--port` omitted.

5. **docker build + run** on the VPS, bound to loopback only:
   ```bash
   cd ~/apps/<slug> && docker build -t <slug>-app:latest .
   docker rm -f <slug>-app 2>/dev/null; \
   docker run -d --name <slug>-app --restart unless-stopped \
     -p 127.0.0.1:<port>:<port> --env-file ~/apps/<slug>/.env <slug>-app:latest
   ```
   (Omit `--env-file` if the app has no secrets. The `.env` must be chmod 600, server-side only.)

6. **nginx vhost** at `/etc/nginx/sites-available/<slug>.topengdev.com` (root-owned → sudo via `rsudo`), reverse-proxy to `127.0.0.1:<port>`, then symlink into `sites-enabled`. Write HTTP-only first (certbot adds TLS). Proven vhost body:
   ```nginx
   server {
       server_name <slug>.topengdev.com;
       client_max_body_size 5M;
       location / {
           proxy_pass http://127.0.0.1:<port>/;
           proxy_http_version 1.1;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_buffering off;
           proxy_read_timeout 86400;
       }
       listen 80;
       listen [::]:80;
   }
   ```
   Then: `sudo ln -sf …/sites-available/<slug>.topengdev.com …/sites-enabled/` → **`sudo nginx -t`** (ALWAYS test before reload) → `sudo nginx -s reload`. If `nginx -t` fails, remove your symlink + vhost and reload to restore — never leave nginx broken. **Non-interactive ssh sudo needs the login password** (`echo "$VPS_PASSWORD" | sudo -S -p '' <cmd>` — the login password IS the sudo password); plain `sudo` over ssh fails "a terminal is required". Don't `sudo tee <<heredoc` (stdin clash with `sudo -S`) — scp the file to /tmp then `sudo cp`.

7. **TLS via certbot** (rewrites the vhost to add 443 + an HTTP→HTTPS 301 redirect; auto-renews via `certbot.timer`):
   ```bash
   sudo certbot --nginx -d <slug>.topengdev.com --non-interactive --agree-tos -m topengdev@gmail.com --redirect
   ```

### Phase 6 — Live verify (close the loop — do NOT trust the first curl)

1. Container: `docker ps` shows `<slug>-app` Up + `restart=unless-stopped`; VPS-local `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:<port>` → 200.
2. External: `curl -I https://<slug>.topengdev.com` → **HTTP/2 200**; `http://` → 301.
3. **Content check (the gotcha):** confirm the served page is actually YOUR app — grep the `<title>`/hero text. **Right after deploy the domain can briefly serve a STALE title** (Cloudflare/routing settling). If the title is wrong, wait ~20–30s and re-verify before believing it. Don't report a URL until the content matches.
4. **Local resolver lag** — this machine resolves DNS via a Netbird/Tailscale resolver (`100.114.167.227`) that can lag minutes behind public DNS for a freshly-created record. A `000` from `curl https://<slug>.topengdev.com` locally does NOT mean the deploy failed. Confirm with an origin check (`curl --resolve <slug>.topengdev.com:443:$VPS_HOST …`) + public DoH (`cloudflare-dns.com/dns-query?name=…`). qutebrowser uses the same lagging resolver, so a live screenshot may show a DNS error page even when the site is up — screenshot localhost (identical build) + grep the live HTML over the CF edge instead.
5. Visual: screenshot the live site (or localhost identical build) and eyeball the design quality (NON-NEGOTIABLE 1).
6. If the demo has an AI feature: fire the real flow live once (confirm real model path, not just fallback) AND confirm the fallback works. Then **reset the demo to a clean seed** so Toper opens a pristine state.
7. Re-verify other services are intact: `curl -I https://hiremeup.topengdev.com` → 200, `docker ps` shows aenoxa/bithour/etc still up.

### Phase 7 — Report

Report the **live URL** + what was built, the **safe preset used** (one of the four), anything cut for scope, the baseline override (light-only/single-locale + why), AI-feature status + fallback, and verification evidence (not claims — curl codes, screenshot paths, container status). If this was a Laurel build, send Toper the finished URL via WhatsApp.

---

## Proven gotchas checklist (from Selaras / bithour-ops-pm / Alamanda — pre-empt these)

- [ ] `next.config` has `output: "standalone"` (or the Docker standalone copy fails).
- [ ] Next 16+ removed the `eslint` config key — don't add it; read `node_modules/next/dist/docs/`.
- [ ] App Router treats `_`-prefixed route folders as private (non-routed) — don't name a test route `/api/_diag`.
- [ ] OpenRouter `X-Title`/headers must be ASCII (no em-dash) or every call throws + silently falls back.
- [ ] `max_tokens` ≥ 4096 AND constrain the model to terse output (truncation → JSON parse fail).
- [ ] Secrets server-side only — `.env` chmod 600 on VPS, never `NEXT_PUBLIC_`, never in the image.
- [ ] DNS A record created (no wildcard exists) + proxied (orange cloud).
- [ ] `sudo nginx -t` before every reload; rollback your vhost on failure.
- [ ] Loopback-only container bind (`127.0.0.1:<port>`) — nginx is the only ingress.
- [ ] Free port chosen (not 3310/3294 or any in-use proxy_pass).
- [ ] Stale-title re-verify after deploy; reset demo seed when done.
- [ ] Other VPS services verified intact.
- [ ] **VPS has NO `rsync`** — `deploy.sh` falls back to tar-over-ssh. Manual tar exclude set: `node_modules .next .git data`.
- [ ] **Non-interactive ssh sudo needs the login password** — `echo "$VPS_PASSWORD" | sudo -S -p '' <cmd>`. `deploy.sh` does this via `rsudo`. Don't `sudo tee <<heredoc`.
- [ ] **Local resolver lag** — a local `000`/DNS-error does NOT mean the deploy failed; verify via origin `--resolve` + public DoH, screenshot localhost.
- [ ] **NO dark mode shipped** — grep: no `next-themes`, no `dark:` clusters, no theme toggle.
- [ ] **Preset ∈ {Japanese Minimal, Warm Craft, Editorial Luxury, Soft Structuralism}** — high-variance not shipped.

## References

- Worked example repo: `~/claude/Git/repositories/bithour-ops-pm` (Dockerfile, next.config, components.json).
- Full build log + problems solved: `~/claude/notes/bithour-ops-pm-build-2026-05-29/{STATE,report}.md`; alamanda run notes `~/claude/notes/oneshot-alamanda-2026-05-29/`.
- Live example: `https://bithour.topengdev.com`.
- Design rules + the four safe presets: `/frontend-design` skill (`~/.claude/skills/frontend-design/SKILL.md`) + memory `feedback_frontend_design_safe_templates`.
- Skill-robustness bar: memory `feedback_skill_authoring_robustness`.
- Laurel build-on-demand: memory `reference_laurel_bithour_recruiter`.
- Deploy helper: `~/.claude/skills/oneshot-webapp/deploy.sh` (idempotent; source of truth for the deploy *sequence*).
- Related: `/deploy-landing` (PM2/static landing pattern for *.aenoxa.com — different stack), `/cloudflare-dns` (aenoxa.com-scoped — this skill uses the topengdev.com zone directly).
