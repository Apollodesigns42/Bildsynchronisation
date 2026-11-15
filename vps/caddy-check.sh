#!/usr/bin/env bash
# Prüft eine neue Caddyfile, BEVOR sie /etc/caddy/Caddyfile ersetzt:
#  1. Sind alle Domains der laufenden Caddyfile weiterhin enthalten? (sonst fällt ein Dienst weg)
#  2. Ist die neue Datei gültig (caddy validate)?
# Verwendung:  sudo ./caddy-check.sh /root/Caddyfile.master
#              sudo ./caddy-check.sh /root/Caddyfile.master übernehmen   # bei Erfolg einspielen
set -euo pipefail
neu=${1:?Pfad zur neuen Caddyfile angeben}
alt=/etc/caddy/Caddyfile
[[ -f $neu ]] || { echo "$neu nicht gefunden."; exit 1; }

# Site-Adressen: Zeilen ohne Einrückung, die mit "{" enden (ohne globale Optionen und Snippets)
hosts() { grep -E '^[^#[:space:](][^{]*\{[[:space:]]*$' "$1" | sed 's/[[:space:]]*{[[:space:]]*$//' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u; }

fehlt=$(comm -23 <(hosts "$alt") <(hosts "$neu") || true)
if [[ -n "$fehlt" ]]; then
  echo "ACHTUNG – diese Domains laufen jetzt, fehlen aber in $neu:"
  echo "$fehlt" | sed 's/^/  - /'
  echo "Nicht übernehmen, erst ergänzen (Vorlage mit allen Diensten: vps/Caddyfile.vps)."
  exit 1
fi
echo "Alle bisherigen Domains sind enthalten. Neu hinzu kommen:"
comm -13 <(hosts "$alt") <(hosts "$neu") | sed 's/^/  + /' || true

caddy validate --adapter caddyfile --config "$neu"

if [[ ${2:-} == übernehmen ]]; then
  bak="$alt.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$alt" "$bak"
  cp "$neu" "$alt"
  if systemctl reload caddy; then
    echo "Übernommen und neu geladen. Alte Fassung: $bak"
  else
    # Neu laden fehlgeschlagen: alte Fassung zurück, damit ein späterer Neustart nichts kaputtmacht
    cp "$bak" "$alt"
    echo "Neu laden fehlgeschlagen – alte Caddyfile wiederhergestellt, Caddy läuft unverändert weiter."
    echo "Ursache: journalctl -u caddy -n 30 --no-pager"
    exit 1
  fi
fi
