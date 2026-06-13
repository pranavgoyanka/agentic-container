# Claude Code Docker Environment

A minimal Ubuntu container whose sole purpose is running Claude Code against a single mounted project folder. Claude can only see the folder you give it — nothing else on your Mac.

---

## How it works

The container runs `claude` as its entrypoint. On `docker start`, Claude Code launches immediately inside an isolated Ubuntu environment. The only directory it can read or write is the project folder you specify in `.env`, mounted at `/workspace`.

```
your Mac                          container
─────────────────────────────     ──────────────────────────
$WORKSPACE_BASE/$WORKSPACE_FOLDER ──▶ /workspace/$WORKSPACE_FOLDER   (rw)
ubuntu-dev-home (Docker volume)   ──▶ /home/dev    (rw, persists ~/.claude)
everything else                        (not mounted, not visible)
```

**What Claude can do:**
- Read and write files in `/workspace`
- Make outbound network calls to Anthropic's API (`api.anthropic.com`)
- Run shell commands, git, compilers, and other tools installed in the image

**What Claude cannot do:**
- Access any other folder on your Mac
- Reach the Docker daemon (`/var/run/docker.sock` is not mounted)
- Escalate to macOS host root (container root ≠ Mac root)

> **Note on network access:** Claude Code needs outbound HTTPS to function — all inference happens on Anthropic's servers. The container cannot be air-gapped without breaking Claude Code entirely.

---

## Project structure

```
claude-code-docker/
├── .env             # Your local config — not committed
├── .env.example     # Committed template
├── Dockerfile
├── scripts/
│   ├── build.sh
│   ├── create.sh
│   ├── start.sh
│   ├── stop.sh
│   └── destroy.sh
└── README.md
```

---

## Configuration

### `.env.example`

```bash
# Copy this file to .env and fill in your values.
# .env is never committed to version control.

# The name of the project folder to mount inside the container.
# Only this folder will be accessible to Claude.
# Example: if your project is at ~/projects/my-app
# set WORKSPACE_FOLDER=my-app
WORKSPACE_FOLDER=

# The parent directory on your Mac that contains your projects.
WORKSPACE_BASE=~/projects
```

### `.env`

```bash
WORKSPACE_FOLDER=my-app
WORKSPACE_BASE=~/projects
```

### `.gitignore`

```
.env
```

---

## Dockerfile

```dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 20 LTS and essential dev tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    build-essential \
    python3 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -s /bin/bash dev \
    && mkdir -p /workspace

# Install Claude Code globally
# WORKDIR /tmp prevents the installer from scanning the entire filesystem
WORKDIR /tmp
RUN npm install -g @anthropic-ai/claude-code

USER dev
WORKDIR /workspace

ENTRYPOINT ["claude"]
```

---

## Scripts

Make all scripts executable:

```bash
chmod +x scripts/*.sh
```

### `scripts/build.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker build -t claude-code-docker "$REPO_ROOT"
```

### `scripts/create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE not found."
    echo "Copy .env.example to .env and set WORKSPACE_FOLDER."
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${WORKSPACE_FOLDER:-}" ]]; then
    echo "Error: WORKSPACE_FOLDER is not set in $ENV_FILE."
    exit 1
fi

WORKSPACE_BASE="${WORKSPACE_BASE:-~/projects}"
WORKSPACE_HOST="${WORKSPACE_BASE}/${WORKSPACE_FOLDER}"

if [[ ! -d "$WORKSPACE_HOST" ]]; then
    echo "Error: Folder not found on host: $WORKSPACE_HOST"
    echo "Check WORKSPACE_BASE and WORKSPACE_FOLDER in $ENV_FILE."
    exit 1
fi

VOLUME_NAME="claude-code-home"
CONTAINER_NAME="claude-code"

# Create the persistent home volume if it does not already exist.
# This is where Claude stores ~/.claude (settings, auth, project context).
if ! docker volume inspect "$VOLUME_NAME" > /dev/null 2>&1; then
    echo "Creating Docker volume: $VOLUME_NAME"
    docker volume create "$VOLUME_NAME"
else
    echo "Volume $VOLUME_NAME already exists, skipping."
fi

WORKSPACE_CONTAINER="/workspace/${WORKSPACE_FOLDER}"

echo "Workspace: $WORKSPACE_HOST -> $WORKSPACE_CONTAINER"

docker create \
    --name "$CONTAINER_NAME" \
    --interactive \
    --tty \
    --user dev \
    --workdir "$WORKSPACE_CONTAINER" \
    --volume "${VOLUME_NAME}:/home/dev" \
    --volume "${WORKSPACE_HOST}:${WORKSPACE_CONTAINER}" \
    claude-code-docker

echo ""
echo "Container '$CONTAINER_NAME' created."
echo "Run ./scripts/start.sh to launch Claude Code."
```

### `scripts/start.sh`

Starts the container and attaches to the Claude Code session.

```bash
#!/usr/bin/env bash
set -euo pipefail

docker start --attach --interactive claude-code
```

### `scripts/stop.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

docker stop claude-code
```

### `scripts/destroy.sh`

Removes the container but preserves the home volume (auth and Claude settings).

```bash
#!/usr/bin/env bash
set -euo pipefail

docker rm -f claude-code
echo "Container removed. Volume 'claude-code-home' preserved."
echo "Run ./scripts/create.sh then ./scripts/start.sh to recreate."
```

---

## Daily workflow

### First-time setup

```bash
cp .env.example .env
# Edit .env — set WORKSPACE_FOLDER to your project folder name

./scripts/build.sh
./scripts/create.sh
./scripts/start.sh    # Claude Code launches immediately
```

On first launch Claude Code will walk you through OAuth authentication with your Anthropic account. Auth credentials are saved to `/home/dev/.claude/` inside the persistent home volume, so you only do this once.

### Normal usage

```bash
./scripts/start.sh    # Launches directly into Claude Code
```

### Switching to a different project

```bash
./scripts/stop.sh
./scripts/destroy.sh

# Edit .env — change WORKSPACE_FOLDER to the new project
./scripts/create.sh
./scripts/start.sh
```

Your Claude auth and settings in the home volume carry over automatically.

### After changing the Dockerfile

```bash
./scripts/stop.sh
./scripts/destroy.sh
./scripts/build.sh
./scripts/create.sh
./scripts/start.sh
```

---

## Deleting the home volume

The home volume (`claude-code-home`) stores Claude's auth token, settings, and project memory. To wipe it:

```bash
./scripts/stop.sh
./scripts/destroy.sh
docker volume rm claude-code-home
```

The next `create.sh` will create a fresh volume and Claude Code will ask you to authenticate again.