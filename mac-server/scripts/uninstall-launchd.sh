#!/bin/bash
set -e

# Terminal Gateway launchd Uninstallation Script
# This script removes the terminal-gateway service from launchd

PLIST_NAME="com.terminal-gateway.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "=== Terminal Gateway launchd Uninstallation ==="
echo ""

# Check if service is loaded
if launchctl list | grep -q "com.terminal-gateway"; then
    echo "Unloading service..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    echo "Service unloaded."
else
    echo "Service is not currently loaded."
fi

# Remove plist file
if [ -f "$PLIST_PATH" ]; then
    echo "Removing plist file..."
    rm "$PLIST_PATH"
    echo "Plist file removed."
else
    echo "Plist file not found at $PLIST_PATH"
fi

echo ""
echo "✅ Uninstallation complete!"
echo ""
echo "Note: Logs and configuration files were not removed."
echo "To remove all data, manually delete:"
echo "  - ~/.terminal-gateway/ (audit logs)"
echo "  - ~/.terminal-gateway-token (authentication token)"
echo "  - <project>/mac-server/logs/ (service logs)"
echo "  - <project>/mac-server/config.json (configuration)"
echo ""
