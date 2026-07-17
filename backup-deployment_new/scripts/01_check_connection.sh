#!/bin/bash

source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../config.sh"

log_step "Verbindung testen"

# Abhängigkeiten prüfen
if ! check_dependencies; then
    exit 1
fi

# Lokale Dateien prüfen
files_to_check=("$DATA_FILE" "$VIDEO_FILE" "$SQL_FILE")
if ! check_local_files "${files_to_check[@]}"; then
    exit 1
fi

# Dateigrößen anzeigen
log_info "Zu kopierende Dateien:"
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        log_info "  - $(basename "$file"): $size"
    fi
done

# Passwort prüfen
if [ -z "$PASSWORD" ]; then
    log_error "Passwort nicht gesetzt!"
    exit 1
fi

# Verbindung testen
log_info "Teste Verbindung zum Server als $REMOTE_USER..."
if run_ssh_command "echo 'Verbindung OK'" &>/dev/null; then
    log_success "Verbindung zum Server erfolgreich"
else
    log_error "Verbindung zum Server fehlgeschlagen"
    exit 1
fi
