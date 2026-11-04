#!/usr/bin/env bash
# Aktualisiert Immich (innerhalb von IMMICH_VERSION) und – falls eingerichtet – OpenCloud
# (innerhalb von OC_VERSION), Paperless-ngx und Mealie (feste Version MEALIE_VERSION in rezepte/.env). Vor großen Versionssprüngen die Release Notes lesen:
#   https://github.com/immich-app/immich/releases
#   https://docs.opencloud.eu/opencloud_release_notes.html
set -euo pipefail
cd "$(dirname "$0")"
docker compose pull
docker compose up -d
for dir in cloud dokumente rezepte; do
  if [[ -f $dir/.env ]]; then
    (cd "$dir" && docker compose pull && docker compose up -d)
  fi
done
docker image prune -f
