# Hacker Tracker (`03e768e104ef026d`)

Lightweight, real-time status monitor and automated 30-minute historical telemetry tracker for device `03e768e104ef026d` (the C2 auto-relay gateway handset).

- **Cloudflare Pages**: [https://c2-device-tracker.pages.dev](https://c2-device-tracker.pages.dev)
- **GitHub Repository**: [https://github.com/chandranshB/hacker-tracker](https://github.com/chandranshB/hacker-tracker)

---

## Features
- **Strict Read-Only**: Performs HTTP GET requests only. Zero database mutations.
- **Minimal Load**: Fetches only endpoints for `03e768e104ef026d` (<200 KB bandwidth).
- **Fast Search & OTP Highlighting**: Instant client-side search across all messages with extracted credentials and OTP codes highlighted with 1-click copy.
- **GitHub Cron Tracker**: Automatically checks status every 30 minutes (`.github/workflows/track-device.yml`) and archives state changes.

---

## Local Usage
```bash
python -m http.server 8080
```
Open [http://localhost:8080](http://localhost:8080) in your browser.
