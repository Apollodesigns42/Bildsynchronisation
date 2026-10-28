#!/usr/bin/env bash
# Auf dem VPS ausführen: richtet den WireGuard-Tunnel zum Mini-PC daheim ein und –
# falls Port 80/443 frei sind – Caddy als HTTPS-Weiterleitung.
#
# Verwendung:  sudo ./setup.sh
#
# Erzeugt heimserver-wg.conf für den Mini-PC (dort mit heimserver/tunnel.sh einspielen).
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Bitte mit sudo ausführen."; exit 1; }

IFACE=wg-fotos
VPS_TUNNEL_IP=10.77.0.1
HOME_TUNNEL_IP=10.77.0.2
CONF=/etc/wireguard/$IFACE.conf
HOME_CONF=heimserver-wg.conf
UPSTREAM=$HOME_TUNNEL_IP:2283

read -rp "Domain für die Fotos (z.B. fotos.example.de): " domain
[[ -n "$domain" ]] || { echo "Keine Domain angegeben."; exit 1; }

port_used() {  # $1 = Port, $2 = t (TCP) oder u (UDP)
  if command -v ss >/dev/null 2>&1; then
    ss -Hl"$2"n "sport = :$1" | grep -q .
  else
    [[ $2 == t ]] && (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
  fi
}

# --- WireGuard -----------------------------------------------------------------
command -v wg >/dev/null 2>&1 || { apt-get update && apt-get install -y wireguard-tools; }

if [[ -f $CONF ]]; then
  echo "$CONF existiert bereits – Tunnel wird nicht neu erzeugt."
  wg_port=$(awk -F' *= *' '/^ListenPort/ {print $2}' "$CONF")
else
  wg_port=51820
  while port_used "$wg_port" u; do wg_port=$((wg_port + 1)); done

  umask 077
  vps_key=$(wg genkey);  vps_pub=$(wg pubkey <<<"$vps_key")
  home_key=$(wg genkey); home_pub=$(wg pubkey <<<"$home_key")
  psk=$(wg genpsk)

  cat > "$CONF" <<CONF
[Interface]
Address = $VPS_TUNNEL_IP/24
ListenPort = $wg_port
PrivateKey = $vps_key

[Peer]
# Mini-PC daheim
PublicKey = $home_pub
PresharedKey = $psk
AllowedIPs = $HOME_TUNNEL_IP/32
CONF

  cat > "$HOME_CONF" <<CONF
[Interface]
Address = $HOME_TUNNEL_IP/24
PrivateKey = $home_key
# Über den Tunnel ist nur Immich (Docker-Port 2283) erreichbar – SSH und andere Dienste
# des Mini-PCs bleiben für den VPS gesperrt. (Docker-Ports laufen über FORWARD, nicht INPUT.)
PostUp = iptables -I INPUT -i %i -m conntrack --ctstate NEW -j DROP
PostDown = iptables -D INPUT -i %i -m conntrack --ctstate NEW -j DROP

[Peer]
# VPS
PublicKey = $vps_pub
PresharedKey = $psk
Endpoint = $domain:$wg_port
AllowedIPs = $VPS_TUNNEL_IP/32
# Hält den Tunnel durch die FritzBox hindurch offen
PersistentKeepalive = 25
CONF
  umask 022
  systemctl enable --now "wg-quick@$IFACE"
  echo "WireGuard läuft auf UDP-Port $wg_port."
fi

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow "$wg_port/udp"
fi

# --- HTTPS-Weiterleitung ---------------------------------------------------------
echo
if port_used 80 t || port_used 443 t; then
  echo "Port 80/443 ist belegt – es läuft bereits ein Webserver. Dort eintragen:"
  echo "  $domain  →  http://$UPSTREAM   (Beispiele: docs/reverse-proxy.md)"
elif command -v docker >/dev/null 2>&1; then
  printf 'DOMAIN=%s\nIMMICH_UPSTREAM=%s\n' "$domain" "$UPSTREAM" > .env
  docker compose up -d
  echo "Caddy gestartet – https://$domain wird erreichbar, sobald der Tunnel steht."
else
  echo "Port 80/443 ist frei, aber Docker fehlt. Entweder Docker installieren"
  echo "(curl -fsSL https://get.docker.com | sh) und dieses Skript erneut starten,"
  echo "oder einen Webserver nach docs/reverse-proxy.md einrichten."
fi

echo
echo "WICHTIG: In der IONOS-Firewall (Cloud Panel → Netzwerk → Firewall-Richtlinien)"
echo "         UDP-Port $wg_port freigeben."
if [[ -f $HOME_CONF ]]; then
  echo
  echo "Nächster Schritt: $(pwd)/$HOME_CONF auf den Mini-PC kopieren, z.B.:"
  echo "  scp $(pwd)/$HOME_CONF <benutzer>@<mini-pc>:   (oder per USB-Stick)"
  echo "und dort ausführen: sudo heimserver/tunnel.sh ~/heimserver-wg.conf"
  echo "Danach die Datei hier löschen: rm $(pwd)/$HOME_CONF"
fi
