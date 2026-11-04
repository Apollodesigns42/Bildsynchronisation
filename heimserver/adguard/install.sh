#!/usr/bin/env bash
# Ersteinrichtung von AdGuard Home auf dem Mini-PC (nach heimserver/install.sh).
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  detected=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1)}')
  read -rp "LAN-Adresse des Mini-PCs [${detected}]: " lan_ip
  lan_ip=${lan_ip:-$detected}
  [[ -n "$lan_ip" ]] || { echo "Keine Adresse angegeben."; exit 1; }
  sed -e "s|^ADGUARD_IP=.*|ADGUARD_IP=${lan_ip}|" .env.example > .env
  echo ".env angelegt."
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi
set -a; source .env; set +a

# Die Ports hängen an der LAN-Adresse. Damit AdGuard auch dann startet, wenn Docker beim
# Hochfahren schneller ist als die Netzwerkkarte, darf an noch nicht vorhandene Adressen
# gebunden werden.
echo 'net.ipv4.ip_nonlocal_bind = 1' | sudo tee /etc/sysctl.d/99-adguard.conf >/dev/null
sudo sysctl -q --system

mkdir -p conf work
docker compose pull
docker compose up -d

echo
echo "AdGuard läuft. Einrichtungsassistent: http://${ADGUARD_IP}:3000"
echo "Im Assistenten Weboberfläche auf Port 80 und DNS-Server auf Port 53 lassen."
echo "Danach erreichst du AdGuard unter: http://${ADGUARD_IP}:3080"
