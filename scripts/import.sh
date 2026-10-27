#!/usr/bin/env bash
# Importiert Fotos von einer externen Festplatte, einem Ordner oder einem Google-Takeout
# auf den Server. Läuft auf dem PC/Laptop (Linux/macOS), an dem die Daten liegen.
#
# Voraussetzung: immich-go  →  https://github.com/simulot/immich-go/releases
#                (Datei für dein System herunterladen, entpacken, in den PATH legen)
#
# Verwendung:
#   scripts/import.sh ordner  /media/festplatte/Fotos      # Ordnernamen werden zu Alben
#   scripts/import.sh google  ~/Downloads/takeout-*.zip    # Google-Fotos-Export
#   scripts/import.sh ordner  /pfad --dry-run              # nur testen, nichts hochladen
#
# Duplikate erkennt der Server automatisch – ein erneuter Import ist unschädlich.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[[ $# -ge 2 ]] || usage

command -v immich-go >/dev/null 2>&1 || {
  echo "immich-go nicht gefunden. Download: https://github.com/simulot/immich-go/releases"
  exit 1
}
[[ -f import.env ]] || { echo "import.env fehlt – import.env.example kopieren und ausfüllen."; exit 1; }
set -a; source import.env; set +a
[[ -n "${IMMICH_API_KEY:-}" ]] || { echo "IMMICH_API_KEY in import.env ist leer."; exit 1; }

mode=$1; shift
paths=(); extra=()
for arg in "$@"; do
  if [[ $arg == --* ]]; then extra+=("$arg"); else paths+=("$arg"); fi
done

common=(--server="$IMMICH_SERVER" --api-key="$IMMICH_API_KEY"
        --manage-raw-jpeg=StackCoverJPG --manage-burst=Stack --on-errors=continue)

case $mode in
  ordner|folder)
    exec immich-go upload from-folder "${common[@]}" --folder-as-album=FOLDER ${extra[@]+"${extra[@]}"} "${paths[@]}" ;;
  google|takeout)
    exec immich-go upload from-google-photos "${common[@]}" ${extra[@]+"${extra[@]}"} "${paths[@]}" ;;
  *) usage ;;
esac
