#!/bin/bash

# Haupt-Script für Backup-Deployment
# Führt alle Schritte für ein komplettes Nextcloud-Backup-Deployment durch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

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
log_info "  6. Verifikation (optional)"
echo ""

# Bestätigung vor Start
read -p "Möchtest du das Deployment starten? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment abgebrochen."
    exit 0
fi

echo ""

# ===========================================
# SCHRITT 1: VERBINDUNG UND VORAUSSETZUNGEN
# ===========================================
log_step "1/6: Verbindung und Voraussetzungen prüfen"

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
log_step "2/6: Docker und Docker Compose installieren"

if ! "$SCRIPT_DIR/scripts/02_install_docker.sh"; then
    log_error "Schritt 2 fehlgeschlagen: Docker-Installation"
    log_error "Deployment wird abgebrochen."
    exit 1
fi

log_success "Schritt 2 erfolgreich abgeschlossen"
#echo ""
exit 0 
# ===========================================
# SCHRITT 3: DATEIEN KOPIEREN
# ===========================================
log_step "3/6: Backup-Dateien kopieren"

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
log_step "4/6: Dateien verarbeiten"

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
log_step "5/6: Domain-Ersetzung (optional)"

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
# SCHRITT 6: VERIFIKATION (OPTIONAL)
# ===========================================
log_step "6/6: Verifikation (optional)"

log_info "Möchtest du eine Verifikation durchführen?"
log_info "Dies überprüft:"
log_info "  - Domain-Ersetzung (falls durchgeführt)"
log_info "  - Docker-Installation"
log_info "  - Entpackte Dateien"
echo ""

read -p "Verifikation durchführen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    
    # Docker-Verifikation
    log_info "Prüfe Docker-Installation..."
    if run_ssh_command "docker --version && docker-compose --version"; then
        log_success "Docker und Docker Compose sind verfügbar"
    else
        log_warning "Docker-Verifikation fehlgeschlagen"
    fi
    
    # Domain-Verifikation (falls Domain-Ersetzung konfiguriert)
    if [ -n "$OLD_DOMAIN" ] && [ -n "$NEW_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
        if [ -f "$SCRIPT_DIR/scripts/07_verify_domain.sh" ]; then
            log_info "Führe Domain-Verifikation durch..."
            if ! "$SCRIPT_DIR/scripts/07_verify_domain.sh"; then
                log_warning "Domain-Verifikation fehlgeschlagen"
            fi
        fi
    fi
    
    # Datei-Verifikation
    log_info "Prüfe entpackte Dateien..."
    run_ssh_command "
        echo 'Verzeichnisinhalt /root:';
        ls -la /root/ | grep -E '\.(sql|tar\.gz)';
        echo '';
        echo 'Docker-Compose-Dateien:';
        find /home -name 'docker-compose.y*ml' 2>/dev/null | head -5;
        echo '';
        echo 'Nextcloud-Verzeichnis:';
        ls -la $DOMAIN_REPLACE_PATH 2>/dev/null || echo 'Verzeichnis nicht gefunden';
    "
    
    log_success "Verifikation abgeschlossen"
else
    log_info "Verifikation übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 7: DOCKER IMAGE ERSTELLEN
# ===========================================
log_step "7/7: Docker-Image erstellen"

log_info "Möchtest du das Database-Dump Docker-Image erstellen?"
log_info "Image-Name: databasedump"
log_info "Dockerfile-Pfad: $DOMAIN_REPLACE_PATH/ggg/prepare/mysql-backup"
echo ""

read -p "Docker-Image erstellen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/08_build_docker_image_extended.sh"; then
        log_error "Schritt 7 fehlgeschlagen: Docker-Image-Erstellung"
        log_warning "Deployment kann trotzdem als erfolgreich betrachtet werden."
        
        read -p "Trotzdem als erfolgreich markieren? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment als fehlgeschlagen markiert."
            exit 1
        fi
    else
        log_success "Schritt 7 erfolgreich abgeschlossen"
    fi
else
    log_info "Docker-Image-Erstellung übersprungen"
fi

echo ""

# ===========================================
# SCHRITT 8: DATENBANK STARTEN UND IMPORT
# ===========================================
log_step "8/8: Datenbank-Import"

log_info "Möchtest du die Datenbank starten und den SQL-Dump importieren?"
log_info "Dies wird folgende Container starten:"
log_info "  - nextcloud-mariadb (Datenbank)"
log_info "  - databasedump (Import-Tool)"
log_info "Und dann nextcloud_dump.sql importieren"
echo ""

read -p "Datenbank-Import durchführen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/09_start_db_and_import.sh"; then
        log_error "Schritt 8 fehlgeschlagen: Datenbank-Import"
        exit 1
    else
        log_success "Schritt 8 erfolgreich abgeschlossen"
    fi
else
    log_info "Datenbank-Import übersprungen"
fi

echo ""

# ===========================================
# DEPLOYMENT ABGESCHLOSSEN
# ===========================================
log_success "=========================================="
log_success "   BACKUP-DEPLOYMENT ERFOLGREICH ABGESCHLOSSEN!"
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
    log_success "✅ Schritt 5: Domain-Ersetzung verfügbar"
else
    log_info "➖ Schritt 5: Domain-Ersetzung nicht konfiguriert"
fi

log_success "✅ Schritt 6: Deployment abgeschlossen"

echo ""
log_info "📁 VERARBEITETE DATEIEN:"
log_info "════════════════════════════════════════"
log_success "  ✓ data.tar.gz - entpackt im Root-Verzeichnis (/)"
log_success "  ✓ data_video.tar.gz - entpackt im Root-Verzeichnis (/)" 
log_success "  ✓ nextcloud_dump.sql - entzippt in /root/"

if [ -n "$OLD_DOMAIN" ] && [ -n "$NEW_DOMAIN" ] && [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
    log_success "  ✓ Domain-Ersetzung: $OLD_DOMAIN → $NEW_DOMAIN"
    log_info "    └─ Zielverzeichnis: $DOMAIN_REPLACE_PATH"
fi

echo ""
log_info "🐳 DOCKER-STATUS:"
log_info "════════════════════════════════════════"
run_ssh_command "
    echo '  Docker Version: '$(docker --version);
    echo '  Docker Compose: '$(docker-compose --version || echo 'Nicht verfügbar');
    echo '  Docker Service: '$(systemctl is-active docker);
"

echo ""
log_info "🔧 NÄCHSTE SCHRITTE:"
log_info "════════════════════════════════════════"
log_info "  1. SSH zum Server: ssh $REMOTE_USER@$DOMAIN"

if [ -d "$DOMAIN_REPLACE_PATH" ]; then
    log_info "  2. Nextcloud starten:"
    log_info "     cd $DOMAIN_REPLACE_PATH"
    log_info "     docker-compose up -d"
    log_info "  3. Logs prüfen:"
    log_info "     docker-compose logs -f"
fi

log_info "  4. SQL-Import (falls nötig):"
log_info "     # In MySQL/MariaDB Container:"
log_info "     mysql -u nextcloud -p nextcloud < /root/nextcloud_dump.sql"

echo ""
log_info "⏰ DEPLOYMENT-DETAILS:"
log_info "════════════════════════════════════════"
log_info "  Start-Zeit: $(cat /tmp/deployment_start_time 2>/dev/null || echo 'Unbekannt')"
log_info "  Ende-Zeit:  $(date)"
log_info "  Server:     $REMOTE_USER@$DOMAIN"
log_info "  Backup-Verzeichnis: /root/*backup*"

echo ""
log_success "🎉 Deployment erfolgreich abgeschlossen!"
log_info "Bei Problemen prüfe die Logs auf dem Server oder führe eine Verifikation durch."

# Deployment-Start-Zeit für Statistik speichern
echo "$(date)" > /tmp/deployment_start_time 2>/dev/null || true

# Optional: Aufräumen
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
log_success "Vielen Dank für die Nutzung des Backup-Deployment-Scripts! 🚀"
