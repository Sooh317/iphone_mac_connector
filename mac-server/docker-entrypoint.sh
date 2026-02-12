#!/bin/sh
set -e

# Token file path (from environment variable or default)
TOKEN_FILE=${GATEWAY_TOKEN_FILE:-/data/terminal-gateway-token}

# Generate token if it doesn't exist
if [ ! -f "$TOKEN_FILE" ]; then
  echo "Generating authentication token..."

  # Create config.json with the token file path
  cat > config.json <<EOF
{
  "host": "127.0.0.1",
  "port": 8765,
  "shell": "/bin/zsh",
  "tokenFile": "$TOKEN_FILE"
}
EOF
  chmod 600 config.json

  node scripts/generate-token.js
  echo ""
  echo "Token has been generated and saved to $TOKEN_FILE"
  echo "You can view it with: docker exec terminal-gateway cat $TOKEN_FILE"
  echo ""
fi

# Start the server
exec node src/server.js
