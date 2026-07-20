#!/bin/bash
space=`df -k /home/richard |tail -1 |tr -s " " |cut -f 2 -d " "`
freeeSpace=`df -k /home/richard |tail -1 |tr -s " " |cut -f 4 -d " "`
freeeSpaceDisk=`df -k /media/richard/TOSHIBA\ EXT |tail -1 |tr -s " " |cut -f 4 -d " "`

/home/richard/bin/sendMeaageToAnalitycs.sh freeSpace $freeeSpace
/home/richard/bin/sendMeaageToAnalitycs.sh absoluteSpace $space
/home/richard/bin/sendMeaageToAnalitycs.sh freeSpaceDisk $freeeSpaceDisk
exit 0

