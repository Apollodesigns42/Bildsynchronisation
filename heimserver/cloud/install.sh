#!/usr/bin/env bash
# Ersteinrichtung von OpenCloud auf dem Mini-PC (nach heimserver/install.sh).
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  read -rp "Domain der Cloud (z.B. cloud.example.de): " domain
  [[ -n "$domain" ]] || { echo "Keine Domain angegeben."; exit 1; }
  read -rp "Speicherort für Cloud-Daten [./daten]: " data
  data=${data:-./daten}
  # Erfüllt die Passwort-Regeln von OpenCloud (Groß-/Kleinbuchstaben, Ziffer, Sonderzeichen)
  # Ohne Pipe, sonst bricht "set -o pipefail" ab, wenn head die Pipe schließt
  password=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 2000 /dev/urandom)); password="${password:0:20}Aa1-"

  sed -e "s|^OC_DOMAIN=.*|OC_DOMAIN=${domain}|" \
      -e "s|^OC_DATA_DIR=.*|OC_DATA_DIR=${data}|" \
      -e "s|^INITIAL_ADMIN_PASSWORD=.*|INITIAL_ADMIN_PASSWORD=${password}|" \
      .env.example > .env
  chmod 600 .env
  echo ".env angelegt."
  echo
  echo "Admin-Zugang:  Benutzer admin  /  Passwort ${password}"
  echo "→ Jetzt im Passwortmanager speichern."
  echo
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi

set -a; source .env; set +a
mkdir -p "$OC_CONFIG_DIR" "$OC_DATA_DIR"
# Der Container läuft als Benutzer 1000:1000
sudo chown -R 1000:1000 "$OC_CONFIG_DIR" "$OC_DATA_DIR"

docker compose pull
docker compose up -d

echo "OpenCloud läuft. Erreichbar unter https://${OC_DOMAIN}, sobald die Domain auf dem VPS"
echo "eingetragen ist (sudo vps/setup.sh erneut ausführen und die Cloud-Domain angeben)."
