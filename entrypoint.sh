#!/usr/bin/env bash
set -euo pipefail

# Defaults
DATA_DIR=${DATA_DIR:-/data}
PACK_ZIP=${PACK_ZIP:-/opt/server/pack.zip}
UNZIP_FLAGS=${UNZIP_FLAGS:--q}
SERVER_PACK_URL=${SERVER_PACK_URL:-}
FORCE_INIT=${FORCE_INIT:-false}

log() { echo "[entrypoint] $*"; }

# Ensure data dir exists and is owned by minecraft
mkdir -p "$DATA_DIR"
chown -R minecraft:minecraft "$DATA_DIR" || true

# Ensure we have a pack zip available; prefer runtime URL if provided
if [ ! -f "$PACK_ZIP" ] && [ -n "$SERVER_PACK_URL" ]; then
  log "Descargando pack desde SERVER_PACK_URL=$SERVER_PACK_URL"
  mkdir -p "$(dirname "$PACK_ZIP")"
  curl -L -o "$PACK_ZIP" "$SERVER_PACK_URL"
fi

# If DATA_DIR is empty (or FORCE_INIT=true), extract the server pack there
need_init=false
if [ "$FORCE_INIT" = "true" ]; then
  need_init=true
elif [ -d "$DATA_DIR" ] && [ -z "$(ls -A "$DATA_DIR")" ]; then
  need_init=true
fi

if [ "$need_init" = true ]; then
  if [ -f "$PACK_ZIP" ]; then
    log "Inicializando datos en $DATA_DIR desde $PACK_ZIP"
    # Extract directly into DATA_DIR, but some packs have top-level folder
    # Extract to a temp and then rsync to flatten if needed
    tmpdir=$(mktemp -d)
    unzip $UNZIP_FLAGS "$PACK_ZIP" -d "$tmpdir"
    # If the zip has a single top folder, descend into it
    inner="$tmpdir"
    count=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [ "$count" -eq 1 ]; then
      inner=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d)
    fi
    rsync -a --remove-source-files "$inner"/ "$DATA_DIR"/
    rm -rf "$tmpdir"
  else
    log "No se encontró el ZIP en $PACK_ZIP; nada que inicializar"
  fi
else
  log "$DATA_DIR ya contiene datos; se omite la extracción (use FORCE_INIT=true para forzar)"
fi

# Fix ownership and drop privileges to minecraft for the final command
chown -R minecraft:minecraft "$DATA_DIR" || true

if [ "$#" -gt 0 ]; then
  exec gosu minecraft "$@"
else
  exec gosu minecraft tail -f /dev/null
fi
