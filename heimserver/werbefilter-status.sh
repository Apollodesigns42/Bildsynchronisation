#!/usr/bin/env bash
# Prüft, ob die FritzBox gerade wirklich an AdGuard weiterleitet, und schreibt das Ergebnis für die
# Startseite (Kachel „Werbeblocker“) nach startseite/status/werbefilter.json. Alle 5 Minuten per cron.
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
tmp=$(mktemp "$dir/.werbefilter.XXXXXX")
printf '{"filter": "%s", "geprueft": "%s"}\n' "$status" "$(date '+%H:%M')" > "$tmp"
chmod 644 "$tmp"
mv "$tmp" "$dir/werbefilter.json"
