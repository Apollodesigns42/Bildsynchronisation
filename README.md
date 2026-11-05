# Bildsynchronisation – eigene Foto-Cloud und Cloud-Speicher

Dieses Repository richtet eine eigene Foto-Cloud ein, die Google Fotos und iCloud Fotos ersetzt, und optional einen
eigenen Cloud-Speicher als Ersatz für MEGA, Dropbox & Co.

- **Fotos**: **[Immich](https://immich.app)**, ein aktiv entwickeltes Open-Source-Projekt, das genau für diesen Zweck gebaut ist
- **Dateien**: **[OpenCloud](https://opencloud.eu)**, eine schlanke Open-Source-Dateicloud mit PC-Sync-Programm und Handy-Apps

Beides läuft auf einem **Mini-PC bei dir zu Hause**. Dein **VPS** stellt die Adressen im Internet (HTTPS) bereit und
leitet über einen verschlüsselten Tunnel nach Hause weiter. Ein **verschlüsseltes Backup** geht jede Nacht auf eine
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
| Eigener Cloud-Speicher statt MEGA | OpenCloud: Ordner-Sync auf PC/Mac, Handy-Apps, Weboberfläche, Freigabe-Links mit Passwort |
| Dokumentenverwaltung | Paperless-ngx: Texterkennung, Volltextsuche, automatische Einordnung, Scannen per Browser, E-Mail-Import |
| Rezepte & Einkaufsliste | Mealie: Rezepte per Link importieren, Wochenplan, gemeinsame Einkaufsliste |
| Werbeblocker fürs Heimnetz | AdGuard Home: filtert Werbung und Tracking für alle Geräte zu Hause |
| Überwachung von außen | Uptime Kuma auf dem VPS: Push-Nachricht aufs Handy, wenn ein Dienst ausfällt |
| Passwortmanager | Vaultwarden: kompatibel mit den Bitwarden-Apps, gemeinsame Tresore für die Familie |
| Smart-Home-Zentrale | Home Assistant: alle smarten Geräte in einer App, herstellerübergreifende Automationen |
| Startseite | Homepage: Links und Status aller Dienste auf einen Blick (nur Heimnetz) |
| Backup | Nächtlich, verschlüsselt und mit mehreren Versionen (restic) auf die Hetzner Storage Box |

Die Daten liegen physisch bei dir zu Hause. Die KI-Auswertung läuft lokal, nichts geht an Dritte.

## Aufbau

```
                     unterwegs                                   daheim (FritzBox, keine Portfreigabe nötig)
Handy/Browser ──HTTPS──► VPS (IONOS)  ══ WireGuard-Tunnel ══►  Mini-PC
                        fotos.deine-domain.de ──────────────►    Immich    (Port 2283)
                        cloud.deine-domain.de ──────────────►    OpenCloud (Port 9200)
                        dokumente.deine-domain.de ──────────►    Paperless (Port 8000)
                        rezepte.deine-domain.de ────────────►    Mealie    (Port 9925)
                        nur Weiterleitung                               │
                                                                        │ nachts, verschlüsselt
                                                                        ▼
                                                               Hetzner Storage Box
```

- Der **Mini-PC baut den Tunnel selbst zum VPS auf**. An der FritzBox muss nichts freigegeben werden.
- Über den Tunnel erreicht der VPS **nur Immich und OpenCloud**, nicht SSH oder andere Dienste des Mini-PCs.
- **Fotos** sprechen Handy und PC im Heimnetz direkt an. Das ist schnell und belastet den Internet-Upload nicht.
- **Cloud-Dateien** laufen immer über die Domain, auch daheim. OpenCloud braucht für die Anmeldung immer dieselbe
  Adresse. Daheim ist der Cloud-Zugriff deshalb auf etwa die Upload-Geschwindigkeit des Anschlusses begrenzt
  (20 Mbit/s ≈ 2,5 MB/s). Für Dokumente merkt man das nicht. Der erste Upload von 40 GB dauert etwa 5 Stunden.
- Unterwegs reicht der Upload deines Anschlusses gut für Vorschaubilder, Fotos, Videos in 720p und Dokumente.

| Ordner / Datei | Läuft auf | Zweck |
|---|---|---|
| `heimserver/docker-compose.yml` | Mini-PC | Offizielle Immich-Dienste |
| `heimserver/install.sh` | Mini-PC | Ersteinrichtung Immich, erzeugt `.env` mit sicherem DB-Passwort |
| `heimserver/cloud/` | Mini-PC | OpenCloud: `docker-compose.yml` + `install.sh` |
| `heimserver/dokumente/` | Mini-PC | Paperless-ngx + Scannen per Browser: `docker-compose.yml` + `install.sh` |
| `heimserver/rezepte/` | Mini-PC | Mealie (Rezepte, Wochenplan, Einkaufsliste): `docker-compose.yml` + `install.sh` |
| `heimserver/adguard/` | Mini-PC | AdGuard Home (nur Heimnetz): `docker-compose.yml` + `install.sh` |
| `vps/uptime-kuma/` | VPS | Uptime Kuma: überwacht alle Dienste von außen |
| `heimserver/passwoerter/` | Mini-PC | Vaultwarden: `docker-compose.yml`, `install.sh`, `registrierung.sh` |
| `heimserver/smarthome/` | Mini-PC | Home Assistant: `docker-compose.yml` + `install.sh` |
| `heimserver/startseite/` | Mini-PC | Homepage (nur Heimnetz): `docker-compose.yml` + `install.sh` |
| `heimserver/tunnel.sh` | Mini-PC | Spielt die WireGuard-Konfiguration ein |
| `heimserver/backup.sh` | Mini-PC | Nächtliches verschlüsseltes Backup (Fotos, Cloud, Dokumente) auf die Storage Box |
| `heimserver/check.sh` | Mini-PC | Täglicher Gesundheits-Check mit E-Mail bei Problemen |
| `heimserver/update.sh` | Mini-PC | Immich, OpenCloud und Paperless aktualisieren |
| `vps/setup.sh` | VPS | WireGuard-Tunnel + HTTPS-Weiterleitung (Caddy, falls Port 80/443 frei) |
| `docs/reverse-proxy.md` | VPS | Weiterleitung, falls auf dem VPS schon ein Webserver läuft |
| `docs/fahrplan.md` | – | Reihenfolge der noch offenen Schritte und Übersicht der Domains |
| `scripts/import.sh` / `scripts/import.ps1` | dein PC | Import von Festplatte, Google-Takeout oder iCloud-Export |

## Einkaufsliste

**Mini-PC** mit Intel **N100/N150**, z.B. Beelink EQ12 / S12 Pro, GMKtec G3 Plus oder Minisforum UN100:

| | Empfehlung |
|---|---|
| RAM | **8 GB** reichen für Immich + OpenCloud (zusammen ca. 4–6 GB). Mit Paperless wird es knapp, dann **16 GB** |
| System-SSD | eingebaut, 256–512 GB reichen |
| Daten-Platte | **1–2 TB**. Ideal ist ein Modell mit zweitem Steckplatz (2,5"-SATA oder M.2). Eine Festplatte (HDD) reicht völlig, das Internet ist ohnehin langsamer; Datenbank und Vorschaubilder liegen auf der System-SSD. Eine SSD ist nur leiser und sparsamer. Bei 150 GB Fotos + 40 GB Cloud reicht 1 TB einige Jahre. |
| Preis | ca. 150–220 € + ca. 60–120 € für die SSD |
| Strom | ca. 6–10 W, das sind etwa 20–25 € pro Jahr |

Ein Raspberry Pi 5 funktioniert auch, ist aber langsamer bei der Gesichtserkennung. Mit SSD-Aufsatz, Netzteil und
Gehäuse kostet er kaum weniger.

**Hetzner Storage Box** BX11 (1 TB, ca. 4 €/Monat) für das Backup außer Haus.

**Domains**: zwei Subdomains wie `fotos.deine-domain.de` und `cloud.deine-domain.de`, deren DNS-A-Einträge auf die IP
des VPS zeigen.

## Installation

### 1. Mini-PC vorbereiten

1. **Ubuntu Server 26.04 LTS** (aktuelle Langzeitversion, Updates bis 2031) installieren (USB-Stick mit [Ubuntu Server](https://ubuntu.com/download/server)).
   Dabei „OpenSSH Server“ ankreuzen, dann geht alles Weitere bequem vom Desktop-PC aus per `ssh`.
2. Die Daten-Platte formatieren und dauerhaft einhängen, z.B. unter `/mnt/daten`
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
./install.sh            # Speicherort für Fotos: /mnt/daten/fotos
```

Datenbank (`postgres/`) und Vorschaubilder (`thumbs/`) bleiben im Repo-Ordner auf der System-SSD, nur die
Originale landen auf der Daten-Platte. So bleibt die Zeitleiste flott, auch wenn die Daten-Platte eine Festplatte ist.

Danach im Browser `http://<IP des Mini-PCs>:2283` öffnen und **sofort registrieren. Der erste Benutzer wird
Administrator.** Weitere Benutzer (z.B. Familie) legst du anschließend unter *Administration → Benutzer* an.

### 3. VPS: Tunnel und HTTPS einrichten

**DNS**: Beim Domain-Anbieter A-Einträge `fotos` und `cloud` → IP des VPS anlegen.

**IONOS-Firewall**: Im IONOS Cloud Panel unter *Netzwerk → Firewall-Richtlinien* den Port **UDP 51820** freigeben.
Für Caddy zusätzlich TCP 80 und 443, sofern noch nicht offen. `setup.sh` zeigt am Ende den genauen Port an.

```bash
git clone https://github.com/apollodesigns42/bildsynchronisation.git
cd bildsynchronisation/vps
sudo ./setup.sh         # fragt Foto- und Cloud-Domain ab (Cloud kann auch später ergänzt werden)
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

### 5. Cloud (OpenCloud) einrichten

```bash
cd bildsynchronisation/heimserver/cloud
./install.sh            # Domain: cloud.deine-domain.de, Speicherort: /mnt/daten/cloud
```

Das Skript zeigt das **Admin-Passwort** einmal an, speichere es im Passwortmanager. Hast du die Cloud-Domain beim
VPS-Setup noch nicht angegeben, führst du `sudo vps/setup.sh` erneut aus und trägst sie nach.

Dann `https://cloud.deine-domain.de` öffnen und als `admin` anmelden. Am besten legst du unter *Benutzer* einen
persönlichen Benutzer für den Alltag an und nutzt `admin` nur für die Verwaltung.

**Programme:** OpenCloud Desktop für Windows, macOS und Linux sowie die OpenCloud-Apps für Android und iOS gibt es
unter [opencloud.eu](https://opencloud.eu/de). Im PC-Programm wählst du Ordner aus, die synchronisiert werden, wie bei MEGA.

**Umzug von MEGA:**
1. Im MEGA-Programm sicherstellen, dass alle Dateien lokal auf dem PC liegen (Sync-Ordner vollständig heruntergeladen).
2. OpenCloud Desktop installieren, anmelden und einen Sync-Ordner anlegen.
3. Die Dateien aus dem MEGA-Ordner in den OpenCloud-Ordner **kopieren**. Der erste Upload läuft über Nacht.
4. Stichproben in der OpenCloud-Weboberfläche machen, dann einige Wochen parallel laufen lassen und erst danach MEGA kündigen.

Freigabe-Links sind standardmäßig nur mit Passwort möglich. Die Foto-Sicherung der OpenCloud-App bleibt aus, darum
kümmert sich Immich.

### 6. Dokumente (Paperless-ngx) einrichten (optional)

[Paperless-ngx](https://docs.paperless-ngx.com) macht aus Scans, Fotos und PDFs ein durchsuchbares Archiv: Texterkennung
(Deutsch und Englisch), Volltextsuche und automatische Zuordnung von Absender, Dokumenttyp und Schlagwörtern. Nach ein
paar Beispielen lernt es selbst mit.

**RAM:** Paperless braucht ca. 1–2 GB. Neben Immich und OpenCloud werden 8 GB damit knapp, 16 GB sind empfehlenswert.

**Vorbereitung:**
- DNS: A-Einträge der Dokumenten-Domain auf den VPS, im Caddyfile des VPS ein Eintrag mit Ziel `10.77.0.2:8000`
  (oder `sudo vps/setup.sh` erneut ausführen und die Domain angeben)
- Netzwerk-Scanner: In der FritzBox eine **feste IP** für den Drucker vergeben. Test im Browser:
  `http://<IP des Druckers>/eSCL/ScannerCapabilities`. Erscheint eine XML-Seite, klappt das Scannen übers Netz.
  Nach der Installation prüft `docker exec scanservjs scanimage -d escl:http://<IP>:80 -A`, ob der Scan-Dienst den
  Drucker erreicht (es erscheint eine Liste mit `--mode`, `--resolution` …).

```bash
cd bildsynchronisation/heimserver/dokumente
./install.sh            # Domain, Speicherort (/mnt/daten/dokumente), IP des Scanners
```

Das Skript zeigt das **Admin-Passwort** einmal an, speichere es im Passwortmanager. Nach der Anmeldung als `admin`:
1. **Zwei-Faktor-Anmeldung aktivieren** (Profil oben rechts). In Paperless landen Steuer, Verträge und Ausweise.
2. Unter *Benutzer & Gruppen* einen persönlichen Benutzer für den Alltag anlegen.

**Dokumente hineinbekommen:**

| Weg | So geht's |
|---|---|
| **Scanner (Heimnetz)** | Dokument auflegen, im Browser `http://<IP des Mini-PCs>:8080` öffnen, „Scannen“. Für mehrere Seiten unter „Stapel“ den manuellen Modus wählen, dann fragt es nach jeder Seite. Der Scan landet direkt im Eingangsordner, Paperless übernimmt ihn innerhalb einer Minute. |
| **E-Mail** | In deinem Postfach einen Ordner „Paperless“ anlegen. In Paperless unter *E-Mail* ein Konto hinzufügen (GMX: `imap.gmx.net`, Port 993, SSL) und eine Regel: Ordner „Paperless“, Anhänge verarbeiten, danach als gelesen markieren. Paperless schaut alle 10 Minuten nach. Rechnungen musst du dann nur noch in diesen Ordner verschieben. |
| **Handy** | App „Paperless Mobile“ (Android) oder „Swift Paperless“ (iOS) mit `https://<Dokumenten-Domain>` anmelden und Dokumente abfotografieren. |
| **Browser** | Dateien auf die Paperless-Startseite ziehen. |

Word-, Excel- und E-Mail-Dateien (.eml) verarbeitet Paperless erst mit `COMPOSE_PROFILES=scanner,office` und
`PAPERLESS_TIKA_ENABLED=1` in `.env` (danach `docker compose up -d`). Das kostet ca. 1 GB RAM mehr. PDF-Anhänge aus
E-Mails gehen auch ohne.

### 7. Rezepte & Einkaufsliste (Mealie) einrichten (optional)

[Mealie](https://mealie.io) sammelt Rezepte (Import per Link von fast jeder Rezeptseite), plant die Woche und
erzeugt daraus eine gemeinsame Einkaufsliste. Die Einkaufsliste lässt sich auch ganz ohne Rezepte nutzen.

```bash
cd bildsynchronisation/heimserver/rezepte
./install.sh            # Domain, z.B. rezepte.deine-domain.de
```

⚠️ **Mealie startet mit einem Standard-Zugang** (`changeme@example.com` / `MyPassword`). Deshalb in dieser Reihenfolge:
1. Im Heimnetz `http://<IP des Mini-PCs>:9925` öffnen, mit dem Standard-Zugang anmelden.
2. Unter *Profil* **E-Mail-Adresse und Passwort ändern**, Sprache auf Deutsch stellen.
3. **Erst dann** die Domain freischalten: DNS-Eintrag auf den VPS und im Caddyfile `reverse_proxy 10.77.0.2:9925`
   (oder `sudo vps/setup.sh` erneut ausführen).
4. Weitere Familienmitglieder unter *Einstellungen → Benutzer* einladen oder anlegen.

Auf dem Handy die Seite im Browser öffnen und **„Zum Startbildschirm hinzufügen“** wählen, dann verhält sie sich
wie eine App. Mealie hat eine feste Version (`MEALIE_VERSION` in `rezepte/.env`), `update.sh` aktualisiert es erst,
wenn du die Version dort erhöhst.

### 8. Werbeblocker fürs Heimnetz (AdGuard Home) einrichten (optional)

AdGuard Home beantwortet die DNS-Anfragen aller Geräte im Heimnetz und blockiert dabei Werbe- und Tracking-Adressen –
auch auf Fernseher, Echo & Co., wo man sonst keinen Werbeblocker installieren kann. Es ist **nur im Heimnetz**
erreichbar.

```bash
cd bildsynchronisation/heimserver/adguard
./install.sh            # bestätigt die LAN-Adresse des Mini-PCs
```

1. **Einrichtungsassistent** `http://<IP des Mini-PCs>:3000` öffnen:
   - Admin-Weboberfläche: *Alle Schnittstellen*, **Port 80** lassen
   - DNS-Server: *Alle Schnittstellen*, **Port 53** lassen
   - Benutzername und Passwort festlegen (Passwortmanager)
   (Die Ports gelten innerhalb des Containers; von außen ist die Oberfläche danach unter **Port 3080** erreichbar.)
2. **Weboberfläche** `http://<IP des Mini-PCs>:3080` → *Einstellungen → DNS-Einstellungen*:
   - Upstream-DNS-Server: `https://dns.quad9.net/dns-query` (Quad9, Schweiz, datenschutzfreundlich)
   - Bootstrap-DNS: `9.9.9.9`
3. **Filter** (*Filter → DNS-Sperrlisten*): Die voreingestellte „AdGuard DNS filter“-Liste reicht für den Anfang.
   Über „Sperrliste hinzufügen → Aus der Liste wählen“ lassen sich weitere ergänzen (z.B. „OISD Blocklist Small“).
4. **FritzBox** → *Internet → Zugangsdaten → DNS-Server*:

   | | Bevorzugt | Alternativ (Rückfall) |
   |---|---|---|
   | „Andere DNSv4-Server verwenden“ | IP des Mini-PCs (z.B. `192.168.178.23`) | `9.9.9.9` |
   | „Andere DNSv6-Server verwenden“ | IPv6-Adresse des Mini-PCs (`fd…`, zeigt `install.sh`) | `2620:fe::fe` |

   Haken bei **„Verschlüsselte Namensauflösung im Internet (DNS over TLS)“** entfernen. Nach „Übernehmen“ ggf. an der
   FritzBox per Tastendruck bestätigen, sonst verwirft sie die Änderung. Im **Online-Monitor** muss bei „Genutzte
   DNS-Server“ eine AdGuard-Adresse als „aktuell genutzt“ stehen.

   **Wichtig zum Rückfall:** Ist AdGuard kurz nicht erreichbar (Neustart, Update), wechselt die FritzBox auf Quad9 –
   das Internet funktioniert weiter – **bleibt dort aber auch**, der Filter ist dann aus. Der **tägliche Check**
   (`check.sh`) testet deshalb, ob eine bekannte Werbeadresse blockiert wird, und meldet per Mail
   „Werbefilter ist aus“. Abhilfe: **FritzBox neu starten**, danach nutzt sie wieder AdGuard.

   Nach Änderungen an den DNS-Einstellungen kann die FritzBox kurz ihre eigene Adresse ausgeben. Meldet eine App danach
   einen Zertifikatsfehler mit der FritzBox als Aussteller: **nicht bestätigen**, sondern `ipconfig /flushdns` und die App
   neu starten.

**Test:** Am PC `ipconfig /flushdns` und dann `nslookup googleads.g.doubleclick.net` – die Antwort sollte `0.0.0.0` bzw. `::` sein. Im AdGuard-Abfrageprotokoll
tauchen die Anfragen auf (alle mit der Adresse der FritzBox, weil sie weiterleitet).

**Wenn eine Seite oder App plötzlich nicht mehr funktioniert:** Im Abfrageprotokoll nach der gesperrten Adresse suchen
und auf **„Freigeben“** klicken.

### 9. Passwortmanager (Vaultwarden) einrichten (optional)

[Vaultwarden](https://github.com/dani-garcia/vaultwarden) ist ein schlanker, mit **Bitwarden** kompatibler Server.
Genutzt wird er mit den offiziellen, kostenlosen **Bitwarden-Apps** (Browser-Erweiterung, Windows/Mac/Linux,
Android, iOS) – inklusive automatischem Ausfüllen, 2FA-Codes und Passkeys.

⚠️ Hier liegen alle Passwörter. Deshalb:
- **Das Master-Passwort kann niemand zurücksetzen** – auch der Admin nicht. Vergessen = Daten weg. Aufschreiben und
  sicher verwahren (z.B. im Tresor/Bankschließfach).
- **Erst einrichten, wenn Backup und Überwachung ein paar Wochen zuverlässig laufen.**
- Zusätzlich zum nächtlichen Backup gelegentlich einen **verschlüsselten Export** (Bitwarden-App → Tresor exportieren
  → „.json (verschlüsselt)“) auf einen USB-Stick an einem sicheren Ort.

**Einrichtung:**
1. DNS: Subdomain (z.B. `passwort.deine-domain.de`) auf den VPS; im Caddyfile `reverse_proxy 10.77.0.2:8222`.
   Die Bitwarden-Apps funktionieren nur über HTTPS – die Domain ist also Pflicht.
2. Installieren und Registrierung **nur kurz** öffnen:
   ```bash
   cd bildsynchronisation/heimserver/passwoerter
   ./install.sh                 # Domain abfragen
   ./registrierung.sh an
   ```
3. `https://passwort.deine-domain.de` öffnen → **Konto erstellen** (für dich und deine Frau, jeweils eigenes
   Master-Passwort) → in den Einstellungen jeweils die **Zwei-Faktor-Anmeldung** aktivieren.
4. Registrierung **sofort wieder schließen**:
   ```bash
   ./registrierung.sh aus
   ```
5. Gemeinsame Passwörter: im Web-Tresor *Neue Organisation* (z.B. „Familie“) anlegen und deine Frau einladen
   (ohne Mailserver: Einladung annehmen, indem sie sich anmeldet; danach in der Organisation „Bestätigen“ klicken).
6. **Umzug aus 1Password:** In 1Password exportieren (`.1pux`), im Web-Tresor *Werkzeuge → Daten importieren →
   1Password (1pux)*. Danach die Exportdatei **sicher löschen** (sie ist unverschlüsselt). Dateianhänge werden nicht
   übernommen.
7. In den **Bitwarden-Apps** vor dem Anmelden *Selbst gehostet* wählen und die Server-URL eintragen.

Die Apps haben eine **Offline-Kopie**: Ist der Server kurz nicht erreichbar, kommt man weiter an alle Passwörter.

### 10. Smart Home (Home Assistant) einrichten (optional)

[Home Assistant](https://www.home-assistant.io) bündelt smarte Geräte verschiedener Hersteller (z.B. tado, FritzBox,
Mähroboter) in einer Oberfläche und verbindet sie über Automationen. Es läuft im Netzwerk des Mini-PCs
(„Host-Modus“), damit es Geräte im Heimnetz selbst findet.

```bash
cd bildsynchronisation/heimserver/smarthome
./install.sh            # Domain z.B. haus.deine-domain.de – oder leer lassen = nur Heimnetz
```

1. Im Heimnetz `http://<IP des Mini-PCs>:8123` öffnen und **sofort das Konto anlegen** (die Startseite ist bis dahin
   offen). Standort, Einheiten und Sprache einstellen.
2. **Erst danach** – falls gewünscht – die Domain freischalten: DNS auf den VPS, im Caddyfile
   `reverse_proxy 10.77.0.2:8123`. Mit Domain hat `install.sh` den Tunnel bereits für Port 8123 geöffnet und die
   nötige Proxy-Einstellung in `config/configuration.yaml` hinterlegt.
3. Geräte unter *Einstellungen → Geräte & Dienste* hinzufügen. Viele werden automatisch gefunden.
4. Auf dem Handy die App **„Home Assistant“** installieren (Server-URL: die Domain bzw. im Heimnetz die IP).
   Darüber erkennt Home Assistant auch, wer zu Hause ist.

Hinweise: Die Container-Variante hat keinen eingebauten Add-on-Store; Erweiterungen aus der Community (z.B. für den
Dreame-Mähroboter) installiert man über **HACS** (Anleitung auf hacs.xyz). Für Zigbee/Thread-Geräte braucht es einen
USB-Funkstick am Mini-PC.

### 11. Startseite (Homepage) einrichten (optional)

Eine Übersichtsseite mit Links zu allen Diensten, grüner/roter Statusanzeige sowie Auslastung von Prozessor,
Arbeitsspeicher und Festplatten. **Nur im Heimnetz** erreichbar.

```bash
cd bildsynchronisation/heimserver/startseite
./install.sh            # erkennt automatisch alle installierten Dienste
```

Danach `http://<IP des Mini-PCs>:3010` als Startseite im Browser festlegen. Kommt später ein weiterer Dienst dazu:
`./install.sh neu` erzeugt die Liste neu (eigene Änderungen an `config/services.yaml` gehen dabei verloren).

**Am besten zuletzt installieren**, wenn alle anderen Dienste laufen – dann sind gleich alle auf der Startseite.

### 12. Empfohlene Immich-Einstellungen nach dem ersten Login

Unter *Administration → Einstellungen*:

1. **Server → Externe Domain**: `https://fotos.deine-domain.de` eintragen, damit geteilte Links die richtige Adresse
   bekommen.
2. **Gesichtserkennung**: ist standardmäßig aktiv. Nach dem ersten großen Import läuft sie auf dem N100 je nach
   Bildanzahl ein bis zwei Tage. Fortschritt unter *Administration → Aufträge*. Danach unter *Erkunden → Personen*
   die Personen benennen.
3. **Reverse-Geocoding** (Ortsnamen aus GPS) und **Karte** sind standardmäßig aktiv.
4. **Speichervorlage** (optional): aktivieren, damit die Dateien nach Datum abgelegt werden, z.B.
   `{{y}}/{{y}}-{{MM}}/{{filename}}`. So bleibt die Ordnerstruktur auch ohne Immich verständlich.

## Überwachung von außen (Uptime Kuma auf dem VPS)

Der tägliche Check auf dem Mini-PC meldet Probleme per Mail – fällt der Mini-PC aber ganz aus (Strom, Internet,
Defekt), kann er nichts mehr melden. Uptime Kuma prüft deshalb **vom VPS aus** jede Minute, ob alle Dienste erreichbar
sind, und schickt bei einem Ausfall sofort eine **Push-Nachricht** aufs Handy (über die kostenlose App **ntfy**).

**1. Installieren** (auf dem VPS):

```bash
docker --version || curl -fsSL https://get.docker.com | sh
cd <Repo-Ordner auf dem VPS>/vps/uptime-kuma && git pull
docker compose up -d
```

**2. Einrichten** – die Weboberfläche ist absichtlich nur auf dem VPS selbst erreichbar. Vom PC aus per SSH-Tunnel:

```bash
ssh -L 3001:127.0.0.1:3001 root@<IP des VPS>
```

Solange diese Verbindung offen ist, im Browser **`http://localhost:3001`** öffnen → Admin-Konto anlegen → Einstellungen →
Sprache **Deutsch**. (Die Oberfläche bleibt so dauerhaft privat; zum Nachsehen einfach wieder den SSH-Tunnel öffnen.
Die Push-Nachrichten kommen natürlich auch ohne Tunnel.)

**3. Push-Nachrichten (ntfy):**
1. App **„ntfy“** installieren (Android/iOS), **„+“** → Thema abonnieren, Server `ntfy.sh`, als Thema einen
   **langen, zufälligen Namen** wählen, z.B. `heimserver-k7Qx2mPz9w` (wer den Namen kennt, kann mitlesen).
2. In Uptime Kuma: *Einstellungen → Benachrichtigungen → Benachrichtigung einrichten* → Typ **ntfy**,
   Server `https://ntfy.sh`, dasselbe Thema, **„Standardmäßig aktiviert“** und **„Auf alle bestehenden Monitore
   anwenden“** anhaken → **Testen**.

**4. Monitore anlegen** (*Neuen Monitor hinzufügen*, Intervall 60 s, Wiederholungen 3):

| Name | Typ | Adresse | |
|---|---|---|---|
| Fotos | HTTP(s) – Schlüsselwort | `https://fotos.deine-domain.de/api/server/ping` | Schlüsselwort `pong` |
| Cloud | HTTP(s) | `https://cloud.deine-domain.de` | |
| Dokumente | HTTP(s) | `https://dokumente.deine-domain.de` | |
| Rezepte | HTTP(s) | `https://rezepte.deine-domain.de` | |
| Tunnel zum Mini-PC | TCP-Port | Host `10.77.0.2`, Port `2283` | zeigt, ob der Tunnel steht |

Bei den HTTP(s)-Monitoren unter „Erweitert“ zusätzlich **„Zertifikatsablauf-Benachrichtigung“** aktivieren. Andere
Webseiten auf dem VPS lassen sich genauso mit überwachen.

So liest man eine Meldung: Fallen **alle** Heimdienste und der Tunnel gleichzeitig aus, ist der Mini-PC oder das
Internet daheim weg. Fällt nur **einer** aus, hängt dieser eine Dienst (`docker compose ps` auf dem Mini-PC).

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

Eine Cloud ohne Backup ist kein Backup. Der Mini-PC sichert jede Nacht Fotos, Datenbank und Cloud-Dateien mit
**[restic](https://restic.net)** auf die Storage Box:

- **verschlüsselt**: Hetzner sieht nur unlesbare Daten
- **mit Versionen**: 7 tägliche, 4 wöchentliche und 12 monatliche Stände. Auch versehentlich gelöschte oder
  überschriebene Dateien lassen sich wiederherstellen.
- **inkrementell**: Nach dem ersten Lauf werden nur Änderungen übertragen.

**Einmalig einrichten** (auf dem Mini-PC, als root, weil die Daten root bzw. dem Container gehören):

1. In der Hetzner Console bei der Storage Box **SSH-Support** und **externe Erreichbarkeit** aktivieren.
2. restic installieren, einen SSH-Schlüssel anlegen und hinterlegen (`uXXXXXX` = dein Storage-Box-Benutzer):

   ```bash
   sudo apt install restic
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

4. Backup-Einstellungen anlegen und das verschlüsselte Repository erzeugen:

   ```bash
   cd bildsynchronisation/heimserver
   cp backup.env.example backup.env
   sudo ./backup.sh init
   ```

   Das Skript zeigt das **Backup-Passwort** an. **Speichere es im Passwortmanager.** Geht der Mini-PC kaputt, ist
   es der einzige Weg an die Daten. Ohne Passwort ist das Backup wertlos.

5. Erstes Backup starten. Bei ca. 190 GB und der Begrenzung auf 1500 KiB/s (`BWLIMIT` in `backup.env`) dauert es
   etwa 1,5 Tage. Daneben bleibt genug Upload für den normalen Gebrauch. Während das Cloud-Backup läuft, ist
   OpenCloud kurz angehalten, beim ersten Mal ein paar Stunden, danach Minuten. Starte es deshalb abends.

   ```bash
   sudo ./backup.sh
   ```

6. Automatisch jede Nacht um 3 Uhr (`sudo crontab -e`):

   ```
   0 3 * * * /home/<benutzer>/bildsynchronisation/heimserver/backup.sh >> /var/log/heimserver-backup.log 2>&1
   ```

`sudo ./backup.sh status` zeigt alle vorhandenen Backup-Stände.

**Wiederherstellen**, z.B. eine versehentlich gelöschte Cloud-Datei:

```bash
sudo bash -c 'set -a; source backup.env; restic snapshots --tag opencloud'     # Stände anzeigen
sudo bash -c 'set -a; source backup.env; restic mount /mnt/restore'            # alle Stände als Ordner durchsuchen
```

Für eine komplette Wiederherstellung von Immich siehe [Immich-Doku „Backup and Restore“](https://docs.immich.app/administration/backup-and-restore).
Der Datenbank-Dump liegt im Backup unter `backups/manual-*.sql.gz`.

## Überwachung per E-Mail

`heimserver/check.sh` prüft jeden Morgen den Mini-PC und schickt dir **nur bei Problemen** eine E-Mail:

| Prüfung | Warnt, wenn … |
|---|---|
| SSDs (SMART) | eine SSD Ausfall meldet, Sektoren ersetzt/unlesbar sind oder sie zu ≥ 80 % abgenutzt ist |
| Backup | das letzte erfolgreiche Backup älter als 30 Stunden ist |
| Speicherplatz | eine Platte zu ≥ 85 % voll ist |
| Container | Immich oder OpenCloud nicht läuft |
| Tunnel | der Mini-PC seit über 5 Minuten keinen Kontakt zum VPS hat |
| Erreichbarkeit | Fotos oder Cloud aus dem Internet nicht erreichbar sind (prüft die ganze Kette über den VPS) |

Einmal pro Woche (standardmäßig montags) kommt zusätzlich eine „Alles in Ordnung“-Mail. Bleibt sie aus, läuft
der Check selbst nicht mehr.

**Einrichten:**

1. SMART-Werkzeuge installieren: `sudo apt install smartmontools`
2. Einstellungen anlegen und ausfüllen (Mail-Zugangsdaten, Foto-Adresse):

   ```bash
   cd bildsynchronisation/heimserver
   cp check.env.example check.env
   chmod 600 check.env          # enthält das Mail-Passwort
   nano check.env
   ```

   Am einfachsten verschickt das Skript über dein normales Mail-Konto. Bei GMX musst du dafür in den
   GMX-Einstellungen unter *E-Mail → POP3/IMAP-Abruf* den Zugriff erlauben. Ist die Zwei-Faktor-Anmeldung aktiv,
   brauchst du ein App-Passwort.

3. Testen:

   ```bash
   sudo ./check.sh test       # schickt eine Test-Mail
   sudo ./check.sh zeigen     # zeigt den aktuellen Bericht ohne Mail
   ```

4. Täglich um 8 Uhr ausführen (`sudo crontab -e`, unter der Backup-Zeile):

   ```
   0 8 * * * /home/<benutzer>/bildsynchronisation/heimserver/check.sh >> /var/log/heimserver-check.log 2>&1
   ```

Fällt der ganze Mini-PC aus (Strom, Defekt), kann er natürlich keine Mail mehr schicken. Dann fehlt die
wöchentliche „Alles in Ordnung“-Mail, und die Handy-App meldet, dass der Server nicht erreichbar ist.

## Update

```bash
cd bildsynchronisation/heimserver && ./update.sh
```

Das aktualisiert Immich und OpenCloud. `IMMICH_VERSION=v3` bzw. `OC_VERSION=7` in den `.env`-Dateien aktualisieren
automatisch innerhalb der jeweiligen Hauptversion. Vor einem Wechsel auf eine neue
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
docker logs opencloud --tail 50                # Cloud-Logs
sudo ./backup.sh status                        # Backup-Stände
sudo ./check.sh zeigen                         # Gesundheits-Check

# VPS
sudo wg show                                   # Tunnel-Status
curl -sI http://10.77.0.2:2283                 # Erreicht der VPS Immich durch den Tunnel?
curl -sI http://10.77.0.2:9200                 # … und OpenCloud?
cd bildsynchronisation/vps && docker compose logs caddy   # HTTPS/Zertifikat (falls Caddy genutzt wird)
```

## Fehlerbehebung

- **Daheim geht's, unterwegs nicht**: Auf dem VPS `sudo wg show` aufrufen. Fehlt „latest handshake“, ist UDP 51820
  in der IONOS-Firewall nicht freigegeben, oder der Tunnel auf dem Mini-PC läuft nicht
  (`sudo systemctl status wg-quick@wg-fotos`). Steht der Tunnel, aber die Seite lädt nicht: `curl -sI http://10.77.0.2:2283`
  auf dem VPS prüfen, dann die Webserver-Konfiguration ([docs/reverse-proxy.md](docs/reverse-proxy.md)).
- **Zertifikatsfehler**: DNS-Eintrag prüfen (`dig fotos.deine-domain.de`), sind TCP 80/443 in der IONOS-Firewall offen?
- **Cloud-Anmeldung schlägt fehl / Endlosschleife**: OpenCloud muss immer über `https://cloud.deine-domain.de`
  aufgerufen werden, nicht über die IP des Mini-PCs. `OC_DOMAIN` in `heimserver/cloud/.env` muss genau dieser Domain
  entsprechen.
- **Gesichter werden nicht erkannt**: *Administration → Aufträge → Gesichtserkennung → Fehlende*.
- **Falsches Datum bei alten Bildern**: Fehlen EXIF-Daten, liest immich-go das Datum aus dem Dateinamen. In der
  Weboberfläche lässt sich das Datum mehrerer Bilder gleichzeitig korrigieren (Auswahl → „Datum ändern“).
- **Mehr Tempo auf dem N100** (optional): Immich kann die Grafikeinheit des N100 für Videos (Quick Sync) und
  Gesichtserkennung (OpenVINO) nutzen, siehe [Hardware-Transkodierung](https://docs.immich.app/features/hardware-transcoding)
  und [ML-Beschleunigung](https://docs.immich.app/features/ml-hardware-acceleration).
