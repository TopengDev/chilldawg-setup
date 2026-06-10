# Skill eval format (`evals/evals.json`)

`skill-eval.sh` STRUCTURALLY validates every `evals/evals.json` it finds (parses,
checks `skill_name`, asserts each case is well-formed). This doc is the schema +
the two supported eval *kinds* a skill can adopt.

A skill opts in by adding **`<skill>/evals/evals.json`**. Nothing else is required;
the harness picks it up automatically and fails CI if it is malformed.

```json
{
  "skill_name": "<must equal the skill dir name>",
  "evals": [ <one or more eval cases> ]
}
```

Every case needs an `id` and a `prompt`, plus EITHER judgment criteria
(`assertions` / `expected_output`) OR runnable `checks` (or both).

---

## Kind A — judgment evals (the existing format)

Used by `content-strategy` and `launch-strategy`. Each case describes the prompt,
a prose `expected_output`, and a list of natural-language `assertions`. These are
graded by a human or an LLM judge (NOT by `skill-eval.sh` — the harness only
validates their STRUCTURE, since grading needs a model in the loop).

```json
{
  "id": 1,
  "prompt": "Help me build a content strategy for our B2B SaaS product ...",
  "expected_output": "Should check for product-marketing-context.md first. Should establish 3-5 content pillars ...",
  "assertions": [
    "Checks for product-marketing-context.md",
    "Establishes 3-5 content pillars",
    "Uses prioritization scoring framework"
  ],
  "files": []
}
```

- `expected_output` — prose description of what a correct response does.
- `assertions[]` — atomic, checkable claims (what a grader looks for).
- `files[]` — optional fixture file paths the eval prompt references.

Best for **strategy / advisory / generative** skills where "correct" is a
judgment call, not a string match.

---

## Kind B — runnable evals (the deterministic format)

For skills whose output CAN be checked mechanically (a file was written, a command
exited 0, output contains a token). Add a `checks[]` array; each check is an object
with a `type`. `skill-eval.sh` validates the SHAPE today (EV4); a future
`skill-eval.sh --run` can EXECUTE them (the format is designed to be runnable).

```json
{
  "id": 1,
  "prompt": "/invoice \"Acme\" \"Website\" 5000000",
  "checks": [
    { "type": "output_contains",  "value": "Acme" },
    { "type": "output_matches",   "pattern": "Rp\\s?5[.,]000[.,]000" },
    { "type": "file_exists",      "path": "out/invoice-*.pdf" },
    { "type": "file_contains",    "path": "out/ledger.jsonl", "value": "Acme" },
    { "type": "exit_code",        "equals": 0 },
    { "type": "json_field",       "path": "result.json", "field": "status", "equals": "done" }
  ]
}
```

Supported `type`s (the vocabulary `--run` will honor):

| type              | required keys                | passes when …                                  |
|-------------------|------------------------------|------------------------------------------------|
| `output_contains` | `value`                      | the run's stdout contains `value`              |
| `output_matches`  | `pattern`                    | stdout matches the regex `pattern`             |
| `output_excludes` | `value`                      | stdout does NOT contain `value`                |
| `file_exists`     | `path` (glob ok)             | a file matching `path` exists after the run    |
| `file_contains`   | `path`, `value`              | that file contains `value`                     |
| `exit_code`       | `equals`                     | the run exit code equals `equals`              |
| `json_field`      | `path`, `field`, `equals`    | JSON file's dotted `field` equals `equals`     |

Best for **deterministic / artifact-producing** skills (invoice, worklog,
deploy-landing, project-init) where success is observable on disk or in output.

---

## Validation (what the harness enforces now)

`skill-eval.sh` asserts, per `evals.json`:

- **EV1** parses as JSON.
- **EV2** `skill_name` equals the dir name AND `evals` is a non-empty array.
- **EV3** every case has `id` + `prompt` + (at least one of `assertions` /
  `expected_output` / non-empty `checks`).
- **EV4** every `checks[]` entry is an object with a `type`.

A malformed `evals.json` is a CI **FAIL** (exit 1). Add evals freely — a broken
eval file can never silently rot.

---

## Adding evals to a skill (checklist)

1. Create `<skill>/evals/evals.json` with `skill_name` = the dir name.
2. Pick a kind: **A** (judgment) for advisory skills, **B** (runnable) for
   artifact/deterministic skills. Mixing is allowed per case.
3. 3–8 cases covering: the happy path, a casual-phrasing trigger, an edge case,
   and a "should DEFER to another skill" boundary case.
4. Run `skill-eval.sh <skill>` — it must report `EV1/EV2/EV3` PASS.
