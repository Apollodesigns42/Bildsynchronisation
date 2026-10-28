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

  # Läuft schon etwas auf dem Server? Belegte Ports erkennen.
  port_used() {
    if command -v ss >/dev/null 2>&1; then
      ss -Hltn "sport = :$1" | grep -q .
    else
      (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
    fi
  }

  profiles=caddy
  if port_used 80 || port_used 443; then
    echo
    echo "Port 80/443 ist bereits belegt – vermutlich läuft schon ein Webserver:"
    ss -Hltnp '( sport = :80 or sport = :443 )' 2>/dev/null | awk '{print "  " $4, $6}' || true
    echo "Der mitgelieferte Caddy wird daher NICHT gestartet. Leite stattdessen in deinem"
    echo "bestehenden Webserver die Domain an Immich weiter (Beispiele: docs/reverse-proxy.md)."
    profiles=
  fi

  port=2283
  while port_used "$port"; do port=$((port + 1)); done
  [[ $port == 2283 ]] || echo "Port 2283 ist belegt – Immich nutzt lokal Port $port."

  sed -e "s|^DOMAIN=.*|DOMAIN=${domain}|" \
      -e "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=${upload}|" \
      -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${password}|" \
      -e "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=${profiles}|" \
      -e "s|^IMMICH_PORT=.*|IMMICH_PORT=${port}|" \
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
if [[ ${COMPOSE_PROFILES:-} == *caddy* ]]; then
  echo "Fertig. Nach 1–2 Minuten erreichbar unter: https://${DOMAIN}"
else
  echo "Immich läuft lokal auf http://127.0.0.1:${IMMICH_PORT:-2283}"
  echo "Jetzt im bestehenden Webserver ${DOMAIN} dorthin weiterleiten: docs/reverse-proxy.md"
fi
echo "Der erste Benutzer, der sich dort registriert, wird Administrator."
