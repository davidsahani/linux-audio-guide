#!/usr/bin/env bash
# install.sh
# Installs easyeffects-change-priority service for the current user.

set -euo pipefail

# Must run as root for systemd system-level service installation
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    echo "Usage: sudo ./install.sh"
    exit 1
fi

# Get the actual user who invoked sudo (not root)
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
if [[ -z "$REAL_USER" ]]; then
    echo "Error: Could not determine the real user. Please run with sudo."
    exit 1
fi

REAL_UID=$(id -u "$REAL_USER")
REAL_HOME=$(eval echo "~$REAL_USER")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="easyeffects-change-priority.service"
SCRIPT_FILE="easyeffects-change-priority.sh"

SCRIPT_DEST="$REAL_HOME/.var/app/com.github.wwmm.easyeffects/$SCRIPT_FILE"
SERVICE_DEST="/etc/systemd/system/$SERVICE_FILE"

echo "[>] Installing EasyEffects Change Priority Service"
echo "    User:    $REAL_USER (UID: $REAL_UID)"
echo "    Script:  $SCRIPT_DEST"
echo "    Service: $SERVICE_DEST"
echo ""

# --- Copy the shell script to its destination ---
echo "[*] Copying $SCRIPT_FILE -> $SCRIPT_DEST"
mkdir -p "$(dirname "$SCRIPT_DEST")"
cp "$SCRIPT_DIR/$SCRIPT_FILE" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
chown "$REAL_USER:$REAL_USER" "$SCRIPT_DEST"

# --- Edit and install the service file ---
echo "[*] Installing $SERVICE_FILE -> $SERVICE_DEST"

sed \
    -e "s|After=user@[0-9]*.service|After=user@${REAL_UID}.service|" \
    -e "s|Requires=user@[0-9]*.service|Requires=user@${REAL_UID}.service|" \
    -e 's|\$USER|'"${REAL_USER}"'|g' \
    -e "s|ExecStart=.*${SCRIPT_FILE}|ExecStart=${SCRIPT_DEST}|" \
    -e "s|WantedBy=user@[0-9]*.service|WantedBy=user@${REAL_UID}.service|" \
    "$SCRIPT_DIR/$SERVICE_FILE" > "$SERVICE_DEST"

# --- Reload systemd and enable the service ---
echo "[*] Reloading systemd daemon..."
systemctl daemon-reload

echo "[*] Enabling service..."
systemctl enable "$SERVICE_FILE"

echo ""
echo "[✓] Installation complete!"
echo "    The service will start automatically on next login."
echo "    To start it now:  sudo systemctl start $SERVICE_FILE"
echo "    To check status:  sudo systemctl status $SERVICE_FILE"
