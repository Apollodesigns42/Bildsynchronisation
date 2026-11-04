#!/usr/bin/env bash
# Ersteinrichtung von Mealie auf dem Mini-PC (nach heimserver/install.sh).
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  read -rp "Domain für Mealie (z.B. rezepte.example.de): " domain
  [[ -n "$domain" ]] || { echo "Keine Domain angegeben."; exit 1; }
  sed -e "s|^MEALIE_DOMAIN=.*|MEALIE_DOMAIN=${domain}|" .env.example > .env
  echo ".env angelegt."
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi

set -a; source .env; set +a
mkdir -p "$MEALIE_DATA_DIR"
# Mealie läuft im Container als Benutzer 1000:1000
sudo chown -R 1000:1000 "$MEALIE_DATA_DIR"

docker compose pull
docker compose up -d

ip=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Mealie läuft. Im Heimnetz nach 1–2 Minuten: http://${ip:-<IP des Mini-PCs>}:9925"
echo
echo "WICHTIG: Mealie startet mit dem Standard-Zugang  changeme@example.com / MyPassword"
echo "Sofort im Heimnetz anmelden und unter Profil E-Mail-Adresse und Passwort ändern –"
echo "ERST DANACH die Domain ${MEALIE_DOMAIN} auf dem VPS freischalten."
