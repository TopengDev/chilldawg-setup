---
name: cloudflare-dns
description: "Canonical DNS authority for the Cloudflare zones aenoxa.com and topengdev.com: list, create, update, delete, verify, and audit A records via the Cloudflare API with hard guardrails (zone-resolution gate, proxied decision table, 4-box verify-after-write, protected-record delete gate). Use when the user says /cloudflare-dns, asks to add/remove/check a DNS record or subdomain on aenoxa.com or topengdev.com, asks why a subdomain is not resolving, wants a propagation check, or wants a DNS zone audit."
argument-hint: <list|create|delete|verify|audit> [fqdn] [--zone aenoxa|topengdev] [--proxied|--grey]
allowed-tools: Bash, Read
---

# Cloudflare DNS - Multi-Zone Authority (aenoxa.com + topengdev.com)

This skill is the manual / audit / repair / list path for DNS on Christopher's two
working Cloudflare zones. It manages DNS RECORDS ONLY. It never touches nginx,
certbot, ssh, containers, or the VPS (see S7 Boundaries).

Progressive disclosure: encyclopedic API detail, the token-verify false-negative
transcript, the Beacon legacy naming scheme, and the dated zone inventory snapshot
live in `references/cloudflare-api.md`. Everything load-bearing is in this file.

---

## S0. PRIME RULES (read before ANY command)

These are hard rules. Violating any one of them is a failed run, even if the DNS
operation itself "worked".

### S0.1 Secret hygiene

- **NEVER print, echo, or log `$CLOUDFLARE_API_TOKEN`.** The token appears ONLY as
  `${CLOUDFLARE_API_TOKEN}` inside the `-H "Authorization: Bearer ..."` argument of
  a curl call. Never in any other position, never in a report, never in a commit
  message, never in a WhatsApp message, never in task notes.
- **NEVER use `curl -v`, `--trace`, or `--trace-ascii` on any Cloudflare call.**
  Verbose/trace modes dump the Authorization header (the raw token) to the
  transcript.
- **NEVER print `$VPS_HOST` or any record `.content` raw.** The origin IP is itself
  a secret (it lives in secrets.env and the whole point of the orange cloud is to
  hide it). Assert record targets programmatically:
  `jq --arg vps "$VPS_HOST" '(.content == $vps)'` and print only the boolean
  `points_at_vps`. Every jq filter in this skill already excludes `.content`;
  keep it that way. Never pipe a raw API response to the transcript.
- **NEVER print DoH answer IPs.** Compare them to `$VPS_HOST` inside jq and print
  the boolean (see S5 box 3). For proxied records the answers are Cloudflare edge
  IPs (public anyway), but the filter stays uniform so a grey record can never leak.

### S0.2 The token health check (verified gotcha)

- **NEVER use `GET /user/tokens/verify` as the health check.** VERIFIED 2026-07-03
  (and re-verified today): that endpoint returns `success:false, errors[0].code=1000
  "Invalid API Token"` for THIS working token (it lacks the User-level read
  permission the endpoint needs), while the same token succeeds on `GET /zones` and
  all dns_records reads/writes. An agent that trusts the verify endpoint will
  wrongly declare the token dead and escalate for rotation.
- **The health check is ALWAYS `GET /zones`** expecting `success:true` with
  `aenoxa.com` present:

```bash
curl -s "https://api.cloudflare.com/client/v4/zones?per_page=50" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | jq '{success, zones: [.result[].name]}'
```

Expected: `success:true` + 5 zones (aenoxa.com, execfi.xyz, sinarsuryaproperty.co.id,
topengdev.com, wiradutaindah.com). Full writeup: `references/cloudflare-api.md`.

### S0.3 The filter syntax (verified gotcha - the v1 skill shipped broken on this)

- **NEVER use `name=contains:X`.** It is not valid Cloudflare filter syntax, and it
  fails SILENTLY: `success:true` with 0 results, always. Verified live A/B
  2026-07-03 (re-run today): `?name=contains:grpc` returned count 0 while
  `?name.contains=grpc` returned the 4 real grpc.* records in the same zone.
- **ALWAYS use:**
  - `name.contains=<substring>` for substring lookups
  - `name=<exact FQDN>` for exact lookups (the ONLY form allowed for deletes)

### S0.4 The response envelope

- **NEVER trust HTTP 200 alone.** Cloudflare returns HTTP 200 with
  `success:false` + a populated `errors[]` array on many failures. Exit code 0 +
  status 200 proves nothing.
- **ALWAYS assert `.success == true` with jq** on EVERY response (reads and writes)
  before reporting anything as done. Envelope anatomy: `references/cloudflare-api.md`.

### S0.5 No wildcards

- **NEVER create a wildcard record** (`*.aenoxa.com` / `*.topengdev.com`). House
  convention, verified live in both zones 2026-07-03: zero wildcards exist; every
  subdomain gets its own explicit A record. This is deliberate (per-subdomain
  control, per-subdomain TLS via certbot, no accidental catch-all).

### S0.6 DNS records only - never the VPS

- **NEVER touch nginx, certbot, ssh, docker, or the VPS from this skill.** A DNS
  record that is correct but whose site is down is OUT OF SCOPE: hand off with your
  evidence block to `/deploy-landing` (aenoxa landings) or oneshot-webapp's
  `deploy.sh` (topengdev demos). See S7.

### S0.7 No hardcoded proxied flag

- **NEVER hardcode `proxied:true`** (the v1 skill's dead default, contradicted by
  12 of 13 live aenoxa records). ALWAYS classify via the S3 decision table and name
  the class in the report. Unclear class -> `proxied:false` (grey) + say why.

### S0.8 Style

- No em or en dashes in any user-facing output this skill emits (house rule).
  Evidence blocks are plain ASCII.

---

## S1. VERIFIED ENVIRONMENT (all facts live-verified 2026-07-03)

### Env vars (from `~/.claude/secrets.env`, sourced by `.bashrc`)

| Var | Meaning | Print policy |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | API token, all Cloudflare calls | NEVER print (S0.1) |
| `CLOUDFLARE_ZONE_ID` | Zone id of **aenoxa.com** (verified: id prefix `29d0c2`) | id itself ok, token never |
| `VPS_HOST` | The origin VPS IP, target of every A record | NEVER print (S0.1) |

If a var is empty in a fresh shell: `source ~/.claude/secrets.env` first, then
re-check `[ -n "$CLOUDFLARE_API_TOKEN" ]`. Do NOT cat secrets.env into the transcript.

### The 5 zones this token can see

| Zone | Zone id | Write status |
|---|---|---|
| aenoxa.com | `$CLOUDFLARE_ZONE_ID` (prefix `29d0c2`) | **VERIFIED writable** (service records live) |
| topengdev.com | `6011237924132746c5d8ffeb4132e696` | **VERIFIED writable** (AURA records created 2026-06-23; 12+ one-shot records) |
| execfi.xyz | prefix `dadce9` | READ-ONLY assumed. Writes HUMAN-GATED |
| sinarsuryaproperty.co.id | prefix `8b026c` | READ-ONLY assumed. Writes HUMAN-GATED |
| wiradutaindah.com | prefix `49dadd` | READ-ONLY assumed. Writes HUMAN-GATED |

Note: `~/.claude/CLAUDE.md` states the token scope as "Zone > DNS > Edit for
aenoxa.com". That is UNDERSTATED: the token verifiably lists 5 zones and has
performed DNS Edit on both aenoxa.com and topengdev.com. It is also possibly
OVERSTATED for the 3 client zones, where Edit is unverified. This skill's zone
table above is the verified ground truth; do not assume Edit rights on the 3
client zones, and do not refuse legitimate topengdev.com work.

### Tooling facts on this box (verified 2026-07-03)

| Tool | Status | Consequence |
|---|---|---|
| `jq`, `python3`, `curl` | present | all recipes below depend only on these |
| `dig`, `host`, `nslookup`, `drill` | ALL MISSING | never write a recipe using them (S6-h) |
| `resolvectl query` | BROKEN (`org.freedesktop.resolve1` unit not active) | never use |
| `getent hosts` | works BUT resolves via the Netbird resolver `100.64.0.2` which lags MINUTES behind public DNS for fresh records | never use as a propagation check |
| DoH (`cloudflare-dns.com/dns-query`) | WORKS (verified Status 0 on a live record) | the ONLY propagation check (S5 box 3) |

**Local resolver lag rule:** NEVER interpret a local resolution failure (getent,
plain `curl https://<fqdn>`, a qutebrowser screenshot showing a DNS error) as
"record not created". The local Netbird resolver lags public DNS by minutes for
fresh records; qutebrowser uses the same lagging resolver. Verified gotcha, also
documented in oneshot-webapp SKILL.md (Phase 6, local resolver lag). Truth order:
API re-fetch > DoH > `curl --resolve` origin probe > (never) local resolver.

---

## S2. ZONE RESOLUTION GATE (blocking - step 0 of EVERY command)

Before ANY API call, resolve the zone FROM the FQDN and print which zone the
operation targets. Unknown domains abort. Human-gated zones abort all writes.

```bash
FQDN="<target record, full name>"
case "$FQDN" in
  aenoxa.com|*.aenoxa.com)        ZONE_NAME="aenoxa.com";    ZONE_ID="${CLOUDFLARE_ZONE_ID}";            ZONE_TIER="verified" ;;
  topengdev.com|*.topengdev.com)  ZONE_NAME="topengdev.com"; ZONE_ID="6011237924132746c5d8ffeb4132e696"; ZONE_TIER="verified" ;;
  execfi.xyz|*.execfi.xyz)                              ZONE_NAME="execfi.xyz";               ZONE_TIER="human-gated" ;;
  sinarsuryaproperty.co.id|*.sinarsuryaproperty.co.id)  ZONE_NAME="sinarsuryaproperty.co.id"; ZONE_TIER="human-gated" ;;
  wiradutaindah.com|*.wiradutaindah.com)                ZONE_NAME="wiradutaindah.com";        ZONE_TIER="human-gated" ;;
  *)                                                    ZONE_NAME="UNKNOWN";                  ZONE_TIER="unknown" ;;
esac
echo "ZONE: ${ZONE_NAME} (${ZONE_TIER})"
```

Gate outcomes:

| Tier | Reads | Writes |
|---|---|---|
| `verified` | proceed | proceed (through S3-S5 gates) |
| `human-gated` | reads allowed | **ABORT** + escalate: "Writes on ${ZONE_NAME} are human-gated (DNS Edit unverified, client zone). Ask Toper explicitly." NO exceptions, not even "just a test record". |
| `unknown` | **ABORT entirely** | **ABORT entirely** - this token does not manage that domain |

For a READ on a human-gated zone, resolve its full zone id live (only prefixes are
documented, S1): `GET /zones` piped to
`jq -r --arg z "$ZONE_NAME" '.result[] | select(.name == $z) | .id'`.

The `ZONE:` line is mandatory output before the first API call of every operation
and is copied into the evidence block (S8).

---

## S3. PROXIED DECISION TABLE (blocking on create)

Never guess the orange/grey cloud. Classify, name the class in the report, then set
`proxied` from the class. Live house practice (verified across both zones
2026-07-03) IS the table; do not fight it.

| Class | What it is | `proxied` | Live evidence (2026-07-03) |
|---|---|---|---|
| **A** | One-shot demo / static marketing frontend on topengdev.com (or a zone apex serving a website) | `true` (orange) | 13/15 topengdev records orange: apex + alamanda, bithour, coba-pulse, dev, hiremeup, portfolio, pulse-genz, pulse-warmcraft, resumind, simple-e-commerce, startuppage, techpage. aenoxa.com apex orange. |
| **B** | API / gRPC / backend / docs / storage / app service subdomain (certbot TLS at origin, gRPC or S3 semantics, or grey-by-design app) | `false` (grey) | 12/13 aenoxa records grey: api.billing, app.pulse, docs.auth/iam/pos, grpc.auth/billing/iam/pos, minio.pos, pulse, s3.pos. Plus aura + api-aura on topengdev (grey by design, AURA deploy 2026-06-23). |
| **C** | Unknown / does not clearly fit A or B | `false` (grey) + flag for review | Round DOWN to grey: a grey record behind certbot works for everything; a wrongly-orange record breaks gRPC and hides nothing worth hiding yet. |

Hard consequences:

- **An orange `grpc.*` / `api.*` / `s3.*` / `minio.*` record is an outage-shaped
  record** (Cloudflare's HTTP proxy breaks gRPC traffic and S3-style clients).
  The audit command flags any such record as a conformance violation.
- oneshot-webapp's `deploy.sh` creates its topengdev demo records `proxied:true`.
  That is CORRECT for class A; this table deliberately agrees with it. Do not
  "fix" one-shot records to grey.
- A `--proxied` / `--grey` flag from the user overrides the table, but the evidence
  block must record both the class AND the override.

---

## S4. COMMANDS

Every command starts with: source-check env vars (S1) -> zone resolution gate (S2).
Every command ends with the evidence block (S8). All jq filters exclude `.content`
per S0.1.

### S4.1 LIST - `/cloudflare-dns list [substring] [--zone aenoxa|topengdev]`

Default zone if none given and no FQDN to infer from: list BOTH working zones.

```bash
# all A records in a zone (names, flags, ids - never raw IPs)
curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&per_page=100" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | jq --arg vps "$VPS_HOST" '{success, total: .result_info.total_count,
      records: [.result[] | {name, type, proxied, ttl, id, points_at_vps: (.content == $vps)}]}'

# substring filter (S0.3: dot notation, never contains:)
# ...dns_records?type=A&per_page=100&name.contains=<substring>
```

**List integrity gate (mandatory):**

1. Assert `.success == true`.
2. Assert `result_info.total_count <= 100` (the per_page). If greater, paginate
   with `&page=2` etc. until all pages are fetched (pagination reference:
   `references/cloudflare-api.md`). Currently 13 + 15 records, but never assume.
3. **An EMPTY result must be cross-checked before you believe it** (this is the
   exact silent-failure class the v1 skill shipped): re-query one known-existing
   record by exact name, `name=${ZONE_NAME}` (both zone apexes exist, verified
   2026-07-03). If the cross-check ALSO returns 0, your query mechanics are broken
   (bad filter syntax, wrong zone id, dead token) - diagnose via S6, do NOT report
   "no records".

Render as a plain ASCII table: name / proxied / points_at_vps / id.

### S4.2 CREATE - `/cloudflare-dns create <fqdn> [--proxied|--grey]`

1. **Zone gate (S2).** Writes only on `verified` zones.
2. **Classify (S3).** Decide class A/B/C -> `PROXIED=true|false`. State the class.
3. **Pre-check by exact name** (idempotency - never rely on the duplicate error):

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${FQDN}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | jq --arg vps "$VPS_HOST" '{success, count: (.result|length),
      existing: (.result[0] // null | if . == null then null
                 else {name, proxied, id, points_at_vps: (.content == $vps)} end)}'
```

   - Exists + matches intent (proxied flag equal, `points_at_vps:true`):
     report **idempotent no-op success** with the existing record id. Done.
   - Exists + differs: do NOT blind delete+recreate. Propose a PATCH update
     (recipe in `references/cloudflare-api.md`) and get confirmation if the record
     is on the S4.3 protected list.
   - Count 0: proceed.

4. **POST the record.** `ttl:1` means "automatic" (the correct default; an explicit
   TTL only matters for grey records - see references for TTL semantics):

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"${FQDN}\",\"content\":\"${VPS_HOST}\",\"ttl\":1,\"proxied\":${PROXIED}}" \
  | jq '{success, errors, id: (.result.id // null), name: (.result.name // null),
         proxied: (.result.proxied // null)}'
```

5. **Run the full verify-after-write protocol (S5), boxes 1-3.** A create without
   all three boxes green is status FAILED-VERIFY, not done.
6. Emit the evidence block (S8).

### S4.3 DELETE - `/cloudflare-dns delete <fqdn>`

**Protected-record denylist.** These names (both working zones) are production or
revenue-bearing. Deleting one requires Toper's EXPLICIT confirmation quoting the
exact FQDN back ("yes, delete grpc.pos.aenoxa.com"). A generic "clean it up" is
NOT confirmation.

```
PROTECTED (aenoxa.com):   aenoxa.com (apex), api.billing, app.pulse,
                          docs.auth, docs.iam, docs.pos,
                          grpc.auth, grpc.billing, grpc.iam, grpc.pos,
                          minio.pos, pulse, s3.pos
PROTECTED (topengdev.com): topengdev.com (apex), aura, api-aura, portfolio
PROTECTED (patterns, future-proof): any apex, grpc.*, api.*, api-*, docs.*,
                          app.*, pulse*, aura*, s3.*, minio.*, www.*
```

(One-shot demo records - alamanda, bithour, coba-pulse, dev, hiremeup, pulse-genz,
pulse-warmcraft, resumind, simple-e-commerce, startuppage, techpage - are demo-tier:
still show the record + get a normal go-ahead, but they are not on the hard
denylist.)

Procedure:

1. **Zone gate (S2).** A name must be provided; refuse bare `delete`.
2. **Lookup by EXACT name only.** `name=<full fqdn>`. NEVER delete from a
   substring (`name.contains=`) match - one loose substring is a multi-record
   outage.
3. **Display before delete** (never delete blind): name, type, proxied,
   `points_at_vps` boolean, record id. If 0 records: report and stop.
4. **Protected check.** Match against the denylist (exact names AND patterns).
   Protected -> STOP, require the quoted-FQDN confirmation. Not protected ->
   state what will be deleted and proceed on the user's go.
5. **DELETE by record id:**

```bash
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | jq '{success, deleted_id: (.result.id // null)}'
```

6. **Post-delete verify (S5 box 4):** GET by exact name must return 0 records.
7. Evidence block (S8).

### S4.4 VERIFY - `/cloudflare-dns verify <fqdn>`

Read-only diagnosis of one record ("is DNS set up / why is it not resolving").

1. Zone gate (S2). Health check (S0.2) if anything smells token-shaped.
2. API exact fetch (the S4.2 pre-check query). Report: exists?, proxied,
   `points_at_vps`.
3. DoH propagation check (S5 box 3 command) with the proxied/grey assertion split.
4. If DoH is green but the site is reported down: origin-reachability probe
   (bypasses DNS entirely, proves the origin serves the vhost):

```bash
curl -s -o /dev/null -w '%{http_code}\n' --resolve "${FQDN}:443:${VPS_HOST}" "https://${FQDN}/"
```

5. Verdict, exactly one of:
   - `RECORD MISSING` -> offer create (S4.2)
   - `RECORD WRONG` (not at VPS / wrong proxied class) -> propose PATCH
   - `PROPAGATION LAG` (API green, DoH not yet) -> wait, re-check, warn about the
     local resolver (S1)
   - `DNS GREEN, SITE DOWN` -> out of scope, hand off (S7) with the evidence block
   - `ALL GREEN`

### S4.5 AUDIT - `/cloudflare-dns audit`

Read-only sweep of BOTH working zones. Never auto-fixes.

1. LIST both zones (S4.1, including the integrity gate).
2. For each record compute: S3 class (from the name), class-conformance
   (does the live proxied flag match the class?), `points_at_vps`.
3. Flag:
   - conformance violations (e.g. an orange `grpc.*`, a grey one-shot demo)
   - records with `points_at_vps: false` (pointing somewhere unexpected)
   - any wildcard record (must be zero, S0.5)
   - drift vs the dated snapshot in `references/cloudflare-api.md` (new/removed
     names since 2026-07-03) - informational, not an error
4. Output one ASCII table per zone + a flags section. Fixes are proposed, never
   executed; every proposed fix routes through S4.2/S4.3 with their gates.

---

## S5. VERIFY-AFTER-WRITE PROTOCOL (all boxes or it did not happen)

House rule (feedback_verify_after_write + Close the Loop): an unverified "created"
is not created. Every write reports these boxes explicitly; ANY unchecked box means
the operation status is **FAILED-VERIFY**, never "done".

**Box 1 - write response asserts.** `.success == true` on the POST/PATCH/DELETE
response itself (S0.4: HTTP 200 does not mean success).

**Box 2 - API re-fetch (within 5s of the write).** GET by `name=<exact fqdn>`:
exactly 1 record, `type` matches, `proxied` matches intent, `points_at_vps: true`.

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${FQDN}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | jq --arg vps "$VPS_HOST" '{success, count: (.result|length),
      rec: (.result[0] // null | if . == null then null
            else {name, type, proxied, id, points_at_vps: (.content == $vps)} end)}'
```

**Box 3 - DoH propagation (budget 120s: up to 4 retries at 30s intervals).**
The ONLY propagation check on this box (S1 tooling facts):

```bash
curl -s -H 'accept: application/dns-json' \
  "https://cloudflare-dns.com/dns-query?name=${FQDN}&type=A" \
  | jq --arg vps "$VPS_HOST" '{Status, answers: ((.Answer // [])|length),
      matches_origin: ([(.Answer // [])[].data] | index($vps) != null)}'
```

Assertion SPLITS by record class:

| Record | Pass condition | Why |
|---|---|---|
| **grey** (`proxied:false`) | `Status == 0` AND `matches_origin == true` | public DNS must answer with the origin IP (compared inside jq, never printed) |
| **proxied** (`proxied:true`) | `Status == 0` AND `answers >= 1` | answers are Cloudflare EDGE IPs, different from the origin BY DESIGN. Do NOT assert content; `matches_origin` will be false and that is correct |

If box 3 fails while boxes 1-2 pass: that is propagation lag, NOT a record error.
Wait and retry within the budget; do NOT delete/recreate (S6-e). If still lagging
at 120s, report boxes 1-2 green + box 3 `PENDING (propagation)` with the observed
latency, and give the `curl --resolve` origin probe (S4.4 step 4) as the
DNS-independent check.

**Box 4 - deletes only.** GET by exact name returns 0 records.

Record the observed propagation latency in the evidence block.

---

## S6. FAILURE PLAYBOOK (symptom -> diagnostic -> recovery)

| # | Symptom | Diagnostic (read-only) | Recovery |
|---|---|---|---|
| a | `code 1000 "Invalid API Token"` on a REAL call (`/zones`, `dns_records`) | `[ -n "$CLOUDFLARE_API_TOKEN" ]` - is the env even populated? If empty: `source ~/.claude/secrets.env` and retry once. If populated and /zones still fails: token genuinely dead/rotated | Escalate to Toper for rotation. Do NOT retry-loop, do NOT try other endpoints hoping |
| b | `code 1000` from `/user/tokens/verify` ONLY, while /zones works | This is the KNOWN false-negative on this token (S0.2, verified 2026-07-03) | Ignore the verify endpoint entirely. `GET /zones` is truth |
| c | 403 / authentication error on a SPECIFIC zone while others work | Which zone? The 3 client zones (execfi.xyz, sinarsuryaproperty.co.id, wiradutaindah.com) have UNVERIFIED edit rights - a 403 there is expected | Abort. That zone is human-gated (S2). Report to Toper; never work around |
| d | Create fails, `errors[].message` contains `already exists` | You skipped the S4.2 pre-check. Fetch the existing record by exact name; compare proxied + `points_at_vps` to intent | Identical -> report idempotent no-op success. Different -> propose PATCH (references), never blind delete+recreate. Match on the message SUBSTRING `already exists`; do not hardcode unverified numeric error codes |
| e | Verify box 3 fails, boxes 1-2 pass | Propagation lag, not a record error. Re-run DoH within the 120s budget | Wait + retry. Warn that the LOCAL resolver lags additionally (S1). Do NOT delete/recreate, do NOT touch the record |
| f | DNS all green (boxes 1-3) but the site is down | `curl --resolve "${FQDN}:443:${VPS_HOST}" https://${FQDN}/` - if that also fails, the problem is origin-side (container/nginx/TLS), not DNS | OUT OF SCOPE. Hand off to /deploy-landing or oneshot-webapp deploy.sh WITH the evidence block. Never ssh/fix nginx from here (S0.6) |
| g | LIST returns empty | Run the known-record cross-check (S4.1 gate step 3: exact `name=${ZONE_NAME}`) | Cross-check hits -> the zone segment really is empty, report that. Cross-check ALSO empty -> your query is broken (filter syntax S0.3? wrong ZONE_ID? token a)) - fix the query, never report "no records" |
| h | Reflex says "just dig it" | `dig`/`host`/`nslookup`/`drill` are NOT INSTALLED here; `resolvectl` is broken; `getent` lies (lagging resolver) | DoH only (S5 box 3). Do not apt-install resolvers mid-task |
| i | HTTP 200 but the operation "did nothing" | Read `.success` and `.errors[]` - Cloudflare 200s its failures (S0.4) | Treat `success:false` as the failure it is; diagnose from `errors[]`, starting at row a |

Blame discipline (house rule feedback_dont_blame_external): before concluding
"Cloudflare is broken/slow", exhaust rows a-i. Every incident so far has been our
syntax, our resolver, or our assumption.

---

## S7. BOUNDARIES + HANDOFFS (cite, never duplicate)

| Concern | Owner | This skill's role |
|---|---|---|
| Automated one-shot record creation during a demo deploy | **oneshot-webapp `deploy.sh`** (creates its own `<slug>.topengdev.com` record idempotently, proxied:true, hardcoded topengdev zone id - see oneshot-webapp SKILL.md Phase 5) | Do NOT double-create while a one-shot deploy is running. This skill is the MANUAL / audit / repair / list path |
| aenoxa landing-page deploys (nginx, files, certbot) | **/deploy-landing** (its SSL step explicitly points back here for the DNS record) | Provide the record; hand back |
| nginx vhosts, certbot, containers, ssh, anything on the VPS | /deploy-landing, oneshot-webapp deploy.sh, or an explicitly-briefed worker | NEVER from this skill (S0.6). VPS is read-only by default house-wide |
| Browser-based verification of a live site | **/agent-browser** skill exclusively (multi-port /claim lifecycle, never Playwright MCP) | Do not screenshot a URL to "prove DNS" at all - the browser uses the same lagging local resolver (S1). DNS proof = API + DoH; site proof = curl --resolve; anything browser = agent-browser skill |
| Beacon `{name}-landing-page.aenoxa.com` legacy naming + generator | Legacy, parked in `references/cloudflare-api.md` (Beacon SaaS never built; /deploy-landing may still exercise the pairing) | If invoked with a bare Beacon-style name, apply the legacy convention from references, then run the normal S4.2 path |

---

## S8. EVIDENCE BLOCK + DELIVERY GATE

Every operation ends with this block (plain ASCII, no secrets, no raw IPs).
A claim without the block is invalid per Close-the-Loop.

```
DNS OPERATION REPORT
zone:         topengdev.com (verified)
fqdn:         example.topengdev.com
action:       create | update | delete | verify | list | audit
class:        A (one-shot demo frontend) -> proxied: true   [override: none]
record id:    <id or n/a>
verify boxes:
  [1] write response success:true        PASS | FAIL | n/a
  [2] API re-fetch matches intent        PASS (count=1, proxied=true, points_at_vps=true) | FAIL | n/a
  [3] DoH propagation                    PASS (Status=0, answers=1, matched grey/proxied rule) | PENDING | FAIL | n/a
  [4] post-delete zero records           PASS | FAIL | n/a
propagation latency: <observed, e.g. 34s | not reached in 120s>
status:       DONE | FAILED-VERIFY | ABORTED (gate: zone|protected|human-gated)
handoff:      none | /deploy-landing | oneshot-webapp deploy.sh (+ why)
```

### Delivery gate (self-check before reporting - ALL must hold)

- [ ] Zone line printed BEFORE the first API call; operation ran in that zone
- [ ] No token, no `$VPS_HOST` value, no raw `.content`, no DoH IPs in anything I printed
- [ ] Every API response had `.success` asserted (not HTTP status)
- [ ] Substring lookups used `name.contains=`; the delete lookup used exact `name=`
- [ ] Create: class named from the S3 table (or override recorded); no hardcoded proxied
- [ ] Write: verify boxes per S5 all reported; any unchecked box -> status FAILED-VERIFY
- [ ] Delete: displayed-before-deleted; protected list checked; box 4 ran
- [ ] Empty list result was cross-checked against a known record before being believed
- [ ] No nginx/certbot/ssh/VPS action taken; handoffs stated instead
- [ ] Evidence block emitted; no em/en dashes in user-facing output

If any box fails, fix it before reporting. An unverified "done" is not done.
