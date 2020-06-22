#!/bin/sh
# CakeQOS-Merlin - port for Merlin firmware supported routers
# Site: https://github.com/ttgapers/cakeqos-merlin
# Thread: https://www.snbforums.com/threads/release-cakeqos-merlin.64800/
# Credits: robcore, Odkrys, ttgapers, jackiechun

readonly SCRIPT_NAME="cake-qos"
readonly SCRIPT_VERSION="v0.0.4"

### Status
readonly STATUS="$(tc qdisc)"
readonly STATUS_UPLOAD=$(echo "${STATUS}" | grep "dev eth0 root")
readonly STATUS_DOWNLOAD=$(echo "${STATUS}" | grep "dev ifb9eth0 root")
RUNNING="false"
if [ "${STATUS_UPLOAD}" != "" ] && [ "${STATUS_DOWNLOAD}" != "" ]; then
	RUNNING="true"
fi

### Cake Download
cake_download() {
	if [ "${1}" = "update" ]; then
		VERSION_LOCAL_CAKE=$(opkg list_installed | grep "^sched-cake-oot - " | awk -F" - " '{print $2}' | cut -d- -f-4)
		VERSION_LOCAL_TC=$(opkg list_installed | grep "^tc-adv - " | awk -F" - " '{print $2}')
		LATEST=$(/usr/sbin/curl --retry 3 -s "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/develop/cake-qos.sh")
		LATEST_VERSION=$(echo "$LATEST" | grep "^readonly SCRIPT_VERSION" | awk -F"=" '{print $2}' | cut -d "\"" -f 2)
		if [ "${LATEST_VERSION}" != "" ] && [ "${LATEST_VERSION}" != "${SCRIPT_VERSION}" ]; then
			echo "New CakeQOS-Merlin detected (${LATEST_VERSION}, currently running ${SCRIPT_VERSION}), updating..."
			echo "${LATEST}" > "/jffs/scripts/${SCRIPT_NAME}"
			chmod 0755 "/jffs/scripts/${SCRIPT_NAME}"
		fi
	elif [ "${1}" = "install" ]; then
		VERSION_LOCAL_CAKE="0"
		VERSION_LOCAL_TC="0"
	fi
	if [ "${2}" = "ac86u" ]; then
		FILE1_TYPE="1"
	elif [ "${2}" = "ax88u" ]; then
		FILE1_TYPE="ax"
	fi
	VERSIONS_ONLINE=$(/usr/sbin/curl --retry 3 -s "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/versions.txt")
	if [ "${VERSIONS_ONLINE}" != "" ] && [ "${VERSION_LOCAL_CAKE}" != "" ] && [ "${VERSION_LOCAL_TC}" != "" ]; then
		VERSION_ONLINE_CAKE=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $1}')
		VERSION_ONLINE_TC=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $2}')
		VERSION_ONLINE_SUFFIX=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $3}')
		if [ "${VERSION_LOCAL_CAKE}" != "${VERSION_ONLINE_CAKE}" ] || [ "${VERSION_LOCAL_TC}" != "${VERSION_ONLINE_TC}" ]; then
			echo "Updated cake binaries detected, updating..."
			FILE1="sched-cake-oot_${VERSION_ONLINE_CAKE}-${FILE1_TYPE}_${VERSION_ONLINE_SUFFIX}.ipk"
			FILE2="tc-adv_${VERSION_ONLINE_TC}_${VERSION_ONLINE_SUFFIX}.ipk"
			FILE1_OUT="sched-cake-oot.ipk"
			FILE2_OUT="tc-adv.ipk"
			/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/${FILE1}" -o "/tmp/home/root/${FILE1_OUT}"
			/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/${FILE2}" -o "/tmp/home/root/${FILE2_OUT}"
			if [ -f "/tmp/home/root/${FILE1_OUT}" ] && [ -f "/tmp/home/root/${FILE2_OUT}" ]; then
				if [ "${1}" = "update" ]; then
					opkg --autoremove remove sched-cake-oot
					opkg --autoremove remove tc-adv
				fi
				/opt/bin/opkg install "/tmp/home/root/${FILE1_OUT}"
				/opt/bin/opkg install "/tmp/home/root/${FILE2_OUT}"
				rm "/tmp/home/root/${FILE1_OUT}"
				rm "/tmp/home/root/${FILE2_OUT}"
				return 0
			else
				echo "There was an error downloading the cake binaries, please try again."
				return 1
			fi
		else
			echo "Your cake binaries are up-to-date."
			return 0
		fi
	fi
}

### Cake Start
cake_start() {
	# Thanks @JGrana
	for i in 1 2 3 4 5 6 7 8 9 10
	do
		if [ -f /opt/bin/sh ]; then
			cake_serve "${@}"
			exit
		else
			sleep 10
		fi
	done
	if [ ! -f /opt/bin/sh ]; then
		logger "CakeQOS-Merlin ${SCRIPT_VERSION} - Entware did not start in 100 seconds, please check"
		return 1
	fi
}

### Cake Serve
cake_serve() {
	options=${4}
	case "${options}" in 
		*diffserv3*|*diffserv4*|*diffserv8*|*besteffort*)
			# priority queue specified
			;;
		*)
			# priority queue not specified, default to besteffort
			options="besteffort ${options}"
			;;
	esac
	logger "CakeQOS-Merlin ${SCRIPT_VERSION} Starting - settings: ${2} | ${3} | ${options}"
	runner disable 2>/dev/null
	fc disable 2>/dev/null
	fc flush 2>/dev/null
	insmod /opt/lib/modules/sch_cake.ko 2>/dev/null
	/opt/sbin/tc qdisc replace dev eth0 root cake bandwidth "${3}" nat ${options}
	ip link add name ifb9eth0 type ifb
	/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
	/opt/sbin/tc qdisc add dev eth0 handle ffff: ingress
	/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
	/opt/sbin/tc qdisc add dev ifb9eth0 root cake bandwidth "${2}" nat wash ingress ${options}
	ifconfig ifb9eth0 up
	/opt/sbin/tc filter add dev eth0 parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb9eth0
}

### Cake Stop If
cake_stopif() {
	if [ "${RUNNING}" = "true" ]; then
		cake_stop
	fi
}

### Cake Stop
cake_stop() {
	logger "CakeQOS-Merlin ${SCRIPT_VERSION} Stopping"
	/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
	/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
	/opt/sbin/tc qdisc del dev eth0 root 2>/dev/null
	ip link del ifb9eth0
	rmmod sch_cake 2>/dev/null
	fc enable
	runner enable
}

### Cake Disable
cake_disable() {
	logger "CakeQOS-Merlin ${SCRIPT_VERSION} Disabled"
	if [ -f /jffs/scripts/firewall-start ]; then
		LINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/firewall-start)
		if [ "$LINECOUNT" -gt 0 ]; then
			sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/firewall-start
		fi
	fi
	if [ -f /jffs/scripts/services-stop ]; then
		LINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-stop)
		if [ "$LINECOUNT" -gt 0 ]; then
			sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-stop
		fi
	fi
}

### Check Requirements
FAIL="0"
if [ "$(nvram get jffs2_scripts)" -ne 1 ]; then
	echo "ERROR: Custom JFFS Scripts must be enabled."
	FAIL="1"
fi
if [ "${1}" != "start" ] && [ ! -f "/opt/bin/opkg" ]; then
	echo "ERROR: Entware must be installed."
	FAIL="1"
fi
if [ "${FAIL}" = "1" ]; then
	return 1
fi

### Parameter Checks
if [ "${1}" = "enable" ] || [ "${1}" = "start" ]; then
	if [ -z "$2" ] || [ -z "$3" ]; then
		echo "Required parameters missing: $SCRIPT_NAME ${1} dlspeed upspeed \"optional extra parameters\""
		echo ""
		echo "Example #1: $SCRIPT_NAME ${1} 30Mbit 5000Kbit"
		echo "Example #2: $SCRIPT_NAME ${1} 30Mbit 5Mbit \"diffserv4 docsis ack-filter\""
		return 1
	fi	
fi
if [ "${1}" = "install" ] || [ "${1}" = "update" ]; then
	if [ -z "$2" ]; then
		echo "Required model missing: $SCRIPT_NAME ${1} {ac86u|ax88u}"
		echo ""
		echo "Example #1: $SCRIPT_NAME ${1} ac86u"
		echo "Example #2: $SCRIPT_NAME ${1} ax88u"
		return 1
	fi
fi

case $1 in
	install|update)
		cake_download "${@}"
		;;
	enable)
		cake_stopif
		# Start
		# Remove from firewall-start
		if [ -f /jffs/scripts/firewall-start ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/firewall-start)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME start"' # '"$SCRIPT_NAME" /jffs/scripts/firewall-start)
			
			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/firewall-start
			fi
		fi
		# Add to services-start
		if [ -f /jffs/scripts/services-start ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME start"' # '"$SCRIPT_NAME" /jffs/scripts/services-start)
			
			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
			fi
			
			if [ "$LINECOUNTEX" -eq 0 ]; then
				echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" &"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
			fi
		else
			echo "#!/bin/sh" > /jffs/scripts/services-start
			echo "" >> /jffs/scripts/services-start
			echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" &"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
			chmod 0755 /jffs/scripts/services-start
		fi
		# Stop
		if [ -f /jffs/scripts/services-stop ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-stop)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME stop"' # '"$SCRIPT_NAME" /jffs/scripts/services-stop)
			
			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-stop
			fi
			
			if [ "$LINECOUNTEX" -eq 0 ]; then
				echo "/jffs/scripts/$SCRIPT_NAME stop"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-stop
			fi
		else
			echo "#!/bin/sh" > /jffs/scripts/services-stop
			echo "" >> /jffs/scripts/services-stop
			echo "/jffs/scripts/$SCRIPT_NAME stop"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-stop
			chmod 0755 /jffs/scripts/services-stop
		fi
		logger "CakeQOS-Merlin ${SCRIPT_VERSION} Enabled"
		cake_start "${@}"
		return 0
		;;
	start)
		cake_stopif
		cake_start "${@}"
		return 0
		;;
	status)
		if [ "${RUNNING}" = "true" ]; then
			echo "> CakeQOS-Merlin ${SCRIPT_VERSION} is running"
			echo "> Download Status:"
			echo "${STATUS_DOWNLOAD}"
			echo "> Upload Status:"
			echo "${STATUS_UPLOAD}"
			return 0
		else
			echo "> CakeQOS-Merlin ${SCRIPT_VERSION} is not running..."
			return 1
		fi
		;;
	stop)
		cake_stop
		return 0
		;;
	disable)
		cake_stop
		cake_disable
		return 0
		;;
	uninstall)
		cake_stop
		cake_disable
		opkg --autoremove remove sched-cake-oot
		opkg --autoremove remove tc-adv
		rm /jffs/scripts/$SCRIPT_NAME
		return 0
		;;
	*)
		echo "Usage: $SCRIPT_NAME {install|update|enable|start|status|stop|disable|uninstall} (install, update, enable, and start have required parameters)"
		echo ""
		echo "install:   download and install necessary $SCRIPT_NAME binaries"
		echo "update:    update $SCRIPT_NAME binaries (if any available)"
		echo "enable:    start $SCRIPT_NAME and add to startup"
		echo "start:     start $SCRIPT_NAME"
		echo "status:    check the current status of $SCRIPT_NAME"
		echo "stop:      stop $SCRIPT_NAME"
		echo "disable:   stop $SCRIPT_NAME and remove from startup"
		echo "uninstall: stop $SCRIPT_NAME, remove from startup, and remove cake binaries"
		return 1
		;;
esac
