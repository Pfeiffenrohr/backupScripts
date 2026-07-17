#!/bin/bash

source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../config.sh"

log_step "Dateien kopieren"

# Data-Datei kopieren
if ! copy_file "$DATA_FILE" 60; then
    exit 1
fi
# Video-Datei kopieren (längerer Timeout)
if ! copy_file "$VIDEO_FILE" 120; then
    exit 1
fi

# SQL-Datei kopieren
if ! copy_file "$SQL_FILE" 30; then
    exit 1
fi

log_success "Alle Dateien erfolgreich kopiert"
