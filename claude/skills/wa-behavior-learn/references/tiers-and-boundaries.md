# Tiers + the style/contact Boundary

Two things that keep this skill's output correct and non-duplicative: knowing WHO
a profile is for (tier, which gates whether the profile is even actionable), and
keeping `whatsapp_style_` strictly separate from `contact_`.

---

## 1. Relationship tiers (a classification, tagged not invented)

The relationship tier is captured in the profile `tags` and Summary, and it tells
a downstream reply-writer how (and whether) to use the profile. It is NOT the
frontmatter `tier:` field (that is always `1`, the memory-retrieval tier).

| Tier | Who | Style relevance | Auto-reply posture (owned elsewhere) |
|---|---|---|---|
| family | papih, mama, close relatives | Voice still worth learning, but flag "personal" | Christopher handles himself. A profile should say "only assist if explicitly asked". |
| close-friend | kenny, kenken, hezkiel, stiven, etc. | HIGH value, this is where tone matching pays off | CLOSE_FRIEND auto-reply applies (see `feedback_whatsapp_auto_reply_global.md`). |
| coworker | ISI / BMS contacts (Ryan, Ikhsan, ...) | Professional register, matters for work replies | Coworker tier auto-respond + notify (see `feedback_isi_coworker_tier.md`). |
| vendor / acquaintance / unknown | shops, one-off contacts | Low, often thin-data | No auto-reply. Profile only if genuinely active. |

Rules of thumb:
- Do NOT invent a tier. Read it from the person's `contact_<slug>.md` if one
  exists, or from their existing style file, or infer conservatively from tags and
  default to the cautious side (treat as non-auto-reply until confirmed).
- For family / personal profiles, ALWAYS end How to Reply with the caveat that
  Christopher likely handles these himself and the assistant should only step in if
  asked. Verified pattern: `whatsapp_style_papih.md`, `whatsapp_style_ado_tri.md`
  (the confidential "jangan bilang mami" thread).
- Tier does not change the extraction rubric. A vendor still needs real tokens or
  "insufficient data"; tier only changes the How to Reply guidance and whether the
  profile is worth writing at all.

The auto-reply POLICY itself is owned by the feedback memories above and by
`/whatsapp`. This skill only records the voice and the tier-appropriate caveat; it
never decides or performs auto-reply.

---

## 2. `whatsapp_style_` vs `contact_` (strict split, cross-link never duplicate)

Both share `namespace: contact` and both land in `indexes/contact.md`, so the
boundary must be disciplined or they drift into duplicated, conflicting facts.

| | `contact_<slug>.md` | `whatsapp_style_<slug>.md` |
|---|---|---|
| Answers | WHO is this person | HOW do they write |
| Owns | identity, phone JID, tier, whitelist / CLOSE_FRIEND mode, relationship, key background | language, message shape, tone, slang tokens, emoji, catchphrases, punctuation, example messages, How to Reply |
| Written by | hand / other flows | THIS skill |
| Not exists for everyone | only notable contacts (9 today) | any active 1:1 contact (21 today) |

When BOTH exist for a person (verified today: kenny, kenken, suryadi):
- The style file is the CANONICAL source for voice. Put the deep tone analysis
  there.
- Do NOT copy JID, tier, whitelist status, or relationship narrative into the
  style file. Reference it: a single line like
  `Identity / tier / JID: see [[contact_kenny]]` is enough.
- If a person has ONLY a style file, it may carry a light one-line identity note,
  but keep it minimal and let a future `contact_` file own identity.
- Never let the two disagree. If the style file learns a new fact that belongs in
  identity (a confirmed tier, a whitelist change), note it for Christopher rather
  than silently editing `contact_` from this skill.

Cross-link convention: use `[[contact_<slug>]]` wiki-links (the memory system
resolves them), not copied prose. Keep each file answering only its own question.
