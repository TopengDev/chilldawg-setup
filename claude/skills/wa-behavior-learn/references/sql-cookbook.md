# SQL Cookbook (READ-ONLY)

Every query here is READ-ONLY. Never open either database read-write. Schemas
below were verified on 2026-07-03 against live snapshots; re-check with
`pragma_table_info` if anything looks off (see Schema drift in the playbook).

Store facts (2026-07-03):
- **app.db** `~/.local/share/whatsapp-tui/app.db` (whatsapp-tui / Rust `wa` client)
  `schema_version = 3`, 38,345 messages, WAL mode, PHONE-JID keyed for 1:1.
  Fresh only while the `wa` TUI runs.
- **messages.db** `~/.config/whatsapp-mcp/messages.db` (Baileys / MCP bridge)
  24,914 messages, WAL mode, live while the main session runs, but recent 1:1
  activity is heavily `@lid`-keyed (LID-fragmented).

---

## 0. Snapshot copy (the safe access pattern, do this first)

Copy `db + -wal + -shm` together so the snapshot is transaction-consistent
(recent commits live in the `-wal`), then query the copies. This never touches
the live stores and never contends with the live writer.

```bash
WORK="$(mktemp -d)"
APP="$HOME/.local/share/whatsapp-tui/app.db"
MSG="$HOME/.config/whatsapp-mcp/messages.db"
for db in "$APP" "$MSG"; do
  for ext in "" "-wal" "-shm"; do
    [ -f "${db}${ext}" ] && cp "${db}${ext}" "$WORK/$(basename "$db")${ext}" 2>/dev/null
  done
done
APPS="$WORK/app.db"; MSGS="$WORK/messages.db"
# ... run all queries against $APPS / $MSGS ...
# rm -rf "$WORK"   # at end of run
```

Lightweight alternative (single quick read, no snapshot): open read-only with a
busy-timeout, never read-write:
```bash
sqlite3 "file:$APP?mode=ro" ".timeout 5000" "SELECT COALESCE(MAX(timestamp),0) FROM messages;"
```

---

## 1. Schemas (verified)

### app.db (PRIMARY)
```
messages( id, chat_jid, sender_jid, from_me, timestamp,  -- timestamp = unix seconds
          type, text, media_type, media_path, media_key, direct_path, media_url,
          mimetype, file_name, file_size, width, height, thumbnail,
          quoted_id, status, push_name, react_emoji )
chats( jid, name, last_msg_ts, unread, pinned, archived, muted_until, is_group, lid_jid )
contacts( jid, lid, name, notify, phone )
group_participants( ... )
schema_version( ... )   -- single row, value 3
```
Notes: text lives in `type IN ('conversation','extendedTextMessage')`. `from_me`
is 0/1. `quoted_id` (NOT quoted_message_id). `react_emoji` + `push_name` are
app.db-only niceties. In `contacts`, `jid == phone` (phone-JID) and `lid` is the
`@lid`. In `chats`, `jid` is usually the phone-JID but can itself be an `@lid`;
`lid_jid` holds the `@lid` twin.

### messages.db (FALLBACK)
```
messages( id, chat_jid, sender_jid, sender_name, content, message_type,
          timestamp,  -- unix seconds
          is_from_me, quoted_message_id, media_type, media_url, raw_json )
contacts( jid, name, notify_name, phone )
```
Notes: text is `content`, flag is `is_from_me`, type is `message_type` (same
`'conversation'`/`'extendedTextMessage'` values). Column names differ from app.db,
do not mix them. `contacts` is fully phone-mapped (740 rows all have `phone`),
and includes 488 `@lid` jid rows that also carry a phone (an internal lid map).

---

## 2. Skip-registry predicate (reuse verbatim)

app.db:
```sql
chat_jid NOT LIKE '%@g.us'
AND chat_jid NOT LIKE '%@broadcast'
AND chat_jid NOT LIKE '628XXXXXXXXXX%'    -- system/AI noise
AND chat_jid NOT LIKE '$TOPER_WA_PHONE%'      -- Toper-self phone
AND chat_jid NOT LIKE '$TOPER_WA_LID%'  -- Toper-self lid
```
messages.db: same, but the phone/lid forms may appear as either key, so also
re-check the RESOLVED phone after the `@lid` merge (section 6).

---

## 3. Freshness queries (drive the decision table)

```sql
-- newest message, human-readable in WIB (UTC+7)
SELECT MAX(timestamp),
       datetime(MAX(timestamp),'unixepoch','+7 hours') AS newest_wib
FROM messages;
```
Compare `now - MAX(timestamp)` against 48h (172800). `wa` liveness in bash:
```bash
WAPID=$(cat "$HOME/.local/share/whatsapp-tui/wa.pid" 2>/dev/null)
ps -p "$WAPID" -o comm= >/dev/null 2>&1 && wa_alive=1 || wa_alive=0
```
Even if `wa_alive=1`, if `now-appMax > 48h` treat app.db as STALE (the pidfile can
outlive the process). Verified 2026-07-03: `wa.pid=369385` pointed at no live
process, app.db newest was 2026-06-30 04:08 WIB, messages.db newest 2026-07-03
07:44 WIB.

---

## 4. Active-set query (app.db path)

Window anchored on the source's own MAX (per the decision table). For the fresh
path swap `(SELECT MAX(timestamp) FROM messages)` for `strftime('%s','now')`.
```sql
SELECT chat_jid, COUNT(*) AS n,
       datetime(MAX(timestamp),'unixepoch','+7 hours') AS last_wib
FROM messages
WHERE chat_jid NOT LIKE '%@g.us'
  AND chat_jid NOT LIKE '%@broadcast'
  AND chat_jid NOT LIKE '628XXXXXXXXXX%'
  AND chat_jid NOT LIKE '$TOPER_WA_PHONE%'
  AND chat_jid NOT LIKE '$TOPER_WA_LID%'
  AND from_me = 0
  AND text IS NOT NULL AND text <> ''
  AND type IN ('conversation','extendedTextMessage')
  AND timestamp >= (SELECT MAX(timestamp) FROM messages) - 7*86400
GROUP BY chat_jid
HAVING COUNT(*) >= 5
ORDER BY n DESC
LIMIT 20;
```
Verified shape (2026-07-03, window = appMax-7d): 6 rows, e.g. `6289658300184`
(88), `6285156366007` (80), `62895323050669` (48), `628118803084` (24, = Cece),
`62895385252813` (21, = Kenny), `62895110000019` (16).

messages.db path: same idea with `is_from_me`, `content`, `message_type`, and add
the `@lid` merge (section 6) so counts are attributed to the right human.

---

## 5. Per-contact fetch (their last ~50 texts)

app.db:
```sql
SELECT datetime(timestamp,'unixepoch','+7 hours') AS wib, text
FROM messages
WHERE chat_jid = :phone_jid
  AND from_me = 0
  AND text IS NOT NULL AND text <> ''
  AND type IN ('conversation','extendedTextMessage')
ORDER BY timestamp DESC
LIMIT 50;
```
Name resolution:
```sql
SELECT COALESCE(NULLIF(c.name,''), NULLIF(c.notify,''), NULLIF(ch.name,''),
                (SELECT push_name FROM messages
                 WHERE chat_jid = :phone_jid AND push_name IS NOT NULL AND push_name<>''
                 ORDER BY timestamp DESC LIMIT 1)) AS display_name
FROM (SELECT :phone_jid AS jid) q
LEFT JOIN contacts c ON c.jid = q.jid
LEFT JOIN chats    ch ON ch.jid = q.jid;
```
Remember: `display_name` is for the human-readable title only. The dedup identity
is the phone JID, never the name.

---

## 6. @lid -> phone merge (messages.db fallback ONLY)

The messages.db fallback keys recent 1:1 chats by `@lid`. Resolve each `@lid` to a
phone JID BEFORE slugging. Precedence, verified by hit-rate on real recent lids
(4/5 via contacts.lid, 2/5 via chats.lid_jid):

```bash
resolve_lid() {  # echoes phone JID or empty
  local lid="$1"
  # 1. app.db contacts.lid  (most complete)
  local p; p=$(sqlite3 "$APPS" "SELECT jid FROM contacts WHERE lid='$lid' AND jid<>'' LIMIT 1;" 2>/dev/null)
  [ -z "$p" ] && p=$(sqlite3 "$APPS" "SELECT jid FROM chats    WHERE lid_jid='$lid' AND jid LIKE '%@s.whatsapp.net' LIMIT 1;" 2>/dev/null)
  [ -z "$p" ] && p=$(sqlite3 "$MSGS" "SELECT phone FROM contacts WHERE jid='$lid' AND phone<>'' LIMIT 1;" 2>/dev/null)
  echo "$p"
}
```
Rules:
- If `resolve_lid` returns empty, the `@lid` is unresolvable. SKIP it, log a gap,
  never slug from the raw `@lid`. (Verified: `27706867605621@lid` resolves to
  nothing in any table.)
- After resolving, re-apply the skip registry on the phone. (Verified:
  `$TOPER_WA_LID` resolves to `$TOPER_WA_PHONE` = Toper-self, must be skipped.)
- To analyze a person fully on this path, UNION their `@lid` rows and their
  phone-JID rows so history is not split:
```sql
SELECT content FROM messages
WHERE (chat_jid = :lid OR chat_jid = :phone_jid)
  AND is_from_me = 0 AND content IS NOT NULL AND content <> ''
  AND message_type IN ('conversation','extendedTextMessage')
ORDER BY timestamp DESC LIMIT 50;
```
LID-split proof (2026-07-03): Cece `628118803084` has 2295 messages in app.db but
only 2 in messages.db (the rest under her `@lid`). This is exactly why app.db is
primary and why the fallback needs the merge.

---

## 7. Quick sanity one-liners

```bash
# how stale is app.db, in whole days
echo $(( ( $(date +%s) - $(sqlite3 "$APPS" "SELECT MAX(timestamp) FROM messages;") ) / 86400 ))
# is a given phone already profiled?
ls "$HOME/.claude/memory/" | grep -i "whatsapp_style_" | wc -l
# columns of a table (drift check)
sqlite3 "$APPS" "SELECT name FROM pragma_table_info('messages');"
```
