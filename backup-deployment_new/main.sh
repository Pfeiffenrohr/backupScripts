#!/bin/bash

# Haupt-Script für Backup-Deployment
# Führt alle Schritte für ein komplettes Nextcloud-Backup-Deployment durch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

# Deployment-Start-Zeit speichern
echo "$(date)" > /tmp/deployment_start_time 2>/dev/null || true

# Banner anzeigen
echo "=========================================="
echo "    NEXTCLOUD BACKUP DEPLOYMENT SCRIPT    "
echo "=========================================="
echo ""

log_info "Starte Backup-Deployment"
log_info "Deployment-Zeit: $(date)"
log_info "Ziel-Server: $REMOTE_USER@$DOMAIN"
log_info ""

# Übersicht der geplanten Aktionen
log_info "Geplante Aktionen:"
log_info "  1. Verbindung und Voraussetzungen prüfen"
log_info "  2. Docker und Docker Compose installieren"
log_info "  3. Backup-Dateien kopieren"
log_info "  4. Dateien verarbeiten (entpacken/entzippen)"
log_info "  5. Domain-Ersetzung (optional)"
log_info "  6. Docker-Image erstellen (optional)"
log_info "  7. Datenbank starten und SQL-Import"
log_info "  8. Nextcloud-Core reparieren (falls nötig)"
log_info "  9. Datenbank-Schema reparieren (falls nötig)"
log_info "  10. Vollständiges Deployment starten"
log_info "  11. Verifikation und Tests"
echo ""

# Bestätigung vor Start
read -p "Möchtest du das komplette Deployment starten? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment abgebrochen."
    exit 0
fi

echo ""

# ===========================================
# SCHRITT 1: VERBINDUNG UND VORAUSSETZUNGEN
# ===========================================
log_step "1/11: Verbindung und Voraussetzungen prüfen"

if ! "$SCRIPT_DIR/scripts/01_check_connection.sh"; then
    log_error "Schritt 1 fehlgeschlagen: Verbindungsprüfung"
    log_error "Deployment wird abgebrochen."
    exit 1
fi

log_success "Schritt 1 erfolgreich abgeschlossen"
echo ""

# ===========================================
# SCHRITT 2: DOCKER INSTALLATION
# ===========================================
log_step "2/11: Docker und Docker Compose installieren"

if ! "$SCRIPT_DIR/scripts/02_install_docker.sh"; then
    log_error "Schritt 2 fehlgeschlagen: Docker-Installation"
    log_error "Deployment wird abgebrochen."
    exit 1
fi

log_success "Schritt 2 erfolgreich abgeschlossen"
echo ""

# ===========================================
# SCHRITT 3: DATEIEN KOPIEREN
# ===========================================
log_step "3/11: Backup-Dateien kopieren"

log_info "Folgende Dateien werden kopiert:"
log_info "  - $(basename "$DATA_FILE")"
log_info "  - $(basename "$VIDEO_FILE")"
log_info "  - $(basename "$SQL_FILE")"
echo ""

if ! "$SCRIPT_DIR/scripts/03_copy_files.sh"; then
    log_error "Schritt 3 fehlgeschlagen: Dateien kopieren"
    log_error "Deployment wird abgebrochen."
    exit 1
fi

log_success "Schritt 3 erfolgreich abgeschlossen"
echo ""

# ===========================================
# SCHRITT 4: DATEIEN VERARBEITEN
# ===========================================
log_step "4/11: Dateien verarbeiten"

log_info "Dateiverarbeitung:"
log_info "  - data.tar.gz_0 → umbenennen → entpacken in /"
log_info "  - data_video.tar.gz_0 → umbenennen → entpacken in /"
log_info "  - nextcloud_dump.sql.gz → entzippen in /root/"
echo ""

if ! "$SCRIPT_DIR/scripts/04_process_files.sh"; then
    log_error "Schritt 4 fehlgeschlagen: Dateien verarbeiten"
    log_error "Deployment wird abgebrochen."
    exit 1
fi

log_success "Schritt 4 erfolgreich abgeschlossen"
echo ""

# ===========================================
# SCHRITT 5: DOMAIN-ERSETZUNG (OPTIONAL)
# ===========================================
log_step "5/11: Domain-Ersetzung (optional)"

if [ -n "$OLD_DOMAIN" ] && [ -n "$NEW_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
    log_info "Domain-Ersetzung verfügbar:"
    log_info "  Alte Domain: $OLD_DOMAIN"
    log_info "  Neue Domain: $NEW_DOMAIN"
    log_info "  Zielverzeichnis: $DOMAIN_REPLACE_PATH"
    echo ""
    
    read -p "Domain-Ersetzung durchführen? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! "$SCRIPT_DIR/scripts/05_replace_domain.sh"; then
            log_error "Schritt 5 fehlgeschlagen: Domain-Ersetzung"
            log_warning "Deployment kann trotzdem fortgesetzt werden."
            
            read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Deployment abgebrochen."
                exit 1
            fi
        else
            log_success "Schritt 5 erfolgreich abgeschlossen"
        fi
    else
        log_info "Domain-Ersetzung übersprungen"
    fi
else
    log_info "Keine Domain-Ersetzung konfiguriert oder nötig"
    log_info "  OLD_DOMAIN: ${OLD_DOMAIN:-'nicht gesetzt'}"
    log_info "  NEW_DOMAIN: ${NEW_DOMAIN:-'nicht gesetzt'}"
fi

echo ""

# ===========================================
# SCHRITT 6: DOCKER IMAGE ERSTELLEN (OPTIONAL)
# ===========================================
log_step "6/11: Docker-Image erstellen (optional)"

log_info "Möchtest du das Database-Dump Docker-Image erstellen?"
log_info "Image-Name: databasedump"
log_info "Dockerfile-Pfad: $DOMAIN_REPLACE_PATH/ggg/prepare/mysql-backup"
echo ""

read -p "Docker-Image erstellen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/08_build_docker_image.sh"; then
        log_error "Schritt 6 fehlgeschlagen: Docker-Image-Erstellung"
        log_warning "Deployment kann trotzdem fortgesetzt werden."
        
        read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment abgebrochen."
            exit 1
        fi
    else
        log_success "Schritt 6 erfolgreich abgeschlossen"
    fi
else
    log_info "Docker-Image-Erstellung übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 7: DATENBANK STARTEN UND IMPORT
# ===========================================
log_step "7/11: Datenbank starten und SQL-Import"

log_info "Starte Datenbank und importiere SQL-Dump:"
log_info "  - nextcloud-mariadb (Datenbank)"
log_info "  - databasedump (Import-Tool)"
log_info "  - Import von nextcloud_dump.sql"
echo ""

read -p "Datenbank-Import durchführen? (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/09_start_db_and_import_fixed.sh"; then
        log_error "Schritt 7 fehlgeschlagen: Datenbank-Import"
        log_warning "Möchtest du trotzdem fortfahren?"
        
        read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment abgebrochen."
            exit 1
        fi
    else
        log_success "Schritt 7 erfolgreich abgeschlossen"
    fi
else
    log_info "Datenbank-Import übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 8: NEXTCLOUD-CORE REPARIEREN (FALLS NÖTIG)
# ===========================================
log_step "8/11: Nextcloud-Core reparieren (falls nötig)"

log_info "Möchtest du die Nextcloud-Core-Dateien prüfen und reparieren?"
log_info "Dies ist nötig wenn:"
log_info "  - Fehlende Core-Dateien (console.php, occ, lib/...)"
log_info "  - versioncheck.php Fehler"
log_info "  - Unvollständige Nextcloud-Installation"
echo ""

read -p "Core-Reparatur durchführen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/13_repair_nextcloud34_latest.sh"; then
        log_error "Schritt 8 fehlgeschlagen: Core-Reparatur"
        log_warning "Deployment kann trotzdem fortgesetzt werden."
        
        read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment abgebrochen."
            exit 1
        fi
    else
        log_success "Schritt 8 erfolgreich abgeschlossen"
    fi
else
    log_info "Core-Reparatur übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 9: DATENBANK-SCHEMA REPARIEREN (FALLS NÖTIG)
# ===========================================
log_step "9/11: Datenbank-Schema reparieren (falls nötig)"

log_info "Möchtest du das Datenbank-Schema prüfen und reparieren?"
log_info "Dies ist nötig wenn:"
log_info "  - 500 Fehler beim Login"
log_info "  - 'Column not found' Fehler"
log_info "  - App und DB aus verschiedenen Zeiten stammen"
echo ""

read -p "Schema-Reparatur durchführen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/14_fix_database_schema.sh"; then
        log_error "Schritt 9 fehlgeschlagen: Schema-Reparatur"
        log_warning "Deployment kann trotzdem fortgesetzt werden."
        
        read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment abgebrochen."
            exit 1
        fi
    else
        log_success "Schritt 9 erfolgreich abgeschlossen"
    fi
else
    log_info "Schema-Reparatur übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 10: VOLLSTÄNDIGES DEPLOYMENT STARTEN
# ===========================================
log_step "10/11: Vollständiges Nextcloud-Deployment starten"

log_info "Starte alle Nextcloud-Container:"
log_info "  - proxy (Nginx Reverse Proxy)"
log_info "  - letsencrypt (SSL-Zertifikate)"
log_info "  - db (MariaDB - falls noch nicht gestartet)"
log_info "  - app (Nextcloud-Anwendung)"
log_info "  - elasticsearch (Volltextsuche)"
log_info "  - nextcloud-appapi-dsp (App-API)"
echo ""

read -p "Vollständiges Deployment starten? (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/11_complete_deployment_with_ssl.sh"; then
        log_error "Schritt 10 fehlgeschlagen: Vollständiges Deployment"
        log_warning "Möchtest du trotzdem zur Verifikation?"
        
        read -p "Zur Verifikation? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment abgebrochen."
            exit 1
        fi
    else
        log_success "Schritt 10 erfolgreich abgeschlossen"
    fi
else
    log_info "Vollständiges Deployment übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 11: VERIFIKATION UND TESTS
# ===========================================
log_step "11/11: Verifikation und Tests"

log_info "Führe finale Verifikation durch:"
log_info "  - Container-Status prüfen"
log_info "  - SSL-Zertifikat testen"
log_info "  - Nextcloud-Erreichbarkeit"
log_info "  - Datenbank-Verbindung"
log_info "  - Domain-Ersetzung (falls durchgeführt)"
echo ""

read -p "Finale Verifikation durchführen? (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    
    # Container-Status
    log_info "Prüfe Container-Status..."
    run_ssh_command "
    cd $DOMAIN_REPLACE_PATH &&
    echo 'Container-Status:' &&
    docker-compose -f docker-compose.yaml ps &&
    echo '' &&
    echo 'Docker-System-Info:' &&
    docker system df
    "
    
    # SSL-Test
    if [ -n "$NEW_DOMAIN" ]; then
        log_info "Prüfe SSL-Zertifikat für $NEW_DOMAIN..."
        run_ssh_command "
        cd $DOMAIN_REPLACE_PATH &&
        if [ -f './proxy/certs/$NEW_DOMAIN.crt' ]; then
            echo '✅ SSL-Zertifikat vorhanden für $NEW_DOMAIN'
            openssl x509 -in './proxy/certs/$NEW_DOMAIN.crt' -noout -dates 2>/dev/null || echo 'Zertifikat-Details nicht lesbar'
        else
            echo '⚠ SSL-Zertifikat für $NEW_DOMAIN noch nicht verfügbar'
            echo 'Let'\''s Encrypt Logs:'
            docker logs nextcloud-letsencrypt --tail=10 2>/dev/null || echo 'Keine Let'\''s Encrypt Logs verfügbar'
        fi
        "
    fi
    
    # Nextcloud-Funktionstest
    log_info "Prüfe Nextcloud-Funktionalität..."
    run_ssh_command "
    cd $DOMAIN_REPLACE_PATH &&
    echo 'Nextcloud-Status:' &&
    docker-compose -f docker-compose.yaml exec -T app php occ status 2>/dev/null || echo 'OCC nicht verfügbar' &&
    echo '' &&
    echo 'Nextcloud-Version:' &&
    docker-compose -f docker-compose.yaml exec -T app php occ -V 2>/dev/null || echo 'Version nicht abrufbar' &&
    echo '' &&
    echo 'Wartungsmodus-Status:' &&
    docker-compose -f docker-compose.yaml exec -T app php occ maintenance:mode 2>/dev/null || echo 'Wartungsmodus-Status nicht abrufbar'
    "
    
    # HTTP/HTTPS-Test
    if [ -n "$NEW_DOMAIN" ]; then
        log_info "Teste HTTP/HTTPS-Erreichbarkeit..."
        run_ssh_command "
        echo 'HTTP-Test für $NEW_DOMAIN:'
        curl -I http://$NEW_DOMAIN/ 2>/dev/null | head -3 || echo 'HTTP nicht erreichbar'
        echo ''
        echo 'HTTPS-Test für $NEW_DOMAIN:'
        curl -I https://$NEW_DOMAIN/ 2>/dev/null | head -3 || echo 'HTTPS noch nicht verfügbar (normal bei frischen SSL-Zertifikaten)'
        "
    fi
    
    # Domain-Verifikation
    if [ -n "$OLD_DOMAIN" ] && [ -n "$NEW_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
        log_info "Prüfe Domain-Ersetzung..."
        run_ssh_command "
        cd $DOMAIN_REPLACE_PATH &&
        echo 'Suche nach alter Domain ($OLD_DOMAIN):' &&
        grep -r '$OLD_DOMAIN' . 2>/dev/null | head -3 || echo 'Keine alte Domain gefunden (✅)' &&
        echo '' &&
        echo 'Suche nach neuer Domain ($NEW_DOMAIN):' &&
        grep -r '$NEW_DOMAIN' . 2>/dev/null | head -3 || echo 'Neue Domain nicht gefunden (⚠)'
        "
    fi
    
    log_success "Verifikation abgeschlossen"
else
    log_info "Verifikation übersprungen"
fi

echo ""

# ===========================================
# DEPLOYMENT ABGESCHLOSSEN
# ===========================================
log_success "=========================================="
log_success "   NEXTCLOUD BACKUP-DEPLOYMENT ABGESCHLOSSEN!"
log_success "=========================================="

echo ""
log_info "📋 ZUSAMMENFASSUNG:"
log_info "════════════════════════════════════════"

# Schritt-Status
log_success "✅ Schritt 1: Verbindung und Voraussetzungen geprüft"
log_success "✅ Schritt 2: Docker und Docker Compose installiert"
log_success "✅ Schritt 3: Backup-Dateien kopiert"
log_success "✅ Schritt 4: Dateien verarbeitet"

if [ -n "$OLD_DOMAIN" ] && [ -n "$NEW_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
    log_success "✅ Schritt 5: Domain-Ersetzung durchgeführt"
else
    log_info "➖ Schritt 5: Domain-Ersetzung nicht nötig"
fi

log_success "✅ Schritt 6: Docker-Image erstellt (optional)"
log_success "✅ Schritt 7: Datenbank gestartet und SQL importiert"
log_success "✅ Schritt 8: Nextcloud-Core repariert (optional)"
log_success "✅ Schritt 9: Datenbank-Schema repariert (optional)"
log_success "✅ Schritt 10: Vollständiges Deployment gestartet"
log_success "✅ Schritt 11: Verifikation durchgeführt"

echo ""
log_info "📁 VERARBEITETE DATEIEN:"
log_info "════════════════════════════════════════"
log_success "  ✓ data.tar.gz - entpackt im Root-Verzeichnis (/)"
log_success "  ✓ data_video.tar.gz - entpackt im Root-Verzeichnis (/)" 
log_success "  ✓ nextcloud_dump.sql - importiert in MariaDB"

if [ -n "$OLD_DOMAIN" ] && [ -n "$NEW_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
    log_success "  ✓ Domain-Ersetzung: $OLD_DOMAIN → $NEW_DOMAIN"
fi

echo ""
log_info "🐳 DOCKER-STATUS:"
log_info "════════════════════════════════════════"
run_ssh_command "
cd $DOMAIN_REPLACE_PATH &&
echo 'Laufende Container:' &&
docker-compose -f docker-compose.yaml ps | grep 'Up' | wc -l &&
echo 'Container-Details:' &&
docker-compose -f docker-compose.yaml ps
"

echo ""
log_info "🌐 ZUGRIFF AUF NEXTCLOUD:"
log_info "════════════════════════════════════════"
if [ -n "$NEW_DOMAIN" ]; then
    log_success "  🔗 Nextcloud-URL: https://$NEW_DOMAIN"
    log_info "  📱 HTTP wird automatisch auf HTTPS umgeleitet"
else
    log_info "  🔗 Nextcloud-URL: https://$DOMAIN"
fi

echo ""
log_info "🔧 BEI PROBLEMEN:"
log_info "════════════════════════════════════════"
log_info "  Container-Logs prüfen:"
log_info "    ssh $REMOTE_USER@$DOMAIN"
log_info "    cd $DOMAIN_REPLACE_PATH"
log_info "    docker-compose -f docker-compose.yaml logs [container-name]"
log_info ""
log_info "  Nextcloud-Logs:"
log_info "    docker-compose -f docker-compose.yaml logs app"
log_info ""
log_info "  SSL-Probleme:"
log_info "    docker-compose -f docker-compose.yaml logs letsencrypt"

echo ""
log_info "⏰ DEPLOYMENT-DETAILS:"
log_info "════════════════════════════════════════"
log_info "  Start-Zeit: $(cat /tmp/deployment_start_time 2>/dev/null || echo 'Unbekannt')"
log_info "  Ende-Zeit:  $(date)"
log_info "  Server:     $REMOTE_USER@$DOMAIN"
if [ -n "$NEW_DOMAIN" ]; then
    log_info "  Domain:     $NEW_DOMAIN"
fi
log_info "  Compose-Pfad: $DOMAIN_REPLACE_PATH"

echo ""
log_success "🎉 NEXTCLOUD-DEPLOYMENT ERFOLGREICH ABGESCHLOSSEN!"
log_info ""
log_info "Deine Nextcloud sollte jetzt unter https://$NEW_DOMAIN erreichbar sein!"
log_info "Bei der ersten Anmeldung können SSL-Zertifikate noch einige Minuten brauchen."

# Optional: Aufräumen
echo ""
read -p "Möchtest du temporäre lokale Dateien aufräumen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Räume temporäre Dateien auf..."
    rm -f /tmp/deployment_start_time
    rm -f /tmp/*_backup.sh
    rm -f /tmp/install_docker.sh
    rm -f /tmp/process_files.sh
    rm -f /tmp/replace_domain.sh
    rm -f /tmp/verify_domain.sh
    log_success "Aufräumen abgeschlossen"
fi

echo ""
log_success "Vielen Dank für die Nutzung des Nextcloud Backup-Deployment-Scripts! 🚀"
echo ""
log_info "🎯 QUICK-START:"
log_info "  1. Öffne: https://$NEW_DOMAIN"
log_info "  2. Logge dich mit deinen Nextcloud-Zugangsdaten ein"
log_info "  3. Bei Problemen: Prüfe Container-Logs auf dem Server"
echo ""
