#!/usr/bin/env bash
# Sichert Fotos + Datenbank vom VPS auf ein Ziel (z.B. externe Festplatte, NAS, zweiter Server).
#
# Verwendung:  scripts/backup.sh /mnt/backup/immich
#              scripts/backup.sh user@backupserver:/backups/immich
#
# Immich legt selbst täglich Datenbank-Dumps unter $UPLOAD_LOCATION/backups an.
# Dieses Skript erstellt zusätzlich einen aktuellen Dump und spiegelt alles per rsync.
set -euo pipefail
cd "$(dirname "$0")/.."

target=${1:?"Ziel angeben, z.B. scripts/backup.sh /mnt/backup/immich"}
set -a; source .env; set +a

dump="$UPLOAD_LOCATION/backups/manual-$(date +%Y%m%d-%H%M%S).sql.gz"
mkdir -p "$UPLOAD_LOCATION/backups"
echo "Erstelle Datenbank-Dump: $dump"
docker exec immich_postgres pg_dumpall --clean --if-exists --username="$DB_USERNAME" | gzip > "$dump"

# Nur die letzten 5 manuellen Dumps behalten
ls -1t "$UPLOAD_LOCATION"/backups/manual-*.sql.gz 2>/dev/null | tail -n +6 | xargs -r rm --

# Thumbnails und transkodierte Videos lassen sich neu erzeugen und werden nicht gesichert.
echo "Synchronisiere nach $target ..."
rsync -a --info=progress2 \
  --exclude 'thumbs/' --exclude 'encoded-video/' \
  "$UPLOAD_LOCATION"/ "$target"/

echo "Backup abgeschlossen."
