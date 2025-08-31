#!/usr/bin/env bash
set -euo pipefail

# Env vars
SERVER_HOME=${SERVER_HOME:-/opt/server-dist}
DATA_DIR=${DATA_DIR:-/data}
BACKUP_DIR=${BACKUP_DIR:-/data/backups}
SERVER_PACK_URL=${SERVER_PACK_URL:-}
# Update/backup behavior
UPDATE_ON_START=${UPDATE_ON_START:-false}
ALWAYS_BACKUP_ON_START=${ALWAYS_BACKUP_ON_START:-false}

# Memory settings
JVM_MIN_MEMORY=${JVM_MIN_MEMORY:-2G}
JVM_MAX_MEMORY=${JVM_MAX_MEMORY:-4G}
JVM_OPTS=${JVM_OPTS:-""}

# EULA and admin
EULA=${EULA:-false}
DEFAULT_OPS=${DEFAULT_OPS:-}

# Update behavior
WIPE_CONFIG=${WIPE_CONFIG:-false}
WIPE_DIRS=${WIPE_DIRS:-"libraries mods packmenu kubejs defaultconfigs"}

# Common server settings
RCON_PORT=${RCON_PORT:-25575}
RCON_PASSWORD=${RCON_PASSWORD:-}
ENABLE_RCON=${ENABLE_RCON:-true}
SERVER_PORT=${SERVER_PORT:-25565}
JAVA_HOME=${JAVA_HOME:-/opt/java/openjdk}
TZ=${TZ:-UTC}
# Additional properties
MOTD=${MOTD:-"ATM10 Server"}
ONLINE_MODE=${ONLINE_MODE:-true}
MAX_PLAYERS=${MAX_PLAYERS:-20}
ENABLE_QUERY=${ENABLE_QUERY:-false}
QUERY_PORT=${QUERY_PORT:-$SERVER_PORT}

export TZ

mkdir -p "$DATA_DIR" "$BACKUP_DIR"

# Optional full backup on every start (off by default)
if [ "${ALWAYS_BACKUP_ON_START,,}" = "true" ]; then
  if [ -d "$DATA_DIR" ] && [ "$(ls -A "$DATA_DIR" 2>/dev/null || true)" ]; then
    timestamp=$(date +%Y%m%d_%H%M%S)
    archive="$BACKUP_DIR/server_full_${timestamp}.tar.gz"
    echo "ALWAYS_BACKUP_ON_START=true -> Creating full backup: $archive"
    tar -czf "$archive" --exclude="$BACKUP_DIR" -C "$DATA_DIR" . || echo "Backup failed (continuing)."
  fi
fi

# Ensure base server files exist in DATA_DIR by copying from SERVER_HOME once (idempotent)
if [ -d "$SERVER_HOME" ]; then
  if [ ! -f "$DATA_DIR/startserver.sh" ] && [ -f "$SERVER_HOME/startserver.sh" ]; then
    echo "Seeding data directory with server distribution from $SERVER_HOME"
    rsync -a --ignore-existing "$SERVER_HOME/" "$DATA_DIR/"
  fi
else
  echo "Warning: SERVER_HOME $SERVER_HOME not found."
fi

# Download server pack on first run OR during explicit update
if [ -n "$SERVER_PACK_URL" ]; then
  if [ ! -f "$DATA_DIR/startserver.sh" ] || [ "${UPDATE_ON_START,,}" = "true" ]; then
    echo "Fetching server pack from $SERVER_PACK_URL"
    tmpzip="/tmp/pack.zip"
    wget -O "$tmpzip" "$SERVER_PACK_URL"
    if [ "${UPDATE_ON_START,,}" = "true" ]; then
      echo "UPDATE_ON_START=true -> Will unpack over existing data after wipe logic"
    else
      unzip -o -q "$tmpzip" -d "$DATA_DIR"
    fi
    rm -f "$tmpzip"
  fi
fi

# Make sure start scripts are executable
if [ -f "$DATA_DIR/startserver.sh" ]; then chmod +x "$DATA_DIR/startserver.sh"; fi
if [ -f "$DATA_DIR/start.sh" ]; then chmod +x "$DATA_DIR/start.sh"; fi

# EULA handling
if [ "${EULA,,}" = "true" ]; then
  echo "eula=true" > "$DATA_DIR/eula.txt"
fi

# Configure RCON/server.properties and other properties
PROP_FILE="$DATA_DIR/server.properties"
if [ ! -f "$PROP_FILE" ]; then
  echo "Creating $PROP_FILE"
  touch "$PROP_FILE"
fi

if [ -f "$PROP_FILE" ]; then
  # Basic network settings
  sed -i "s/^server-port=.*/server-port=${SERVER_PORT}/" "$PROP_FILE" || true
  if [ "${ENABLE_RCON,,}" = "true" ]; then
    sed -i "s/^enable-rcon=.*/enable-rcon=true/" "$PROP_FILE" || true
    sed -i "s/^rcon.port=.*/rcon.port=${RCON_PORT}/" "$PROP_FILE" || true
    if [ -n "$RCON_PASSWORD" ]; then
      if grep -q '^rcon.password=' "$PROP_FILE"; then
        sed -i "s/^rcon.password=.*/rcon.password=${RCON_PASSWORD}/" "$PROP_FILE" || true
      else
        echo "rcon.password=${RCON_PASSWORD}" >> "$PROP_FILE"
      fi
    fi
  else
    sed -i "s/^enable-rcon=.*/enable-rcon=false/" "$PROP_FILE" || true
  fi

  # Query
  if [ "${ENABLE_QUERY,,}" = "true" ]; then
    if grep -q '^enable-query=' "$PROP_FILE"; then
      sed -i "s/^enable-query=.*/enable-query=true/" "$PROP_FILE" || true
    else
      echo "enable-query=true" >> "$PROP_FILE"
    fi
    if grep -q '^query.port=' "$PROP_FILE"; then
      sed -i "s/^query.port=.*/query.port=${QUERY_PORT}/" "$PROP_FILE" || true
    else
      echo "query.port=${QUERY_PORT}" >> "$PROP_FILE"
    fi
  fi

  # Other common properties
  if grep -q '^online-mode=' "$PROP_FILE"; then
    sed -i "s/^online-mode=.*/online-mode=${ONLINE_MODE}/" "$PROP_FILE" || true
  else
    echo "online-mode=${ONLINE_MODE}" >> "$PROP_FILE"
  fi
  if grep -q '^max-players=' "$PROP_FILE"; then
    sed -i "s/^max-players=.*/max-players=${MAX_PLAYERS}/" "$PROP_FILE" || true
  else
    echo "max-players=${MAX_PLAYERS}" >> "$PROP_FILE"
  fi
  if grep -q '^motd=' "$PROP_FILE"; then
    sed -i "s/^motd=.*/motd=${MOTD}/" "$PROP_FILE" || true
  else
    echo "motd=${MOTD}" >> "$PROP_FILE"
  fi
fi

# Memory/JVM args via user_jvm_args.txt (NeoForge/Forge convention)
USER_JVM_FILE="$DATA_DIR/user_jvm_args.txt"
touch "$USER_JVM_FILE"
if grep -q '^-Xms' "$USER_JVM_FILE"; then
  sed -i "s/^-Xms.*/-Xms${JVM_MIN_MEMORY}/" "$USER_JVM_FILE" || true
else
  echo "-Xms${JVM_MIN_MEMORY}" >> "$USER_JVM_FILE"
fi
if grep -q '^-Xmx' "$USER_JVM_FILE"; then
  sed -i "s/^-Xmx.*/-Xmx${JVM_MAX_MEMORY}/" "$USER_JVM_FILE" || true
else
  echo "-Xmx${JVM_MAX_MEMORY}" >> "$USER_JVM_FILE"
fi
if [ -n "$JVM_OPTS" ]; then
  # Append custom opts if not already present
  if ! grep -q "$JVM_OPTS" "$USER_JVM_FILE"; then
    echo "$JVM_OPTS" >> "$USER_JVM_FILE"
  fi
fi

# Ops handling
if [ -n "$DEFAULT_OPS" ]; then
  echo "$DEFAULT_OPS" | tr ',' '\n' > "$DATA_DIR/ops.txt"
fi

# Update workflow: when UPDATE_ON_START=true, perform dual backups then wipe selected dirs
if [ "${UPDATE_ON_START,,}" = "true" ]; then
  timestamp=$(date +%Y%m%d_%H%M%S)
  # 1) Full backup (first)
  full_archive="$BACKUP_DIR/server_full_${timestamp}.tar.gz"
  echo "Creating FULL backup before update: $full_archive"
  tar -czf "$full_archive" --exclude="$BACKUP_DIR" -C "$DATA_DIR" . || echo "Full backup failed (continuing)."

  # 2) Backup only the directories that will be wiped
  delete_archive="$BACKUP_DIR/server_wipe_set_${timestamp}.tar.gz"
  echo "Creating WIPE-SET backup before update: $delete_archive"
  (
    cd "$DATA_DIR"
    # Only include existing targets
    include_list=()
    for dir in $WIPE_DIRS; do
      if [ -e "$dir" ]; then include_list+=("$dir"); fi
    done
    if [ ${#include_list[@]} -gt 0 ]; then
      tar -czf "$delete_archive" "${include_list[@]}"
    else
      echo "No matching directories from WIPE_DIRS to backup."
    fi
  ) || echo "Wipe-set backup failed (continuing)."

  # 3) Wipe selected directories
  for dir in $WIPE_DIRS; do
    target="$DATA_DIR/$dir"
    if [ -d "$target" ]; then
      echo "Deleting directory for update: $target"
      rm -rf "$target"
    fi
  done

  # 4) If a pack zip was fetched above, re-unpack over data now
  if [ -n "$SERVER_PACK_URL" ]; then
    echo "Re-applying pack contents after wipe"
    tmpzip="/tmp/pack.zip"
    wget -O "$tmpzip" "$SERVER_PACK_URL"
    unzip -o -q "$tmpzip" -d "$DATA_DIR"
    rm -f "$tmpzip"
  fi

  # Config directory handling
  if [ "${WIPE_CONFIG,,}" = "true" ]; then
    if [ -d "$DATA_DIR/config" ]; then
      echo "WIPE_CONFIG=true -> Deleting $DATA_DIR/config"
      rm -rf "$DATA_DIR/config"
    fi
  else
    echo "Preserving $DATA_DIR/config to keep administrator settings."
  fi
fi

# If not updating now, still honor config preservation message for clarity
if [ "${UPDATE_ON_START,,}" != "true" ]; then
  if [ "${WIPE_CONFIG,,}" = "true" ]; then
    if [ -d "$DATA_DIR/config" ]; then
      echo "WIPE_CONFIG=true -> Deleting $DATA_DIR/config"
      rm -rf "$DATA_DIR/config"
    fi
  else
    echo "Preserving $DATA_DIR/config to keep administrator settings."
  fi
fi

cd "$DATA_DIR"

# Determine launch command (prefer ATM/NeoForge start scripts)
LAUNCH_CMD=""
if [ -f "startserver.sh" ]; then
  LAUNCH_CMD="bash ./startserver.sh"
elif [ -f "run.sh" ]; then
  LAUNCH_CMD="bash ./run.sh"
elif [ -f "start.sh" ]; then
  LAUNCH_CMD="bash ./start.sh"
else
  # Fallback: try to find a forge/fabric/neoforge jar
  SERVER_JAR=$(ls -1 *.jar 2>/dev/null | head -n1 || true)
  if [ -n "$SERVER_JAR" ]; then
    LAUNCH_CMD="java -Xms${JVM_MIN_MEMORY} -Xmx${JVM_MAX_MEMORY} ${JVM_OPTS} -jar \"$SERVER_JAR\" nogui"
  fi
fi

if [ -z "$LAUNCH_CMD" ]; then
  echo "No server start script or jar found. Exiting."
  exit 1
fi

echo "Starting server with command: $LAUNCH_CMD"

# Run server under a coprocess so we can send a graceful 'stop' on signals
graceful_shutdown() {
  echo "Signal received -> requesting graceful shutdown (stop)"
  # Try to send 'stop' to the server's stdin
  if [ -n "${SERVER_COPROC_PID:-}" ] 2>/dev/null; then
    # shellcheck disable=SC2069
    { echo "stop"; sleep 1; } >&"${SERVER_COPROC[1]}" || true
  fi
  # Give it time to flush and exit
  timeout_sec=60
  for i in $(seq 1 $timeout_sec); do
    if ! kill -0 "$SERVER_COPROC_PID" 2>/dev/null; then
      echo "Server process exited gracefully."
      return 0
    fi
    sleep 1
  done
  echo "Grace period exceeded; sending TERM"
  kill -TERM "$SERVER_COPROC_PID" 2>/dev/null || true
  sleep 5
  if kill -0 "$SERVER_COPROC_PID" 2>/dev/null; then
    echo "Still running; sending KILL"
    kill -KILL "$SERVER_COPROC_PID" 2>/dev/null || true
  fi
}

trap graceful_shutdown SIGTERM SIGINT

# Start the server
coproc SERVER_COPROC { bash -lc "$LAUNCH_CMD"; }
SERVER_COPROC_PID=$!

# Forward server stdout/stderr (already inherited), wait until it exits
wait "$SERVER_COPROC_PID"


