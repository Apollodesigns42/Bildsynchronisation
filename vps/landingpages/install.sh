#!/usr/bin/env bash
# Erzeugt die Platzhalterseiten direkt auf dem VPS unter /var/www/<domain>/index.html.
# Bereits vorhandene Seiten werden NICHT überschrieben (eigene Inhalte bleiben erhalten);
# mit "neu" werden alle Platzhalter neu erzeugt.
# Verwendung:  sudo vps/landingpages/install.sh [neu]
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }

domains=(florian.pw sophia.lv hannah.ee karl.je schillerhoehe.net)

for d in "${domains[@]}"; do
  ziel=/var/www/$d
  mkdir -p "$ziel"
  if [[ -f $ziel/index.html && ${1:-} != neu ]]; then
    echo "  $d: vorhanden, bleibt unverändert"
    continue
  fi
  sed "s/__DOMAIN__/$d/g" vorlage.html > "$ziel/index.html"
  echo "  $d: Platzhalter angelegt"
done

# Zielordner für halvern-industries.com (Inhalt kommt per deploy.sh der Website)
mkdir -p /var/www/halvern-industries.com
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy 2>/dev/null || true
chmod -R a+rX /var/www
echo "Fertig. Danach: sudo vps/caddy-check.sh vps/Caddyfile.vps übernehmen"
