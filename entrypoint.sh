#!/usr/bin/env bash
set -euo pipefail

# Env vars
SERVER_HOME=${SERVER_HOME:-/opt/server-dist}
DATA_DIR=${DATA_DIR:-/data}
BACKUP_DIR=${BACKUP_DIR:-/data/backups}
SERVER_PACK_URL=${SERVER_PACK_URL:-}

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

export TZ

mkdir -p "$DATA_DIR" "$BACKUP_DIR"

# If there is existing data, create an automatic backup on startup
if [ -f "$DATA_DIR/server.properties" ] || [ -d "$DATA_DIR/world" ]; then
  timestamp=$(date +%Y%m%d_%H%M%S)
  archive="$BACKUP_DIR/server_backup_${timestamp}.tar.gz"
  echo "Existing data detected in $DATA_DIR. Creating backup: $archive"
  tar -czf "$archive" -C "$DATA_DIR" . || echo "Backup failed (continuing)."
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

# If URL is provided and no pack present, download into DATA_DIR
if [ -n "$SERVER_PACK_URL" ] && [ ! -f "$DATA_DIR/startserver.sh" ]; then
  echo "Downloading server pack into data dir from $SERVER_PACK_URL"
  tmpzip="/tmp/pack.zip"
  wget -O "$tmpzip" "$SERVER_PACK_URL"
  unzip -q "$tmpzip" -d "$DATA_DIR"
  rm -f "$tmpzip"
fi

# Make sure start scripts are executable
if [ -f "$DATA_DIR/startserver.sh" ]; then chmod +x "$DATA_DIR/startserver.sh"; fi
if [ -f "$DATA_DIR/start.sh" ]; then chmod +x "$DATA_DIR/start.sh"; fi

# EULA handling
if [ "${EULA,,}" = "true" ]; then
  echo "eula=true" > "$DATA_DIR/eula.txt"
fi

# Configure RCON/server.properties defaults if present
PROP_FILE="$DATA_DIR/server.properties"
if [ -f "$PROP_FILE" ]; then
  if [ "${ENABLE_RCON,,}" = "true" ]; then
    sed -i "s/^enable-rcon=.*/enable-rcon=true/" "$PROP_FILE" || true
    sed -i "s/^rcon.port=.*/rcon.port=${RCON_PORT}/" "$PROP_FILE" || true
    if [ -n "$RCON_PASSWORD" ]; then
      sed -i "s/^rcon.password=.*/rcon.password=${RCON_PASSWORD}/" "$PROP_FILE" || true
    fi
  fi
  sed -i "s/^server-port=.*/server-port=${SERVER_PORT}/" "$PROP_FILE" || true
fi

# Ops handling
if [ -n "$DEFAULT_OPS" ]; then
  echo "$DEFAULT_OPS" | tr ',' '\n' > "$DATA_DIR/ops.txt"
fi

# Update workflow: remove selected directories to allow new pack content to replace them
for dir in $WIPE_DIRS; do
  target="$DATA_DIR/$dir"
  if [ -d "$target" ]; then
    echo "Deleting directory for update: $target"
    rm -rf "$target"
  fi
done

# Config directory is preserved by default to retain admin-made changes
if [ "${WIPE_CONFIG,,}" = "true" ]; then
  if [ -d "$DATA_DIR/config" ]; then
    echo "WIPE_CONFIG=true -> Deleting $DATA_DIR/config"
    rm -rf "$DATA_DIR/config"
  fi
else
  echo "Preserving $DATA_DIR/config to keep administrator settings."
fi

cd "$DATA_DIR"

# Determine launch command
LAUNCH_CMD=""
if [ -f "startserver.sh" ]; then
  LAUNCH_CMD="bash ./startserver.sh"
elif [ -f "run.sh" ]; then
  LAUNCH_CMD="bash ./run.sh"
else
  # Fallback: try to find a forge/fabric jar
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
exec bash -lc "$LAUNCH_CMD"


