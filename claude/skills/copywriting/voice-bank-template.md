---
brand: <brand-slug>
primary-language: id | en | both
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
schema-version: 1
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
> Real customer phrases, quoted VERBATIM, with source. The best copy is found here, not written.
| Phrase (verbatim) | Source (review / ticket / call / DM) | What it reveals (desire / pain / objection) |
|---|---|---|
| "<exact words>" | <source> | <desire/pain/objection> |

## The enemy
- **Status quo it argues against:** <the old way / belief / competitor this brand kills>
- **The conflict line:** <the "X but Y" framing, no literal "but">

## Proven lines (passed the gate + shipped)
> Reusable as motif anchors and as a voice calibration sample.
| Line (ID / EN) | Asset | Date | Note |
|---|---|---|---|
| "<line>" | <hero/ad/...> | <date> | <why it worked> |

## Awareness note
- **Where the typical reader sits (Schwartz):** <unaware / problem-aware / solution-aware / product-aware / most-aware>
- **Market sophistication:** <how many rivals made this claim, so direct-claim vs mechanism vs identification>

## Open corrections (Toper said, do this / never that)
- <date>: <correction>
