# Cloudflare API Reference (cloudflare-dns skill)

Encyclopedic depth for the /cloudflare-dns skill. Everything here was verified
live read-only on 2026-07-03 unless a different date is stated. Nothing in this
file overrides the SKILL.md PRIME RULES (S0), especially secret hygiene: token
only inside the Authorization header, never `curl -v/--trace`, never print
`$VPS_HOST` or record `.content`.

---

## 1. API surface used by this skill

Base: `https://api.cloudflare.com/client/v4`
Auth on every call: `-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"`

| Endpoint | Method | Used for |
|---|---|---|
| `/zones?per_page=50` | GET | token health check (S0.2) + zone discovery |
| `/zones/{zone_id}/dns_records` | GET | list / lookup (filters below) |
| `/zones/{zone_id}/dns_records` | POST | create (JSON body: type, name, content, ttl, proxied) |
| `/zones/{zone_id}/dns_records/{record_id}` | PATCH | partial update (see recipe, section 5) |
| `/zones/{zone_id}/dns_records/{record_id}` | DELETE | delete by id |
| `/user/tokens/verify` | GET | **DO NOT USE** - false-negative on this token (section 7) |

Content type for bodies: `-H "Content-Type: application/json"`.

## 2. Response envelope anatomy

Every v4 response is a JSON envelope; HTTP status is NOT the success signal
(failures commonly arrive as HTTP 200 + `success:false`):

```json
{
  "success": true,
  "errors":   [],
  "messages": [],
  "result":   { } ,
  "result_info": { "page": 1, "per_page": 100, "count": 13, "total_count": 13 }
}
```

- `success` (boolean) - THE signal. Assert it with jq on every call.
- `errors[]` - objects with `code` (int) + `message` (string). On failure this is
  where the diagnosis lives (e.g. code 1000 "Invalid API Token"; duplicate-create
  messages contain the substring `already exists` - match the substring, do not
  hardcode numeric codes that were never observed here).
- `result` - object (single-resource calls) or array (list calls). DELETE returns
  `{"result":{"id":"..."}}` on success.
- `result_info` - list calls only. `total_count` > `per_page` means you must
  paginate (section 3).

## 3. List filters + pagination (verified behavior)

| Filter | Syntax | Status on this box |
|---|---|---|
| Exact name | `?name=<full fqdn>` | VERIFIED working (returns 0 or 1 A record) |
| Substring | `?name.contains=<substring>` | VERIFIED working (grpc test returned the 4 real grpc.* records) |
| Type | `?type=A` | VERIFIED working |
| **Invalid** | `?name=contains:<substring>` | **VERIFIED BROKEN 2026-07-03: returns `success:true` with 0 results ALWAYS.** Live A/B in the aenoxa zone: `name=contains:grpc` -> count 0, `name.contains=grpc` -> count 4. This exact syntax shipped in the v1 skill and made its LIST permanently empty. Never use the `contains:` value-prefix form |

Cloudflare docs list further dot-notation operators (`name.startswith`,
`name.endswith`, etc.); they are UNVERIFIED on this box - if you need one, A/B it
against a known record first (the S4.1 cross-check pattern) before trusting it.

Pagination: `?page=N&per_page=M` (max per_page 100 per docs). The skill uses
`per_page=100` and asserts `result_info.total_count <= 100`; if greater, loop
`page=2..ceil(total/100)` and concatenate. Current reality (2026-07-03): 13 A
records on aenoxa.com, 15 on topengdev.com - one page each, but always assert.

## 4. TTL semantics

- `"ttl": 1` = **automatic** (Cloudflare-managed). This is the skill default and
  what every live record in both zones uses via the standard create path.
- Explicit TTLs (per Cloudflare docs: 60-86400 seconds, UNVERIFIED here - no live
  record uses one) only take real effect on **grey** (`proxied:false`) records;
  on proxied records the edge answers with its own TTL regardless.
- Practical rule: leave `ttl:1` unless a grey record specifically needs a short
  TTL for a planned migration (then set it explicitly, then set it back).

## 5. UPDATE recipe (PATCH - the fix for "exists but differs")

When the create pre-check finds an existing record whose `proxied` flag or target
differs from intent, PATCH the delta - never blind delete+recreate (deleting a
live record creates an NXDOMAIN window; PATCH is atomic).

```bash
# example: flip a record to grey (send ONLY the fields you change)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"proxied": false}' \
  | jq '{success, errors, id: (.result.id // null), proxied: (.result.proxied // null)}'
```

To retarget content to the VPS without printing the IP:
`--data "{\"content\":\"${VPS_HOST}\"}"`.

A PATCH is a WRITE: the full S5 verify-after-write protocol applies (boxes 1-3).
If the record is on the S4.3 protected list, the same explicit-confirmation gate
applies as for delete (changing `pulse.aenoxa.com` is as production-affecting as
deleting it).

## 6. DoH JSON response format (the only propagation check)

Endpoint: `https://cloudflare-dns.com/dns-query` with header
`accept: application/dns-json`. Verified live 2026-07-03 against
`aura.topengdev.com` (Status 0, 1 answer).

```json
{
  "Status": 0,
  "TC": false, "RD": true, "RA": true, "AD": false, "CD": false,
  "Question": [ { "name": "example.topengdev.com", "type": 1 } ],
  "Answer":   [ { "name": "example.topengdev.com", "type": 1, "TTL": 300, "data": "<ip>" } ]
}
```

- `Status` is the DNS RCODE: `0` = NOERROR, `3` = NXDOMAIN (record genuinely not
  in public DNS yet, or never created).
- `Answer` may be ABSENT (not just empty) on NXDOMAIN - jq with `(.Answer // [])`
  as in the S5 box 3 command.
- `data` holds the answer IP. NEVER print it; compare inside jq against
  `$VPS_HOST` and emit the `matches_origin` boolean.
- Proxied records answer with Cloudflare EDGE IPs: `matches_origin` false is
  CORRECT for them (S5 assertion split). Grey records must match the origin.

## 7. The /user/tokens/verify false-negative (verified 2026-07-03)

Observed transcript shape (re-verified same day this file was written):

```
GET /user/tokens/verify   -> { "success": false, "errors": [ { "code": 1000, "message": "Invalid API Token" } ] }
GET /zones                -> { "success": true, ... 5 zones ... }        (same token, seconds apart)
GET /zones/{aenoxa}/dns_records?type=A -> success:true, 13 records       (same token)
```

Interpretation: the verify endpoint effectively requires a User-level permission
(API Tokens Read) that this zone-scoped DNS token does not carry, so it reports
the token as invalid even though every zone/DNS call works. Consequence, encoded
as SKILL.md S0.2: health-check with `GET /zones` (expect `success:true` +
aenoxa.com present), never with `/user/tokens/verify`. A `code 1000` from a REAL
zone/DNS call is still a genuine dead-token signal (playbook row a).

## 8. Zone inventory snapshot - audit baseline (2026-07-03)

Names + proxied flags only (no IPs by policy). All 28 records verified pointing
at `$VPS_HOST` (`points_at_vps:true`) at snapshot time. No wildcard records exist
in either zone. `/cloudflare-dns audit` diffs live state against this table and
reports drift as informational.

### aenoxa.com (13 A records; zone id = $CLOUDFLARE_ZONE_ID, prefix 29d0c2)

| Name | proxied | S3 class |
|---|---|---|
| aenoxa.com (apex) | true | A |
| api.billing.aenoxa.com | false | B |
| app.pulse.aenoxa.com | false | B |
| docs.auth.aenoxa.com | false | B |
| docs.iam.aenoxa.com | false | B |
| docs.pos.aenoxa.com | false | B |
| grpc.auth.aenoxa.com | false | B |
| grpc.billing.aenoxa.com | false | B |
| grpc.iam.aenoxa.com | false | B |
| grpc.pos.aenoxa.com | false | B |
| minio.pos.aenoxa.com | false | B |
| pulse.aenoxa.com | false | B |
| s3.pos.aenoxa.com | false | B |

### topengdev.com (15 A records; zone id 6011237924132746c5d8ffeb4132e696)

| Name | proxied | S3 class |
|---|---|---|
| topengdev.com (apex) | true | A |
| alamanda.topengdev.com | true | A (one-shot) |
| bithour.topengdev.com | true | A (one-shot) |
| coba-pulse.topengdev.com | true | A (one-shot) |
| dev.topengdev.com | true | A (one-shot) |
| hiremeup.topengdev.com | true | A (one-shot) |
| portfolio.topengdev.com | true | A (protected) |
| pulse-genz.topengdev.com | true | A (one-shot) |
| pulse-warmcraft.topengdev.com | true | A (one-shot) |
| resumind.topengdev.com | true | A (one-shot) |
| simple-e-commerce.topengdev.com | true | A (one-shot) |
| startuppage.topengdev.com | true | A (one-shot) |
| techpage.topengdev.com | true | A (one-shot) |
| aura.topengdev.com | false | B (grey by design, AURA web - deploy 2026-06-23) |
| api-aura.topengdev.com | false | B (grey by design, AURA backend) |

Token-visible but human-gated zones (reads only, writes forbidden without Toper):
execfi.xyz (prefix dadce9), sinarsuryaproperty.co.id (prefix 8b026c),
wiradutaindah.com (prefix 49dadd). All status active.

## 9. LEGACY - Beacon landing-page naming (kept for /deploy-landing pairing)

The v1 skill existed solely for the **Beacon** landing-page SaaS
(`beacon.aenoxa.com`, memory `project_landing_page_saas`) which was designed but
NEVER BUILT: zero `*-landing-page.aenoxa.com` records exist live (verified
2026-07-03). /deploy-landing still references /cloudflare-dns for aenoxa records,
so the convention is preserved here, OUT of the hot path:

- **Naming convention:** full record = `{name}-landing-page.aenoxa.com`. The user
  supplies only the prefix (e.g. `sunny-ocean`); the skill appends the suffix.
- **Class:** a Beacon landing page is a static marketing frontend -> S3 class A
  (`proxied:true`), matching the original design intent ("orange cloud"). Note
  the live one-shot demos prove certbot HTTP-01 issuance works fine behind the
  orange cloud on this stack.
- **Random name generator** (v1 skill, verbatim - 32 adjectives x 32 nouns):

```bash
python3 -c "
import random
adjectives = ['sunny','blue','swift','calm','bold','bright','cool','dark','deep','fair','fast','gold','grand','green','keen','kind','lost','new','old','pale','pure','rare','red','rich','safe','soft','tall','thin','vast','warm','wild','wise']
nouns = ['ocean','river','mountain','forest','meadow','valley','stone','cloud','flame','frost','storm','dawn','dusk','hawk','moon','peak','pine','reef','sage','star','tide','vine','wave','wolf','bear','crow','deer','dove','eagle','elk','fox','lake']
print(f'{random.choice(adjectives)}-{random.choice(nouns)}')
"
```

If a Beacon-style request ever arrives (bare prefix, "landing page" context),
build the FQDN with this convention, then run the NORMAL S4.2 create path with
every gate (zone resolution, class table, verify-after-write). The legacy flow
gets no gate exemptions.
