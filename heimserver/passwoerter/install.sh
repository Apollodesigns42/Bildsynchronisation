#!/usr/bin/env bash
# Ersteinrichtung von Vaultwarden auf dem Mini-PC (nach heimserver/install.sh).
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  read -rp "Domain für den Passwortmanager (z.B. passwort.example.de): " domain
  [[ -n "$domain" ]] || { echo "Keine Domain angegeben."; exit 1; }
  sed -e "s|^VAULTWARDEN_DOMAIN=.*|VAULTWARDEN_DOMAIN=${domain}|" .env.example > .env
  chmod 600 .env
  echo ".env angelegt."
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi
set -a; source .env; set +a
mkdir -p "$VAULTWARDEN_DATA_DIR"

docker compose pull
docker compose up -d

echo
echo "Vaultwarden läuft (Registrierung ist AUS)."
echo "Zum Anlegen eurer Konten:  ./registrierung.sh an  →  Konten anlegen  →  ./registrierung.sh aus"
echo "Die Bitwarden-Apps brauchen HTTPS: Erst die Domain ${VAULTWARDEN_DOMAIN} auf dem VPS freischalten."
