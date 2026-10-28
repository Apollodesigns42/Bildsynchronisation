#!/usr/bin/env bash
# Ersteinrichtung auf dem Mini-PC: prüft Docker, legt .env an und startet Immich.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker ist nicht installiert. Installation (Debian/Ubuntu):"
  echo "  curl -fsSL https://get.docker.com | sudo sh"
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "Das Docker-Compose-Plugin fehlt (docker compose). Bitte nachinstallieren."
  exit 1
fi

if [[ ! -f .env ]]; then
  read -rp "Speicherort für Fotos [./library]: " upload
  upload=${upload:-./library}
  # Ohne Pipe, sonst bricht "set -o pipefail" ab, wenn head die Pipe schließt
  password=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 2000 /dev/urandom)); password=${password:0:32}

  sed -e "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=${upload}|" \
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

ip=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Fertig. Im Heimnetz nach 1–2 Minuten erreichbar unter: http://${ip:-<IP des Mini-PCs>}:2283"
echo "Der erste Benutzer, der sich dort registriert, wird Administrator – jetzt direkt erledigen."
echo "Nächster Schritt: Tunnel zum VPS (siehe README, Schritt 3)."
