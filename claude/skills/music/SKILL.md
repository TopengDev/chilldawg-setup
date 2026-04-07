---
name: music
description: >
  Music playback controller and DJ using mpv + yt-dlp. Use when the user asks to
  play, pause, stop, skip music, asks what's playing, wants a recommendation,
  says "play something", mentions a mood (chill, sad, upbeat, romantic, nostalgic,
  late-night), or anything related to music. Also triggers on: "what's playing",
  "next song", "surprise me", "stop the music", "change it".
allowed-tools: Bash, Read, Write, Edit, Grep
---

# Music Skill — mpv + yt-dlp (Linux)

Stream music from YouTube via mpv. No ads, no account needed.

## Architecture

| Tool | Purpose |
|------|---------|
| `mpv` | Audio player (streams YouTube via yt-dlp) |
| `yt-dlp` | YouTube stream extraction (no ads) |
| `~/.music/profile.json` | User taste profile, mood mappings, dislikes |
| `~/.music/history.json` | Play history for smart picks |

## Playback Control

**All mpv playback MUST run inside a tmux window.** Background `&` processes do not route audio correctly.

### Step 1: Ensure a music tmux window exists

```bash
# Check if music window already exists
tmux list-windows -F '#I:#W' 2>/dev/null | grep -q "music"
```

If no music window exists, create one:
```bash
tmux new-window -n "music"
```

### Step 2: Play a song

Send the mpv command to the music window via `send-keys`:

```bash
# Stop any existing mpv first
tmux send-keys -t :music C-c
sleep 0.5

# Play new song
tmux send-keys -t :music 'mpv --no-video --really-quiet "ytdl://ytsearch:SONG ARTIST"' Enter
echo "Playing: SONG by ARTIST"
```

### Step 3: Play with queue (multiple songs)

```bash
tmux send-keys -t :music C-c
sleep 0.5

tmux send-keys -t :music 'mpv --no-video --really-quiet --playlist=-' Enter
tmux send-keys -t :music 'ytdl://ytsearch:song1 artist1' Enter
tmux send-keys -t :music 'ytdl://ytsearch:song2 artist2' Enter
tmux send-keys -t :music 'ytdl://ytsearch:song3 artist3' Enter
tmux send-keys -t :music '' Enter  # empty line to end playlist input
```

### Controls

```bash
# Stop
tmux send-keys -t :music C-c

# Check if playing
tmux capture-pane -t :music -p | tail -5

# Skip to next song
tmux send-keys -t :music C-c
sleep 0.5
tmux send-keys -t :music 'mpv --no-video --really-quiet "ytdl://ytsearch:NEW SONG"' Enter
```

### Verifying playback

After sending keys, verify mpv started:
```bash
sleep 2
tmux capture-pane -t :music -p | tail -3
```

If you see errors, the search term may have failed — try an alternative search.

---

## Data Files (~/.music/)

### profile.json

```json
{
  "last_updated": "2026-04-03",
  "mood_to_searches": {
    "sad": ["radiohead creep", "bon iver skinny love", "elliott smith between the bars"],
    "chill": ["nujabes feather", "khruangbin evan finds the third room", "tame impala the less i know the better"],
    "romantic": ["daniel caesar best part", "frank ocean thinkin bout you", "sza the weekend"],
    "upbeat": ["daft punk get lucky", "mark ronson uptown funk", "pharrell happy"],
    "nostalgic": ["oasis wonderwall", "green day basket case", "nirvana smells like teen spirit"],
    "late-night": ["mac demarco chamber of reflection", "the neighbourhood sweater weather", "arctic monkeys do i wanna know"],
    "focus": ["lofi hip hop radio", "hans zimmer interstellar soundtrack", "tycho dive"],
    "indonesian": ["sheila on 7 dan", "dewa 19 kangen", "noah separuh aku"]
  },
  "favorites": [],
  "dislikes": [],
  "play_history": []
}
```

### Querying profile
```bash
# Get mood playlist
jq -r '.mood_to_searches["chill"][]' ~/.music/profile.json

# Check dislikes
jq -r '.dislikes[]? | .artist' ~/.music/profile.json

# Get play history
jq -r '.play_history[-10:][] | "\(.title) - \(.artist)"' ~/.music/profile.json
```

---

## Smart Pick Logic

### Step 0: ALWAYS check dislikes first
```bash
jq -r '.dislikes[]? | .artist' ~/.music/profile.json
```
Never recommend disliked artists.

### "Play something" (no mood)
1. Check play history to avoid repeats
2. Pick from favorites or a random mood category
3. Play it, tell user what you picked and why

### "Play something <mood>"
1. Map mood to searches in profile.json
2. Pick a random entry from that mood
3. Play it

### "Surprise me"
1. Think of something the user probably hasn't heard based on their history
2. Pick something outside their usual genres
3. Play it, explain why they might like it

---

## Feedback Tracking

### Positive ("love this", "more like this", "fav")
```bash
jq '.favorites += [{"artist":"ARTIST","title":"TITLE","date":"DATE"}]' ~/.music/profile.json > /tmp/music_tmp.json && mv /tmp/music_tmp.json ~/.music/profile.json
```

### Negative ("change it", "skip", "don't like this")
```bash
jq '.dislikes += [{"artist":"ARTIST","title":"TITLE","reason":"REASON","date":"DATE"}]' ~/.music/profile.json > /tmp/music_tmp.json && mv /tmp/music_tmp.json ~/.music/profile.json
```

Then immediately play something different.

### Log play
After every play, log it:
```bash
jq '.play_history += [{"artist":"ARTIST","title":"TITLE","date":"DATE","mood":"MOOD"}]' ~/.music/profile.json > /tmp/music_tmp.json && mv /tmp/music_tmp.json ~/.music/profile.json
```

---

## Mood Customization

Users can add custom mood mappings:
```bash
jq '.mood_to_searches["workout"] = ["eminem lose yourself", "eye of the tiger", "dmx x gon give it to ya"]' ~/.music/profile.json > /tmp/music_tmp.json && mv /tmp/music_tmp.json ~/.music/profile.json
```

---

## Response Style

- One brief line when playing. Don't be verbose.
- For smart picks, one-liner about WHY you chose it.
- Don't ask confirmation before playing. Just play it.
- If user says "change it" — record dislike, play something else immediately.
- If user says "stop" — kill mpv, done.
