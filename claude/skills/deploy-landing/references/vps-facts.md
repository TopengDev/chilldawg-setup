# VPS verified-facts ledger (deploy-landing)

Dated, sourced facts about Christopher's VPS that this skill's recipes depend on.
Every entry cites where it was verified. Facts here OUTRANK training-data intuition
and the pre-2026-07 version of this skill. Anything marked UNVERIFIED must stay a
runtime preflight check, never an assertion.

Related canonical sources (cite, never fork): `~/.claude/skills/oneshot-webapp/SKILL.md`
(+ `deploy.sh`), `~/.claude/skills/cloudflare-dns/SKILL.md`, memory files named per fact.

---

## Transfer + privilege (pipeline-shaping facts)

### No rsync on the VPS (verified 2026-05-29, re-confirmed 2026-06-28)
- oneshot-webapp alamanda run: rsync transfer failed - the VPS has NO rsync binary;
  `deploy.sh` auto-falls back to tar-over-ssh.
- Independently: christopher-portfolio's `deploy.sh` ships via tar+ssh "because rsync
  is NOT installed on the VPS" (reference_portfolio_deployment, 2026-06-28).
- Consequence: tar-over-ssh is the ONLY transfer path in this skill (HR-3). rsync
  `--delete` semantics = empty the dir (after backup) then tar in (S7 step 2).

### Non-interactive sudo needs the password on stdin (verified 2026-05-29)
- Plain `sudo <cmd>` over non-interactive ssh fails: `sudo: a terminal is required to
  read the password`.
- Working pattern: `echo "$VPS_PASSWORD" | sudo -S -p '' <cmd>` - the LOGIN password
  IS the sudo password on this box (oneshot deploy.sh `rsudo`, verified live).
- `sudo tee <<heredoc` is broken with this pattern (the heredoc and `sudo -S` fight
  over stdin) - config writes go scp-to-/tmp then `sudo -S cp` (S5.3).

### SSH discipline
- House standard: `-o StrictHostKeyChecking=accept-new` (CLAUDE.md VPS access
  pattern). `=no` disables host-key verification entirely - never use it.
- `sshpass -e` (password via SSHPASS env) keeps the password off local argv
  (`sshpass -p` is visible in `ps` - sshpass's own help calls -p "security unwise").
  Verified: sshpass 1.10 on this box supports `-e`.

---

## Connection behavior

### Gentle-connect / temporary auto-ban (verified 2026-05-30)
- Aggressive probing (ICMP + multi-port 22/80/443 loops) from a non-home IP triggered
  a TEMPORARY auto-ban that was then misdiagnosed as a "Cloudflare-only firewall
  whitelist". Retry minutes later connected fine.
- Protocol: ONE gentle ssh with `ConnectTimeout=12` at a time. On timeout wait >=3
  minutes, retry ONCE. Cross-check `github.com:22` reachability to rule out a local
  outbound problem. Never nmap/ping-flood/port-scan; never ask Toper to "whitelist an
  IP" as the first move. (feedback_vps_gentle_connect)

### Local resolver lag (verified 2026-05-29, re-verified in /cloudflare-dns 2026-07-03)
- This machine resolves via a Netbird resolver (100.64.0.2) that lags MINUTES
  behind public DNS for fresh records. A local `curl https://<sub>` returning 000
  right after a deploy does NOT mean failure.
- qutebrowser (the /agent-browser stack) uses the SAME lagging resolver - a live
  screenshot showing a DNS error proves nothing about the deploy.
- Truth order: origin `curl --resolve <sub>:443:$VPS_HOST` > public DoH (via
  `/cloudflare-dns verify`) > (never) the local resolver. `dig`/`host`/`nslookup` are
  NOT installed on this box (cloudflare-dns S1) - DoH is the only propagation check.

---

## Post-deploy behavior

### Stale-title window (~20-30s, verified 2026-05-29)
- Right after a deploy the domain can briefly serve a STALE page/title while
  Cloudflare/routing settles. Content-grep mismatch -> wait ~30s, re-check ONCE before
  believing it (oneshot Phase 6.3). Never report a URL until the content matches.

### Encoded-slash %2F path 404 (verified 2026-06-23, AURA)
- A `%2F` inside a dynamic path segment 404s behind nginx + Next standalone even
  though `next dev` serves it - the request dies before the route handler. `/`
  returning 200 does not prove dynamic routes work. Keep path segments slash-free
  (slugify before pathing). (reference_nextjs_encoded_slash_path_404)

---

## Process durability (the reboot outage pattern)

### Clean provider reboot 2026-06-10 -> ~20h outage (verified 2026-06-11)
- The VPS had a clean, provider-side maintenance reboot (23 min down). Everything
  with `restart: unless-stopped`/`always` came back. Everything with `restart=no` -
  including the LANDING-PAGE containers `wira-duta-indah` and `sinar-surya` - stayed
  down ~20h until manually restored.
- Consequences for this skill (HR-11):
  - docker-routed standalone: `--restart unless-stopped` is mandatory; verify via
    `docker inspect -f '{{.HostConfig.RestartPolicy.Name}}'`.
  - pm2-routed standalone: `pm2 save` WITHOUT a `pm2 startup` systemd unit
    (`pm2-<user>.service`) does not survive reboot -> loud report warning.
  - static: nginx is systemd-managed, survives on its own.
- Recovery order on the box after a reboot is data-tier-first (postgres/rabbitmq/minio
  -> apps) but that fleet is NOT this skill's job: restart ONLY your scoped process,
  then file the durability warning. (project_vps_infra_constraints)

### pm2 presence: UNVERIFIED (as of 2026-07-03)
- Zero positive evidence pm2 exists on the VPS. The live landing precedent is docker
  containers; the proven deploy lineage (oneshot/hiremeup/bithour/portfolio) is docker
  or static nginx. `command -v pm2` is a mandatory GATE 1 runtime check; ABSENT ->
  S5.2 STOP branch (never install, never silently switch to docker).

---

## Diagnostics discipline

### Orphaned `docker logs` spins dockerd (verified 2026-06-02, recurred 06-15 + 06-19)
- `docker logs` through a timeout-wrapped/backgrounded SSH orphans the remote process
  when the client dies; each stuck stream spins dockerd ~1 full core (observed 200%+
  and 338%). `docker logs --tail N` even WITHOUT `-f` HANGS on a PAUSED container.
- For deploy debugging: `docker ps` / `docker inspect` / bounded FOREGROUND
  `docker logs --tail 50 --since 10m`. Afterwards sweep:
  `ps -eo pid,etime,args | grep "docker logs"` and kill hour-old leftovers.
  (feedback_no_docker_logs_via_timeout_ssh)

### "The box is slow" - check CPU steal FIRST (verified 2026-05-31)
- Hostinger applies a usage-triggered hypervisor CPU throttle: `top` showing high `st`
  (steal, observed 62.6%) means the provider is throttling the whole box - local
  restarts/wipes will NOT fix it and heavy retries make it worse. Deploys/builds crawl
  under throttle; don't re-run them while `st` is high.
- `/run` tmpfs (796M) can intermittently fill from a healthcheck .pid leak
  (aenoxa-auth outbox-relayer) - unrelated to landing deploys; don't touch it, it is
  outside HR-1 scope. (project_vps_infra_constraints)

### Ground truth before panic (verified 2026-05-17)
- A "failed" signal (CI red, one bad curl) does not mean prod is down - auto-retries,
  resolver lag, and stale reads all false-alarm. 2-line triage BEFORE escalating:
  what does origin `--resolve` serve? what does `docker ps`/pm2 list show?
  (feedback_verify_prod_before_ci_panic)

---

## Box identity + do-not-disrupt

### Hardware / OS (last verified snapshots)
- 4 vCPU, 15.6GB RAM (upgraded 2026-05-31 from 2 vCPU / 7.8GB), Debian
  (kernel 6.1.0-49-cloud), Hostinger (srv906234.hstgr.cloud). Disk `/` ~99G.
- 5 self-hosted GitHub runners live on the box (pos_web, dashboard, billing, auth,
  landing_page) - CI load shares the same cores as your deploy.

### Do-not-disrupt service list (verified 2026-05-29, oneshot)
Never touch, and verify intact after every nginx reload (GATE 2 item 6):
hiremeup, signal-trader, wa-sender, aenoxa(_auth/_iam/_pos/_billing), bithour,
sinarsurya, wiraduta, the portfolio apex (`/var/www/christopher-portfolio` via
`sites-available/default` - reference_portfolio_deployment), and every `~/apps/*`
checkout. Canary: `curl -I https://hiremeup.topengdev.com` -> 200.

### DNS zone facts (owned by /cloudflare-dns - summary only)
- NO wildcard records exist on aenoxa.com or topengdev.com; every subdomain gets its
  own A record (cloudflare-dns S0.5, verified 2026-07-03).
- `$CLOUDFLARE_API_TOKEN` covers both zones. `$VPS_HOST` (the origin IP) is itself a
  secret - never print it (cloudflare-dns S0.1).
- `*-landing-page.aenoxa.com` is the legacy Beacon SaaS naming convention
  (project_landing_page_saas); /cloudflare-dns keeps the legacy pairing in its
  references and owns record creation.

### UNVERIFIED as of 2026-07-03 (keep as runtime checks, never assert)
- pm2 presence (above), current sudoers policy details, aenoxa.com CAA records
  (check via DoH before blaming certbot - see nginx-and-tls.md), current
  sites-available inventory. Re-verify at GATE 1 every run.
