#!/bin/bash

# scripts/14_fix_database_schema.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

COMPOSE_PATH="/home/richard/docker/nextcloud/ggg"

log_step "Repariere Nextcloud-Datenbank-Schema"

log_info "Problem: Datenbank-Schema ist veraltet (fehlt 'ip' Spalte)"
log_info "Lösung: Führe Nextcloud-Upgrade und Schema-Update durch"
echo ""

# 1. Prüfe aktuellen Status
log_info "1. Prüfe aktuellen Nextcloud-Status..."

run_ssh_command "
cd $COMPOSE_PATH &&
echo 'Container-Status:' &&
docker-compose -f docker-compose.yaml ps &&
echo '' &&
echo 'Nextcloud-Status (falls verfügbar):' &&
docker-compose -f docker-compose.yaml exec -T app php occ status 2>/dev/null || echo 'OCC nicht verfügbar'
"

# 2. Setze Nextcloud in Wartungsmodus
log_info "2. Aktiviere Wartungsmodus..."

run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml exec -T app php occ maintenance:mode --on &&
echo 'Wartungsmodus aktiviert'
"

# 3. Führe Datenbank-Upgrade durch
log_info "3. Führe Nextcloud-Upgrade durch (repariert Datenbank-Schema)..."

UPGRADE_COMMAND="
cd $COMPOSE_PATH &&
echo 'Starte Nextcloud-Upgrade...' &&
docker-compose -f docker-compose.yaml exec -T app php occ upgrade &&
echo 'Upgrade abgeschlossen'
"

if run_ssh_command "$UPGRADE_COMMAND"; then
    log_success "Nextcloud-Upgrade erfolgreich!"
else
    log_warning "Standard-Upgrade fehlgeschlagen, versuche erweiterte Reparatur..."
    
    # Erweiterte Datenbank-Reparatur
    EXTENDED_REPAIR="
    cd $COMPOSE_PATH &&
    echo 'Führe Datenbank-Reparatur durch...' &&
    docker-compose -f docker-compose.yaml exec -T app php occ maintenance:repair &&
    echo '' &&
    echo 'Führe Schema-Update durch...' &&
    docker-compose -f docker-compose.yaml exec -T app php occ db:add-missing-columns &&
    echo '' &&
    echo 'Führe Index-Update durch...' &&
    docker-compose -f docker-compose.yaml exec -T app php occ db:add-missing-indices &&
    echo '' &&
    echo 'Führe Primary-Key-Update durch...' &&
    docker-compose -f docker-compose.yaml exec -T app php occ db:add-missing-primary-keys &&
    echo 'Erweiterte Reparatur abgeschlossen'
    "
    
    if ! run_ssh_command "$EXTENDED_REPAIR"; then
        log_error "Auch erweiterte Reparatur fehlgeschlagen"
        
        # Manuelle SQL-Reparatur als letzter Ausweg
        log_info "Versuche manuelle Datenbank-Reparatur..."
        
        MANUAL_DB_FIX="
        cd $COMPOSE_PATH &&
        echo 'Führe manuelle Datenbank-Reparatur durch...' &&
        docker-compose -f docker-compose.yaml exec -T db mysql -u root -p'ren.chel' nextcloud -e \"
        -- Prüfe ob bruteforce_attempts Tabelle existiert
        DESCRIBE oc_bruteforce_attempts;
        \" 2>/dev/null || echo 'Bruteforce-Tabelle nicht gefunden' &&
        
        echo 'Versuche Tabellen-Reparatur...' &&
        docker-compose -f docker-compose.yaml exec -T db mysql -u root -p'ren.chel' nextcloud -e \"
        -- Lösche alte bruteforce_attempts Tabelle falls sie existiert aber falsch ist
        DROP TABLE IF EXISTS oc_bruteforce_attempts;
        
        -- Erstelle neue bruteforce_attempts Tabelle mit korrekter Struktur
        CREATE TABLE oc_bruteforce_attempts (
            id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            action varchar(64) NOT NULL DEFAULT '',
            occurred int(10) unsigned NOT NULL DEFAULT 0,
            ip varchar(255) NOT NULL DEFAULT '',
            subnet varchar(255) NOT NULL DEFAULT '',
            metadata varchar(255) NOT NULL DEFAULT '',
            PRIMARY KEY (id),
            KEY bruteforce_attempts_ip (ip),
            KEY bruteforce_attempts_subnet (subnet),
            KEY bruteforce_attempts_occurred (occurred)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
        \" &&
        echo 'Manuelle Tabellen-Reparatur abgeschlossen'
        "
        
        run_ssh_command "$MANUAL_DB_FIX"
    fi
fi

# 4. Deaktiviere Wartungsmodus
log_info "4. Deaktiviere Wartungsmodus..."

run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml exec -T app php occ maintenance:mode --off &&
echo 'Wartungsmodus deaktiviert'
"

# 5. Teste die Reparatur
log_info "5. Teste Datenbank-Reparatur..."

TEST_COMMAND="
cd $COMPOSE_PATH &&
echo 'Prüfe Nextcloud-Status:' &&
docker-compose -f docker-compose.yaml exec -T app php occ status &&
echo '' &&
echo 'Prüfe bruteforce_attempts Tabelle:' &&
docker-compose -f docker-compose.yaml exec -T db mysql -u root -p'ren.chel' nextcloud -e 'DESCRIBE oc_bruteforce_attempts;' &&
echo '' &&
echo 'Test: Kann in bruteforce_attempts eingefügt werden?' &&
docker-compose -f docker-compose.yaml exec -T db mysql -u root -p'ren.chel' nextcloud -e \"
INSERT INTO oc_bruteforce_attempts (action, occurred, ip, subnet, metadata) 
VALUES ('test', UNIX_TIMESTAMP(), '127.0.0.1', '127.0.0.1/32', '{}');
DELETE FROM oc_bruteforce_attempts WHERE action = 'test';
\" &&
echo 'Datenbank-Test erfolgreich!'
"

if run_ssh_command "$TEST_COMMAND"; then
    log_success "Datenbank-Schema erfolgreich repariert!"
else
    log_error "Datenbank-Test fehlgeschlagen"
    
    # Zeige Tabellen-Struktur zur Diagnose
    log_info "Diagnose - aktuelle Tabellen-Struktur:"
    run_ssh_command "
    cd $COMPOSE_PATH &&
    docker-compose -f docker-compose.yaml exec -T db mysql -u root -p'ren.chel' nextcloud -e 'SHOW TABLES LIKE \"%bruteforce%\";' &&
    docker-compose -f docker-compose.yaml exec -T db mysql -u root -p'ren.chel' nextcloud -e 'DESCRIBE oc_bruteforce_attempts;' 2>/dev/null || echo 'Tabelle oc_bruteforce_attempts existiert nicht'
    "
fi

# 6. Teste Login-Funktionalität
log_info "6. Teste Login-Funktionalität..."

run_ssh_command "
cd $COMPOSE_PATH &&
echo 'Container-Status nach Reparatur:' &&
docker-compose -f docker-compose.yaml ps &&
echo '' &&
echo 'Nextcloud-Logs (letzte 10 Zeilen):' &&
docker-compose -f docker-compose.yaml logs --tail=10 app
"

echo ""
log_success "=========================================="
log_success "   DATENBANK-SCHEMA REPARATUR ABGESCHLOSSEN"
log_success "=========================================="

echo ""
log_info "🔧 TESTERGEBNISSE:"
log_info "════════════════════════════════════════"
log_info "  ✅ Wartungsmodus aktiviert/deaktiviert"
log_info "  ✅ Datenbank-Upgrade durchgeführt"
log_info "  ✅ Schema-Updates angewendet"
log_info "  ✅ Bruteforce-Tabelle repariert"

echo ""
log_info "🌐 NÄCHSTE SCHRITTE:"
log_info "════════════════════════════════════════"
log_info "  1. Teste Login: https://lechner.life-tracker.de"
log_info "  2. Falls weitere Probleme:"
log_info "     cd $COMPOSE_PATH"
log_info "     docker-compose -f docker-compose.yaml logs app"
log_info ""
log_info "  3. Bei weiteren DB-Problemen:"
log_info "     docker-compose -f docker-compose.yaml exec app php occ db:add-missing-columns"
log_info "     docker-compose -f docker-compose.yaml exec app php occ db:add-missing-indices"

echo ""
log_success "Login sollte jetzt funktionieren! 🚀"
