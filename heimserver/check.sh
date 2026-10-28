#!/usr/bin/env bash
# Gesundheits-Check für den Heimserver. Schickt eine E-Mail, wenn etwas nicht stimmt.
# Prüft: SSDs (SMART), letztes Backup, Speicherplatz, Docker-Container, WireGuard-Tunnel
# und ob Fotos/Cloud aus dem Internet erreichbar sind. Als root ausführen.
#
# Verwendung:  sudo ./check.sh          # prüfen, bei Problemen Mail senden (täglich per cron)
#              sudo ./check.sh test     # Test-Mail senden
#              sudo ./check.sh zeigen   # nur prüfen und anzeigen, keine Mail
#
# Einstellungen in check.env (Vorlage: check.env.example).
set -uo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }
[[ -f check.env ]] || { echo "check.env fehlt – check.env.example kopieren und ausfüllen."; exit 1; }
set -a; source check.env; set +a

mode=${1:-mail}
problems=()   # führt zu einer Warn-Mail
infos=()      # steht nur im Bericht

problem() { problems+=("$1"); }
info()    { infos+=("$1"); }

send_mail() {  # $1 = Betreff, $2 = Text
  local msg; msg=$(mktemp)
  {
    echo "From: Heimserver <$MAIL_FROM>"
    echo "To: $MAIL_TO"
    echo "Subject: =?UTF-8?B?$(printf '%s' "$1" | base64 -w0)?="
    echo "Date: $(LC_ALL=C date -R)"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo "Content-Transfer-Encoding: 8bit"
    echo
    printf '%s\n' "$2"
  } > "$msg"
  # Zugangsdaten über stdin statt Kommandozeile, damit sie nicht in der Prozessliste stehen
  curl -sS --ssl-reqd --url "$SMTP_URL" --mail-from "$MAIL_FROM" --mail-rcpt "$MAIL_TO" \
       --upload-file "$msg" -K - <<<"user = \"$SMTP_USER:$SMTP_PASS\""
  local rc=$?
  rm -f "$msg"
  return $rc
}

if [[ $mode == test ]]; then
  send_mail "Heimserver: Test-Mail" "Der E-Mail-Versand von check.sh funktioniert." \
    && echo "Test-Mail an $MAIL_TO gesendet." || { echo "Versand fehlgeschlagen – SMTP-Daten in check.env prüfen."; exit 1; }
  exit 0
fi

# --- 1. SSDs (SMART) -------------------------------------------------------------
if command -v smartctl >/dev/null 2>&1; then
  while read -r dev _ type _; do
    [[ -n "$dev" ]] || continue
    out=$(smartctl -H -A -d "$type" "$dev" 2>&1); rc=$?
    model=$(smartctl -i -d "$type" "$dev" 2>/dev/null | awk -F: '/Model Number|Device Model/ {gsub(/^ +/,"",$2); print $2; exit}')
    name="$dev${model:+ ($model)}"
    before=${#problems[@]}
    # Exit-Code-Bits von smartctl: 8 = Platte meldet Ausfall, 16 = Grenzwert unterschritten
    if (( rc & 8 )) || (( rc & 16 )) || grep -qiE 'result: FAILED|FAILING_NOW' <<<"$out"; then
      problem "SSD $name meldet einen drohenden Ausfall! Daten sichern und SSD tauschen."
    fi
    # Wichtige Einzelwerte
    realloc=$(awk '$2 ~ /^(Reallocated_Sector_Ct|Reallocated_Event_Count)$/ {s+=$10} END {print s+0}' <<<"$out")
    pending=$(awk '$2 ~ /^(Current_Pending_Sector|Offline_Uncorrectable)$/ {s+=$10} END {print s+0}' <<<"$out")
    used=$(awk -F: '/Percentage Used/ {gsub(/[ %]/,"",$2); print $2}' <<<"$out")
    media=$(awk -F: '/Media and Data Integrity Errors/ {gsub(/[ ,]/,"",$2); print $2}' <<<"$out")
    (( realloc > 0 )) && problem "SSD $name: $realloc ersetzte Sektoren – Zustand beobachten."
    (( pending > 0 )) && problem "SSD $name: $pending nicht lesbare Sektoren."
    [[ -n "$used" ]] && (( used >= 80 )) && problem "SSD $name: zu $used % abgenutzt."
    [[ -n "$media" ]] && (( media > 0 )) && problem "SSD $name: $media Datenfehler."
    (( ${#problems[@]} == before )) && info "SSD $name: ok${used:+, $used % abgenutzt}"
  done < <(smartctl --scan)
else
  problem "smartmontools fehlt – SSDs werden nicht geprüft (sudo apt install smartmontools)."
fi

# --- 2. Letztes Backup -------------------------------------------------------------
if [[ -f backup.env ]]; then
  if [[ -f /var/lib/heimserver/backup-ok ]]; then
    age_h=$(( ($(date +%s) - $(cat /var/lib/heimserver/backup-ok)) / 3600 ))
    if (( age_h > ${BACKUP_MAX_AGE_HOURS:-30} )); then
      problem "Letztes erfolgreiches Backup vor $age_h Stunden – Log prüfen: /var/log/heimserver-backup.log"
    else
      info "Backup: zuletzt vor $age_h Stunden erfolgreich"
    fi
  else
    problem "Noch kein erfolgreiches Backup gelaufen."
  fi
else
  problem "Backup ist nicht eingerichtet (backup.env fehlt)."
fi

# --- 3. Speicherplatz --------------------------------------------------------------
# Liest eine Variable aus einer .env-Datei und macht den Pfad absolut (relativ zum Ordner der Datei)
env_path() { (cd "$(dirname "$1")" && set -a && source "$(basename "$1")" && realpath "${!2}") 2>/dev/null; }
paths=(/)
[[ -f .env ]] && paths+=("$(env_path .env UPLOAD_LOCATION)")
[[ -f cloud/.env ]] && paths+=("$(env_path cloud/.env OC_DATA_DIR)")
declare -A seen=()
for p in "${paths[@]}"; do
  [[ -n "$p" ]] || continue
  read -r fs pct mnt < <(df -P "$p" | awk 'NR==2 {print $1, $5, $6}')
  [[ -n "${seen[$fs]:-}" ]] && continue; seen[$fs]=1
  pct=${pct%\%}
  if (( pct >= ${DISK_WARN_PERCENT:-85} )); then
    problem "Festplatte $mnt ist zu $pct % voll."
  else
    info "Speicher $mnt: $pct % belegt"
  fi
done

# --- 4. Docker-Container -----------------------------------------------------------
containers=(immich_server immich_machine_learning immich_postgres immich_redis)
[[ -f cloud/.env ]] && containers+=(opencloud)
before=${#problems[@]}
for c in "${containers[@]}"; do
  state=$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c" 2>/dev/null) \
    || { problem "Container $c existiert nicht."; continue; }
  case $state in
    "running "|"running healthy") ;;
    "running starting") info "Container $c startet gerade" ;;
    *) problem "Container $c: $state" ;;
  esac
done
(( ${#problems[@]} == before )) && info "Container: alle ${#containers[@]} laufen"

# --- 5. WireGuard-Tunnel zum VPS ---------------------------------------------------
if [[ -f /etc/wireguard/wg-fotos.conf ]]; then
  hs=$(wg show wg-fotos latest-handshakes 2>/dev/null | awk '{print $2; exit}')
  if [[ -z "$hs" ]]; then
    problem "WireGuard-Tunnel ist nicht aktiv (sudo systemctl status wg-quick@wg-fotos)."
  elif (( $(date +%s) - hs > 300 )); then
    problem "WireGuard-Tunnel: kein Kontakt zum VPS seit $(( ($(date +%s) - hs) / 60 )) Minuten."
  else
    info "Tunnel zum VPS: ok"
  fi
fi

# --- 6. Erreichbarkeit aus dem Internet --------------------------------------------
urls=()
[[ -n "${PHOTOS_URL:-}" ]] && urls+=("${PHOTOS_URL%/}/api/server/ping")
[[ -f cloud/.env ]] && urls+=("https://$(set -a; source cloud/.env; echo "$OC_DOMAIN")/")
for u in "${urls[@]}"; do
  code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$u")
  if [[ $code =~ ^[23] ]]; then
    info "Erreichbar: $u"
  else
    problem "Nicht erreichbar von außen: $u (HTTP ${code:-keine Antwort}) – VPS/Webserver prüfen."
  fi
done

# --- Bericht -----------------------------------------------------------------------
report=""
if (( ${#problems[@]} )); then
  report+="PROBLEME:"$'\n'
  for p in "${problems[@]}"; do report+="  ✗ $p"$'\n'; done
  report+=$'\n'
fi
report+="In Ordnung:"$'\n'
for i in "${infos[@]}"; do report+="  ✓ $i"$'\n'; done
report+=$'\n'"Geprüft am $(date '+%d.%m.%Y %H:%M') auf $(hostname)."

if [[ $mode == zeigen ]]; then
  echo "$report"
elif (( ${#problems[@]} )); then
  send_mail "Heimserver: ${#problems[@]} Problem(e)" "$report"
elif [[ -n "${OK_MAIL_WEEKDAY:-}" && $(date +%u) == "$OK_MAIL_WEEKDAY" ]]; then
  send_mail "Heimserver: alles in Ordnung" "$report"
fi
(( ${#problems[@]} == 0 ))
