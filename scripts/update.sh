#!/usr/bin/env bash
# Aktualisiert Immich auf die neueste Version innerhalb von IMMICH_VERSION (siehe .env).
# Vor großen Versionssprüngen die Release Notes lesen: https://github.com/immich-app/immich/releases
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose pull
docker compose up -d
docker image prune -f
