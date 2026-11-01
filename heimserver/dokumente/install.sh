#!/usr/bin/env bash
# Ersteinrichtung von Paperless-ngx auf dem Mini-PC (nach heimserver/install.sh).
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

# Zufallswert ohne Pipe, sonst bricht "set -o pipefail" ab, wenn head die Pipe schließt
random() { local r; r=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 2000 /dev/urandom)); echo "${r:0:$1}"; }

if [[ ! -f .env ]]; then
  read -rp "Domain der Dokumentenverwaltung (z.B. www.example.eu): " domain
  [[ -n "$domain" ]] || { echo "Keine Domain angegeben."; exit 1; }
  read -rp "Speicherort für Dokumente [./dokumente]: " media
  media=${media:-./dokumente}
  read -rp "IP-Adresse des Netzwerk-Scanners (leer = kein Scannen per Browser): " scanner_ip

  profiles=scanner
  [[ -n "$scanner_ip" ]] || profiles=
  admin_pw=$(random 24)

  sed -e "s|^PAPERLESS_DOMAIN=.*|PAPERLESS_DOMAIN=${domain}|" \
      -e "s|^PAPERLESS_MEDIA_DIR=.*|PAPERLESS_MEDIA_DIR=${media}|" \
      -e "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=${profiles}|" \
      -e "s|^SCANNER_URL=.*|SCANNER_URL=http://${scanner_ip:-192.168.178.50}/eSCL|" \
      -e "s|^PAPERLESS_SECRET_KEY=.*|PAPERLESS_SECRET_KEY=$(random 64)|" \
      -e "s|^PAPERLESS_DB_PASSWORD=.*|PAPERLESS_DB_PASSWORD=$(random 32)|" \
      -e "s|^PAPERLESS_ADMIN_PASSWORD=.*|PAPERLESS_ADMIN_PASSWORD=${admin_pw}|" \
      .env.example > .env
  chmod 600 .env
  echo ".env angelegt."
  echo
  echo "Admin-Zugang:  Benutzer admin  /  Passwort ${admin_pw}"
  echo "→ Jetzt im Passwortmanager speichern."
  echo
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi

set -a; source .env; set +a
mkdir -p "$PAPERLESS_DB_DIR" "$PAPERLESS_DATA_DIR" "$PAPERLESS_CONSUME_DIR" "$PAPERLESS_MEDIA_DIR" export
# Paperless läuft im Container als Benutzer 1000:1000
sudo chown -R 1000:1000 "$PAPERLESS_DATA_DIR" "$PAPERLESS_CONSUME_DIR" "$PAPERLESS_MEDIA_DIR" export

docker compose pull
docker compose up -d

ip=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Paperless läuft. Erreichbar unter https://${PAPERLESS_DOMAIN}, sobald die Domain auf dem VPS"
echo "eingetragen ist. Der erste Start dauert 1–2 Minuten."
[[ ${COMPOSE_PROFILES:-} != *scanner* ]] || echo "Scannen im Heimnetz: http://${ip:-<IP des Mini-PCs>}:8080"
