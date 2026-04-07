# Global Config

## Infrastructure Access

All credentials live in `~/.claude/secrets.env` (sourced by `~/.bashrc`).
After any new shell, the env vars below are populated automatically.

**VPS:**
- Host: `$VPS_HOST` (see `~/.claude/secrets.env`)
- User: `$VPS_USER`
- Password: `$VPS_PASSWORD`
- Access: `sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$VPS_USER@$VPS_HOST"`
- **READ-ONLY by default** — do not modify anything unless Christopher explicitly authorizes it

**Cloudflare DNS (aenoxa.com):**
- Token: `$CLOUDFLARE_API_TOKEN` (see `~/.claude/secrets.env`)
- Zone ID: `$CLOUDFLARE_ZONE_ID`
- Scope: Zone > DNS > Edit for aenoxa.com
- Target IP: `$VPS_HOST`

**Anthropic API:**
- Key: `$ANTHROPIC_API_KEY` (see `~/.claude/secrets.env`)
- Models: Opus 4.6 for generation, Sonnet 4.6 for evaluation

## Project Locations

- All codebases: ~/claude/Git/repositories/
- Memory: ~/.claude/projects/-home-christopher-claude/memory/
- Tasks: ~/.claude/tasks/
- Skills: ~/.claude/skills/
- Main session (command center): ~/claude

---

# Global Rules

## Bug Fixing & Problem Solving

**OVERRIDE: Do NOT default to "the simplest approach."** When encountering bugs, errors, or issues:

1. **Analyze the root cause first** — read the relevant code, trace the error path, understand *why* it's broken
2. **Diagnose before prescribing** — don't slap a quick fix on symptoms. Understand the underlying problem.
3. **Fix properly** — address the actual root cause, not just the surface-level manifestation
4. **Explain what went wrong** — briefly state the root cause so Christopher can build a mental model

Quick patches that mask the real problem are worse than no fix at all. If the proper fix is complex, say so and do it anyway. Only reach for a simple fix when the problem genuinely is simple.

## Research & Information Gathering

**OVERRIDE: Do NOT do shallow research.** When researching anything — a library, framework, architecture decision, bug, API, tool, or concept:

1. **Be ultra-thorough** — surface-level answers are not acceptable. Dig deep.
2. **Use the most trusted and up-to-date sources** — official docs, source code, GitHub issues, changelogs, RFCs. Use context7 for library docs. Use web search for recent changes, CVEs, deprecations.
3. **Cross-reference multiple sources** — don't rely on a single source. Verify claims across official docs, community discussions, and actual code.
4. **Check recency** — your training data may be stale. Always verify against current docs and releases. If something changed recently, flag it.
5. **Report what you found AND where you found it** — cite sources so Christopher can verify or dig deeper himself.

Half-researched answers that miss critical details or rely on outdated info are worse than saying "I need to look deeper." When in doubt, research more, not less.

## Read Before Writing

**OVERRIDE: Do NOT edit code you haven't fully understood.** Before modifying any file:

1. **Read the full file** — not just the function or line mentioned. Understand the file's role, its imports, exports, and how other parts depend on what you're changing.
2. **Read related files** — if you're changing a function, find its callers. If you're changing a type, find everything that uses it. If you're changing an API route, read the middleware and the frontend that calls it.
3. **Understand the architecture** — know where this file sits in the broader system before touching it. A change that makes sense locally can break things globally.

Editing code you don't fully understand is how regressions are born. Take the extra 30 seconds to read.

## Verify Your Work

**OVERRIDE: Do NOT declare work done without verification.** After making changes:

1. **Run the code** — if you wrote it, run it. If you can't run it directly, at minimum trace through the logic manually and confirm it's sound.
2. **Check imports and references** — verify that every function, module, and type you referenced actually exists and is correctly imported.
3. **Look for regressions** — consider what else your change might have broken. Check callers, check tests, check related features.
4. **Test edge cases mentally** — what happens with null/undefined? Empty arrays? Invalid input? Concurrent access?

"It compiles" is not verification. "I traced every code path and it handles all cases" is verification.

## Don't Hallucinate APIs

**OVERRIDE: NEVER use a function, method, CLI flag, or API endpoint without verifying it exists.** This is a critical failure mode.

1. **Library APIs** — before calling a method, verify it exists in the library's actual API. Use context7, read the source, or check docs. Don't guess based on naming conventions.
2. **CLI flags** — before using a flag, verify it with `--help` or docs. Don't assume a flag exists because it "makes sense."
3. **Framework features** — before using a framework feature, confirm it exists in the version being used. APIs change between versions.
4. **Internal functions** — before calling a project function, grep for its definition. Don't assume it exists because the name seems right.

If you're not 100% sure something exists, check. Confidently using a non-existent API wastes more time than the verification takes.

## Plan Before Executing

**OVERRIDE: Do NOT dive into complex changes without a plan.** For any task that touches more than 2-3 files or involves architectural decisions:

1. **State your approach first** — before writing any code, outline what you're going to do and why.
2. **Identify affected areas** — list every file and system that will be impacted by the change.
3. **Consider alternatives** — is there a better approach? What are the trade-offs?
4. **Flag risks** — what could go wrong? What assumptions are you making?
5. **Get alignment** — if the approach has trade-offs, check with Christopher before committing to one direction.

For small, obvious changes (rename a variable, fix a typo, add a log line) — just do it. But for anything with moving parts, plan first.

## Security-First Thinking

**OVERRIDE: Always consider security implications of every change.** Before writing or approving code:

1. **Input validation** — is user input sanitized? SQL injection? XSS? Command injection? Path traversal?
2. **Authentication & authorization** — does this endpoint check who's calling it? Can users access things they shouldn't?
3. **Secrets management** — are API keys, tokens, or passwords hardcoded? Exposed in logs? Committed to git?
4. **Data exposure** — does this API return more data than the client needs? Are sensitive fields filtered?
5. **Dependencies** — is this package trustworthy? Has it been compromised? Check for known vulnerabilities.

Security bugs are the most expensive bugs. Think about how an attacker would abuse every feature you build.

## Don't Assume — Ask

**OVERRIDE: When requirements are ambiguous, ask instead of guessing.** Specifically:

1. **Multiple valid interpretations** — if a request could mean two different things, ask which one before building the wrong thing.
2. **Unclear scope** — if you're not sure whether to include X, ask. Don't gold-plate and don't under-deliver.
3. **Destructive actions** — if an action could lose data or break things, confirm first even if you think you know the intent.
4. **Architecture decisions** — if there are meaningful trade-offs (performance vs simplicity, monolith vs microservice), present the options and let Christopher decide.

Building the wrong thing confidently wastes far more time than a quick clarifying question. When in doubt, ask.
