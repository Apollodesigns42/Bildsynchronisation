#!/usr/bin/env bash
# Ersteinrichtung auf dem VPS: prüft Docker, legt .env an und startet alle Dienste.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker ist nicht installiert. Installation (Debian/Ubuntu):"
  echo "  curl -fsSL https://get.docker.com | sh"
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "Das Docker-Compose-Plugin fehlt (docker compose). Bitte nachinstallieren."
  exit 1
fi

if [[ ! -f .env ]]; then
  read -rp "Domain für den Fotoserver (z.B. fotos.example.de): " domain
  [[ -n "$domain" ]] || { echo "Keine Domain angegeben."; exit 1; }
  read -rp "Speicherort für Fotos [./library]: " upload
  upload=${upload:-./library}
  password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

  sed -e "s|^DOMAIN=.*|DOMAIN=${domain}|" \
      -e "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=${upload}|" \
      -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${password}|" \
      .env.example > .env
  chmod 600 .env
  echo ".env angelegt."
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi

set -a; source .env; set +a
mkdir -p "$UPLOAD_LOCATION" "$DB_DATA_LOCATION"

docker compose pull
docker compose up -d

echo
echo "Fertig. Nach 1–2 Minuten erreichbar unter: https://${DOMAIN}"
echo "Der erste Benutzer, der sich dort registriert, wird Administrator."
