#!/usr/bin/env bash
# Schaltet die Hardware-Beschleunigung von Immich über die Intel-Grafik (Quick Sync / OpenVINO) ein oder aus.
#
# Verwendung:  ./beschleunigung.sh video   # Videoumwandlung über Intel Quick Sync (empfohlen)
#              ./beschleunigung.sh ki      # zusätzlich Gesichtserkennung/Suche über OpenVINO (experimentell)
#              ./beschleunigung.sh aus     # alles wieder auf dem Prozessor
#              ./beschleunigung.sh status  # aktuelle Einstellung und erkannte Grafikeinheiten
#
# Hintergrund: https://docs.immich.app/features/hardware-transcoding
#              https://docs.immich.app/features/ml-hardware-acceleration
set -euo pipefail
cd "$(dirname "$0")"
[[ -f .env ]] || { echo ".env fehlt – zuerst ./install.sh ausführen."; exit 1; }

# Wert in .env setzen oder ergänzen
setenv() { if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }

# Grafikeinheiten auflisten (Intel = Hersteller 0x8086, AMD = 0x1002)
gpus() {
  intel=""
  for d in /sys/class/drm/renderD*; do
    [[ -e "$d" ]] || continue
    vendor=$(cat "$d/device/vendor" 2>/dev/null || echo "?")
    case $vendor in 0x8086) name="Intel"; intel=${intel:-$(basename "$d")} ;; 0x1002) name="AMD" ;; *) name="unbekannt ($vendor)" ;; esac
    echo "  /dev/dri/$(basename "$d"): $name"
  done
}

case ${1:-status} in
  video)
    setenv IMMICH_TRANSCODE_BACKEND quicksync ;;
  ki)
    setenv IMMICH_TRANSCODE_BACKEND quicksync
    setenv IMMICH_ML_BACKEND openvino
    setenv IMMICH_ML_IMAGE_SUFFIX -openvino ;;
  aus)
    setenv IMMICH_TRANSCODE_BACKEND cpu
    setenv IMMICH_ML_BACKEND cpu
    setenv IMMICH_ML_IMAGE_SUFFIX "" ;;
  status) ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

echo "Grafikeinheiten:"
gpus
mode=${1:-status}
if [[ -z "${intel:-}" && ( $mode == video || $mode == ki ) ]]; then
  echo "Keine Intel-Grafik gefunden – Beschleunigung über Quick Sync/OpenVINO nicht möglich."
  setenv IMMICH_TRANSCODE_BACKEND cpu; setenv IMMICH_ML_BACKEND cpu; setenv IMMICH_ML_IMAGE_SUFFIX ""
  exit 1
fi
echo
grep -E '^IMMICH_(TRANSCODE_BACKEND|ML_BACKEND|ML_IMAGE_SUFFIX)=' .env || echo "Keine Einstellung in .env – alles läuft auf dem Prozessor."

if [[ $mode != status ]]; then
  docker compose pull immich-machine-learning
  docker compose up -d
  echo
  if [[ $mode != aus ]]; then
    echo "Jetzt in Immich einstellen: Administration → Einstellungen → Videotranskodierung →"
    echo "  Hardware-Beschleunigung: Beschleunigung = Quick Sync, Hardware-Dekodierung = an,"
    echo "  Bevorzugtes Hardwaregerät = ${intel:-renderD128} (die Intel-Grafik, nicht AMD)."
  fi
fi
