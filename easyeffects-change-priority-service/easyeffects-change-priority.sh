#!/usr/bin/env bash
# easyeffects-change-priority.sh
# Watches for new easyeffects process and automatically elevates its CPU priority.

TARGET_PRIORITY=-10
POLL_INTERVAL=1
TIMEOUT=100

echo "[>] EasyEffects Change Priority Service Started"

for ((i=POLL_INTERVAL; i<=TIMEOUT; i+=POLL_INTERVAL)); do
    # Find all running easyeffects processes
    PIDS=$(pgrep -x easyeffects 2>/dev/null || true)
    
    # If no processes found yet, sleep and try again
    if [[ -z "$PIDS" ]]; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    for pid in $PIDS; do
        # Get current priority value, stripping any whitespace
        CURRENT_PRIORITY=$(ps -o nice= -p "$pid" | tr -d ' ' 2>/dev/null || true)
        
        if [[ -n "$CURRENT_PRIORITY" ]] && [[ "$CURRENT_PRIORITY" -gt "$TARGET_PRIORITY" ]]; then
            renice -n "$TARGET_PRIORITY" -p "$pid" >/dev/null 2>&1
            echo "[*] Elevated EasyEffects CPU priority (PID: $pid) from $CURRENT_PRIORITY to $TARGET_PRIORITY"
        elif [[ "$CURRENT_PRIORITY" -eq "$TARGET_PRIORITY" ]]; then
            echo "[*] EasyEffects (PID: $pid) priority is already $TARGET_PRIORITY. No action needed."
        else
            echo "[*] EasyEffects (PID: $pid) priority is already higher than $TARGET_PRIORITY ($CURRENT_PRIORITY). No action needed."
        fi
    done
    
    # We found EasyEffects and processed it. We are done!
    exit 0
done

echo "[✗] EasyEffects not found after $TIMEOUT seconds. Timing out."
exit 1
