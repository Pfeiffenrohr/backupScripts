#!/bin/bash

# Script mit korrigierter MySQL-Client-Nutzung

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

# Konfiguration
COMPOSE_PATH="/home/richard/docker/nextcloud/ggg"
COMPOSE_FILE="docker-compose.yaml"
SQL_FILE="/root/nextcloud_dump.sql"
DB_SERVICE="db"
DUMP_SERVICE="databasedump"
DB_NAME="nextcloud"
DB_ROOT_PASSWORD="ren.chel"

# ===========================================
# SCHRITT 9: DATENBANK STARTEN UND IMPORT
# ===========================================

log_step "9/9: Datenbank-Container starten und SQL-Import"

log_info "Konfiguration:"
log_info "  Docker-Compose-Pfad: $COMPOSE_PATH"
log_info "  SQL-Datei: $SQL_FILE"
echo ""

# Voraussetzungen prüfen
log_info "Prüfe Voraussetzungen..."

if ! run_ssh_command "test -f $COMPOSE_PATH/$COMPOSE_FILE"; then
    log_error "docker-compose.yaml nicht gefunden: $COMPOSE_PATH/$COMPOSE_FILE"
    exit 1
fi

if ! run_ssh_command "test -f $SQL_FILE"; then
    log_error "SQL-Datei nicht gefunden: $SQL_FILE"
    exit 1
fi

log_success "Alle Voraussetzungen erfüllt"

# SQL-Datei vorbereiten
log_info "Bereite SQL-Import vor..."
run_ssh_command "
mkdir -p $COMPOSE_PATH/dump &&
cp $SQL_FILE $COMPOSE_PATH/dump/ &&
chmod 644 $COMPOSE_PATH/dump/nextcloud_dump.sql &&
ls -la $COMPOSE_PATH/dump/
"

# Container starten
log_info "Starte Container..."
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f $COMPOSE_FILE up -d $DB_SERVICE $DUMP_SERVICE &&
sleep 15
"

# MariaDB-Bereitschaft prüfen (mit mariadb-Befehl statt mysql)
log_info "Warte auf MariaDB-Bereitschaft..."

WAIT_COMMAND="
cd $COMPOSE_PATH &&
for i in {1..30}; do
    # Versuche verschiedene Client-Befehle
    if docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mariadb -u root -p'$DB_ROOT_PASSWORD' -e 'SELECT 1' >/dev/null 2>&1; then
        echo 'MariaDB ist bereit (mariadb-client)!'
        break
    elif docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mysql -u root -p'$DB_ROOT_PASSWORD' -e 'SELECT 1' >/dev/null 2>&1; then
        echo 'MariaDB ist bereit (mysql-client)!'
        break
    elif docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE sh -c 'echo \"SELECT 1;\" | mariadb -u root -p\"$DB_ROOT_PASSWORD\"' >/dev/null 2>&1; then
        echo 'MariaDB ist bereit (sh+mariadb)!'
        break
    fi
    echo \"Warte auf MariaDB... (\$i/30)\"
    sleep 2
done
"

if ! run_ssh_command "$WAIT_COMMAND"; then
    log_error "MariaDB wurde nicht rechtzeitig bereit"
    exit 1
fi

log_success "MariaDB ist bereit!"

# Container-Status anzeigen
log_info "Container-Status:"
run_ssh_command "cd $COMPOSE_PATH && docker-compose -f $COMPOSE_FILE ps"

# SQL-Import - Verschiedene Methoden versuchen
log_info "Starte SQL-Import..."

# Methode 1: mariadb-Befehl
log_info "Versuche Import mit mariadb-Client..."
IMPORT_METHOD1="
cd $COMPOSE_PATH &&
docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME < dump/nextcloud_dump.sql
"

if run_ssh_command "$IMPORT_METHOD1"; then
    log_success "SQL-Import mit mariadb-Client erfolgreich!"
    IMPORT_SUCCESS=true
else
    log_warning "mariadb-Client-Import fehlgeschlagen, versuche mysql-Client..."
    
    # Methode 2: mysql-Befehl
    IMPORT_METHOD2="
    cd $COMPOSE_PATH &&
    docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mysql -u root -p'$DB_ROOT_PASSWORD' $DB_NAME < dump/nextcloud_dump.sql
    "
    
    if run_ssh_command "$IMPORT_METHOD2"; then
        log_success "SQL-Import mit mysql-Client erfolgreich!"
        IMPORT_SUCCESS=true
    else
        log_warning "mysql-Client-Import fehlgeschlagen, versuche databasedump-Container..."
        
        # Methode 3: Über databasedump-Container
        IMPORT_METHOD3="
        cd $COMPOSE_PATH &&
        docker-compose -f $COMPOSE_FILE exec -T $DUMP_SERVICE mysql -h nextcloud-mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME < /dump/nextcloud_dump.sql
        "
        
        if run_ssh_command "$IMPORT_METHOD3"; then
            log_success "SQL-Import über databasedump-Container erfolgreich!"
            IMPORT_SUCCESS=true
        else
            log_warning "databasedump-Container-Import fehlgeschlagen, versuche Docker-exec..."
            
            # Methode 4: Direkter Docker-exec
            IMPORT_METHOD4="
            docker exec -i nextcloud-mariadb mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME < $COMPOSE_PATH/dump/nextcloud_dump.sql
            "
            
            if run_ssh_command "$IMPORT_METHOD4"; then
                log_success "SQL-Import über Docker-exec erfolgreich!"
                IMPORT_SUCCESS=true
            else
                # Methode 5: Datei in Container kopieren und dort importieren
                log_warning "Alle Standard-Methoden fehlgeschlagen, versuche Container-interne Methode..."
                
                IMPORT_METHOD5="
                docker cp $COMPOSE_PATH/dump/nextcloud_dump.sql nextcloud-mariadb:/tmp/nextcloud_dump.sql &&
                docker exec nextcloud-mariadb mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e 'source /tmp/nextcloud_dump.sql'
                "
                
                if run_ssh_command "$IMPORT_METHOD5"; then
                    log_success "SQL-Import über Container-interne Methode erfolgreich!"
                    IMPORT_SUCCESS=true
                else
                    IMPORT_SUCCESS=false
                fi
            fi
        fi
    fi
fi

if [ "$IMPORT_SUCCESS" = true ]; then
    # Import verifizieren
    log_info "Verifiziere Import..."
    
    # Versuche Verifikation mit verfügbarem Client
    VERIFY_COMMAND="
    cd $COMPOSE_PATH &&
    if docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e 'SHOW TABLES;' >/dev/null 2>&1; then
        docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e 'SHOW TABLES;' | wc -l
    elif docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mysql -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e 'SHOW TABLES;' >/dev/null 2>&1; then
        docker-compose -f $COMPOSE_FILE exec -T $DB_SERVICE mysql -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e 'SHOW TABLES;' | wc -l
    else
        docker exec nextcloud-mariadb mariadb -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e 'SHOW TABLES;' | wc -l
    fi
    "
    
    TABLE_COUNT=$(run_ssh_command "$VERIFY_COMMAND" | tail -1)
    log_success "Anzahl Tabellen in der Datenbank: $TABLE_COUNT"
    
    echo ""
    log_success "=========================================="
    log_success "   DATENBANK-IMPORT ERFOLGREICH!        "
    log_success "=========================================="
    
    echo ""
    log_info "🔧 NÄCHSTE SCHRITTE:"
    log_info "════════════════════════════════════════"
    log_info "  1. Alle Container starten:"
    log_info "     cd $COMPOSE_PATH"
    log_info "     docker-compose -f $COMPOSE_FILE up -d"
    log_info ""
    log_info "  2. Nextcloud-Logs prüfen:"
    log_info "     docker-compose -f $COMPOSE_FILE logs -f app"
    log_info ""
    log_info "  3. Nextcloud aufrufen:"
    log_info "     https://lechner.life-tracker.de"
    
else
    log_error "Alle Import-Methoden fehlgeschlagen!"
    
    # Erweiterte Fehlerdiagnose
    log_info "Erweiterte Fehlerdiagnose:"
    
    log_info "1. Verfügbare Befehle im MariaDB-Container:"
    run_ssh_command "docker exec nextcloud-mariadb ls -la /usr/bin/ | grep -E '(mysql|mariadb)'"
    
    log_info "2. Container-Umgebung:"
    run_ssh_command "docker exec nextcloud-mariadb env | grep -E '(MYSQL|MARIA)'"
    
    log_info "3. Datei-Zugriff:"
    run_ssh_command "ls -la $COMPOSE_PATH/dump/"
    
    exit 1
fi

log_success "Datenbank-Import abgeschlossen! 🗄️"
