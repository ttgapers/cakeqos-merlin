#!/bin/sh
# CakeQOS-Merlin - port for Merlin firmware supported routers
# Site: https://github.com/ttgapers/cakeqos-merlin
# Thread: https://www.snbforums.com/threads/release-cakeqos-merlin.64800/
# Credits: robcore, Odkrys, ttgapers, jackiechun

# shellcheck disable=SC2086
readonly SCRIPT_VERSION="v0.0.6"
readonly SCRIPT_NAME="cake-qos"
readonly SCRIPT_NAME_FANCY="CakeQOS-Merlin"
readonly SCRIPT_BRANCH="master"
WDogdir="/jffs/addons/$SCRIPT_NAME.d"
WDog="${WDogdir}/cake-watchdog.sh"

readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"

[ -z "$(nvram get odmpid)" ] && RMODEL=$(nvram get productid) || RMODEL=$(nvram get odmpid) #get router model

### Print_Output - Thanks @JackYaz
Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME_FANCY" "$2"
		printf "\\e[1m$3%s: $2\\e[0m\\n" "$SCRIPT_NAME_FANCY - $SCRIPT_VERSION"
	else
		printf "\\e[1m$3%s: $2\\e[0m\\n" "$SCRIPT_NAME_FANCY - $SCRIPT_VERSION"
	fi
}

### Status
isrunning() {
	STATUS="$(tc qdisc | grep '^qdisc cake ')"
	STATUS_UPLOAD=$(echo "${STATUS}" | grep "dev eth0 root")
	STATUS_DOWNLOAD=$(echo "${STATUS}" | grep "dev ifb9eth0 root")
	if [ "${STATUS_UPLOAD}" != "" ] && [ "${STATUS_DOWNLOAD}" != "" ]; then
		echo "true"
	else
		echo "false"
	fi
}

install_watchdog() {
  if [ ! -f "$WDog" ]; then
  	Print_Output "true" "Installing cake-watchdog..." "$PASS"
  	if [ ! -d "$WDogdir" ]; then
  	   mkdir "$WDogdir"
  	   chmod 0777 "$WDogdir"
  	fi
  	printf "" > "$WDog"
  	chmod 0755 "$WDog"
  fi
}

### Cake Download
cake_download() {
	if [ "${1}" = "update" ]; then
		VERSION_LOCAL_CAKE=$(opkg list_installed | grep "^sched-cake-oot - " | awk -F" - " '{print $2}' | cut -d- -f-4)
		VERSION_LOCAL_TC=$(opkg list_installed | grep "^tc-adv - " | awk -F" - " '{print $2}')
		LATEST="$(/usr/sbin/curl -fsL --retry 3 https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/$SCRIPT_BRANCH/$SCRIPT_NAME.sh)"
		LATEST_VERSION=$(echo "$LATEST" | grep "^readonly SCRIPT_VERSION" | awk -F"=" '{print $2}' | cut -d "\"" -f 2)
		LOCALMD5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		REMOTEMD5="$(/usr/sbin/curl -fsL --retry 3 https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/$SCRIPT_BRANCH/$SCRIPT_NAME.sh | md5sum | awk '{print $1}')"

		if [ "${LATEST_VERSION}" != "" ]; then
			if [ "${LATEST_VERSION}" != "${SCRIPT_VERSION}" ]; then
				Print_Output "true" "New CakeQOS-Merlin detected (${LATEST_VERSION}, currently running ${SCRIPT_VERSION}), updating..." "$WARN"
				echo "${LATEST}" > "/jffs/scripts/${SCRIPT_NAME}"
				chmod 0755 "/jffs/scripts/${SCRIPT_NAME}"
			elif [ "$LOCALMD5" != "$REMOTEMD5" ]; then
				Print_Output "true" "Local and server md5 don't match, updating..." "$WARN"
				echo "${LATEST}" > "/jffs/scripts/${SCRIPT_NAME}"
				chmod 0755 "/jffs/scripts/${SCRIPT_NAME}"
			else
				Print_Output "false" "You are running the latest CakeQOS-Merlin script (${LATEST_VERSION}, currently running ${SCRIPT_VERSION}), skipping..." "$PASS"
			fi
		fi
	elif [ "${1}" = "install" ]; then
		VERSION_LOCAL_CAKE="0"
		VERSION_LOCAL_TC="0"
		DOINSTALL="1"
	fi

	case "$RMODEL" in
		RT-AC86U)
			FILE1_TYPE="1"
			;;
		RT-AX88U)
			FILE1_TYPE="ax"
			;;
		*)
			Print_Output "false" "Cake isn't yet compatible with ASUS $RMODEL, keep watching our thread!" "$CRIT"
			exit 1
			;;
	esac

        if [ ! -f "/opt/lib/modules/sch_cake.ko" ] || [ ! -f "/opt/sbin/tc" ]; then
                 DOINSTALL="1"
        fi

	VERSIONS_ONLINE=$(/usr/sbin/curl --retry 3 -s "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/$SCRIPT_BRANCH/versions.txt")
	if [ "${VERSIONS_ONLINE}" != "" ]; then
		VERSION_ONLINE_CAKE=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $1}')
		VERSION_ONLINE_TC=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $2}')
		VERSION_ONLINE_SUFFIX=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $3}')
		if [ "${VERSION_LOCAL_CAKE}" != "${VERSION_ONLINE_CAKE}" ] || [ "${VERSION_LOCAL_TC}" != "${VERSION_ONLINE_TC}" ] || [ "$DOINSTALL" = "1" ]; then
			if [ "$DOINSTALL" = "1" ]; then
				Print_Output "true" "Installing cake binaries" "$WARN"
			else
				Print_Output "true" "Updated cake binaries detected, updating..." "$WARN"
			fi
			FILE1="sched-cake-oot_${VERSION_ONLINE_CAKE}-${FILE1_TYPE}_${VERSION_ONLINE_SUFFIX}.ipk"
			FILE2="tc-adv_${VERSION_ONLINE_TC}_${VERSION_ONLINE_SUFFIX}.ipk"
			FILE1_OUT="sched-cake-oot.ipk"
			FILE2_OUT="tc-adv.ipk"
			/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/$SCRIPT_BRANCH/${FILE1}" -o "/tmp/home/root/${FILE1_OUT}"
			/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/$SCRIPT_BRANCH/${FILE2}" -o "/tmp/home/root/${FILE2_OUT}"

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
				Print_Output "true" "There was an error downloading the cake binaries, please try again." "$ERR"
				return 1
			fi
		else
			Print_Output "false" "Your cake binaries are up-to-date." "$PASS"
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
			cru a "$SCRIPT_NAME_FANCY" "*/30 * * * * $0 checkrun"
			cake_serve "${@}"
			exit 0
		else
			Print_Output "true" "Entware isn't ready, waiting 10 sec - retry $i" "$ERR"
			sleep 10
		fi
	done
	if [ ! -f /opt/bin/sh ]; then
		Print_Output "true" "Entware didn't start in 100 seconds, please check" "$CRIT"
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

	Print_Output "true" "Starting - settings: ${2} | ${3} | ${options}" "$PASS"
	runner disable 2>/dev/null
	fc disable 2>/dev/null
	fc flush 2>/dev/null
	insmod /opt/lib/modules/sch_cake.ko 2>/dev/null
	/opt/sbin/tc qdisc replace dev eth0 root cake bandwidth "${3}" nat ${options} # options needs to be left unquoted to support multiple extra parameters
	ip link add name ifb9eth0 type ifb
	/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
	/opt/sbin/tc qdisc add dev eth0 handle ffff: ingress
	/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
	/opt/sbin/tc qdisc add dev ifb9eth0 root cake bandwidth "${2}" nat wash ingress ${options} # options needs to be left unquoted to support multiple extra parameters
	ifconfig ifb9eth0 up
	/opt/sbin/tc filter add dev eth0 parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb9eth0
}

### Cake Stop If
cake_stopif() {
	if [ "$(isrunning)" = "true" ]; then
		cake_stop
	fi
}

### Cake Stop
cake_stop() {
	Print_Output "true" "Stopping" "$PASS"
	/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
	/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
	/opt/sbin/tc qdisc del dev eth0 root 2>/dev/null
	ip link del ifb9eth0
	rmmod sch_cake 2>/dev/null
	fc enable
	runner enable
	cru d "$SCRIPT_NAME_FANCY"
  > "$WDog"
}

### Cake Disable
cake_disable() {
	Print_Output "true" "Disabled" "$PASS"
	if [ -f /jffs/scripts/firewall-start ]; then
		LINECOUNT=$(grep -c '# '"$SCRIPT_NAME_FANCY" /jffs/scripts/nat-start)
		if [ "$LINECOUNT" -gt 0 ]; then
			sed -i -e '/# '"$SCRIPT_NAME_FANCY"'/d' /jffs/scripts/nat-start
		fi
	fi
	if [ -f /jffs/scripts/services-stop ]; then
		LINECOUNT=$(grep -c '# '"$SCRIPT_NAME_FANCY" /jffs/scripts/services-stop)
		if [ "$LINECOUNT" -gt 0 ]; then
			sed -i -e '/# '"$SCRIPT_NAME_FANCY"'/d' /jffs/scripts/services-stop
		fi
	fi
	if [ -d "$WDogdir" ]; then
		rm -r "$WDogdir"
	fi
}

### Check Requirements
FAIL="0"
if [ "$(nvram get jffs2_scripts)" -ne 1 ]; then
	Print_Output "true" "ERROR: Custom JFFS Scripts must be enabled." "$CRIT"
	FAIL="1"
fi
if [ "${1}" != "start" ] && [ ! -f "/opt/bin/opkg" ]; then
	Print_Output "true" "ERROR: Entware must be installed." "$CRIT"
	FAIL="1"
fi
if [ "${FAIL}" = "1" ]; then
	return 1
fi

### Parameter Checks
if [ "${1}" = "enable" ] || [ "${1}" = "start" ]; then
	if [ -z "$2" ] || [ -z "$3" ]; then
		Print_Output "false" "Required parameters missing: $SCRIPT_NAME ${1} dlspeed upspeed \"optional extra parameters\"" "$WARN"
		Print_Output "false" ""
		Print_Output "false" "Example #1: $SCRIPT_NAME ${1} 30Mbit 5000Kbit"
		Print_Output "false" "Example #2: $SCRIPT_NAME ${1} 30Mbit 5Mbit \"diffserv4 docsis ack-filter\""
		return 1
	fi
fi

case $1 in
	install|update)
    install_watchdog
		cake_download "${@}"
		[ -f "/opt/bin/$SCRIPT_NAME" ] || ln -s "$0" "/opt/bin/$SCRIPT_NAME" >/dev/null 2>&1 # add to /opt/bin so it can be called only as "cake-qos param"
		;;
	enable|start)
    install_watchdog
    [ -f "/opt/bin/$SCRIPT_NAME" ] || ln -s "$0" "/opt/bin/$SCRIPT_NAME" >/dev/null 2>&1 # add to /opt/bin so it can be called only as "cake-qos param"
		cake_stopif
		#check if bins are installed, for the sake of......
		if [ ! -f "/opt/lib/modules/sch_cake.ko" ] || [ ! -f "/opt/sbin/tc" ]; then
				 cake_download "${@}"
		fi
		
		
		# Start
####### remove from here after a while....
		# Remove from firewall-start and services-start
		if [ -f /jffs/scripts/firewall-start ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME_FANCY" /jffs/scripts/firewall-start)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME start"' # '"$SCRIPT_NAME" /jffs/scripts/firewall-start)

			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/firewall-start
			fi
		fi

		if [ -f /jffs/scripts/services-start ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME_FANCY" /jffs/scripts/services-start)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME start"' # '"$SCRIPT_NAME" /jffs/scripts/services-start)

			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
			fi
		fi		
####### until here.....


		# Add to nat-start
		if [ -f /jffs/scripts/nat-start ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME_FANCY" /jffs/scripts/nat-start)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME start"' # '"$SCRIPT_NAME_FANCY" /jffs/scripts/nat-start)

			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME_FANCY"'/d' /jffs/scripts/nat-start
			fi

			if [ "$LINECOUNTEX" -eq 0 ]; then
				echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" &"' # '"$SCRIPT_NAME_FANCY" >> /jffs/scripts/nat-start
				echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" &"' # '"$SCRIPT_NAME_FANCY" >> "$WDog"
			fi
		else
			printf "#!/bin/sh\n\n/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" & # $SCRIPT_NAME_FANCY"  >> /jffs/scripts/nat-start
			echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" &"' # '"$SCRIPT_NAME_FANCY" >> "$WDog"
			chmod 0755 /jffs/scripts/nat-start
		fi
		# Stop
		if [ -f /jffs/scripts/services-stop ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME_FANCY" /jffs/scripts/services-stop)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME stop"' # '"$SCRIPT_NAME_FANCY" /jffs/scripts/services-stop)

			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME_FANCY"'/d' /jffs/scripts/services-stop
			fi

			if [ "$LINECOUNTEX" -eq 0 ]; then
				echo "/jffs/scripts/$SCRIPT_NAME stop"' # '"$SCRIPT_NAME_FANCY" >> /jffs/scripts/services-stop
			fi
		else
			SCRIPT_NAME="cake-qos"
			printf "#!/bin/sh\n\n/jffs/scripts/$SCRIPT_NAME stop # $SCRIPT_NAME_FANCY" > /jffs/scripts/services-stop
			chmod 0755 /jffs/scripts/services-stop
		fi
		
		Print_Output "true" "Enabled" "$PASS"
		cake_start "${@}"
		return 0
		;;
	status)
		if [ "$(isrunning)" = "true" ]; then
			isrunning >/dev/null 2>&1
			Print_Output "true" "Running..." "$WARN"
			Print_Output "false" "> Download Status:" "$PASS"
			echo "$STATUS_DOWNLOAD"
			Print_Output "false" "> Upload Status:" "$PASS"
			echo "$STATUS_UPLOAD"
			return 0
		else
			Print_Output "true" "Not running..." "$PASS"
			return 1
		fi
		;;
	checkrun)
		if [ "$(isrunning)" = "false" ]; then
			. "$WDog"
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
		rm /jffs/scripts/"$SCRIPT_NAME"
		return 0
		;;
	*)
		Print_Output "false" "Usage: $SCRIPT_NAME {install|update|enable|start|status|stop|disable|uninstall} (enable and start have required parameters)" "$WARN"
		Print_Output "false" "" "$PASS"
		Print_Output "false" "install:   download and install necessary $SCRIPT_NAME binaries" "$PASS"
		Print_Output "false" "update:    update $SCRIPT_NAME binaries (if any available)" "$PASS"
		Print_Output "false" "enable:    start $SCRIPT_NAME and add to startup" "$PASS"
		Print_Output "false" "start:     start $SCRIPT_NAME" "$PASS"
		Print_Output "false" "status:    check the current status of $SCRIPT_NAME" "$PASS"
		Print_Output "false" "stop:      stop $SCRIPT_NAME" "$PASS"
		Print_Output "false" "disable:   stop $SCRIPT_NAME and remove from startup" "$PASS"
		Print_Output "false" "uninstall: stop $SCRIPT_NAME, remove from startup, and remove cake binaries" "$PASS"
		return 1
		;;
esac

exit 0
