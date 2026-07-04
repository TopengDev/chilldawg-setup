# oneshot-webapp - LLM Demo Recipe (server-side + deterministic fallback)

The mandatory recipe when the demo uses an LLM (NON-NEGOTIABLE 5). The model is called SERVER-SIDE
only, the key never reaches the client, and a deterministic fallback guarantees the live demo NEVER
breaks. All prose is ASCII (no em/en dashes). NEVER print a key value anywhere; report file + pattern
only. If the demo has NO LLM feature, ignore this file entirely (the LLM rule collapses to the GATE 2
secret-scan grep).

---

## 1. Where the key lives (verified caveat)

- Reuse the existing OpenRouter setup: model `anthropic/claude-sonnet-4.6` (same as hiremeup).
- The key belongs ONLY in the container env: `~/apps/<slug>/.env`, `chmod 600`, server-side. NEVER
  `NEXT_PUBLIC_`, never baked into the image, never committed.
- `OPENROUTER_API_KEY` is EMPTY in the local `~/.claude/secrets.env` (verified 2026-07-03). The key
  exists ONLY in a VPS app `.env` if at all. The historical pattern is `~/apps/hiremeup/.env` on the
  VPS (project_hiremeup). Pull the KEY PATTERN from there ONLY if present.
- STOP-and-ask branch (HARD): if that `.env` is absent or the key looks rotated, STOP and ask Toper.
  NEVER mint a new key, and NEVER silently reuse another product's key. Note: `$ANTHROPIC_API_KEY`
  IS set locally and could drive a direct-Anthropic call, but it is a SEPARATE credit pot (signal-
  trader / Beacon use it) and may be used ONLY with Toper's explicit ok. Default = ask.
- deploy.sh preserves `~/apps/<slug>/.env` across a re-deploy's source wipe and reuses it when `--env`
  is omitted, so an iteration deploy does not silently strip the key (FP-6).

---

## 2. The 402 pre-auth mechanic (hiremeup's #1 verified failure, 2026-05-24)

OpenRouter PRE-AUTHORIZES the model's full `max_tokens` reservation at request time. Actual billing is
only tokens USED, but the pre-flight check needs the balance to cover the whole reservation. So when
the balance drops below the reservation, the request 402s on PRE-FLIGHT even though the real usage
would have been affordable. The user-facing symptom is a generic "AI unavailable" while the real error
is HTTP 402 in the container logs.

Consequences baked into this recipe:
- Diagnostic order when the AI misbehaves: CHECK THE OPENROUTER BALANCE FIRST (openrouter.ai/settings/
  credits). Top-up is Toper's billing action.
- Keep `max_tokens` bounded (see 4): a huge `max_tokens` inflates the reservation and 402s earlier.
- Map 402 to a NON-RETRYABLE `INSUFFICIENT_CREDITS` error (hiremeup fix, commit f4c48fa): retrying a
  402 just burns time, the balance will not refill mid-request.

---

## 3. Server-side route handler (shape)

```ts
// app/api/<feature>/route.ts  - SERVER ONLY. Key from process.env, never exposed.
export const runtime = "nodejs";           // not edge: keep the key + fetch server-side

const SYSTEM = "You are <role>. Respond TERSELY. Output ONLY valid JSON matching the schema. " +
  "Cap the list at N items. No prose, no markdown fences.";       // terseness caps truncation risk

export async function POST(req: Request) {
  const input = await req.json();
  try {
    const r = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        // ASCII-ONLY headers. An em-dash in X-Title throws
        // "Cannot convert argument to a ByteString" and the call silently fails to fallback.
        "X-Title": "oneshot demo",                 // plain ASCII, no long dash
        "HTTP-Referer": "https://<slug>.topengdev.com",
      },
      body: JSON.stringify({
        model: "anthropic/claude-sonnet-4.6",
        max_tokens: 4096,                          // >= 4096, capped (see 4); NOT unbounded
        messages: [{ role: "system", content: SYSTEM }, { role: "user", content: JSON.stringify(input) }],
        response_format: {                          // structured output the UI can consume safely
          type: "json_schema",
          json_schema: { name: "result", strict: true, schema: RESULT_SCHEMA },
        },
      }),
    });

    if (r.status === 402) return served(fallback(input), "http_402");   // NON-retryable: credits
    if (!r.ok)           return served(fallback(input), `http_${r.status}`);
    const data = await r.json();
    const text = data?.choices?.[0]?.message?.content ?? "";
    let parsed; try { parsed = JSON.parse(text); } catch { return served(fallback(input), "parse_fail"); }
    return served(parsed, "model");
  } catch (e) {
    return served(fallback(input), "timeout");     // network/timeout: NON-retryable, serve fallback
  }
}

// served() attaches a served-path marker so FP-6 can tell which path answered.
function served(payload: unknown, path: string) {
  console.log(`[llm] served: ${path === "model" ? "model (openrouter)" : "fallback"} (reason=${path})`);
  return Response.json({ ...(<object>payload), _served: path });
}
```

---

## 4. max_tokens + terseness (avoid truncation AND latency)

- `max_tokens` >= 4096 (below it, complex demo output truncates -> `finish_reason: length` -> JSON
  parse fail -> fallback). Cap it: 16384 is the proven hiremeup ceiling. Do NOT just crank it higher:
  a bigger reservation 402s earlier (section 2) AND long generations risk the Cloudflare 100s edge
  timeout.
- The REAL truncation fix is to CONSTRAIN the model, not to raise the cap blindly: terse fields, cap
  the item/op count in the system prompt, `response_format: json_schema` so the shape is fixed.

---

## 5. Deterministic fallback (the demo must survive an API failure)

The fallback is a pure, deterministic function that produces plausible, on-brand output for the EXACT
demo scenario, with no network call. It fires on 402 / non-2xx / timeout / JSON-parse-fail, all treated
as NON-RETRYABLE (retrying any of them just stalls the live demo).

```ts
function fallback(input: Input): Result {
  // Hand-authored, scenario-specific canned result. Realistic seed values, on-brand copy,
  // dash-free (the §0.4 no-dash rule applies to fallback strings too). Deterministic: same
  // input -> same output, so a rehearsal is repeatable.
  return CANNED_RESULT_FOR(input);
}
```

- A visible "Simulate AI failure" toggle (a query flag or a dev-only switch) that forces the fallback
  path is useful for rehearsals: it lets Toper prove the demo survives an outage on stage.
- Before handoff you MUST fire the REAL model path once live (confirm `served: model`), because a
  fallback-only pass is not proof the key/route works. Then reset the demo to a clean seed.

---

## 6. Reset-demo-seed

Ship a "Reset demo" control (a server action that rewrites `data/db.json` from the seed). After you
fire the real path during verification, RESET so Toper opens a pristine state. The JSON-file store
(`data/db.json`, writable `/app/data` in the Dockerfile) is the demo persistence layer, NOT SQLite/
Prisma (native-binding + migration risk in Alpine).

---

## 7. GATE 2 secret scan (the LLM-path grep)

Even a no-LLM demo runs this; an LLM demo must pass it before deploy:

```bash
# zero hits expected: no client-exposed keys, no inline sk- keys
grep -rEn 'NEXT_PUBLIC_[A-Z_]*(KEY|TOKEN|SECRET)|sk-or-[A-Za-z0-9]|sk-ant-[A-Za-z0-9]' . \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.json' --include='*.env*'
```

Any hit = a secret is client-reachable or committed. Fix before deploy. If a hit is a real captured
key, report the FILE and the PATTERN TYPE only, never the value.

---

## Freshness ledger

- OpenRouter model `anthropic/claude-sonnet-4.6` + 402 pre-auth + f4c48fa fix: project_hiremeup (2026-05-24).
- `OPENROUTER_API_KEY` empty locally, `ANTHROPIC_API_KEY` set: verified 2026-07-03.
- ASCII-header ByteString throw + max_tokens truncation + json_schema: encoded from the Selaras build.
- JSON-file store rationale (Alpine SQLite/Prisma risk): SKILL.md Phase 3, proven on bithour-ops-pm.
