#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GATEWAY_HOST:-}" ]]; then
  HOST="${GATEWAY_HOST}"
else
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "Error: tailscale command is not installed. Set GATEWAY_HOST manually." >&2
    exit 1
  fi
  HOST="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
fi

PORT="${GATEWAY_PORT:-8767}"
TOKEN_FILE="$HOME/.terminal-gateway-token"

if [[ -z "${HOST}" ]]; then
  echo "Error: Could not determine Tailscale IPv4 address. Set GATEWAY_HOST manually." >&2
  exit 1
fi

if [[ ! "${HOST}" =~ ^100\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Invalid GATEWAY_HOST '${HOST}'. Expected Tailscale IPv4 (100.x.x.x)." >&2
  exit 1
fi

if lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Error: port ${PORT} is already in use." >&2
  echo "Use this to inspect: lsof -nP -iTCP:${PORT} -sTCP:LISTEN" >&2
  exit 1
fi

export GATEWAY_HOST="${HOST}"
export GATEWAY_PORT="${PORT}"
export GATEWAY_TOKEN_FILE="${TOKEN_FILE}"
export GATEWAY_SHELL="${GATEWAY_SHELL:-/bin/zsh}"
# Keep caller PATH precedence (e.g. Volta), only append safe defaults.
export PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "Starting Terminal Gateway with:"
echo "  Host: ${GATEWAY_HOST}"
echo "  Port: ${GATEWAY_PORT}"
echo "  Shell: ${GATEWAY_SHELL}"
echo "  Token file: ${GATEWAY_TOKEN_FILE}"
echo

node scripts/generate-token.js
node src/server.js
