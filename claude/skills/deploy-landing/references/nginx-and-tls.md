# nginx vhosts + TLS mechanics (deploy-landing)

The CANONICAL vhost templates live in SKILL.md S5.3 - this file annotates them and
carries the TLS/Cloudflare depth. Never fork the template text here; if a template
changes, change it in SKILL.md and update the annotations.

---

## 1. Standalone (reverse proxy) template - line notes

| Line | Why it is there |
|---|---|
| `server_name {SUBDOMAIN};` | exact-match vhost; nginx routes by Host header. One config file per landing page, always named exactly the fqdn (that filename IS the redeploy-detection key in GATE 1). |
| `proxy_pass http://127.0.0.1:{PORT}/;` | loopback-only upstream - the node process must bind 127.0.0.1, nginx is the only ingress. The trailing `/` maps location `/` to upstream `/`. |
| `proxy_http_version 1.1;` | required for keep-alive to the upstream; default 1.0 breaks some streaming responses. |
| `proxy_set_header Host/X-Real-IP/X-Forwarded-For/X-Forwarded-Proto` | Next.js needs Host + proto for absolute URL generation behind a proxy; logs need the real client IP (which, behind Cloudflare, is the CF edge - fine for a landing page). |
| `proxy_buffering off; proxy_cache off;` | landing pages are small + dynamic-ish (RSC streaming); buffering adds latency and can garble streamed responses. |
| `proxy_read_timeout 86400;` | generous read timeout; harmless for a landing, protects any long-poll. |
| `listen 80; listen [::]:80;` | HTTP-ONLY on purpose. certbot `--nginx` rewrites this file to add 443 + a 301 redirect. Never hand-write the 443 block. |

## 2. Static export template - line notes

| Line | Why it is there |
|---|---|
| `root /var/www/{SUBDOMAIN}; index index.html;` | serves the `out/` export directly - zero process, reboot-proof (nginx is systemd-managed). |
| `try_files $uri $uri.html $uri/ /index.html;` | Next static-export URL semantics: `/about` -> `about.html`; trailing-dir indexes; SPA-style fallback to `/index.html` last. Order is load-bearing - do not reorder. |
| `location /_next/static/ { expires 365d; add_header Cache-Control "public, immutable"; }` | Next fingerprints these assets by content hash - immutable forever-caching is correct and free performance. Do NOT extend this to `/` (unhashed HTML must revalidate). |

Both templates deliberately contain NO `client_max_body_size`, no gzip tuning, no
security-header stack - landing pages take no uploads and Cloudflare fronts them.
Add nothing without a reason you can state in the report.

---

## 3. certbot mechanics on this box

- Command (SKILL.md S5.5): `certbot --nginx -d <sub> --non-interactive --agree-tos
  --email admin@aenoxa.com --redirect` - run via rsudo.
- `--nginx` authenticates via the HTTP-01 challenge THROUGH the live vhost (this is
  why the HTTP-only vhost must be enabled + reloaded BEFORE certbot runs), then
  REWRITES the config file in place: adds `listen 443 ssl`, cert paths under
  `/etc/letsencrypt/live/<sub>/`, and a port-80 301 redirect (`--redirect`).
- Renewal is automatic via the systemd `certbot.timer` (the oneshot lineage relies on
  it; topengdev certs renew this way). No cron to add, nothing to babysit.
- Because certbot MUTATES the config: on a redeploy of an SSL:YES site, the existing
  config already carries the 443 block - do NOT overwrite it with the HTTP-only
  template unless you intend to re-run certbot afterwards. GATE 1's config-shape check
  accepts the certbot-rewritten form (it still contains `server_name` + `proxy_pass`/
  `root` lines).
- certbot failure is NEVER a deploy failure (HR-7 / FP-4): the site serves on HTTP at
  origin and usually on HTTPS at the Cloudflare edge already (next section).

---

## 4. Cloudflare-proxied nuances (why "it's already HTTPS" and "certbot failed" coexist)

- **Universal SSL:** Cloudflare's free edge cert covers the apex + FIRST-LEVEL
  subdomains (`*.aenoxa.com`). Every `<name>-landing-page.aenoxa.com` is one label
  deep, so with a PROXIED (orange) record the edge serves valid HTTPS to visitors
  even while the origin has no cert yet.
- **Why the origin cert still matters:** edge->origin encryption. Without an origin
  cert the zone can only run "Flexible"/"Full" (not "Full (strict)") for that host;
  Full (strict) requires a valid origin cert - which is exactly what certbot issues.
  So `SSL: PENDING` = visitors likely fine via the edge, origin leg not yet strict -
  finish the certbot rerun, don't shrug it off.
- **HTTP-01 through the orange cloud:** Cloudflare proxies port 80 and passes
  `/.well-known/acme-challenge/` through, so certbot's HTTP-01 normally succeeds even
  on proxied records - the usual real failure causes are (a) the A record does not
  exist yet, (b) public DNS has not propagated, (c) CAA forbids letsencrypt.
- **Proxied flag ownership:** /cloudflare-dns S3 decision table + its Beacon legacy
  note own the orange/grey call for these records (historically orange per
  reference_cloudflare). This skill records the class it reports, never overrides it.

---

## 5. CAA (check before blaming certbot)

- topengdev.com: CAA verified to allow `letsencrypt.org` (oneshot SKILL.md, 2026-05-29).
- aenoxa.com: CAA NOT verified as of 2026-07-03 - treat as a runtime check. Read-only
  check via DoH (no dig on this box - cloudflare-dns S1):

```bash
curl -s -H 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=aenoxa.com&type=CAA' | jq '{Status, Answer}'
```

- No CAA records at all -> any CA may issue (fine). CAA present WITHOUT
  `letsencrypt.org` -> certbot will always fail for this zone; escalate to Toper
  (fixing CAA is a /cloudflare-dns + Toper decision, not this skill's).

---

## 6. nginx operational rules recap (enforced in SKILL.md)

- `nginx -t && nginx -s reload` - ALWAYS one chain (HR-4). A reload with a broken
  config takes down EVERY vhost on the box, not just yours.
- Config writes: local temp -> scp to `/tmp/<sub>.conf` -> `rsudo cp` into
  sites-available -> remove both temps (HR-2; `sudo tee <<heredoc` clashes with
  `sudo -S` stdin).
- Never touch `sites-available/default` (serves the portfolio apex topengdev.com) or
  any vhost you did not create. After every reload, run the neighbor canary
  (GATE 2 item 6).
