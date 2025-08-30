# minecraft-server-docker
Automatic creation and deployment of Minecraft servers containerized and with persistent data using Docker

## ATM10 server with persistence and auto-update

This setup builds an image from JDK 21, downloads an ATM10 server pack (URL provided via environment), persists all data under a Docker volume, and on each start performs an automatic backup and optional selective wipe of pack-managed directories to ease updates. The `config` directory is preserved by default to avoid losing admin changes; set `WIPE_CONFIG=true` to delete configs during an update.

### Files

- `Dockerfile`: Base image and tooling. Copies `entrypoint.sh` and sets it as entrypoint.
- `entrypoint.sh`: Startup logic, backups, optional pack download, EULA handling, ops, memory flags, update wipe.
- `docker-compose.yml`: Service definition, environment, volume, ports, restart policy.

### Environment variables

- `SERVER_PACK_URL` (required): Direct URL to the ATM10 server pack zip.
- `EULA` (default `false`): Set to `true` to auto-create `eula.txt`.
- `DEFAULT_OPS`: Comma-separated list of usernames or UUIDs to grant OP.
- `JVM_MIN_MEMORY` (default `2G`), `JVM_MAX_MEMORY` (default `6G`), `JVM_OPTS` for additional flags.
- `ENABLE_RCON` (default `true`), `RCON_PORT` (default `25575`), `RCON_PASSWORD`.
- `SERVER_PORT` (default `25565`), `TZ` (default `UTC`).
- `WIPE_DIRS` (default `"libraries mods packmenu kubejs defaultconfigs"`): Directories to delete on start to allow pack updates.
- `WIPE_CONFIG` (default `false`): If `true`, also deletes `config`.

### Build and run

1. Set `SERVER_PACK_URL` to the direct download URL of the ATM10 server pack zip.
2. Build the image:

```bash
docker compose build
```

3. Start the server:

```bash
docker compose up -d
```

Logs:

```bash
docker compose logs -f
```

### Quick scripts (Windows PowerShell)

- Run without rebuilding (attached logs):

```powershell
./Run-ATM10.ps1
```

- Build (if needed) and run detached:

```powershell
./BuildAndRun-ATM10.ps1
```

### Cross-platform scripts

- Windows (PowerShell):
  - Normal run: `./run-server.ps1`
  - Update run (rebuild): `./run-server-update.ps1`
- macOS/Linux (bash):
  - Normal run: `./run-server.sh`
  - Update run (rebuild): `./run-server-update.sh`

> IMPORTANT: The update scripts rebuild the Docker image and should be used ONLY when updating the server (e.g., changing `SERVER_PACK_URL` or Dockerfile). For daily use, run the normal scripts.

### Updating the server

- To update to a new pack version, update `SERVER_PACK_URL`, rebuild the image, and restart the container. On startup, directories listed in `WIPE_DIRS` are deleted, letting the new pack files take effect. `config` is preserved unless `WIPE_CONFIG=true`.
- An automatic timestamped backup of `/data` is created on each start under `/data/backups`.

### Notes on config deletion

Deleting the `config` folder will remove any admin-made configuration changes for mods and the server. Default behavior preserves `config` to avoid data loss. Only set `WIPE_CONFIG=true` if you explicitly want to reset configs to the new pack defaults.

## Installation

### Requirements

- Docker (Desktop on Windows/macOS, Engine on Linux)
  - Windows/macOS: see Docker Desktop install docs: [Docker Desktop](https://docs.docker.com/desktop/install/)
  - Linux: see Docker Engine install docs: [Docker Engine](https://docs.docker.com/engine/install/)
- Docker Compose v2 (included with recent Docker Desktop / Engine)
  - Verify: `docker compose version`

### Get this repository

- Using git:

```bash
git clone https://github.com/your-user/minecraft-server-docker.git
cd minecraft-server-docker
```

- Using wget:

```bash
wget https://github.com/your-user/minecraft-server-docker/archive/refs/heads/main.zip -O minecraft-server-docker.zip
unzip minecraft-server-docker.zip
cd minecraft-server-docker-*/
```

- Using browser (zip): download and extract to your preferred folder, then open a terminal in that folder.

### Configure storage location

This project stores server data in a Docker volume named `mc_data` by default, which Docker manages in its data root. If you prefer binding to a host folder, change the `volumes` section in `docker-compose.yml` like:

```yaml
    volumes:
      - ./data:/data
```

Then create the folder and ensure you have permissions to write to it.

### Configure environment

Create a `.env` file in the project root with your settings:

```ini
SERVER_PACK_URL=https://example.com/atm10-server.zip
EULA=true
DEFAULT_OPS=YourUserName
JVM_MIN_MEMORY=4G
JVM_MAX_MEMORY=8G
ENABLE_RCON=true
RCON_PASSWORD=some-strong-password
```

### Run the server

- With scripts (Windows PowerShell): `./BuildAndRun-ATM10.ps1` (detached) or `./Run-ATM10.ps1` (attached).
- Or manually: `docker compose up -d` then `docker compose logs -f`.