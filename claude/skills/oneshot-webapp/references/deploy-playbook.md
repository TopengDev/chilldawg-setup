# oneshot-webapp - Deploy Playbook (encyclopedic)

Deep reference for the `<slug>.topengdev.com` deploy. `deploy.sh` is the source of truth for
the SEQUENCE and runs all of this idempotently; this file is the source of truth for the FACTS
and the manual fallback for when the helper hits an edge. Every fact here is dated + verified.
All prose is ASCII (no em/en dashes), per the house prime rule.

Load order at deploy time: run `deploy.sh`. Read this ONLY when a step errors or you must run a
step by hand. For failure symptoms, see `failure-playbooks.md`. For the AI route, `llm-demo-recipe.md`.

---

## 1. Connection recipes (secret-safe, gentle)

House standard (mirrors `/deploy-landing` HR-14 + S3.1; `/cloudflare-dns` S0.1):

```bash
export SSHPASS="$VPS_PASSWORD"                    # sshpass -e reads this; keeps pw OFF local argv
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=12"
rssh()  { sshpass -e ssh  $SSH_OPTS "$VPS_USER@$VPS_HOST" "$@"; }
rscp()  { sshpass -e scp  $SSH_OPTS "$@"; }
# Non-interactive sudo: ssh has no TTY, so feed the login password to `sudo -S` over stdin.
# The login password IS the sudo password on this VPS (verified 2026-05-29).
rsudo() { rssh "echo '$VPS_PASSWORD' | sudo -S -p '' $*"; }
```

HARD hygiene (any violation = a failed run under the house standard):
- NEVER `sshpass -p "$VPS_PASSWORD"` (password lands on local argv, visible in `ps`). Always `-e`.
- NEVER `echo`/`say`/log `$VPS_HOST`, `$VPS_PASSWORD`, or `$CLOUDFLARE_API_TOKEN`. The origin IP
  is a secret (the orange cloud exists to hide it). Use it only inside `curl --resolve` (not printed).
- NEVER `set -x` / `set -v` around any `rsudo`/`rssh` call: the composed command carries the password.
- Gentle connect (`/deploy-landing` HR-8): ONE ssh at a time, `ConnectTimeout=12`. On timeout, wait
  >= 3 minutes and retry ONCE. NEVER port-scan / ping-flood / nmap the box: aggressive probing trips a
  temporary auto-ban (verified 2026-05-30). See FP-7.

Why `rsudo` uses single quotes around the password: it protects the password on the REMOTE shell.
Do not "harden" this into a `printf`/nested-quote variant; the proven form is what `/deploy-landing`
mirrors. NEVER `sudo tee <<heredoc` over ssh: its stdin clashes with `sudo -S`. Always scp the file
to `/tmp` then `rsudo cp` into place.

---

## 2. The proven Dockerfile (from bithour-ops-pm, verified 2026-07-03)

Copy `~/claude/Git/repositories/bithour-ops-pm/Dockerfile`. It is a `node:20-alpine` multi-stage
standalone build. The container is started by `deploy.sh` with `-e PORT=<chosen>`, so the baked
`ENV PORT=3310` is overridden at runtime and you do NOT have to edit the Dockerfile per deploy.

```dockerfile
FROM node:20-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat          # Alpine glibc shim; Next needs it
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build                            # needs output:"standalone" in next.config

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
RUN mkdir -p /app/data && chown nextjs:nodejs /app/data   # writable JSON-file store (Phase 3)
USER nextjs
EXPOSE 3310
ENV PORT=3310
ENV HOSTNAME="0.0.0.0"                        # MUST bind 0.0.0.0 inside the container, not 127.0.0.1
CMD ["node", "server.js"]                     # server.js honors process.env.PORT at runtime
```

Non-negotiable image facts:
- `output: "standalone"` in `next.config.*` or the `.next/standalone` copy fails and the build breaks.
- The runtime process is `node server.js` (Next's generated standalone server), which reads
  `process.env.PORT`. That is WHY `docker run -e PORT=$PORT` works and is the 502-proof fix.
- `HOSTNAME="0.0.0.0"` must stay: server.js binds to it. Bind the loopback on the HOST side (the
  `-p 127.0.0.1:$PORT:$PORT` mapping), never inside the container.
- `/app/data` is created writable for the dependency-free JSON store. Do NOT reach for SQLite/Prisma
  in Alpine (native-binding + migration risk). See SKILL.md Phase 3.

---

## 3. Port pick protocol (3-source union)

`deploy.sh` auto-picks when `--port` is omitted; pass `--port` only to pin one. The free-port scan
unions THREE sources (a host process is invisible to the first two, so all three are required,
matching `/deploy-landing` S4.3):

```bash
USED=$(rssh "grep -rhoP 'proxy_pass\s+http://127\.0\.0\.1:\K[0-9]+' /etc/nginx/sites-available/ 2>/dev/null;
  docker ps --format '{{.Ports}}' | grep -oP '127\.0\.0\.1:\K[0-9]+';
  (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | grep -oP ':\K[0-9]+'" | sort -un)
# first free port in 3310-3399 that is NOT in $USED (grep -qx exact-line match)
```

Convention: the `33xx` range. Known-taken (do NOT reuse): bithour = 3310, hiremeup = 3294. The
container binds `127.0.0.1:<port>` ONLY (loopback) so nginx is the sole ingress.

---

## 4. DNS (deploy.sh owns the ONE automated create; everything else is /cloudflare-dns)

There is NO `*.topengdev.com` wildcard (verified live 2026-07-03, zero wildcards in the zone). Every
subdomain needs its own explicit A record to `$VPS_HOST`, class A = `proxied:true` (orange cloud).
`/cloudflare-dns` S3 explicitly BLESSES `deploy.sh`'s automated proxied create as correct for class A.

- topengdev.com zone id: `6011237924132746c5d8ffeb4132e696` (VERIFIED writable; 12+ one-shot records).
- The aenoxa `$CLOUDFLARE_API_TOKEN` covers this zone (no separate creds).
- `deploy.sh` asserts the POST `.success` or ABORTS (a failed DNS create must not cascade into a
  broken nginx/certbot run), and prints ONLY the `.errors` array (never the response body, whose
  `.result.content` is the origin IP).

Manual DNS work (verify / repair / delete / audit / propagation check) is NOT deploy.sh's job:
route it to `/cloudflare-dns` and its gates. Do NOT hand-roll `curl` against the CF API here. Two
`/cloudflare-dns` facts you will need:
- Token health check is `GET /zones` (S0.2). `GET /user/tokens/verify` is a FALSE NEGATIVE for this
  token, do not use it to "prove the token is dead".
- Propagation is checked ONLY via DoH (`cloudflare-dns.com/dns-query`). `dig`/`host`/`nslookup` are
  NOT installed on this box, `resolvectl` is broken, and `getent`/the Netbird resolver lag. See FP-3.

Reference-only create shape (deploy.sh already does this idempotently, do not run by hand unless the
helper failed and /cloudflare-dns is unavailable):

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/6011237924132746c5d8ffeb4132e696/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
  -d "{\"type\":\"A\",\"name\":\"<slug>.topengdev.com\",\"content\":\"${VPS_HOST}\",\"proxied\":true}"
```

---

## 5. nginx vhost + reload discipline

Write the vhost locally, scp to `/tmp`, `rsudo cp` into `sites-available`, symlink into
`sites-enabled`. HTTP-only first; certbot rewrites it to add 443. Proven body:

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

Reload discipline (HARD): reload ONLY as the single chain `nginx -t && nginx -s reload`. If
`nginx -t` fails, remove YOUR symlink + vhost and reload to restore, never leave nginx broken (this
is FP-1). `deploy.sh` does exactly this rollback on a `-t` failure and exits.

---

## 6. TLS via certbot + Universal SSL

```bash
rsudo "certbot --nginx -d <slug>.topengdev.com --non-interactive --agree-tos -m $TOPER_EMAIL --redirect"
```

certbot rewrites the vhost to add `listen 443 ssl`, the cert paths, and an HTTP->HTTPS 301 redirect,
and auto-renews via `certbot.timer`. CAA on topengdev.com allows `letsencrypt.org`, so issuance works.

certbot failure is NOT a deploy failure (FP-2): the site is live on HTTP and Cloudflare Universal SSL
often already serves HTTPS at the edge for a first-level subdomain. Record `SSL: PENDING`, confirm the
A record via `/cloudflare-dns verify`, and re-run certbot after propagation.

---

## 7. Live verify recipes (truth order: origin > DoH > never local)

The local box resolves via a Netbird resolver that LAGS public DNS by minutes for a fresh record, so
a local `000` or a qutebrowser DNS-error page does NOT mean the deploy failed (HR-13, FP-3).

```bash
# 1) container up + loopback health (on the VPS)
rssh "docker ps --filter name=<slug>-app --format '{{.Names}} {{.Status}} {{.Ports}}'"
rssh "docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' <slug>-app"     # must be unless-stopped
rssh "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:<port>"        # 200

# 2) origin edge check, bypassing the lagging local resolver (IP inside --resolve, never printed)
curl -s -o /dev/null -w '%{http_code}\n' --resolve "<slug>.topengdev.com:443:${VPS_HOST}" "https://<slug>.topengdev.com"   # 200
curl -s --resolve "<slug>.topengdev.com:443:${VPS_HOST}" "https://<slug>.topengdev.com" | grep -oiP '<title>\K[^<]+' | head -1

# 3) public propagation, DoH ONLY (the sole reliable check on this box)
curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=<slug>.topengdev.com&type=A'

# 4) neighbors intact (do NOT disrupt other services)
curl -s -o /dev/null -w '%{http_code}\n' https://hiremeup.topengdev.com     # 200
rssh "docker ps --format '{{.Names}}' | wc -l"                              # compare to baseline count
```

Stale-title window (FP-4): right after deploy the domain can briefly serve a STALE `<title>`
(Cloudflare/routing settling). If the served title is wrong, wait 20-30s and re-grep over the CF edge
BEFORE reporting the URL. Never announce a URL whose content does not match your build.

Dynamic-route trap (FP + reference_nextjs_encoded_slash_path_404): an encoded slash (`%2F`) inside a
Next dynamic path segment 404s behind nginx + standalone even though `next dev` served it. If the demo
has dynamic detail routes over seed data, spot-check ONE live (`/thing/<id>` -> 200) and keep every
seed slug/id slash-free.

---

## 8. Manual full-deploy fallback (when deploy.sh cannot run)

Run these by hand only if the helper is unavailable or wedged on an edge. Same sequence, same facts:

```bash
export SSHPASS="$VPS_PASSWORD"; SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=12"
rssh(){ sshpass -e ssh $SSH_OPTS "$VPS_USER@$VPS_HOST" "$@"; }
rsudo(){ rssh "echo '$VPS_PASSWORD' | sudo -S -p '' $*"; }

# 1. DNS: prefer /cloudflare-dns create <slug>.topengdev.com --proxied (owns manual DNS).
# 2. ship source (tar; VPS has no rsync), PRESERVING an existing .env across the wipe:
rssh "mkdir -p ~/apps/<slug> && find ~/apps/<slug> -mindepth 1 -maxdepth 1 ! -name .env -exec rm -rf {} + 2>/dev/null; true"
tar czf - -C <repo> --exclude=node_modules --exclude=.next --exclude=.git --exclude=data \
  --exclude=.env --exclude=.env.local . | rssh "tar xzf - -C ~/apps/<slug>"
# 2b. env (if any): rscp the file to ~/apps/<slug>/.env then rssh chmod 600.
# 3. build + run (loopback bind, runtime PORT override):
rssh "cd ~/apps/<slug> && docker build -t <slug>-app:latest ."
rssh "docker rm -f <slug>-app 2>/dev/null; docker run -d --name <slug>-app --restart unless-stopped \
  -e PORT=<port> -p 127.0.0.1:<port>:<port> --env-file ~/apps/<slug>/.env <slug>-app:latest"
# 3b. GATE on health BEFORE nginx: rssh curl 127.0.0.1:<port> must be 200 (retry x3, else stop + FP-5).
# 4. vhost: write local -> rscp /tmp -> rsudo cp -> ln -sf -> rsudo "nginx -t && nginx -s reload" (FP-1 on fail).
# 5. TLS: rsudo certbot --nginx -d <slug>.topengdev.com --non-interactive --agree-tos -m $TOPER_EMAIL --redirect
# 6. verify per section 7 (origin --resolve, DoH, neighbors, restart-policy, title).
```

Never disrupt other services. Touch ONLY: the one DNS record, `~/apps/<slug>/`, container
`<slug>-app`, nginx vhost `<slug>.topengdev.com`. Neighbors on the box include hiremeup /
signal-trader / wa-sender / aenoxa(_auth/_iam/_pos/_billing) / bithour / aura / sinarsurya / wiraduta.

---

## Freshness ledger

- Dockerfile / next.config / EXPOSE 3310 / PORT env / HOSTNAME 0.0.0.0: re-read from bithour-ops-pm 2026-07-03.
- No rsync on the VPS: verified 2026-05-29 (alamanda run), re-confirmed via /deploy-landing 2026-07-03.
- topengdev zone id + no-wildcard + class-A-proxied bless: /cloudflare-dns SKILL.md, verified 2026-07-03.
- Netbird resolver lag + DoH-only + dig/host/nslookup missing: /cloudflare-dns S6, verified 2026-07-03.
- Gentle-connect auto-ban 2026-05-30; docker-logs-stream dockerd spin 2026-06-02/15/19 (/deploy-landing HR-8/HR-9).
- Local tooling present (sshpass tar jq curl python3 fuser ss rsync scp): verified 2026-07-03.
