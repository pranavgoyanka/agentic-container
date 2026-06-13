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

WORKSPACE_BASE="${WORKSPACE_BASE:-/Users/pranav/Lemon/Code}"
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
