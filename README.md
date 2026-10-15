# FamTask Docker - Container-Setup

Docker Compose Konfiguration für FamTask (Web, MariaDB, phpMyAdmin).

## Inhalte

- `docker-compose.yml` – 3 Services: php-apache (Port 8888), mariadb (Port 3307), phpmyadmin (Port 8081)
- `php/Dockerfile` – PHP 8.2 Apache Image mit Extensions (pdo_mysql, zip, gd, curl, **ftp**, mbstring, intl)
- `php/php.ini` – PHP-Konfiguration (Upload-Limits, Timezone, OPcache)
- `db/init.sql` – Datenbank-Initialisierung
- `scripts/setup.sh` / `setup.ps1` – Automatische Konfiguration nach Container-Start (klont famtask Repo, erstellt Config)

### PHP-Extensions

| Extension | Wofür |
|---|---|
| `pdo_mysql` | Datenbank-Sync |
| `gd` | Cover-Bilder, Icons |
| `zip` | Backup/Restore |
| `mbstring` | UTF-8 in allen Sprachdateien |
| `intl` | Datumsformate |
| `curl` | **WebDAV** (PROPFIND) und **HTTPS/S3**-Downloads in `remote.php` |
| `ftp` | **FTP/FTPS**-Stream-Wrapper in `remote.php` |

`curl` und `ftp` sind seit v1.5.0 enthalten. Ohne sie funktionieren externe
Musikquellen nicht – WebDAV und HTTPS brauchen `curl`, FTP braucht `ftp`.

Nach einem Update des Images:

```bash
cd /opt/famtask_docker
git pull
docker compose up -d --build      # baut das Image neu, damit curl/ftp wirksam werden
bash scripts/setup.sh
```

## Musik von einem NAS (SMB/CIFS, NFS)

**PHP kann Netzwerkdateisysteme nicht selbst mounten.** Der Host mountet,
Docker reicht den Pfad nur durch. Deshalb ist in `docker-compose.yml` eine
Zeile vorbereitet, die du nach dem Mounten aktivierst.

**1. Auf dem Host mounten** (auf dem Rechner mit Docker, nicht im Container):

```bash
# SMB/CIFS
sudo apt-get install -y cifs-utils
sudo mkdir -p /srv/famtask-music
sudo mount -t cifs //192.168.1.20/musik /srv/famtask-music \
     -o username=NASUSER,password=GEHEIM,uid=0,gid=0,ro

# NFS
sudo mkdir -p /mnt/nas/music
sudo mount -t nfs 192.168.1.30:/export/music /mnt/nas/music

# Prüfen – muss Dateien zeigen
ls /srv/famtask-music
```

**2. Bind-Mount aktivieren.** In `docker-compose.yml` die Zeile unter `volumes:`
einkommentieren und den Host-Pfad anpassen:

```yaml
- /srv/famtask-music:/mnt/music:ro
```

**3. Neu starten:**

```bash
docker compose up -d
```

**4. In FamTask anlegen:** Admin → Musikquellen → Art **„Gemountetes Laufwerk"**,
Adresse `/mnt/music`, Übernahme **Verlinken**.

Erlaubte Stammpfade stehen in `FAMTASK_REMOTE_ROOTS` (Standard
`/mnt,/media,/srv,/net,/Volumes`). Alles ausserhalb wird mit HTTP 403 abgewiesen,
damit niemand versehentlich `/etc` in die Jukebox hängen kann.

> WebDAV, FTP und HTTPS brauchen **keinen** Mount – dafür reicht die Adresse in
> FamTask allein.

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
docker compose up -d --build      # Compose-Datei liegt im Repository-Stamm
bash scripts/setup.sh
```

## Deinstallation

```bash
cd /opt/famtask_docker
docker compose down -v
rm -rf /opt/famtask_docker
```

> ⚠️ **Bekannter Widerspruch:** Die Skripte in
> [famtask_proxmox](https://github.com/nanoemilios/famtask_proxmox) rufen weiterhin
> `docker/docker-compose.yml` auf. Diese Datei existiert nicht – die Compose-Datei
> liegt im Repository-Stamm. Ausserdem liest `scripts/setup.sh` die `.env` aus
> `docker/.env`, waehrend Compose standardmaessig `.env` aus dem Arbeitsverzeichnis
> erwartet. Details in
> [famtask_docs/WORKSPACE_COMPARISON.md](https://github.com/nanoemilios/famtask_docs/blob/main/WORKSPACE_COMPARISON.md).
> Die Befehle oben in diesem README sind die korrekte Form.

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
- **famtask_docs** – ausführliche Dokumentation

## Sicherheit

> ⚠️ FamTask hat keine echte Benutzerverwaltung – der Familiencode ist keine
> Authentifizierung. **Nicht ungeschützt ins Internet stellen.** Empfehlung:
> nur im Heimnetz betreiben oder einen Reverse-Proxy mit Basic-Auth davorsetzen.

Die Ports 8888 (App), 8081 (phpMyAdmin) und 3307 (Datenbank) gehören **nicht**
ins Internet. 3307 sollte nach dem Setup gar nicht mehr von aussen erreichbar
sein – bei Bedarf in `docker-compose.yml` die Port-Zuweisung entfernen.

## Lizenz

Keine Lizenz definiert.