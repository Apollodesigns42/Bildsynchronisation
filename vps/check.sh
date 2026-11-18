#!/usr/bin/env bash
# Gesundheits-Check für den VPS. Meldet sich per E-Mail und/oder ntfy-Push, wenn etwas nicht stimmt,
# und am OK_MAIL_WEEKDAY eine „Alles ok“-Mail. Als root ausführen.
# Prüft: Speicherplatz, Arbeitsspeicher, Caddy, Burgenkampf, Uptime Kuma, WireGuard-Tunnel,
# automatische Sicherheitsupdates und ausstehende Neustarts.
#
# Verwendung:  ./check.sh          # prüfen, bei Problemen Mail senden (täglich per cron)
#              ./check.sh test     # Test-Mail senden
#              ./check.sh zeigen   # nur prüfen und anzeigen, keine Mail
#
# Einstellungen in check.env (Vorlage: check.env.example).
set -uo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte als root ausführen."; exit 1; }
[[ -f check.env ]] || { echo "check.env fehlt – check.env.example kopieren und ausfüllen."; exit 1; }
set -a; source check.env; set +a

mode=${1:-mail}
problems=()
infos=()
problem() { problems+=("$1"); }
info()    { infos+=("$1"); }

send_mail() {  # $1 = Betreff, $2 = Text
  local msg; msg=$(mktemp)
  {
    echo "From: VPS <$MAIL_FROM>"
    echo "To: $MAIL_TO"
    echo "Subject: =?UTF-8?B?$(printf '%s' "$1" | base64 -w0)?="
    echo "Date: $(LC_ALL=C date -R)"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo "Content-Transfer-Encoding: 8bit"
    echo
    printf '%s\n' "$2"
  } > "$msg"
  curl -sS --ssl-reqd --url "$SMTP_URL" --mail-from "$MAIL_FROM" --mail-rcpt "$MAIL_TO" \
       --upload-file "$msg" -K - <<<"user = \"$SMTP_USER:$SMTP_PASS\""
  local rc=$?
  rm -f "$msg"
  return $rc
}

# Push-Nachricht über ntfy (z.B. dasselbe Thema wie Uptime Kuma). $1 = Titel, $2 = Text, $3 = Priorität
send_push() {
  [[ -n "${NTFY_URL:-}" ]] || return 1
  curl -sS -m 20 -H "Title: $1" -H "Priority: ${3:-default}" -H "Tags: computer" \
       ${NTFY_TOKEN:+-H "Authorization: Bearer $NTFY_TOKEN"} -d "$2" "$NTFY_URL" >/dev/null
}

# Meldet über alle eingerichteten Wege (Mail und/oder ntfy)
melden() {  # $1 = Titel, $2 = Text, $3 = ntfy-Priorität
  local ok=1
  if [[ -n "${SMTP_USER:-}" && "${SMTP_USER}" != name@example.de ]]; then send_mail "$1" "$2" && ok=0; fi
  send_push "$1" "$2" "${3:-default}" && ok=0
  return $ok
}

if [[ $mode == test ]]; then
  if [[ -n "${SMTP_USER:-}" && "${SMTP_USER}" != name@example.de ]]; then
    send_mail "VPS: Test-Mail" "Der E-Mail-Versand von vps/check.sh funktioniert." \
      && echo "Test-Mail an $MAIL_TO gesendet." || echo "Mail-Versand fehlgeschlagen – SMTP-Daten in check.env prüfen."
  fi
  if [[ -n "${NTFY_URL:-}" ]]; then
    send_push "VPS: Test" "Push-Nachrichten von vps/check.sh funktionieren." \
      && echo "Test-Push an $NTFY_URL gesendet." || echo "Push fehlgeschlagen – NTFY_URL prüfen."
  fi
  exit 0
fi

# --- 1. Speicherplatz --------------------------------------------------------------
pct=$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if (( pct >= ${DISK_WARN_PERCENT:-85} )); then
  problem "Festplatte / ist zu $pct % voll."
else
  info "Speicher /: $pct % belegt"
fi

# --- 2. Arbeitsspeicher ------------------------------------------------------------
read -r total avail < <(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
free_pct=$(( avail * 100 / total ))
if (( free_pct < ${MEM_WARN_FREE_PERCENT:-10} )); then
  problem "Arbeitsspeicher knapp: nur noch $free_pct % frei."
else
  info "Arbeitsspeicher: $free_pct % frei"
fi

# --- 3. Dienste --------------------------------------------------------------------
if systemctl is-active --quiet caddy; then
  info "Caddy läuft"
else
  problem "Caddy läuft nicht (systemctl status caddy)."
fi

if [[ -n "${BURGENKAMPF_URL:-}" ]]; then
  code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$BURGENKAMPF_URL")
  if [[ $code == 000 ]]; then
    problem "Burgenkampf antwortet nicht ($BURGENKAMPF_URL)."
  else
    info "Burgenkampf antwortet"
  fi
fi

if command -v docker >/dev/null 2>&1; then
  state=$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' uptime-kuma 2>/dev/null)
  case $state in
    "running healthy"|"running "|"running starting") info "Uptime Kuma läuft" ;;
    "") ;;  # nicht installiert
    *) problem "Uptime Kuma: $state" ;;
  esac
fi

# --- 4. Tunnel zum Heimserver ------------------------------------------------------
if command -v wg >/dev/null 2>&1 && wg show wg-fotos >/dev/null 2>&1; then
  hs=$(wg show wg-fotos latest-handshakes | awk '{print $2; exit}')
  if [[ -z "$hs" || "$hs" == 0 ]]; then
    problem "WireGuard: noch nie Kontakt zum Heimserver."
  elif (( $(date +%s) - hs > 300 )); then
    problem "WireGuard: kein Kontakt zum Heimserver seit $(( ($(date +%s) - hs) / 60 )) Minuten (Heimserver aus oder Internet daheim weg?)."
  else
    info "Tunnel zum Heimserver: ok"
  fi
fi

# --- 5. Automatische Sicherheitsupdates --------------------------------------------
log=/var/log/unattended-upgrades/unattended-upgrades.log
if [[ -f $log ]]; then
  last=$(stat -c %Y "$log")
  days=$(( ($(date +%s) - last) / 86400 ))
  if (( days > 3 )); then
    problem "Automatische Sicherheitsupdates seit $days Tagen nicht gelaufen (systemctl status unattended-upgrades)."
  elif tail -n 50 "$log" | grep -q "ERROR"; then
    problem "Automatische Sicherheitsupdates melden Fehler – siehe $log."
  else
    info "Sicherheitsupdates: laufen"
  fi
else
  problem "Automatische Sicherheitsupdates sind nicht aktiv (sudo apt install unattended-upgrades)."
fi
if [[ -f /var/run/reboot-required ]]; then
  age=$(( ($(date +%s) - $(stat -c %Y /var/run/reboot-required)) / 86400 ))
  if (( age >= 3 )); then
    problem "Neustart nach Updates steht seit $age Tagen aus (automatischer Neustart eingerichtet?)."
  else
    info "Neustart nach Updates ausstehend (erfolgt nachts automatisch)"
  fi
fi

# --- Bericht -----------------------------------------------------------------------
report=""
if (( ${#problems[@]} )); then
  report+="PROBLEME:"$'\n'
  for p in "${problems[@]}"; do report+="  ✗ $p"$'\n'; done
  report+=$'\n'
fi
report+="In Ordnung:"$'\n'
for i in "${infos[@]}"; do report+="  ✓ $i"$'\n'; done
report+=$'\n'"Geprüft am $(TZ=Europe/Berlin date '+%d.%m.%Y %H:%M') auf $(hostname)."

if [[ $mode == zeigen ]]; then
  echo "$report"
elif (( ${#problems[@]} )); then
  melden "VPS: ${#problems[@]} Problem(e)" "$report" high
elif [[ -n "${OK_MAIL_WEEKDAY:-}" && $(date +%u) == "$OK_MAIL_WEEKDAY" ]]; then
  melden "VPS: alles in Ordnung" "$report" low
fi
(( ${#problems[@]} == 0 ))
