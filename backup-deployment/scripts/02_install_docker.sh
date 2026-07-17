#!/bin/bash

source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../config.sh"

log_step "Docker Installation prüfen/durchführen"

# Docker-Installations-Script für Remote-Server
cat << 'DOCKER_SCRIPT' > /tmp/install_docker.sh
set -e

echo "ℹ Prüfe Docker Installation..."

# Prüfen ob Docker installiert ist
if command -v docker &> /dev/null; then
    echo "✓ Docker ist bereits installiert: $(docker --version)"
else
    echo "ℹ Docker nicht gefunden. Installiere Docker..."
    
    # System updaten
    apt-get update
    
    # Abhängigkeiten installieren
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Docker GPG-Schlüssel hinzufügen
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Docker Repository hinzufügen
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Paketliste aktualisieren und Docker installieren
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Docker-Service starten und aktivieren
    systemctl start docker
    systemctl enable docker
    
    echo "✓ Docker erfolgreich installiert: $(docker --version)"
fi

# Docker Compose prüfen/installieren
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "✓ Docker Compose ist bereits installiert"
else
    echo "ℹ Installiere Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "✓ Docker Compose erfolgreich installiert"
fi

# Docker-Service prüfen
if systemctl is-active --quiet docker; then
    echo "✓ Docker-Service läuft"
else
    echo "ℹ Starte Docker-Service..."
    systemctl start docker
    echo "✓ Docker-Service gestartet"
fi

echo "✓ Docker-Setup abgeschlossen"
DOCKER_SCRIPT

# Script ausführen
if run_ssh_script /tmp/install_docker.sh; then
    log_success "Docker und Docker Compose erfolgreich installiert/geprüft"
else
    log_error "Docker-Installation fehlgeschlagen"
    exit 1
fi

# Cleanup
rm -f /tmp/install_docker.sh
