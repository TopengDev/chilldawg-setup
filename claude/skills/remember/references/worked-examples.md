# Worked Examples — well-formed memories, bad→good rewrites, merges

Illustrative templates (not copies of live files). Match the *shape* and the
*enrichment discipline*, not the exact words.

## A. Full well-formed memories (one per namespace)

### feedback (needs Why + How to apply)
```markdown
---
name: feedback_stage_prod_writes
title: Stage prod write-actions behind a confirm gate
namespace: feedback
tier: 1
description: On any deployed prod environment, never fire a create/update/delete write-action without an explicit confirm step — stage it, show the diff, wait for go.
tags: [prod-safety, write-actions, confirm-gate, deploy-discipline]
entities: [prod, maker-checker, write-action]
aliases: [stage prod writes, confirm before prod mutation, no silent prod write]
trigger_keywords: [prod write gate, stage before apply, confirm destructive action, prod mutation safety]
hypothetical_questions:
  - Can I run a write-action directly against prod?
  - How should I handle a destructive action on a live environment?
created: 2026-07-03
updated: 2026-07-03
---

## Summary
Any write-action against a live/prod environment is staged behind an explicit
confirm, never fired silently.

## Context
**Why:** a silent prod mutation is unrecoverable and invisible until it breaks
something downstream.
**How to apply:** compute the change, show the exact diff/row, wait for an
explicit "go", then apply and re-verify persistence.
```

### project (needs Why + How to apply + status)
```markdown
---
name: project_acme_billing_migration
title: ACME billing migration — Stripe → in-house ledger
namespace: project
tier: 2
status: active
description: Migration of ACME billing off Stripe onto the in-house ledger service; cutover gated on the reconciliation job matching 30 days of invoices.
tags: [acme-billing, stripe-migration, ledger-cutover, reconciliation]
entities: [ACME, Stripe, ledger-service, reconciliation-job]
aliases: [acme billing migration, stripe to ledger, billing cutover]
trigger_keywords: [acme billing migration, stripe cutover, reconciliation gate, in-house ledger]
hypothetical_questions:
  - What is the cutover condition for ACME billing?
  - Are we still on Stripe for ACME?
created: 2026-07-03
updated: 2026-07-03
---

## Summary
...
## Context
**Why:** ... **How to apply:** ...
```

### reference (tool/system/how-it-works)
```markdown
---
name: reference_ledger_idempotency_keys
title: Ledger service idempotency-key contract
namespace: reference
tier: 2
description: The ledger POST /entries requires an Idempotency-Key header; a replayed key returns the original 200 body, never a duplicate row.
tags: [ledger-service, idempotency-key, dedup-contract]
entities: [ledger-service, Idempotency-Key, POST /entries]
aliases: [ledger idempotency, dedup key contract, replay-safe ledger post]
trigger_keywords: [ledger idempotency key, replay safe post, duplicate entry prevention]
hypothetical_questions:
  - How do I avoid double-posting to the ledger?
  - What header does the ledger require for dedup?
created: 2026-07-03
updated: 2026-07-03
---
```

### credential (LOCATION only, never the value)
```markdown
---
name: reference_acme_api_key
title: ACME API key (location)
namespace: credential
tier: 2
description: ACME API key for the billing sync — value at $ACME_API_KEY in ~/.claude/secrets.env; used by the reconciliation job only.
tags: [acme-api, billing-sync-cred, secrets-env-ref]
entities: [ACME, $ACME_API_KEY, secrets.env, reconciliation-job]
aliases: [acme api key location, acme billing credential]
trigger_keywords: [acme api key, acme credential location, acme billing secret]
hypothetical_questions:
  - Where is the ACME API key stored?
  - Which env var holds the ACME billing credential?
created: 2026-07-03
updated: 2026-07-03
---

## Summary
The ACME API key lives at `$ACME_API_KEY` in `~/.claude/secrets.env`. NEVER
write the value here.
```

## B. Bad → good rewrites

### B1 — the execfi miss (rare term body-only)
The canonical failure: "do you remember about **execfi**" returned zero of the 5
files that discuss execfi, because "execfi" was body-only (weight 1) in all of
them and lost to conversational filler hitting other files' HIGH fields.
```yaml
# BAD
title: BCAS VPS rootless deploy
description: How the BCAS VPS deploy works.
trigger_keywords: [vps, deploy, podman]      # generic; "execfi" nowhere up here
# ...body says "execfi" 4×...                # weight 1 → invisible to a natural query

# GOOD — hoist the rare term into HIGH fields + description
title: BCAS execfi rootless-podman deploy (ibankent gap-fill)
description: How the execfi container deploys on the BCAS VPS via rootless Podman/Oracle — the ibankent gap-fill migration.
aliases: [execfi deploy, execfi-postgres, ibankent gap-fill]
trigger_keywords: [execfi, rootless podman oracle, ibankent gap-fill, bcas vps deploy]
entities: [execfi, ibankent, BCAS VPS, Podman, Oracle]
```

### B2 — generic-tag IDF dilution
```yaml
# BAD — every term matches half the corpus; dilutes IDF, helps nothing
tags: [memory, workflow, automation]
trigger_keywords: [notes, session, general, info]

# GOOD — specific, high-IDF, the exact tokens a future query uses
tags: [journal-audit, high-water-mark, promotion-dedup]
trigger_keywords: [journal audit high-water, promote journal entry, consolidation dedup]
```

### B3 — secret-leak redaction
```yaml
# BAD — a literal value in a version-controlled, auto-pushed store
description: ACME key is sk-live-9f2a...redacted... use it for the sync.

# GOOD — location only; namespace: credential; value stays in secrets.env
description: ACME API key for the sync — value at $ACME_API_KEY in ~/.claude/secrets.env.
```
If the PostToolUse hook fires a leak warning: redact to the `$ENV` ref, re-save,
then **rotate the key** (assume autopush already pushed it to the private
remote).

### B4 — generic hypothetical_questions (wastes the highest-leverage field)
```yaml
# BAD — matches nothing specific; a future query never phrases itself this way
hypothetical_questions:
  - What should I remember here?
  - Is there anything important about this?

# GOOD — the exact question a future session will type, naming the rare term
hypothetical_questions:
  - What is the cutover gate for the ACME billing migration?
  - Are we still on Stripe for ACME?
```
`hypothetical_questions` is HIGH-weight (×3) AND it pre-writes the query the
future you will type — a generic question throws away both advantages.

## C. Merge + REDIRECT stub

When two files cover the same topic, merge the loser into the higher-tier /
older-`created` winner. If the loser is `[[wikilinked]]` from live files, don't
delete it — leave a **REDIRECT stub** so links don't dangle and
`memory-decay.py`'s G1 guard keeps it until it can archive it (S2
self-declared-superseded):

```markdown
---
name: reference_old_topic
title: REDIRECT — merged into reference_new_topic
namespace: reference
tier: 3
description: REDIRECT — this entry was merged into [[reference_new_topic]]; kept as a stub so existing wikilinks resolve.
tags: [redirect-stub]
entities: [reference_new_topic]
aliases: [old topic]
trigger_keywords: [old topic redirect]
hypothetical_questions:
  - Where did the old-topic memory go?
created: 2026-06-01
updated: 2026-07-03
---

REDIRECT — merged into [[reference_new_topic]]. See that file.
```
Then `gen-memory-index.py`. The weekly decay will later archive the stub once no
live file links to it (G1 clears) because it self-declares superseded (S2).

## D. Under-enriched drift to avoid (live examples)

Six live files are metadata-nested AND enrichment-empty (`trigger_keywords: 0`,
`hypothetical_questions: 0`), so they are nearly unfindable:
`feedback_delegate_skills_via_formal_invocation`,
`project_aura_session_handoff_2026_07_02`, `project_skills_ultra_enhance` (this
very program's tracker), `reference_bcas_vps_oracle_access`,
`reference_aura_zerocup_strategy`, `reference_zerocup_bracket`. They were written
through the Write tool (harness-normalised into a `metadata:` block) but the
author never supplied enrichment — nesting preserves fields, it does not invent
them. This is exactly the drift the Pre-Write Gate exists to stop.
