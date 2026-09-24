# FamTask Docker - Container-Setup

Docker Compose Konfiguration für FamTask (Web, MariaDB, phpMyAdmin).

## Inhalte

- `docker-compose.yml` – 3 Services: php-apache (Port 8888), mariadb (Port 3307), phpmyadmin (Port 8081)
- `php/Dockerfile` – PHP 8.2 Apache Image mit Extensions (pdo_mysql, zip, gd, curl, mbstring, intl)
- `php/php.ini` – PHP-Konfiguration (Upload-Limits, Timezone, OPcache)
- `db/init.sql` – Datenbank-Initialisierung
- `scripts/setup.sh` / `setup.ps1` – Automatische Konfiguration nach Container-Start (klont famtask Repo, erstellt Config)

## Installation auf Proxmox / Debian / Ubuntu

**Für Proxmox Nutzung das separate Repo: [famtask_proxmox](https://github.com/nanoemilios/famtask_proxmox)**

```bash
# One-Liner (empfohlen):
bash <(curl -fsSL https://raw.githubusercontent.com/nanoemilios/famtask_proxmox/main/proxmox-install-oneliner.sh)

# Oder manuell:
git clone https://github.com/nanoemilios/famtask_proxmox.git
cd famtask_proxmox
bash proxmox-install.sh
```

Der Installer klont dieses Repo (famtask_docker) automatisch nach `/opt/famtask_docker` und führt das Setup aus.

## Manuelle Docker-Nutzung (ohne Proxmox Installer)

```bash
git clone https://github.com/nanoemilios/famtask_docker.git
cd famtask_docker
cp docker/.env.example docker/.env
# .env anpassen (Passwörter!)
docker compose up -d --build
bash scripts/setup.sh  # klont famtask Repo, erstellt .famtask_cfg.php
```

## Nach der Installation

| Dienst | URL |
|--------|-----|
| **FamTask App** | `http://<IP>:8888` |
| **Admin-Panel** | `http://<IP>:8888/?action=admin` |
| **phpMyAdmin** | `http://<IP>:8081` |

**Wichtige Dateien:**
- `docker/.env` – Docker-Umgebungsvariablen (Passwörter!)
- `my/.famtask_cfg.php` – App-DB-Konfiguration (wird von setup.sh erstellt)

## Ports anpassen

In `docker/.env`:
```env
APP_PORT=8888      # Web-App
PMA_PORT=8081      # phpMyAdmin
DB_PORT=3307       # MariaDB (Host-Port)
```

In `docker-compose.yml` die Ports entsprechend anpassen.

## Updates

```bash
cd /opt/famtask_docker
git pull
docker compose -f docker/docker-compose.yml up -d --build
bash scripts/setup.sh
```

## Deinstallation

```bash
cd /opt/famtask_docker
docker compose down -v
rm -rf /opt/famtask_docker
```

## LXC Container (Proxmox)

Für bessere Performance in unprivilegiertem LXC:

1. CT erstellen: Debian 12, 2 GB RAM, 2 CPU, 10 GB Disk
2. Features aktivieren: `Nesting=1`, `Keyctl=1`
3. In CT: Proxmox Installer ausführen (siehe famtask_proxmox)

```bash
# Auf Proxmox-Host:
pct set <CTID> -features nesting=1,keyctl=1
```

## Firewall

```bash
# Proxmox Host:
pve-firewall add rule --port 8888 --proto tcp --action accept
pve-firewall add rule --port 8081 --proto tcp --action accept
pve-firewall add rule --port 3307 --proto tcp --action accept
```

## Troubleshooting

**Logs anzeigen:**
```bash
docker compose logs -f
```

**Passwörter anzeigen:**
```bash
cat docker/.env
```

**Datenbank zurücksetzen (Datenverlust!):**
```bash
docker compose down -v
docker compose up -d
bash scripts/setup.sh
```

## Verwandte Repositories

- **famtask** – Hauptanwendung (wird als Volume in `php-apache` gemountet)
- **famtask_installer** – Web-Installer für Shared Hosting
- **famtask_proxmox** – Proxmox Installer Scripts

## Lizenz

Keine Lizenz definiert.