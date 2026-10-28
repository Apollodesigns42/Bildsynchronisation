# Immich hinter einem bestehenden Webserver

Läuft auf dem VPS bereits ein Webserver auf Port 80/443, bleibt der mitgelieferte Caddy aus
(`COMPOSE_PROFILES=` leer in `.env`). Immich lauscht dann nur lokal auf `127.0.0.1:2283`
(bzw. dem Port aus `IMMICH_PORT`). Dein Webserver leitet die Foto-Domain dorthin weiter.

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
        proxy_pass http://127.0.0.1:2283;
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
    RewriteRule /(.*) ws://127.0.0.1:2283/$1 [P,L]

    ProxyPass        / http://127.0.0.1:2283/
    ProxyPassReverse / http://127.0.0.1:2283/
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
	reverse_proxy 127.0.0.1:2283
}
```

Läuft dieser Caddy selbst in Docker, statt `127.0.0.1` die IP des Docker-Hosts verwenden
(oder beide Container in ein gemeinsames Docker-Netzwerk hängen und `immich_server:2283` nutzen).

## Traefik, Nginx Proxy Manager, Coolify o. Ä. (in Docker)

Diese Proxys erreichen `127.0.0.1` des Hosts nicht. Am einfachsten hängst du `immich-server`
zusätzlich in das Netzwerk des Proxys und leitest auf `immich_server:2283` weiter.
Dazu eine Datei `docker-compose.override.yml` neben `docker-compose.yml` anlegen
(`proxy-netz` durch den Netzwerknamen deines Proxys ersetzen, siehe `docker network ls`):

```yaml
services:
  immich-server:
    networks: [default, proxy-netz]
networks:
  proxy-netz:
    external: true
```

Danach `docker compose up -d`. Im Nginx Proxy Manager: Forward Hostname `immich_server`,
Port `2283`, „Websockets Support“ aktivieren, SSL-Zertifikat anfordern.
