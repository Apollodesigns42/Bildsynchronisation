#!/usr/bin/env bash
# Ersteinrichtung von Home Assistant auf dem Mini-PC (nach heimserver/install.sh).
set -euo pipefail
cd "$(dirname "$0")"

docker compose version >/dev/null 2>&1 || { echo "Docker fehlt – zuerst heimserver/install.sh ausführen."; exit 1; }

if [[ ! -f .env ]]; then
  read -rp "Domain für Home Assistant (z.B. haus.example.de, leer = nur Heimnetz): " domain
  sed -e "s|^HA_DOMAIN=.*|HA_DOMAIN=${domain}|" .env.example > .env
  echo ".env angelegt."
else
  echo ".env existiert bereits – wird unverändert verwendet."
fi
set -a; source .env; set +a

# Grundkonfiguration: entspricht der Standardkonfiguration von Home Assistant, ergänzt um
# den Reverse Proxy auf dem VPS (sonst lehnt Home Assistant weitergeleitete Anfragen ab).
mkdir -p config/themes
if [[ ! -f config/configuration.yaml ]]; then
  cat > config/configuration.yaml <<'CONF'
# Standardkonfiguration von Home Assistant
default_config:

frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml

# Zugriff über den VPS (WireGuard-Tunnel) erlauben
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.77.0.1
CONF
  touch config/automations.yaml config/scripts.yaml config/scenes.yaml
fi

# Home Assistant läuft im Host-Netzwerk. Damit der VPS es über den Tunnel erreicht, braucht der
# Tunnel eine Ausnahme für Port 8123 (sonst sperrt er Verbindungen zu Diensten des Mini-PCs).
conf=/etc/wireguard/wg-fotos.conf
if [[ -n "${HA_DOMAIN}" ]] && sudo test -f "$conf" && ! sudo grep -q 'dport 8123' "$conf"; then
  sudo sed -i '/^PostDown = iptables -D INPUT -i %i -m conntrack --ctstate NEW -j DROP/a\
PostUp = iptables -I INPUT -i %i -p tcp --dport 8123 -j ACCEPT\
PostDown = iptables -D INPUT -i %i -p tcp --dport 8123 -j ACCEPT' "$conf"
  sudo systemctl restart wg-quick@wg-fotos
  echo "Tunnel: Port 8123 für Home Assistant freigegeben."
fi

docker compose pull
docker compose up -d

ip=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Home Assistant startet (beim ersten Mal 1–3 Minuten)."
echo "Einrichtung im Heimnetz: http://${ip:-<IP des Mini-PCs>}:8123  – dort sofort das Konto anlegen,"
echo "ERST DANACH die Domain ${HA_DOMAIN:-(keine)} auf dem VPS freischalten."
