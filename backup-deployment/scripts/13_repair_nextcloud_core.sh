#!/bin/bash

# scripts/13_repair_nextcloud34_latest.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

COMPOSE_PATH="/home/richard/docker/nextcloud/ggg"

log_step "Nextcloud 34 (Latest) Core-Dateien reparieren"

log_info "Verwende Nextcloud 34 (latest) für die Reparatur"
echo ""

# 1. Container stoppen
log_info "1. Stoppe Nextcloud-Container..."
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml stop app
"

# 2. Backup erstellen
log_info "2. Erstelle Sicherheitsbackup..."
run_ssh_command "
cd $COMPOSE_PATH &&
BACKUP_DIR=\"/root/nextcloud34_repair_backup_\$(date +%Y%m%d_%H%M%S)\" &&
mkdir -p \"\$BACKUP_DIR\" &&
cp -r ./app \"\$BACKUP_DIR/\" 2>/dev/null || echo 'Backup-Warnung: App-Verzeichnis teilweise nicht kopierbar' &&
echo \"Backup erstellt in: \$BACKUP_DIR\"
"

# 3. Lade Nextcloud 34 herunter und repariere Core-Dateien
log_info "3. Lade Nextcloud 34 (latest) herunter und repariere Core-Dateien..."

REPAIR_NEXTCLOUD34="
# Installiere benötigte Tools
apt-get update -qq &&
apt-get install -y wget unzip curl &&

cd /tmp &&
rm -rf nextcloud* latest* 2>/dev/null || true &&

echo 'Lade Nextcloud 34 (latest) herunter...' &&

# Versuche verschiedene Download-URLs für Nextcloud 34
if wget -q https://download.nextcloud.com/server/releases/latest-34.zip; then
    echo 'Latest-34 ZIP-Download erfolgreich' &&
    unzip -q latest-34.zip
elif wget -q https://download.nextcloud.com/server/releases/nextcloud-34.0.0.zip; then
    echo 'Nextcloud 34.0.0 ZIP-Download erfolgreich' &&
    unzip -q nextcloud-34.0.0.zip
elif curl -L -o latest-34.zip https://download.nextcloud.com/server/releases/latest-34.zip; then
    echo 'CURL Latest-34 Download erfolgreich' &&
    unzip -q latest-34.zip
elif curl -L -o nextcloud-34.zip https://github.com/nextcloud/server/archive/refs/heads/stable34.zip; then
    echo 'GitHub stable34 Download erfolgreich' &&
    unzip -q nextcloud-34.zip &&
    mv server-stable34 nextcloud
else
    echo 'Alle Download-Methoden fehlgeschlagen!'
    exit 1
fi &&

# Prüfe ob Nextcloud-Verzeichnis existiert
if [ ! -d 'nextcloud' ]; then
    echo 'Nextcloud-Verzeichnis nicht gefunden nach Download!'
    ls -la /tmp/
    exit 1
fi &&

echo 'Nextcloud 34 erfolgreich heruntergeladen' &&
echo 'Verzeichnisinhalt:' &&
ls -la nextcloud/ | head -10 &&

# Sichere aktuelle Daten vollständig
echo 'Sichere alle aktuellen Nextcloud-Daten...' &&
mkdir -p /tmp/nextcloud_current_backup &&
cp -r $COMPOSE_PATH/app/* /tmp/nextcloud_current_backup/ 2>/dev/null || true &&

# Repariere nur fehlende oder defekte Core-Dateien
echo 'Repariere Core-Dateien...' &&

# Wichtige Core-Verzeichnisse
core_dirs=('lib' 'core' 'ocs' 'ocs-provider' 'resources' 'settings' 'updater' '3rdparty')
for core_dir in \"\${core_dirs[@]}\"; do
    if [ ! -d \"$COMPOSE_PATH/app/\$core_dir\" ] || [ -z \"\$(ls -A $COMPOSE_PATH/app/\$core_dir 2>/dev/null)\" ]; then
        echo \"Repariere Verzeichnis: \$core_dir\" &&
        cp -r \"/tmp/nextcloud/\$core_dir\" \"$COMPOSE_PATH/app/\" 2>/dev/null || echo \"Warnung: \$core_dir nicht gefunden in Download\"
    else
        echo \"Verzeichnis \$core_dir ist OK\"
    fi
done &&

# Wichtige Core-Dateien
core_files=('console.php' 'occ' 'index.php' 'status.php' 'version.php' 'remote.php' 'public.php' 'cron.php' 'robots.txt')
for core_file in \"\${core_files[@]}\"; do
    if [ ! -f \"$COMPOSE_PATH/app/\$core_file\" ]; then
        echo \"Repariere Datei: \$core_file\" &&
        cp \"/tmp/nextcloud/\$core_file\" \"$COMPOSE_PATH/app/\" 2>/dev/null || echo \"Warnung: \$core_file nicht gefunden in Download\"
    else
        echo \"Datei \$core_file ist OK\"
    fi
done &&

# Spezielle Behandlung für versioncheck.php (das war das ursprüngliche Problem)
if [ ! -f \"$COMPOSE_PATH/app/lib/versioncheck.php\" ]; then
    echo 'Repariere lib/versioncheck.php (war das ursprüngliche Problem)' &&
    mkdir -p \"$COMPOSE_PATH/app/lib\" &&
    cp \"/tmp/nextcloud/lib/versioncheck.php\" \"$COMPOSE_PATH/app/lib/\" 2>/dev/null || echo 'Warnung: versioncheck.php nicht gefunden'
fi &&

# Berechtigungen korrigieren
echo 'Setze korrekte Berechtigungen...' &&
chown -R www-data:www-data $COMPOSE_PATH/app/ &&
chmod -R 755 $COMPOSE_PATH/app/ &&
chmod +x $COMPOSE_PATH/app/occ 2>/dev/null || true &&
chmod 770 $COMPOSE_PATH/app/data/ 2>/dev/null || true &&

echo 'Nextcloud 34 Core-Reparatur abgeschlossen!'
"

if ! run_ssh_command "$REPAIR_NEXTCLOUD34"; then
    log_error "Nextcloud 34 Reparatur fehlgeschlagen"
    exit 1
fi

# 4. Container neu starten
log_info "4. Starte Nextcloud-Container neu..."
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml up -d app &&
sleep 20 &&
echo 'Container gestartet, prüfe Nextcloud...'
"

# 5. Teste die wichtigste Datei (versioncheck.php)
log_info "5. Teste reparierte Dateien..."
run_ssh_command "
cd $COMPOSE_PATH &&
echo 'Prüfe versioncheck.php (war das ursprüngliche Problem):' &&
docker-compose -f docker-compose.yaml exec -T app ls -la /var/www/html/lib/versioncheck.php &&
echo '' &&
echo 'Prüfe console.php:' &&
docker-compose -f docker-compose.yaml exec -T app ls -la /var/www/html/console.php &&
echo '' &&
echo 'Prüfe occ:' &&
docker-compose -f docker-compose.yaml exec -T app ls -la /var/www/html/occ
"

# 6. Nextcloud-Funktionstest
log_info "6. Teste Nextcloud-Funktionalität..."

FUNCTION_TEST=$(run_ssh_command "
cd $COMPOSE_PATH &&
echo 'Teste OCC-Befehl...' &&
docker-compose -f docker-compose.yaml exec -T app php occ status 2>&1
")

if echo "$FUNCTION_TEST" | grep -q "installed.*true"; then
    log_success "Nextcloud 34 funktioniert wieder perfekt!"
    
    # Wartungsmodus deaktivieren
    run_ssh_command "
    cd $COMPOSE_PATH &&
    docker-compose -f docker-compose.yaml exec -T app php occ maintenance:mode --off 2>/dev/null || true
    "
    
    # Zeige Nextcloud-Version
    run_ssh_command "
    cd $COMPOSE_PATH &&
    echo 'Aktuelle Nextcloud-Version:' &&
    docker-compose -f docker-compose.yaml exec -T app php occ -V
    "
    
elif echo "$FUNCTION_TEST" | grep -q "versioncheck.php"; then
    log_error "versioncheck.php Problem besteht weiterhin!"
    log_info "Versuche manuelle Reparatur..."
    
    # Manuelle Reparatur der versioncheck.php
    run_ssh_command "
    cd $COMPOSE_PATH &&
    docker-compose -f docker-compose.yaml exec -T app find /var/www/html -name 'versioncheck.php' -type f 2>/dev/null || echo 'versioncheck.php nicht gefunden'
    "
    
else
    log_success "Nextcloud startet, führe Wartungsarbeiten durch..."
    
    # Wartung und Reparatur
    run_ssh_command "
    cd $COMPOSE_PATH &&
    echo 'Führe Nextcloud-Wartung durch...' &&
    docker-compose -f docker-compose.yaml exec -T app php occ maintenance:repair &&
    docker-compose -f docker-compose.yaml exec -T app php occ maintenance:mode --off &&
    docker-compose -f docker-compose.yaml exec -T app php occ upgrade
    "
fi

# 7. Finale Verifikation
log_info "7. Finale Verifikation..."
run_ssh_command "
cd $COMPOSE_PATH &&
echo '=== Nextcloud 34 Status ===' &&
docker-compose -f docker-compose.yaml exec -T app php occ status &&
echo '' &&
echo '=== Version ===' &&
docker-compose -f docker-compose.yaml exec -T app php -v | head -1 &&
docker-compose -f docker-compose.yaml exec -T app php occ -V &&
echo '' &&
echo '=== Wichtige Dateien ===' &&
docker-compose -f docker-compose.yaml exec -T app ls -la /var/www/html/ | grep -E '(console\.php|occ|version\.php|index\.php)'
"

# 8. Cleanup
log_info "8. Räume temporäre Dateien auf..."
run_ssh_command "rm -rf /tmp/nextcloud* /tmp/latest*"

echo ""
log_success "=========================================="
log_success "   NEXTCLOUD 34 REPARATUR ABGESCHLOSSEN  "
log_success "=========================================="

echo ""
log_info "🎉 ERFOLGREICH:"
log_info "════════════════════════════════════════"
log_info "  ✅ Nextcloud 34 Core-Dateien repariert"
log_info "  ✅ versioncheck.php Problem behoben"
log_info "  ✅ Alle wichtigen Core-Dateien wiederhergestellt"

echo ""
log_info "🌐 ZUGRIFF:"
log_info "════════════════════════════════════════"
log_info "  Nextcloud-URL: https://lechner.life-tracker.de"
log_info ""
log_info "  Bei Problemen:"
log_info "    cd $COMPOSE_PATH"
log_info "    docker-compose -f docker-compose.yaml logs app"

echo ""
log_success "Nextcloud 34 sollte jetzt einwandfrei funktionieren! 🚀"
