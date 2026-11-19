#!/usr/bin/env bash
# Status-Werte für die Startseite, alle 5 Minuten per cron (als root):
#  - startseite/status/werbefilter.json: leitet die FritzBox gerade wirklich an AdGuard weiter? (Kachel „Werbeblocker“)
#  - startseite/status/temperaturen.json: Prozessor, SSD und Festplatte (Kachel „Temperaturen“)
# Gleicher Test wie im täglichen Check: Eine Werbeadresse darf über den normalen Weg
# (Mini-PC → FritzBox → AdGuard) nicht auf eine echte Adresse führen.
set -uo pipefail
cd "$(dirname "$0")"
[[ -f check.env ]] && { set -a; source check.env; set +a; }
test_domain=${ADGUARD_TEST_DOMAIN:-googleads.g.doubleclick.net}
control_domain=${ADGUARD_CONTROL_DOMAIN:-www.wikipedia.org}

resolvectl flush-caches >/dev/null 2>&1 || true
ad=$(getent ahostsv4 "$test_domain" 2>/dev/null | awk 'NR == 1 {print $1}')
normal=$(getent ahostsv4 "$control_domain" 2>/dev/null | awk 'NR == 1 {print $1}')

if [[ -z "$normal" ]]; then
  status="DNS gestört"
elif [[ -n "$ad" && "$ad" != "0.0.0.0" ]]; then
  status="AUS – FritzBox nutzt Ersatz-DNS"
else
  status="aktiv"
fi

dir=startseite/status
mkdir -p "$dir"
schreiben() {  # $1 = Dateiname, $2 = JSON-Inhalt – atomar ersetzen, damit die Startseite nie eine halbe Datei liest
  local tmp; tmp=$(mktemp "$dir/.$1.XXXXXX")
  printf '%s\n' "$2" > "$tmp"
  chmod 644 "$tmp"
  mv "$tmp" "$dir/$1"
}
jetzt=$(date '+%H:%M')
schreiben werbefilter.json "$(printf '{"filter": "%s", "geprueft": "%s"}' "$status" "$jetzt")"

# --- Temperaturen ------------------------------------------------------------------
cpu="–"
for h in /sys/class/hwmon/hwmon*; do
  case $(cat "$h/name" 2>/dev/null) in coretemp|k10temp|zenpower)
    cpu="$(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 )) °C"; break ;;
  esac
done
ssd="–"; hdd="–"
if command -v smartctl >/dev/null 2>&1; then
  while read -r dev _ type _; do
    [[ -n "$dev" && "$dev" != \#* ]] || continue
    # -n standby: eine ruhende Festplatte nicht nur für die Anzeige aufwecken
    out=$(smartctl -n standby -i -A -d "$type" "$dev" 2>/dev/null); rc=$?
    rpm=$(awk -F: '/Rotation Rate/ {gsub(/^ +/,"",$2); print $2; exit}' <<<"$out")
    if (( rc & 2 )) && grep -qi standby <<<"$out"; then
      t="ruht"
    else
      t=$(awk '$2 ~ /^(Temperature_Celsius|Airflow_Temperature_Cel)$/ {print $10+0 " °C"; exit} /^Temperature:/ {print $2+0 " °C"; exit}' <<<"$out")
    fi
    [[ -n "$t" ]] || continue
    if [[ -n "$rpm" && "$rpm" != *Solid* ]]; then [[ $hdd == "–" ]] && hdd=$t; else [[ $ssd == "–" ]] && ssd=$t; fi
  done < <(smartctl --scan-open 2>/dev/null)
fi
schreiben temperaturen.json "$(printf '{"cpu": "%s", "ssd": "%s", "festplatte": "%s", "geprueft": "%s"}' "$cpu" "$ssd" "$hdd" "$jetzt")"
