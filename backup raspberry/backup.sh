#!/bin/bash

#==============================================================================
# Backup Script für Nextcloud und Budget-Datenbank
# Autor: Richard
# Beschreibung: Erstellt Backups von Nextcloud-Daten, Videos und Datenbanken
#==============================================================================

# Locale-Probleme vermeiden
export LC_ALL=C
export LANG=C

# Konfiguration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/home/richard/logs"
readonly LOG_FILE="${LOG_DIR}/backup_$(date +%Y%m%d).log"
readonly BACKUP_DIR="/home/richard/backup"

# Server-Konfiguration (getrennte Hosts für SSH und SCP)
readonly NEXTCLOUD_HOST_SSH="root@nextcloud.life-tracker.de"      # Für SSH-Befehle
readonly NEXTCLOUD_HOST_SCP="richard@nextcloud.life-tracker.de"   # Für SCP-Downloads
readonly BUDGET_HOST="richard@h2915074.stratoserver.net"

# Passwörter
readonly SSH_PASSWORD="ren.chel"    # Für SSH-Befehle (root)
readonly SCP_PASSWORD="dra.chir"    # Für SCP-Downloads (richard)

readonly SSH_KEY="/home/richard/.ssh/id_rsa"
readonly NOTIFICATION_SCRIPT="/home/richard/bin/sendMeaageToTalk.sh"

# Globale Variablen
backup_success=1
version=$(date +"%u")
version=$((version % 2))

#==============================================================================
# Funktionen
#==============================================================================

# Logging-Funktion
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$*"; }
log_error() { log "ERROR" "$*"; }
log_warn() { log "WARN" "$*"; }

# Benachrichtigung senden
send_notification() {
    local message="$1"
    log_info "Sende Benachrichtigung: $message"
    "$NOTIFICATION_SCRIPT" "$message"
}

# Setup
setup() {
    log_info "=== Backup-Skript gestartet ==="
    log_info "Version: $version"
    log_info "Backup-Verzeichnis: $BACKUP_DIR"
    log_info "Log-Datei: $LOG_FILE"
    log_info "Nextcloud SSH-Server: $NEXTCLOUD_HOST_SSH"
    log_info "Nextcloud SCP-Server: $NEXTCLOUD_HOST_SCP"
    log_info "Budget-Server: $BUDGET_HOST"

    # Verzeichnisse erstellen
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
}

# Hauptdaten-Backup
backup_main_data() {
    log_info "=== Starte Hauptdaten-Backup ==="

    # Alte TAR-Datei löschen (als root)
    log_info "Lösche alte TAR-Datei auf Remote-Server"
    /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t "rm -f /home/richard/backup/data.tar.gz"
    if [ $? != 0 ]; then
        log_error "Konnte altes tarfile nicht löschen"
        send_notification "@richard Konnte altes tarfile nicht loeschen"
        backup_success=0
    fi

    # TAR-Archiv erstellen (als root)
    log_info "Erstelle TAR-Archiv der Hauptdaten"
    /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t "tar --exclude='*.mp4' --exclude='*.MOV' --exclude='*.log' --exclude='dump' --exclude='proxy' -cf /home/richa
rd/backup/data.tar /home/richard/docker/nextcloud/ggg/"
    if [ $? != 0 ]; then
        log_error "Konnte den backup tar nicht ausführen"
        send_notification "@richard konnte den bakup tar nicht ausführen"
        backup_success=0
    fi

    # TAR-Datei komprimieren (als root)
    log_info "Komprimiere TAR-Archiv"
    /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t "gzip -9 /home/richard/backup/data.tar"
    if [ $? != 0 ]; then
        log_error "Konnte das backup nicht zippen"
        send_notification "@richard konnte das backup nicht zippen"
        backup_success=0
    fi

    # Lokale alte Backups entfernen
    log_info "Entferne lokale alte Backups"
    rm -f /home/richard/backup/data.tar.gz /home/richard/backup/data.tar.gz_$version
    rm -f /home/richard/backup/data_video.tar.gz_$version

    # Backup herunterladen (als richard)
    log_info "Lade Backup herunter"
    error_output=$(/usr/bin/sshpass -p "$SCP_PASSWORD" /usr/bin/scp "$NEXTCLOUD_HOST_SCP:/home/richard/backup/data.tar.gz" /home/richard/backup 2>&1)
    if [ $? != 0 ]; then
        log_error "SCP vom backup ist gescheitert. Fehler: $error_output"
        send_notification "@richard der scp vom backuup ist gescheitert. Fehler $error_output "
        backup_success=0
    fi

    # Backup versionieren
    log_info "Versioniere Backup"
    if [ -f "/home/richard/backup/data.tar.gz" ]; then
        mv /home/richard/backup/data.tar.gz /home/richard/backup/data.tar.gz_$version
    fi
}

# Video-Backup
backup_videos() {
    log_info "=== Starte Video-Backup ==="

    # Alte Video-TAR-Datei löschen (als root)
    log_info "Lösche alte Video-TAR-Datei"
    /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t "rm -f /home/richard/backup/data_video.tar.gz"
    if [ $? != 0 ]; then
        log_error "Konnte altes video tarfile nicht löschen"
        send_notification "@richard Konnte altes video tarfile nicht loeschen"
        backup_success=0
    fi

    # Video-TAR-Archiv erstellen (als root)
    log_info "Erstelle Video-TAR-Archiv"
    /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t 'find /home/richard/docker/nextcloud/ggg/app -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0 | xargs -
0 tar -cf /home/richard/backup/data_video.tar'
    if [ $? != 0 ]; then
        log_error "Konnte den video backup tar nicht ausführen"
        send_notification "@richard konnte den video bakup tar nicht ausführen"
        backup_success=0
    fi

    # Video-TAR komprimieren (als root)
    log_info "Komprimiere Video-TAR"
    /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t "gzip -9 /home/richard/backup/data_video.tar"
    if [ $? != 0 ]; then
        log_error "Konnte das video backup nicht zippen"
        send_notification "@richard konnte das video backup nicht zippen"
        backup_success=0
    fi

    # Video-Backup herunterladen (als richard)
    log_info "Lade Video-Backup herunter"
    error_output=$(/usr/bin/sshpass -p "$SCP_PASSWORD" /usr/bin/scp "$NEXTCLOUD_HOST_SCP:/home/richard/backup/data_video.tar.gz" /home/richard/backup 2>&1)
    if [ $? != 0 ]; then
        log_error "SCP vom video backup ist gescheitert. Fehler: $error_output"
        send_notification "@richard der scp vom video backup ist gescheitert"
        backup_success=0
    fi

    # Video-Backup versionieren
    log_info "Versioniere Video-Backup"
    if [ -f "/home/richard/backup/data_video.tar.gz" ]; then
        mv /home/richard/backup/data_video.tar.gz /home/richard/backup/data_video.tar.gz_$version
    fi
}

# Datenbank-Backups
backup_databases() {
    log_info "=== Starte Datenbank-Backups ==="

    # Nextcloud-Datenbank (als richard herunterladen)
    log_info "Backup Nextcloud-Datenbank"
    /usr/bin/sshpass -p "$SCP_PASSWORD" /usr/bin/scp "$NEXTCLOUD_HOST_SCP:/home/richard/docker/nextcloud/ggg/dump/nextcloud_dump*" /home/richard/backup
    if [ $? == 0 ]; then
        log_info "Lösche Remote Nextcloud-Dumps"
        /usr/bin/sshpass -p "$SSH_PASSWORD" /usr/bin/ssh "$NEXTCLOUD_HOST_SSH" -t "rm -f /home/richard/docker/nextcloud/ggg/dump/nextcloud_dump*"
    else
        log_error "Konnte das Nextcloud Datenbankbackup nicht erstellen"
        send_notification "@richard Konnte das Nextcloud Datenbankbackup nicht erstellen"
        backup_success=0
    fi

    # Budget-Datenbank (mit SSH-Key)
    log_info "Backup Budget-Datenbank"
    /usr/bin/scp -i /home/richard/.ssh/id_rsa "$BUDGET_HOST:/home/richard/docker/CbudgetNew/dump/*" /home/richard/backup
    if [ $? -eq 0 ]; then
        log_info "Lösche Remote Budget-Dumps"
        /usr/bin/ssh -i /home/richard/.ssh/id_rsa "$BUDGET_HOST" "rm -f /home/richard/docker/CbudgetNew/dump/budget*"
    else
        log_error "Konnte das Budget Datenbankbackup nicht erstellen"
        send_notification "@richard Konnte das Budget Datenbankbackup nicht erstellen"
        backup_success=0
    fi
}

# Cleanup und finale Meldung
cleanup_and_finish() {
    log_info "=== Backup-Prozess beendet ==="

    if [ $backup_success == 1 ]; then
        log_info "Alle Backups erfolgreich abgeschlossen!"
        send_notification "Backup ok!"
    else
        log_error "Backup mit Fehlern abgeschlossen!"
    fi

    log_info "Log-Datei: $LOG_FILE"
    log_info "=== Ende des Backup-Skripts ==="
}

#==============================================================================
# Hauptprogramm
#==============================================================================

main() {
    setup
    backup_main_data
    backup_videos
    backup_databases
    cleanup_and_finish
}

# Skript ausführen
main "$@"