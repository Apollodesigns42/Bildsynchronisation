#!/usr/bin/env bash
# Verschlüsseltes, versioniertes Backup von Fotos (Immich) und Cloud (OpenCloud) mit restic,
# standardmäßig auf die Hetzner Storage Box. Als root ausführen.
#
# Verwendung:  sudo ./backup.sh init     # einmalig: Passwort erzeugen, Repository anlegen
#              sudo ./backup.sh          # Backup ausführen (z.B. nächtlich per cron)
#              sudo ./backup.sh status   # vorhandene Backup-Stände anzeigen
#
# Einstellungen in backup.env (Vorlage: backup.env.example).
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }
command -v restic >/dev/null 2>&1 || { echo "restic fehlt: sudo apt install restic"; exit 1; }
[[ -f backup.env ]] || { echo "backup.env fehlt – backup.env.example kopieren und anpassen."; exit 1; }

set -a; source backup.env; set +a
limit=(); [[ -z "${BWLIMIT:-}" ]] || limit=(--limit-upload "$BWLIMIT")

case ${1:-run} in
  init)
    if [[ ! -s $RESTIC_PASSWORD_FILE ]]; then
      # Ohne Pipe, sonst bricht "set -o pipefail" ab, wenn head die Pipe schließt
      pw=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 2000 /dev/urandom))
      (umask 077; printf '%s' "${pw:0:40}" > "$RESTIC_PASSWORD_FILE")
      echo "Backup-Passwort erzeugt: $(cat "$RESTIC_PASSWORD_FILE")"
      echo "→ JETZT im Passwortmanager speichern. Ohne dieses Passwort lässt sich nichts wiederherstellen."
    fi
    restic init
    exit 0 ;;
  status)
    restic snapshots
    exit 0 ;;
  run) ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

echo "== $(date '+%F %T') Backup startet"

# --- Fotos (Immich) ---
set -a; source .env; set +a
UPLOAD_LOCATION=$(realpath "$UPLOAD_LOCATION")
dump="$UPLOAD_LOCATION/backups/manual-$(date +%Y%m%d-%H%M%S).sql.gz"
mkdir -p "$UPLOAD_LOCATION/backups"
docker exec immich_postgres pg_dumpall --clean --if-exists --username="$DB_USERNAME" | gzip > "$dump"
ls -1t "$UPLOAD_LOCATION"/backups/manual-*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm --

# Vorschaubilder und umgewandelte Videos erzeugt Immich bei Bedarf neu.
restic backup "${limit[@]}" --tag immich \
  --exclude "$UPLOAD_LOCATION/thumbs" --exclude "$UPLOAD_LOCATION/encoded-video" \
  "$UPLOAD_LOCATION"

# --- Cloud (OpenCloud), falls eingerichtet ---
if [[ -f cloud/.env ]]; then
  (
    cd cloud
    set -a; source .env; set +a
    # Für ein stimmiges Backup wird OpenCloud kurz angehalten (nachts unkritisch).
    trap 'docker start opencloud >/dev/null' EXIT
    docker stop opencloud >/dev/null
    restic backup "${limit[@]}" --tag opencloud "$(realpath "$OC_CONFIG_DIR")" "$(realpath "$OC_DATA_DIR")"
  )
fi

# --- Alte Stände aufräumen (sonntags, das Aufräumen dauert etwas) ---
if [[ $(date +%u) == 7 ]]; then
  restic forget --prune --group-by tags \
    --keep-daily "${KEEP_DAILY:-7}" --keep-weekly "${KEEP_WEEKLY:-4}" --keep-monthly "${KEEP_MONTHLY:-12}"
  restic check
fi

echo "== $(date '+%F %T') Backup fertig"
