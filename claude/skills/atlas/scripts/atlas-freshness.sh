#!/usr/bin/env bash
# atlas-freshness.sh <dossier-dir> [--list-stale] [--json]
#
# READ-ONLY freshness report for an /atlas dossier (SKILL.md 11.2 scoring):
#   fresh  : age < 50% of ttl_days
#   aging  : 50% to 100% of ttl_days
#   stale  : age > ttl_days
# Dossier verdict = worst bucket present. Exit code: 0 fresh, 1 aging, 2 stale
# (so callers can gate a consumer handoff on it).
# Writes NOTHING. Touches NO browser.
set -u
DIR="${1:-}"
[ -d "$DIR" ] || { echo "usage: atlas-freshness.sh <dossier-dir> [--list-stale] [--json]"; exit 3; }
MODE="${2:-}"

python3 - "$DIR" "$MODE" <<'EOF'
import json, glob, os, sys
from datetime import datetime, timezone
d, mode = sys.argv[1], sys.argv[2]
now = datetime.now(timezone.utc)
buckets = {'fresh': [], 'aging': [], 'stale': [], 'unknown': []}
for f in sorted(glob.glob(os.path.join(d, 'surfaces/*.json'))):
    sid = os.path.basename(f)[:-5]
    try:
        j = json.load(open(f))
        fr = j.get('freshness') or {}
        cap = fr.get('captured_at'); ttl = float(fr.get('ttl_days') or 14)
        ts = datetime.fromisoformat(cap)
        if ts.tzinfo is None: ts = ts.replace(tzinfo=timezone.utc)
        age = (now - ts).total_seconds() / 86400.0
    except Exception:
        buckets['unknown'].append((sid, None, None)); continue
    b = 'fresh' if age < 0.5 * ttl else ('aging' if age <= ttl else 'stale')
    buckets[b].append((sid, round(age, 1), ttl))
verdict = 'stale' if buckets['stale'] else ('aging' if buckets['aging'] else 'fresh')
if buckets['unknown'] and not (buckets['stale'] or buckets['aging']):
    verdict = 'aging'  # missing freshness data can never report a clean 'fresh'
if mode == '--json':
    print(json.dumps({'verdict': verdict,
                      'counts': {k: len(v) for k, v in buckets.items()},
                      'stale': [s for s, a, t in buckets['stale']],
                      'unknown': [s for s, a, t in buckets['unknown']]}))
else:
    print('dossier: %s' % d)
    print('verdict: %s  (fresh=%d aging=%d stale=%d unknown=%d)' % (
        verdict.upper(), len(buckets['fresh']), len(buckets['aging']),
        len(buckets['stale']), len(buckets['unknown'])))
    if mode == '--list-stale':
        for s, a, t in buckets['stale']:
            print('STALE   %-45s age=%sd ttl=%sd' % (s, a, t))
        for s, a, t in buckets['unknown']:
            print('UNKNOWN %-45s (missing/unparseable freshness)' % s)
    if verdict != 'fresh':
        print('handoff rule: attach a staleness disclaimer, or run a targeted refresh (SKILL.md 11.2).')
sys.exit({'fresh': 0, 'aging': 1, 'stale': 2}[verdict])
EOF
