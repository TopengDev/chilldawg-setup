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

Editing code you don't fully understand is how regressions are born. Make extra effort to read.

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

1. **Prototype & smoke test first** — if the task involves anything new (library, API, design, integration), validate assumptions with throwaway prototypes BEFORE planning. See "Prototype & Smoke Test Before Planning" in Agent Work Protocol below.
2. **State your approach first** — before writing any code, outline what you're going to do and why.
3. **Identify affected areas** — list every file and system that will be impacted by the change.
4. **Consider alternatives** — is there a better approach? What are the trade-offs?
5. **Flag risks** — what could go wrong? What assumptions are you making?
6. **Get alignment** — if the approach has trade-offs, check with Christopher before committing to one direction.

For small, obvious changes (rename a variable, fix a typo, add a log line) — just do it. But for anything with moving parts, prototype → plan → execute.

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

---

# Agent Work Protocol

## Prototype & Smoke Test Before Planning

**OVERRIDE: Do NOT plan or implement with unvalidated assumptions.** Before committing to a plan for anything new (new feature, new library, new integration, new design):

1. **Prototype first** — build a small, throwaway proof-of-concept that tests the core hypothesis. Multiple iterations. Does the API actually return what you think? Does the UI look right with these colors? Does the library work with your stack version?
2. **Smoke test the tools** — before planning implementation around a tool/library/framework, run it. Install it, call its API, render its output, hit its edge cases. Note what works, what doesn't, what's undocumented.
3. **Note constraints and issues** — write down what you discovered. Broken features, version incompatibilities, rate limits, missing docs, unexpected behavior. These become planning inputs.
4. **Minimize assumptions** — every assumption in a plan is a risk. Replace assumptions with verified facts from prototypes. If you can't verify, flag it explicitly as an assumption.
5. **THEN plan** — only after prototyping + smoke testing, draft the real plan. The plan should reference what you validated and what constraints you discovered.

A plan built on assumptions wastes more time than the prototype would have taken. Christopher rejected the Gruvbox reskin after full implementation — a 10-minute color-swap prototype on one page would have caught that. Prototype iterations are cheap; full implementations based on wrong assumptions are expensive.

## Equip Before Delegating

**OVERRIDE: Do NOT delegate work to a spawned session without equipping it fully.** Before any implementation brief:

1. **Credentials** — does the agent need login credentials, API keys, SSH access? Include them or tell the agent where to find them (`~/.claude/secrets.env` pattern). Don't let the agent discover mid-task that it can't authenticate.
2. **Tools** — does the agent need qutebrowser, grpcurl, a running dev server, a specific MCP plugin? Verify availability BEFORE briefing. If a tool isn't installed or configured, set it up first.
3. **Access level** — is the agent authorized for read-only or read-write on prod? On git push? On container restarts? State this explicitly in the brief.
4. **Context** — does the agent need to read specific files, memory entries, prior investigation findings? Include paths or inline the critical context. Don't assume the agent will find what it needs.
5. **Test accounts** — if verification requires a logged-in session, provide test credentials upfront (from `$PULSE_TEST_*` or equivalent). Don't let the agent hit auth walls mid-verification.
6. **Attn shim** — is the attn local peer shim running? Can the agent report back? Verify the round-trip BEFORE briefing. **NO EXCEPTIONS — not even for "quick" or "1-line" tasks.** Every spawned session MUST have attn connected from minute zero. If attn shim is not set up, DO NOT send the brief. Set it up first.

**HARD RULE: Do NOT spawn a session without attn.** The sequence is ALWAYS: (1) create tmux window → (2) start attn shim + verify round-trip → (3) launch claude → (4) paste brief. Never skip step 2. Never "come back to it later." Never judge a task as "too small" to need attn. Christopher should NEVER have to ask "how's the progress" — the agent reports to main via attn automatically on every completion.

An agent that hits a dead end because it lacks credentials, tools, or access wastes its entire context window on workarounds instead of the actual task. An agent without attn is invisible — main has no idea when it finishes. Equip first, brief second.

## Close the Loop — Agents Must Self-Verify and Report Back

**OVERRIDE: An agent's job is NOT done until it has verified its own work end-to-end AND reported back to main.** Every spawned session or delegated task must:

1. **Verify the change works** — not just "it compiles" or "the edit looks right." Run the actual flow. Open the page. Call the API. Check the database. Capture evidence (screenshots, curl output, DB query results).
2. **Verify constraints are met** — if the brief said "light mode must stay pixel-perfect" or "don't break existing tests," explicitly check those constraints and report the check.
3. **Verify in the target environment** — dev verification is necessary but not sufficient. If the change ships to prod, verify on prod after deploy (smoke test, health check, curl).
4. **Report evidence, not claims** — "I verified it works" is a claim. "Screenshot at /tmp/X.png shows the field is disabled, curl returns 200, DB row has status=ACTIVE" is evidence. Always report evidence.
5. **Flag what you COULDN'T verify** — if a test case is untestable (e.g., no draft POs exist to test the button label), say so explicitly and explain what alternative verification you did.
6. **ALWAYS report back to main** — when the task is done (or blocked), the agent MUST send a completion report to the main session / command center via attn. No exceptions. Don't wait to be asked. Don't sit idle after finishing. The report must include: what was done, what was verified, what's pending, and any surprises. Main session needs this to continue the pipeline without Christopher having to relay status.

An unverified "done" is not done. An unreported "done" is invisible. The agent that ships the code must also close the verification loop AND report back.

## Compact After Major Milestones

**OVERRIDE: Proactively manage context window during long sessions.** When using the 1M context window:

1. **After every major milestone** (feature shipped, big investigation complete, multi-phase task done), assess context usage. If above 60%, consider compacting.
2. **Before compaction, save everything important to memory** — decisions made, findings discovered, current state of all open threads, pending tasks, credential/access notes, session states. Memory files survive compaction; context does not.
3. **Update existing memory files** rather than creating duplicates. Check MEMORY.md index for related entries before writing new files.
4. **Write a compaction-safe summary** — if the session will be continued from a compaction summary, make sure the summary includes: (a) what was done, (b) what's pending, (c) what state exists on disk/in git, (d) what decisions Christopher made, (e) any open threads with external parties (attn, WhatsApp).
5. **Don't let context hit 95%+ before acting** — by then it's too late to save everything cleanly. The sweet spot is 60-70%: save state, compact, continue fresh.

## Creative Tasks — ALWAYS Delegate

**OVERRIDE: NEVER execute creative tasks in the main session.** Any task in the creative/design domain MUST be delegated to a spawned session. The main session's role for creative work is DISCUSSION and BRAINSTORMING only.

**What counts as "creative tasks" (delegate ALL of these):**
- Graphic design (social media posts, banners, headers, thumbnails)
- Illustration creation (hero images, spot illustrations, conceptual art)
- Logo design / brand mark creation
- Image generation or editing via any AI model (Gemini, Recraft, OpenAI, FLUX)
- Content asset creation (OG images, email graphics, presentation slides)
- Icon design / icon set creation
- UI mockup generation (not code — visual mockups)
- Photo editing, retouching, compositing
- Any invocation of the `/creative` skill
- Any use of nanobanana MCP tools (gemini_generate_image, gemini_edit_image)
- Any curl/API call to image generation endpoints (Recraft, OpenAI images, FLUX)

**What stays in main session (OK to do here):**
- Discussing design direction, brainstorming concepts, reviewing outputs
- Choosing between design options (A vs B)
- Providing feedback on generated assets ("make it darker", "too busy")
- Brand kit configuration (editing JSON files)
- Design critique and art direction

**Bright-line test:** Does this task generate, edit, or manipulate a visual asset? YES → delegate. Is this a conversation ABOUT design without producing an artifact? → safe in main.

**How to delegate:** Spawn a tmux session, brief it with the creative task + brand context + reference assets, invoke `/creative` skill from there. Follow the standard spawned session protocol (attn shim, auto-report-back, close-the-loop verification).

**IMPORTANT — scope of this rule:** "Main session" means the command-center session in tmux window 1 (the one Christopher interacts with directly). Spawned worker sessions that RECEIVE a creative task brief should EXECUTE it directly — they are the delegation target, not another layer of delegation. Do NOT recursively delegate from a worker session.

**Why:** Creative tasks consume massive context (image data, prompt iterations, multi-variant generation, critique loops). Running them in main pollutes the coordination context and risks hitting context limits during unrelated work. Main session = command center. Creative execution = spawned worker.
