#!/bin/bash

# Docker und Docker Compose vollständig deinstallieren

# Funktionen
log_error() {
    echo "✗ FEHLER: $1" >&2
}

log_success() {
    echo "✓ $1"
}

log_info() {
    echo "ℹ $1"
}

log_warning() {
    echo "⚠ WARNUNG: $1"
}

log_step() {
    echo ""
    echo "=========================================="
    echo "SCHRITT: $1"
    echo "=========================================="
}

# Root-Rechte prüfen
if [ "$EUID" -ne 0 ]; then
    log_error "Dieses Script muss als root ausgeführt werden!"
    echo "Verwende: sudo $0"
    exit 1
fi

log_info "Docker und Docker Compose Deinstallation gestartet"
log_warning "ACHTUNG: Alle Docker-Container, Images und Volumes werden gelöscht!"

# Bestätigung
read -p "Möchtest du wirklich Docker vollständig deinstallieren? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deinstallation abgebrochen."
    exit 0
fi

# Schritt 1: Docker-Container und Services stoppen
log_step "Docker-Container und Services stoppen"

if command -v docker &> /dev/null; then
    log_info "Stoppe alle laufenden Container..."
    if docker ps -q | xargs -r docker stop; then
        log_success "Container gestoppt"
    else
        log_warning "Fehler beim Stoppen der Container oder keine Container vorhanden"
    fi
    
    log_info "Entferne alle Container..."
    if docker ps -aq | xargs -r docker rm -f; then
        log_success "Container entfernt"
    else
        log_warning "Fehler beim Entfernen der Container oder keine Container vorhanden"
    fi
    
    log_info "Entferne alle Images..."
    if docker images -aq | xargs -r docker rmi -f; then
        log_success "Images entfernt"
    else
        log_warning "Fehler beim Entfernen der Images oder keine Images vorhanden"
    fi
    
    log_info "Entferne alle Volumes..."
    if docker volume ls -q | xargs -r docker volume rm; then
        log_success "Volumes entfernt"
    else
        log_warning "Fehler beim Entfernen der Volumes oder keine Volumes vorhanden"
    fi
    
    log_info "Entferne alle Netzwerke..."
    if docker network ls -q --filter type=custom | xargs -r docker network rm; then
        log_success "Benutzerdefinierte Netzwerke entfernt"
    else
        log_warning "Fehler beim Entfernen der Netzwerke oder keine benutzerdefinierten Netzwerke vorhanden"
    fi
    
    # Docker-System bereinigen
    log_info "Führe Docker-System-Bereinigung durch..."
    docker system prune -af --volumes || log_warning "System-Bereinigung fehlgeschlagen"
else
    log_info "Docker-Befehl nicht gefunden, überspringe Container-Bereinigung"
fi

# Schritt 2: Docker-Services stoppen und deaktivieren
log_step "Docker-Services stoppen und deaktivieren"

services=("docker.socket" "docker.service" "containerd.service")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_info "Stoppe $service..."
        systemctl stop "$service" && log_success "$service gestoppt" || log_warning "Fehler beim Stoppen von $service"
    fi
    
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        log_info "Deaktiviere $service..."
        systemctl disable "$service" && log_success "$service deaktiviert" || log_warning "Fehler beim Deaktivieren von $service"
    fi
done

# Schritt 3: Docker-Pakete deinstallieren
log_step "Docker-Pakete deinstallieren"

# Erkennung der Linux-Distribution
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    log_info "Erkenne Ubuntu/Debian - deinstalliere Docker-Pakete..."
    
    docker_packages=(
        "docker-ce"
        "docker-ce-cli"
        "docker-ce-rootless-extras"
        "docker-buildx-plugin"
        "docker-compose-plugin"
        "containerd.io"
        "docker.io"
        "docker-doc"
        "docker-compose"
        "podman-docker"
    )
    
    for package in "${docker_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package"; then
            log_info "Deinstalliere $package..."
            apt-get purge -y "$package" && log_success "$package deinstalliert" || log_warning "Fehler beim Deinstallieren von $package"
        fi
    done
    
    # Autoremove
    log_info "Entferne nicht mehr benötigte Pakete..."
    apt-get autoremove -y && log_success "Autoremove abgeschlossen" || log_warning "Autoremove fehlgeschlagen"
    
elif [ -f /etc/redhat-release ]; then
    # CentOS/RHEL/Rocky
    log_info "Erkenne CentOS/RHEL - deinstalliere Docker-Pakete..."
    
    docker_packages=(
        "docker-ce"
        "docker-ce-cli"
        "docker-buildx-plugin"
        "docker-compose-plugin"
        "containerd.io"
        "docker"
        "docker-client"
        "docker-client-latest"
        "docker-common"
        "docker-latest"
        "docker-latest-logrotate"
        "docker-logrotate"
        "docker-engine"
        "docker-compose"
    )
    
    for package in "${docker_packages[@]}"; do
        if rpm -q "$package" &>/dev/null; then
            log_info "Deinstalliere $package..."
            yum remove -y "$package" && log_success "$package deinstalliert" || log_warning "Fehler beim Deinstallieren von $package"
        fi
    done
else
    log_warning "Unbekannte Distribution - manuelle Paket-Deinstallation erforderlich"
fi

# Schritt 4: Docker Compose (standalone) entfernen
log_step "Docker Compose (standalone) entfernen"

compose_locations=(
    "/usr/local/bin/docker-compose"
    "/usr/bin/docker-compose"
    "/bin/docker-compose"
)

for location in "${compose_locations[@]}"; do
    if [ -f "$location" ]; then
        log_info "Entferne Docker Compose von $location..."
        rm -f "$location" && log_success "Docker Compose von $location entfernt" || log_warning "Fehler beim Entfernen von $location"
    fi
done

# Schritt 5: Docker-Verzeichnisse und -Dateien entfernen
log_step "Docker-Verzeichnisse und -Dateien entfernen"

# Docker-Datenverzeichnisse
docker_dirs=(
    "/var/lib/docker"
    "/var/lib/containerd"
    "/etc/docker"
    "/etc/containerd"
    "/var/run/docker.sock"
    "/var/run/docker"
    "/run/docker"
    "/usr/libexec/docker"
)

for dir in "${docker_dirs[@]}"; do
    if [ -e "$dir" ]; then
        log_info "Entferne $dir..."
        rm -rf "$dir" && log_success "$dir entfernt" || log_warning "Fehler beim Entfernen von $dir"
    fi
done

# Docker-Konfigurationsdateien in Benutzerverzeichnissen
log_info "Entferne Docker-Konfigurationsdateien aus Benutzerverzeichnissen..."
find /home -name ".docker" -type d -exec rm -rf {} + 2>/dev/null || true
find /root -name ".docker" -type d -exec rm -rf {} + 2>/dev/null || true

# Schritt 6: Docker-Gruppen und -Benutzer entfernen
log_step "Docker-Gruppen entfernen"

if getent group docker &>/dev/null; then
    log_info "Entferne docker-Gruppe..."
    groupdel docker && log_success "docker-Gruppe entfernt" || log_warning "Fehler beim Entfernen der docker-Gruppe"
fi

# Schritt 7: Docker-Repository entfernen
log_step "Docker-Repository entfernen"

if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    repo_files=(
        "/etc/apt/sources.list.d/docker.list"
        "/etc/apt/sources.list.d/docker-ce.list"
        "/etc/apt/keyrings/docker.gpg"
    )
    
    for file in "${repo_files[@]}"; do
        if [ -f "$file" ]; then
            log_info "Entferne $file..."
            rm -f "$file" && log_success "$file entfernt" || log_warning "Fehler beim Entfernen von $file"
        fi
    done
    
    # Paketliste aktualisieren
    log_info "Aktualisiere Paketliste..."
    apt-get update && log_success "Paketliste aktualisiert" || log_warning "Paketliste-Update fehlgeschlagen"
    
elif [ -f /etc/redhat-release ]; then
    # CentOS/RHEL
    repo_files=(
        "/etc/yum.repos.d/docker-ce.repo"
    )
    
    for file in "${repo_files[@]}"; do
        if [ -f "$file" ]; then
            log_info "Entferne $file..."
            rm -f "$file" && log_success "$file entfernt" || log_warning "Fehler beim Entfernen von $file"
        fi
    done
fi

# Schritt 8: Systemd-Daemon neu laden
log_step "System-Services neu laden"

log_info "Lade systemd-Daemon neu..."
systemctl daemon-reload && log_success "systemd-Daemon neu geladen" || log_warning "Fehler beim Neuladen des systemd-Daemon"

# Schritt 9: Abschlussverifikation
log_step "Deinstallation verifizieren"

# Prüfe ob Docker-Befehle noch existieren
if command -v docker &>/dev/null; then
    log_warning "Docker-Befehl ist noch verfügbar!"
else
    log_success "Docker-Befehl erfolgreich entfernt"
fi

if command -v docker-compose &>/dev/null; then
    log_warning "docker-compose-Befehl ist noch verfügbar!"
else
    log_success "docker-compose-Befehl erfolgreich entfernt"
fi

# Prüfe ob Docker-Services noch existieren
if systemctl list-unit-files | grep -q docker; then
    log_warning "Docker-Services sind noch registriert:"
    systemctl list-unit-files | grep docker
else
    log_success "Alle Docker-Services erfolgreich entfernt"
fi

# Schritt 10: Zusammenfassung
log_step "Deinstallation abgeschlossen"

log_success "=========================================="
log_success "DOCKER DEINSTALLATION ABGESCHLOSSEN!"
log_success "=========================================="

log_info "Was wurde entfernt:"
log_info "  ✓ Alle Docker-Container, Images und Volumes"
log_info "  ✓ Docker-CE und Docker Compose"
log_info "  ✓ Docker-Services und -Daemons"
log_info "  ✓ Docker-Verzeichnisse und -Konfigurationen"
log_info "  ✓ Docker-Repository und -Schlüssel"
log_info "  ✓ docker-Gruppe"

log_info ""
log_info "Empfohlene nächste Schritte:"
log_info "  - Neustart des Systems: sudo reboot"
log_info "  - Prüfung auf verbliebene Dateien: find / -name '*docker*' 2>/dev/null"

echo ""
read -p "Möchtest du das System jetzt neu starten? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "System wird neu gestartet..."
    reboot
else
    log_info "Neustart übersprungen. Starte das System später manuell neu."
fi
