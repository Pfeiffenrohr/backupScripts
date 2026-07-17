#!/bin/bash

# scripts/12_diagnose_nextcloud.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

COMPOSE_PATH="/home/richard/docker/nextcloud/ggg"

log_info "=== NEXTCLOUD DIAGNOSE ==="

log_info "1. Container-Status:"
run_ssh_command "cd $COMPOSE_PATH && docker-compose -f docker-compose.yaml ps"

log_info "2. Nextcloud-Verzeichnisstruktur:"
run_ssh_command "
cd $COMPOSE_PATH &&
echo 'App-Verzeichnis:' &&
ls -la ./app/ 2>/dev/null || echo 'App-Verzeichnis fehlt' &&
echo '' &&
echo 'Nextcloud-Core-Dateien:' &&
docker-compose -f docker-compose.yaml exec -T app ls -la /var/www/html/ | head -10 &&
echo '' &&
echo 'Lib-Verzeichnis:' &&
docker-compose -f docker-compose.yaml exec -T app ls -la /var/www/html/lib/ | head -5 2>/dev/null || echo 'Lib-Verzeichnis fehlt oder leer'
"

log_info "3. Nextcloud-Version prüfen:"
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml exec -T app cat /var/www/html/version.php 2>/dev/null || echo 'version.php fehlt'
"

log_info "4. Container-Logs:"
run_ssh_command "cd $COMPOSE_PATH && docker-compose -f docker-compose.yaml logs app | tail -20"
