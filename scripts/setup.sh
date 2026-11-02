#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$DIR/.."
MY_DIR="$PROJECT_ROOT/my"
CFG="$MY_DIR/.famtask_cfg.php"
ENV_FILE="$PROJECT_ROOT/docker/.env"

echo "=== FamTask Docker Setup ==="

# 1. App-Repo klonen falls nicht vorhanden
if [[ ! -d "$MY_DIR/.git" ]]; then
    echo "Klone FamTask App-Repo..."
    git clone https://github.com/nanoemilios/famtask.git "$MY_DIR"
else
    echo "App-Repo existiert, aktualisiere..."
    cd "$MY_DIR"
    git fetch origin
    git reset --hard origin/main
    cd "$PROJECT_ROOT"
fi

# 2. .env laden
if [[ ! -f "$ENV_FILE" ]]; then
    echo "FEHLER: $ENV_FILE nicht gefunden. Bitte zuerst .env erstellen."
    exit 1
fi

source "$ENV_FILE"
DB_PASS="${DB_PASS:-famtask123}"

# 3. Auf Datenbank warten
echo "Warte auf Datenbank..."
until docker exec famtask-db mariadb -u root -p"${DB_ROOT_PASS:-root123}" -e "SELECT 1" &>/dev/null; do
    sleep 2
done

# 4. App-Konfiguration und Datenbankschema anlegen
#    Das übernimmt der App-Installer selbst: er legt alle Tabellen an und
#    schreibt .famtask_cfg.php als www-data (damit Apache sie lesen kann).
#    Bei bestehender Konfiguration ist der Endpunkt durch die Admin-Anmeldung
#    geschützt – deshalb wird die Datei für den Aufruf kurz beiseitegelegt.
echo "Erstelle App-Konfiguration und Datenbankschema..."

# Der Webserver muss die Konfiguration im Programmverzeichnis anlegen dürfen.
docker exec famtask-web chgrp www-data /var/www/html 2>/dev/null || true
docker exec famtask-web chmod 775 /var/www/html 2>/dev/null || true

CFG_BACKUP=""
if [[ -f "$CFG" ]]; then
    CFG_BACKUP="$(mktemp)"
    cp -p "$CFG" "$CFG_BACKUP"
    rm -f "$CFG"
fi

# Passwort für JSON maskieren (Anführungszeichen/Backslashes in .env).
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

INSTALL_JSON="{\"host\":\"mariadb\",\"port\":3306,\"db\":\"$(json_escape "${DB_NAME:-famtask}")\",\"user\":\"$(json_escape "${DB_USER:-famtask}")\",\"pass\":\"$(json_escape "$DB_PASS")\"}"
INSTALL_RESP=""
for _ in $(seq 1 15); do
    INSTALL_RESP=$(curl -sS -X POST -H 'Content-Type: application/json' \
        --data "$INSTALL_JSON" \
        "http://localhost:${APP_PORT:-8888}/api.php?action=install" 2>/dev/null || true)
    if [[ "$INSTALL_RESP" == *'"ok":true'* ]]; then
        break
    fi
    sleep 2
done

if [[ "$INSTALL_RESP" == *'"ok":true'* ]]; then
    echo "Konfiguration geschrieben, Tabellen angelegt."
    if [[ -n "$CFG_BACKUP" ]]; then rm -f "$CFG_BACKUP"; fi
else
    echo "WARNUNG: App-Installer antwortete nicht wie erwartet: ${INSTALL_RESP:-keine Antwort}"
    if [[ -n "$CFG_BACKUP" ]]; then
        cp -p "$CFG_BACKUP" "$CFG"
        rm -f "$CFG_BACKUP"
        echo "Bestehende Konfiguration wiederhergestellt."
    else
        cat > "$CFG" << PHPEOF
<?php if(!defined('FAMTASK'))die('403'); return array (
  'host' => 'mariadb',
  'port' => 3306,
  'db' => '${DB_NAME:-famtask}',
  'user' => '${DB_USER:-famtask}',
  'pass' => '$DB_PASS',
); ?>
PHPEOF
        chmod 644 "$CFG"
        echo "Konfiguration direkt geschrieben – bitte App-Installer prüfen."
    fi
fi

# Uploads (Musik, Cover) schreiben in das Programmverzeichnis. Ohne passenden
# Besitzer scheitert das mit "Keine Schreibrechte im Programmverzeichnis".
mkdir -p "$MY_DIR/audio"
if docker exec famtask-web chown -R www-data:www-data /var/www/html/audio 2>/dev/null; then
    echo "Schreibrechte für audio/ gesetzt."
else
    echo "WARNUNG: Konnte audio/ nicht an www-data übergeben (Uploads evtl. nicht möglich)."
fi

echo "Fertig! App ist bereit unter http://localhost:${APP_PORT:-8888}"
echo "Admin-Panel: http://localhost:${APP_PORT:-8888}/?action=admin"
echo "phpMyAdmin:  http://localhost:${PMA_PORT:-8081}"