#!/usr/bin/env bash
# =============================================================================
# Kopie zum Nachschlagen – gehört nach J:\Claude\Youtube\website\deploy\deploy.sh (läuft nur dort).
# HALVERN INDUSTRIES — Deploy auf den IONOS-VPS
#
#   ./deploy/deploy.sh
#
# Baut die Seite neu, prueft sie und spiegelt public/ nach
# /var/www/halvern-industries.com auf dem VPS. Caddy liefert die Dateien von
# dort direkt aus – die Caddy-Konfiguration liegt im Projekt bildsynchronisation
# (vps/Caddyfile) und wird hier NICHT angefasst. Kein Caddy-Reload noetig.
#
# Laeuft in Git-Bash unter Windows genauso wie unter Linux. Ohne rsync (Git-Bash
# bringt keins mit) wird per tar ueber ssh uebertragen – ebenfalls vollstaendig
# gespiegelt, geloeschte Seiten verschwinden auch auf dem Server.
#
# Anderer Server/Benutzer:  HALVERN_HOST=benutzer@1.2.3.4 ./deploy/deploy.sh
# =============================================================================

set -euo pipefail

# ------------------------------------------------------------------ Konfiguration
HOST="${HALVERN_HOST:-root@217.154.115.102}"
REMOTE="${HALVERN_REMOTE:-/var/www/halvern-industries.com}"
URL="https://halvern-industries.com/"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

say() { printf '\033[38;5;179m▸\033[0m %s\n' "$1"; }
die() { printf '\033[31m✕\033[0m %s\n' "$1" >&2; exit 1; }

# Unter Windows heisst Python oft "python" statt "python3"
PY=python3
command -v "$PY" >/dev/null 2>&1 || PY=python
command -v "$PY" >/dev/null 2>&1 || die "Python nicht gefunden."

# ------------------------------------------------------------------ 1. Bauen
say "Baue die Seite"
"$PY" build.py

# ------------------------------------------------------------------ 2. Pruefen
say "Pruefe Links und Struktur"
"$PY" verify.py || die "Verifikation fehlgeschlagen — nichts uebertragen."
[[ -f public/index.html ]] || die "public/index.html fehlt — nichts uebertragen."

SIZE="$(du -sh public | cut -f1)"
FILES="$(find public -type f | wc -l | tr -d ' ')"
say "public/ enthaelt $FILES Dateien, $SIZE"

# ------------------------------------------------------------------ 3. Uebertragen
say "Uebertrage nach $HOST:$REMOTE"
ssh "$HOST" "mkdir -p '$REMOTE'"

if command -v rsync >/dev/null 2>&1; then
  # --delete raeumt geloeschte Seiten mit ab.
  rsync -avz --delete --human-readable \
        --exclude '.DS_Store' --exclude 'Thumbs.db' \
        public/ "$HOST:$REMOTE/"
else
  # Neue Fassung erst in einen Nebenordner, dann in einem Schritt austauschen:
  # Die Seite ist nie halb hochgeladen, die vorige Fassung bleibt als .alt liegen.
  say "rsync nicht gefunden, uebertrage per tar ueber ssh"
  tar -C public --exclude '.DS_Store' --exclude 'Thumbs.db' -czf - . | ssh "$HOST" "
    set -e
    rm -rf '$REMOTE.neu' && mkdir -p '$REMOTE.neu'
    tar -C '$REMOTE.neu' -xzf -
    rm -rf '$REMOTE.alt'
    mv '$REMOTE' '$REMOTE.alt'
    mv '$REMOTE.neu' '$REMOTE'
  "
fi

# ------------------------------------------------------------------ 4. Rechte
say "Setze Rechte"
ssh "$HOST" "find '$REMOTE' -type d -exec chmod 755 {} + && \
             find '$REMOTE' -type f -exec chmod 644 {} +"

# ------------------------------------------------------------------ 5. Kurztest
say "Teste die Auslieferung"
code="$(curl -s -o /dev/null -w '%{http_code}' "$URL" || true)"
if [[ "$code" == 200 ]]; then
  say "$URL antwortet (200)"
else
  say "Keine 200 von $URL (Antwort: ${code:-keine})."
  say "Pruefen: DNS-Eintrag auf 217.154.115.102? vps/Caddyfile auf dem VPS eingespielt?"
fi

say "Fertig."
