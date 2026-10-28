#!/usr/bin/env bash
# Aktualisiert Immich (innerhalb von IMMICH_VERSION) und – falls eingerichtet – OpenCloud
# (innerhalb von OC_VERSION). Vor großen Versionssprüngen die Release Notes lesen:
#   https://github.com/immich-app/immich/releases
#   https://docs.opencloud.eu/opencloud_release_notes.html
set -euo pipefail
cd "$(dirname "$0")"
docker compose pull
docker compose up -d
if [[ -f cloud/.env ]]; then
  (cd cloud && docker compose pull && docker compose up -d)
fi
docker image prune -f
