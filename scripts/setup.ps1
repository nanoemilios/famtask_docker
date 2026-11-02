# FamTask Docker Setup für Windows/PowerShell
$PROJECT_ROOT = Resolve-Path "$PSScriptRoot\.."
$MY_DIR = "$PROJECT_ROOT\my"
$CFG = "$MY_DIR\.famtask_cfg.php"
$ENV_FILE = "$PROJECT_ROOT\docker\.env"

Write-Host "=== FamTask Docker Setup ===" -ForegroundColor Cyan

# 1. App-Repo klonen falls nicht vorhanden
if (-not (Test-Path "$MY_DIR\.git")) {
    Write-Host "Klone FamTask App-Repo..." -ForegroundColor Yellow
    git clone https://github.com/nanoemilios/famtask.git "$MY_DIR"
} else {
    Write-Host "App-Repo existiert, aktualisiere..." -ForegroundColor Yellow
    Set-Location "$MY_DIR"
    git fetch origin
    git reset --hard origin/main
    Set-Location "$PROJECT_ROOT"
}

# 2. .env laden
if (-not (Test-Path $ENV_FILE)) {
    Write-Host "FEHLER: $ENV_FILE nicht gefunden. Bitte zuerst .env erstellen." -ForegroundColor Red
    exit 1
}

$envContent = Get-Content $ENV_FILE | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        "[$name]=$value"
    }
} | ConvertFrom-StringData

$DB_PASS = $envContent['DB_PASS'] ?? 'famtask123'
$DB_ROOT_PASS = $envContent['DB_ROOT_PASS'] ?? 'root123'
$DB_NAME = $envContent['DB_NAME'] ?? 'famtask'
$DB_USER = $envContent['DB_USER'] ?? 'famtask'
$APP_PORT = $envContent['APP_PORT'] ?? '8888'
$PMA_PORT = $envContent['PMA_PORT'] ?? '8081'

# 3. Auf Datenbank warten
Write-Host "Warte auf Datenbank..." -ForegroundColor Yellow
do {
    $result = docker exec famtask-db mariadb -u root -p"$DB_ROOT_PASS" -e "SELECT 1" 2>$null
    if (-not $?) { Start-Sleep -Seconds 2 }
} while (-not $?)

# 4. App-Konfiguration und Datenbankschema anlegen
#    Das übernimmt der App-Installer selbst: er legt alle Tabellen an und
#    schreibt .famtask_cfg.php. Bei bestehender Konfiguration ist der Endpunkt
#    durch die Admin-Anmeldung geschützt – daher wird sie kurz beiseitegelegt.
Write-Host "Erstelle App-Konfiguration und Datenbankschema..." -ForegroundColor Yellow

$cfgBackup = $null
if (Test-Path $CFG) {
    $cfgBackup = "$CFG.bak"
    Copy-Item $CFG $cfgBackup -Force
    Remove-Item $CFG -Force
}

$installBody = @{
    host = 'mariadb'
    port = 3306
    db   = $DB_NAME
    user = $DB_USER
    pass = $DB_PASS
} | ConvertTo-Json -Compress

$installOk = $false
for ($i = 0; $i -lt 15; $i++) {
    try {
        $resp = Invoke-RestMethod -Method Post -ContentType 'application/json' `
            -Body $installBody -Uri "http://localhost:$APP_PORT/api.php?action=install" -TimeoutSec 10
        if ($resp.ok) { $installOk = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}

if ($installOk) {
    Write-Host "Konfiguration geschrieben, Tabellen angelegt." -ForegroundColor Green
    if ($cfgBackup) { Remove-Item $cfgBackup -Force }
} else {
    Write-Host "WARNUNG: App-Installer antwortete nicht wie erwartet." -ForegroundColor Red
    if ($cfgBackup) {
        Copy-Item $cfgBackup $CFG -Force
        Remove-Item $cfgBackup -Force
        Write-Host "Bestehende Konfiguration wiederhergestellt." -ForegroundColor Yellow
    } else {
        $content = @"
<?php if(!defined('FAMTASK'))die('403'); return array (
  'host' => 'mariadb',
  'port' => 3306,
  'db' => '$DB_NAME',
  'user' => '$DB_USER',
  'pass' => '$DB_PASS',
); ?>
"@
        [System.IO.File]::WriteAllText($CFG, $content)
        Write-Host "Konfiguration direkt geschrieben – bitte App-Installer prüfen." -ForegroundColor Yellow
    }
}

# Uploads (Musik, Cover) brauchen Schreibrechte im Programmverzeichnis.
New-Item -ItemType Directory -Force -Path "$MY_DIR\audio" | Out-Null
docker exec famtask-web chown -R www-data:www-data /var/www/html/audio 2>$null

Write-Host "Fertig! App ist bereit unter http://localhost:$APP_PORT" -ForegroundColor Green
Write-Host "Admin-Panel: http://localhost:$APP_PORT/?action=admin" -ForegroundColor Cyan
Write-Host "phpMyAdmin:  http://localhost:$PMA_PORT" -ForegroundColor Cyan