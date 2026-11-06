#!/usr/bin/env bash
# Schaltet die Hardware-Beschleunigung von Immich ein oder aus: Intel-Grafik (Quick Sync / OpenVINO)
# oder – wenn keine Intel-Grafik vorhanden ist – AMD-Grafik (VAAPI, nur Videos).
#
# Verwendung:  ./beschleunigung.sh video   # Videoumwandlung über Intel Quick Sync bzw. AMD VAAPI (empfohlen)
#              ./beschleunigung.sh ki      # zusätzlich Gesichtserkennung/Suche über OpenVINO (nur Intel, experimentell)
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

# Grafikeinheiten auflisten und die erste Intel- bzw. AMD-Schnittstelle merken
# (Hersteller-Kennung: Intel = 0x8086, AMD = 0x1002)
intel=""
amd=""
echo "Grafikeinheiten:"
for d in /sys/class/drm/renderD*; do
  [[ -e "$d" ]] || continue
  vendor=$(cat "$d/device/vendor" 2>/dev/null || echo "?")
  case $vendor in
    0x8086) name="Intel"; intel=${intel:-$(basename "$d")} ;;
    0x1002) name="AMD";   amd=${amd:-$(basename "$d")} ;;
    *)      name="unbekannt ($vendor)" ;;
  esac
  echo "  /dev/dri/$(basename "$d"): $name"
done
[[ -n "$intel$amd" ]] || echo "  (keine)"

mode=${1:-status}
accel=""
device=""
case $mode in
  video)
    if [[ -n "$intel" ]]; then
      setenv IMMICH_TRANSCODE_BACKEND quicksync; accel="Quick Sync (QSV)"; device=$intel
    elif [[ -n "$amd" ]]; then
      setenv IMMICH_TRANSCODE_BACKEND vaapi; accel="VAAPI"; device=$amd
    else
      echo "Keine unterstützte Grafikeinheit gefunden – alles bleibt auf dem Prozessor."; exit 1
    fi ;;
  ki)
    [[ -n "$intel" ]] || { echo "Die Gesichtserkennung lässt sich nur mit Intel-Grafik (OpenVINO) beschleunigen – keine gefunden."; exit 1; }
    setenv IMMICH_TRANSCODE_BACKEND quicksync; accel="Quick Sync (QSV)"; device=$intel
    setenv IMMICH_ML_BACKEND openvino
    setenv IMMICH_ML_IMAGE_SUFFIX -openvino ;;
  aus)
    setenv IMMICH_TRANSCODE_BACKEND cpu
    setenv IMMICH_ML_BACKEND cpu
    setenv IMMICH_ML_IMAGE_SUFFIX "" ;;
  status) ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

echo
grep -E '^IMMICH_(TRANSCODE_BACKEND|ML_BACKEND|ML_IMAGE_SUFFIX)=' .env || echo "Keine Einstellung in .env – alles läuft auf dem Prozessor."

if [[ $mode != status ]]; then
  docker compose pull immich-machine-learning
  docker compose up -d
  echo
  if [[ $mode == aus ]]; then
    echo "In Immich unter Administration → Einstellungen → Videotranskodierung die Hardware-Beschleunigung"
    echo "wieder auf „Deaktiviert“ stellen."
  else
    echo "Jetzt in Immich einstellen: Administration → Einstellungen → Videotranskodierung →"
    echo "  Hardware-Beschleunigung: Beschleunigung = ${accel}, Hardware-Dekodierung = an,"
    echo "  Bevorzugtes Hardwaregerät = ${device}."
  fi
fi
