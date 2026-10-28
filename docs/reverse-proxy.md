# Weiterleitung im bestehenden Webserver des VPS

Läuft auf dem VPS bereits ein Webserver auf Port 80/443, startet `vps/setup.sh` keinen eigenen Caddy.
Stattdessen trägst du die Foto-Domain in deinem vorhandenen Webserver ein und leitest sie durch den
WireGuard-Tunnel an den Mini-PC weiter:

| Domain | Ziel |
|---|---|
| Fotos (Immich) | `http://10.77.0.2:2283` |
| Cloud (OpenCloud) | `http://10.77.0.2:9200` |

Die Beispiele unten zeigen die Foto-Domain. Für die Cloud legst du einen zweiten, gleich aufgebauten Eintrag mit
der Cloud-Domain und Port **9200** an.

Wichtig für alle Varianten:
- **Keine Upload-Größenbegrenzung** (Videos können mehrere GB haben)
- **WebSockets** durchreichen (Live-Aktualisierung der Oberfläche)
- **Lange Timeouts** für große Uploads

Welcher Webserver läuft? → `sudo ss -ltnp '( sport = :80 or sport = :443 )'` oder `docker ps`

## nginx

`/etc/nginx/sites-available/immich`:

```nginx
server {
    listen 80;
    server_name fotos.example.de;

    client_max_body_size 50000M;
    proxy_request_buffering off;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
    send_timeout 600s;

    location / {
        proxy_pass http://10.77.0.2:2283;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/immich /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d fotos.example.de     # HTTPS-Zertifikat
```

## Apache

Module aktivieren: `sudo a2enmod proxy proxy_http proxy_wstunnel headers rewrite`

`/etc/apache2/sites-available/immich.conf`:

```apache
<VirtualHost *:80>
    ServerName fotos.example.de

    ProxyPreserveHost On
    ProxyTimeout 600
    LimitRequestBody 0
    RequestHeader set X-Forwarded-Proto "https" env=HTTPS

    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*) ws://10.77.0.2:2283/$1 [P,L]

    ProxyPass        / http://10.77.0.2:2283/
    ProxyPassReverse / http://10.77.0.2:2283/
</VirtualHost>
```

```bash
sudo a2ensite immich && sudo systemctl reload apache2
sudo certbot --apache -d fotos.example.de
```

## Caddy (bereits installiert)

Im bestehenden Caddyfile ergänzen und Caddy neu laden:

```
fotos.example.de {
	reverse_proxy 10.77.0.2:2283
}
```

Das funktioniert auch, wenn dieser Caddy in Docker läuft: Container erreichen die Tunnel-Adresse
über das Routing des VPS.

## Traefik, Nginx Proxy Manager, Coolify o. Ä. (in Docker)

Als Ziel `10.77.0.2` mit Port `2283` eintragen (Schema `http`). Docker-Container erreichen die
Tunnel-Adresse über das Routing des VPS. Im Nginx Proxy Manager zusätzlich „Websockets Support“
aktivieren und ein SSL-Zertifikat anfordern.

## Test

Auf dem VPS muss `curl -sI http://10.77.0.2:2283` eine Antwort von Immich liefern (Tunnel steht).
Danach `https://fotos.example.de` im Browser öffnen.
