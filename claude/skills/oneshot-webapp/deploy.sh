#!/usr/bin/env bash
# oneshot-webapp deploy helper — ship a Next.js (standalone) app to <slug>.topengdev.com
# Replicates the proven bithour-ops-pm / Selaras deploy (2026-05-29). Idempotent: safe to re-run.
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

set -euo pipefail

# ---- args ----
SLUG="${1:-}"; REPO="${2:-}"; shift $(( $# >= 2 ? 2 : $# )) || true
ENV_FILE=""; PORT=""; EMAIL="topengdev@gmail.com"
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
ZONE_ID="6011237924132746c5d8ffeb4132e696"   # topengdev.com (aenoxa token covers it)
VPS_IP="$VPS_HOST"
SSH="sshpass -p $VPS_PASSWORD ssh -o StrictHostKeyChecking=accept-new ${VPS_USER}@${VPS_HOST}"
RSYNC_SSH="ssh -o StrictHostKeyChecking=accept-new"

say(){ printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
# Run a command on the VPS with sudo, feeding the login password to `sudo -S`
# over stdin. Non-interactive ssh has no TTY, so plain `sudo` prompts fail.
# Verified on this VPS: the login password IS the sudo password (2026-05-29).
rsudo(){ $SSH "echo '$VPS_PASSWORD' | sudo -S -p '' $*"; }

# ---- next.config standalone sanity ----
if ! grep -rqs 'standalone' "$REPO"/next.config.* 2>/dev/null; then
  echo "WARNING: next.config does not contain 'standalone' — the Docker build needs output:'standalone'." >&2
fi
[[ -f "$REPO/Dockerfile" ]] || { echo "no Dockerfile in $REPO — copy bithour-ops-pm/Dockerfile and set its PORT first." >&2; exit 3; }

# ---- pick a free port if not given ----
if [[ -z "$PORT" ]]; then
  say "Picking a free loopback port (33xx)"
  USED=$($SSH "grep -rhoP 'proxy_pass\s+http://127\.0\.0\.1:\K[0-9]+' /etc/nginx/sites-available/ 2>/dev/null; docker ps --format '{{.Ports}}' | grep -oP '127\.0\.0\.1:\K[0-9]+'" 2>/dev/null | sort -un || true)
  for p in $(seq 3310 3399); do
    if ! grep -qx "$p" <<<"$USED"; then PORT="$p"; break; fi
  done
  [[ -n "$PORT" ]] || { echo "no free port found in 3310-3399" >&2; exit 3; }
fi
say "slug=$SLUG  domain=$DOMAIN  port=$PORT  repo=$REPO"

# ---- 1. Cloudflare A record (idempotent) ----
say "Ensuring Cloudflare A record $DOMAIN -> $VPS_IP (proxied)"
EXISTING=$(curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${DOMAIN}" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['result'][0]['id'] if d.get('result') else '')" 2>/dev/null || true)
if [[ -z "$EXISTING" ]]; then
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
    -d "{\"type\":\"A\",\"name\":\"${DOMAIN}\",\"content\":\"${VPS_IP}\",\"proxied\":true}" \
    | python3 -c "import sys,json;d=json.load(sys.stdin);print('  created' if d.get('success') else '  FAILED: '+json.dumps(d.get('errors')))"
else
  echo "  already exists ($EXISTING) — leaving as-is"
fi

# ---- 2. ship source to VPS (build happens in-container) ----
# NOTE: this VPS has NO rsync installed (verified 2026-05-29). Prefer rsync if
# both ends have it; otherwise fall back to tar-over-ssh (same exclude set).
say "Syncing source to ~/apps/$SLUG (excluding node_modules/.next/.git/data/.env*)"
if command -v rsync >/dev/null 2>&1 && $SSH "command -v rsync >/dev/null 2>&1"; then
  $SSH "mkdir -p ~/apps/$SLUG"
  sshpass -p "$VPS_PASSWORD" rsync -az --delete -e "$RSYNC_SSH" \
    --exclude node_modules --exclude .next --exclude .git --exclude data \
    --exclude '.env' --exclude '.env.local' \
    "$REPO"/ "${VPS_USER}@${VPS_HOST}:~/apps/$SLUG/"
else
  echo "  rsync unavailable on one end — using tar-over-ssh fallback"
  $SSH "rm -rf ~/apps/$SLUG && mkdir -p ~/apps/$SLUG"
  tar czf - -C "$REPO" \
    --exclude=node_modules --exclude=.next --exclude=.git --exclude=data \
    --exclude=.env --exclude=.env.local --exclude=tsconfig.tsbuildinfo . \
    | $SSH "tar xzf - -C ~/apps/$SLUG"
fi

# ---- 2b. env file (secrets, server-side only) ----
if [[ -n "$ENV_FILE" ]]; then
  [[ -f "$ENV_FILE" ]] || { echo "env file not found: $ENV_FILE" >&2; exit 3; }
  say "Uploading env file (chmod 600, server-side only)"
  sshpass -p "$VPS_PASSWORD" scp -o StrictHostKeyChecking=accept-new "$ENV_FILE" "${VPS_USER}@${VPS_HOST}:~/apps/$SLUG/.env"
  $SSH "chmod 600 ~/apps/$SLUG/.env"
  ENVFLAG="--env-file ~/apps/$SLUG/.env"
else
  ENVFLAG=""
  echo "  (no --env given; container runs without an env-file)"
fi

# ---- 3. docker build + run (loopback-only bind) ----
say "Building image ${SLUG}-app:latest on the VPS"
$SSH "cd ~/apps/$SLUG && docker build -t ${SLUG}-app:latest ."
say "Running container ${SLUG}-app on 127.0.0.1:${PORT}"
$SSH "docker rm -f ${SLUG}-app 2>/dev/null; docker run -d --name ${SLUG}-app --restart unless-stopped -p 127.0.0.1:${PORT}:${PORT} ${ENVFLAG} ${SLUG}-app:latest"
sleep 3
$SSH "curl -s -o /dev/null -w '  local health: %{http_code}\n' http://127.0.0.1:${PORT} || true"

# ---- 4. nginx vhost (HTTP first; certbot adds TLS) ----
# Build the vhost locally, scp to /tmp on the VPS, then `sudo cp` into place.
# (A `sudo tee <<heredoc` over ssh competes with `sudo -S` for stdin — avoid it.)
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
sshpass -p "$VPS_PASSWORD" scp -o StrictHostKeyChecking=accept-new "$VHOST_TMP" "${VPS_USER}@${VPS_HOST}:/tmp/${DOMAIN}.vhost"
rm -f "$VHOST_TMP"
rsudo "cp /tmp/${DOMAIN}.vhost /etc/nginx/sites-available/${DOMAIN}"
rsudo "ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}"

say "Testing nginx config"
if ! rsudo "nginx -t" 2>&1; then
  echo "  nginx -t FAILED — rolling back this vhost" >&2
  rsudo "rm -f /etc/nginx/sites-enabled/${DOMAIN} /etc/nginx/sites-available/${DOMAIN}"
  rsudo "nginx -t && nginx -s reload"
  exit 4
fi
rsudo "nginx -s reload"

# ---- 5. TLS ----
say "Issuing TLS cert via certbot"
rsudo "certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL} --redirect" || \
  echo "  certbot failed — site is live on HTTP; ensure DNS has propagated then re-run: sudo certbot --nginx -d ${DOMAIN}" >&2

# ---- 6. verify (note: stale responses can appear right after deploy — re-check if wrong) ----
say "Verifying live"
$SSH "docker ps --filter name=${SLUG}-app --format '  container: {{.Names}} {{.Status}} {{.Ports}}'"
# Origin check (bypasses DNS — proves nginx+app+TLS are correct even before the
# local resolver caches the new record):
echo -n "  origin https (via VPS IP): "; curl -s -o /dev/null -w '%{http_code}\n' --resolve "${DOMAIN}:443:${VPS_IP}" "https://${DOMAIN}" || true
echo -n "  public https: "; curl -s -o /dev/null -w '%{http_code}\n' "https://${DOMAIN}" || true
echo "  title: $(curl -s --resolve "${DOMAIN}:443:${VPS_IP}" "https://${DOMAIN}" | grep -oiP '<title>\K[^<]+' | head -1 || echo '(none)')"
echo
echo "DONE → https://${DOMAIN}"
echo "If public https is 000, your LOCAL resolver may not have cached the new A record yet — confirm public DNS with:"
echo "  curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=${DOMAIN}&type=A'"
echo "Verify other services intact: curl -I https://hiremeup.topengdev.com"
