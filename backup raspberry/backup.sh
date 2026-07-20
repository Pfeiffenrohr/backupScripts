#!/bin/bash
backupok=1
version=`date +"%u"`
version=`expr $version % 2`

/usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "rm -f /home/richard/backup/data.tar.gz"
if [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte altes tarfile nicht loeschen"
  backupok=0
fi

/usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "tar --exclude='*.mp4' --exclude='*.MOV' --exclude='*.log' --exclude='dump' --exclude='proxy' -cf /home/richard/backup/dat
a.tar /home/richard/docker/nextcloud/ggg/"
if  [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard konnte den bakup tar nicht ausführen"
  backupok=0
fi

/usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "gzip -9 /home/richard/backup/data.tar"
if [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard konnte das backup nicht zippen"
  backupok=0
fi
rm /home/richard/backup/data.tar.gz /home/richard/backup/data.tar.gz_$version
rm /home/richard/backup/data_video.tar.gz_$version
error_output=$(/usr/bin/sshpass  -p 'dra.chir' /usr/bin/scp "richard@nextcloud.life-tracker.de:/home/richard//backup/data.tar.gz" /home/richard/backup 2>&1)
if [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard der scp vom backuup ist gescheitert. Fehler $error_output "
  backupok=0
fi

mv /home/richard/backup/data.tar.gz /home/richard/backup/data.tar.gz_$version
#################
# Backup mp4 und mov Dateien
############################
/usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "rm -f /home/richard/backup/data_video.tar.gz"
if [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte altes video tarfile nicht loeschen"
  backupok=0
fi
/usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "find /home/richard/docker/nextcloud/ggg/app  -type f \( -iname \"*.mp4\" -o -iname \"*.mov\" \) -print0 | xargs -0 tar -c
vf /home/richard/backup/data_video.tar"
if  [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard konnte den video bakup tar nicht ausführen"
  backupok=0
fi

/usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "gzip -9 /home/richard/backup/data_video.tar"
if [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard konnte das video backup nicht zippen"
  backupok=0
fi

/usr/bin/sshpass  -p 'dra.chir' /usr/bin/scp "richard@nextcloud.life-tracker.de:/home/richard//backup/data_video.tar.gz" /home/richard/backup
if [ $? != 0 ]
then
  /home/richard/bin/sendMeaageToTalk.sh "@richard der scp vom video backup ist gescheitert"
  backupok=0
fi

mv /home/richard/backup/data_video.tar.gz /home/richard/backup/data_video.tar.gz_$version

########################
#Backup Datenbank
/usr/bin/sshpass  -p 'dra.chir' /usr/bin/scp "richard@nextcloud.life-tracker.de:/home/richard/docker/nextcloud/ggg/dump/nextcloud_dump*" /home/richard/backup
if [ $? == 0 ]
then
 /usr/bin/sshpass  -p ren.chel /usr/bin/ssh root@nextcloud.life-tracker.de -t "rm -f /home/richard/docker/nextcloud/ggg/dump/nextcloud_dump*"
else
  /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte das Nextcloud Datenbankbackup nicht erstellen"
  backupok=0

fi
#Backup Datenbank
  /usr/bin/scp -i /home/richard/.ssh/id_rsa richard@h2915074.stratoserver.net:/home/richard/docker/CbudgetNew/dump/* /home/richard/backup
if [ $? -eq 0 ]; then
    /usr/bin/ssh -i /home/richard/.ssh/id_rsa  richard@h2915074.stratoserver.net "rm -f /home/richard/docker/CbudgetNew/dump/budget*"
else
  /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte das Budget Datenbankbackup nicht erstellen"
  backupok=0
fi

# Backup bilder von Raspberry
#/usr/bin/sshpass  -p 'dra.chir' /usr/bin/scp "richard@192.168.188.88:/home/richard/bilder/*" /home/richard/backup/bilder/bauGutmann
#if [ $? == 0 ]
#then
# /usr/bin/sshpass  -p 'dra.chir' /usr/bin/ssh richard@192.168.188.88 -t "rm -f /home/richard/bilder/*"
#else
#  /home/richard/bin/sendMeaageToTalk.sh "@richard Konnte kein Backup von den Bilder vom Raspberry erstellen"
#  backupok=0
#fi

if [ $backupok == 1 ]
then
    /home/richard/bin/sendMeaageToTalk.sh "Backup ok!"
fi
