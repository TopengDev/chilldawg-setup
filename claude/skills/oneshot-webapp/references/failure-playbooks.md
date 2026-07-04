# oneshot-webapp - Failure Playbooks (FP-1 .. FP-8)

Symptom -> diagnose -> recover -> verify, each with exact commands and the verified-failure date it
encodes. Connection helpers (`rssh`/`rsudo`/`export SSHPASS`) are defined in `deploy-playbook.md` S1.
All prose is ASCII (no em/en dashes). Never echo `$VPS_HOST`/`$VPS_PASSWORD`/`$CLOUDFLARE_API_TOKEN`.

Jump: nginx broke -> FP-1 | cert failed -> FP-2 | local 000 / DNS page -> FP-3 | wrong title -> FP-4 |
502 -> FP-5 | AI degraded -> FP-6 | ssh timeout -> FP-7 | blank shot / browser wedge -> FP-8.

---

## FP-1 - `nginx -t` FAILED after adding the vhost

Encodes: never leave nginx broken (a broken global config takes down every site on the box).

- Diagnose: read the `nginx -t` output. It names the file + line. Usually a stray brace or a duplicate
  `server_name` from a half-written vhost.
- Recover (remove YOUR objects, restore the last-good config):
  ```bash
  rsudo "rm -f /etc/nginx/sites-enabled/<slug>.topengdev.com /etc/nginx/sites-available/<slug>.topengdev.com"
  rsudo "nginx -t && nginx -s reload"        # must pass now; if not, you touched a foreign vhost -> STOP
  ```
- Verify: `rsudo "nginx -t"` returns `syntax is ok` + `test is successful`; a neighbor still 200s
  (`curl -s -o /dev/null -w '%{http_code}\n' https://hiremeup.topengdev.com`).
- deploy.sh already does this rollback automatically and exits 4. Fix your vhost body, re-run.

---

## FP-2 - certbot failed (NOT a deploy failure)

Encodes: the site is already live on HTTP, and Cloudflare Universal SSL usually already serves HTTPS
at the edge for a first-level subdomain, so a certbot miss is a follow-up, not a rollback.

- Diagnose: common causes are DNS not yet propagated to Let's Encrypt's resolvers, or rate limiting.
- Recover:
  1. Confirm the A record exists + is correct via the authority: `/cloudflare-dns verify <slug>.topengdev.com`.
  2. Confirm public propagation via DoH (see FP-3), then re-run:
     ```bash
     rsudo "certbot --nginx -d <slug>.topengdev.com --non-interactive --agree-tos -m $TOPER_EMAIL --redirect"
     ```
- Verify: `curl -sI --resolve "<slug>.topengdev.com:443:${VPS_HOST}" https://<slug>.topengdev.com | head -1`
  is `HTTP/2 200`. CAA on topengdev.com allows `letsencrypt.org`, so issuance is not blocked by CAA.
- Report `SSL: PENDING (re-run: sudo certbot --nginx -d <slug>.topengdev.com)` in GATE 3, not a failure.

---

## FP-3 - local `curl` returns 000 / qutebrowser shows a DNS-error page

Encodes (verified via /cloudflare-dns S6, 2026-07-03): the local box resolves through a Netbird
resolver (`100.64.0.2`) that lags public DNS by MINUTES for a freshly created record. qutebrowser
uses the same lagging resolver, so a live screenshot can show a DNS error even when the site is up.
This is NOT a deploy failure. Do NOT touch DNS, do NOT redeploy.

- Diagnose + confirm the site is actually live (resolver-lag ladder, in truth order):
  ```bash
  # 1) origin edge, bypassing the local resolver (IP inside --resolve, never printed):
  curl -s -o /dev/null -w '%{http_code}\n' --resolve "<slug>.topengdev.com:443:${VPS_HOST}" "https://<slug>.topengdev.com"
  # 2) public propagation, DoH ONLY (the sole reliable check on this box):
  curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=<slug>.topengdev.com&type=A'
  # 3) for a screenshot, shoot LOCALHOST (the identical build) instead of the lagging live URL.
  ```
- NEVER use `dig` / `host` / `nslookup` (not installed on this box), `resolvectl` (broken), or
  `getent`/the Netbird resolver as a propagation check. DoH is the only truth for public state.
- Verify: origin `--resolve` is 200 AND DoH `Status: 0` with an answer. Then the deploy is good; the
  local resolver will catch up on its own.

---

## FP-4 - wrong / stale `<title>` right after deploy

Encodes: right after deploy the domain can briefly serve a STALE title while Cloudflare/routing settle.

- Diagnose: you grepped the title too fast. Re-grep over the CF edge after a short wait.
  ```bash
  sleep 25
  curl -s --resolve "<slug>.topengdev.com:443:${VPS_HOST}" "https://<slug>.topengdev.com" | grep -oiP '<title>\K[^<]+' | head -1
  ```
- Verify: the served title matches your build's title. Only THEN report the URL. Never announce a URL
  whose content does not match.

---

## FP-5 - 502 Bad Gateway after deploy

Encodes: nginx is up but the upstream container is not answering on the proxied port. The classic
cause is a container/nginx PORT mismatch (the Dockerfile bakes `ENV PORT=3310`; if the chosen port
differs and the container was NOT started with `-e PORT=<port>`, nginx proxies to a dead port).

- Diagnose ladder (bounded, foreground only, never stream/background docker logs, HR-11):
  ```bash
  rssh "docker ps -a --filter name=<slug>-app"                              # is it Up, or Exited/Restarting?
  rssh "docker inspect -f 'restart={{.HostConfig.RestartPolicy.Name}} port_env={{range .Config.Env}}{{println .}}{{end}}' <slug>-app" | grep -i 'restart\|PORT'
  rssh "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>"   # does the container answer on <port>?
  rssh "docker logs --tail 50 --since 10m <slug>-app"                       # BOUNDED; then sweep leaked streams:
  rssh "ps -eo pid,etime,args | grep 'docker logs' | grep -v grep"          # kill any orphaned stream
  ```
- Recover: re-run the container WITH the runtime port override (deploy.sh does this by default now):
  ```bash
  rssh "docker rm -f <slug>-app 2>/dev/null; docker run -d --name <slug>-app --restart unless-stopped \
    -e PORT=<port> -p 127.0.0.1:<port>:<port> --env-file ~/apps/<slug>/.env <slug>-app:latest"
  ```
- Verify: `rssh "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:<port>"` -> 200, then the
  public/origin check is 200.

---

## FP-6 - the AI demo silently degraded to fallback mode

Encodes hiremeup's #1 verified failure (2026-05-24): OpenRouter pre-authorizes the full `max_tokens`
reservation at request time, so a low balance 402s on PRE-FLIGHT even when actual usage is affordable.
The deterministic fallback then MASKS it, so the demo runs on canned output with no error on screen.

- Diagnose: check which path served (the fallback wrapper must log a served-path line, per HR-15):
  - `served: fallback (reason=http_402)` -> credit depletion. Check the OpenRouter balance
    (openrouter.ai/settings/credits). Top-up is Toper's billing action, you cannot pay for him.
  - `served: fallback (reason=http_401)` -> key rotated/missing. Did a re-deploy wipe
    `~/apps/<slug>/.env`? deploy.sh now PRESERVES it across the source wipe and reuses it when `--env`
    is omitted, so re-upload with `--env <file>` or confirm the preserved file:
    ```bash
    rssh "test -f ~/apps/<slug>/.env && echo present || echo MISSING; stat -c '%a' ~/apps/<slug>/.env 2>/dev/null"
    ```
    Report the file + the fact it is empty/missing, NEVER its contents.
  - `served: fallback (reason=timeout|parse_fail)` -> see llm-demo-recipe.md (terse-output + max_tokens).
- Recover: fix the root cause, then FIRE THE REAL MODEL PATH ONCE live (fallback-only proof is not
  proof), then reset the demo to a clean seed so Toper opens a pristine state.
- Verify: a live request returns `served: model (openrouter)` with real output, then reset the seed.

---

## FP-7 - SSH connection times out / VPS unreachable

Encodes the auto-ban (verified 2026-05-30): aggressive probing (port-scan, ping-flood, rapid retries)
trips a temporary auto-ban on the VPS.

- Diagnose + recover: suspect the auto-ban FIRST. Wait >= 3 minutes, then retry ONCE:
  ```bash
  sshpass -e ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 "$VPS_USER@$VPS_HOST" "echo ok"
  ```
- NEVER scan ports, ping-flood, or hammer retries. If still down after the single retry, report the
  reachability failure and STOP. Do not keep probing (that extends the ban).

---

## FP-8 - blank/black screenshot or browser wedge during localhost QA

Encodes the pegged-dev-server phantom-wedge (agent-browser 10.0): a pegged `next dev` process
masquerades as a browser wedge (Page.navigate timeouts, about:blank tabs, blank shots).

- Diagnose: run `top` FIRST. If `next dev` is pegged (>100% CPU), that is the wedge, not the browser.
  QA against a static build instead:
  ```bash
  npm run build && npx next start -p <localport>     # serve the production build, then screenshot that
  ```
- For a genuinely blank/black shot on a healthy server, follow the /agent-browser blank-shot ladder
  (PB-4: retry, then qb-shoot fallback). For an oversized `--full` shot with content pinned top-left,
  apply the /agent-browser DPR trim (PB-5) ONLY to that `--full` output.
- HARD: all browser evidence goes through the /agent-browser skill and its jump table. NEVER kill the
  live qutebrowser. NEVER use Playwright MCP (hook-banned). NEVER `agent-browser tab new` as the
  primary path (exit 144); use `/claim?url=` on a claimed port (`?from=9223`).
- Verify: a non-blank screenshot of the intended surface at the expected viewport.

---

## Verified-failure index (what each FP protects against)

| FP | Verified failure it encodes | Date |
|----|-----------------------------|------|
| FP-1 | broken nginx config takes down the box | ongoing house rule |
| FP-2 | certbot miss misreported as deploy failure | proven pattern |
| FP-3 | Netbird resolver lag read as "deploy failed" | 2026-07-03 (/cloudflare-dns S6) |
| FP-4 | stale title reported as the live URL | 2026-05-29 |
| FP-5 | container/nginx PORT mismatch -> silent 502 | 2026-07-03 (Dockerfile ENV PORT gap) |
| FP-6 | OpenRouter 402 pre-auth depletion masked by fallback | 2026-05-24 (hiremeup #1) |
| FP-7 | VPS auto-ban from aggressive probing | 2026-05-30 |
| FP-8 | pegged next dev masquerading as a browser wedge | agent-browser 10.0 |
