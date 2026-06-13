#!/usr/bin/env bash
set -euo pipefail

docker exec -it -u dev -w "/workspace" claude-code bash
