# SpyBoot

SpyBoot is a small utility that sends Telegram notifications whenever your **Windows 10/11 PC or Ubuntu machine** boots or shuts down. It also includes basic network information, public IP geolocation, offline queuing, and uptime tracking.

## ✨ Features

- Telegram notifications on boot and shutdown
- Device, OS, network and geolocation information
- Uptime included in shutdown notifications
- Offline queue for boot alerts
- Prevents duplicate boot notifications
- Separate implementations for Windows and Linux (Ubuntu)

---

## 📋 Prerequisites

Before using SpyBoot, create a Telegram bot and obtain your chat ID.

### 1. Create a Telegram Bot

Create a bot using [@BotFather](https://t.me/BotFather) and copy the bot token.

### 2. Get Your Chat ID

Send a message to your bot, then visit:

```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```

Find the `"id"` value inside the `"chat"` object.

Example:

```json
"chat": {
    "id": 123456789,
    ...
}
```

Replace the placeholders inside the scripts:

```
YOUR_BOT_TOKEN
YOUR_USER_CHAT_ID
```

---

# 🪟 Windows Setup

## 1. Copy the Scripts

Create a folder:

```
C:\Scripts
```

Copy the following files into it:

```
windows/
├── BootAlert.ps1
└── ShutdownAlert.ps1
```

---

## 2. Configure the Scripts

Open both PowerShell scripts and replace:

```powershell
YOUR_BOT_TOKEN
YOUR_USER_CHAT_ID
```

with your own values.

---

## 3. Import the Boot Task

1. Open **Task Scheduler** as Administrator.
2. Select **Task Scheduler Library**.
3. Click **Import Task...**
4. Import:

```
windows/BootAlertTask.xml
```

5. Verify the action points to:

```text
powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\BootAlert.ps1"
```

---

## 4. Import the Shutdown Task

Repeat the same process for:

```
windows/ShutdownAlertTask.xml
```

Verify the action points to:

```text
powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\ShutdownAlert.ps1"
```

---

## 5. Test

Right-click each task and select **Run**.

If configured correctly, you should receive a Telegram notification.

*(If right-click > Run does not work, try actually shutting down or booting up)*

---

# 🐧 Ubuntu Setup

## 1. Install Dependency

```bash
sudo apt update
sudo apt install curl -y
```

---

## 2. Copy the Scripts

Copy the executable scripts:

```bash
sudo cp linux/boot-alert.sh /usr/local/bin/boot-alert.sh
sudo chmod +x /usr/local/bin/boot-alert.sh

sudo cp linux/shutdown-alert.sh /usr/local/bin/shutdown-alert.sh
sudo chmod +x /usr/local/bin/shutdown-alert.sh
```

Copy the systemd files:

```bash
sudo cp linux/boot-alert.service /etc/systemd/system/boot-alert.service
sudo cp linux/boot-alert.timer /etc/systemd/system/boot-alert.timer
```

Copy the NetworkManager dispatcher:

```bash
sudo cp linux/99-shutdown-alert /etc/NetworkManager/dispatcher.d/99-shutdown-alert
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-shutdown-alert
```

---

## 3. Configure the Scripts

Edit both scripts:

```bash
sudo nano /usr/local/bin/boot-alert.sh
```

```bash
sudo nano /usr/local/bin/shutdown-alert.sh
```

Replace:

```bash
TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_USER_CHAT_ID"
```

with your own credentials.

---

## 4. Enable the Boot Timer

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable the timer:

```bash
sudo systemctl enable boot-alert.timer
```

Start it:

```bash
sudo systemctl start boot-alert.timer
```

Verify it is running:

```bash
systemctl status boot-alert.timer
```

---

## 5. Shutdown Alert

The shutdown notification uses a NetworkManager dispatcher.

To test it manually:

```bash
sudo /usr/local/bin/shutdown-alert.sh
```

If you have already tested once, remove the sentinel file before testing again:

```bash
sudo rm -f /var/run/shutdown-alert.sent
```

---

## ⚙️ How It Works

- **Windows** detects new boots using `LastBootUpTime` and sends notifications through Task Scheduler.
- **Ubuntu** tracks `/proc/sys/kernel/random/boot_id` and retries queued boot notifications every 15 seconds using a systemd timer.
- If no internet connection is available during boot, the notification is queued and sent once connectivity returns.
- Shutdown notifications are triggered by **Event ID 1074** on Windows and a **NetworkManager dispatcher** on Ubuntu.

---

## 🧪 Testing

### Windows

**Boot**

Restart the computer and wait a few seconds for the notification.

**Shutdown**

Shut down or restart Windows and verify the shutdown notification.

### Ubuntu

**Boot**

Restart the machine. The timer should send the notification within approximately 15–30 seconds once network connectivity is available.

**Shutdown**

*(On my testing, shutdown notifications were not coming to telegram due to )*

You can run:

```bash
sudo /usr/local/bin/shutdown-alert.sh
```

to verify the script works correctly.

---

## 🔒 Security Notes

- Never commit your real Telegram bot token.
- Replace all placeholder values before use.
- If your bot token is exposed, revoke it immediately using [@BotFather](https://t.me/BotFather).
- Windows tasks run as **SYSTEM**.
- Ubuntu scripts run as **root**.

---

## License

This project is provided as-is for personal and educational use.

Feel free to modify it to suit your own needs.