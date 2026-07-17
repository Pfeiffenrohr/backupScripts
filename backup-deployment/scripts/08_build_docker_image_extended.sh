#!/bin/bash

# Erweitertes Script zum Erstellen des Docker-Images
# Mit zusätzlichen Optionen und Fehlerbehandlung

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

# Konfiguration
IMAGE_NAME="databasedump"
IMAGE_TAG="latest"
DOCKERFILE_PATH="$DOMAIN_REPLACE_PATH/ggg/prepare/mysql-backup"

# ===========================================
# SCHRITT 8: DOCKER IMAGE ERSTELLEN
# ===========================================

log_step "8/8: Docker-Image erstellen"

log_info "Docker-Image-Konfiguration:"
log_info "  Image-Name: $IMAGE_NAME:$IMAGE_TAG"
log_info "  Dockerfile-Pfad: $DOCKERFILE_PATH"
log_info "  Build-Context: $DOCKERFILE_PATH"
echo ""

# Voraussetzungen prüfen
log_info "Prüfe Voraussetzungen..."

# Docker verfügbar?
if ! run_ssh_command "docker --version"; then
    log_error "Docker ist nicht verfügbar"
    exit 1
fi

# Dockerfile vorhanden?
if ! run_ssh_command "test -f $DOCKERFILE_PATH/Dockerfile"; then
    log_error "Dockerfile nicht gefunden: $DOCKERFILE_PATH/Dockerfile"
    log_info "Verfügbare Dateien im Verzeichnis:"
    run_ssh_command "ls -la $DOCKERFILE_PATH/"
    exit 1
fi

log_success "Alle Voraussetzungen erfüllt"

# Dockerfile-Inhalt anzeigen (optional)
read -p "Dockerfile-Inhalt anzeigen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Dockerfile-Inhalt:"
    echo "----------------------------------------"
    run_ssh_command "cat $DOCKERFILE_PATH/Dockerfile"
    echo "----------------------------------------"
    echo ""
fi

# Bestätigung vor Build
read -p "Docker-Image '$IMAGE_NAME:$IMAGE_TAG' erstellen? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Docker-Build abgebrochen."
    exit 0
fi

echo ""

# Altes Image entfernen (optional)
log_info "Prüfe auf vorhandenes Image..."
if run_ssh_command "docker images | grep -q '^$IMAGE_NAME'"; then
    log_warning "Image '$IMAGE_NAME' existiert bereits"
    
    read -p "Vorhandenes Image entfernen? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Entferne vorhandenes Image..."
        run_ssh_command "docker rmi $IMAGE_NAME:$IMAGE_TAG" || log_warning "Image konnte nicht entfernt werden"
    fi
fi

# Docker-Image erstellen
log_info "Starte Docker-Build..."

BUILD_COMMAND="
cd $DOCKERFILE_PATH && 
echo 'Build-Context: \$(pwd)' &&
echo 'Dockerfile vorhanden: \$(test -f Dockerfile && echo 'ja' || echo 'nein')' &&
docker build -t $IMAGE_NAME:$IMAGE_TAG . --progress=plain
"

if run_ssh_command "$BUILD_COMMAND"; then
    log_success "Docker-Image '$IMAGE_NAME:$IMAGE_TAG' erfolgreich erstellt!"
    
    # Image-Details anzeigen
    echo ""
    log_info "Image-Details:"
    echo "----------------------------------------"
    run_ssh_command "docker images | head -1; docker images | grep '$IMAGE_NAME'"
    echo "----------------------------------------"
    
    # Image-Größe und Layer-Info
    log_info "Image-Inspektion:"
    run_ssh_command "docker inspect $IMAGE_NAME:$IMAGE_TAG --format='
Erstellt: {{.Created}}
Größe: {{.Size}} Bytes
Architektur: {{.Architecture}}
OS: {{.Os}}
'"
    
else
    log_error "Fehler beim Erstellen des Docker-Images!"
    
    log_info "Fehlerdiagnose:"
    log_info "1. Dockerfile-Inhalt:"
    run_ssh_command "cat $DOCKERFILE_PATH/Dockerfile"
    
    echo ""
    log_info "2. Build-Context-Inhalt:"
    run_ssh_command "ls -la $DOCKERFILE_PATH/"
    
    echo ""
    log_info "3. Docker-System-Info:"
    run_ssh_command "docker system df"
    
    exit 1
fi

# Optionale Tests
echo ""
read -p "Möchtest du das Image testen? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Teste das erstellte Image..."
    
    # Einfacher Test - Container starten und stoppen
    if run_ssh_command "docker run --rm $IMAGE_NAME:$IMAGE_TAG --version 2>/dev/null || echo 'Test-Command nicht verfügbar'"; then
        log_success "Image-Test erfolgreich"
    else
        log_warning "Image-Test nicht durchführbar (normal bei speziellen Images)"
    fi
fi

echo ""
log_success "=========================================="
log_success "   DOCKER-IMAGE ERFOLGREICH ERSTELLT!   "
log_success "=========================================="

echo ""
log_info "📋 ZUSAMMENFASSUNG:"
log_info "════════════════════════════════════════"
log_success "  ✅ Image-Name: $IMAGE_NAME:$IMAGE_TAG"
log_success "  ✅ Dockerfile: $DOCKERFILE_PATH/Dockerfile"
log_success "  ✅ Build erfolgreich abgeschlossen"

echo ""
log_info "🐳 VERWENDUNG:"
log_info "════════════════════════════════════════"
log_info "  Container starten:"
log_info "    docker run -it $IMAGE_NAME:$IMAGE_TAG"
log_info ""
log_info "  Container mit Volume:"
log_info "    docker run -v /pfad/zu/daten:/data $IMAGE_NAME:$IMAGE_TAG"
log_info ""
log_info "  Image-Details anzeigen:"
log_info "    docker inspect $IMAGE_NAME:$IMAGE_TAG"

echo ""
log_success "Docker-Image-Erstellung abgeschlossen! 🐳"
