#!/bin/bash

source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../config.sh"

log_step "Domain-Ersetzung verifizieren"

log_info "Prüfe Domain-Vorkommen in: $DOMAIN_REPLACE_PATH"

# Verifikations-Script für Remote-Server
cat << 'VERIFY_SCRIPT' > /tmp/verify_domain.sh
#!/bin/bash

OLD_DOMAIN="$1"
NEW_DOMAIN="$2"
TARGET_PATH="$3"

echo "Verifikation der Domain-Ersetzung:"
echo "  Zielverzeichnis: $TARGET_PATH"
echo "  Alte Domain: $OLD_DOMAIN"
echo "  Neue Domain: $NEW_DOMAIN"
echo ""

if [ ! -d "$TARGET_PATH" ]; then
    echo "✗ Zielverzeichnis existiert nicht: $TARGET_PATH"
    exit 1
fi

# Suche nach alter Domain
echo "Suche nach alter Domain '$OLD_DOMAIN':"
old_count=$(find "$TARGET_PATH" -type f -exec grep -l "$OLD_DOMAIN" {} \; 2>/dev/null | wc -l)
if [ "$old_count" -gt 0 ]; then
    echo "⚠ Noch $old_count Dateien mit alter Domain gefunden:"
    find "$TARGET_PATH" -type f -exec grep -l "$OLD_DOMAIN" {} \; 2>/dev/null | head -5
    echo ""
else
    echo "✓ Keine Dateien mit alter Domain gefunden"
fi

# Suche nach neuer Domain
echo "Suche nach neuer Domain '$NEW_DOMAIN':"
new_count=$(find "$TARGET_PATH" -type f -exec grep -l "$NEW_DOMAIN" {} \; 2>/dev/null | wc -l)
if [ "$new_count" -gt 0 ]; then
    echo "✓ $new_count Dateien mit neuer Domain gefunden:"
    find "$TARGET_PATH" -type f -exec grep -l "$NEW_DOMAIN" {} \; 2>/dev/null | head -5
else
    echo "⚠ Keine Dateien mit neuer Domain gefunden"
fi

echo ""
echo "Verifikation abgeschlossen."
VERIFY_SCRIPT

# Script ausführen
if sshpass -p "$PASSWORD" ssh $SSH_OPTS "$REMOTE_USER@$DOMAIN" "bash -s '$OLD_DOMAIN' '$NEW_DOMAIN' '$DOMAIN_REPLACE_PATH'" < /tmp/verify_domain.sh; then
    log_success "Verifikation abgeschlossen"
else
    log_error "Verifikation fehlgeschlagen"
fi

# Cleanup
rm -f /tmp/verify_domain.sh
