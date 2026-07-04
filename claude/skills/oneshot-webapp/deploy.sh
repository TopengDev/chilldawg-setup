#!/usr/bin/env bash
# oneshot-webapp deploy helper - ship a Next.js (standalone) app to <slug>.topengdev.com
# Replicates the proven bithour-ops-pm / Selaras deploy (verified live 2026-05-29;
# re-confirmed by the wave-2 rebuilds of /deploy-landing + /cloudflare-dns 2026-07-03).
# Idempotent: safe to re-run. Owns exactly ONE automated Cloudflare create (class A,
# proxied) - every MANUAL DNS op (verify/repair/delete/audit) belongs to /cloudflare-dns.
#
# Usage:
#   bash deploy.sh <slug> <local-repo-dir> [--env <local-env-file>] [--port <port>] [--email <certbot-email>]
#
# Example:
#   bash deploy.sh acme-invoicing ~/claude/Git/repositories/acme-invoicing --env ./.env.local
#
# Requires (auto-sourced from ~/.claude/secrets.env via ~/.bashrc):
#   $VPS_HOST $VPS_USER $VPS_PASSWORD $CLOUDFLARE_API_TOKEN
# Touches ONLY: Cloudflare A record <slug>.topengdev.com, ~/apps/<slug>/, docker container <slug>-app,
#               nginx vhost <slug>.topengdev.com. Never other services.
#
# SECRET HYGIENE (house standard, /deploy-landing HR-14 + /cloudflare-dns S0.1):
#   - $VPS_HOST (the origin IP) is itself a SECRET - the orange cloud exists to hide it.
#     This script NEVER echoes it. It is used only inside `curl --resolve` args (not printed).
#   - sshpass reads the password from the SSHPASS env (`-e`), never from argv (`-p` is
#     visible in `ps`). NEVER add `set -x`/`-v`: the composed rsudo command carries the password.

set -euo pipefail

# ---- args ----
SLUG="${1:-}"; REPO="${2:-}"; shift $(( $# >= 2 ? 2 : $# )) || true
ENV_FILE=""; PORT=""; EMAIL="$TOPER_EMAIL"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)   ENV_FILE="$2"; shift 2 ;;
    --port)  PORT="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SLUG" || -z "$REPO" ]]; then
  echo "Usage: bash deploy.sh <slug> <local-repo-dir> [--env <file>] [--port <port>] [--email <addr>]" >&2
  exit 2
fi
[[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "slug must be lowercase/hyphen only (got: $SLUG)" >&2; exit 2; }
[[ -d "$REPO" ]] || { echo "repo dir not found: $REPO" >&2; exit 2; }
: "${VPS_HOST:?}"; : "${VPS_USER:?}"; : "${VPS_PASSWORD:?}"; : "${CLOUDFLARE_API_TOKEN:?}"

DOMAIN="${SLUG}.topengdev.com"
ZONE_ID="6011237924132746c5d8ffeb4132e696"   # topengdev.com (aenoxa token covers it; /cloudflare-dns S1)
VPS_IP="$VPS_HOST"                            # used ONLY in `curl --resolve` below; never echoed (secret)

# Gentle connect (/deploy-landing HR-8): ConnectTimeout so a hung box fails fast instead of
# hammering. sshpass -e reads SSHPASS (below) - keeps the password OFF local argv (HR-14).
export SSHPASS="$VPS_PASSWORD"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=12"
SSH="sshpass -e ssh $SSH_OPTS ${VPS_USER}@${VPS_HOST}"
RSYNC_SSH="ssh $SSH_OPTS"

say(){ printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
# Run a command on the VPS with sudo, feeding the login password to `sudo -S` over stdin.
# Non-interactive ssh has no TTY, so plain `sudo` prompts fail ("a terminal is required").
# Verified on this VPS: the login password IS the sudo password (2026-05-29). The password
# transits the encrypted SSH channel inside the remote command - never on LOCAL argv, and
# this script never echoes it (do NOT `set -x` near this). This is the proven pattern that
# /deploy-landing mirrors; do not "harden" it into breakage.
rsudo(){ $SSH "echo '$VPS_PASSWORD' | sudo -S -p '' $*"; }

# ---- next.config standalone sanity ----
if ! grep -rqs 'standalone' "$REPO"/next.config.* 2>/dev/null; then
  echo "WARNING: next.config does not contain 'standalone' - the Docker build needs output:'standalone'." >&2
fi
[[ -f "$REPO/Dockerfile" ]] || { echo "no Dockerfile in $REPO - copy bithour-ops-pm/Dockerfile and set its PORT first." >&2; exit 3; }

# ---- pick a free port if not given (3-source union: nginx proxy_pass + docker + ss -tln) ----
# The container is started with `-e PORT=$PORT` below, so a runtime PORT override makes the
# baked Dockerfile ENV PORT irrelevant - but the loopback port must still be free on the host.
if [[ -z "$PORT" ]]; then
  say "Picking a free loopback port (33xx)"
  USED=$($SSH "grep -rhoP 'proxy_pass\s+http://127\.0\.0\.1:\K[0-9]+' /etc/nginx/sites-available/ 2>/dev/null;
    docker ps --format '{{.Ports}}' | grep -oP '127\.0\.0\.1:\K[0-9]+';
    (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | grep -oP ':\K[0-9]+'" 2>/dev/null | sort -un || true)
  for p in $(seq 3310 3399); do
    if ! grep -qx "$p" <<<"$USED"; then PORT="$p"; break; fi
  done
  [[ -n "$PORT" ]] || { echo "no free port found in 3310-3399" >&2; exit 3; }
fi
say "slug=$SLUG  domain=$DOMAIN  port=$PORT  repo=$REPO"

# ---- 1. Cloudflare A record (idempotent, class A = proxied; /cloudflare-dns S3 blesses this) ----
say "Ensuring Cloudflare A record $DOMAIN (proxied, points_at_vps)"
EXISTING=$(curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${DOMAIN}" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['result'][0]['id'] if d.get('result') else '')" 2>/dev/null || true)
if [[ -z "$EXISTING" ]]; then
  # Assert .success or ABORT (a failed DNS create must not cascade into a broken nginx/certbot run).
  CF_RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
    -d "{\"type\":\"A\",\"name\":\"${DOMAIN}\",\"content\":\"${VPS_IP}\",\"proxied\":true}" || true)
  CF_OK=$(printf '%s' "$CF_RESP" | python3 -c "import sys,json
try: print('1' if json.load(sys.stdin).get('success') else '0')
except Exception: print('0')" 2>/dev/null || echo 0)
  if [[ "$CF_OK" != "1" ]]; then
    # Print ONLY the .errors array - never the full response (its .result.content is the origin IP).
    ERRS=$(printf '%s' "$CF_RESP" | python3 -c "import sys,json
try: print(json.dumps(json.load(sys.stdin).get('errors')))
except Exception: print('(unparseable response)')" 2>/dev/null || echo '(error)')
    echo "  CF A record create FAILED: $ERRS" >&2
    echo "  route manual DNS work through /cloudflare-dns (owns verify/repair)." >&2
    exit 4
  fi
  echo "  created (proxied)"
else
  echo "  already exists ($EXISTING) - leaving as-is"
fi

# ---- 2. ship source to VPS (build happens in-container) ----
# This VPS has NO rsync (verified 2026-05-29 + re-confirmed by /deploy-landing 2026-07-03),
# so the tar-over-ssh fallback ALWAYS fires here. Both branches PRESERVE a server-side .env:
#   - rsync: `.env` is excluded from the transfer, and rsync --delete PROTECTS excluded files.
#   - tar:   we delete the old source tree EXCEPT `.env` (never a blanket `rm -rf ~/apps/$SLUG`).
# Rationale: an AI demo whose ~/apps/<slug>/.env got wiped silently degrades to fallback mode
# FOREVER (no key -> every model call 402/401 -> the deterministic fallback masks it). See FP-6.
say "Syncing source to ~/apps/$SLUG (excluding node_modules/.next/.git/data/.env*, preserving .env)"
if command -v rsync >/dev/null 2>&1 && $SSH "command -v rsync >/dev/null 2>&1"; then
  $SSH "mkdir -p ~/apps/$SLUG"
  sshpass -e rsync -az --delete -e "$RSYNC_SSH" \
    --exclude node_modules --exclude .next --exclude .git --exclude data \
    --exclude '.env' --exclude '.env.local' \
    "$REPO"/ "${VPS_USER}@${VPS_HOST}:~/apps/$SLUG/"
else
  echo "  rsync unavailable on one end - using tar-over-ssh fallback"
  # Wipe the old source tree but KEEP an existing .env across the wipe (never blanket rm -rf).
  $SSH "mkdir -p ~/apps/$SLUG && find ~/apps/$SLUG -mindepth 1 -maxdepth 1 ! -name .env -exec rm -rf {} + 2>/dev/null; true"
  tar czf - -C "$REPO" \
    --exclude=node_modules --exclude=.next --exclude=.git --exclude=data \
    --exclude=.env --exclude=.env.local --exclude=tsconfig.tsbuildinfo . \
    | $SSH "tar xzf - -C ~/apps/$SLUG"
fi

# ---- 2b. env file (secrets, server-side only) ----
# Precedence: an explicit --env upload WINS; else reuse the preserved server-side .env; else none.
if [[ -n "$ENV_FILE" ]]; then
  [[ -f "$ENV_FILE" ]] || { echo "env file not found: $ENV_FILE" >&2; exit 3; }
  say "Uploading env file (chmod 600, server-side only)"
  sshpass -e scp $SSH_OPTS "$ENV_FILE" "${VPS_USER}@${VPS_HOST}:~/apps/$SLUG/.env"
  $SSH "chmod 600 ~/apps/$SLUG/.env"
  ENVFLAG="--env-file ~/apps/$SLUG/.env"
elif $SSH "test -f ~/apps/$SLUG/.env"; then
  say "Reusing preserved server-side ~/apps/$SLUG/.env (no --env passed this run)"
  echo "  (a prior deploy's env survived the source wipe - the LLM key is intact; chmod 600 re-asserted)"
  $SSH "chmod 600 ~/apps/$SLUG/.env"
  ENVFLAG="--env-file ~/apps/$SLUG/.env"
else
  ENVFLAG=""
  echo "  (no --env given and no existing server-side .env; container runs without an env-file)"
fi

# ---- 3. docker build + run (loopback-only bind, runtime PORT override) ----
say "Building image ${SLUG}-app:latest on the VPS"
$SSH "cd ~/apps/$SLUG && docker build -t ${SLUG}-app:latest ."
say "Running container ${SLUG}-app on 127.0.0.1:${PORT}"
# `-e PORT=$PORT` makes Next standalone's server.js listen on the CHOSEN port at runtime, so a
# port that differs from the Dockerfile's baked ENV PORT (e.g. 3310) can NEVER cause a 502
# (nginx proxies to $PORT and the container listens on $PORT). HOSTNAME=0.0.0.0 is baked.
$SSH "docker rm -f ${SLUG}-app 2>/dev/null; docker run -d --name ${SLUG}-app --restart unless-stopped -e PORT=${PORT} -p 127.0.0.1:${PORT}:${PORT} ${ENVFLAG} ${SLUG}-app:latest"

# ---- 3b. GATE: container health on loopback BEFORE we touch nginx/certbot ----
# A silent 502 must be caught here, not after we have rewritten nginx + issued a cert.
say "Waiting for container health on 127.0.0.1:${PORT} (3 attempts, then ABORT)"
HEALTHY=0
for i in 1 2 3; do
  sleep 3
  CODE=$($SSH "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${PORT}" 2>/dev/null || echo 000)
  echo "  attempt $i: $CODE"
  [[ "$CODE" =~ ^(2[0-9][0-9]|3[0-9][0-9])$ ]] && { HEALTHY=1; break; }
done
if [[ "$HEALTHY" != "1" ]]; then
  echo "  container NOT healthy on 127.0.0.1:${PORT} after 3 attempts - ABORTING before nginx/certbot." >&2
  echo "  diagnose (bounded, foreground only - never stream/background docker logs, /deploy-landing HR-9):" >&2
  echo "    $SSH 'docker ps -a --filter name=${SLUG}-app'" >&2
  echo "    $SSH 'docker logs --tail 50 --since 10m ${SLUG}-app'" >&2
  echo "  common cause: image listens on a different port - this run passes -e PORT=${PORT}, so rebuild if you edited the Dockerfile ENV." >&2
  exit 4
fi

# ---- 4. nginx vhost (HTTP first; certbot adds TLS) ----
# Build the vhost locally, scp to /tmp on the VPS, then `sudo cp` into place.
# (A `sudo tee <<heredoc` over ssh competes with `sudo -S` for stdin - avoid it.)
say "Writing nginx vhost + enabling"
VHOST_TMP="$(mktemp)"
cat > "$VHOST_TMP" <<NGINXEOF
server {
    server_name ${DOMAIN};
    client_max_body_size 5M;
    location / {
        proxy_pass http://127.0.0.1:${PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
        proxy_read_timeout 86400;
    }
    listen 80;
    listen [::]:80;
}
NGINXEOF
sshpass -e scp $SSH_OPTS "$VHOST_TMP" "${VPS_USER}@${VPS_HOST}:/tmp/${DOMAIN}.vhost"
rm -f "$VHOST_TMP"
rsudo "cp /tmp/${DOMAIN}.vhost /etc/nginx/sites-available/${DOMAIN}"
rsudo "ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}"

say "Testing nginx config"
if ! rsudo "nginx -t" 2>&1; then
  echo "  nginx -t FAILED - rolling back this vhost (never leave nginx broken)" >&2
  rsudo "rm -f /etc/nginx/sites-enabled/${DOMAIN} /etc/nginx/sites-available/${DOMAIN}"
  rsudo "nginx -t && nginx -s reload"
  exit 4
fi
rsudo "nginx -s reload"

# ---- 5. TLS ----
# certbot failure is NOT a deploy failure: the site is live on HTTP and Cloudflare Universal SSL
# may already serve HTTPS at the edge for a first-level subdomain. Record SSL: PENDING and re-run.
say "Issuing TLS cert via certbot"
rsudo "certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL} --redirect" || \
  echo "  certbot failed - site is live on HTTP; ensure DNS propagated (DoH via /cloudflare-dns) then re-run: sudo certbot --nginx -d ${DOMAIN}" >&2

# ---- 6. verify (note: stale responses can appear right after deploy - re-check if wrong) ----
say "Verifying live"
$SSH "docker ps --filter name=${SLUG}-app --format '  container: {{.Names}} {{.Status}} {{.Ports}}'"
# Durability (/deploy-landing HR-11): the restart policy must be unless-stopped or a reboot kills it.
$SSH "docker inspect -f '  restart-policy: {{.HostConfig.RestartPolicy.Name}}' ${SLUG}-app 2>/dev/null || true"
# Origin check (bypasses DNS - proves nginx+app+TLS are correct even before the local resolver
# caches the new record). The IP lives inside --resolve and is NOT printed (secret).
echo -n "  origin https (CF-bypass --resolve): "; curl -s -o /dev/null -w '%{http_code}\n' --resolve "${DOMAIN}:443:${VPS_IP}" "https://${DOMAIN}" || true
echo -n "  public https (via local resolver): "; curl -s -o /dev/null -w '%{http_code}\n' "https://${DOMAIN}" || true
echo "  title (origin): $(curl -s --resolve "${DOMAIN}:443:${VPS_IP}" "https://${DOMAIN}" | grep -oiP '<title>\K[^<]+' | head -1 || echo '(none)')"
echo
echo "DONE -> https://${DOMAIN}"
echo "If public https is 000, your LOCAL resolver (Netbird, lags minutes) may not have the new A record yet."
echo "  That is NOT a deploy failure. Confirm public propagation via DoH (the ONLY reliable check on this box):"
echo "  curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=${DOMAIN}&type=A'"
echo "Verify other services intact: curl -I https://hiremeup.topengdev.com  (expect 200) + docker ps count unchanged."
