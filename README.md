# FamTask Docker - Container-Setup & Proxmox Installer

Docker Compose Konfiguration für FamTask (Web, MariaDB, phpMyAdmin) sowie automatische Installationsscripts für Proxmox VE.

## Inhalte

- `docker-compose.yml` – 3 Services: php-apache (Port 8888), mariadb (Port 3307), phpmyadmin (Port 8081)
- `php/Dockerfile` – PHP 8.2 Apache Image mit Extensions (pdo_mysql, zip, gd, curl, mbstring, intl)
- `php/php.ini` – PHP-Konfiguration (Upload-Limits, Timezone, OPcache)
- `db/init.sql` – Datenbank-Initialisierung
- `scripts/setup.sh` / `setup.ps1` – Automatische Konfiguration nach Container-Start
- `proxmox-install.sh` – Vollständiges Installationsscript für Proxmox
- `proxmox-install-oneliner.sh` – One-Liner für `curl | bash`

## Schnellstart (Proxmox / Debian / Ubuntu)

### One-Liner (empfohlen)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nanoemilios/famtask_docker/main/proxmox-install-oneliner.sh)
```

### Manuell

```bash
git clone https://github.com/nanoemilios/famtask_docker.git
cd famtask_docker
bash proxmox-install.sh
```

## Was der Installer tut

1. **Docker & Docker Compose** installiert (falls nicht vorhanden)
2. **Repository** klont nach `/opt/famtask_docker`
3. **Sichere Passwörter** generiert (24 Zeichen)
4. **`.env` Datei** erstellt mit allen Zugangsdaten
5. **Container baut & startet** (Web, MariaDB, phpMyAdmin)
6. **Wartet auf DB** und erstellt App-Konfiguration (`.famtask_cfg.php`)

## Nach der Installation

| Dienst | URL |
|--------|-----|
| **FamTask App** | `http://<IP>:8888` |
| **Admin-Panel** | `http://<IP>:8888/?action=admin` |
| **phpMyAdmin** | `http://<IP>:8081` |

**Wichtige Dateien:**
- `docker/.env` – Docker-Umgebungsvariablen (Passwörter!)
- `my/.famtask_cfg.php` – App-DB-Konfiguration (wird von Installer erstellt)

## Manuelle Docker-Nutzung

```bash
cd famtask_docker
# .env anpassen (oder .env.example kopieren)
docker compose up -d --build
# Dann: bash scripts/setup.sh  (erstellt .famtask_cfg.php)
```

## Ports anpassen

In `.env`:
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
docker compose -f docker-compose.yml up -d --build
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
3. In CT: One-Liner ausführen

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

## Lizenz

Keine Lizenz definiert.