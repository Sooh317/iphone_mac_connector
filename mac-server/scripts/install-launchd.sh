#!/bin/bash
set -e

# Terminal Gateway launchd Installation Script
# This script installs the terminal-gateway service to run automatically on macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_TEMPLATE="$PROJECT_ROOT/com.terminal-gateway.plist"
PLIST_NAME="com.terminal-gateway.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
LOGS_DIR="$PROJECT_ROOT/logs"
NODE_BIN="$(command -v node || true)"

echo "=== Terminal Gateway launchd Installation ==="
echo ""

# Check if plist template exists
if [ ! -f "$PLIST_TEMPLATE" ]; then
    echo "Error: plist template not found at $PLIST_TEMPLATE"
    exit 1
fi

# Verify Node.js is available
if [ -z "$NODE_BIN" ]; then
    echo "Error: Node.js not found in PATH"
    echo "Please install Node.js and retry."
    exit 1
fi

# Create logs directory
if [ ! -d "$LOGS_DIR" ]; then
    echo "Creating logs directory..."
    mkdir -p "$LOGS_DIR"
fi

# Create LaunchAgents directory if it doesn't exist
if [ ! -d "$LAUNCH_AGENTS_DIR" ]; then
    echo "Creating LaunchAgents directory..."
    mkdir -p "$LAUNCH_AGENTS_DIR"
fi

# Replace template placeholders in plist
echo "Configuring plist with project path: $PROJECT_ROOT"
echo "Using Node.js binary: $NODE_BIN"
sed \
  -e "s|ABSOLUTE_PATH_TO_PROJECT|$PROJECT_ROOT|g" \
  -e "s|ABSOLUTE_PATH_TO_NODE|$NODE_BIN|g" \
  "$PLIST_TEMPLATE" > "$PLIST_DEST"

# Check if already loaded and unload if necessary
if launchctl list | grep -q "com.terminal-gateway"; then
    echo "Service already loaded. Unloading..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Load the service
echo "Loading service..."
launchctl load "$PLIST_DEST"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Service: com.terminal-gateway"
echo "Plist location: $PLIST_DEST"
echo "Logs directory: $LOGS_DIR"
echo ""
echo "The service will start automatically on login."
echo ""
echo "Useful commands:"
echo "  Check status:    launchctl list | grep com.terminal-gateway"
echo "  View stdout:     tail -f $LOGS_DIR/stdout.log"
echo "  View stderr:     tail -f $LOGS_DIR/stderr.log"
echo "  View audit log:  tail -f ~/.terminal-gateway/audit.log"
echo "  Restart service: launchctl kickstart -k gui/$(id -u)/com.terminal-gateway"
echo "  Uninstall:       $SCRIPT_DIR/uninstall-launchd.sh"
echo ""
