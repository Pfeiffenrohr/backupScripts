#!/bin/bash

source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../config.sh"

log_step "Domain-Ersetzung in Nextcloud-Verzeichnis"

# Prüfen ob Domain-Variablen gesetzt sind
if [ -z "$OLD_DOMAIN" ] || [ -z "$NEW_DOMAIN" ]; then
    log_error "OLD_DOMAIN oder NEW_DOMAIN nicht in config.sh definiert!"
    exit 1
fi

if [ "$OLD_DOMAIN" = "$NEW_DOMAIN" ]; then
    log_info "Alte und neue Domain sind identisch - keine Ersetzung nötig"
    exit 0
fi

log_info "Ersetze Domain in: $DOMAIN_REPLACE_PATH"
log_info "Ersetzung: $OLD_DOMAIN → $NEW_DOMAIN"

# Domain-Ersetzungs-Script für Remote-Server erstellen
cat << 'DOMAIN_REPLACE_SCRIPT' > /tmp/replace_domain.sh
#!/bin/bash

OLD_DOMAIN="$1"
NEW_DOMAIN="$2"
TARGET_PATH="$3"

log_info() {
    echo "ℹ $1"
}

log_success() {
    echo "✓ $1"
}

log_warning() {
    echo "⚠ $1"
}

log_error() {
    echo "✗ FEHLER: $1" >&2
}

# Prüfen ob Zielverzeichnis existiert
if [ ! -d "$TARGET_PATH" ]; then
    log_error "Zielverzeichnis $TARGET_PATH existiert nicht!"
    log_info "Verfügbare Verzeichnisse:"
    ls -la /home/richard/docker/nextcloud/ 2>/dev/null || echo "Verzeichnis nicht gefunden"
    exit 1
fi

log_info "Zielverzeichnis gefunden: $TARGET_PATH"
log_info "Verzeichnisinhalt:"
ls -la "$TARGET_PATH"

# Backup-Verzeichnis erstellen
BACKUP_DIR="/root/nextcloud_domain_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
log_info "Backup-Verzeichnis erstellt: $BACKUP_DIR"

# Statistiken
files_found=0
files_changed=0

log_info "Durchsuche Verzeichnis: $TARGET_PATH"
log_info "Suche nach Domain: $OLD_DOMAIN"

# Erste Schnellsuche - gibt es überhaupt Dateien mit der alten Domain?
log_info "Führe Schnellsuche nach '$OLD_DOMAIN' durch..."
quick_search=$(grep -r "$OLD_DOMAIN" "$TARGET_PATH" 2>/dev/null | head -5)

if [ -n "$quick_search" ]; then
    log_success "Domain gefunden! Erste Treffer:"
    echo "$quick_search"
    echo ""
else
    log_warning "Keine Dateien mit '$OLD_DOMAIN' in der Schnellsuche gefunden"
    log_info "Führe detaillierte Suche durch..."
fi

# Finde alle relevanten Dateien (korrigierter find-Befehl)
log_info "Sammle Dateien..."
temp_file_list="/tmp/nextcloud_files_$$"

find "$TARGET_PATH" -type f \
    \( -name "*.php" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" \
    -o -name "*.xml" -o -name "*.conf" -o -name "*.config" \
    -o -name "*.cfg" -o -name "*.ini" -o -name "*.env" \
    -o -name "*.txt" -o -name "*.md" -o -name "*.sh" \
    -o -name "*.sql" -o -name "*.js" -o -name "*.css" -o -name "*.html" \) \
    -not -path "*/.*" \
    -not -name "*.log" \
    -not -name "*.cache" \
    -not -name "*.tmp" \
    2>/dev/null > "$temp_file_list"

file_count=$(wc -l < "$temp_file_list")
log_info "Gefunden: $file_count Dateien zum Durchsuchen"

if [ "$file_count" -eq 0 ]; then
    log_warning "Keine relevanten Dateien gefunden!"
    log_info "Verzeichnisstruktur:"
    find "$TARGET_PATH" -type f | head -10
    rm -f "$temp_file_list"
    exit 1
fi

# Durchsuche Dateien nach der alten Domain
log_info "Durchsuche $file_count Dateien nach '$OLD_DOMAIN'..."

while IFS= read -r file; do
    if [ -f "$file" ] && [ -r "$file" ]; then
        # Prüfe ob Datei die alte Domain enthält (mit besserer Fehlerbehandlung)
        if grep -l "$OLD_DOMAIN" "$file" >/dev/null 2>&1; then
            files_found=$((files_found + 1))
            
            log_success "Gefunden in: ${file#$TARGET_PATH/}"
            
            # Erstelle Backup der Original-Datei
            relative_path="${file#$TARGET_PATH}"
            backup_file="$BACKUP_DIR$relative_path"
            backup_dir=$(dirname "$backup_file")
            mkdir -p "$backup_dir"
            
            if cp "$file" "$backup_file" 2>/dev/null; then
                log_info "  → Backup erstellt"
            else
                log_warning "  → Backup-Fehler für: $file"
                continue
            fi
            
            # Zeige Vorkommen vor der Änderung
            log_info "  → Gefundene Vorkommen:"
            grep -n "$OLD_DOMAIN" "$file" 2>/dev/null | head -3 | while read -r line; do
                echo "    $line"
            done
            
            # Führe Ersetzung durch
            if sed -i.bak "s|$OLD_DOMAIN|$NEW_DOMAIN|g" "$file" 2>/dev/null; then
                # Prüfe ob Änderungen gemacht wurden
                if ! cmp -s "$file" "$file.bak" 2>/dev/null; then
                    files_changed=$((files_changed + 1))
                    
                    # Zeige Anzahl der Ersetzungen
                    changes=$(grep -c "$NEW_DOMAIN" "$file" 2>/dev/null || echo "0")
                    log_success "  → Ersetzt: $changes Vorkommen"
                else
                    log_info "  → Keine Änderungen nötig"
                fi
                rm -f "$file.bak" 2>/dev/null
            else
                log_warning "  → Fehler beim Bearbeiten von $file"
            fi
            
            echo ""
        fi
    fi
done < "$temp_file_list"

# Cleanup
rm -f "$temp_file_list"

# Spezielle Nextcloud-Dateien prüfen (mit korrigierten Pfaden)
log_info "Prüfe spezielle Nextcloud-Konfigurationsdateien..."

# Array von speziellen Dateien
declare -a special_files=(
    "$TARGET_PATH/docker-compose.yml"
    "$TARGET_PATH/docker-compose.yaml"
    "$TARGET_PATH/.env"
    "$TARGET_PATH/config/config.php"
    "$TARGET_PATH/app/config/config.php"
)

# Dynamische Suche nach weiteren Konfigurationsdateien
while IFS= read -r file; do
    special_files+=("$file")
done < <(find "$TARGET_PATH" -name "config.php" -o -name "*.env" -o -name "nginx.conf" 2>/dev/null)

for file in "${special_files[@]}"; do
    if [ -f "$file" ] && grep -l "$OLD_DOMAIN" "$file" >/dev/null 2>&1; then
        log_info "Spezielle Datei gefunden: ${file#$TARGET_PATH/}"
        
        # Backup erstellen
        relative_path="${file#$TARGET_PATH}"
        backup_file="$BACKUP_DIR$relative_path"
        backup_dir=$(dirname "$backup_file")
        mkdir -p "$backup_dir"
        cp "$file" "$backup_file" 2>/dev/null
        
        # Zeige Inhalt vor Änderung
        log_info "  → Vorkommen:"
        grep -n "$OLD_DOMAIN" "$file" 2>/dev/null | head -3 | while read -r line; do
            echo "    $line"
        done
        
        # Ersetzung durchführen
        if sed -i "s|$OLD_DOMAIN|$NEW_DOMAIN|g" "$file" 2>/dev/null; then
            files_changed=$((files_changed + 1))
            changes=$(grep -c "$NEW_DOMAIN" "$file" 2>/dev/null || echo "0")
            log_success "  → Spezielle Datei bearbeitet: $changes Ersetzungen"
        fi
    fi
done

# Zusammenfassung
echo ""
log_info "=========================================="
log_info "DOMAIN-ERSETZUNG ABGESCHLOSSEN"
log_info "=========================================="
log_info "Statistiken:"
log_info "  - Zielverzeichnis: $TARGET_PATH"
log_info "  - Dateien mit alter Domain: $files_found"
log_info "  - Dateien geändert: $files_changed"
log_info "  - Backup-Verzeichnis: $BACKUP_DIR"

if [ $files_changed -gt 0 ]; then
    log_success "Domain-Ersetzung erfolgreich durchgeführt!"
    
    # Zeige geänderte Dateien
    log_info ""
    log_info "Geänderte Dateien:"
    find "$BACKUP_DIR" -type f 2>/dev/null | while read -r backup_file; do
        original_file="$TARGET_PATH${backup_file#$BACKUP_DIR}"
        if [ -f "$original_file" ]; then
            new_count=$(grep -c "$NEW_DOMAIN" "$original_file" 2>/dev/null || echo "0")
            if [ "$new_count" -gt 0 ]; then
                relative_path="${original_file#$TARGET_PATH/}"
                log_info "  ✓ $relative_path ($new_count Ersetzungen)"
            fi
        fi
    done
    
    # Verifikation
    log_info ""
    log_info "Verifikation - neue Domain gefunden in:"
    grep -r "$NEW_DOMAIN" "$TARGET_PATH" 2>/dev/null | cut -d: -f1 | sort -u | head -5 | while read -r file; do
        count=$(grep -c "$NEW_DOMAIN" "$file" 2>/dev/null || echo "0")
        log_info "  ✓ ${file#$TARGET_PATH/} ($count mal)"
    done
    
elif [ $files_found -gt 0 ]; then
    log_warning "Dateien mit alter Domain gefunden, aber Ersetzung fehlgeschlagen"
else
    log_warning "Keine Dateien mit der Domain '$OLD_DOMAIN' gefunden"
    log_info ""
    log_info "Mögliche Ursachen:"
    log_info "  1. Domain wurde bereits ersetzt"
    log_info "  2. Dateien befinden sich in anderem Verzeichnis"
    log_info "  3. Domain ist in anderer Form gespeichert (mit/ohne www, https://)"
    log_info ""
    log_info "Manuelle Suche:"
    log_info "  grep -r 'nextcloud' $TARGET_PATH | head -5"
    log_info "  grep -r 'life-tracker' $TARGET_PATH | head -5"
fi

echo ""
echo "Domain-Ersetzung abgeschlossen!"
DOMAIN_REPLACE_SCRIPT

# Script auf Server ausführen
log_info "Führe Domain-Ersetzung auf Server aus..."

if run_ssh_command "bash -s '$OLD_DOMAIN' '$NEW_DOMAIN' '$DOMAIN_REPLACE_PATH'" < /tmp/replace_domain.sh; then
    log_success "Domain-Ersetzung erfolgreich abgeschlossen"
    
    # Frage nach Container-Neustart
    echo ""
    read -p "Möchtest du die Nextcloud-Container neu starten? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starte Nextcloud-Container neu..."
        
        RESTART_COMMAND="
        cd $DOMAIN_REPLACE_PATH &&
        if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
            echo 'Stoppe Container...' &&
            docker-compose -f docker-compose.yaml down 2>/dev/null || docker-compose down &&
            sleep 5 &&
            echo 'Starte Container neu...' &&
            docker-compose -f docker-compose.yaml up -d 2>/dev/null || docker-compose up -d &&
            sleep 10 &&
            echo '✓ Container neu gestartet' &&
            echo '' &&
            echo 'Container-Status:' &&
            docker-compose -f docker-compose.yaml ps 2>/dev/null || docker-compose ps
        else
            echo '⚠ Keine docker-compose.yml/yaml gefunden in $DOMAIN_REPLACE_PATH'
        fi
        "
        
        if run_ssh_command "$RESTART_COMMAND"; then
            log_success "Container-Neustart abgeschlossen"
        else
            log_warning "Container-Neustart fehlgeschlagen - bitte manuell durchführen"
        fi
    fi
    
else
    log_error "Domain-Ersetzung fehlgeschlagen"
    exit 1
fi

# Cleanup
rm -f /tmp/replace_domain.sh
