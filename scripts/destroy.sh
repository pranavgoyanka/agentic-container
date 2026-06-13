#!/usr/bin/env bash
set -euo pipefail

docker rm -f claude-code
echo "Container removed. Volume 'claude-code-home' preserved."
echo "Run ./scripts/create.sh then ./scripts/start.sh to recreate."
