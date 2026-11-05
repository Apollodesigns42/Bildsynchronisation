# Fahrplan: noch offene Schritte

Stand: Fotos (Immich), Cloud (OpenCloud), Dokumente (Paperless mit Scanner und E-Mail-Abruf), Tunnel, Backup und
täglicher Check laufen.

## Reihenfolge

| # | Schritt | Wann | Voraussetzung | Aufwand |
|---|---|---|---|---|
| 1 | **Uptime Kuma** auf dem VPS (README „Überwachung von außen“) | sofort | – | ~30 Min. |
| 2 | **AdGuard Home** auf dem NUC (README Schritt 8) | sofort | – | ~30 Min. |
| 3 | **Mealie** (README Schritt 7) | sobald `www.wuerminghausen.si` aufgelöst wird | DNS bei deSEC aktiv | ~20 Min. |
| 4 | ✓ **iPhone deiner Frau** auf dein Immich-Konto umgestellt, Partnerfreigabe aufgehoben | erledigt | – | – |
| 5 | **Google-Takeout-Import** (beide Konten nacheinander), danach **externe Festplatte** | Exporte liegen vor | `import.env` am PC | Stunden, über Nacht |
| 6 | **iCloud-Export** anfordern und importieren | jetzt anfordern, Import nach 5 | Export von privacy.apple.com | je nach Menge |
| 7 | ✓ Altes Immich-Konto deiner Frau gelöscht | erledigt | – | – |
| 8 | **Home Assistant** (README Schritt 10) | nach den Importen | Konto sofort im Heimnetz anlegen, erst dann Domain | ~1 Std. + Geräte einrichten |
| 9 | **Vaultwarden** (README Schritt 9) | nach den Importen **und** einigen Wochen stabilem Backup | Domain + Caddy-Eintrag, Master-Passwort sicher verwahrt | ~1 Std. inkl. 1Password-Umzug |
| 10 | **Homepage** (README Schritt 11) | zuletzt | alle anderen Dienste installiert | ~15 Min. |
| 11 | **MEGA kündigen**, Google Fotos/iCloud aufräumen | nach einigen Wochen Parallelbetrieb | Backups laufen nachweislich | – |

Während der großen Importe (5, 6) den Arbeitsspeicher mit `free -h` beobachten. Steigt der Swap dauerhaft über
~1–2 GB oder wird alles zäh, wäre eine Aufrüstung auf 16 GB das Mittel – im Normalbetrieb ist das nicht nötig.

## Domains

| Dienst | Domain | Status | Warum |
|---|---|---|---|
| Fotos (Immich) | `www.wuerminghausen.org` | ✓ eingerichtet | **nötig** – Handy-Backup und Ansicht unterwegs |
| Cloud (OpenCloud) | `www.wuerminghausen.net` | ✓ eingerichtet | **nötig** – OpenCloud funktioniert nur über eine feste Adresse (Anmeldung), auch daheim |
| Dokumente (Paperless) | `www.wuerminghausen.eu` | ✓ eingerichtet | **empfehlenswert** – Dokumente unterwegs abrufen, Handy-App |
| Rezepte (Mealie) | `www.wuerminghausen.si` | ✓ DNS bei deSEC aktiv | **empfehlenswert** – Einkaufsliste im Supermarkt |
| Passwörter (Vaultwarden) | `www.wuerminghausen.wf` (DNS bei Regery) | offen | **nötig** – die Bitwarden-Apps funktionieren nur über HTTPS |
| Smart Home (Home Assistant) | `www.florian.lv` (DNS bei Regery) | offen | **optional** – nur nötig für Steuerung unterwegs und Anwesenheitserkennung über die App außer Haus |
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
