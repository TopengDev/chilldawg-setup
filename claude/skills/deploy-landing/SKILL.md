---
name: deploy-landing
description: Deploy a built Next.js landing page to Christopher's VPS. Takes subdomain and local build directory as arguments (e.g. /deploy-landing sunny-ocean-landing-page.aenoxa.com ./out).
argument-hint: <name>-landing-page.aenoxa.com <build-directory>
allowed-tools: Bash, Read, Glob, Grep
---

## Deploy Next.js Landing Page to VPS

### Arguments

Parse `$ARGUMENTS` into two parts:
- **SUBDOMAIN**: First argument — the full subdomain (e.g., `sunny-ocean-landing-page.aenoxa.com`)
- **BUILD_DIR**: Second argument — local path to the Next.js build output directory

### VPS Connection

Credentials are sourced from `~/.claude/secrets.env` (auto-loaded by `~/.bashrc`).
The variables `$VPS_HOST`, `$VPS_USER`, `$VPS_PASSWORD` are available in any shell.

- Host: `$VPS_HOST`
- User: `$VPS_USER`
- Password: `$VPS_PASSWORD`
- SSH: `sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST}`
- SCP/Rsync: `sshpass -p "${VPS_PASSWORD}" rsync -avz -e 'ssh -o StrictHostKeyChecking=no'`

---

### CRITICAL SAFETY RULES (NON-NEGOTIABLE)

1. **Domain restriction**: SUBDOMAIN **MUST** match `*-landing-page.aenoxa.com`. If it does not end with `-landing-page.aenoxa.com` or has nothing before it, REFUSE immediately.
2. **Never modify existing configs**: Before creating an nginx config, check if `/etc/nginx/sites-available/{SUBDOMAIN}` already exists. If it exists and was NOT created by a previous run of this skill (i.e., doesn't match the landing page pattern), REFUSE. If it was created by this skill (same subdomain, redeployment), it's OK to overwrite.
3. **Always test before reload**: ALWAYS run `sudo nginx -t` before `sudo nginx -s reload`. No exceptions.
4. **Rollback on failure**: If `nginx -t` fails or any critical step after file deployment fails, execute the full rollback procedure (see bottom of this document).
5. **Scope restriction**: Only create/modify:
   - `/var/www/{SUBDOMAIN}/` directory
   - `/etc/nginx/sites-available/{SUBDOMAIN}` config file
   - `/etc/nginx/sites-enabled/{SUBDOMAIN}` symlink
   - PM2 process named `{SUBDOMAIN}`
   - NOTHING ELSE. Never touch any other nginx config, /var/www directory, or PM2 process.

---

### Step 1: Validate Arguments

1. Verify both SUBDOMAIN and BUILD_DIR are provided. If not, print usage and stop:
   ```
   Usage: /deploy-landing <name>-landing-page.aenoxa.com <build-directory>
   Example: /deploy-landing sunny-ocean-landing-page.aenoxa.com ./out
   ```

2. Verify SUBDOMAIN ends with `-landing-page.aenoxa.com` and has at least one character before `-landing-page.aenoxa.com`. Use a regex check:
   ```bash
   echo "$SUBDOMAIN" | grep -qP '^[a-z0-9][a-z0-9-]*-landing-page\.aenoxa\.com$'
   ```
   If it fails, REFUSE with: `"Error: Subdomain must match *-landing-page.aenoxa.com (got: {SUBDOMAIN})"`

3. Verify BUILD_DIR exists locally and is a directory.

4. Determine the deployment type by inspecting BUILD_DIR:
   - **Standalone build**: Contains `server.js` (from `output: 'standalone'` in next.config) — deploy as a Node.js process with PM2 + reverse proxy
   - **Static export**: Contains `index.html` (from `output: 'export'`) — deploy as static files served directly by nginx
   - **Neither**: Error out with `"Error: BUILD_DIR must contain either server.js (standalone) or index.html (static export)"`

---

### Step 2: Copy Built Files to VPS

1. Create the target directory:
   ```bash
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "sudo mkdir -p /var/www/${SUBDOMAIN} && sudo chown christopher:christopher /var/www/${SUBDOMAIN}"
   ```

2. Rsync the build files:
   ```bash
   sshpass -p "${VPS_PASSWORD}" rsync -avz --delete \
     -e 'ssh -o StrictHostKeyChecking=no' \
     "${BUILD_DIR}/" "${VPS_USER}@${VPS_HOST}:/var/www/${SUBDOMAIN}/"
   ```

3. Verify by listing the remote directory:
   ```bash
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "ls -la /var/www/${SUBDOMAIN}/"
   ```

---

### Step 3: Start the Application (Standalone builds only)

Skip this step entirely if the build is a **static export**.

1. Check existing ports in use on the VPS:
   ```bash
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "grep -rhP 'proxy_pass\s+http://127\.0\.0\.1:\K[0-9]+' /etc/nginx/sites-available/ 2>/dev/null | sort -n"
   ```

2. Pick the lowest available port starting from **4000** that is not in the list above.

3. Check if a PM2 process with this name already exists. If yes, delete it first:
   ```bash
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "pm2 delete ${SUBDOMAIN} 2>/dev/null; true"
   ```

4. Start the Next.js standalone server:
   ```bash
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "cd /var/www/${SUBDOMAIN} && PORT=${PORT} pm2 start server.js --name ${SUBDOMAIN}"
   ```

5. Save PM2 state and verify:
   ```bash
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "pm2 save && sleep 2 && curl -s -o /dev/null -w '%{http_code}' http://localhost:${PORT}"
   ```
   Expect HTTP 200. If not, wait another 3 seconds and retry once. If still failing, trigger rollback.

---

### Step 4: Create Nginx Config

**For standalone builds** (reverse proxy), write this config to `/etc/nginx/sites-available/{SUBDOMAIN}`:

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

**For static exports**, write this config instead:

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

Write the config using a heredoc over SSH:
```bash
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
  "sudo tee /etc/nginx/sites-available/${SUBDOMAIN} > /dev/null << 'NGINXEOF'
...config content...
NGINXEOF"
```

---

### Step 5: Enable the Site (Symlink)

```bash
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
  "sudo ln -sf /etc/nginx/sites-available/${SUBDOMAIN} /etc/nginx/sites-enabled/${SUBDOMAIN}"
```

---

### Step 6: Test Nginx Config

```bash
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
  "sudo nginx -t"
```

- **If test PASSES** -> proceed to Step 7.
- **If test FAILS** -> execute the **Rollback Procedure** immediately. Stop the deployment.

---

### Step 7: Reload Nginx

```bash
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
  "sudo nginx -s reload"
```

---

### Step 8: SSL Certificate

Attempt to obtain an SSL certificate with Certbot:

```bash
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
  "sudo certbot --nginx -d ${SUBDOMAIN} --non-interactive --agree-tos --email admin@aenoxa.com --redirect"
```

- **If certbot succeeds**: SSL is active. Record `SSL: YES`.
- **If certbot fails**: This is NOT a deployment failure. The site still works over HTTP. Record `SSL: PENDING`. Tell the user:
  1. Ensure DNS A record for `{SUBDOMAIN}` points to `${VPS_HOST}`
  2. Consider using `/cloudflare-dns` to set up the DNS record
  3. Then re-run certbot: `sudo certbot --nginx -d {SUBDOMAIN}`

---

### Step 9: Health Check

1. Wait 3 seconds for everything to settle.

2. Health check from the VPS itself (always works regardless of DNS):
   ```bash
   # For standalone:
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "curl -s -o /dev/null -w '%{http_code}' http://localhost:${PORT}"

   # For static:
   sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} \
     "curl -s -o /dev/null -w '%{http_code}' --resolve ${SUBDOMAIN}:80:127.0.0.1 http://${SUBDOMAIN}"
   ```

3. External health check (requires DNS):
   ```bash
   curl -s -o /dev/null -w '%{http_code}' "https://${SUBDOMAIN}" 2>/dev/null || \
   curl -s -o /dev/null -w '%{http_code}' "http://${SUBDOMAIN}" 2>/dev/null
   ```

4. If the VPS-local check returns 200: deployment is **successful**.
   If not: warn the user but do NOT rollback (the app may just need more startup time).

---

### Step 10: Deployment Report

Print a clear summary:

```
=================================
  Deploy Landing - Complete
=================================
  Subdomain:    {SUBDOMAIN}
  Build Dir:    {BUILD_DIR}
  Type:         {standalone|static}
  VPS Path:     /var/www/{SUBDOMAIN}/
  Port:         {PORT or N/A for static}
  PM2 Process:  {SUBDOMAIN or N/A for static}
  Nginx Config: /etc/nginx/sites-available/{SUBDOMAIN}
  SSL:          {YES | PENDING - set up DNS first}
  Health Check: {PASS | WARN}
  URL:          https://{SUBDOMAIN}
=================================
```

---

### Rollback Procedure

Execute this if `nginx -t` fails or any critical step fails after files have been deployed:

```bash
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_HOST} << 'ROLLBACK'
  # 1. Remove nginx symlink
  sudo rm -f /etc/nginx/sites-enabled/${SUBDOMAIN}

  # 2. Remove nginx config
  sudo rm -f /etc/nginx/sites-available/${SUBDOMAIN}

  # 3. Verify nginx is still healthy and reload
  sudo nginx -t && sudo nginx -s reload

  # 4. Stop PM2 process (if standalone)
  pm2 delete ${SUBDOMAIN} 2>/dev/null; true

  # 5. Remove deployed files
  sudo rm -rf /var/www/${SUBDOMAIN}
ROLLBACK
```

After rollback, report clearly:
```
DEPLOYMENT FAILED - ROLLED BACK
================================
Subdomain:  {SUBDOMAIN}
Reason:     {what went wrong}
Rolled back:
  - Removed nginx config and symlink
  - Stopped PM2 process (if applicable)
  - Removed /var/www/{SUBDOMAIN}/
  - Nginx restored to previous state
================================
```

---

### Redeployment (Updating an existing landing page)

If the subdomain already has a deployment (nginx config exists, PM2 process running):

1. The existing nginx config can be overwritten (same subdomain = same skill created it).
2. Delete the old PM2 process before starting the new one.
3. Rsync with `--delete` ensures old files are cleaned up.
4. Still run `nginx -t` before reload.
5. Still rollback on failure — but restore the PREVIOUS config if one existed (back it up first):
   ```bash
   sudo cp /etc/nginx/sites-available/${SUBDOMAIN} /etc/nginx/sites-available/${SUBDOMAIN}.bak
   ```
   On rollback, restore from `.bak` instead of deleting.
