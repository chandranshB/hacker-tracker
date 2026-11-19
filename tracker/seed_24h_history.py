#!/usr/bin/env python3
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
HISTORY_FILE = DATA_DIR / "history.json"

now = datetime.now(timezone.utc)
# Generate 48 points spanning the last 24 hours, ending now
entries = []

# Battery discharge schedule over 48 30-min intervals
# 24h ago down to now: 85% down to 43%
discharge_curve = [
    85, 85, 84, 84, 83, 83, 82, 82, 81, 81, 80, 80,
    79, 79, 78, 78, 77, 77, 76, 76, 76, 75, 75, 75,
    75, 75, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74,
    74, 74, 73, 73, 71, 68, 62, 56, 51, 47, 45, 43
]

total_points = len(discharge_curve)
for i, bat in enumerate(discharge_curve):
    delta_mins = (total_points - 1 - i) * 30
    point_time = now - timedelta(minutes=delta_mins)
    entries.append({
        "timestamp": point_time.isoformat(),
        "battery_pct": bat,
        "battery_raw": f"{bat}%",
        "ip": "106.211.47.194",
        "status": True,
        "msg_count": 613 if i < 40 else 614,
        "liveness_ping": "ping_magic_scan",
        "liveness_pong": "pong",
        "command": "forward status"
    })

DATA_DIR.mkdir(parents=True, exist_ok=True)
with open(HISTORY_FILE, "w", encoding="utf-8") as f:
    json.dump(entries, f, indent=2)

print(f"[+] Wrote {len(entries)} 30-min historical records to {HISTORY_FILE}")
