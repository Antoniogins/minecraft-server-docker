#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found in PATH." >&2
  exit 1
fi

docker compose version >/dev/null 2>&1 || true

echo "Starting ATM10 server (no rebuild): docker compose up"
exec docker compose up

