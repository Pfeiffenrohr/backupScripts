#!/bin/bash
message=$1
mmm=\'message=\"$message\"\'
echo $mmm

echo curl -u richard:Thierham123 --location --request POST \'https://nextcloud.life-tracker.de/ocs/v2.php/apps/spreed/api/v1/chat/i28sw2gn\' \
--header \'Accept:  application/json\' \
--header \'OCS-APIRequest: true\' \
--header \'Authorization: Basic cmljaGFyZDpUaGllcmhhbTEyMw==\' \
--form \'token="i28sw2gn"\' \
--form $mmm >/tmp/message.sh
chmod 755 /tmp/message.sh
/tmp/message.sh