# /creative - Model Reality Reference (progressive-disclosure depth)

Read this file when you need the FULL model surface: the availability pre-flight, the
verified Gemini/nanobanana parameter reference, the true-4K path, the MCP-flaky fallback,
the negative-prompt phrase table, or the UNVERIFIED optional-lane recipes. SKILL.md carries
the summary + the hard rules; this file carries the detail so SKILL.md stays under its cap.

Everything here was verified against the live tool schemas, the env, and the zografee engine
on **2026-07-03**, EXCEPT the sections explicitly headed `UNVERIFIED` (the non-Gemini lanes,
which were carried forward from the prior skill version and NOT re-tested this session).

---

## 1. Availability pre-flight gate (RUN THIS BEFORE ROUTING)

A lane may be routed to ONLY if its row passed the pre-flight in THIS session. Do not assume a
lane from a past run is still live. All checks below are read-only.

**Key presence (one portable command - works in bash and zsh):**
```bash
for v in OPENAI_API_KEY RECRAFT_API_KEY FLUX_API_KEY NANOBANANA_API_KEY; do
  eval "val=\${$v}"; [ -n "$val" ] && echo "$v: SET" || echo "$v: MISSING"
done
```

**MCP presence (observe your own tool list - do NOT call the tools):** the nanobanana tools
(`gemini_generate_image`, `gemini_edit_image`, `set_model`, `set_aspect_ratio`, `gemini_chat`,
`get_image_history`, `clear_conversation`) are present when nanobanana is installed. Recraft
tools are present only if the recraft MCP was added AND Claude Code was restarted.

**Optional config sanity (read-only):**
```bash
jq -r '.mcpServers | keys[]' ~/.claude.json            # lists installed MCP servers
```

| Lane | Passes pre-flight when | Verified state 2026-07-03 |
|---|---|---|
| **Gemini (nanobanana MCP)** | `gemini_*` tools in your tool list | PRESENT (only installed MCP server) |
| **Recraft** | recraft MCP tools present OR `RECRAFT_API_KEY` set (curl) | KEY SET; MCP NOT installed -> curl-only |
| **GPT Image (curl)** | `OPENAI_API_KEY` set | SET |
| **FLUX (curl)** | `FLUX_API_KEY` set | SET |

`BFL_API_KEY` does **not** exist anywhere in the env. Any check or curl that references
`$BFL_API_KEY` is dead. The Black Forest Labs key lives in `FLUX_API_KEY`.

---

## 2. Verified Gemini economics (the only cost numbers to trust)

Source: Christopher's Google Cloud billing check, 2026-06-16 (`project_creative_content_factory`).
Gemini image gen has **no free tier**; billed in IDR behind the Google Cloud project key.

| Model (direct-REST IDs) | Rate | Use |
|---|---|---|
| `gemini-2.5-flash-image` (flash) | **$0.039 / img** | ideation variants (cheap, explore breadth) |
| `gemini-3-pro-image` (Pro) @ 1K/2K | **$0.134 / img** | final render |
| `gemini-3-pro-image` (Pro) @ 4K | **$0.24 / img** | true-4K finalize (4x flash output-token rate) |

- Entire 7-job / ~100-image test phase (incl. a ~15-round grind) billed **Rp 45.780 ≈ $2.80**.
- That is **≈ $0.30-1.00 per finished multi-round job**. The factory is economically viable at scale.
- The MCP flash/pro map to `-preview` variants (`gemini-3.1-flash-image-preview` /
  `gemini-3-pro-image-preview`); treat their cost as the same order of magnitude, and prefer the
  cheap-flash-ideate -> Pro-finalize shape regardless of surface.
- **UNVERIFIED (carried forward, not re-checked):** Recraft ~$0.04-0.30/img · GPT `gpt-image-1`
  ~$0.009-0.133/img · FLUX ~$0.03-0.055/img. Do not quote these as fact.

---

## 3. Gemini via nanobanana MCP - verified parameter reference

Live tool schemas (2026-07-03). This is the PRIMARY engine surface. There is **no imageSize/4K
parameter on any MCP tool** (see section 4 for true-4K).

### `set_model` (call once per session, or per `conversation_id`)
- `model`: `"flash"` = `gemini-3.1-flash-image-preview` · `"pro"` = `gemini-3-pro-image-preview`.
- `conversation_id` (optional, default `"default"`).
- Policy: **flash to ideate, pro to finalize.** flash is the cheap breadth pass; pro nails
  bold composition + precise editorial type + exact supplied copy.

### `set_aspect_ratio` (call before generating if a ratio matters)
- `aspect_ratio` enum (the ONLY valid values): `1:1 · 9:16 · 16:9 · 3:4 · 4:3 · 3:2 · 2:3 · 5:4 · 4:5 · 21:9`.
- `conversation_id` (optional). A ratio outside this enum is rejected. `gemini_generate_image`
  and `gemini_edit_image` also take `aspect_ratio` directly, which overrides the session setting.

### `gemini_generate_image`
| Param | Notes |
|---|---|
| `prompt` (required) | the constructed spatial-first prompt (Phase 3) + the negative block (section 6). |
| `output_path` | **ALWAYS PASS THIS.** If omitted, the file saves to `~/Documents/nanobanana_generated/` and leaves your job dir. Point it at `<job-dir>/variants/<name>.png`. |
| `aspect_ratio` | enum above; overrides session ratio. |
| `conversation_id` | reuse the SAME id across a job to hold style/character consistency. |
| `reference_images` | array of file paths -> feed brand-kit `references` here for brand consistency (NOT as a fidelity target; fidelity-to-a-reference is /zografee). |
| `use_image_history` | `true` includes this session's prior generations for consistency. |
| `enable_google_search` | real-world grounding; off unless you need real logos/landmarks. |

### `gemini_edit_image` (the refine-the-pick tool)
| Param | Notes |
|---|---|
| `image_path` (required) | a file path, or `"last"` (most recent), or `"history:N"` (by index, e.g. `history:0`). |
| `edit_prompt` (required) | natural-language edit. For a refine pass: "keep composition + exact text, polish X". |
| `output_path` | **ALWAYS PASS THIS** (same trap as generate). |
| `reference_images` | max 10; file paths / `"last"` / `"history:N"`. |
| `aspect_ratio`, `conversation_id`, `enable_google_search` | as above. |

### `gemini_chat`, `get_image_history`, `clear_conversation`
- `gemini_chat(message, [conversation_id], [images<=10], [system_prompt])` - Gemini 3.1 Flash chat;
  useful to reason about a candidate image before editing.
- `get_image_history(conversation_id)` - list the session's generated images (for `history:N` refs).
- `clear_conversation(conversation_id)` - reset a session's history.

### Text-garble caveat (hard rule, see SKILL.md §1)
Do NOT try to repair misspelled/garbled text with `gemini_edit_image`. Regenerate with the text
re-specified in quotes. Editing rarely fixes character-level text errors.

---

## 4. True high-res (4K) - NOT on the MCP

The MCP tools cap out well below 4K and expose no size knob. An ImageMagick/Lanczos upscale is
**fake resolution** (interpolation) and must never be delivered as hi-res (SKILL.md §1).

True high-res = re-render the APPROVED variant through Gemini 3 Pro at 4K via the zografee
direct-REST engine (which sets `generationConfig.imageConfig.imageSize:"4K"`, unavailable to the MCP):

```
# scripts live in the zografee repo, NOT in this skill dir - cite, don't duplicate
~/claude/Git/repositories/zografee/engine/generate.py
  finalize(chosen_png, instruction, out, aspect="3:4", size="4K", model=gemini.PRO)
    -> gemini.edit(...) at imageSize 4K, ~3584px long edge (verified 3584x4800 at 3:4)
  FINALIZE_INSTRUCTION  # canonical "keep design + exact text, maximize resolution" prompt
```

Recipe: pass the chosen PNG as the input image + the finalize instruction ("keep design/text,
maximize resolution"). **Warn Christopher that the Pro re-render slightly REINTERPRETS the design**
(usually an improvement, occasionally cleans linework). If a pixel-identical-but-bigger result is
required, say so honestly - no local upscaler (Real-ESRGAN) is installed, so we cannot do a
faithful non-generative upscale.

---

## 5. Failure playbook - nanobanana MCP flaky -> direct REST

The MCP has a verified flakiness history (the 2026-06-15 AI Workshop poster run bypassed it
entirely). **Never conclude "Gemini is down" from a single MCP failure.** On two consecutive tool
errors on the same call, switch to the direct-REST engine:

```
~/claude/Git/repositories/zografee/engine/gemini.py
  generate(prompt, out, model=FLASH|PRO, aspect, size)
  edit(image_path, prompt, out, model=FLASH|PRO, aspect, size)
  # direct REST to the Generative Language API, bypasses the MCP.
  # retry-on-transient built in: 429/500/502/503/504 + network, with backoff
  #   (a lone 503 mid-job otherwise aborts it).
  # key resolves automatically (GOOGLE_AI_API_KEY: secrets.env first, then walks ~/.claude.json).
```

Do NOT print the key. Do NOT hand-retry a transient 503 by aborting - the engine's backoff owns
retries. `NANOBANANA_API_KEY` also exists in the env for the MCP server, but the direct-REST engine
uses `GOOGLE_AI_API_KEY` as above; let `resolve_key()` handle it.

---

## 6. Hard-bans -> negative-prompt phrase table (moved from SKILL.md)

The 20 hard bans + their scan live in SKILL.md. This is the lookup that turns each ban into
model-ready negative phrasing. **Build the negative block = archetype negatives + ALL 20 phrases
below + any user constraints**, then format per model.

| # | Ban | Negative phrase |
|---|---|---|
| 1 | gradient backgrounds | "no gradient backgrounds, no color transitions, no gradient overlays, no linear gradient, no radial gradient, no mesh gradient" |
| 2 | glow/aura/neon | "no glow, no neon glow, no luminous edges, no light emission effects, no aura, no outer glow, no bloom" |
| 3 | drop shadows | "no drop shadow, no floating shadow, no box shadow effects, no shadow beneath text" |
| 4 | centered symmetric | "no centered layout, no symmetrical composition, no perfectly balanced, no mirror symmetry" |
| 5 | generic sans-serif | "no generic font, no default typography, no Arial, no Helvetica, no system font" |
| 6 | 3D device mockups | "no phone mockup, no laptop mockup, no device frame, no app-in-phone template, no 3D device" |
| 7 | floating no-context | "no floating elements, no objects without ground, no disconnected elements, no elements in void" |
| 8 | abstract blobs | "no amorphous blobs, no gradient blobs, no abstract organic shapes, no floating blob shapes" |
| 9 | isometric | "no isometric, no isometric illustration, no 3D isometric view, no isometric tech art" |
| 10 | generic tech visuals | "no circuit board, no binary code, no digital particles, no matrix rain, no digital wave, no tech pattern" |
| 11 | lens flare / light leaks | "no lens flare, no light leak, no photographic artifact, no bokeh overlay, no light streak" |
| 12 | soft pastels | "no washed out pastel, no soft pastel colors, no muted baby colors, no faded pastel" |
| 13 | rounded-rect app cards | "no app card, no rounded rectangle card, no Dribbble card layout, no card-based template" |
| 14 | glassmorphism blur cards | "no frosted glass overlay, no glassmorphism card, no blur card background, no transparent blur panel" |
| 15 | geometric pattern fills | "no triangle pattern, no hexagon pattern, no dot grid background, no geometric texture fill" |
| 16 | starburst / radial burst | "no starburst, no radial burst, no sunburst behind text, no radial lines, no explosion lines" |
| 17 | stock-photo compositing | "no stock photography, no pasted-in photo, no composite stock image, no generic stock people" |
| 18 | generic icon grids | "no icon grid, no grid of icons with labels, no feature icon layout, no uniform icon set" |
| 19 | SaaS landing template | "no website template, no Webflow template, no SaaS landing page, no generic web layout" |
| 20 | purposeless decoration | "no decorative elements, no unnecessary ornament, no filler decoration, no pointless embellishment" |

**Model-specific formatting:**
- **Gemini (MCP):** append as a `Do not include: [comma-separated phrases]` block at the end of the prompt.
- **GPT Image (curl):** inline as an `Avoid the following: [phrases]` section in the prompt text.
- **Recraft (curl):** pass `negative_prompt` if supported, else inline `Avoid: [phrases]`.
- **FLUX (curl):** pass the `negative_prompt` field.

Reminder: the negative block is belt-and-suspenders. The real enforcement is the **post-generation
20-ban scan** in SKILL.md - any hit = reject + regenerate from a revised prompt, never patch by editing.

---

## 7. UNVERIFIED optional lanes (smoke-test-FIRST, every session)

These three lanes are **UNVERIFIED as of 2026-07-03** - the payloads/model IDs/endpoints were
carried forward from the prior skill version and NOT re-tested this session (Recraft MCP is not
installed; the curl payloads were never re-run here). House rule "Don't Hallucinate APIs" applies:
**before using ANY recipe below in a real job, run ONE cheap smoke generation and assert the
response shape.** If the smoke test fails, fall back to Gemini (which is the fallback for every
asset type) and report the lane dead. Do NOT "upgrade" a payload to match a nicer headline name
(e.g. `gpt-image-1` -> `gpt-image-1.5`, or `flux-pro-1.1` -> a `flux-2` endpoint) - that is how you
get 4xx failures mid-job. Headline names below are pinned to what the payloads actually send.

### 7a. GPT Image - `gpt-image-1` (curl, `OPENAI_API_KEY`)
Strengths (from prior testing): best text-rendering accuracy; conservative composition (softens
edges, warm-shifts white toward cream, will NOT crop type at frame edges). Good for structured
multi-text layouts where every word matters; weak for bold asymmetric composition.
```bash
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "model": "gpt-image-1", "prompt": "...", "size": "1024x1024",
        "quality": "medium", "n": 1, "output_format": "png" }'
# response = base64; decode: echo "$b64" | base64 -d > <job-dir>/variants/<name>.png
# quality "medium" for iterations, "high" only for the final.
# edits: POST /v1/images/edits with the image as input (supports a mask for targeted edits).
```

### 7b. FLUX - `flux-pro-1.1` (curl, `FLUX_API_KEY`, async)
This endpoint is **FLUX 1.1 Pro**, not "FLUX.2". Auth header is `x-key: $FLUX_API_KEY` (NOT
`$BFL_API_KEY`). Photorealistic mockups / product photography; prompt it like a photographer
(camera, lens, lighting, depth of field). Bad at text (treats it as texture).
```bash
TASK_ID=$(curl -s -X POST "https://api.bfl.ai/v1/flux-pro-1.1" \
  -H "x-key: $FLUX_API_KEY" -H "Content-Type: application/json" \
  -d '{ "prompt": "...", "width": 1024, "height": 1024 }' | jq -r '.id')
for i in $(seq 1 12); do                     # poll 5s x up to 60s
  RESULT=$(curl -s "https://api.bfl.ai/v1/get_result?id=$TASK_ID" -H "x-key: $FLUX_API_KEY")
  [ "$(echo "$RESULT" | jq -r '.status')" = "Ready" ] && {
    curl -s -o "<job-dir>/variants/<name>.png" "$(echo "$RESULT" | jq -r '.result.sample')"; break; }
  sleep 5
done
# NOTE: the .result.sample URL is a signed URL - extract the file, never paste the full response into a report.
```

### 7c. Recraft - `recraftv4` / `recraftv4_vector` (MCP or curl, `RECRAFT_API_KEY`)
The ONLY lane with native SVG output -> logos, icons, brand vectors. Cleanest rendering, but
typographically flat (weak bold/thin weight contrast). Raster fallback (Gemini) needs manual
vectorization for production logos/icons - keep that warning in `prompts/logo.md` + `prompts/icon.md`.

- **Style enum (documented, UNVERIFIED):** `realistic_image`, `digital_illustration`,
  `vector_illustration`, `icon`. Models: `recraftv4` (raster) / `recraftv4_vector` (SVG).
- **Single source of truth for the style param:** a prior skill note claimed `recraftv4` does not
  accept `digital_illustration`; that was never verified here and is NOT authoritative. **Resolve
  it by smoke test:** run one cheap generation with your intended `style` and assert a 200 + a
  usable asset. Whatever the smoke test shows wins. Do not hard-code the claim either way.
```bash
curl -s -X POST "https://external.api.recraft.ai/v1/images/generations" \
  -H "Authorization: Bearer $RECRAFT_API_KEY" -H "Content-Type: application/json" \
  -d '{ "prompt": "...", "model": "recraftv4_vector", "style": "vector_illustration",
        "size": "1024x1024", "response_format": "url" }' | jq -r '.data[0].url'
# download: curl -s -o "<job-dir>/variants/<name>.svg" "<url>"
```

### 7d. Recraft MCP install (corrected - the settings.json path is dead)
Recraft MCP is NOT installed. The nanobanana server is registered in `~/.claude.json` (the
`claude mcp add` store); **`~/.claude/settings.json` has NO `mcpServers` key** (verified
2026-07-03). Writing a `mcpServers` block into settings.json does nothing.
```bash
claude mcp add recraft -- npx @recraft-ai/mcp-recraft-server@latest   # writes to ~/.claude.json
```
- Requires `RECRAFT_API_KEY` in env (SET).
- **Requires a Claude Code restart** for the new MCP tools to load into the tool list.
- The package name + tool surface (`@recraft-ai/mcp-recraft-server`, a `generate_image` tool) are
  **verify-at-install-time** - after restart, confirm the recraft tools appear, then run a 1-image
  smoke generation before routing any real logo/icon job to it.
