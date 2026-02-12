#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_SRC="$INSTALL_DIR/com.terminal-gateway.plist"
PLIST_NAME="com.terminal-gateway.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
LOG_DIR="$HOME/.terminal-gateway"
NODE_PATH=$(which node)

echo "Terminal Gateway - launchd installer"
echo "====================================="
echo ""
echo "Install directory: $INSTALL_DIR"
echo "Node.js path: $NODE_PATH"
echo ""

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Ensure token exists
if [ ! -f "$HOME/.terminal-gateway-token" ]; then
    echo "No token found. Generating..."
    cd "$INSTALL_DIR" && node scripts/generate-token.js
    echo ""
fi

# Create plist from template
mkdir -p "$HOME/Library/LaunchAgents"

sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|/usr/local/bin/node|$NODE_PATH|g" \
    "$PLIST_SRC" > "$PLIST_DEST"

echo "Plist installed to: $PLIST_DEST"

# Unload existing service if present (idempotent)
echo "Checking for existing service..."
launchctl bootout "gui/$(id -u)" "$PLIST_DEST" 2>/dev/null || true
launchctl unload "$PLIST_DEST" 2>/dev/null || true

# Load the agent using bootstrap (modern approach)
echo "Loading service..."
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"
launchctl enable "gui/$(id -u)/com.terminal-gateway"
launchctl kickstart -k "gui/$(id -u)/com.terminal-gateway"

echo ""
echo "Terminal Gateway service installed and started."
echo "Check status: launchctl list | grep terminal-gateway"
echo "View logs: tail -f $LOG_DIR/launchd-stdout.log"
