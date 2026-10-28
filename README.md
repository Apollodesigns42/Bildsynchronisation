# Bildsynchronisation – eigene Foto-Cloud statt Google Fotos

Dieses Repository richtet eine eigene Foto-Cloud ein, die Google Fotos und iCloud Fotos ersetzt.
Grundlage ist **[Immich](https://immich.app)**, ein aktiv entwickeltes Open-Source-Projekt, das für genau diesen
Zweck gebaut ist. Immich läuft auf einem **Mini-PC bei dir zu Hause**. Dein **VPS** stellt die Adresse im Internet
(HTTPS) bereit und leitet über einen verschlüsselten Tunnel nach Hause weiter. Ein Backup geht jede Nacht auf eine
**Hetzner Storage Box**.

## Was du bekommst

| Wunsch | Umsetzung |
|---|---|
| Handy-Bilder automatisch synchronisieren | Immich-App für **Android** und **iOS** mit automatischem Hintergrund-Backup |
| Kategorisierung nach **Personen** | Gesichtserkennung läuft auf deinem Mini-PC, Personen benennen, zusammenführen, nach Person filtern |
| Kategorisierung nach **Orten** | GPS-Daten aus den Fotos → Weltkarte und Orts-Übersicht (Stadt/Land), Suche nach Orten |
| Kategorisierung nach **Aufnahmedatum** | Zeitleiste mit Sprungleiste nach Jahr/Monat, „Heute vor X Jahren“-Erinnerungen |
| Import von externer Festplatte / Altbeständen | `scripts/import.sh` bzw. `scripts/import.ps1` (Windows), Ordner werden zu Alben, Duplikate werden erkannt |
| Import aus Google Fotos / iCloud | Takeout- bzw. iCloud-Export inkl. Alben, Aufnahmedaten und Ortsdaten |
| Ansicht auf Handy und PC | Responsive Weboberfläche im Browser + native Apps, daheim und unterwegs |
| Extras | Suche per Beschreibung („Hund am Strand“), Alben teilen, Partner-Freigabe, Videos, RAW-Dateien |

Die Fotos liegen physisch bei dir zu Hause. Die KI-Auswertung läuft lokal, nichts geht an Dritte.

## Aufbau

```
                     unterwegs                                   daheim (FritzBox, keine Portfreigabe nötig)
Handy/Browser ──HTTPS──► VPS (IONOS)  ══ WireGuard-Tunnel ══►  Mini-PC: Immich, Fotos, Gesichtserkennung
                        fotos.deine-domain.de                    ▲                          │
                        nur Weiterleitung                        │ Heimnetz direkt          │ nachts Backup
                                                       Handy im WLAN, PC-Import             ▼
                                                                                  Hetzner Storage Box
```

- Der **Mini-PC baut den Tunnel selbst zum VPS auf**. An der FritzBox muss nichts freigegeben werden.
- Über den Tunnel erreicht der VPS **nur Immich** (Port 2283), nicht SSH oder andere Dienste des Mini-PCs.
- Im Heimnetz sprechen Handy und PC den Mini-PC direkt an. Das ist schnell und belastet den Internet-Upload nicht.
- Unterwegs reicht der Upload deines Anschlusses (z.B. 20 Mbit/s) gut für Vorschaubilder, Fotos und Videos in 720p.

| Ordner / Datei | Läuft auf | Zweck |
|---|---|---|
| `heimserver/docker-compose.yml` | Mini-PC | Offizielle Immich-Dienste |
| `heimserver/install.sh` | Mini-PC | Ersteinrichtung, erzeugt `.env` mit sicherem DB-Passwort |
| `heimserver/tunnel.sh` | Mini-PC | Spielt die WireGuard-Konfiguration ein |
| `heimserver/backup.sh` | Mini-PC | Nächtliche Sicherung auf die Storage Box |
| `heimserver/update.sh` | Mini-PC | Immich aktualisieren |
| `vps/setup.sh` | VPS | WireGuard-Tunnel + HTTPS-Weiterleitung (Caddy, falls Port 80/443 frei) |
| `docs/reverse-proxy.md` | VPS | Weiterleitung, falls auf dem VPS schon ein Webserver läuft |
| `scripts/import.sh` / `scripts/import.ps1` | dein PC | Import von Festplatte, Google-Takeout oder iCloud-Export |

## Einkaufsliste

**Mini-PC** mit Intel **N100/N150**, z.B. Beelink EQ12 / S12 Pro, GMKtec G3 Plus oder Minisforum UN100:

| | Empfehlung |
|---|---|
| RAM | **16 GB** (8 GB gehen auch, 16 GB lassen Luft für die Gesichtserkennung) |
| System-SSD | eingebaut, 256–512 GB reichen |
| Foto-Speicher | **1–2 TB SSD**. Ideal ist ein Modell mit freiem 2,5"-SATA- oder zweitem M.2-Steckplatz. Bei 150 GB Fotos reicht 1 TB viele Jahre, 2 TB geben Reserve. |
| Preis | ca. 150–220 € + ca. 60–120 € für die SSD |
| Strom | ca. 6–10 W, das sind etwa 20–25 € pro Jahr |

Ein Raspberry Pi 5 funktioniert auch, ist aber langsamer bei der Gesichtserkennung. Mit SSD-Aufsatz, Netzteil und
Gehäuse kostet er kaum weniger.

**Hetzner Storage Box** BX11 (1 TB, ca. 4 €/Monat) für das Backup außer Haus.

**Domain**: eine Subdomain wie `fotos.deine-domain.de`, deren DNS-A-Eintrag auf die IP des VPS zeigt.

## Installation

### 1. Mini-PC vorbereiten

1. **Ubuntu Server 24.04 LTS** installieren (USB-Stick mit [Ubuntu Server](https://ubuntu.com/download/server)).
   Dabei „OpenSSH Server“ ankreuzen, dann geht alles Weitere bequem vom Desktop-PC aus per `ssh`.
2. Die Foto-SSD formatieren und dauerhaft einhängen, z.B. unter `/mnt/fotos`
   (Anleitung: [Ubuntu-Wiki fstab](https://wiki.ubuntuusers.de/fstab/)).
3. **FritzBox**: *Heimnetz → Netzwerk → Mini-PC bearbeiten →* „Diesem Netzwerkgerät immer die gleiche IPv4-Adresse
   zuweisen“. Eine Portfreigabe ist **nicht** nötig.
4. **BIOS** des Mini-PCs: „Restore on AC Power Loss“ bzw. „Power On after Power Failure“ auf **Power On** stellen.
   Dann startet er nach einem Stromausfall von selbst wieder.

### 2. Immich auf dem Mini-PC installieren

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

git clone https://github.com/apollodesigns42/bildsynchronisation.git
cd bildsynchronisation/heimserver
./install.sh            # Speicherort für Fotos: /mnt/fotos
```

Danach im Browser `http://<IP des Mini-PCs>:2283` öffnen und **sofort registrieren. Der erste Benutzer wird
Administrator.** Weitere Benutzer (z.B. Familie) legst du anschließend unter *Administration → Benutzer* an.

### 3. VPS: Tunnel und HTTPS einrichten

**DNS**: Beim Domain-Anbieter einen A-Eintrag `fotos` → IP des VPS anlegen.

**IONOS-Firewall**: Im IONOS Cloud Panel unter *Netzwerk → Firewall-Richtlinien* den Port **UDP 51820** freigeben.
Für Caddy zusätzlich TCP 80 und 443, sofern noch nicht offen. `setup.sh` zeigt am Ende den genauen Port an.

```bash
git clone https://github.com/apollodesigns42/bildsynchronisation.git
cd bildsynchronisation/vps
sudo ./setup.sh         # fragt die Domain ab
```

Das Skript:
- installiert WireGuard und richtet den Tunnel ein (VPS = `10.77.0.1`, Mini-PC = `10.77.0.2`). Es nutzt einen
  eigenen Netzbereich, damit sich nichts mit vorhandenen VPNs überschneidet.
- startet **Caddy** mit automatischem HTTPS-Zertifikat, wenn Port 80/443 frei sind. Läuft dort schon ein
  Webserver, zeigt es an, was du eintragen musst ([docs/reverse-proxy.md](docs/reverse-proxy.md),
  Ziel `http://10.77.0.2:2283`).
- erzeugt die Datei `heimserver-wg.conf` für den Mini-PC.

### 4. Tunnel auf dem Mini-PC einspielen

`heimserver-wg.conf` vom VPS auf den Mini-PC kopieren (z.B. per `scp` oder USB-Stick), dann:

```bash
cd bildsynchronisation/heimserver
sudo ./tunnel.sh ~/heimserver-wg.conf
rm ~/heimserver-wg.conf               # enthält einen privaten Schlüssel
```

Danach die Datei auch auf dem VPS löschen. Jetzt ist `https://fotos.deine-domain.de` von überall erreichbar.

### 5. Empfohlene Einstellungen nach dem ersten Login

Unter *Administration → Einstellungen*:

1. **Server → Externe Domain**: `https://fotos.deine-domain.de` eintragen, damit geteilte Links die richtige Adresse
   bekommen.
2. **Gesichtserkennung**: ist standardmäßig aktiv. Nach dem ersten großen Import läuft sie auf dem N100 je nach
   Bildanzahl ein bis zwei Tage. Fortschritt unter *Administration → Aufträge*. Danach unter *Erkunden → Personen*
   die Personen benennen.
3. **Reverse-Geocoding** (Ortsnamen aus GPS) und **Karte** sind standardmäßig aktiv.
4. **Speichervorlage** (optional): aktivieren, damit die Dateien nach Datum abgelegt werden, z.B.
   `{{y}}/{{y}}-{{MM}}/{{filename}}`. So bleibt die Ordnerstruktur auch ohne Immich verständlich.

## Handy einrichten (Auto-Sync)

1. App **„Immich“** installieren ([Android/Play Store](https://play.google.com/store/apps/details?id=app.alextran.immich),
   [F-Droid](https://f-droid.org/packages/app.alextran.immich/), [iOS/App Store](https://apps.apple.com/app/immich/id1613945652))
2. Server-URL eingeben: `https://fotos.deine-domain.de` und anmelden
3. **Automatische URL-Umschaltung** (App-Einstellungen → Netzwerk): dein WLAN-Name + lokale Adresse
   `http://<IP des Mini-PCs>:2283`. Daheim lädt die App dann direkt im Heimnetz hoch, unterwegs über den VPS.
   Auf dem iPhone braucht die App dafür die Standort-Berechtigung, sonst kann sie den WLAN-Namen nicht lesen.
4. Oben rechts auf das Wolken-Symbol tippen → **Alben auswählen**, die gesichert werden sollen (z.B. „Kamera“)
5. **Vordergrund- und Hintergrund-Backup** aktivieren. Optional „Nur im WLAN“ und „Nur beim Laden“.
6. Android: Akku-Optimierung für Immich deaktivieren. iPhone: iOS lädt im Hintergrund nur, wenn es das System
   erlaubt (meist nachts beim Laden). Die App ab und zu öffnen beschleunigt das.

## Import von externer Festplatte oder Altbeständen

Der Import läuft auf dem **PC, an dem die Festplatte hängt**, und lädt auf den Mini-PC hoch. Daheim trägst du in
`import.env` am besten die lokale Adresse ein (`IMMICH_SERVER=http://192.168.178.xx:2283`). Dann läuft der Import mit
voller Heimnetz-Geschwindigkeit und nicht über den Internet-Upload.
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

1. **Mini-PC + Backup einrichten** (`heimserver/backup.sh`, siehe unten). Ohne Backup wäre der Mini-PC sonst die einzige Kopie.
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

## Backup auf die Hetzner Storage Box

Eine Foto-Cloud ohne Backup ist kein Backup. Der Mini-PC sichert jede Nacht auf die Storage Box.

**Einmalig einrichten** (auf dem Mini-PC, als root, weil die Immich-Dateien root gehören):

1. In der Hetzner Console bei der Storage Box **SSH-Support** und **externe Erreichbarkeit** aktivieren, außerdem
   **automatische Snapshots** (z.B. täglich, 14 behalten). Die Snapshots schützen auch vor versehentlichem Löschen.
2. SSH-Schlüssel anlegen und hinterlegen (`uXXXXXX` = dein Storage-Box-Benutzer):

   ```bash
   sudo ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519
   sudo ssh-copy-id -p 23 -s -i /root/.ssh/id_ed25519 uXXXXXX@uXXXXXX.your-storagebox.de
   ```

3. Kurzname in `/root/.ssh/config` eintragen:

   ```
   Host storagebox
       HostName uXXXXXX.your-storagebox.de
       User uXXXXXX
       Port 23
   ```

4. Erstes Backup starten. Bei 150 GB und 20 Mbit/s Upload dauert es etwa einen Tag. Mit `BWLIMIT` bleibt
   daneben genug Upload für den normalen Gebrauch übrig:

   ```bash
   cd bildsynchronisation/heimserver
   sudo BWLIMIT=1500 ./backup.sh storagebox:immich
   ```

5. Automatisch jede Nacht um 3 Uhr (`sudo crontab -e`):

   ```
   0 3 * * * /home/<benutzer>/bildsynchronisation/heimserver/backup.sh storagebox:immich >> /var/log/immich-backup.log 2>&1
   ```

Danach werden nur noch neue Dateien übertragen. Das Skript erstellt vorher einen aktuellen Datenbank-Dump und
sichert Originale, Datenbank-Dumps und Profilbilder. Vorschaubilder und umgewandelte Videos lässt es aus, Immich
erzeugt sie bei Bedarf neu. Zusätzlich auf eine USB-Festplatte geht es mit `sudo ./backup.sh /media/usb-platte/immich`.

Wiederherstellung der Datenbank: siehe [Immich-Doku „Backup and Restore“](https://docs.immich.app/administration/backup-and-restore).

## Update

```bash
cd bildsynchronisation/heimserver && ./update.sh
```

`IMMICH_VERSION=v3` in `.env` aktualisiert automatisch innerhalb der Hauptversion 3. Vor einem Wechsel auf eine neue
Hauptversion die [Release Notes](https://github.com/immich-app/immich/releases) lesen und vorher ein Backup machen.
Das Betriebssystem hältst du mit `sudo apt update && sudo apt upgrade` aktuell. Für automatische
Sicherheitsupdates `sudo apt install unattended-upgrades` auf Mini-PC und VPS.

## Nützliche Befehle

```bash
# Mini-PC (im Ordner heimserver/)
docker compose ps                              # Status aller Dienste
docker compose logs -f immich-server           # Server-Logs
docker compose logs immich-machine-learning    # Gesichtserkennung
sudo wg show                                   # Tunnel-Status (letzter Handshake < 2 Minuten = ok)

# VPS
sudo wg show                                   # Tunnel-Status
curl -sI http://10.77.0.2:2283                 # Erreicht der VPS Immich durch den Tunnel?
cd bildsynchronisation/vps && docker compose logs caddy   # HTTPS/Zertifikat (falls Caddy genutzt wird)
```

## Fehlerbehebung

- **Daheim geht's, unterwegs nicht**: Auf dem VPS `sudo wg show` aufrufen. Fehlt „latest handshake“, ist UDP 51820
  in der IONOS-Firewall nicht freigegeben, oder der Tunnel auf dem Mini-PC läuft nicht
  (`sudo systemctl status wg-quick@wg-fotos`). Steht der Tunnel, aber die Seite lädt nicht: `curl -sI http://10.77.0.2:2283`
  auf dem VPS prüfen, dann die Webserver-Konfiguration ([docs/reverse-proxy.md](docs/reverse-proxy.md)).
- **Zertifikatsfehler**: DNS-Eintrag prüfen (`dig fotos.deine-domain.de`), sind TCP 80/443 in der IONOS-Firewall offen?
- **Gesichter werden nicht erkannt**: *Administration → Aufträge → Gesichtserkennung → Fehlende*.
- **Falsches Datum bei alten Bildern**: Fehlen EXIF-Daten, liest immich-go das Datum aus dem Dateinamen. In der
  Weboberfläche lässt sich das Datum mehrerer Bilder gleichzeitig korrigieren (Auswahl → „Datum ändern“).
- **Mehr Tempo auf dem N100** (optional): Immich kann die Grafikeinheit des N100 für Videos (Quick Sync) und
  Gesichtserkennung (OpenVINO) nutzen, siehe [Hardware-Transkodierung](https://docs.immich.app/features/hardware-transcoding)
  und [ML-Beschleunigung](https://docs.immich.app/features/ml-hardware-acceleration).
