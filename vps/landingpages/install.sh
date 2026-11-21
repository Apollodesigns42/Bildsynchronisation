#!/usr/bin/env bash
# Spielt die Platzhalterseiten (index, Impressum, Datenschutz) aus seiten/<domain>/
# nach /var/www/<domain>/ auf dem VPS. Vorhandene Dateien werden überschrieben,
# die Seiten werden hier im Repository gepflegt.
# friedrich-schiller-höhe.de hat keine eigene Seite: Caddy leitet sie auf schillerhoehe.net um.
# Verwendung:  sudo vps/landingpages/install.sh
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }

for quelle in seiten/*/; do
  d=$(basename "$quelle")
  ziel=/var/www/$d
  mkdir -p "$ziel"
  cp -f "$quelle"*.html "$ziel/"
  echo "  $d: $(ls "$quelle" | tr '\n' ' ')"
done

# Zielordner für halvern-industries.com (Inhalt kommt per deploy.sh der Website)
mkdir -p /var/www/halvern-industries.com
chmod -R a+rX /var/www
echo "Fertig. Caddy muss dafür nicht neu geladen werden."
