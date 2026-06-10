#!/usr/bin/env python3
"""lib-email-alert.py — session-independent email alert sender.

Sends a plaintext email WITHOUT needing a Claude session, an MCP server, or the
wa-sender WhatsApp path. This is the alert channel for the daemon deadman
(deadman.sh): when wa-sender itself is dead, alerting *through* it is useless, so
we go out-of-band via SMTP.

Credentials come from the existing email-mcp config at
~/.config/email-mcp/config.json (the same file the email MCP server reads).
NO secrets are hardcoded; nothing is printed except status. Accounts are tried in
a fixed order (business Hostinger 465-TLS first, then personal Outlook
587-STARTTLS) so a single provider outage doesn't kill the alert.

Usage:
    lib-email-alert.py --subject "..." --body "..." [--to addr] [--account name]

    # body can also come from stdin:
    echo "the body" | lib-email-alert.py --subject "..." --body -

Exit codes:
    0  sent (prints: SENT via account=<name> (<from> -> <host>:<port>))
    1  all configured accounts failed (prints FAILED lines to stderr)
    2  config/usage error (no config file, no accounts, bad args)

Importable: `from lib_email_alert import send_alert` -> send_alert(subject, body,
to=None, account=None) returns the account name on success or raises RuntimeError.
"""
from __future__ import annotations

import argparse
import json
import smtplib
import ssl
import sys
from email.message import EmailMessage
from email.utils import formatdate, make_msgid
from pathlib import Path
from typing import Iterable

CONFIG_PATH = Path.home() / ".config" / "email-mcp" / "config.json"

# Default recipient: Toper's personal inbox (he reads this even when AFK from the
# terminal / phone WA). Override with --to.
DEFAULT_TO = "topengdev@gmail.com"

# Try business (Hostinger, 465 implicit-TLS) before personal (Outlook, 587
# STARTTLS): Hostinger has been the more reliable transactional path.
PREFERRED_ORDER = ("business", "personal")


def _load_accounts() -> dict:
    if not CONFIG_PATH.exists():
        raise RuntimeError(f"email config not found at {CONFIG_PATH}")
    try:
        cfg = json.loads(CONFIG_PATH.read_text())
    except Exception as e:  # noqa: BLE001
        raise RuntimeError(f"email config is not valid JSON: {e}") from e
    accts = cfg.get("accounts") or {}
    if not accts:
        raise RuntimeError("no accounts configured in email config.json")
    return accts


def _account_order(accts: dict, preferred: str | None) -> Iterable[str]:
    seen = set()
    if preferred:
        if preferred not in accts:
            raise RuntimeError(f"requested account '{preferred}' not in config")
        seen.add(preferred)
        yield preferred
    for name in PREFERRED_ORDER:
        if name in accts and name not in seen:
            seen.add(name)
            yield name
    # any remaining accounts as a last resort
    for name in accts:
        if name not in seen:
            seen.add(name)
            yield name


def _send_via(acct: dict, to_addr: str, subject: str, body: str) -> None:
    smtp = acct["smtp"]
    msg = EmailMessage()
    msg["From"] = acct["email"]
    msg["To"] = to_addr
    msg["Subject"] = subject
    msg["Date"] = formatdate(localtime=True)
    msg["Message-ID"] = make_msgid()
    msg.set_content(body)

    host = smtp["host"]
    port = int(smtp["port"])
    use_implicit_tls = bool(smtp.get("tls")) and not bool(smtp.get("starttls"))

    if use_implicit_tls:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(host, port, timeout=30, context=ctx) as s:
            s.login(acct["email"], acct["password"])
            s.send_message(msg)
    else:
        with smtplib.SMTP(host, port, timeout=30) as s:
            s.ehlo()
            if smtp.get("starttls"):
                s.starttls(context=ssl.create_default_context())
                s.ehlo()
            s.login(acct["email"], acct["password"])
            s.send_message(msg)


def send_alert(
    subject: str,
    body: str,
    to: str | None = None,
    account: str | None = None,
) -> str:
    """Send an alert email. Returns the account name used. Raises RuntimeError
    if every candidate account fails."""
    to_addr = to or DEFAULT_TO
    accts = _load_accounts()
    errors: list[str] = []
    for name in _account_order(accts, account):
        try:
            _send_via(accts[name], to_addr, subject, body)
            return name
        except Exception as e:  # noqa: BLE001  (any SMTP/socket/auth failure → try next)
            errors.append(f"{name}: {type(e).__name__}: {e}")
            continue
    raise RuntimeError("all accounts failed -> " + " | ".join(errors))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Send a session-independent alert email.")
    ap.add_argument("--subject", required=True)
    ap.add_argument(
        "--body",
        required=True,
        help="alert body, or '-' to read the body from stdin",
    )
    ap.add_argument("--to", default=None, help=f"recipient (default {DEFAULT_TO})")
    ap.add_argument(
        "--account",
        default=None,
        help="force a specific email-mcp account (e.g. business|personal)",
    )
    args = ap.parse_args(argv)

    body = sys.stdin.read() if args.body == "-" else args.body

    try:
        name = send_alert(args.subject, body, to=args.to, account=args.account)
    except RuntimeError as e:
        msg = str(e)
        # config/usage errors (no file/accounts/bad account) → exit 2; send
        # failures → exit 1. Distinguish by the message prefix.
        if msg.startswith("all accounts failed"):
            print(f"FAILED: {msg}", file=sys.stderr)
            return 1
        print(f"ERROR: {msg}", file=sys.stderr)
        return 2

    # Resolve the from/host for a useful confirmation line.
    accts = _load_accounts()
    a = accts[name]
    print(
        f"SENT via account={name} ({a['email']} -> {a['smtp']['host']}:{a['smtp']['port']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
