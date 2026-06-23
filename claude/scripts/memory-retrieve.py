#!/usr/bin/env python3
"""
memory-retrieve.py — self-contained LOCAL retrieval engine over Christopher's
memory store (~/.claude/memory), Phase E of the memory-retrieval refactor.

Design goals
------------
* ZERO external pip dependencies for the ranking core: Okapi BM25 is implemented
  inline (k1=1.5, b=0.75). PyYAML is the ONLY import outside the stdlib, and it
  is used purely for frontmatter parsing (it ships in this environment). If
  PyYAML is somehow unavailable we fall back to a tiny hand-rolled frontmatter
  parser so the engine still runs.
* Schema-v2 aware: per-doc weighted term bag built from the rich retrieval
  frontmatter (title/aliases/trigger_keywords/hypothetical_questions/tags/
  entities = HIGH, description = MEDIUM, body = LOW), plus a Porter-ish stem of
  every term so "messaging" matches "message".
* Fast: the whole corpus (193 docs) is parsed + indexed on each invocation in
  well under a second; there is no persisted index to go stale. (A persisted
  index is documented as a v2 optimisation in README-memory-retrieval.md.)

CLI
---
    memory-retrieve.py "<query>" [-k N] [--json] [--namespace NS] [--expand]

Default output is human-readable; --json emits a JSON array (consumed by the
UserPromptSubmit hook). See README-memory-retrieval.md for the full picture.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

# ---------------------------------------------------------------------------- #
# Frontmatter parsing — prefer PyYAML, fall back to a minimal parser.
# ---------------------------------------------------------------------------- #
try:
    import yaml  # type: ignore

    _HAVE_YAML = True
except Exception:  # pragma: no cover - PyYAML is present in this env
    _HAVE_YAML = False


MEMORY_DIR = Path(os.environ.get("CLAUDE_MEMORY_DIR", str(Path.home() / ".claude" / "memory")))

# Directories / files that are NOT corpus documents.
_EXCLUDE_DIRS = {"archive", "indexes"}
_EXCLUDE_BASENAMES = {"MEMORY.md", "MEMORY.md.prev", "MEMORY.md.tmp", "journal.md"}

# Term-bag field weights (repeat-count = weight).
_W_HIGH = 3   # title, aliases, trigger_keywords, hypothetical_questions, tags, entities
_W_MED = 2    # description
_W_LOW = 1    # body

# BM25 params (locked per the brief).
_BM25_K1 = 1.5
_BM25_B = 0.75

_TOKEN_RE = re.compile(r"[a-z0-9]+")
_WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
_FM_FENCE_RE = re.compile(r"\n---[ \t]*\n")


# ---------------------------------------------------------------------------- #
# Tokenisation + light stemming
# ---------------------------------------------------------------------------- #
def tokenize(text: str) -> List[str]:
    """lowercase, split on non-alphanumeric, keep tokens of length >= 2."""
    if not text:
        return []
    return [t for t in _TOKEN_RE.findall(text.lower()) if len(t) >= 2]


def _stem(tok: str) -> str:
    """
    Tiny, conservative suffix stemmer. NOT full Porter — just enough to fold the
    common English inflections that hurt recall ("messaging"->"messag",
    "committing"->"commit", "rules"->"rule"). Deterministic + cheap. We keep BOTH
    the raw token and its stem in the term bag (per the brief: "include the
    stem"), so an exact-form match still scores, and an inflected query form
    still hits via the stem.
    """
    w = tok
    if len(w) <= 3:
        return w
    # plural / 3rd-person -ies -> -y
    if w.endswith("ies") and len(w) > 4:
        return w[:-3] + "y"
    if w.endswith("sses"):
        return w[:-2]            # classes -> class
    if w.endswith("es") and len(w) > 4 and w[-3] in "sxzo":
        return w[:-2]            # boxes -> box, goes -> go
    if w.endswith("s") and not w.endswith("ss") and len(w) > 3:
        w = w[:-1]               # rules -> rule, keys -> key
    # gerund / past
    if w.endswith("ing") and len(w) > 5:
        w = w[:-3]               # messaging -> messag, committing -> committ
    elif w.endswith("ed") and len(w) > 4:
        w = w[:-2]               # committed -> committ
    # collapse a doubled final consonant left by -ing/-ed (committ -> commit)
    if len(w) > 3 and w[-1] == w[-2] and w[-1] not in "aeiou":
        w = w[:-1]
    return w


def expand_tokens(tokens: Iterable[str]) -> List[str]:
    """Return the tokens plus their stems (deduped per occurrence preserved)."""
    out: List[str] = []
    for t in tokens:
        out.append(t)
        s = _stem(t)
        if s and s != t:
            out.append(s)
    return out


# ---------------------------------------------------------------------------- #
# Document model
# ---------------------------------------------------------------------------- #
class Doc:
    __slots__ = (
        "file", "stem", "title", "namespace", "description", "snippet",
        "tf", "length", "links", "is_contact", "person_keys",
    )

    def __init__(self, file: Path, stem: str, title: str, namespace: str,
                 description: str, snippet: str, tf: Counter, length: int,
                 links: List[str], is_contact: bool, person_keys: set):
        self.file = file
        self.stem = stem
        self.title = title
        self.namespace = namespace
        self.description = description
        self.snippet = snippet
        self.tf = tf
        self.length = length
        self.links = links
        self.is_contact = is_contact
        self.person_keys = person_keys


def _split_frontmatter(text: str) -> Tuple[Optional[str], str]:
    """Return (frontmatter_str_or_None, body)."""
    if not text.startswith("---"):
        return None, text
    m = _FM_FENCE_RE.search(text, 3)
    # search from index 3 to skip the opening fence; if the opening line is
    # exactly '---\n' the closing fence is the next '\n---\n'.
    if not m:
        return None, text
    fm = text[3:m.start()]
    body = text[m.end():]
    return fm, body


def _minimal_frontmatter_parse(fm: str) -> dict:
    """
    Fallback frontmatter parser (only used if PyYAML is missing). Handles the
    flat scalar + simple list-of-strings shape this corpus uses. Not a general
    YAML parser — deliberately small + safe.
    """
    data: dict = {}
    cur_key: Optional[str] = None
    cur_list: Optional[list] = None
    for raw in fm.splitlines():
        if not raw.strip():
            continue
        if raw.startswith(("  - ", "- ", "\t- ")):
            val = raw.split("- ", 1)[1].strip().strip("'\"")
            if cur_list is not None:
                cur_list.append(val)
            continue
        mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", raw)
        if not mm:
            continue
        key, val = mm.group(1), mm.group(2).strip()
        if val == "":
            cur_key = key
            cur_list = []
            data[key] = cur_list
        else:
            data[key] = val.strip("'\"")
            cur_key, cur_list = None, None
    # drop empty lists that were actually scalars-with-no-children
    return data


def _as_text_list(v) -> List[str]:
    """Coerce a frontmatter value into a flat list of strings."""
    if v is None:
        return []
    if isinstance(v, str):
        return [v]
    if isinstance(v, (list, tuple)):
        out = []
        for item in v:
            if item is None:
                continue
            out.append(str(item))
        return out
    return [str(v)]


# Tokens we never treat as a "person key" even inside a contact doc. These are
# role/affiliation/product words that legitimately appear in a contact's
# title/aliases/entities but are NOT the person's name — boosting on them would
# wrongly surface a contact for an unrelated topical query (e.g. "pulse dark
# theme" must NOT boost a contact who happens to be a Pulse POS user).
_NON_PERSON_TOKENS = {
    # frontmatter / file-naming scaffolding
    "whatsapp", "style", "contact", "reference", "the", "and", "for", "with",
    # relationship / role words
    "close", "friend", "coworker", "partner", "cofounder", "founder", "co",
    "ceo", "cto", "family", "gamer", "helper", "shop", "lead", "dev", "qa",
    "buddy", "boss", "sister", "brother", "mom", "dad", "mami", "papih",
    # orgs / products / projects that recur in contact entities
    "aenoxa", "isi", "bms", "fitest", "pulse", "pos", "bri", "bcas", "dota",
    "valorant", "discord", "selenium", "playwright", "claude", "christopher",
    "toper", "solusi", "putra",
}


def _build_doc(path: Path, root: Path) -> Optional[Doc]:
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return None

    fm_str, body = _split_frontmatter(text)
    meta: dict = {}
    if fm_str is not None:
        if _HAVE_YAML:
            try:
                loaded = yaml.safe_load(fm_str)
                if isinstance(loaded, dict):
                    meta = loaded
            except Exception:
                meta = _minimal_frontmatter_parse(fm_str)
        else:
            meta = _minimal_frontmatter_parse(fm_str)

    stem = path.stem
    title = str(meta.get("title") or meta.get("name") or stem)
    namespace = str(meta.get("namespace") or meta.get("type") or "")
    description = str(meta.get("description") or "")

    aliases = _as_text_list(meta.get("aliases"))
    trigger_keywords = _as_text_list(meta.get("trigger_keywords"))
    hypotheticals = _as_text_list(meta.get("hypothetical_questions"))
    tags = _as_text_list(meta.get("tags"))
    entities = _as_text_list(meta.get("entities"))

    # ---- weighted term bag -------------------------------------------------- #
    tf: Counter = Counter()

    def add(text_blob: str, weight: int):
        toks = expand_tokens(tokenize(text_blob))
        if weight == 1:
            tf.update(toks)
        else:
            for t in toks:
                tf[t] += weight

    # HIGH: title + aliases + trigger_keywords + hypothetical_questions + tags + entities
    high_blob = " ".join(
        [title] + aliases + trigger_keywords + hypotheticals + tags + entities
    )
    add(high_blob, _W_HIGH)
    # MEDIUM: description
    add(description, _W_MED)
    # LOW: body
    add(body, _W_LOW)

    length = sum(tf.values())

    # ---- snippet: description, else first non-heading body line ------------- #
    snippet = description.strip()
    if not snippet:
        for line in body.splitlines():
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("---") or s.startswith(">"):
                continue
            snippet = s
            break
    snippet = re.sub(r"\s+", " ", snippet).strip()
    if len(snippet) > 200:
        snippet = snippet[:197].rstrip() + "..."

    # ---- wikilink neighbours ------------------------------------------------ #
    links = []
    for m in _WIKILINK_RE.finditer(body):
        target = m.group(1).strip()
        # a wikilink may carry an alias/anchor: [[stem|label]] or [[stem#sec]]
        target = re.split(r"[|#]", target, maxsplit=1)[0].strip()
        if target:
            links.append(target)
    # dedupe preserving order
    seen = set()
    links = [x for x in links if not (x in seen or seen.add(x))]

    # ---- contact-key detection ---------------------------------------------- #
    is_contact = namespace.lower() == "contact"
    person_keys: set = set()
    if is_contact:
        # Person-name tokens for the contact-key boost. Source = title + aliases
        # ONLY (the human's actual name + nicknames). We deliberately EXCLUDE
        # `entities`, because a contact's entities routinely list *associated*
        # things/people (Pulse POS, mami, Christopher, Aenoxa) that are not the
        # contact's own name — keying the boost on those caused unrelated
        # topical queries to wrongly surface a person. Generic role/product
        # words are additionally filtered, and we require length >= 3 so short
        # noise tokens (e.g. "di") don't over-trigger.
        name_blob = " ".join([title] + aliases)
        for tok in tokenize(name_blob):
            if len(tok) < 3 or tok in _NON_PERSON_TOKENS:
                continue
            person_keys.add(tok)
            st = _stem(tok)
            if st and st not in _NON_PERSON_TOKENS:
                person_keys.add(st)

    return Doc(
        file=path, stem=stem, title=title, namespace=namespace,
        description=description, snippet=snippet, tf=tf, length=length,
        links=links, is_contact=is_contact, person_keys=person_keys,
    )


# ---------------------------------------------------------------------------- #
# Corpus + BM25 index
# ---------------------------------------------------------------------------- #
class MemoryIndex:
    def __init__(self, root: Path = MEMORY_DIR):
        self.root = root
        self.docs: List[Doc] = []
        self.by_stem: Dict[str, Doc] = {}
        self.df: Counter = Counter()         # document frequency per term
        self.idf: Dict[str, float] = {}
        self.avgdl: float = 0.0
        self.N: int = 0
        self._load()

    # -- corpus discovery ---------------------------------------------------- #
    def _iter_corpus_files(self) -> Iterable[Path]:
        for p in sorted(self.root.rglob("*.md")):
            try:
                rel = p.relative_to(self.root)
            except ValueError:
                continue
            parts = rel.parts
            if parts and parts[0] in _EXCLUDE_DIRS:
                continue
            if p.name in _EXCLUDE_BASENAMES:
                continue
            if p.name.endswith(".prev"):
                continue
            yield p

    def _load(self):
        for path in self._iter_corpus_files():
            doc = _build_doc(path, self.root)
            if doc is None:
                continue
            self.docs.append(doc)
            self.by_stem[doc.stem] = doc

        self.N = len(self.docs)
        if self.N == 0:
            return

        total_len = 0
        for doc in self.docs:
            total_len += doc.length
            for term in doc.tf.keys():
                self.df[term] += 1
        self.avgdl = total_len / self.N if self.N else 0.0

        # BM25 idf (the "+0.5 / +0.5 ... +1" smoothed form; clamp at 0 so a term
        # present in >half the corpus can't drag a score negative).
        for term, df in self.df.items():
            idf = math.log((self.N - df + 0.5) / (df + 0.5) + 1.0)
            self.idf[term] = idf

    # -- scoring ------------------------------------------------------------- #
    def _bm25_score(self, q_terms: Counter, doc: Doc) -> float:
        if doc.length == 0:
            return 0.0
        score = 0.0
        k1, b = _BM25_K1, _BM25_B
        norm = k1 * (1 - b + b * (doc.length / self.avgdl)) if self.avgdl else k1
        for term, qf in q_terms.items():
            f = doc.tf.get(term)
            if not f:
                continue
            idf = self.idf.get(term, 0.0)
            if idf <= 0:
                continue
            score += idf * (f * (k1 + 1)) / (f + norm) * (1.0 + 0.0 * qf)
        return score

    # -- public search ------------------------------------------------------- #
    def search(self, query: str, k: int = 5,
               namespaces: Optional[Iterable[str]] = None,
               expand: bool = False) -> List[dict]:
        if self.N == 0:
            return []
        raw_q = tokenize(query)
        if not raw_q:
            return []
        q_terms = Counter(expand_tokens(raw_q))

        ns_filter = None
        if namespaces:
            ns_filter = {n.lower() for n in namespaces}

        # CONTACT-KEY boost: if a query token names a person who owns a contact
        # doc, that contact doc gets a strong additive boost so "message Ryan"
        # surfaces the Ryan contact even though "message" out-weights "ryan" in a
        # pure BM25 bag. We boost by a multiple of the best BM25 score so it's
        # scale-aware (works regardless of corpus IDF magnitudes).
        raw_q_set = set(raw_q) | {_stem(t) for t in raw_q}

        scored: List[Tuple[float, Doc]] = []
        max_bm25 = 0.0
        for doc in self.docs:
            if ns_filter is not None and doc.namespace.lower() not in ns_filter:
                continue
            s = self._bm25_score(q_terms, doc)
            if s > max_bm25:
                max_bm25 = s
            scored.append((s, doc))

        # apply contact boost (scaled to the result set's magnitude)
        if max_bm25 > 0:
            boost_unit = max_bm25
        else:
            boost_unit = 1.0
        for i, (s, doc) in enumerate(scored):
            if doc.is_contact and doc.person_keys:
                hit = raw_q_set & doc.person_keys
                if hit:
                    # strong, but proportional to how many name tokens matched
                    scored[i] = (s + boost_unit * (1.5 + 0.5 * (len(hit) - 1)), doc)

        scored = [(s, d) for (s, d) in scored if s > 0]
        # primary sort: score desc, tiebreak stem asc (deterministic)
        scored.sort(key=lambda x: (-x[0], x[1].stem))

        top = scored[:k]
        results = [self._fmt(s, d, rank=i + 1, expanded=False)
                   for i, (s, d) in enumerate(top)]

        # -- 1-HOP expansion -------------------------------------------------- #
        if expand and top:
            present = {d.stem for _, d in top}
            neighbours: List[Tuple[float, Doc]] = []
            seen_n = set(present)
            for _, d in top:
                for link in d.links:
                    if link in seen_n:
                        continue
                    nd = self.by_stem.get(link)
                    if nd is None:
                        continue
                    if ns_filter is not None and nd.namespace.lower() not in ns_filter:
                        continue
                    seen_n.add(link)
                    # give the neighbour its own (possibly zero) query score so a
                    # topically-relevant neighbour ranks above an unrelated one.
                    ns = self._bm25_score(q_terms, nd)
                    neighbours.append((ns, nd))
            neighbours.sort(key=lambda x: (-x[0], x[1].stem))
            for i, (s, d) in enumerate(neighbours):
                results.append(self._fmt(s, d, rank=len(top) + i + 1, expanded=True))

        return results

    @staticmethod
    def _fmt(score: float, doc: Doc, rank: int, expanded: bool) -> dict:
        return {
            "rank": rank,
            "file": str(doc.file),
            "stem": doc.stem,
            "title": doc.title,
            "namespace": doc.namespace,
            "score": round(float(score), 4),
            "snippet": doc.snippet,
            "expanded": expanded,
        }


# ---------------------------------------------------------------------------- #
# CLI
# ---------------------------------------------------------------------------- #
def _human(results: List[dict]) -> str:
    if not results:
        return "(no matching memories)"
    lines = []
    for r in results:
        tag = " [1-hop]" if r.get("expanded") else ""
        lines.append(
            f"{r['rank']:>2}. {r['title']}  [{r['namespace']}]  "
            f"({r['stem']}.md)  score={r['score']}{tag}\n"
            f"    {r['snippet']}"
        )
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="memory-retrieve.py",
        description="Local BM25 retrieval over the ~/.claude/memory store.",
    )
    ap.add_argument("query", help="free-text query")
    ap.add_argument("-k", type=int, default=5, help="number of results (default 5)")
    ap.add_argument("--json", action="store_true", help="emit a JSON array")
    ap.add_argument("--namespace", action="append", default=None,
                    help="restrict to a namespace (repeatable)")
    ap.add_argument("--expand", action="store_true",
                    help="append 1-hop [[wikilink]] neighbours of the top hits")
    ap.add_argument("--root", default=None, help="override memory dir (testing)")
    args = ap.parse_args(argv)

    root = Path(args.root) if args.root else MEMORY_DIR
    try:
        idx = MemoryIndex(root)
    except Exception as e:  # fail soft on the CLI too
        if args.json:
            print("[]")
        else:
            print(f"(retrieval error: {e})", file=sys.stderr)
        return 0

    results = idx.search(args.query, k=args.k,
                         namespaces=args.namespace, expand=args.expand)

    if args.json:
        print(json.dumps(results, ensure_ascii=False))
    else:
        print(_human(results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
