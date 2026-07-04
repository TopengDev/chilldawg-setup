---
brand: <brand-slug>
primary-language: id | en | both
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
atlas-dossier: <slug | none>   # if set, /copywriting reads real facts from ~/.claude/skills/atlas/dossiers/<slug> (SKILL §4b, run the freshness gate first)
schema-version: 2
---

# Voice bank: <Brand Name>

> A per-brand memory the `/copywriting` skill READS on invoke and UPDATES on exit, so it does not re-learn the brand every run. Copy this file to `~/.claude/skills/copywriting/voice-banks/<brand-slug>.md` and fill it. Treat stored facts as possibly stale, verify before leaning on them. No em-dash or en-dash anywhere (the skill's N8 rule applies to its own state files too).

## Voice
- **Adjectives (3 to 5):** <e.g. warm, direct, fact-led, a little dry>
- **Sounds like:** <one line, a real reference voice or a sample sentence in-voice>
- **Never sounds like:** <the failure mode, e.g. "never corporate-excited, never adjective-soup, never em-dash">

## Banned words (brand-specific, ON TOP of the global §8 list)
| Word / phrase | Why banned for this brand |
|---|---|
| <word> | <reason> |

## VoC library (the most valuable section, mine it relentlessly)
> Real customer phrases, quoted VERBATIM, with source. The best copy is found here, not written. Every row carries a PROVENANCE flag (SKILL N13): `mined` = a real quote with a real source (usable as falsifiable proof); `inferred` = a guess (NEVER cite as proof, and flag any shipping line that rests on it as an assumption).
| Phrase (verbatim) | Provenance (mined \| inferred) | Source (review / ticket / call / DM) | What it reveals (desire / pain / objection) |
|---|---|---|---|
| "<exact words>" | mined \| inferred | <source, or "inferred (verify)"> | <desire/pain/objection> |

## The enemy
- **Status quo it argues against:** <the old way / belief / competitor this brand kills>
- **The conflict line:** <the "X but Y" framing, no literal "but">

## Proven lines (passed the gate + shipped)
> Reusable as motif anchors and as a voice calibration sample. PROMOTION GATE (SKILL N13): a line enters here ONLY after it passed the §7 gate AND (if it rests on VoC) that VoC is `mined` with a real source, never `inferred`.
| Line (ID / EN) | Asset | Date | Note |
|---|---|---|---|
| "<line>" | <hero/ad/...> | <date> | <why it worked> |

## Awareness note
- **Where the typical reader sits (Schwartz):** <unaware / problem-aware / solution-aware / product-aware / most-aware>
- **Market sophistication:** <how many rivals made this claim, so direct-claim vs mechanism vs identification>

## Open corrections (Toper said, do this / never that)
- <date>: <correction>
