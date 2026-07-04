# Failure playbooks FP-1..FP-10 (deploy-landing)

Each playbook: SYMPTOM -> DIAGNOSE (read-only) -> RECOVER (exact commands) -> VERIFY
-> REPORT wording. All commands use the S4.1 helpers (`rssh`/`rscp`/`rsudo`/
`assert_scoped`) with variables expanded LOCALLY. Never improvise on the prod VPS -
if no playbook fits, stop and report the raw evidence.

---

## FP-1 - `sudo: a terminal is required to read the password`

- **Symptom:** any remote sudo command fails with the terminal-required error.
- **Diagnose:** you ran plain `sudo` over non-interactive ssh. This ALWAYS fails on
  this VPS (vps-facts). Nothing is broken on the box.
- **Recover:** re-run the same command through `rsudo` (S4.1) - it pipes
  `$VPS_PASSWORD` to `sudo -S -p ''` (the login password IS the sudo password).
  If a config write was involved, remember: never `sudo tee <<heredoc` - scp to /tmp
  then `rsudo cp` (S5.3).
- **Verify:** the command's effect landed (re-read the file / re-list the dir).
- **Report:** do not report this as a VPS problem - it is a recipe violation; note it
  was corrected.

## FP-2 - transfer failed / file counts mismatch

- **Symptom:** the tar pipe errors, or `LOCAL_COUNT != REMOTE_COUNT` (S5.1).
- **Diagnose (in order):**
  1. Did you try rsync? The VPS has no rsync (HR-3) - use the tar pipe.
  2. `rssh "ls -la /var/www/$SUBDOMAIN | head"` - dir exists? owned by $VPS_USER?
     (a root-owned dir -> tar extract permission-denied; re-run the S5.1 chown).
  3. Partial extract from a broken pipe (ssh dropped mid-stream)? Count again -
     a re-run of the tar pipe is idempotent (tar overwrites).
  4. `rssh "df -h /"` - disk full is rare (27G+ free historically) but cheap to rule out.
- **Recover:** fix the cause, then re-run the FULL tar pipe (never "patch" a partial
  transfer file-by-file), then re-verify counts.
- **Verify:** counts match AND a spot-file exists: `rssh "test -f /var/www/$SUBDOMAIN/index.html && echo ok"` (static) or `.../server.js` (standalone).
- **Report:** include both counts as evidence.

## FP-3 - `nginx -t` FAILED

- **Symptom:** the S5.4 chain prints a config error and (correctly) never reloads.
- **Diagnose:** `rsudo "nginx -t" 2>&1` - read the exact error + file:line. If the
  error is in YOUR config file, it is your template substitution. If it is in ANOTHER
  file, STOP - the box has a pre-existing broken config; do not "fix" foreign configs
  (HR-1), escalate to Toper with the verbatim error.
- **Recover (your config at fault):** either fix the substitution and re-run
  S5.3 -> S5.4, or roll back per S8 R-A (fresh) / R-B (redeploy).
- **Verify:** `rsudo "nginx -t"` passes; neighbor canary
  `curl -s -o /dev/null -w '%{http_code}' -m 12 https://hiremeup.topengdev.com` -> 200.
- **Report:** ROLLED BACK (or fixed) + the nginx error VERBATIM.

## FP-4 - certbot failed (NOT a deploy failure)

- **Symptom:** S5.5 certbot exits nonzero.
- **Diagnose checklist (in order):**
  1. A record exists? `/cloudflare-dns verify $SUBDOMAIN` (Skill call). Missing ->
     create via /cloudflare-dns, wait for its DoH box, re-run certbot.
  2. Propagation lag? /cloudflare-dns's box 3 has a 120s budget - if API green +
     DoH pending, wait and re-run certbot after DoH is green.
  3. CAA? DoH CAA check in `nginx-and-tls.md` section 5 - aenoxa.com CAA is
     unverified; a CAA that omits letsencrypt.org means certbot can NEVER succeed ->
     escalate.
  4. Vhost actually serving port 80? `curl -s -o /dev/null -w '%{http_code}' --resolve
     "$SUBDOMAIN:80:$VPS_HOST" "http://$SUBDOMAIN"` must be 200 (HTTP-01 goes through
     the live vhost).
- **Recover:** fix the cause, single rerun: `rsudo "certbot --nginx -d $SUBDOMAIN --non-interactive --agree-tos --email admin@aenoxa.com --redirect"`.
- **Verify:** on success `curl -s -o /dev/null -w '%{http_code}' --resolve "$SUBDOMAIN:443:$VPS_HOST" "https://$SUBDOMAIN"` -> 200.
- **Report:** if still failing, `SSL: PENDING (<cause>)` + the exact rerun command +
  the note that the edge likely already serves HTTPS via Universal SSL
  (nginx-and-tls.md section 4). The deploy itself stays SUCCESSFUL.

## FP-5 - SSH timeout / VPS unreachable

- **Symptom:** the GATE 1 probe (or any rssh) times out.
- **Diagnose:** assume a TEMPORARY auto-ban FIRST (verified 2026-05-30 - aggressive
  probing CAUSES the timeout it then misdiagnoses). Cross-check local outbound:
  `timeout 8 bash -c '</dev/tcp/github.com/22' && echo outbound-ok`. Also check the
  Cloudflare edge still serves a proxied site (`curl -I -m 12
  https://hiremeup.topengdev.com` -> 200 proves the origin is alive behind the edge).
- **Recover:** wait >= 3 minutes. Retry ONCE (one gentle ssh). NEVER loop retries,
  never scan ports, never nmap, never ping-flood - that extends the ban. Still dead
  after the single retry + outbound-ok -> report to Toper with the evidence; do NOT
  propose IP whitelisting as the first move.
- **Verify:** `rssh "echo ok"`.
- **Report:** timeline of the two attempts + the outbound/edge cross-checks.

## FP-6 - port collision / app will not bind

- **Symptom:** pm2/node logs `EADDRINUSE`, or the S5.2 local curl gets connection
  refused while the process crash-loops.
- **Diagnose:** who owns the port?
  `rssh "(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep :$PORT"` - and was
  the S4.3 union actually run (all THREE sources)?
- **Recover:** NEVER kill the other listener (it is outside HR-1 scope). Re-run the
  S4.3 protocol, pick the next free port, update BOTH the pm2 start (S5.2) AND the
  proxy_pass in the config (S5.3 -> S5.4 chain again).
- **Verify:** `rssh "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT"` -> 200.
- **Report:** old port, its owner (evidence line), new port.

## FP-7 - 502 after deploy

- **Symptom:** vhost serves 502 (origin or edge).
- **Diagnose (bounded, in order):**
  1. Process up? `rssh "pm2 list"` (or `rssh "docker ps --filter name=$SUBDOMAIN"`).
  2. Port matches? compare the config's proxy_pass port to the started PORT:
     `rssh "grep proxy_pass /etc/nginx/sites-available/$SUBDOMAIN"`.
  3. On-box direct: `rssh "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT"`.
  4. Process logs BOUNDED ONLY: `rssh "pm2 logs $SUBDOMAIN --lines 50 --nostream"`
     (docker: `rssh "docker logs --tail 50 --since 10m $SUBDOMAIN"` FOREGROUND -
     never streaming over timeout-ssh, HR-9; sweep for orphans afterwards).
  5. Crashed at boot? `rssh "test -f /var/www/$SUBDOMAIN/server.js && echo present"`;
     `rssh "node --version"` (standalone needs a Node the build supports).
- **Recover:** up to 3 fix attempts (wrong port -> FP-6; missing files -> FP-2;
  crash -> fix cause + restart via the S5.2 block). Unrecoverable in 3 -> rollback
  per S8 and report.
- **Verify:** GATE 2 items 1-4 all green.
- **Report:** which step found the cause + the bounded log excerpt.

## FP-8 - wrong or stale content served

- **Symptom:** GATE 2 title/content grep does not match the built page.
- **Diagnose:** FIRST suspect the stale-title window - Cloudflare/routing settles
  ~20-30s post-deploy (vps-facts). Wait ~30s, re-grep ONCE via the origin
  (`curl -s --resolve "$SUBDOMAIN:443:$VPS_HOST" "https://$SUBDOMAIN" | grep -oiP '<title>\K[^<]+'`).
  Still wrong -> is nginx serving the right root/proxy? (`rssh "cat /etc/nginx/sites-available/$SUBDOMAIN"`) -
  and does the DEPLOYED file have the expected title?
  (`rssh "grep -o '<title>[^<]*' /var/www/$SUBDOMAIN/index.html"` for static).
- **Recover:** deployed file wrong -> you shipped the wrong BUILD_DIR; re-run the
  transfer with the right build (redeploys: the .prev backup still protects you).
  nginx pointing elsewhere -> S5.3/S5.4 again.
- **Verify:** origin grep matches; then edge grep matches.
- **Report:** never report the URL as live until the content matches (house rule).

## FP-9 - local `curl https://<sub>` returns 000 / browser shows DNS error

- **Symptom:** edge check 000 locally right after a fresh deploy.
- **Diagnose:** this is the Netbird local-resolver lag (vps-facts) - NOT a deploy
  failure. Truth checks:
  1. Origin, DNS-independent: `curl -s -o /dev/null -w '%{http_code}' --resolve "$SUBDOMAIN:443:$VPS_HOST" "https://$SUBDOMAIN"` (port 80 variant if SSL: PENDING).
  2. Public DNS: `/cloudflare-dns verify $SUBDOMAIN` (its DoH box is the only valid
     propagation check on this machine - no dig/host installed).
- **Recover:** nothing to recover if 1+2 are green - the record simply has not
  reached the LOCAL resolver yet. Do not delete/recreate the record, do not redeploy.
- **Verify:** re-try the plain edge curl later; it converges within minutes.
- **Report:** `edge: 000 = local resolver lag; origin <code>; DoH green via /cloudflare-dns` - counts as PASS.

## FP-10 - VPS rebooted / process gone

- **Symptom:** the landing 502s/times out; `rssh "uptime"` shows minutes; pm2 list is
  empty or the container is Exited.
- **Diagnose:** this is the 2026-06-10 pattern (vps-facts): after a clean provider
  reboot, anything without boot persistence (`restart=no` containers, pm2 without a
  startup unit) stays down. Confirm: `rssh "uptime; docker ps -a --filter name=$SUBDOMAIN --format '{{.Names}} {{.Status}}'"` / `rssh "pm2 list"`.
- **Recover (SCOPED - only YOUR process, HR-1):**
  - pm2: the S5.2 start block (`pm2 delete ... ; pm2 start server.js --name $SUBDOMAIN && pm2 save`).
  - docker-routed: `rssh "docker start $SUBDOMAIN"`.
  - The wider fleet (aenoxa stacks, brokers, other landings) is NOT yours to restart -
    data-tier-first recovery is main/Toper's runbook; just flag what you observed.
- **Verify:** GATE 2 items 1-4.
- **Report:** MUST include the durability warning that predicted this
  (`DURABILITY: WILL NOT SURVIVE REBOOT`) + offer the durable fix as a Toper-gated
  follow-up (pm2 startup unit, or `--restart unless-stopped`, or migrate to static).

---

## Cross-cutting reporting rule

Every playbook ends in the S9 report (success) or the S8 rollback report (failure) -
with evidence lines from the ACTUAL commands above. A playbook that "worked" but has
no evidence in the report did not happen (HR-13).
