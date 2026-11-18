#!/usr/bin/env bash
# Gesundheits-Check für den Heimserver. Schickt eine E-Mail, wenn etwas nicht stimmt.
# Prüft: SSDs und Festplatten (SMART, Temperatur), Prozessor-Temperatur, automatische Updates, letztes Backup, Speicherplatz, Docker-Container, WireGuard-Tunnel,
# Werbefilter (FritzBox → AdGuard) und ob die Dienste aus dem Internet erreichbar sind. Als root ausführen.
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

# --- 1. Datenträger (SMART) ------------------------------------------------------
# --scan-open erkennt SATA-Platten korrekt als "sat" (mit --scan wären es "scsi" ohne SMART-Werte).
if command -v smartctl >/dev/null 2>&1; then
  while read -r dev _ type _; do
    [[ -n "$dev" && "$dev" != \#* ]] || continue
    out=$(smartctl -H -A -d "$type" "$dev" 2>&1); rc=$?
    ident=$(smartctl -i -d "$type" "$dev" 2>/dev/null)
    model=$(awk -F: '/Model Number|Device Model|Product:/ {gsub(/^ +/,"",$2); print $2; exit}' <<<"$ident")
    rpm=$(awk -F: '/Rotation Rate/ {gsub(/^ +/,"",$2); print $2; exit}' <<<"$ident")
    if [[ -n "$rpm" && "$rpm" != *Solid* ]]; then kind="Festplatte"; else kind="SSD"; fi
    name="$dev${model:+ ($model)}"
    before=${#problems[@]}
    # Exit-Code-Bits von smartctl: 8 = Platte meldet Ausfall, 16 = Grenzwert unterschritten
    if (( rc & 8 )) || (( rc & 16 )) || grep -qiE 'result: FAILED|FAILING_NOW' <<<"$out"; then
      problem "$kind $name meldet einen drohenden Ausfall! Daten sichern und $kind tauschen."
    fi
    # Wichtige Einzelwerte
    realloc=$(awk '$2 ~ /^(Reallocated_Sector_Ct|Reallocated_Event_Count)$/ {s+=$10} END {print s+0}' <<<"$out")
    pending=$(awk '$2 ~ /^(Current_Pending_Sector|Offline_Uncorrectable)$/ {s+=$10} END {print s+0}' <<<"$out")
    used=$(awk -F: '/Percentage Used/ {gsub(/[ %]/,"",$2); print $2}' <<<"$out")
    media=$(awk -F: '/Media and Data Integrity Errors/ {gsub(/[ ,]/,"",$2); print $2}' <<<"$out")
    hours=$(awk '$2 == "Power_On_Hours" {print $10+0; exit} /Power On Hours/ {gsub(/[^0-9]/,"",$0); print $0+0; exit}' <<<"$out")
    temp=$(awk '$2 ~ /^(Temperature_Celsius|Airflow_Temperature_Cel)$/ {print $10+0; exit} /^Temperature:/ {print $2+0; exit}' <<<"$out")
    if [[ "$kind" == Festplatte ]]; then tmax=${HDD_TEMP_WARN:-55}; else tmax=${SSD_TEMP_WARN:-70}; fi
    [[ -n "$temp" ]] && (( temp >= tmax )) && problem "$kind $name ist $temp °C warm (Grenze $tmax °C) – Belüftung prüfen."
    (( realloc > 0 )) && problem "$kind $name: $realloc ersetzte Sektoren – Zustand beobachten."
    (( pending > 0 )) && problem "$kind $name: $pending nicht lesbare Sektoren."
    [[ -n "$used" ]] && (( used >= 80 )) && problem "$kind $name: zu $used % abgenutzt."
    [[ -n "$media" ]] && (( media > 0 )) && problem "$kind $name: $media Datenfehler."
    detail=""
    [[ -n "$used" ]] && detail+=", $used % abgenutzt"
    [[ "$kind" == Festplatte ]] && grep -q Reallocated_Sector_Ct <<<"$out" && detail+=", keine defekten Sektoren"
    [[ -n "$hours" ]] && (( hours > 0 )) && detail+=", $(( hours / 24 )) Tage in Betrieb"
    [[ -n "$temp" ]] && (( temp > 0 )) && detail+=", $temp °C"
    (( ${#problems[@]} == before )) && info "$kind $name: ok$detail"
  done < <(smartctl --scan-open)
else
  problem "smartmontools fehlt – SSDs werden nicht geprüft (sudo apt install smartmontools)."
fi

# --- 1b. Prozessor-Temperatur ---------------------------------------------------------
cpu_temp=""
for h in /sys/class/hwmon/hwmon*; do
  case $(cat "$h/name" 2>/dev/null) in coretemp|k10temp|zenpower)
    cpu_temp=$(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 )); break ;;
  esac
done
if [[ -z "$cpu_temp" || "$cpu_temp" == 0 ]]; then
  for z in /sys/class/thermal/thermal_zone*; do
    [[ $(cat "$z/type" 2>/dev/null) == x86_pkg_temp ]] && cpu_temp=$(( $(cat "$z/temp") / 1000 )) && break
  done
fi
if [[ -n "$cpu_temp" && "$cpu_temp" != 0 ]]; then
  if (( cpu_temp >= ${CPU_TEMP_WARN:-85} )); then
    problem "Prozessor ist $cpu_temp °C warm (Grenze ${CPU_TEMP_WARN:-85} °C) – Lüftung/Staub prüfen."
  else
    info "Prozessor: $cpu_temp °C"
  fi
fi

# --- 1c. Automatische Updates (auto-update.sh) ----------------------------------------
if [[ -f /var/lib/heimserver/update-ok ]]; then
  up_d=$(( ($(date +%s) - $(cat /var/lib/heimserver/update-ok)) / 86400 ))
  if (( up_d > ${UPDATE_MAX_AGE_DAYS:-10} )); then
    problem "Automatische Updates seit $up_d Tagen nicht erfolgreich – Log: /var/log/heimserver-update.log"
  else
    info "Updates: zuletzt vor $up_d Tagen erfolgreich"
  fi
fi
[[ -f /var/run/reboot-required ]] && info "Neustart nach Updates ausstehend (erfolgt beim nächsten automatischen Update)"

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
[[ -f dokumente/.env ]] && paths+=("$(env_path dokumente/.env PAPERLESS_MEDIA_DIR)")
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
if [[ -f dokumente/.env ]]; then
  containers+=(paperless paperless_db paperless_broker)
  profiles=$(set -a; source dokumente/.env; echo "${COMPOSE_PROFILES:-}")
  [[ $profiles == *scanner* ]] && containers+=(scanservjs)
  [[ $profiles == *office* ]] && containers+=(paperless_tika paperless_gotenberg)
fi
[[ -f rezepte/.env ]] && containers+=(mealie)
[[ -f adguard/.env ]] && containers+=(adguard)
[[ -f passwoerter/.env ]] && containers+=(vaultwarden)
[[ -f smarthome/.env ]] && containers+=(homeassistant)
[[ -f startseite/.env ]] && containers+=(homepage)
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

# --- 5b. Werbefilter: leitet die FritzBox wirklich an AdGuard weiter? -------------
# Die FritzBox wechselt bei kurzen Aussetzern von AdGuard auf den alternativen DNS-Server
# (z.B. Quad9) und bleibt dort – dann ist der Filter unbemerkt aus. Test über den normalen
# Weg (Mini-PC → FritzBox → AdGuard): Eine bekannte Werbeadresse darf nicht auf eine echte
# Adresse führen. Die FritzBox verwirft die Sperr-Antwort 0.0.0.0 (DNS-Rebind-Schutz), daher
# zählt auch „keine Antwort“ als gesperrt – sofern eine normale Adresse aufgelöst wird.
if [[ -f adguard/.env ]]; then
  test_domain=${ADGUARD_TEST_DOMAIN:-googleads.g.doubleclick.net}
  control_domain=${ADGUARD_CONTROL_DOMAIN:-www.wikipedia.org}
  resolvectl flush-caches >/dev/null 2>&1 || true
  ad=$(getent ahostsv4 "$test_domain" 2>/dev/null | awk 'NR == 1 {print $1}')
  normal=$(getent ahostsv4 "$control_domain" 2>/dev/null | awk 'NR == 1 {print $1}')
  if [[ -z "$normal" ]]; then
    problem "DNS im Heimnetz gestört: Selbst $control_domain lässt sich nicht auflösen."
  elif [[ -n "$ad" && "$ad" != "0.0.0.0" ]]; then
    msg="Werbefilter ist aus: Die FritzBox nutzt nicht AdGuard (vermutlich auf dem alternativen DNS-Server hängen geblieben). Abhilfe: FritzBox neu starten; danach im Online-Monitor prüfen, dass ein AdGuard-Server „aktuell genutzt“ wird."
    if [[ ${ADGUARD_FILTER_WARN:-1} == 1 ]]; then problem "$msg"; else info "Werbefilter: aus (FritzBox nutzt den alternativen DNS-Server)"; fi
  else
    info "Werbefilter: aktiv (FritzBox leitet an AdGuard weiter)"
  fi
fi

# --- 6. Erreichbarkeit aus dem Internet --------------------------------------------
urls=()
[[ -n "${PHOTOS_URL:-}" ]] && urls+=("${PHOTOS_URL%/}/api/server/ping")
[[ -f cloud/.env ]] && urls+=("https://$(set -a; source cloud/.env; echo "$OC_DOMAIN")/")
[[ -f dokumente/.env ]] && urls+=("https://$(set -a; source dokumente/.env; echo "$PAPERLESS_DOMAIN")/")
[[ -f rezepte/.env ]] && urls+=("https://$(set -a; source rezepte/.env; echo "$MEALIE_DOMAIN")/")
[[ -f passwoerter/.env ]] && urls+=("https://$(set -a; source passwoerter/.env; echo "$VAULTWARDEN_DOMAIN")/alive")
ha_domain=$( [[ -f smarthome/.env ]] && (set -a; source smarthome/.env; echo "${HA_DOMAIN:-}") || true)
[[ -z "$ha_domain" ]] || urls+=("https://$ha_domain/")
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
