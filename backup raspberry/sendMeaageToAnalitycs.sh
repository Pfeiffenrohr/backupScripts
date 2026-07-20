#!/bin/bash
name=$1
value=$2
dat=`date "+%Y-%m-%d %H:%M:%S"`
mmm="\"value\": \"$value\""
object="\"dimension1\": \"$name\""
datum="\"dimension2\": \"$dat\""
#echo $mmm
#echo $datum
echo curl -u richard:Thierham123 --location --request POST \'https://nextcloud.life-tracker.de/index.php/apps/analytics/api/3.0/data/3/add\' \
--header \'Accept: application/json\' \
--header \'OCS-APIRequest: true\' \
--header \'Authorization: Basic cmljaGFyZDpUaGllcmhhbTEyMw==\' \
--header \'Content-Type: application/json\' \
--data-raw \'{ \
     \"data\":[ \
        { \
            $object, \
            $datum, \
            $mmm \
        } \
    ] \
 }\'  > /tmp/messageAnalytics.sh
chmod 755 /tmp/messageAnalytics.sh
/tmp/messageAnalytics.sh