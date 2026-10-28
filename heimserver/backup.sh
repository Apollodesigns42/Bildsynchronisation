#!/usr/bin/env bash
# Sichert Fotos + Datenbank vom Mini-PC auf ein Ziel (Hetzner Storage Box, USB-Festplatte …).
#
# Verwendung:  ./backup.sh storagebox:immich          # Storage Box (Eintrag in ~/.ssh/config, siehe README)
#              ./backup.sh /mnt/usb-platte/immich      # USB-Festplatte
#              BWLIMIT=1500 ./backup.sh storagebox:immich   # Upload auf 1500 KB/s begrenzen
#
# Immich legt selbst täglich Datenbank-Dumps unter $UPLOAD_LOCATION/backups an.
# Dieses Skript erstellt zusätzlich einen aktuellen Dump und spiegelt alles per rsync.
set -euo pipefail
cd "$(dirname "$0")"

target=${1:?"Ziel angeben, z.B. ./backup.sh storagebox:immich"}
set -a; source .env; set +a

dump="$UPLOAD_LOCATION/backups/manual-$(date +%Y%m%d-%H%M%S).sql.gz"
mkdir -p "$UPLOAD_LOCATION/backups"
echo "Erstelle Datenbank-Dump: $dump"
docker exec immich_postgres pg_dumpall --clean --if-exists --username="$DB_USERNAME" | gzip > "$dump"

# Nur die letzten 5 manuellen Dumps behalten
ls -1t "$UPLOAD_LOCATION"/backups/manual-*.sql.gz 2>/dev/null | tail -n +6 | xargs -r rm --

# Thumbnails und transkodierte Videos lassen sich neu erzeugen und werden nicht gesichert.
echo "Synchronisiere nach $target ..."
rsync -a --info=progress2 ${BWLIMIT:+--bwlimit="$BWLIMIT"} \
  --exclude 'thumbs/' --exclude 'encoded-video/' \
  "$UPLOAD_LOCATION"/ "$target"/

echo "Backup abgeschlossen."
