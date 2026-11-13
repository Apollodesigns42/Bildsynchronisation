#!/usr/bin/env bash
# Ersteinrichtung der Container-Verwaltung (Portainer) auf dem Mini-PC – nur im Heimnetz.
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  detected=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1)}' || true)
  read -rp "LAN-Adresse des Mini-PCs [${detected}]: " lan_ip
  lan_ip=${lan_ip:-$detected}
  [[ -n "$lan_ip" ]] || { echo "Keine Adresse angegeben."; exit 1; }
  sed -e "s|^PORTAINER_IP=.*|PORTAINER_IP=${lan_ip}|" .env.example > .env
fi
set -a; source .env; set +a

# Port-Bindung an die LAN-Adresse auch dann erlauben, wenn Docker beim Start schneller ist als das Netzwerk
echo 'net.ipv4.ip_nonlocal_bind = 1' | sudo tee /etc/sysctl.d/99-lan-bind.conf >/dev/null
sudo sysctl -q --system

mkdir -p data
docker compose pull
docker compose up -d

echo
echo "Portainer: https://${PORTAINER_IP}:9443  (nur im Heimnetz)"
echo "JETZT innerhalb von 5 Minuten öffnen und das Admin-Konto anlegen – sonst sperrt sich"
echo "Portainer aus Sicherheitsgründen (dann: docker restart portainer)."
echo "Die Zertifikatswarnung des Browsers ist hier normal (eigenes Zertifikat im Heimnetz)."
echo "Danach in startseite/: ./install.sh neu  – dann erscheint die Kachel „Container“."
