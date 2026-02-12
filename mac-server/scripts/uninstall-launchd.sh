#!/bin/bash
set -euo pipefail

PLIST_NAME="com.terminal-gateway.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "Terminal Gateway - launchd uninstaller"
echo "======================================="
echo ""

if [ -f "$PLIST_PATH" ]; then
    echo "Unloading service..."
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
    launchctl unload "$PLIST_PATH" 2>/dev/null || true

    echo "Removing plist..."
    rm "$PLIST_PATH"

    echo ""
    echo "Terminal Gateway service uninstalled."
else
    echo "Service plist not found at: $PLIST_PATH"
    echo "Attempting to stop service anyway..."
    launchctl bootout "gui/$(id -u)/com.terminal-gateway" 2>/dev/null || true
    echo "Done."
fi
