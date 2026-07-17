#!/bin/bash

# Logging-Funktionen
log_error() {
    echo "✗ FEHLER: $1" >&2
}

log_success() {
    echo "✓ $1"
}

log_info() {
    echo "ℹ $1"
}

log_step() {
    echo ""
    echo "=========================================="
    echo "SCHRITT: $1"
    echo "=========================================="
}

# SSH-Befehle
run_ssh_command() {
    local command="$1"
    sshpass -p "$PASSWORD" ssh $SSH_OPTS "$REMOTE_USER@$DOMAIN" "$command"
}

run_ssh_script() {
    local script="$1"
    sshpass -p "$PASSWORD" ssh $SSH_OPTS "$REMOTE_USER@$DOMAIN" 'bash -s' < "$script"
}

copy_file() {
    local local_file="$1"
    local timeout="${2:-60}"
    
    log_info "Kopiere $(basename "$local_file")..."
    if sshpass -p "$PASSWORD" scp -o ConnectTimeout="$timeout" -o StrictHostKeyChecking=no "$local_file" "$REMOTE_USER@$DOMAIN:$REMOTE_PATH"; then
        log_success "$(basename "$local_file") erfolgreich kopiert"
        return 0
    else
        log_error "Kopieren von $(basename "$local_file") fehlgeschlagen"
        return 1
    fi
}

# Prüfungen
check_local_files() {
    local files=("$@")
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Lokale Datei $file nicht gefunden!"
            return 1
        fi
    done
    return 0
}

check_dependencies() {
    if ! command -v sshpass &> /dev/null; then
        log_error "sshpass ist nicht installiert. Installiere es mit: sudo apt-get install sshpass"
        return 1
    fi
    return 0
}
