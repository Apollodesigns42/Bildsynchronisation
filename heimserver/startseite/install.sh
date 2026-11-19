#!/usr/bin/env bash
# Ersteinrichtung der Startseite (Homepage) auf dem Mini-PC.
#
# Verwendung:  ./install.sh        # einrichten (Dienste-Liste nur beim ersten Mal erzeugen)
#              ./install.sh neu    # Dienste-Liste neu erzeugen, z.B. nach Installation weiterer Dienste
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  detected=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1)}' || true)
  read -rp "LAN-Adresse des Mini-PCs [${detected}]: " lan_ip
  lan_ip=${lan_ip:-$detected}
  [[ -n "$lan_ip" ]] || { echo "Keine Adresse angegeben."; exit 1; }
  sed -e "s|^HOMEPAGE_IP=.*|HOMEPAGE_IP=${lan_ip}|" .env.example > .env
fi
set -a; source .env; set +a
ip=$HOMEPAGE_IP

# Port-Bindung an die LAN-Adresse auch dann erlauben, wenn Docker beim Start schneller ist als das Netzwerk
echo 'net.ipv4.ip_nonlocal_bind = 1' | sudo tee /etc/sysctl.d/99-lan-bind.conf >/dev/null
sudo sysctl -q --system

mkdir -p config status

# Liest eine Variable aus der .env-Datei eines anderen Dienstes
val() { [[ -f "../$1/.env" ]] && (set -a; source "../$1/.env"; echo "${!2:-}") || true; }

if [[ ! -f config/services.yaml || ${1:-} == neu ]]; then
  photos=$( [[ -f ../check.env ]] && (set -a; source ../check.env; echo "${PHOTOS_URL:-}") || true)
  {
    echo "# Von install.sh erzeugt (./install.sh neu erzeugt sie neu). Anpassen erlaubt."
    echo "- Alltag:"
    echo "    - Fotos:"
    echo "        icon: mdi-image-multiple"
    echo "        href: ${photos:-http://$ip:2283}"
    echo "        description: Immich"
    echo "        siteMonitor: http://$ip:2283"
    echo "        server: heimserver"
    echo "        container: immich_server"
    if [[ -f ../cloud/.env ]]; then
      echo "    - Cloud:"
      echo "        icon: mdi-cloud"
      echo "        href: https://$(val cloud OC_DOMAIN)"
      echo "        description: OpenCloud"
      echo "        siteMonitor: http://$ip:9200"
      echo "        server: heimserver"
      echo "        container: opencloud"
    fi
    if [[ -f ../dokumente/.env ]]; then
      echo "    - Dokumente:"
      echo "        icon: mdi-file-document-multiple"
      echo "        href: https://$(val dokumente PAPERLESS_DOMAIN)"
      echo "        description: Paperless-ngx"
      echo "        siteMonitor: http://$ip:8000"
      echo "        server: heimserver"
      echo "        container: paperless"
      if [[ $(val dokumente COMPOSE_PROFILES) == *scanner* ]]; then
        echo "    - Scannen:"
        echo "        icon: mdi-scanner"
        echo "        href: http://$ip:8080"
        echo "        description: Scan direkt in Paperless"
        echo "        siteMonitor: http://$ip:8080"
        echo "        server: heimserver"
        echo "        container: scanservjs"
      fi
    fi
    if [[ -f ../rezepte/.env ]]; then
      echo "    - Rezepte:"
      echo "        icon: mdi-chef-hat"
      echo "        href: https://$(val rezepte MEALIE_DOMAIN)"
      echo "        description: Mealie – Rezepte & Einkaufsliste"
      echo "        siteMonitor: http://$ip:9925"
      echo "        server: heimserver"
      echo "        container: mealie"
    fi
    if [[ -f ../passwoerter/.env ]]; then
      echo "    - Passwörter:"
      echo "        icon: mdi-shield-key"
      echo "        href: https://$(val passwoerter VAULTWARDEN_DOMAIN)"
      echo "        description: Vaultwarden"
      echo "        siteMonitor: http://$ip:8222"
      echo "        server: heimserver"
      echo "        container: vaultwarden"
    fi
    if [[ -f ../smarthome/.env ]]; then
      ha=$(val smarthome HA_DOMAIN)
      if [[ -n "$ha" ]]; then ha_url="https://$ha"; else ha_url="http://$ip:8123"; fi
      echo "    - Smart Home:"
      echo "        icon: mdi-home-automation"
      echo "        href: $ha_url"
      echo "        description: Home Assistant"
      echo "        siteMonitor: http://$ip:8123"
      echo "        server: heimserver"
      echo "        container: homeassistant"
    fi
    printer=$(val dokumente SCANNER_URL)
    if [[ -f ../adguard/.env || -f ../verwaltung/.env || -n "$printer" ]]; then
      echo "- Verwaltung:"
    fi
    if [[ -n "$printer" ]]; then
      echo "    - Drucker:"
      echo "        icon: mdi-printer"
      echo "        href: $printer"
      echo "        description: Tonerstand & Einstellungen"
      echo "        siteMonitor: $printer"
    fi
    if [[ -f ../verwaltung/.env ]]; then
      echo "    - Container:"
      echo "        icon: mdi-docker"
      echo "        href: https://$(val verwaltung PORTAINER_IP):9443"
      echo "        description: Portainer – Dienste neu starten"
      echo "        server: heimserver"
      echo "        container: portainer"
    fi
    if [[ -f ../adguard/.env ]]; then
      echo "    - Werbeblocker:"
      echo "        icon: mdi-shield-check"
      echo "        href: http://$(val adguard ADGUARD_IP):3080"
      echo "        description: AdGuard Home"
      echo "        siteMonitor: http://$(val adguard ADGUARD_IP):3080"
      echo "        server: heimserver"
      echo "        container: adguard"
      echo "        widget:"
      echo "          type: customapi"
      echo "          url: http://localhost:3000/status/werbefilter.json"
      echo "          refreshInterval: 60000"
      echo "          mappings:"
      echo "            - field: filter"
      echo "              label: Filter"
      echo "            - field: geprueft"
      echo "              label: Geprüft"
    fi
  } > config/services.yaml
  echo "Dienste-Liste erzeugt: config/services.yaml"
fi

[[ -f config/settings.yaml ]] || cat > config/settings.yaml <<'CONF'
title: Heimserver
language: de
headerStyle: clean
layout:
  Alltag:
    style: row
    columns: 4
CONF

sudo mkdir -p /var/lib/heimserver   # Systemplatte für die Speicheranzeige
[[ -f config/widgets.yaml ]] || cat > config/widgets.yaml <<'CONF'
- resources:
    cpu: true
    memory: true
- resources:
    label: System
    disk: /mnt/system
- resources:
    label: Daten
    disk: /mnt/daten
- datetime:
    text_size: md
    format:
      dateStyle: long
      timeStyle: short
CONF
touch config/bookmarks.yaml
# Container-Status über den Lese-Proxy (siehe docker-compose.yml)
grep -q '^heimserver:' config/docker.yaml 2>/dev/null || cat >> config/docker.yaml <<'CONF'
heimserver:
  host: dockerproxy
  port: 2375
CONF
sudo chown -R 1000:1000 config

# Status-Datei für die Werbeblocker-Kachel vor dem Start anlegen (Homepage liefert nur Dateien aus,
# die beim Start schon da sind; danach wird sie von werbefilter-status.sh laufend aktualisiert)
[[ -f ../adguard/.env ]] && { ../werbefilter-status.sh || true; }
docker compose pull
docker compose up -d
docker compose restart homepage >/dev/null   # neu erzeugte Liste laden

echo
echo "Startseite: http://${ip}:3010  (nur im Heimnetz)"
