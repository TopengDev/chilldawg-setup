#!/usr/bin/env python3
"""
memory-eval.py — eval harness for the local memory-retrieval engine.

Two modes:

  --build         (re)generate eval/golden.json from the live corpus:
                  sample ~N memories spread across namespaces, take ONE
                  hypothetical_question from each as a query whose
                  expected_file is that memory's filename, then append a set of
                  hand-written natural queries. Deterministic (seeded) so the
                  golden set is stable across runs unless --seed changes.

  (default)       run the engine over every golden query and report
                  recall@1, recall@3, recall@5 and MRR, plus a per-miss list
                  (query -> expected vs what actually surfaced). This is the
                  baseline miss-rate metric for the retrieval refactor.

Usage:
  memory-eval.py --build [--n 30] [--seed 7]
  memory-eval.py            [--golden eval/golden.json] [-k 5] [--json]

The harness imports the engine in-process (no subprocess), so eval latency is
just the corpus parse + the per-query BM25 scan.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Import the engine from the same directory.
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

# The engine file name has a hyphen, so it can't be `import`ed normally; load it
# explicitly by file path.
import importlib.util as _ilu

_SPEC = _ilu.spec_from_file_location("memory_retrieve", str(_HERE / "memory-retrieve.py"))
assert _SPEC and _SPEC.loader, "cannot locate memory-retrieve.py next to memory-eval.py"
memory_retrieve = _ilu.module_from_spec(_SPEC)
_SPEC.loader.exec_module(memory_retrieve)  # type: ignore

MEMORY_DIR = memory_retrieve.MEMORY_DIR
GOLDEN_DEFAULT = _HERE / "eval" / "golden.json"


# ---------------------------------------------------------------------------- #
# Hand-written natural queries (the brief asks for ~5). expected_file is the
# filename (basename) of the memory that SHOULD be the top hit.
# ---------------------------------------------------------------------------- #
HANDWRITTEN: List[Dict[str, str]] = [
    {
        "query": "how do I message my Aenoxa cofounder",
        "expected_file": "contact_suryadi.md",
        "note": "cofounder = Suryadi",
    },
    {
        "query": "what's the BMS fitest authoring standard",
        "expected_file": "reference_fitest_bms_authoring_standard.md",
        "note": "the enforced authoring standard reference",
    },
    {
        "query": "rule about committing with the commit skill",
        "expected_file": "feedback_commit_skill_enforced.md",
        "note": "never raw git commit",
    },
    {
        "query": "how should I talk to Ryan when delivering a bug report",
        "expected_file": "whatsapp_style_ryan.md",
        "note": "Ryan ISI QA register",
    },
    {
        "query": "main session should not do development work itself",
        "expected_file": "feedback_no_dev_in_main.md",
        "note": "main is discussion-only",
    },
    {
        "query": "do not set WHATSAPP=1 on worker sessions",
        "expected_file": "feedback_whatsapp_single_session_rule.md",
        "note": "WHATSAPP=1 main session only",
    },
]


# ---------------------------------------------------------------------------- #
# Golden-set builder
# ---------------------------------------------------------------------------- #
def build_golden(n: int = 30, seed: int = 7) -> dict:
    """
    Sample ~n corpus docs spread across namespaces; for each, take one
    hypothetical_question as the query. Returns the golden dict (also written to
    disk by the caller).
    """
    idx = memory_retrieve.MemoryIndex(MEMORY_DIR)

    # Re-read each doc's frontmatter to pull hypothetical_questions (the engine
    # folds them into the term bag but doesn't retain the raw list on the Doc).
    candidates_by_ns: Dict[str, List[Dict]] = {}
    for doc in idx.docs:
        try:
            text = doc.file.read_text(encoding="utf-8")
        except Exception:
            continue
        fm_str, _body = memory_retrieve._split_frontmatter(text)
        if fm_str is None:
            continue
        try:
            import yaml
            meta = yaml.safe_load(fm_str) or {}
        except Exception:
            meta = memory_retrieve._minimal_frontmatter_parse(fm_str)
        hqs = memory_retrieve._as_text_list(meta.get("hypothetical_questions"))
        hqs = [q.strip() for q in hqs if q and len(q.strip()) > 8]
        if not hqs:
            continue
        candidates_by_ns.setdefault(doc.namespace, []).append({
            "file": doc.file.name,
            "namespace": doc.namespace,
            "title": doc.title,
            "hqs": hqs,
        })

    rng = random.Random(seed)
    namespaces = sorted(candidates_by_ns.keys())
    # Spread the sample across namespaces proportionally, but guarantee coverage.
    selected: List[Dict] = []
    # round-robin across namespaces until we hit n
    pools = {ns: list(candidates_by_ns[ns]) for ns in namespaces}
    for ns in pools:
        rng.shuffle(pools[ns])
    # Weighted but coverage-guaranteed: iterate namespaces round-robin.
    exhausted = set()
    while len(selected) < n and len(exhausted) < len(namespaces):
        for ns in namespaces:
            if len(selected) >= n:
                break
            pool = pools[ns]
            if not pool:
                exhausted.add(ns)
                continue
            cand = pool.pop()
            q = rng.choice(cand["hqs"])
            selected.append({
                "query": q,
                "expected_file": cand["file"],
                "namespace": cand["namespace"],
                "source": "hypothetical_question",
                "title": cand["title"],
            })

    # Append hand-written natural queries.
    for hw in HANDWRITTEN:
        selected.append({
            "query": hw["query"],
            "expected_file": hw["expected_file"],
            "namespace": "(handwritten)",
            "source": "handwritten",
            "note": hw.get("note", ""),
        })

    golden = {
        "_meta": {
            "generated_by": "memory-eval.py --build",
            "seed": seed,
            "n_sampled": len([s for s in selected if s["source"] == "hypothetical_question"]),
            "n_handwritten": len(HANDWRITTEN),
            "corpus_size": idx.N,
            "namespaces_covered": sorted(
                {s["namespace"] for s in selected if s["source"] == "hypothetical_question"}
            ),
        },
        "queries": selected,
    }
    return golden


# ---------------------------------------------------------------------------- #
# Eval runner
# ---------------------------------------------------------------------------- #
def run_eval(golden_path: Path, k: int = 5) -> dict:
    with golden_path.open(encoding="utf-8") as f:
        golden = json.load(f)
    queries = golden.get("queries", [])
    if not queries:
        raise SystemExit("golden set has no queries; run --build first")

    idx = memory_retrieve.MemoryIndex(MEMORY_DIR)

    total = len(queries)
    hit1 = hit3 = hit5 = 0
    mrr_sum = 0.0
    misses: List[dict] = []

    for q in queries:
        query = q["query"]
        expected = q["expected_file"]
        expected_stem = expected[:-3] if expected.endswith(".md") else expected
        results = idx.search(query, k=max(k, 5))
        ranked_stems = [r["stem"] for r in results]

        rank = None
        for i, st in enumerate(ranked_stems):
            if st == expected_stem:
                rank = i + 1
                break

        if rank is not None:
            mrr_sum += 1.0 / rank
            if rank <= 1:
                hit1 += 1
            if rank <= 3:
                hit3 += 1
            if rank <= 5:
                hit5 += 1

        if rank is None or rank > 1:
            misses.append({
                "query": query,
                "expected": expected,
                "expected_rank": rank,        # None => not in top-k
                "source": q.get("source", ""),
                "surfaced": [
                    f"{r['stem']}.md (#{r['rank']}, {r['score']})"
                    for r in results[:3]
                ],
            })

    metrics = {
        "total_queries": total,
        "recall@1": round(hit1 / total, 4),
        "recall@3": round(hit3 / total, 4),
        "recall@5": round(hit5 / total, 4),
        "mrr": round(mrr_sum / total, 4),
        "hit1": hit1, "hit3": hit3, "hit5": hit5,
        "corpus_size": idx.N,
    }
    return {"metrics": metrics, "misses": misses}


def _print_report(report: dict):
    m = report["metrics"]
    misses = report["misses"]
    print("=" * 64)
    print("  MEMORY RETRIEVAL — EVAL REPORT (BM25 v1 baseline)")
    print("=" * 64)
    print(f"  corpus docs        : {m['corpus_size']}")
    print(f"  golden queries     : {m['total_queries']}")
    print("-" * 64)
    print(f"  recall@1           : {m['recall@1']:.3f}   ({m['hit1']}/{m['total_queries']})")
    print(f"  recall@3           : {m['recall@3']:.3f}   ({m['hit3']}/{m['total_queries']})")
    print(f"  recall@5           : {m['recall@5']:.3f}   ({m['hit5']}/{m['total_queries']})")
    print(f"  MRR                : {m['mrr']:.3f}")
    print("=" * 64)
    if misses:
        print(f"\n  PER-MISS LIST ({len(misses)} queries where expected != rank-1):\n")
        for mi in misses:
            rk = mi["expected_rank"]
            rk_s = f"rank {rk}" if rk else "NOT in top-5"
            print(f"  • [{mi['source']}] \"{mi['query']}\"")
            print(f"      expected: {mi['expected']}  ({rk_s})")
            print(f"      surfaced: {', '.join(mi['surfaced'])}")
    else:
        print("\n  No misses — every expected doc surfaced at rank 1. 🎯")
    print()


# ---------------------------------------------------------------------------- #
# CLI
# ---------------------------------------------------------------------------- #
def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="memory-eval.py")
    ap.add_argument("--build", action="store_true",
                    help="(re)generate eval/golden.json from the live corpus")
    ap.add_argument("--n", type=int, default=30,
                    help="number of hypothetical-question samples (default 30)")
    ap.add_argument("--seed", type=int, default=7, help="sampling seed (default 7)")
    ap.add_argument("--golden", default=str(GOLDEN_DEFAULT),
                    help="path to golden.json")
    ap.add_argument("-k", type=int, default=5, help="recall cutoff (default 5)")
    ap.add_argument("--json", action="store_true",
                    help="emit the metrics+misses report as JSON")
    args = ap.parse_args(argv)

    golden_path = Path(args.golden)

    if args.build:
        golden = build_golden(n=args.n, seed=args.seed)
        golden_path.parent.mkdir(parents=True, exist_ok=True)
        with golden_path.open("w", encoding="utf-8") as f:
            json.dump(golden, f, ensure_ascii=False, indent=2)
        meta = golden["_meta"]
        print(f"Wrote {golden_path}")
        print(f"  {meta['n_sampled']} sampled (hypothetical_question) across "
              f"{len(meta['namespaces_covered'])} namespaces: "
              f"{', '.join(meta['namespaces_covered'])}")
        print(f"  + {meta['n_handwritten']} hand-written queries")
        print(f"  total golden queries: {len(golden['queries'])}")
        return 0

    if not golden_path.exists():
        print(f"golden set not found at {golden_path}; building it now...",
              file=sys.stderr)
        golden = build_golden(n=args.n, seed=args.seed)
        golden_path.parent.mkdir(parents=True, exist_ok=True)
        with golden_path.open("w", encoding="utf-8") as f:
            json.dump(golden, f, ensure_ascii=False, indent=2)

    report = run_eval(golden_path, k=args.k)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        _print_report(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
