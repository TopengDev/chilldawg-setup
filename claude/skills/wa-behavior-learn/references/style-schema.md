# Style Profile Schema + Extraction Rubric

The output contract for every `whatsapp_style_<slug>.md`. Match this exactly:
malformed frontmatter mis-routes the auto-index, and generic bodies are worthless
for tone matching.

---

## 1. Frontmatter (exact key set)

```yaml
---
name: whatsapp_style_<slug>
title: <Human Name (optional nickname in parens)>
namespace: contact
tier: 1
description: <=150 chars, dense, leads with the ONE signature trait
tags:
- whatsapp
- style
- <slug>
- <relationship: family | close-friend | coworker | vendor | ...>
entities:
- <Name>
- Christopher
- <key nouns: shop, Pulse, phone JID>
aliases:
- whatsapp-style-<slug>
- <every name / nickname they go by or are saved as>
trigger_keywords:
- <their real catchphrases and slang tokens, verbatim>
hypothetical_questions:
- How do I reply to <Name> in their style?
- <a second real question a session might ask about this person>
created: <YYYY-MM-DD>     # preserve the original on updates
updated: <YYYY-MM-DD>     # = today, every write
---
```

Hard points:
- `namespace: contact` is mandatory (routes into `indexes/contact.md`). Never
  `type: reference`.
- `description` is the index line. It must name the distinctive trait. Model it on
  the real ones:
  - GOOD: "Older-brother friend 'Bang Ian', 'peng' suffix on every message, chill
    brotherly register, coffee shop business journey"
  - GOOD: "Shop helper 'WilLee', relays mami's instructions, third-person 'ado'
    self-ref, heavy phonetic spelling"
  - BANNED: "Communication style profile for X" / "casual friendly contact".
- `created` is preserved across updates; only `updated` moves.

---

## 2. Body template (the 9 dimensions)

```markdown
## Summary
<2-4 sentences: who they are in chat terms, primary language, the one or two
traits that make their voice unmistakable, and how they address Christopher.>

## Style Profile

### Language
<primary language + code-switching. name the actual patterns (dropped letters,
phonetic spelling), with example tokens.>

### Message Length & Structure
<avg words, one-liner vs paragraph, burst-chaining, media habits.>

### Tone
<the register. back it with what they say when happy / stressed / declining.>

### Slang & Abbreviations
<the ACTUAL tokens, each with meaning if non-obvious. gw/lu, tf, ywdh, etc.>

### Emoji & Reactions
<which specific emoji, how often, stickers, the signature one if any.>

### Common Phrases
<catchphrases, openers, sign-offs, verbal tics. verbatim.>

### Punctuation
<caps habit, periods/ellipses/none, "?" usage.>

### Response Patterns
<do they ask questions, short acks, voice notes, emoji-react, chain fragments.>

### Topics
<what they actually talk about with Christopher.>

## Example Messages
<3 to 5 REAL, redaction-passed quotes that capture the voice. each must be
something only this person would send. no invented lines.>

## How to Reply
<concrete, actionable: register to match, how to address them, what to confirm,
sensitivities to respect, length. this is the payoff section.>
```

On an UPDATE, keep the above intact and append:
```markdown
### Update <YYYY-MM-DD> (through <date of newest analyzed msg>)
<what changed or was re-confirmed; new tokens, new threads, sensitivities.>
```

---

## 3. Extraction rubric (anti-generic, enforced)

- **Minimum evidence, per dimension:** each dimension is backed by `>= 2`
  observed instances, or is written literally as "insufficient data". Never
  invent a pattern from one message.
- **Name real tokens, ban category words.** Slang / phrases / emoji MUST be the
  actual observed tokens. A dimension that says only "casual", "friendly",
  "informal", "expressive" with no tokens is a FAIL. Rewrite it with evidence
  ("casual Jakarta gaul: 'gw/lu', 'wkwkwk', 'anjir', 🗿") or mark it insufficient.
- **Signature trait first.** Find the one thing that makes them unmistakable (the
  "peng" suffix, third-person "ado", the 🗿 deadpan) and lead the Summary and the
  `description` with it.
- **Address form is load-bearing.** Always capture how they address Christopher
  ("brok", "peng", "toper", "kko", "pih") and mirror it in How to Reply. Getting
  this wrong is the most obvious tell.
- **Sensitivities are part of the style.** Money asks, confidential threads
  ("jangan bilang mami"), condolence contexts, credential asks: note them in How
  to Reply so a future reply handles them with the right register, and never
  quote the sensitive VALUE (section 4).
- **>= 5 qualifying messages or no file.** Below the floor is thin-data: skip and
  log a gap.

---

## 4. Redaction (before any quote reaches the file)

Refuse to quote, and paraphrase the STYLE instead, if a candidate example
contains: an OTP / verification code, a password / PIN / "sandi" value, a digit
run of 10+ (rekening / card / NIK), a full street address (Jl / RT / RW), a
token-bearing or login URL, or a raw phone number (62.../08...). It is fine to say
"he asked for the shop gmail password" (describing the ask); it is NOT fine to
quote a message that contains the password itself. Memory is auto-pushed to a
git remote, so a quoted secret is a pushed leak.

---

## 5. Worked example (before -> after)

### BEFORE (generic slop, REJECT)
```markdown
### Tone
Casual and friendly.

### Slang & Abbreviations
Uses Indonesian slang and abbreviations.

## Example Messages
- (various casual messages about the coffee shop)
```
Why it fails: zero tokens, unfalsifiable, could describe anyone, quotes nothing
real. Useless for matching a voice.

### AFTER (evidence-backed, ACCEPT)
```markdown
### Tone
Chill, warm, brotherly, low-drama. Apologetic and gracious when declining or
canceling ("iya sori ya.", "sori peng", "ok kpan2 lagi aja"). Matter-of-fact
about money and plans.

### Slang & Abbreviations
- peng  -- his signature address for Christopher, closes almost every message
- gua / lu  -- I / you
- gpp  -- gapapa (no problem);  kaga  -- nggak (not)
- tf / dana  -- transfer / DANA e-wallet
- kpan2  -- kapan-kapan (some other time);  ntar  -- nanti

## Example Messages
1. "ntar minggu gua kesana ya"
2. "peng gua ga bisa ikut usaha sama lu peng. sori peng"
3. "warung gua mah murah2 kaga mahal"
4. "ok ntar kabarin aja peng"

## How to Reply
Warm, brotherly, low-key (he is "Bang"). Bahasa casual, closing with "peng" or
"bang" mirrors him naturally. Money and business talk: be concrete and easygoing,
confirm amounts and plans, no pressure. The declined-partnership topic is
sensitive (family reasons, he apologized), stay gracious. Keep it to a line or two.
```
Why it passes: every dimension has real tokens, the signature trait ("peng")
leads, quotes are real and clean, How to Reply is actionable. This is the bar.
(Modeled on the real `whatsapp_style_bg_ian.md`.)
