#!/bin/bash

# scripts/11_complete_deployment_with_ssl.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config.sh"

COMPOSE_PATH="/home/richard/docker/nextcloud/ggg"
OLD_DOMAIN="nextcloud.life-tracker.de"
NEW_DOMAIN="lechner.life-tracker.de"

log_step "Komplettes Nextcloud-Deployment mit SSL"

# 1. Alte Zertifikate aufräumen
log_info "1. Räume alte Zertifikate auf..."
run_ssh_command "
cd $COMPOSE_PATH &&
rm -rf ./proxy/certs/$OLD_DOMAIN* &&
rm -rf ./proxy/vhost.d/$OLD_DOMAIN*
"

# 2. Domain-Konfiguration prüfen
log_info "2. Prüfe Domain-Konfiguration..."
run_ssh_command "
cd $COMPOSE_PATH &&
grep -r '$NEW_DOMAIN' docker-compose.yaml || echo 'Domain-Ersetzung prüfen!'
"

# 3. Container starten (in der richtigen Reihenfolge)
log_info "3. Starte Container in korrekter Reihenfolge..."

# Erst Proxy und Let's Encrypt
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml up -d proxy letsencrypt &&
sleep 10
"

# Dann Datenbank
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml up -d db &&
sleep 15
"

# Schließlich Nextcloud
run_ssh_command "
cd $COMPOSE_PATH &&
docker-compose -f docker-compose.yaml up -d app &&
sleep 10
"

# 4. SSL-Zertifikat-Status überwachen
log_info "4. Überwache SSL-Zertifikat-Erstellung..."

MONITOR_SSL="
cd $COMPOSE_PATH &&
for i in {1..30}; do
    echo \"=== SSL-Check \$i/30 ===\" &&
    
    # Prüfe ob Zertifikat existiert
    if [ -f \"./proxy/certs/$NEW_DOMAIN.crt\" ]; then
        echo '✅ SSL-Zertifikat wurde erstellt!' &&
        
        # Zertifikat-Details anzeigen
        openssl x509 -in ./proxy/certs/$NEW_DOMAIN.crt -text -noout | grep -E '(Subject:|Not After)' &&
        break
    fi
    
    echo 'Warte auf SSL-Zertifikat...' &&
    
    # Let's Encrypt Logs anzeigen
    docker-compose -f docker-compose.yaml logs --tail=5 letsencrypt &&
    
    sleep 10
done
"

run_ssh_command "$MONITOR_SSL"

# 5. Finale Überprüfung
log_info "5. Finale Überprüfung..."

# Container-Status
log_info "Container-Status:"
run_ssh_command "cd $COMPOSE_PATH && docker-compose -f docker-compose.yaml ps"

# SSL-Test
log_info "SSL-Zertifikat-Test:"
run_ssh_command "
if [ -f '$COMPOSE_PATH/proxy/certs/$NEW_DOMAIN.crt' ]; then
    echo '✅ SSL-Zertifikat vorhanden'
    openssl x509 -in $COMPOSE_PATH/proxy/certs/$NEW_DOMAIN.crt -noout -dates
else
    echo '❌ SSL-Zertifikat fehlt - prüfe Logs:'
    docker logs nextcloud-letsencrypt --tail=20
fi
"

# HTTP/HTTPS-Test
log_info "Verbindungstest:"
run_ssh_command "
echo 'HTTP-Test (sollte auf HTTPS umleiten):'
curl -I http://$NEW_DOMAIN/ 2>/dev/null | head -3

echo 'HTTPS-Test:'
curl -I https://$NEW_DOMAIN/ 2>/dev/null | head -3 || echo 'HTTPS noch nicht verfügbar'
"

log_success "Deployment mit SSL abgeschlossen!"

echo ""
log_info "🌐 ZUGRIFF:"
log_info "════════════════════════════════════════"
log_info "  HTTP:  http://$NEW_DOMAIN (→ HTTPS redirect)"
log_info "  HTTPS: https://$NEW_DOMAIN"

echo ""
log_info "🔍 TROUBLESHOOTING:"
log_info "════════════════════════════════════════"
log_info "  Let's Encrypt Logs:"
log_info "    docker logs nextcloud-letsencrypt"
log_info ""
log_info "  Nginx Proxy Logs:"
log_info "    docker logs nextcloud-proxy"
log_info ""
log_info "  Zertifikat manuell prüfen:"
log_info "    openssl s_client -connect $NEW_DOMAIN:443 -servername $NEW_DOMAIN"
