#!/usr/bin/env python3
"""
/invoice deterministic money engine - the ONLY place invoice totals are computed
or IDR is formatted. SKILL.md §MONEY COMPUTE CONTRACT calls this; the rendered
PDF/MD/JSON use ONLY its outputs. Never hand-compute or hand-format money.

Usage:
    python3 compute.py < input.json > totals.json      # exit 0 = ok
    python3 compute.py --selfcheck                      # built-in test vectors

Input JSON:
{
  "line_items": [ {"description","detail"?,"qty","unit_price","amount"}, ... ],
  "discount":   0 | <int IDR> | {"pct": <number>},   # optional, default 0
  "apply_ppn":  false,          # gate: true ONLY if is_pkp (SKILL.md enforces)
  "ppn_rate":   0.11,           # effective rate from config
  "tax_name":   "PPN",
  "apply_pph23": false,         # client-withholding memo (NOT arithmetic)
  "pph23_rate": 0.02            # 0.02 with NPWP, 0.04 without
}

Output JSON (all ints are IDR; every *_fmt is the display string "Rp 15.000.000"):
{ subtotal, discount, tax_base, tax_name, ppn_rate, ppn_amount, grand_total,
  pph23_rate, pph23_amount, net_payable, apply_ppn, apply_pph23, <each>_fmt }

Exit codes: 0 ok · 2 line-item amount mismatch (bad input) · 3 self-check gate
failed (internal) · 4 malformed input. On non-zero, a human diff goes to stderr.
Tax order is fixed: tax_base = subtotal - discount; PPN on tax_base; PPh 23 memo
base = tax_base (DPP excluding PPN). Rounding is ROUND_HALF_UP to integer rupiah.
"""
import sys, json
from decimal import Decimal, ROUND_HALF_UP


def rp(n):
    """Integer IDR -> 'Rp 15.000.000' (dot thousands, no decimals)."""
    return "Rp " + "{:,.0f}".format(n).replace(",", ".")


def rhu(x):
    """Round half up to integer rupiah (commercial convention, not banker's)."""
    return int(Decimal(str(x)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def compute(inp):
    li = inp.get("line_items") or []
    if not li:
        raise ValueError("no line_items")

    # Provenance/shape + per-line arithmetic check: amount == round(qty*unit_price)
    for i, l in enumerate(li):
        for k in ("qty", "unit_price", "amount"):
            if k not in l:
                raise ValueError(f"line {i}: missing '{k}'")
        recomputed = rhu(Decimal(str(l["qty"])) * Decimal(str(l["unit_price"])))
        if recomputed != int(l["amount"]):
            raise AmountMismatch(i, l, recomputed)

    subtotal = sum(int(l["amount"]) for l in li)

    disc = inp.get("discount") or 0
    if isinstance(disc, dict):  # percentage form {"pct": 10}
        disc = rhu(Decimal(str(subtotal)) * Decimal(str(disc["pct"])) / Decimal(100))
    disc = int(disc)
    tax_base = subtotal - disc

    apply_ppn = bool(inp.get("apply_ppn"))
    ppn_rate = Decimal(str(inp.get("ppn_rate", 0.11)))
    ppn_amount = rhu(Decimal(str(tax_base)) * ppn_rate) if apply_ppn else 0
    grand_total = tax_base + ppn_amount

    apply_pph23 = bool(inp.get("apply_pph23"))
    pph_rate = Decimal(str(inp.get("pph23_rate", 0.02)))
    pph23_amount = rhu(Decimal(str(tax_base)) * pph_rate) if apply_pph23 else 0
    net_payable = grand_total - pph23_amount

    out = {
        "subtotal": subtotal, "discount": disc, "tax_base": tax_base,
        "tax_name": inp.get("tax_name", "PPN"),
        "ppn_rate": float(ppn_rate), "ppn_amount": ppn_amount,
        "grand_total": grand_total,
        "pph23_rate": float(pph_rate), "pph23_amount": pph23_amount,
        "net_payable": net_payable,
        "apply_ppn": apply_ppn, "apply_pph23": apply_pph23,
    }

    # ---- SELF-CHECK GATE (the invariants SKILL.md's PRE-ISSUE GATE relies on) ----
    assert out["subtotal"] == sum(int(l["amount"]) for l in li), "subtotal != sum(amounts)"
    assert out["tax_base"] == out["subtotal"] - out["discount"], "tax_base != subtotal - discount"
    assert out["grand_total"] == out["tax_base"] + out["ppn_amount"], "grand_total != tax_base + ppn"
    assert out["net_payable"] == out["grand_total"] - out["pph23_amount"], "net_payable != grand - pph23"
    if not apply_ppn:
        assert out["ppn_amount"] == 0 and out["grand_total"] == out["tax_base"], "PPN leaked while off"

    for k in ("subtotal", "discount", "tax_base", "ppn_amount",
              "grand_total", "pph23_amount", "net_payable"):
        out[k + "_fmt"] = rp(out[k])
    return out


class AmountMismatch(Exception):
    def __init__(self, i, line, recomputed):
        self.i, self.line, self.recomputed = i, line, recomputed


def _selfcheck():
    A = {"line_items": [
        {"description": "Shopee sync", "qty": 2.5, "unit_price": 400000, "amount": 1000000},
        {"description": "Code review", "qty": 1.5, "unit_price": 400000, "amount": 600000}],
        "apply_ppn": False, "apply_pph23": True, "pph23_rate": 0.02}
    B = {"line_items": [{"description": "Milestone 2", "qty": 1, "unit_price": 40000000, "amount": 40000000}],
         "apply_ppn": True, "ppn_rate": 0.11}
    C = {"line_items": [{"description": "tie", "qty": 1, "unit_price": 15000150, "amount": 15000150}],
         "apply_ppn": True, "ppn_rate": 0.11}
    D = {"line_items": [{"description": "x", "qty": 1, "unit_price": 10000000, "amount": 10000000}],
         "discount": {"pct": 10}, "apply_ppn": True, "ppn_rate": 0.11}
    rA, rB, rC, rD = compute(A), compute(B), compute(C), compute(D)
    assert (rA["subtotal"], rA["grand_total"], rA["pph23_amount"], rA["net_payable"]) == (1600000, 1600000, 32000, 1568000), rA
    assert (rB["ppn_amount"], rB["grand_total"]) == (4400000, 44400000), rB
    assert rC["ppn_amount"] == 1650017, rC["ppn_amount"]  # ROUND_HALF_UP, not banker's 1650016
    assert (rD["tax_base"], rD["ppn_amount"], rD["grand_total"]) == (9000000, 990000, 9990000), rD
    assert rA["subtotal_fmt"] == "Rp 1.600.000", rA["subtotal_fmt"]
    print("compute.py selfcheck: ALL PASSED")


def main():
    if "--selfcheck" in sys.argv:
        _selfcheck(); return 0
    try:
        inp = json.load(sys.stdin)
    except Exception as e:
        print(f"compute.py: malformed input JSON: {e}", file=sys.stderr); return 4
    try:
        out = compute(inp)
    except AmountMismatch as m:
        print(f"compute.py: LINE-ITEM ARITHMETIC MISMATCH on line {m.i} "
              f"({m.line.get('description','?')}): stated amount={m.line['amount']} "
              f"but qty({m.line['qty']}) x unit_price({m.line['unit_price']}) = "
              f"{m.recomputed}. Fix the line item; do NOT render.", file=sys.stderr)
        return 2
    except AssertionError as e:
        print(f"compute.py: SELF-CHECK GATE FAILED: {e}. Do NOT render.", file=sys.stderr)
        return 3
    except Exception as e:
        print(f"compute.py: {e}", file=sys.stderr); return 4
    json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
