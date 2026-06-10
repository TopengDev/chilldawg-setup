# Secrets — at-rest encryption (age)

How credentials are handled in this environment, and how they're encrypted at rest.

## The plaintext source

All runtime credentials live in `~/.claude/secrets.env` (an `export VAR=value` file). It is
**gitignored** (never committed) and sourced by `~/.bashrc`, so every shell + child process gets the
env vars (`$VPS_HOST`, `$CLOUDFLARE_API_TOKEN`, `$ANTHROPIC_API_KEY`, signal-trader, wa-sender,
NetBird, email, Pulse test creds, …). This file is **load-bearing** — a broken swap bricks every
cred-dependent daemon, so changes to how it's loaded are done carefully and reversibly.

The canonical reference pattern everywhere else (scripts, briefs, docs) is **by variable name** —
`$VPS_PASSWORD`, or "see `~/.claude/secrets.env`" — **never a literal value**. See "no-creds-in-brief"
below.

## At-rest encryption (age) — STAGED

The plaintext can be encrypted at rest with [age](https://age-encryption.org) (single no-sudo Go
binary, X25519). Built + verified, **staged for a supervised cutover** — not yet the primary path.

| Piece | Path | |
|---|---|---|
| age / age-keygen | `~/.local/bin/age{,‑keygen}` | v1.3.1, no-sudo |
| age master key | `~/.config/age/keys.txt` (600) | **gitignored. Lose it = lose every secret.** Back up off-machine. |
| encrypted blob | `~/.claude/secrets.env.enc` (600) | **gitignored, machine-local.** Opaque — no var names leak. |
| decrypt wrapper | `claude/scripts/load-secrets.sh` | decrypts in-memory → exports; never writes plaintext to disk; fail-open |
| parity gate | `claude/scripts/verify-secrets-parity.sh` | proves decrypt env == plaintext env, var-by-var (sha256), NAMES-only output |

**Whole-file `age`, not `sops --input-type dotenv`:** the file is `export VAR=…` format; sops-dotenv
mis-parses the `export ` prefix (fragile) *and* leaves all var NAMES in plaintext. Whole-file age is an
opaque blob with zero metadata leak and a byte-identical decrypt. (sops is installed for completeness,
but the `.enc` is plain age.)

### Loading from the encrypted blob

```bash
source ~/.claude/scripts/load-secrets.sh   # decrypts ~/.claude/secrets.env.enc, exports the vars
```
It's fail-open: if the age binary / key / `.enc` is missing it prints a loud warning and returns
(so a broken setup never locks you out of new shells). Knobs: `AGE_KEY_FILE`, `SECRETS_ENC_FILE`,
`AGE_BIN`, `LOAD_SECRETS_QUIET=1`.

### Verifying parity (the cutover safety gate)

```bash
~/.claude/scripts/verify-secrets-parity.sh   # GREEN = decrypt path identical to plaintext path
```
GREEN (exit 0) is the precondition for switching `.bashrc` over. It compares the exported environment
(not file text) so it's format-agnostic, and it prints only var NAMES + (high-entropy) sha256 — never
a value, never a crackable hash of a short value.

### The cutover

The supervised flip (the exact `.bashrc` from→to, the test-in-one-shell procedure, rollback,
**off-machine key backup**, and an honest threat-model) is documented step-by-step in the task notes:
`~/claude/notes/setup-overhaul-wave5-hardening-2026-06-11/CUTOVER.md`.

**Threat model in one line:** at-rest encryption stops casual disk reads / accidental backup+repo
leaks / `sk-`-greppers and makes the blob safe to sync — it does **not** stop a determined local
attacker (the key is on the same disk) and secrets are still plaintext in process memory after
decrypt. Defense-in-depth, not a vault.

## No-creds-in-brief discipline

Delegation machinery must never carry literal secrets. `claude/scripts/brief-worker.sh` has a
**fail-open pre-flight** that scans every outgoing worker brief for the gitleaks prefix set
(`sk-ant-`, `sk-`, `ghp_`/`gh*_`, `github_pat_`, `AKIA`, `AIza`, `xox*`, PEM private keys). On a hit it
prints a loud warning naming the **pattern-class + line number** (never the value) and **proceeds
anyway** (a brief that legitimately discusses a key prefix must still send). It deliberately does **not**
fire on var-references (`$FOO`, `${FOO}`) or the literal string `secrets.env` — those are the correct
pattern. Silence it with `CHILLDAWG_BRIEF_ALLOW_SECRETS=1`.

This complements the **global pre-push gitleaks hook** (`config/git/hooks`, custom toml with the
Anthropic `sk-ant-` rules the stock 8.21.x ruleset lacks) which blocks secrets from reaching any remote.
