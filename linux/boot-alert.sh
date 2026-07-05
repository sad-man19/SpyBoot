#!/bin/bash

# ===== CONFIGURATION =====
TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_USER_CHAT_ID"
DEVICE_NAME="$(hostname)"
QUEUE_DIR="/var/lib/boot_alert"
QUEUE_FILE="$QUEUE_DIR/queue"
BOOT_ID_FILE="$QUEUE_DIR/last_boot_id"
BOOT_TIME_FILE="$QUEUE_DIR/boot_time"
# =========================

mkdir -p "$QUEUE_DIR"

# Clear the shutdown sentinel so the next shutdown alert can fire
rm -f /var/run/shutdown-alert.sent

# --- 1. New boot check (log only on fresh boot) ---
current_boot_id=$(cat /proc/sys/kernel/random/boot_id)

if [ ! -f "$BOOT_ID_FILE" ] || [ "$(cat "$BOOT_ID_FILE")" != "$current_boot_id" ]; then
    date '+%Y-%m-%d %I:%M:%S %p' >> "$QUEUE_FILE"
    echo "$current_boot_id" > "$BOOT_ID_FILE"
    date '+%Y-%m-%d %H:%M:%S' > "$BOOT_TIME_FILE"
fi

# --- 2. Offline check ---
if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    exit 0
fi

# --- 3. Collect network information ---
# Local IP addresses
LOCAL_IPS=$(hostname -I | xargs)
[ -z "$LOCAL_IPS" ] && LOCAL_IPS="N/A"

# Wi-Fi SSID (via nmcli if NetworkManager is available)
SSID="N/A"
if command -v nmcli &> /dev/null; then
    SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d':' -f2 | head -1)
    [ -z "$SSID" ] && SSID="N/A"
fi

# Default gateway
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
[ -z "$GATEWAY" ] && GATEWAY="N/A"

# Public IP & geolocation
PUBLIC_IP="Unavailable"
LOCATION=""
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    if [ -n "$PUBLIC_IP" ]; then
        GEO=$(curl -s --max-time 5 "http://ip-api.com/json/$PUBLIC_IP")
        CITY=$(echo "$GEO" | grep -Po '"city":".*?"' | cut -d'"' -f4)
        COUNTRY=$(echo "$GEO" | grep -Po '"country":".*?"' | cut -d'"' -f4)
        ISP=$(echo "$GEO" | grep -Po '"isp":".*?"' | cut -d'"' -f4)
        if [ -n "$CITY" ]; then
            LOCATION="$CITY, $COUNTRY ($ISP)"
        else
            LOCATION="Unknown"
        fi
    fi
else
    PUBLIC_IP="curl missing"
    LOCATION="curl missing"
fi

# --- 4. OS name ---
OS_NAME=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 || echo "Linux")

# --- 5. Send all queued timestamps ---
if [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ]; then
    exit 0
fi

while IFS= read -r timestamp; do
    TEXT="Device: $DEVICE_NAME
OS: $OS_NAME
Booted at: $timestamp
Local IP: $LOCAL_IPS
SSID: $SSID
Gateway: $GATEWAY
Public IP: $PUBLIC_IP
Location: $LOCATION"

    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
         --data-urlencode "chat_id=$CHAT_ID" \
         --data-urlencode "text=$TEXT" > /dev/null

    if [ $? -ne 0 ]; then
        exit 1   # keep queue, retry later
    fi
done < "$QUEUE_FILE"

# All queued messages sent successfully → clear queue
> "$QUEUE_FILE"

