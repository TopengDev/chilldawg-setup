# Handoff · <session-slug> · <YYYY-MM-DD>

> Revision: <N> · Written: <YYYY-MM-DD HH:MM WIB> · reconstructed-post-compact: <true|false>

## 1 · TL;DR
<max 3 lines: what this session was, where it ended, THE single next action.>

## 2 · Deliverables + evidence
| Artifact | Path | Proof |
|---|---|---|
| <what> | `<abs path>` | <sha / passing command / verified URL / gate result> |
<or the literal word: none>

## 3 · Live machine state
<PASTE the probe-state.sh fenced output here, verbatim.>
Per-repo summary (from probes, not memory):
- `<repo>`: branch `<b>`, <n> dirty files, HEAD `<sha> <subject>`
Running things a successor must know about:
- <process/daemon/monitor> · check: `<command>` <or: none>

## 4 · Open decisions + gates
| Item | State | OWNER |
|---|---|---|
| <decision/gate> | <state, verbatim if a standing gate> | <Toper / main / session-x / external> |
<or: none>

## 5 · Standing rules in force
- <session-scoped rule a successor must obey, one per line> <or: none>

## 6 · Resume protocol
Read first, in order:
1. `<abs path>` (<why>)
2. `<abs path>` (<why>)

Next actions:
```bash
# 1. <what this does>
<command>
# 2. <what this does>
<command>
```

## 7 · Hazards / do-NOT list
- do NOT <action>: <one-line reason> <or: none>

## 8 · Context pointers
- memory: [[<memory-name>]] <one-line why>
- notes: `<abs dir>` <one-line why>
- prior handoff: `<abs path>` <or: none>

## 9 · Provenance
- Session: <name> (<id if known>) · Model: <model> · Context at write: ~<n>% used [conv]
- Trigger: <manual /session-handoff | threshold | pre-compact nudge | emergency | reconstruction>
