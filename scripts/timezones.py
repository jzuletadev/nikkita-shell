#!/usr/bin/env python3
# ~/nikita-shell/scripts/timezones.py
#
# Every time zone with its UTC offset now, for Settings → Date & time (QML can't
# compute them): [{"zone": "America/Lima", "offset": "-05:00", "minutes": -300}, ...]
import json
import subprocess
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

zones = subprocess.run(["timedatectl", "list-timezones"], capture_output=True, text=True, check=True).stdout.split()
now = datetime.now(timezone.utc)
out = []
for name in zones:
    try:
        minutes = int(now.astimezone(ZoneInfo(name)).utcoffset().total_seconds() // 60)
    except Exception:
        continue
    sign = "+" if minutes >= 0 else "-"
    out.append({"zone": name, "offset": f"{sign}{abs(minutes) // 60:02d}:{abs(minutes) % 60:02d}", "minutes": minutes})
print(json.dumps(out))
