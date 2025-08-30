#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found in PATH." >&2
  exit 1
fi

docker compose version >/dev/null 2>&1 || true

echo "CRITICAL: This will rebuild the image. Use only for server UPDATE." >&2
echo "Building and starting ATM10 server (detached): docker compose up -d"
docker compose up -d
echo "Follow logs with: docker compose logs -f"

