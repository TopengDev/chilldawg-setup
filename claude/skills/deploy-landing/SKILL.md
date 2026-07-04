---
name: deploy-landing
description: "Deploy an ALREADY-BUILT Next.js landing page (static export or standalone) to Christopher's VPS at a *-landing-page.aenoxa.com subdomain: tar-over-ssh transfer, nginx vhost, DNS via /cloudflare-dns, TLS via certbot, evidence-gated verification and safe rollback. Use when the user says /deploy-landing, 'deploy landing', 'deploy the aenoxa landing page', or hands over a built landing for an aenoxa.com subdomain. NOT for building (that is the build skill's job), NOT for topengdev.com pitch demos (/oneshot-webapp), NOT for git pipelines (/ship)."
argument-hint: <name>-landing-page.aenoxa.com <build-directory>
allowed-tools: Bash, Read, Glob, Grep, Skill
---

# /deploy-landing - built Next.js landing -> live *-landing-page.aenoxa.com

Deploys a locally-built Next.js landing page to Christopher's VPS behind nginx +
Cloudflare + certbot. The VPS is PRODUCTION and house-wide READ-ONLY by default -
this skill is a narrowly-scoped, authorization-gated exception (see GATE 0).

Every remote recipe here matches the VPS reality proven live by
`~/.claude/skills/oneshot-webapp/deploy.sh` (2026-05-29): no rsync on the box,
`sudo -S` password-fed sudo, scp+cp config writes, tar-over-ssh transfer.
Encyclopedic depth lives in `references/` (progressive disclosure):

- `references/vps-facts.md` - dated verified-facts ledger (what is TRUE about this VPS)
- `references/nginx-and-tls.md` - vhost annotations, certbot mechanics, Cloudflare/CAA nuances
- `references/failure-playbooks.md` - FP-1..FP-10 symptom/diagnose/recover/verify playbooks

---

## S0. FAILING NOW? - jump table

| Symptom right now | Go to |
|---|---|
| `sudo: a terminal is required` | **FP-1** (you ran plain sudo - use `rsudo`, S4.1) |
| tar/transfer fails or file counts mismatch | **FP-2** |
| `nginx -t` FAILED | **FP-3** + rollback matrix S8 |
| certbot failed | **FP-4** (NOT a deploy failure - SSL: PENDING) |
| SSH timeout / VPS unreachable | **FP-5** (suspect auto-ban FIRST, wait >=3 min) |
| Port already in use / app won't bind | **FP-6** |
| 502 after deploy | **FP-7** |
| Wrong or stale page content served | **FP-8** (stale-title window, re-check after 30s) |
| Local `curl https://<sub>` returns 000 | **FP-9** (Netbird resolver lag - NOT a failure) |
| VPS rebooted / process gone | **FP-10** (restart-policy outage pattern) |
| `pm2: command not found` | S5.2 STOP branch (never install - ask Toper) |
| Existing config not created by this skill | GATE 1 refusal (S4.2 item 6) |

---

## S1. BOUNDARIES - which skill owns what (cite, never duplicate)

| Task | Owner |
|---|---|
| Deploy an ALREADY-BUILT landing to `*-landing-page.aenoxa.com` (nginx static or node reverse-proxy) | **THIS skill** |
| Build AND deploy a pitch/recruiter demo to `<slug>.topengdev.com` (docker + nginx + certbot, its own `deploy.sh`) | **/oneshot-webapp** - its light-only/single-locale exception NEVER routes through this skill; never mix the two paths |
| Create/verify/delete DNS records on aenoxa.com or topengdev.com | **/cloudflare-dns** - this skill CALLS it (S4.4); never hand-roll Cloudflare curl here |
| git commit/push/release/CI pipeline | **/ship** - moves code through git + CI, never SSHes to the VPS |
| Browser screenshot of the live site | **/agent-browser** skill exclusively - but note its qutebrowser uses the same lagging local resolver, so a DNS-error screenshot proves nothing; `curl --resolve` is the site-up truth (FP-9) |
| The portfolio apex `topengdev.com` (`/var/www/christopher-portfolio`, `sites-available/default`) | christopher-portfolio repo's own `deploy.sh` - NEVER this skill, NEVER touch `default` |

---

## S2. HARD RULES (HR-1..HR-16 - violating any one is a failed run)

- **HR-1 - SCOPE: NEVER touch anything on the VPS outside the 5 scoped objects:**
  1. `/var/www/{SUBDOMAIN}/` (+ its `.prev-<ts>` backups)
  2. `/etc/nginx/sites-available/{SUBDOMAIN}` (+ its `.bak`)
  3. `/etc/nginx/sites-enabled/{SUBDOMAIN}` symlink
  4. the process named `{SUBDOMAIN}` (pm2 process, or the container IF Toper routes standalone via docker)
  5. the `{SUBDOMAIN}` DNS record (via /cloudflare-dns only)
  ALWAYS refuse if SUBDOMAIN fails `^[a-z0-9][a-z0-9-]*-landing-page\.aenoxa\.com$`.
  Never touch another vhost, another /var/www dir, another process, `sites-available/default`, or any `~/apps/*` checkout.
- **HR-2 - NEVER run plain `sudo` over non-interactive SSH** (fails `a terminal is required`, verified 2026-05-29). ALWAYS the rsudo pattern: `echo "$VPS_PASSWORD" | sudo -S -p '' <cmd>` (S4.1). NEVER `sudo tee <<heredoc` (stdin clash with `sudo -S`) - ALWAYS scp to /tmp then `sudo -S cp` (S5.3).
- **HR-3 - NEVER rsync to the VPS.** The VPS has NO rsync binary (verified 2026-05-29 + 2026-06-28). ALWAYS tar-over-ssh: `tar czf - -C "$BUILD_DIR" . | rssh "tar xzf - -C /var/www/$SUBDOMAIN"`.
- **HR-4 - NEVER reload nginx without testing in the SAME chain:** ALWAYS `nginx -t && nginx -s reload` as one command - never two separate calls where a reload can run after a forgotten failed test.
- **HR-5 - NEVER put `${VAR}` inside a QUOTED heredoc destined for a remote shell** (the v1 rollback expanded to `rm -rf /var/www/` - would have deleted every site on the box). ALWAYS expand variables locally, and immediately before ANY destructive remote command run `assert_scoped` (S4.1): target must match `/var/www|/etc/nginx/sites-*/<name>-landing-page.aenoxa.com` non-empty, prefix-anchored - or ABORT.
- **HR-6 - NEVER redeploy over a live page without a remote backup first:** `cp -a /var/www/$SUBDOMAIN /var/www/$SUBDOMAIN.prev-<ts>` + config `.bak`. On redeploy failure ALWAYS restore `.prev` + `.bak` - never delete (S7/S8).
- **HR-7 - ALWAYS ensure the Cloudflare A record exists (via the /cloudflare-dns Skill, S4.4) BEFORE running certbot.** Certbot failure is NEVER a deploy failure - record `SSL: PENDING` + the exact rerun command and continue (FP-4).
- **HR-8 - ALWAYS connect gently:** one SSH at a time, `-o StrictHostKeyChecking=accept-new -o ConnectTimeout=12`. On timeout: wait >=3 minutes, retry ONCE. NEVER port-scan, ping-flood, or nmap the VPS - aggressive probing triggers a temporary auto-ban (verified 2026-05-30, FP-5).
- **HR-9 - NEVER run `docker logs` / `docker events` / any streaming docker-cli through timeout-wrapped or backgrounded SSH** while debugging a deploy (orphaned streams spin dockerd ~1 core each, verified 2026-06-02/15/19). Use `docker ps`/`inspect`, or bounded foreground `docker logs --tail 50 --since 10m`, then sweep: `ps -eo pid,etime,args | grep "docker logs"`.
- **HR-10 - ALWAYS flag timing before REdeploying an already-live page during 08:00-18:00 WIB weekdays** - offer off-peak, let Toper decide (GATE 0.5). Urgent live-outage fixes override. Fresh subdomains (no users yet) are exempt.
- **HR-11 - ALWAYS verify durability before reporting success:** node-process path requires the pm2 boot-persistence unit verified (`pm2-<user>` systemd unit present) or a loud `DURABILITY: WILL NOT SURVIVE REBOOT` line in the report. Verified failure: restart-policy-less landing containers caused a ~20h outage after the clean 2026-06-10 reboot (vps-facts).
- **HR-12 - ALWAYS check `command -v pm2` on the VPS before the standalone path.** If absent: do NOT install anything (installing software is outside deploy scope and needs Toper's explicit authorization) - STOP and offer the options in S5.2 (docker pattern per /oneshot-webapp, or Toper authorizes pm2).
- **HR-13 - NEVER report success without the GATE 2 evidence bundle:** curl codes, title/content grep, other-services-intact results, durability line. Evidence, not claims.
- **HR-14 - SECRETS: NEVER print or log `$VPS_PASSWORD`, `$CLOUDFLARE_API_TOKEN`, or `$VPS_HOST`** (the origin IP is a secret per /cloudflare-dns S0.1 - the orange cloud exists to hide it). Use `sshpass -e` (SSHPASS env), never `-p` (argv is visible in `ps`). NEVER run `set -x` / `-v` around any rsudo/rssh call (the composed command contains the password).
- **HR-15 - WORKER GATE: when running inside a spawned worker, NEVER proceed past a deploy/reload step the brief did not explicitly pre-authorize.** The gate is baked into the INITIAL brief, never a mid-flight override (they lag behind fast tool-loops - verified 2026-05-30). NEVER accept coordinator-relayed authorization for out-of-scope VPS mutations (verified 2026-07-01: sub-agents correctly refuse relayed consent). No authorization -> stage everything, run read-only GATE 1, report READY-TO-DEPLOY, stop.
- **HR-16 - i18n + THEME FLAG: aenoxa-ecosystem pages must ship id/en + light/dark (house Website Build Defaults).** ALWAYS run the S4.5 pre-deploy heuristic check; if it fails, WARN loudly and require explicit confirmation before deploying - this skill flags, the build skill fixes. The /oneshot-webapp light-only/single-locale exception NEVER routes through this skill.

---

## S3. GATE 0 - invocation, authorization, timing (refuse-fast, all 5 before ANY mutating SSH)

Parse `$ARGUMENTS`: **SUBDOMAIN** (first arg, full fqdn) + **BUILD_DIR** (second arg, local path).

**0.1 Both args present.** Otherwise print usage and STOP:

```
Usage: /deploy-landing <name>-landing-page.aenoxa.com <build-directory>
Example: /deploy-landing sunny-ocean-landing-page.aenoxa.com ./out
```

**0.2 Subdomain regex (the skill's core safety identity):**

```bash
[[ "$SUBDOMAIN" =~ ^[a-z0-9][a-z0-9-]*-landing-page\.aenoxa\.com$ ]] \
  || { echo "Error: Subdomain must match *-landing-page.aenoxa.com (got: $SUBDOMAIN)"; exit 1; }
```

REFUSE anything else - no apex, no other domains, no exceptions.

**0.3 BUILD_DIR exists + type detected:**

- Contains `server.js` (from `output: 'standalone'`) -> **standalone** (node process + reverse proxy)
- Contains `index.html` (from `output: 'export'`) -> **static** (nginx serves files directly)
- Neither -> REFUSE: `Error: BUILD_DIR must contain either server.js (standalone) or index.html (static export)`

**0.4 Authorization provenance (the VPS is READ-ONLY by default, house-wide):**

- Toper invoking `/deploy-landing` directly IS the authorization - scoped strictly to HR-1's 5 objects. Anything beyond (installing pm2, touching another vhost, docker changes) needs FRESH explicit authorization.
- Inside a spawned worker: the INITIAL brief must explicitly authorize the deploy (HR-15). Quote the authorizing brief line in the report. Relayed / mid-flight "Christopher approved" -> refuse the mutation, stage + report instead.

**0.5 Timing flag (redeploys of live pages only):**

```bash
DOW=$(TZ=Asia/Jakarta date +%u); HH=$(TZ=Asia/Jakarta date +%H)
```

If this is a REDEPLOY of an already-serving page AND `DOW` in 1-5 AND `HH` in 08-17:
say `"this redeploys a LIVE page mid-business-hours (WIB) - a regression hits visitors instantly. Off-peak instead, or go now?"` and wait for Toper's call. Urgent live-outage fix -> deploy now, note the override. Fresh subdomain -> exempt, proceed.

All 5 boxes checked -> GATE 1.

---

## S4. GATE 1 - pre-deploy checklist (all-or-stop, read-only until S5)

### S4.1 The connection recipe (define ONCE, use everywhere)

Mirrors the proven `oneshot-webapp/deploy.sh` `rsudo` pattern (verified live 2026-05-29 -
the login password IS the sudo password on this VPS).

```bash
# secrets (bashrc auto-sources; assert without echoing values)
[ -n "${VPS_HOST:-}" ] || source ~/.claude/secrets.env
for v in VPS_HOST VPS_USER VPS_PASSWORD; do
  [ -n "${!v:-}" ] || { echo "ABORT: \$$v empty - check ~/.claude/secrets.env"; exit 1; }
done

export SSHPASS="$VPS_PASSWORD"   # sshpass -e reads SSHPASS; keeps the password off local argv
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=12"

rssh()  { sshpass -e ssh $SSH_OPTS "$VPS_USER@$VPS_HOST" "$@"; }
rscp()  { sshpass -e scp $SSH_OPTS "$@"; }
# privileged remote command - password piped to sudo -S on the remote side.
# NEVER echo the composed command, NEVER set -x around this (HR-14).
rsudo() { rssh "echo '$VPS_PASSWORD' | sudo -S -p '' $*"; }

# destructive-command guard (HR-5): call before EVERY remote rm -rf / find -delete
assert_scoped() {
  local t="$1"
  [[ "$t" =~ ^(/var/www|/etc/nginx/sites-available|/etc/nginx/sites-enabled)/[a-z0-9][a-z0-9-]*-landing-page\.aenoxa\.com(\.prev-[0-9-]+|\.bak)?(/.*)?$ ]] \
    && return 0
  echo "ABORT: '$t' is outside the 5-object scope - refusing destructive action"
  return 1
}
```

DON'T: `sshpass -p "$VPS_PASSWORD"` (password on argv) / `StrictHostKeyChecking=no` /
plain `sudo` / `sudo tee <<heredoc` / `${VAR}` in a quoted remote heredoc.
DO: `sshpass -e` / `accept-new` + `ConnectTimeout=12` / `rsudo` / scp+cp / expand locally + `assert_scoped`.

### S4.2 Pre-deploy checklist (quantified - every box or STOP)

1. **Local tools present:** `command -v sshpass tar curl jq` all succeed (all verified present on this box).
2. **Secrets populated:** the S4.1 assert loop passed (values never echoed).
3. **Gentle reachability probe - ONE attempt:** `rssh "echo ok"` returns `ok`.
   Timeout -> FP-5 (wait >=3 min, ONE retry, never scan).
4. **Baseline capture** (feeds GATE 2's other-services-intact check):
   ```bash
   DOCKER_BASELINE=$(rssh "docker ps -q | wc -l")
   curl -s -o /dev/null -w '%{http_code}' -m 12 https://hiremeup.topengdev.com   # expect 200, record it
   ```
5. **Existing-deployment scan:**
   ```bash
   rssh "test -e /etc/nginx/sites-available/$SUBDOMAIN && echo EXISTS || echo FRESH"
   ```
   - `FRESH` -> fresh-deploy path.
   - `EXISTS` -> verify it was created by this skill: `rssh "cat /etc/nginx/sites-available/$SUBDOMAIN"` must contain `server_name $SUBDOMAIN;` and either `root /var/www/$SUBDOMAIN` or a `proxy_pass http://127.0.0.1:` line matching S5.3's templates. Match -> **redeploy protocol S7** (remote backup FIRST). No match -> REFUSE: config exists but was not created by this skill - never overwrite foreign configs.
6. **Foreign-config refusal is absolute** - even if the name matches the regex, a hand-written config on the box is out of scope.
7. **Port pick protocol** (standalone only) -> S4.3.
8. **pm2 existence check** (standalone only): `rssh 'command -v pm2 || echo ABSENT'` -> if `ABSENT`, S5.2 STOP branch NOW (before any mutation).
9. **DNS record gate** -> S4.4.
10. **i18n + theme check** (aenoxa-ecosystem page) -> S4.5.

### S4.3 Port pick protocol (standalone only)

The v1 grep lacked `-o` (printed whole lines -> garbage port list) and only scanned
nginx confs (missed docker/other listeners). Union THREE sources, then pick the first
free port >= 4000 (33xx is the /oneshot-webapp docker convention - the union already
excludes those):

```bash
USED_PORTS=$(rssh "grep -rhoP 'proxy_pass\s+http://127\.0\.0\.1:\K[0-9]+' /etc/nginx/sites-available/ 2>/dev/null;
  (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | awk '{print \$4}' | grep -oP ':\K[0-9]+$';
  docker ps --format '{{.Ports}}' 2>/dev/null | grep -oP '127\.0\.0\.1:\K[0-9]+'" | sort -un)
for p in $(seq 4000 4099); do grep -qx "$p" <<<"$USED_PORTS" || { PORT=$p; break; }; done
[ -n "${PORT:-}" ] || { echo "ABORT: no free port in 4000-4099"; exit 1; }
echo "PORT=$PORT (evidence: $(wc -l <<<"$USED_PORTS") ports in use)"
```

Record the chosen port + the in-use count as GATE 1 evidence. (Remote grep is GNU
grep - `-rhoP` proven by oneshot deploy.sh on this VPS.)

### S4.4 DNS gate - via the /cloudflare-dns Skill (BEFORE certbot, HR-7)

Fresh subdomains never have a record yet (NO wildcard exists on aenoxa.com - house
convention, verified in /cloudflare-dns S0.5), so certbot would always fail without this.

1. Invoke the Skill: `/cloudflare-dns verify $SUBDOMAIN`.
2. `RECORD MISSING` -> `/cloudflare-dns create $SUBDOMAIN`. Its S3 decision table +
   Beacon legacy convention own the proxied flag (historically orange for
   `*-landing-page` records per reference_cloudflare); record the class it reports.
3. `RECORD WRONG` -> let /cloudflare-dns propose the fix; do not hand-roll.
4. Do NOT wait for full propagation here - /cloudflare-dns's DoH box has a 120s
   budget, and the origin `--resolve` checks in GATE 2 are DNS-independent anyway.
   Note: with a PROXIED record, Cloudflare Universal SSL already serves edge HTTPS
   for first-level subdomains (all `*-landing-page` names are one label deep) even
   before the origin cert exists - details in `references/nginx-and-tls.md`.

NEVER curl the Cloudflare API directly from this skill - /cloudflare-dns owns the
guardrails (zone gate, proxied table, verify-after-write, secret hygiene).

### S4.5 i18n + theme pre-deploy check (aenoxa-ecosystem pages, HR-16)

Cheap local heuristics on BUILD_DIR (WARN-only - this skill flags, the build skill fixes):

```bash
# locale artifacts (static export: /id + /en route dirs; standalone: .next server app segments)
ls -d "$BUILD_DIR"/id "$BUILD_DIR"/en >/dev/null 2>&1 \
  || ls -d "$BUILD_DIR"/.next/server/app/id "$BUILD_DIR"/.next/server/app/en >/dev/null 2>&1 \
  || echo "WARN: no id/en locale artifacts found"
# theme tokens in compiled CSS
grep -rlqs -- '--bg\|--background\|color-scheme' "$BUILD_DIR" || echo "WARN: no theme token signals found"
```

Any WARN -> tell the user loudly: *"this build looks English-only / single-theme -
that violates the Aenoxa Website Build Defaults (the exact failure mode that got the
2026-05-24 Pulse landing rejected). Deploy anyway?"* Require an explicit yes.
Heuristics can false-positive on exotic builds - say so, don't hard-block.

---

## S5. DEPLOY PIPELINE (first mutating commands - GATE 0 + 1 must be fully green)

### S5.1 Transfer (tar-over-ssh - HR-3)

```bash
rsudo "mkdir -p /var/www/$SUBDOMAIN && chown $VPS_USER:$VPS_USER /var/www/$SUBDOMAIN"
tar czf - -C "$BUILD_DIR" . | rssh "tar xzf - -C /var/www/$SUBDOMAIN"
```

Verify the transfer landed (verify-after-write - counts must match):

```bash
LOCAL_COUNT=$(find "$BUILD_DIR" -type f | wc -l)
REMOTE_COUNT=$(rssh "find /var/www/$SUBDOMAIN -type f | wc -l")
[ "$LOCAL_COUNT" = "$REMOTE_COUNT" ] || { echo "transfer mismatch: $LOCAL_COUNT local vs $REMOTE_COUNT remote"; }  # -> FP-2
```

(`chown $VPS_USER` - parameterized, never a hardcoded username - lets every later
content operation run unprivileged via `rssh`, least privilege.)

### S5.2 Process start (standalone only - skip entirely for static)

**pm2 branch** (only if S4.2 item 8 found pm2):

```bash
rssh "pm2 delete $SUBDOMAIN 2>/dev/null; cd /var/www/$SUBDOMAIN && PORT=$PORT pm2 start server.js --name $SUBDOMAIN && pm2 save"
sleep 2
rssh "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT"   # expect 200; one retry after 3s; then FP-7
```

**Durability check (HR-11)** - `pm2 save` alone does NOT survive a reboot; a
`pm2 startup` systemd unit must exist:

```bash
rssh "systemctl list-unit-files 'pm2-*' --no-legend --no-pager 2>/dev/null | head -3"
```

Empty -> the report MUST carry `DURABILITY: WILL NOT SURVIVE REBOOT (no pm2 startup
unit - cite the 2026-06-10 ~20h reboot outage)`. Creating the unit = out-of-scope VPS
mutation -> offer it to Toper, never auto-run `pm2 startup`.

**pm2 ABSENT branch (HR-12) - STOP, present options, wait:**

There is NO positive evidence pm2 exists on this VPS - the live landing precedent is
DOCKER containers (wira-duta-indah, sinar-surya - see vps-facts). Options for Toper:
1. Route the standalone build through the proven docker pattern (loopback bind +
   `--restart unless-stopped`) documented in /oneshot-webapp SKILL.md Phase 5 - cite,
   do not duplicate its Dockerfile/vhost content; keep the container named `$SUBDOMAIN`
   to stay inside HR-1's scope.
2. Toper explicitly authorizes installing pm2 (out of deploy scope otherwise).
3. Rebuild as a static export (`output: 'export'`) and take the static path - zero
   process to manage, survives reboots via nginx alone.
Never silently switch architecture; never install anything.

### S5.3 nginx config write (scp + cp - NEVER sudo tee heredoc, HR-2)

Write the config LOCALLY with variables substituted, ship it, copy into place:

**Standalone (reverse proxy)** - substitute `$SUBDOMAIN` + `$PORT`:

```nginx
server {
    server_name {SUBDOMAIN};

    location / {
        proxy_pass http://127.0.0.1:{PORT}/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400;
    }

    listen 80;
    listen [::]:80;
}
```

**Static export** - substitute `$SUBDOMAIN`:

```nginx
server {
    server_name {SUBDOMAIN};

    root /var/www/{SUBDOMAIN};
    index index.html;

    location / {
        try_files $uri $uri.html $uri/ /index.html;
    }

    location /_next/static/ {
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    listen 80;
    listen [::]:80;
}
```

(These two templates are canonical HERE; `references/nginx-and-tls.md` annotates them
line-by-line but never forks the text. HTTP-only on purpose - certbot adds 443.)

```bash
CONF_LOCAL=$(mktemp)
# ... write the chosen template into "$CONF_LOCAL" with real values (Write tool or cat > with an UNQUOTED heredoc locally)
rscp "$CONF_LOCAL" "$VPS_USER@$VPS_HOST:/tmp/$SUBDOMAIN.conf"
rsudo "cp /tmp/$SUBDOMAIN.conf /etc/nginx/sites-available/$SUBDOMAIN && rm -f /tmp/$SUBDOMAIN.conf"
rm -f "$CONF_LOCAL"
rssh "grep -c 'server_name $SUBDOMAIN;' /etc/nginx/sites-available/$SUBDOMAIN"   # verify-after-write: expect 1
```

### S5.4 Enable + test + reload (one chain, HR-4)

```bash
rsudo "ln -sf /etc/nginx/sites-available/$SUBDOMAIN /etc/nginx/sites-enabled/$SUBDOMAIN"
rsudo "nginx -t && nginx -s reload"
```

`nginx -t` fails -> the `&&` guarantees no reload ran -> **FP-3 + rollback matrix S8**.
Stop the pipeline.

### S5.5 TLS via certbot (HR-7 - DNS gate S4.4 already ran)

```bash
rsudo "certbot --nginx -d $SUBDOMAIN --non-interactive --agree-tos --email admin@aenoxa.com --redirect"
```

- Succeeds -> `SSL: YES` (certbot rewrote the vhost with 443 + a 301 redirect;
  auto-renews via `certbot.timer` - mechanics in `references/nginx-and-tls.md`).
- Fails -> **NOT a deployment failure** (the site works over HTTP + Cloudflare edge
  HTTPS may already serve via Universal SSL). Record `SSL: PENDING`, run the FP-4
  checklist (A record? propagation? CAA?), and give the user the exact rerun:
  1. Confirm the record: `/cloudflare-dns verify $SUBDOMAIN`
  2. Re-run: `sudo certbot --nginx -d $SUBDOMAIN` (via rsudo)

---

## S6. GATE 2 - post-deploy evidence checklist (every line fills the report from real output)

Wait 3s for everything to settle, then collect ALL of:

1. **VPS-local check** (DNS-independent; 2 retries x 5s before calling it a failure):
   ```bash
   # standalone:
   rssh "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT"
   # static:
   rssh "curl -s -o /dev/null -w '%{http_code}' --resolve $SUBDOMAIN:80:127.0.0.1 http://$SUBDOMAIN"
   ```
   Expect 200. Not 200 after retries -> FP-7 (standalone) / FP-3 aftermath (static).
2. **Origin check over the public vhost, bypassing DNS** (never blocked by resolver lag):
   ```bash
   # SSL: YES  -> curl -s -o /dev/null -w '%{http_code}' --resolve "$SUBDOMAIN:443:$VPS_HOST" "https://$SUBDOMAIN"
   # SSL: PENDING -> curl -s -o /dev/null -w '%{http_code}' --resolve "$SUBDOMAIN:80:$VPS_HOST" "http://$SUBDOMAIN"
   ```
3. **Edge check:** `curl -s -o /dev/null -w '%{http_code}' -m 12 "https://$SUBDOMAIN"` - record
   the status. `000` locally is NOT failure -> FP-9 (Netbird resolver lag): trust the
   origin check + public DoH (via `/cloudflare-dns verify`), never the local resolver.
4. **Content grep (stale-title gotcha):**
   ```bash
   curl -s --resolve "$SUBDOMAIN:443:$VPS_HOST" "https://$SUBDOMAIN" | grep -oiP '<title>\K[^<]+' | head -1
   ```
   Mismatch vs the built page's title -> MANDATORY wait ~30s + re-check once before
   believing it (Cloudflare/routing settles in ~20-30s post-deploy) -> then FP-8.
5. **Dynamic-segment spot check** (only if the app has dynamic path routes): request one
   real dynamic path. Known trap: an encoded slash `%2F` inside a path segment 404s
   behind nginx + Next standalone even though `next dev` serves it (verified 2026-06-23,
   AURA) - keep segments slash-free; `/` returning 200 does NOT prove such routes work.
6. **Other-services-intact sweep** (did the reload hurt a neighbor?):
   ```bash
   curl -s -o /dev/null -w '%{http_code}' -m 12 https://hiremeup.topengdev.com   # expect 200 (same as baseline)
   rssh "docker ps -q | wc -l"                                                   # expect == $DOCKER_BASELINE
   ```
7. **Durability line** (HR-11): static -> `DURABILITY: OK (nginx/systemd)`. pm2 ->
   unit present or the loud warning. Docker-routed -> `--restart unless-stopped` confirmed
   via `docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' $SUBDOMAIN`.
8. **SSL status:** `YES` or `PENDING (<reason> + rerun command)`.

Ground-truth-before-panic (house rule): if anything above LOOKS failed, check what is
actually serving (origin `--resolve`, `docker ps`, pm2 list) BEFORE escalating or rolling
back - CI-style false alarms and resolver lag are the common case, real outages are not.

Any evidence field empty -> the run may NOT print the success report. Fix or roll back.

---

## S7. REDEPLOY PROTOCOL (existing live page - restore-not-delete semantics)

Triggered by GATE 1 item 5 finding a this-skill config. GATE 0.5 timing flag applies.

1. **Backup FIRST (HR-6):**
   ```bash
   TS=$(date +%Y%m%d-%H%M%S)
   rssh  "cp -a /var/www/$SUBDOMAIN /var/www/$SUBDOMAIN.prev-$TS"
   rsudo "cp /etc/nginx/sites-available/$SUBDOMAIN /etc/nginx/sites-available/$SUBDOMAIN.bak"
   ```
2. **Clear + transfer** (rsync `--delete` semantics without rsync: empty the dir, tar in):
   ```bash
   assert_scoped "/var/www/$SUBDOMAIN" || exit 1
   rssh "find /var/www/$SUBDOMAIN -mindepth 1 -delete"
   tar czf - -C "$BUILD_DIR" . | rssh "tar xzf - -C /var/www/$SUBDOMAIN"
   ```
   + the S5.1 file-count verify.
3. **Restart the process** (standalone): the S5.2 pm2 block (delete + start + save) with
   the SAME port as the existing config unless the config is also changing.
4. **Config**: only rewrite if the template/port changed - then the full S5.3 + S5.4 chain.
   Unchanged config -> still run `rsudo "nginx -t && nginx -s reload"` if anything nginx-visible moved.
5. **GATE 2** in full.
6. **On success:** prune older backups, keep this run's as the restore point:
   ```bash
   for d in $(rssh "ls -d /var/www/$SUBDOMAIN.prev-* 2>/dev/null | grep -v \"$TS\""); do
     assert_scoped "$d" && rssh "rm -rf $d"
   done
   ```
7. **On failure:** rollback matrix S8, redeploy row - RESTORE, never delete.

---

## S8. ROLLBACK - decision matrix + safe worked recipes

All variables expanded LOCALLY. `assert_scoped` before every destructive command (HR-5).

| Situation | Recipe |
|---|---|
| **Fresh deploy, `nginx -t` failed (pre-reload)** | R-A: remove symlink+config, verify nginx, clean files |
| **Fresh deploy, failure after reload** (bad 502 loop, broken app) | R-A + stop the process first |
| **Redeploy, any failure** | R-B: restore `.prev` + `.bak` - NEVER delete the site |

**R-A - fresh-deploy rollback (full cleanup so the next run starts clean):**

```bash
rssh  "pm2 delete $SUBDOMAIN 2>/dev/null; true"                       # standalone only; no-op pre-start
assert_scoped "/etc/nginx/sites-enabled/$SUBDOMAIN"   || exit 1
assert_scoped "/etc/nginx/sites-available/$SUBDOMAIN" || exit 1
rsudo "rm -f /etc/nginx/sites-enabled/$SUBDOMAIN /etc/nginx/sites-available/$SUBDOMAIN"
rsudo "nginx -t && nginx -s reload"                                   # restore nginx health
assert_scoped "/var/www/$SUBDOMAIN" || exit 1
rssh  "rm -rf /var/www/$SUBDOMAIN"                                    # owned by $VPS_USER - no sudo needed
curl -s -o /dev/null -w '%{http_code}' -m 12 https://hiremeup.topengdev.com   # neighbors intact: 200
```

DNS record created this run: LEAVE it (harmless - points at the VPS) and note it in the
report; deletion is /cloudflare-dns's call with its own gates.

**R-B - redeploy rollback (restore the previously-live site):**

```bash
assert_scoped "/var/www/$SUBDOMAIN" || exit 1
rssh  "find /var/www/$SUBDOMAIN -mindepth 1 -delete && cp -a /var/www/$SUBDOMAIN.prev-$TS/. /var/www/$SUBDOMAIN/"
rsudo "cp /etc/nginx/sites-available/$SUBDOMAIN.bak /etc/nginx/sites-available/$SUBDOMAIN"
rsudo "nginx -t && nginx -s reload"
# standalone: restart the OLD build
rssh  "pm2 delete $SUBDOMAIN 2>/dev/null; cd /var/www/$SUBDOMAIN && PORT=$PORT pm2 start server.js --name $SUBDOMAIN && pm2 save"
# MANDATORY re-verify: the OLD site serves again
rssh  "curl -s -o /dev/null -w '%{http_code}' --resolve $SUBDOMAIN:80:127.0.0.1 http://$SUBDOMAIN"   # or 127.0.0.1:$PORT
```

Keep `.prev-$TS` + `.bak` until a later SUCCESSFUL redeploy prunes them (S7 step 6).

After any rollback, report:

```
DEPLOYMENT FAILED - ROLLED BACK
================================
Subdomain:   {SUBDOMAIN}
Mode:        {fresh | redeploy}
Reason:      {what went wrong - verbatim error, e.g. the nginx -t output}
Rolled back: {exact actions taken, per recipe}
Verified:    {old site 200 | nginx healthy | neighbors intact - real curl codes}
DNS record:  {left in place | never created}
================================
```

---

## S9. DEPLOYMENT REPORT (structural gate - NO "done" with any line unfilled)

Every value comes from actual command output captured in GATE 1/2 - never from memory.

```
=================================
  Deploy Landing - Complete
=================================
  Subdomain:     {SUBDOMAIN}
  Build Dir:     {BUILD_DIR}
  Type:          {standalone | static}
  Mode:          {fresh | redeploy (.prev-<ts> pruned/kept)}
  VPS Path:      /var/www/{SUBDOMAIN}/
  Port:          {PORT | N/A for static}
  Process:       {pm2:<name> | docker:<name> | N/A}
  Nginx Config:  /etc/nginx/sites-available/{SUBDOMAIN}
  DNS:           {record id/class from /cloudflare-dns | pre-existing}
  SSL:           {YES | PENDING - <reason> + rerun cmd}
  Durability:    {OK (nginx) | pm2 startup unit present | WILL NOT SURVIVE REBOOT | restart=unless-stopped}
  Timing flag:   {n/a fresh | flagged, Toper chose <x> | urgent override}
  Authorization: {Toper direct | brief line: "<quoted>"}
  i18n/theme:    {OK | WARNED, user confirmed}
  Evidence:
    vps-local:   {code}
    origin:      {code via --resolve}
    edge:        {code | 000 = resolver lag, DoH confirmed via /cloudflare-dns}
    title:       "{served title}" {matched | matched after 30s re-check}
    neighbors:   hiremeup {code}, docker count {n}=={baseline}
  URL:           https://{SUBDOMAIN}
=================================
```

---

## S10. REFERENCES

- `references/vps-facts.md` - the dated verified-facts ledger (read before debugging ANYTHING on the box)
- `references/nginx-and-tls.md` - vhost annotations, certbot/renewal mechanics, Cloudflare Universal SSL / Full(strict) / CAA nuances
- `references/failure-playbooks.md` - FP-1..FP-10 worked playbooks
- Proven deploy lineage (cite, never duplicate): `~/.claude/skills/oneshot-webapp/deploy.sh` + its SKILL.md Phase 5-6
- DNS authority: `~/.claude/skills/cloudflare-dns/SKILL.md`
- House memories encoded here: feedback-prod-deploy-timing, feedback_vps_gentle_connect,
  feedback_no_docker_logs_via_timeout_ssh, feedback_verify_prod_before_ci_panic,
  feedback_verify_after_write, feedback_gate_irreversible_in_brief,
  feedback_subagent_relayed_authorization_wall, project_vps_infra_constraints,
  reference_portfolio_deployment, reference_nextjs_encoded_slash_path_404
- No `scripts/` in this skill yet - the SKILL.md recipes are the source of truth. If a
  `deploy-landing.sh` is added later it MUST mirror oneshot `deploy.sh`'s idempotency
  and the rsudo pattern, and keep every gate (0/1/2) as refuse-fast checks.
