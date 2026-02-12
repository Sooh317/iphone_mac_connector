#!/bin/sh
set -e

# Generate token if it doesn't exist
if [ ! -f /data/terminal-gateway-token ]; then
  echo "Generating authentication token..."
  node scripts/generate-token.js
  echo ""
  echo "Token has been generated and saved to /data/terminal-gateway-token"
  echo "You can view it with: docker exec terminal-gateway cat /data/terminal-gateway-token"
  echo ""
fi

# Start the server
exec node src/server.js
