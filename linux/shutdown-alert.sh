#!/bin/bash

TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_USER_CHAT_ID"
DEVICE_NAME="$(hostname)"
BOOT_TIME_FILE="/var/lib/boot_alert/boot_time"
SENTINEL_FILE="/var/run/shutdown-alert.sent"
OS_NAME=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 || echo "Linux")

# Prevent duplicate sends during the same shutdown sequence
if [ -f "$SENTINEL_FILE" ]; then
    exit 0
fi
touch "$SENTINEL_FILE"

# Calculate uptime
if [ -f "$BOOT_TIME_FILE" ]; then
    boot_time=$(cat "$BOOT_TIME_FILE")
    boot_epoch=$(date -d "$boot_time" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    if [ -n "$boot_epoch" ] && [ "$boot_epoch" -le "$now_epoch" ]; then
        diff=$((now_epoch - boot_epoch))
        days=$((diff/86400))
        hours=$(((diff%86400)/3600))
        mins=$(((diff%3600)/60))
        UPTIME="${days} days ${hours} hrs ${mins} min"
    else
        UPTIME="Unknown"
    fi
else
    UPTIME="Unknown"
fi

# Construct message
TEXT="Device: $DEVICE_NAME
OS: $OS_NAME
Event: Shutdown/Restart
Time: $(date '+%Y-%m-%d %I:%M:%S %p')
Uptime: $UPTIME"

# Send with fast timeouts (network may be on its last breath)
curl -s --connect-timeout 2 --max-time 3 \
     -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
     --data-urlencode "chat_id=$CHAT_ID" \
     --data-urlencode "text=$TEXT" > /dev/null 2>&1

