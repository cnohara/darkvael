#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
CLOUDFLARED_BIN="${CLOUDFLARED_BIN:-cloudflared}"
SERVER_LOG="$(mktemp -t darkvael-room-server.XXXXXX.log)"
TUNNEL_LOG="$(mktemp -t darkvael-cloudflared.XXXXXX.log)"
SERVER_PID=""
TUNNEL_PID=""

cleanup() {
  if [[ -n "${TUNNEL_PID}" ]] && kill -0 "${TUNNEL_PID}" 2>/dev/null; then
    kill "${TUNNEL_PID}" 2>/dev/null || true
  fi
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cd "${ROOT_DIR}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python not found: ${PYTHON_BIN}" >&2
  exit 1
fi

if ! command -v "${CLOUDFLARED_BIN}" >/dev/null 2>&1; then
  echo "cloudflared not found. Install it with: brew install cloudflared" >&2
  exit 1
fi

echo "Starting DarkVael room server on http://127.0.0.1:${PORT}"
"${PYTHON_BIN}" tools/online_room_server.py >"${SERVER_LOG}" 2>&1 &
SERVER_PID=$!

sleep 1
if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
  echo "Room server failed to start. Log:" >&2
  cat "${SERVER_LOG}" >&2
  exit 1
fi

echo "Opening Cloudflare Quick Tunnel..."
"${CLOUDFLARED_BIN}" tunnel --url "http://127.0.0.1:${PORT}" >"${TUNNEL_LOG}" 2>&1 &
TUNNEL_PID=$!

echo "Waiting for public URL..."
PUBLIC_URL=""
for _ in {1..60}; do
  if [[ ! -z "${PUBLIC_URL}" ]]; then
    break
  fi
  if grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' "${TUNNEL_LOG}" >/dev/null 2>&1; then
    PUBLIC_URL="$(grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' "${TUNNEL_LOG}" | head -n 1)"
    break
  fi
  if ! kill -0 "${TUNNEL_PID}" 2>/dev/null; then
    echo "cloudflared exited unexpectedly. Log:" >&2
    cat "${TUNNEL_LOG}" >&2
    exit 1
  fi
  sleep 1
done

if [[ -z "${PUBLIC_URL}" ]]; then
  echo "Could not detect a Cloudflare URL. Tunnel log:" >&2
  cat "${TUNNEL_LOG}" >&2
  exit 1
fi

cat <<EOF

DarkVael online room service is live.

Server URL:
  ${PUBLIC_URL}

Use that exact URL in both copies of the game.
Then:
  1. Host clicks "Host Online Game"
  2. Guest clicks "Join Online Game"
  3. Host shares the room code

Press Ctrl+C when you're done. This will stop both the room server and the tunnel.
EOF

wait "${TUNNEL_PID}"
