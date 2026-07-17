#!/bin/bash

source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../config.sh"

log_step "Dateien verarbeiten"

# Dateiverarbeitungs-Script für Remote-Server
cat << 'PROCESS_SCRIPT' > /tmp/process_files.sh
set -e

cd /root || { echo "FEHLER: Kann nicht in /root wechseln"; exit 1; }

# Prüfen ob alle Dateien existieren
files_to_check=("data.tar.gz_0" "data_video.tar.gz_0" "nextcloud_dump.sql.gz")
for file in "${files_to_check[@]}"; do
    if [ ! -f "$file" ]; then
        echo "FEHLER: $file nicht gefunden"
        exit 1
    fi
done
echo "✓ Alle kopierten Dateien gefunden"

# 1. Data-Datei verarbeiten
echo "ℹ Verarbeite data.tar.gz_0..."
[ -f "data.tar.gz" ] && mv data.tar.gz data.tar.gz.backup.$(date +%Y%m%d_%H%M%S)
mv data.tar.gz_0 data.tar.gz
tar -tzf data.tar.gz >/dev/null 2>&1 || { echo "FEHLER: data.tar.gz beschädigt"; exit 1; }
echo "✓ data.tar.gz validiert"

cd /
tar -xzf /root/data.tar.gz || { echo "FEHLER: Entpacken fehlgeschlagen"; exit 1; }
echo "✓ data.tar.gz entpackt"
cd /root

# 2. Video-Datei verarbeiten
echo "ℹ Verarbeite data_video.tar.gz_0..."
[ -f "data_video.tar.gz" ] && mv data_video.tar.gz data_video.tar.gz.backup.$(date +%Y%m%d_%H%M%S)
mv data_video.tar.gz_0 data_video.tar.gz
tar -tzf data_video.tar.gz >/dev/null 2>&1 || { echo "FEHLER: data_video.tar.gz beschädigt"; exit 1; }
echo "✓ data_video.tar.gz validiert"

cd /
tar -xzf /root/data_video.tar.gz || { echo "FEHLER: Entpacken fehlgeschlagen"; exit 1; }
echo "✓ data_video.tar.gz entpackt"
cd /root

# 3. SQL-Datei entzippen
echo "ℹ Verarbeite nextcloud_dump.sql.gz..."
[ -f "nextcloud_dump.sql" ] && mv nextcloud_dump.sql nextcloud_dump.sql.backup.$(date +%Y%m%d_%H%M%S)
gunzip -c nextcloud_dump.sql.gz > nextcloud_dump.sql || { echo "FEHLER: Entzippen fehlgeschlagen"; exit 1; }
echo "✓ nextcloud_dump.sql.gz entzippt ($(du -h nextcloud_dump.sql | cut -f1))"

echo "✓ Alle Dateien erfolgreich verarbeitet"
PROCESS_SCRIPT

# Script ausführen
if run_ssh_script /tmp/process_files.sh; then
    log_success "Alle Dateien erfolgreich verarbeitet"
else
    log_error "Dateiverarbeitung fehlgeschlagen"
    exit 1
fi

# Cleanup
rm -f /tmp/process_files.sh
