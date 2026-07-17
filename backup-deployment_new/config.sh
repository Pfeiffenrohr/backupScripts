#!/bin/bash

# Server-Konfiguration
export DOMAIN="169.58.22.193"
export DOMAIN="lechner.life-tracker.de"
export REMOTE_USER="root"
export REMOTE_PATH="/root"
export PASSWORD=oozj4lzWJIO6Uq8OWYrtR46

# Domain-Ersetzung
export OLD_DOMAIN="nextcloud.life-tracker.de"  # Alte Domain die ersetzt werden soll
export NEW_DOMAIN="lechner.life-tracker.de"            # Neue Domain/IP

# Lokale Dateien
export DATA_FILE="/home/richard/backup/data.tar.gz_0"
export VIDEO_FILE="/home/richard/backup/data_video.tar.gz_0"
export SQL_FILE="/home/richard/backup/nextcloud_dump.sql.gz"

# SSH-Optionen
export SSH_OPTS="-o ConnectTimeout=30 -o StrictHostKeyChecking=no"

# Domain-Ersetzung: Nur in diesem Verzeichnis
export DOMAIN_REPLACE_PATH="/home/richard/docker/nextcloud"

# Dateitypen die durchsucht werden sollen
export DOMAIN_REPLACE_EXTENSIONS=".*\.(conf|config|cfg|ini|yaml|yml|json|xml|php|html|js|css|env|txt|sh|sql|py|md)$"
