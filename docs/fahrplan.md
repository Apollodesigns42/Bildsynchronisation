# Fahrplan: noch offene Schritte

Stand: Fotos (Immich), Cloud (OpenCloud), Dokumente (Paperless mit Scanner und E-Mail-Abruf), Rezepte (Mealie),
Werbeblocker (AdGuard), Smart Home (Home Assistant), Überwachung von außen (Uptime Kuma), Tunnel, Backup und
täglicher Check laufen. Videos werden über den Prozessor umgewandelt (AMD-Beschleunigung blieb hängen).

## Reihenfolge

| # | Schritt | Wann | Voraussetzung | Aufwand |
|---|---|---|---|---|
| 1 | ✓ **Uptime Kuma** auf dem VPS | erledigt | – | – |
| 2 | ✓ **AdGuard Home** auf dem NUC (IPv4 + IPv6, Filter-Check im täglichen Check) | erledigt | – | – |
| 3 | ✓ **Mealie** unter `www.wuerminghausen.si` | erledigt | – | – |
| 4 | ✓ **iPhone deiner Frau** auf dein Immich-Konto umgestellt, Partnerfreigabe aufgehoben | erledigt | – | – |
| 5 | ✓ **Google-Takeout-Import** und **externe Festplatte** importiert und verarbeitet | erledigt | – | – |
| 6 | **iCloud**: ältere Fotos deiner Frau (Datum 15.09.2025, ohne Standort) – prüfen, ob noch in iCloud; dann offiziellen Export importieren | Wochenende | Export von privacy.apple.com | je nach Menge |
| 7 | ✓ Altes Immich-Konto deiner Frau gelöscht | erledigt | – | – |
| 8 | ✓ **Home Assistant** unter `www.florian.lv` (Geräte einbinden läuft) | erledigt | – | – |
| 9 | ✓ **Vaultwarden** unter `www.wuerminghausen.wf` eingerichtet (Konten angelegt, Registrierung zu). **Nutzung und 1Password-Umzug** erst nach einigen Wochen stabilem Backup | eingerichtet | Master-Passwort und 2FA-Wiederherstellungscode sicher verwahrt | ~30 Min. für den Umzug |
| 10 | ✓ **Homepage** mit Container-Status, Drucker-Kachel und **Portainer** (Neustart-Knopf) | erledigt | – | – |
| 12 | ✓ **Landingpages** und **halvern-industries.com** live (Impressum, Datenschutz, AVV mit IONOS, Protokolle 14 Tage). in Uptime Kuma überwacht. Vor Shop-Start noch AGB/Widerruf/Versand und USt-Hinweis klären | erledigt | – | – |
| 13 | **Alexa**: Alexa Media Player (Echos steuern) und Emulated Hue (Sprachsteuerung) | offen | 2FA-App-Schlüssel von Amazon | ~30 Min. |
| 14 | ✓ **ESP32 als Bluetooth-Proxy** aufgespielt – bei Umzug der Hue-Lampe nur neben die Lampe stecken | erledigt | – | – |
| 15 | **VPS auf Ubuntu 26.04** heben (`do-release-upgrade`) – kein Muss, 24.04 hat Updates bis 2029 | irgendwann in Ruhe | vorher Snapshot bei IONOS anlegen | ~1 Std. |
| 16 | **AdGuard stabilisieren**: Ratenbegrenzung 0, parallele Anfragen, optimistisches Caching (✓ erledigt) – beobachten. ✓ NUC hängt jetzt per Kabel (1 Gbit/s) direkt an der FritzBox. Noch offen: zweite AdGuard-Instanz (Raspberry Pi 4) am Repeater mit adguardhome-sync; FritzBox-DNS dann NUC + Pi statt Quad9 | beobachten, Gerät noch offen | zweites Gerät | ~1 Std. |
| 11 | **MEGA kündigen**, Google Fotos/iCloud aufräumen | nach einigen Wochen Parallelbetrieb | Backups laufen nachweislich | – |

Während der großen Importe (5, 6) den Arbeitsspeicher mit `free -h` beobachten. Steigt der Swap dauerhaft über
~1–2 GB oder wird alles zäh, wäre eine Aufrüstung auf 16 GB das Mittel – im Normalbetrieb ist das nicht nötig.

## Domains

| Dienst | Domain | Status | Warum |
|---|---|---|---|
| Fotos (Immich) | `www.wuerminghausen.org` | ✓ eingerichtet | **nötig** – Handy-Backup und Ansicht unterwegs |
| Cloud (OpenCloud) | `www.wuerminghausen.net` | ✓ eingerichtet | **nötig** – OpenCloud funktioniert nur über eine feste Adresse (Anmeldung), auch daheim |
| Dokumente (Paperless) | `www.wuerminghausen.eu` | ✓ eingerichtet | **empfehlenswert** – Dokumente unterwegs abrufen, Handy-App |
| Rezepte (Mealie) | `www.wuerminghausen.si` | ✓ eingerichtet (DNS bei deSEC) | **empfehlenswert** – Einkaufsliste im Supermarkt |
| Passwörter (Vaultwarden) | `www.wuerminghausen.wf` (DNS bei Regery) | ✓ eingerichtet | **nötig** – die Bitwarden-Apps funktionieren nur über HTTPS |
| Smart Home (Home Assistant) | `www.florian.lv` (DNS bei Regery) | ✓ eingerichtet | **optional** – nur nötig für Steuerung unterwegs und Anwesenheitserkennung über die App außer Haus |
| Werbeblocker (AdGuard) | – | – | **keine** – nur im Heimnetz |
| Startseite (Homepage) | – | – | **keine** – nur im Heimnetz |
| Überwachung (Uptime Kuma) | – | – | **keine** – Zugriff per SSH-Tunnel, Benachrichtigung per ntfy |
| Scannen (scanservjs) | – | – | **keine** – nur im Heimnetz |

Für `wuerminghausen.wf` und `florian.lv` bei Regery jeweils A-Einträge `@` und `www` → `217.154.115.102` anlegen
(AAAA-Einträge, die nicht auf den VPS zeigen, entfernen). Im Caddyfile des VPS – erst nach der Einrichtung im Heimnetz:

```
# --- Passwörter: Vaultwarden, über den Tunnel ---
www.wuerminghausen.wf {
	reverse_proxy 10.77.0.2:8222
}

wuerminghausen.wf {
	redir https://www.wuerminghausen.wf{uri} permanent
}

# --- Smart Home: Home Assistant, über den Tunnel ---
www.florian.lv {
	reverse_proxy 10.77.0.2:8123
}

florian.lv {
	redir https://www.florian.lv{uri} permanent
}
```

Ports im Tunnel: Fotos 2283 · Cloud 9200 · Dokumente 8000 · Rezepte 9925 · Passwörter 8222 · Smart Home 8123.

**Bei Diensten mit Erst-Einrichtung im Browser** (Mealie, Home Assistant, Vaultwarden) gilt: erst im Heimnetz
absichern bzw. Konten anlegen, **danach** den Caddy-Eintrag ergänzen.

## Weitere Websites auf dem VPS (Landingpages, halvern-industries.com)

Statische Seiten, die Caddy direkt aus `/var/www/<domain>/` ausliefert – unabhängig vom Heimserver.

| Domain | Registrar | Inhalt |
|---|---|---|
| `halvern-industries.com` | IONOS | eigene Website (Python-Build → `public/`, eigenes `deploy/deploy.sh`) |
| `florian.pw` | Unstoppable | Platzhalter – nur möglich, wenn dort klassisches DNS (A-Eintrag) angeboten wird |
| `sophia.lv`, `hannah.ee` | Regery | Platzhalter |
| `karl.je` | Nicnames | Platzhalter |
| `schillerhoehe.net` | Checkdomains | Platzhalter |
| `friedrich-schiller-höhe.de` | Checkdomains | Weiterleitung auf `schillerhoehe.net` (im Caddyfile als `xn--friedrich-schiller-hhe-eic.de`) |

Pro Domain bei der jeweiligen Registrar A-Einträge `@` und `www` → `217.154.115.102`.

**Alles liegt fertig im Projekt:** `vps/Caddyfile.vps` ist die vollständige Konfiguration des VPS (Burgenkampf, alle
Heimserver-Dienste, halvern, Landingpages). `vps/landingpages/install.sh` legt die Platzhalterseiten direkt auf dem
VPS an. Ablauf auf dem VPS (im Projektordner):

```bash
git pull
sudo vps/landingpages/install.sh                    # Platzhalter nach /var/www/<domain>/
sudo vps/caddy-check.sh vps/Caddyfile.vps               # meldet fehlende Domains, prüft die Syntax
sudo vps/caddy-check.sh vps/Caddyfile.vps übernehmen    # erst wenn alles passt: sichern, einspielen, neu laden
```

halvern-industries.com: Die Website mit ihrem eigenen `deploy.sh` nach `/var/www/halvern-industries.com/`
hochladen – die Caddy-Schritte aus deren `DEPLOY.md` entfallen (der Block steht schon in `vps/Caddyfile.vps`).

### Protokoll-Aufbewahrung auf dem VPS (Datenschutzerklärung halvern-industries.com)

Die Datenschutzerklärung sagt zu: Fehlermeldungen des Webservers (können IP-Adressen enthalten) werden nach
spätestens 14 Tagen gelöscht. Einmalig auf dem VPS einrichten:

```bash
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nMaxRetentionSec=14day\nMaxFileSec=1day\n' > /etc/systemd/journald.conf.d/aufbewahrung.conf
systemctl restart systemd-journald
```

**SSH auf dem VPS nur mit Schlüssel** (erledigt): Passwort-Anmeldung ist abgeschaltet, root nur per Schlüssel.
Neues Gerät? Erst dessen öffentlichen Schlüssel in `/root/.ssh/authorized_keys` eintragen. Notzugang:
KVM-Konsole im IONOS-Kundenbereich.

```bash
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' > /etc/ssh/sshd_config.d/00-haerten.conf
sshd -t && systemctl reload ssh
```

Auf dem NUC genauso (erledigt), dort mit `PermitRootLogin no` und `sudo`. Notzugang: Bildschirm und Tastatur
direkt am NUC.
