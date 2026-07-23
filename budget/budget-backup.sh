#!/bin/bash

# Backup Datenbank und Docker-Verzeichnis
backupok=1

# 1. Datenbank-Backup kopieren (wie bisher)
/usr/bin/scp -i /home/richard/.ssh/id_rsa h2915074.stratoserver.net:/home/richard/docker/CbudgetNew/dump/* /home/richard/backup

if [ $? -eq 0 ]; then
    # Datenbank-Dump vom Remote-Server löschen
    /usr/bin/ssh -i /home/richard/.ssh/id_rsa h2915074.stratoserver.net "rm -f /home/richard/docker/CbudgetNew/dump/budget*"

    # 2. Tar-Backup des gesamten Docker-Verzeichnisses erstellen (ohne data und data_exchange)
    echo "Erstelle Tar-Backup des CbudgetNew-Verzeichnisses..."

    # Zeitstempel für eindeutigen Dateinamen
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_filename="CbudgetNew_backup_${timestamp}.tar.gz"

    /usr/bin/ssh -i /home/richard/.ssh/id_rsa h2915074.stratoserver.net \
        "cd /home/richard/docker && tar --exclude='CbudgetNew/data' --exclude='CbudgetNew/data_exchange' -czf ${backup_filename} CbudgetNew"

    if [ $? -eq 0 ]; then
        # Tar-Backup zum lokalen Server kopieren
        /usr/bin/scp -i /home/richard/.ssh/id_rsa h2915074.stratoserver.net:/home/richard/docker/${backup_filename} /home/richard/backup/

        if [ $? -eq 0 ]; then
            # Tar-Backup vom Remote-Server löschen nach erfolgreichem Transfer
            /usr/bin/ssh -i /home/richard/.ssh/id_rsa h2915074.stratoserver.net "rm -f /home/richard/docker/${backup_filename}"
            echo "Backup erfolgreich erstellt: ${backup_filename}"
        else
            /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte das Tar-Backup nicht kopieren"
            backupok=0
        fi
    else
        /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte das Tar-Backup nicht erstellen"
        backupok=0
    fi

else
    /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte das Budget Datenbankbackup nicht erstellen"
    backupok=0
fi

# Optional: Status ausgeben
if [ $backupok -eq 1 ]; then
    echo "Alle Backups erfolgreich abgeschlossen"
else
    echo "Backup-Prozess mit Fehlern beendet"
fi