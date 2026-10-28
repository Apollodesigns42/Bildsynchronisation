# Bildsynchronisation – eigene Foto-Cloud statt Google Fotos

Dieses Repository richtet auf einem eigenen VPS eine vollständige Foto-Cloud ein, die Google Fotos ersetzt.
Grundlage ist **[Immich](https://immich.app)**, ein aktiv entwickeltes Open-Source-Projekt, das für genau diesen
Zweck gebaut ist. Dieses Repo liefert die fertige Server-Konfiguration (inkl. HTTPS), Import-Skripte für
externe Festplatten und Google-Takeout sowie Backup- und Update-Skripte.

## Was du bekommst

| Wunsch | Umsetzung |
|---|---|
| Handy-Bilder automatisch auf den VPS synchronisieren | Immich-App für **Android** und **iOS** mit automatischem Hintergrund-Backup (auch nur im WLAN) |
| Kategorisierung nach **Personen** | Gesichtserkennung läuft lokal auf deinem Server, Personen benennen, zusammenführen, nach Person filtern |
| Kategorisierung nach **Orten** | GPS-Daten aus den Fotos → Weltkarte und Orts-Übersicht (Stadt/Land), Suche nach Orten |
| Kategorisierung nach **Aufnahmedatum** | Zeitleiste mit Sprungleiste nach Jahr/Monat, „Heute vor X Jahren“-Erinnerungen |
| Import von externer Festplatte / Altbeständen | `scripts/import.sh` bzw. `scripts/import.ps1` (Windows), Ordner werden zu Alben, Duplikate werden erkannt |
| Import aus Google Fotos | Google-Takeout-Import inkl. Alben, Aufnahmedaten und Ortsdaten aus den JSON-Dateien |
| Ansicht auf Handy und PC | Responsive Weboberfläche im Browser + native Apps |
| Extras | Suche per Beschreibung („Hund am Strand“), Alben teilen, Partner-Freigabe, Videos, RAW-Dateien |

Alle Daten und die KI-Auswertung bleiben auf deinem Server, nichts geht an Dritte.

## Aufbau

```
Handy-App ─┐                       VPS (Docker)
Browser  ──┼── HTTPS ──► Caddy ──► immich-server ──► Fotos (UPLOAD_LOCATION)
PC-Import ─┘   (443)   (Zertifikat) │                PostgreSQL (Metadaten)
                                    └─► machine-learning (Gesichter, Suche)
```

| Datei | Zweck |
|---|---|
| `docker-compose.yml` | Offizielle Immich-Dienste + Caddy als HTTPS-Reverse-Proxy |
| `Caddyfile` | Holt automatisch ein Let's-Encrypt-Zertifikat für deine Domain |
| `docs/reverse-proxy.md` | Anbindung an einen bereits laufenden Webserver (nginx, Apache, …) |
| `.env.example` | Vorlage für die Server-Konfiguration |
| `scripts/install.sh` | Ersteinrichtung auf dem VPS |
| `scripts/import.sh` / `scripts/import.ps1` | Import von Festplatte, Ordner oder Google-Takeout (Linux/macOS bzw. Windows) |
| `scripts/backup.sh` | Sicherung von Fotos + Datenbank |
| `scripts/update.sh` | Aktualisierung auf neue Immich-Version |

## Voraussetzungen

- **VPS** mit Linux (z.B. Ubuntu 24.04 / Debian 12)
  - mind. **4 GB RAM** (6–8 GB empfohlen, die Gesichtserkennung braucht Speicher), 2+ CPU-Kerne
  - **Speicherplatz**: Größe deiner Fotosammlung plus ca. 20 % für Vorschaubilder.
    Reicht die VPS-Platte nicht, ein zusätzliches Block-Storage-Volume einhängen und `UPLOAD_LOCATION` dorthin zeigen lassen.
- Eine **Domain/Subdomain** (z.B. `fotos.deinedomain.de`), deren DNS-A-Eintrag auf die IP des VPS zeigt
- Offene Ports **80** und **443**

## Installation auf dem VPS

```bash
# 1. Docker installieren (falls noch nicht vorhanden)
curl -fsSL https://get.docker.com | sh

# 2. Repository holen
git clone https://github.com/apollodesigns42/bildsynchronisation.git
cd bildsynchronisation

# 3. Einrichten und starten (fragt Domain und Speicherort ab, erzeugt ein sicheres DB-Passwort)
./scripts/install.sh
```

### Läuft auf dem Server schon etwas?

Kein Problem, Immich läuft komplett in eigenen Docker-Containern mit eigener Datenbank und stört
andere Dienste nicht. Konflikte kann es nur bei Ports geben, und darum kümmert sich `install.sh`:

- **Port 80/443 belegt** (es läuft schon ein Webserver wie nginx, Apache, Traefik …): Der mitgelieferte
  Caddy wird nicht gestartet. Stattdessen trägst du die Foto-Domain in deinem bestehenden Webserver ein,
  Anleitungen für nginx, Apache, Caddy und Docker-Proxys stehen in [docs/reverse-proxy.md](docs/reverse-proxy.md).
- **Port 2283 belegt**: Immich nimmt automatisch den nächsten freien Port (steht dann als `IMMICH_PORT` in `.env`).
- **Ressourcen**: Immich braucht im Betrieb ca. 2–4 GB RAM, beim ersten Durchlauf der Gesichtserkennung mehr.
  Mit `free -h` und `df -h` prüfen, ob neben den bestehenden Diensten genug frei ist.

Danach `https://fotos.deinedomain.de` im Browser öffnen. **Der erste registrierte Benutzer wird Administrator.**
Diesen Schritt direkt nach der Installation erledigen. Weitere Benutzer (z.B. Familie) legst du anschließend unter
*Administration → Benutzer* an.

Firewall (empfohlen, falls `ufw` genutzt wird):

```bash
ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 443/udp && ufw enable
```

> Hinweis: Docker öffnet veröffentlichte Ports an `ufw` vorbei. Deshalb ist Immich selbst (Port 2283) in
> `docker-compose.yml` nur an `127.0.0.1` gebunden. Von außen ist ausschließlich Caddy über HTTPS erreichbar.

## Empfohlene Einstellungen nach dem ersten Login

Unter *Administration → Einstellungen*:

1. **Gesichtserkennung**: ist standardmäßig aktiv. Nach dem ersten großen Import unter *Administration → Aufträge*
   prüfen, dass „Gesichtserkennung“ durchläuft. Danach unter *Erkunden → Personen* die Personen benennen.
2. **Reverse-Geocoding** (Ortsnamen aus GPS): standardmäßig aktiv, funktioniert offline.
3. **Karte**: standardmäßig aktiv.
4. **Speichervorlage** (optional): *Administration → Einstellungen → Speichervorlage* aktivieren, damit die Dateien
   auf dem Server nach Datum abgelegt werden, z.B. `{{y}}/{{y}}-{{MM}}/{{filename}}`. So bleibt die Ordnerstruktur
   auch ohne Immich verständlich.

## Handy einrichten (Auto-Sync)

1. App **„Immich“** installieren ([Android/Play Store](https://play.google.com/store/apps/details?id=app.alextran.immich),
   [F-Droid](https://f-droid.org/packages/app.alextran.immich/), [iOS/App Store](https://apps.apple.com/app/immich/id1613945652))
2. Server-URL eingeben: `https://fotos.deinedomain.de` und anmelden
3. Oben rechts auf das Wolken-Symbol tippen → **Alben auswählen**, die gesichert werden sollen (z.B. „Kamera“)
4. **Vordergrund- und Hintergrund-Backup** aktivieren. Optional „Nur im WLAN“ und „Nur beim Laden“.
5. Android: Akku-Optimierung für Immich deaktivieren, damit das Hintergrund-Backup zuverlässig läuft.

Erst wenn alles sicher auf dem Server liegt, kannst du die Google-Fotos-Synchronisation auf dem Handy abschalten.

## Import von externer Festplatte oder Altbeständen

Der Import läuft auf dem **PC, an dem die Festplatte hängt**, und lädt über HTTPS auf den Server hoch.
Dafür wird [immich-go](https://github.com/simulot/immich-go) verwendet. Es übernimmt Aufnahmedatum und GPS aus den
Metadaten, erkennt Duplikate und stapelt RAW+JPEG- und Serienbilder.

**Vorbereitung (einmalig):**

1. Dieses Repo auch auf den PC klonen (oder als ZIP herunterladen)
2. `immich-go` für dein System von der [Release-Seite](https://github.com/simulot/immich-go/releases) herunterladen und entpacken
   - Windows: `immich-go.exe` in den Ordner `scripts/` legen
   - Linux/macOS: Datei z.B. nach `/usr/local/bin/` kopieren
3. In der Immich-Weboberfläche: *Profilbild → Kontoeinstellungen → API-Schlüssel → Neuer API-Schlüssel*
4. `import.env.example` nach `import.env` kopieren und Server-Adresse sowie API-Schlüssel eintragen

**Import von Festplatte / Ordner** (jeder Unterordner wird zu einem Album):

```bash
# Linux/macOS
./scripts/import.sh ordner /media/externe-platte/Fotos --dry-run   # erst testen
./scripts/import.sh ordner /media/externe-platte/Fotos
```

```powershell
# Windows (PowerShell)
.\scripts\import.ps1 ordner E:\Fotos --dry-run
.\scripts\import.ps1 ordner E:\Fotos
```

Ein abgebrochener Import kann einfach erneut gestartet werden. Bereits hochgeladene Dateien werden übersprungen.

### Umzug aus Google Fotos

1. Auf [takeout.google.com](https://takeout.google.com) nur **Google Fotos** auswählen, Format **ZIP**, Größe z.B. 50 GB
2. Alle ZIP-Teile herunterladen (nicht entpacken)
3. Alle Teile **in einem Aufruf** importieren, damit Fotos und ihre Metadaten-Dateien zusammengeführt werden:

```bash
./scripts/import.sh google ~/Downloads/takeout-*.zip
```

```powershell
.\scripts\import.ps1 google C:\Downloads\takeout-001.zip C:\Downloads\takeout-002.zip
```

Google-Alben werden als Alben übernommen. Aufnahmedatum und Ort kommen aus den JSON-Dateien von Google.

### Umzug aus iCloud

Am einfachsten lädt die Immich-App auf dem iPhone alles direkt hoch (siehe unten, Abschnitt „Abschied von Google Fotos /
iCloud“). Alternativ: Auf [privacy.apple.com](https://privacy.apple.com) → „Kopie deiner Daten anfordern“ → „iCloud-Fotos“,
die Teile herunterladen, entpacken und importieren:

```bash
./scripts/import.sh icloud ~/Downloads/iCloud-Fotos
```

## Abschied von Google Fotos / iCloud – sichere Reihenfolge

Erst löschen, wenn **alles** nachweislich auf dem Server liegt **und** ein Backup existiert:

1. **Server + Backup einrichten** (`scripts/backup.sh`, siehe unten). Ohne Backup wäre der VPS sonst die einzige Kopie.
2. **Komplettexport importieren** (Google Takeout bzw. iCloud-Export). In der Cloud liegen oft Bilder, die nicht mehr auf
   dem Handy sind (alte Handys, „Speicher freigeben“, „iPhone-Speicher optimieren“).
3. **Handy-App einrichten** und warten, bis der Backup-Bildschirm der App „0 verbleibend“ zeigt.
4. **Stichproben**: Anzahl der Fotos vergleichen, alte Jahrgänge und Videos öffnen.
5. **Cloud-Sync abschalten** und einige Wochen parallel laufen lassen. Den Takeout-/iCloud-Export als zusätzliche Kopie aufheben.
6. **Erst dann in der Cloud löschen**:
   - **Google**: zuerst in der Google-Fotos-App „Backup“ ausschalten, dann auf [photos.google.com](https://photos.google.com)
     löschen und danach den Papierkorb leeren. Nicht in der App löschen, das entfernt die Bilder auch vom Handy.
     Danach die Galerie auf dem Handy kontrollieren.
   - **iCloud**: Auf dem iPhone *Einstellungen → Apple-ID → iCloud → Fotos* ausschalten und dabei **„Fotos und Videos laden“**
     wählen, nicht „Vom iPhone entfernen“. Bei aktiver Option „iPhone-Speicher optimieren“ vorher
     „Laden und Originale behalten“ einstellen und warten, bis alles heruntergeladen ist (Speicherplatz prüfen!).
     Zum Schluss *iCloud → Speicher verwalten → Fotos → „Deaktivieren und löschen“* (30 Tage Wiederherstellungsfrist).

## Backup

Eine Foto-Cloud ohne Backup ist kein Backup. Halte mindestens eine zweite Kopie außerhalb des VPS vor.

```bash
# auf dem VPS: auf ein eingehängtes Laufwerk oder per SSH auf einen anderen Rechner
./scripts/backup.sh /mnt/backup/immich
./scripts/backup.sh user@backup-server:/backups/immich
```

Das Skript erstellt einen aktuellen Datenbank-Dump und spiegelt Originale, Datenbank-Dumps und Profilbilder per
`rsync`. Vorschaubilder und transkodierte Videos werden ausgelassen, Immich erzeugt sie bei Bedarf neu.
Immich legt außerdem selbst täglich Datenbank-Dumps unter `UPLOAD_LOCATION/backups` an.

Automatisch jede Nacht um 3 Uhr (`crontab -e`):

```
0 3 * * * /pfad/zu/bildsynchronisation/scripts/backup.sh user@backup-server:/backups/immich >> /var/log/immich-backup.log 2>&1
```

Für die Sicherung auf eine externe Festplatte daheim kannst du alternativ vom Heim-PC aus ziehen:
`rsync -a --exclude thumbs/ --exclude encoded-video/ root@vps:/pfad/zu/library/ /media/externe-platte/immich/`

Wiederherstellung der Datenbank: siehe [Immich-Doku „Backup and Restore“](https://docs.immich.app/administration/backup-and-restore).

## Update

```bash
./scripts/update.sh
```

`IMMICH_VERSION=v3` in `.env` aktualisiert automatisch innerhalb der Hauptversion 3. Vor einem Wechsel auf eine neue
Hauptversion die [Release Notes](https://github.com/immich-app/immich/releases) lesen und vorher ein Backup machen.

## Nützliche Befehle

```bash
docker compose ps                     # Status aller Dienste
docker compose logs -f immich-server  # Server-Logs
docker compose logs caddy             # Probleme mit HTTPS/Zertifikat
docker compose restart                # Neustart
```

## Fehlerbehebung

- **Seite nicht erreichbar / Zertifikatsfehler**: DNS-Eintrag prüfen (`dig fotos.deinedomain.de`), Ports 80/443 offen?
  `docker compose logs caddy` zeigt, ob das Zertifikat geholt werden konnte.
- **Gesichter werden nicht erkannt**: *Administration → Aufträge → Gesichtserkennung → Alle*. Bei wenig RAM kann der
  Machine-Learning-Container abstürzen (`docker compose logs immich-machine-learning`), dann mehr RAM/Swap einplanen.
- **Falsches Datum bei alten Bildern**: Fehlen EXIF-Daten, liest immich-go das Datum aus dem Dateinamen. In der
  Weboberfläche lässt sich das Datum mehrerer Bilder gleichzeitig korrigieren (Auswahl → „Datum ändern“).
