#!/usr/bin/env bash
# Automatische Updates für den Heimserver – wöchentlich per cron, als root.
#  1. Ubuntu-Pakete (alle, nicht nur Sicherheitsupdates)
#  2. Container (wie ./update.sh: Immich innerhalb von IMMICH_VERSION, Mealie nur mit fester Version usw.)
#  3. Neustart, falls ein Update ihn verlangt – aber nie während eines Backups
# Das Ergebnis prüft der tägliche Check (check.sh) und meldet sich, wenn Updates länger scheitern.
#
# Verwendung:  sudo ./auto-update.sh                # Updates einspielen, ggf. neu starten
#              sudo ./auto-update.sh ohne-neustart  # Updates einspielen, nicht neu starten
set -uo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }
status=/var/lib/heimserver
mkdir -p "$status"
log() { echo "== $(date '+%F %T') $*"; }

backup_laeuft() { pgrep -x restic >/dev/null || pgrep -f 'heimserver/backup.sh' >/dev/null; }

if backup_laeuft; then
  log "Backup läuft gerade – Updates fallen diese Woche aus."
  exit 0
fi

fehler=0

log "Ubuntu-Pakete"
export DEBIAN_FRONTEND=noninteractive
apt=(apt-get -q -y -o DPkg::Lock::Timeout=600
     -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
"${apt[@]}" update || fehler=1
"${apt[@]}" full-upgrade || fehler=1
"${apt[@]}" autoremove --purge || true

log "Container"
./update.sh || fehler=1

if (( fehler == 0 )); then
  date +%s > "$status/update-ok"
  log "Updates erfolgreich."
else
  log "Mindestens ein Update ist fehlgeschlagen – siehe oben."
fi

if [[ -f /var/run/reboot-required && ${1:-} != ohne-neustart ]]; then
  if backup_laeuft; then
    log "Neustart nötig, aber ein Backup läuft – Neustart beim nächsten Mal."
  else
    log "Neustart wegen: $(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null)"
    sync
    systemctl reboot
  fi
fi
