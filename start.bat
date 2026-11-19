@echo off
title C2 Device Monitor (03e768e104ef026d)
echo ========================================================
echo  Launching C2 Device Monitor Dashboard (Safe Read-Only)
echo  Target Device: 03e768e104ef026d
echo ========================================================
echo.
start "" "http://localhost:8080"
python -m http.server 8080
pause
