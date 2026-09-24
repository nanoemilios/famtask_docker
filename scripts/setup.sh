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

# 4. App-Konfiguration erstellen
echo "Erstelle App-Konfiguration..."
cat > "$CFG" << PHPEOF
<?php if(!defined('FAMTASK'))die('403'); return array (
  'host' => 'mariadb',
  'port' => 3306,
  'db' => '${DB_NAME:-famtask}',
  'user' => '${DB_USER:-famtask}',
  'pass' => '$DB_PASS',
); ?>
PHPEOF

chmod 600 "$CFG"

echo "Fertig! App ist bereit unter http://localhost:${APP_PORT:-8888}"
echo "Admin-Panel: http://localhost:${APP_PORT:-8888}/?action=admin"
echo "phpMyAdmin:  http://localhost:${PMA_PORT:-8081}"