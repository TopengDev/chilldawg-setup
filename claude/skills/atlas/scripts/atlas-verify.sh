#!/usr/bin/env bash
# atlas-verify.sh <dossier-dir> [--legacy] [--run-id <id>]
#
# READ-ONLY dossier validator: runs the mechanical completeness-critic checks
# (SKILL.md Section 9.1: checks 4, 6, 7, 8, 9, 10) against an /atlas dossier.
# - Writes NOTHING. Touches NO browser. Never prints a secret value (check 8
#   reports file + pattern type only).
# - Exit 0 = all checks pass; exit 1 = at least one FAIL.
# - --legacy : downgrade checks 7/9/10 to WARN for pre-v1.2 dossiers whose
#   deviations are documented (references/SCHEMA.md Appendix). Checks 4/6/8
#   (curation leak, dashes, secrets) FAIL even on legacy data.
# - --run-id <id> : scope the journal lint (check 10) to one run's lines.
#
# Every check here also exists as an inline command in SKILL.md 9.1, so the
# skill runs without this script.
set -u

DIR="${1:-}"
[ -d "$DIR" ] || { echo "usage: atlas-verify.sh <dossier-dir> [--legacy] [--run-id <id>]"; exit 2; }
shift
LEGACY=0; RUN_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --legacy) LEGACY=1 ;;
    --run-id) RUN_ID="${2:-}"; shift ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
  shift
done

FAIL=0
soft() {  # FAIL normally, WARN under --legacy
  if [ "$LEGACY" -eq 1 ]; then echo "  WARN (legacy-tolerated): $1"; else echo "  FAIL: $1"; FAIL=1; fi
}
hard() { echo "  FAIL: $1"; FAIL=1; }

echo "== atlas-verify: $DIR (legacy=$LEGACY) =="

# Text-file scope for all greps: a bare recursive grep matches raw PNG bytes
# (verified false-positive on 3 pulse screenshots, 2026-07-02).
TEXTGLOB=(--include='*.json' --include='*.jsonl' --include='*.md' --include='*.txt')

# ---- check 4: banned curation fields (N1) --------------------------------
echo "[check 4] banned-field scan (N1)"
HITS=$(grep -rniE '"(should_show|deck_priority|include_in_deck|is_important|recommended)"[[:space:]]*:' "${TEXTGLOB[@]}" "$DIR" -l 2>/dev/null)
if [ -n "$HITS" ]; then hard "curation-verdict field present in: $HITS"; else echo "  PASS"; fi

# ---- check 6: em/en-dash scan (N9) ---------------------------------------
echo "[check 6] em/en-dash scan (N9)"
HITS=$(grep -rlP '[\x{2013}\x{2014}]' "${TEXTGLOB[@]}" "$DIR" 2>/dev/null)
if [ -n "$HITS" ]; then hard "em/en-dash present in: $HITS"; else echo "  PASS"; fi

# ---- check 7: screenshot referential integrity (N16) ---------------------
echo "[check 7] screenshot referential integrity (N16)"
C7=$(python3 - "$DIR" <<'EOF'
import re, os, sys, glob, json
d = sys.argv[1]
pat = re.compile(r'screenshots/[A-Za-z0-9._-]+\.png')
refs = set()
for f in glob.glob(os.path.join(d,'surfaces/*.json')) + glob.glob(os.path.join(d,'flows/*.json')) \
       + glob.glob(os.path.join(d,'modules/*.json')) + glob.glob(os.path.join(d,'manifest*.json')) \
       + glob.glob(os.path.join(d,'product.json')):
    refs.update(pat.findall(open(f, encoding='utf-8', errors='replace').read()))
sd = os.path.join(d,'screenshots')
disk = {'screenshots/'+x for x in os.listdir(sd) if x.endswith('.png')} if os.path.isdir(sd) else set()
dangling = sorted(refs - disk)
unref = sorted(disk - refs)
print(len(dangling)); print(len(unref))
for x in dangling: print('DANGLING ' + x)
EOF
)
ND=$(echo "$C7" | sed -n 1p); NU=$(echo "$C7" | sed -n 2p)
echo "$C7" | grep '^DANGLING ' | sed 's/^/    /'
if [ "${ND:-0}" -gt 0 ]; then soft "$ND dangling screenshot reference(s)"; else echo "  PASS (0 dangling)"; fi
echo "  note: $NU unreferenced file(s) on disk (enumerate into manifest orphan_screenshots[]; warning, not FAIL)"

# ---- check 8: secret-pattern scan (N14): report file + pattern ONLY ------
echo "[check 8] secret-pattern scan (N14)"
S8=0
scan() { # $1 = pattern label, $2 = grep args...
  local label="$1"; shift
  local hits
  hits=$(grep -rl "${TEXTGLOB[@]}" "$@" "$DIR" 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "  SECRET-PATTERN HIT [$label] in: $hits (value NOT shown; quarantine for human review)"
    S8=1
  fi
}
scan "jwt"        -E 'eyJ[A-Za-z0-9_-]{20,}'
scan "auth-header" -iE '"(authorization|cookie|set-cookie)"[[:space:]]*:[[:space:]]*"[^"]+"'
scan "bearer"     -iE 'bearer [A-Za-z0-9._/+-]{16,}'
scan "cred-field" -iE '"(password|token|secret|api_key|apikey|access_token|refresh_token|session_id)"[[:space:]]*:[[:space:]]*"[^"<$]{4,}"'
if [ "$S8" -eq 1 ]; then hard "secret pattern(s) present; run FAILS; files quarantined for human review"; else echo "  PASS (clean)"; fi

# ---- check 9: fingerprint completeness + role/action lint ----------------
echo "[check 9] fingerprint completeness"
C9=$(python3 - "$DIR" <<'EOF'
import json, glob, os, re, sys
d = sys.argv[1]; bad = 0; swaps = 0
ACTIONS = {'navigate','expander','mutator','mutator-local','control','export-external','export/external'}
for f in sorted(glob.glob(os.path.join(d,'surfaces/*.json'))):
    try: j = json.load(open(f))
    except Exception: print('UNPARSEABLE ' + f); bad += 1; continue
    fr = j.get('freshness') or {}
    if 'fingerprint' not in fr:
        print('BADFP %s fingerprint field ABSENT' % os.path.basename(f)); bad += 1
    else:
        fp = fr['fingerprint']
        ok = (fp is None and (j.get('gaps') is not None)) or \
             (isinstance(fp, str) and re.match(r'^sha256:[0-9a-f]{64}$', fp))
        if not ok:
            print('BADFP %s fingerprint=%r' % (os.path.basename(f), fp)); bad += 1
    for el in (j.get('elements') or []):
        if el.get('role') in ACTIONS:
            print('SWAP %s element %s has action-class in role field' % (os.path.basename(f), el.get('id'))); swaps += 1
print('TOTALS %d %d' % (bad, swaps))
EOF
)
echo "$C9" | grep -v '^TOTALS' | head -12 | sed 's/^/    /'
BADFP=$(echo "$C9" | awk '/^TOTALS/{print $2}'); SWAPS=$(echo "$C9" | awk '/^TOTALS/{print $3}')
if [ "${BADFP:-0}" -gt 0 ]; then soft "$BADFP surface(s) with missing/placeholder/non-hash fingerprint"; else echo "  PASS"; fi
[ "${SWAPS:-0}" -gt 0 ] && echo "  WARN: $SWAPS element(s) with role/action swap (SCHEMA.md L6)"

# ---- check 10: journal lint (N15) -----------------------------------------
echo "[check 10] journal lint (N15)"
C10=$(python3 - "$DIR" "$RUN_ID" <<'EOF'
import json, glob, os, sys
d, rid = sys.argv[1], sys.argv[2]
VOCAB = {'seed','in-progress','captured','skipped','blocked','mutation','incident','friction','critic','resume'}
REQ = {'seed':['targets'],'in-progress':['target'],
       'captured':['target','surface','screenshots','states'],
       'skipped':['target','reason'],'blocked':['target','reason'],
       'mutation':['tenant','module','artifact','reversible'],
       'incident':['target','what'],'friction':['detail'],
       'critic':['structural_pct','state_pct'],
       'resume':['resumed_from','first_incomplete']}
bad = legacy = 0
for f in glob.glob(os.path.join(d,'capture-log*.jsonl')):
    for n, line in enumerate(open(f, encoding='utf-8', errors='replace'), 1):
        line = line.strip()
        if not line: continue
        try: j = json.loads(line)
        except Exception: print('NOJSON %s:%d' % (os.path.basename(f), n)); bad += 1; continue
        if 'run_id' not in j:
            legacy += 1; continue                      # pre-v1.2 lines: exempt
        if rid and j.get('run_id') != rid: continue
        ev = j.get('event')
        if ev not in VOCAB:
            print('BADEVENT %s:%d event=%r' % (os.path.basename(f), n, ev)); bad += 1; continue
        missing = [k for k in REQ[ev] if k not in j]
        if missing:
            print('MISSING %s:%d %s lacks %s' % (os.path.basename(f), n, ev, ','.join(missing))); bad += 1
print('TOTALS %d %d' % (bad, legacy))
EOF
)
echo "$C10" | grep -v '^TOTALS' | head -8 | sed 's/^/    /'
J_BAD=$(echo "$C10" | awk '/^TOTALS/{print $2}'); J_LEG=$(echo "$C10" | awk '/^TOTALS/{print $3}')
echo "  note: $J_LEG legacy line(s) without run_id (exempt; folded on resume)"
if [ "${J_BAD:-0}" -gt 0 ]; then soft "$J_BAD journal line violation(s) in run_id-stamped lines"; else echo "  PASS"; fi

echo "== result: $([ $FAIL -eq 0 ] && echo PASS || echo FAIL) =="
exit $FAIL
