# Auto-file rubric (reference)

The scored, gated engine behind `/tasks add` and `/tasks sort`. SKILL.md Section 4 is the summary; this is the full algorithm, the keyword governance, the new-project gate checklist, the priority-tier precedence, and worked scoring examples. The goal is anti-generic: replace naive substring matching with a deterministic score so filing is consistent and explainable, and so the directory never fills with junk project files.

House rule reminder: every string this engine writes or prints is dash-free (comma, colon, parentheses, or line break instead of an em or en dash).

---

## 1. Keyword governance (single source of truth)

**The live keyword-to-file map lives in INDEX.md's `<!-- KEYWORDS MAP -->` comment block, and ONLY there.** SKILL.md and this reference describe the ALGORITHM; they must not carry a hardcoded project list (that was the old bug: the map was duplicated in SKILL.md and INDEX.md and the two diverged, both pointing at files that no longer exist).

Rules:
- On every add/sort, re-read the INDEX.md map fresh. Do not cache a project list across runs.
- A keyword row whose target `.md` file is absent on disk is SKIPPED (do not score it, do not resurrect the file, do not crash). Flag it as stale during `/tasks review`.
- When a project file is created (Section 3 gate) or retired, update the INDEX.md map in the SAME operation. This is what keeps it from re-drifting.
- Keep the map lean: a handful of distinctive keywords per project. Generic words ("app", "bug", "fix") are tier signals (Section 4), not routing keywords, do not add them to the map.

Known drift on disk (2026-07-03): the INDEX.md map still lists `attn.md`, `email-mcp.md`, `whatsapp-mcp.md`, `personal.md`, none of which exist. The current real files are: `aenoxa-dashboard.md`, `beacon.md`, `infrastructure.md`, `pt-aenoxa.md`, `pulse.md`, `qa-skill.md`, `software-house.md`, `tooling.md`, `whatsapp-cli.md` (plus `inbox.md` + `INDEX.md`). The skip-absent-target rule above makes the stale rows harmless; review should prune them (that edits INDEX.md, which this skill owns).

---

## 2. The score (0 to 100)

Compute for EACH candidate project independently, then pick the winner.

| Signal | Points | Notes |
|---|---|---|
| Exact project-name token in task text | +60 | The token must correspond to an existing `*.md` file. "pulse" for `pulse.md`. Case-insensitive whole-word match, not a substring of a larger word. |
| Registered keyword hit(s) for the project | +40 | From the INDEX.md map. Capped at +40 per project: three keyword hits for the same project still score +40, not +120. |
| Client-name pattern | +50 | `client X`, `for {Company}`, or a known client name. Routes to `client_{name}.md` (existing or gated-new). |

Then resolve:

1. Rank projects by score, descending.
2. **Ambiguity check**: if the top TWO distinct projects BOTH score >= 40, go to the tie-break (Section 3) before applying thresholds.
3. **Thresholds** on the winner's score:
   - `>= 70`: file SILENTLY into that project. Confirm one line.
   - `40 to 69`: file into that project AND announce it (offer `/tasks move` to refile). This is the "probably right, but tell him" band.
   - `< 40`: file to `inbox.md`. Never guess.

Why these numbers: an exact project token alone (+60) is strong but lands in the announce band, not silent, because a bare token can be coincidental ("pulse of the market"). Token + a keyword (>= 70, often +60+40=100) is silent-confident. A lone keyword (+40) is announce-band. Nothing (< 40) is inbox. This deliberately biases toward inbox over a wrong silent guess (Rule 4: an ambiguous capture defaults to inbox).

---

## 3. Tie-break (two projects both >= 40)

Apply in order, stop at the first that resolves:

1. **Specificity**: higher score wins. An exact project token (+60) beats a generic keyword (+40). So a task scoring pulse=60, infrastructure=40 files to pulse.
2. **Both have an exact token** (rare, e.g. "migrate pulse infra to the new server" hits `pulse` +60 and `infrastructure` +60): still tied at the top score, route to `inbox.md` with a note naming both candidates. Let Christopher decide, do not coin-flip.
3. **Both only keyword, equal score**: route to `inbox.md`.

Never break a genuine tie by picking the first-alphabetical or first-scanned file. Inbox is the correct answer for a real tie.

---

## 4. Priority-tier decision table

Independent of the project score. Classify which tier the item enters.

| Class | Trigger words | Tier |
|---|---|---|
| Urgency | now, today, urgent, asap, fix, broken, down, critical, hotfix | NOW |
| Blocked | waiting, blocked, pending, need X from, after Y, depends on, stuck on | WAITING |
| Future | someday, later, eventually, idea, maybe, backlog, one day | LATER |
| Planning | need to, should, want to, plan, explore, look into, consider | NEXT |
| (default) | none of the above | NEXT |

**Precedence when multiple classes match: NOW > WAITING > LATER > NEXT.**

- "urgent" + "waiting on Ryan" -> NOW wins by precedence (keeps the urgent item visible). Rare case.
- "waiting on Ryan" alone (no urgency word) -> WAITING. This is the common blocked case.

**WAITING extraction**: when the tier is WAITING, pull the "who/what" from the phrasing:
- "waiting on {X}" -> who = X
- "need {X} from {Y}" -> who = Y
- "blocked by {Z}" -> who = Z
- Set `follow up: {date}`. Use a stated date if present ("follow up friday" -> compute it), else default to `today + 3 days` via `date -d "+3 days" +%F`.
- Write the line as: `- [ ] {task}, waiting on: {who}, follow up: {YYYY-MM-DD} \`{today}\`` (comma before "waiting on", NEVER a dash, the consumers parse the "waiting on" phrase).

---

## 5. New-project creation gate (checklist)

A new project file is EXPENSIVE (it becomes a permanent routing target). Never create one from a soft signal. All five must hold, or the capture goes to `inbox.md`:

- [ ] **Explicit signal**: a client name, OR Christopher literally said "new project {X}" / "start tracking {X} as its own project". A single fuzzy keyword that matches no file is NOT a signal, it is an inbox item.
- [ ] **One-line confirm shown**: `no project matches "{X}". create {file}.md? (else it goes to inbox)`. Wait for a yes on the non-obvious cases; a clear client name can proceed and report.
- [ ] **INDEX.md dashboard row added** (Project, Status, NOW/NEXT/WAITING counts, Next Action).
- [ ] **INDEX.md keyword map updated** with the new file's distinctive keywords.
- [ ] **File seeded** with canonical frontmatter (`project`, `description`, `status`, `client` if applicable, `deadline` empty) + all five empty tier headers (Section 2.1 of SKILL.md).

Filenames: lowercase, hyphenated, `{project}.md`; client work is `client_{name}.md` (e.g. `client_sinarsurya.md`). Verify-after-write on the new file before reporting.

---

## 6. Worked scoring examples

Each shows the input, the computed score, the tier, and the exact one-line confirmation.

**A. Silent high-confidence.**
`/tasks add "fix cash drawer init bug in pulse"`
- Score: exact token "pulse" +60, keyword "pos/inventory/duitku" not present, but "pulse" is also a registered keyword +40 -> capped view: token 60 + keyword 40 = 100 for pulse. No other project >= 40.
- Tier: "fix" -> NOW.
- Max-5-NOW gate: pulse NOW currently has room -> append.
- Output: `→ pulse / NOW: fix cash drawer init bug`

**B. Announce-band (single keyword).**
`/tasks add "call notaris next week about the PT"`
- Score: "notaris" + "PT" are `pt-aenoxa` keywords -> +40 (capped). No exact project-name token ("pt-aenoxa" not literally in text). pt-aenoxa = 40. Nothing else >= 40.
- Tier: "next week" is a soft-future planning phrase, no urgency, no blocked -> NEXT.
- Output: `→ pt-aenoxa / NEXT: call notaris next week about the PT   (low confidence, say "/tasks move" to refile)`
- Also: "next week" is a soft horizon, not a hard time, so NO scheduling handoff. Contrast with "call notaris friday 2pm" which WOULD trigger the /remindme offer.

**C. Ambiguous, no keyword hit -> inbox.**
`/tasks add "email the accountant the Q2 numbers"`
- Score: no project token, no registered keyword hits (accountant/Q2 are not in the map). Top score < 40.
- Output: `→ inbox: email the accountant the Q2 numbers   (3 items need sorting)`

**D. Two-project tie -> inbox (no coin-flip).**
`/tasks add "migrate pulse database to the new VPS"`
- Score: "pulse" token +60 (pulse=60), "VPS/server/deploy" keyword +40 (infrastructure=40). Ambiguity check: only pulse >= 40 at top? pulse=60 beats infrastructure=40 by specificity -> pulse wins, NOT a real tie.
- If instead "migrate pulse infra": "pulse" +60, "infrastructure" as a token +60 -> genuine tie at 60 -> inbox naming both: `→ inbox: migrate pulse infra   (ambiguous: pulse or infrastructure? sort it)`

**E. New client project (gate passes).**
`/tasks add "new project: build inventory app for Toko Sinar Surya"`
- Signal: explicit "new project" + a client name "Toko Sinar Surya". Gate opens.
- Confirm: `no project matches "Sinar Surya". create client_sinarsurya.md?`
- On yes: seed `client_sinarsurya.md` (frontmatter `client: Toko Sinar Surya`), add INDEX row + keyword map row ("sinar surya, sinarsurya, toko sinar"), file the task.
- Tier: "build ... app" is planning -> NEXT.
- Output: `created client_sinarsurya.md  ·  → client_sinarsurya / NEXT: build inventory app`

**F. Deadline capture (handoff fires).**
`/tasks add "send the ISI recap by 5pm today"`
- Score: no strong project match (ISI/recap may hit a keyword) -> file where it lands or inbox.
- Tier: "today" -> NOW.
- Hard time detected ("by 5pm today") -> after filing, append the handoff:
  `→ inbox / NOW: send the ISI recap by 5pm today`
  `heads up: this has a 5pm deadline. the task alone will not alert you. want me to /remindme so it pings your WhatsApp at 17:00 WIB?`
