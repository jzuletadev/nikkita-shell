#!/usr/bin/env python3
# ~/nikkita-shell/scripts/music-library.py
#
# The local music library, for the Music window (dotfiles/quickshell/services/Music.qml).
#
#   music-library.py scan ROOT            every song under ROOT (~/Music) and every
#                                         playlist in ROOT/Playlists, as one JSON
#   music-library.py save ROOT NAME [PATH...]
#                                         write a playlist with these songs, in order
#                                         (none: an empty one)
#   music-library.py delete ROOT NAME     remove a playlist
#   music-library.py rename ROOT OLD NEW  rename a playlist
#
# Tags and length come from ffprobe. The cover is the file's embedded picture or,
# for a video, one of its frames, made once with ffmpeg into
# ~/.cache/nikkita-shell/music/covers. What was read stays in a cache by
# path, size and mtime, so a scan only reads new or changed files.
#
# Playlists are extended M3U (.m3u8) with absolute paths: any player opens them.
import hashlib
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

EXTS = {".mp3", ".m4a", ".mp4", ".flac", ".ogg", ".oga", ".opus", ".wav", ".aac", ".webm", ".mkv", ".wma"}
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "nikkita-shell", "music")
COVERS = os.path.join(CACHE_DIR, "covers")


def cache_file(root):
    """One cache per library folder."""
    return os.path.join(CACHE_DIR, "library-" + hashlib.sha1(root.encode()).hexdigest()[:12] + ".json")


def fail(message):
    print(json.dumps({"error": message}))
    sys.exit(1)


def tags_of(info):
    """Tags from the container and its streams, keys in lower case (ogg keeps
    them in the stream, mp3 in the container)."""
    tags = {}
    for stream in info.get("streams", []):
        for k, v in (stream.get("tags") or {}).items():
            tags.setdefault(k.lower(), v)
    for k, v in (info.get("format", {}).get("tags") or {}).items():
        tags[k.lower()] = v
    return tags


def make_cover(path, info, duration):
    out = os.path.join(COVERS, hashlib.sha1(path.encode()).hexdigest() + ".jpg")
    if os.path.exists(out):
        return out
    streams = [s for s in info.get("streams", []) if s.get("codec_type") == "video"]
    if not streams:
        return ""
    pic = next((s for s in streams if s.get("disposition", {}).get("attached_pic")), None)
    if pic is not None:
        cmd = ["ffmpeg", "-v", "quiet", "-y", "-i", path, "-map", f"0:{pic['index']}", "-frames:v", "1",
               "-vf", "scale=300:300:force_original_aspect_ratio=increase,crop=300:300", out]
    else:
        # A video: a frame a little way in, not the black first one.
        at = str(min(max(duration * 0.2, 0), 30))
        cmd = ["ffmpeg", "-v", "quiet", "-y", "-ss", at, "-i", path, "-frames:v", "1",
               "-vf", "scale=300:300:force_original_aspect_ratio=increase,crop=300:300", out]
    subprocess.run(cmd, stdin=subprocess.DEVNULL)
    return out if os.path.exists(out) else ""


def probe(path):
    r = subprocess.run(["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", path],
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    try:
        info = json.loads(r.stdout or "{}")
    except json.JSONDecodeError:
        info = {}
    tags = tags_of(info)
    try:
        duration = float(info.get("format", {}).get("duration") or 0)
    except ValueError:
        duration = 0.0
    try:
        track = int(str(tags.get("track", "0")).split("/")[0] or 0)
    except ValueError:
        track = 0
    stem = os.path.splitext(os.path.basename(path))[0]
    return {
        "path": path,
        "title": (tags.get("title") or stem).strip(),
        "artist": (tags.get("artist") or tags.get("album_artist") or "").strip(),
        "album": (tags.get("album") or "").strip(),
        "track": track,
        "duration": round(duration, 2),
        "cover": make_cover(path, info, duration),
    }


def scan(root):
    os.makedirs(os.path.join(root, "Playlists"), exist_ok=True)
    os.makedirs(COVERS, exist_ok=True)
    try:
        with open(cache_file(root)) as f:
            cache = json.load(f)
    except (OSError, json.JSONDecodeError):
        cache = {}

    files = []
    for folder, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for name in names:
            if os.path.splitext(name)[1].lower() in EXTS and not name.startswith("."):
                files.append(os.path.join(folder, name))

    songs, todo = {}, []
    for path in files:
        st = os.stat(path)
        old = cache.get(path)
        if old and old.get("mtime") == st.st_mtime and old.get("size") == st.st_size \
                and (not old["song"]["cover"] or os.path.exists(old["song"]["cover"])):
            songs[path] = old["song"]
        else:
            todo.append((path, st))
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        for (path, st), song in zip(todo, pool.map(lambda t: probe(t[0]), todo)):
            songs[path] = song
            cache[path] = {"mtime": st.st_mtime, "size": st.st_size, "song": song}

    cache = {p: v for p, v in cache.items() if p in songs}
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(cache_file(root), "w") as f:
        json.dump(cache, f)

    ordered = sorted(songs.values(), key=lambda s: (s["artist"].lower(), s["album"].lower(), s["track"], s["title"].lower()))
    return {"root": root, "songs": ordered, "playlists": playlists(root, songs)}


def playlists(root, songs):
    folder = os.path.join(root, "Playlists")
    out = []
    for name in sorted(os.listdir(folder), key=str.lower):
        stem, ext = os.path.splitext(name)
        if ext.lower() not in (".m3u", ".m3u8"):
            continue
        paths = []
        with open(os.path.join(folder, name), encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                path = line if os.path.isabs(line) else os.path.normpath(os.path.join(folder, line))
                if path in songs:
                    paths.append(path)
        out.append({"name": stem, "file": os.path.join(folder, name), "songs": paths})
    return out


def playlist_file(root, name):
    name = name.strip()
    if not name or "/" in name or name.startswith("."):
        fail("A playlist needs a name, without slashes.")
    return os.path.join(root, "Playlists", name + ".m3u8")


def save(root, name, paths):
    target = playlist_file(root, name)
    try:
        with open(cache_file(root)) as f:
            cache = json.load(f)
    except (OSError, json.JSONDecodeError):
        cache = {}
    lines = ["#EXTM3U"]
    for path in paths:
        song = cache.get(path, {}).get("song", {})
        label = " - ".join(x for x in (song.get("artist"), song.get("title")) if x) or os.path.basename(path)
        lines.append(f"#EXTINF:{int(song.get('duration') or -1)},{label}")
        lines.append(path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    tmp = target + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, target)
    return {"ok": True}


def main():
    if len(sys.argv) < 3:
        fail("usage: music-library.py scan|save|delete|rename ROOT [NAME [NEW]]")
    cmd, root = sys.argv[1], os.path.abspath(os.path.expanduser(sys.argv[2]))
    if cmd == "scan":
        result = scan(root)
    elif cmd == "save" and len(sys.argv) >= 4:
        result = save(root, sys.argv[3], sys.argv[4:])
    elif cmd == "delete" and len(sys.argv) == 4:
        os.remove(playlist_file(root, sys.argv[3]))
        result = {"ok": True}
    elif cmd == "rename" and len(sys.argv) == 5:
        old, new = playlist_file(root, sys.argv[3]), playlist_file(root, sys.argv[4])
        if os.path.exists(new):
            fail(f"There is already a playlist called {sys.argv[4]}.")
        os.rename(old, new)
        result = {"ok": True}
    else:
        fail("usage: music-library.py scan|save|delete|rename ROOT [NAME [NEW]]")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
