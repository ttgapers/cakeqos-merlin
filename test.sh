#!/bin/sh

if [ "${2}" = "ac86u" ]; then
	FILE1_TYPE="1"
elif [ "${2}" = "ax88u" ]; then
	FILE1_TYPE="ax"
fi
VERSIONS_ONLINE=$(curl --retry 3 -s "https://5m.ca/cake/test.txt") # 2020-05-28-a5dccfd8|4.16.0-git-20191110
if [ "${VERSIONS_ONLINE}" != "" ]; then
	VERSION_ONLINE_CAKE=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $1}')
	VERSION_ONLINE_TC=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $2}')
	FILE1="sched-cake-oot_${VERSION_ONLINE_CAKE}-${FILE1_TYPE}_aarch64-3.10.ipk"
	FILE2="tc-adv_${VERSION_ONLINE_TC}_aarch64-3.10.ipk"
	FILE1_OUT="sched-cake-oot.ipk"
	FILE2_OUT="tc-adv.ipk"
	echo $FILE1
	echo $FILE2
fi
