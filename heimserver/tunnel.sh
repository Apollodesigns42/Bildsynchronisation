#!/usr/bin/env bash
# Richtet auf dem Mini-PC den WireGuard-Tunnel zum VPS ein.
# Die Konfigurationsdatei erzeugt vps/setup.sh auf dem VPS (heimserver-wg.conf).
#
# Verwendung:  sudo ./tunnel.sh heimserver-wg.conf
set -euo pipefail
conf=${1:?"Konfigurationsdatei angeben: sudo ./tunnel.sh heimserver-wg.conf"}
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }

command -v wg-quick >/dev/null 2>&1 || { apt-get update && apt-get install -y wireguard-tools; }

install -m 600 "$conf" /etc/wireguard/wg-fotos.conf
systemctl enable wg-quick@wg-fotos
systemctl restart wg-quick@wg-fotos

sleep 2
if ping -c 2 -W 3 10.77.0.1 >/dev/null 2>&1; then
  echo "Tunnel steht – der VPS ist unter 10.77.0.1 erreichbar."
  echo "Die Datei $conf enthält einen privaten Schlüssel – jetzt löschen: rm $conf"
else
  echo "VPS nicht erreichbar. Prüfen: UDP-Port in der IONOS-Firewall freigegeben? 'sudo wg show' zeigt Details."
  exit 1
fi
