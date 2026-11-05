#!/usr/bin/env bash
# Schaltet die Registrierung neuer Konten bei Vaultwarden an oder aus.
#
# Verwendung:  ./registrierung.sh an    # zum Anlegen eurer Konten
#              ./registrierung.sh aus   # danach sofort wieder ausschalten
set -euo pipefail
cd "$(dirname "$0")"
case ${1:-} in
  an)  value=true ;;
  aus) value=false ;;
  *)   echo "Verwendung: ./registrierung.sh an|aus"; exit 1 ;;
esac
sed -i "s|^VAULTWARDEN_SIGNUPS_ALLOWED=.*|VAULTWARDEN_SIGNUPS_ALLOWED=${value}|" .env
docker compose up -d
echo "Registrierung: ${1}"
[[ $value == false ]] || echo "Nicht vergessen: Nach dem Anlegen der Konten  ./registrierung.sh aus"
