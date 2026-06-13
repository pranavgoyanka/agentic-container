#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker build -t claude-code-docker "$REPO_ROOT"

