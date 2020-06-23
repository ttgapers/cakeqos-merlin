#!/bin/sh
# CakeQOS-Merlin - port for Merlin firmware supported routers
# Site: https://github.com/ttgapers/cakeqos-merlin
# Thread: https://www.snbforums.com/threads/release-cakeqos-merlin.64800/
# Credits: robcore, Odkrys, ttgapers, jackiechun

# shellcheck disable=SC2086
readonly SCRIPT_VERSION="v0.0.6"
readonly SCRIPT_NAME="cake-qos"
readonly SCRIPT_NAME_FANCY="CakeQOS-Merlin"
readonly SCRIPT_NAME_GITHUB="cakeqos-merlin"
readonly SCRIPT_BRANCH="master"
readonly MAINTAINER="ttgapers"

readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"

[ -z "$(nvram get odmpid)" ] && RMODEL=$(nvram get productid) || RMODEL=$(nvram get odmpid) #get router model

Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME_FANCY" "$2"
		printf "\\e[1m$3%s: $2\\e[0m\\n" "$SCRIPT_NAME_FANCY - $SCRIPT_VERSION"
	else
		printf "\\e[1m$3%s: $2\\e[0m\\n" "$SCRIPT_NAME_FANCY - $SCRIPT_VERSION"
	fi
}

Filter_Version() {
	grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})'
}

cake_check() {
	STATUS_UPLOAD=$(tc qdisc | grep -E '^qdisc cake .* dev eth0 root')
	STATUS_DOWNLOAD=$(tc qdisc | grep -E '^qdisc cake .* dev ifb9eth0 root')
	if [ -n "$STATUS_UPLOAD" ] && [ -n "$STATUS_DOWNLOAD" ]; then
		return 0
	else
		return 1
	fi
}

cake_download() {
	if [ "$1" = "update" ]; then
		VERSION_LOCAL_CAKE=$(opkg list_installed | grep "^sched-cake-oot - " | awk -F" - " '{print $2}' | cut -d- -f-4)
		VERSION_LOCAL_TC=$(opkg list_installed | grep "^tc-adv - " | awk -F" - " '{print $2}')
		LATEST="$(/usr/sbin/curl -fsL --retry 3 https://raw.githubusercontent.com/$MAINTAINER/$SCRIPT_NAME_GITHUB/$SCRIPT_BRANCH/$SCRIPT_NAME.sh)"
		REMOTE_VERSION=$(/usr/sbin/curl -fsL --retry 3 https://raw.githubusercontent.com/$MAINTAINER/$SCRIPT_NAME_GITHUB/$SCRIPT_BRANCH/$SCRIPT_NAME.sh | Filter_Version)
		LOCALMD5="$(md5sum "$0" | awk '{print $1}')"
		REMOTEMD5="$(/usr/sbin/curl -fsL --retry 3 https://raw.githubusercontent.com/$MAINTAINER/$SCRIPT_NAME_GITHUB/$SCRIPT_BRANCH/$SCRIPT_NAME.sh | md5sum | awk '{print $1}')"

		if [ -n "$REMOTE_VERSION" ]; then
			if [ "$LOCALMD5" != "$REMOTEMD5" ]; then
				if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
					Print_Output "true" "New CakeQOS-Merlin detected (${REMOTE_VERSION}, currently running ${SCRIPT_VERSION}), updating..." "$WARN"
				else
					Print_Output "true" "Local and server md5 don't match, updating..." "$WARN"
				fi
				echo "${LATEST}" > "/jffs/scripts/${SCRIPT_NAME}"
				chmod 0755 "/jffs/scripts/${SCRIPT_NAME}"
			else
				Print_Output "false" "You are running the latest $SCRIPT_NAME_FANCY script (${REMOTE_VERSION}, currently running ${SCRIPT_VERSION}), skipping..." "$PASS"
			fi
		fi
	elif [ "$1" = "install" ]; then
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

	VERSIONS_ONLINE=$(/usr/sbin/curl -fsL --retry 3 --connect-timeout 3 "https://raw.githubusercontent.com/$MAINTAINER/$SCRIPT_NAME_GITHUB/$SCRIPT_BRANCH/versions.txt")
	if [ -n "$VERSIONS_ONLINE" ]; then
		VERSION_ONLINE_CAKE=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $1}')
		VERSION_ONLINE_TC=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $2}')
		VERSION_ONLINE_SUFFIX=$(echo "$VERSIONS_ONLINE" | awk -F"|" '{print $3}')
		if [ "$VERSION_LOCAL_CAKE" != "$VERSION_ONLINE_CAKE" ] || [ "$VERSION_LOCAL_TC" != "$VERSION_ONLINE_TC" ] || [ "$DOINSTALL" = "1" ]; then
			if [ "$DOINSTALL" = "1" ]; then
				Print_Output "true" "Installing cake binaries" "$WARN"
			else
				Print_Output "true" "New cake binaries detected, updating..." "$WARN"
			fi
			FILE1="sched-cake-oot_${VERSION_ONLINE_CAKE}-${FILE1_TYPE}_${VERSION_ONLINE_SUFFIX}.ipk"
			FILE2="tc-adv_${VERSION_ONLINE_TC}_${VERSION_ONLINE_SUFFIX}.ipk"
			FILE1_OUT="sched-cake-oot.ipk"
			FILE2_OUT="tc-adv.ipk"
			/usr/sbin/curl -fsL --retry 3 --connect-timeout 3 "https://raw.githubusercontent.com/$MAINTAINER/$SCRIPT_NAME_GITHUB/$SCRIPT_BRANCH/${FILE1}" -o "/tmp/home/root/${FILE1_OUT}"
			/usr/sbin/curl -fsL --retry 3 --connect-timeout 3 "https://raw.githubusercontent.com/$MAINTAINER/$SCRIPT_NAME_GITHUB/$SCRIPT_BRANCH/${FILE2}" -o "/tmp/home/root/${FILE2_OUT}"

			if [ -f "/tmp/home/root/${FILE1_OUT}" ] && [ -f "/tmp/home/root/${FILE2_OUT}" ]; then
				if [ "$1" = "update" ]; then
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

cake_start() {
	entwaretimer="0"
	while [ ! -f "/opt/bin/sh" ] && [ "$entwaretimer" -lt "10" ]; do
		entwaretimer="$((entwaretimer + 1))"
		Print_Output "true" "Entware isn't ready, waiting 10 sec - Attempt #${entwaretimer}" "$WARN"
		sleep 10
	done
	if [ "$entwaretimer" -ge "100" ]; then
		Print_Output "true" "Entware didn't start in 100 seconds, please check" "$CRIT"
		exit 1
	else
		cru a "$SCRIPT_NAME_FANCY" "*/30 * * * * /jffs/scripts/$SCRIPT_NAME checkrun ${2} ${3} \"${4}\""
		options="$4"
		case "$options" in
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
		exit 0 # Why do we exit here? All functions should be contained
	fi
}

cake_stop() {
	if cake_check; then
		Print_Output "true" "Stopping" "$PASS"
		cru d "$SCRIPT_NAME_FANCY"
		/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
		/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
		/opt/sbin/tc qdisc del dev eth0 root 2>/dev/null
		ip link del ifb9eth0
		rmmod sch_cake 2>/dev/null
		fc enable
		runner enable
	fi
}

case $1 in
	install|update)
		if [ "$(nvram get jffs2_scripts)" != "1" ]; then
			nvram set jffs2_scripts=1
			nvram commit
			Print_Output "true" "Custom JFFS scripts enabled - Please manually reboot to apply changes - Exiting" "$CRIT"
			exit 1
		fi
		cake_download "${@}"
		[ -L "/opt/bin/$SCRIPT_NAME" ] || ln -s "$0" /opt/bin
		;;
	start)
		if [ -z "$2" ] || [ -z "$3" ]; then
			Print_Output "false" "Required parameters missing: $SCRIPT_NAME ${1} dlspeed upspeed \"optional extra parameters\"" "$WARN"
			Print_Output "false" ""
			Print_Output "false" "Example #1: $SCRIPT_NAME ${1} 30Mbit 5000Kbit"
			Print_Output "false" "Example #2: $SCRIPT_NAME ${1} 30Mbit 5Mbit \"diffserv4 docsis ack-filter\""
			exit 1
		fi
		cake_stop

		if [ ! -f "/opt/lib/modules/sch_cake.ko" ] || [ ! -f "/opt/sbin/tc" ]; then
			Print_Output "true" "Cake binaries missing - Exiting" "$CRIT"
			exit 1
		fi

		# Cleanup old script entries
		rm -r "/jffs/addons/$SCRIPT_NAME.d"
		sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/firewall-start /jffs/scripts/services-start

		# Add to nat-start
		if [ ! -f "/jffs/scripts/nat-start" ]; then
			echo "#!/bin/sh" > /jffs/scripts/nat-start
			echo >> /jffs/scripts/nat-start
		elif [ -f "/jffs/scripts/nat-start" ] && ! head -1 /jffs/scripts/nat-start | grep -qE "^#!/bin/sh"; then
			sed -i '1s~^~#!/bin/sh\n~' /jffs/scripts/nat-start
		fi
		if ! grep -qF "# CakeQOS-Merlin" /jffs/scripts/nat-start; then
			echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\" &"' # '"$SCRIPT_NAME_FANCY" >> /jffs/scripts/nat-start
			chmod 0755 /jffs/scripts/nat-start
		fi

		# Add to services-stop
		if [ ! -f "/jffs/scripts/services-stop" ]; then
			echo "#!/bin/sh" > /jffs/scripts/services-stop
			echo >> /jffs/scripts/services-stop
		elif [ -f "/jffs/scripts/services-stop" ] && ! head -1 /jffs/scripts/services-stop | grep -qE "^#!/bin/sh"; then
			sed -i '1s~^~#!/bin/sh\n~' /jffs/scripts/services-stop
		fi
		if ! grep -qF "# CakeQOS-Merlin" /jffs/scripts/services-stop; then
			echo "/jffs/scripts/$SCRIPT_NAME stop"' # '"$SCRIPT_NAME_FANCY" >> /jffs/scripts/services-stop
			chmod 0755 /jffs/scripts/services-stop
		fi
		Print_Output "true" "Enabled" "$PASS"
		cake_start "${@}"
		return 0
		;;
	status)
		if cake_check; then
			Print_Output "true" "Running..." "$PASS"
			Print_Output "false" "> Download Status:" "$PASS"
			echo "$STATUS_DOWNLOAD"
			Print_Output "false" "> Upload Status:" "$PASS"
			echo "$STATUS_UPLOAD"
			return 0
		else
			Print_Output "true" "Not running..." "$WARN"
			return 1
		fi
		;;
	checkrun)
		Print_Output "true" "Checking if running..." "$WARN" #remove this when we see that it's working OK. It isn't needed to spam log each 30 min
		if ! cake_check; then
			Print_Output "true" "Not running, starting..." "$CRIT"
			cake_start "${@}"
		else
			Print_Output "true" "Running successfully" "$PASS" #remove this when we see that it's working OK. It isn't needed to spam log each 30 min
		fi
		;;
	stop)
		cake_stop
		return 0
		;;
	uninstall)
		cake_stop
		sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/nat-start /jffs/scripts/services-stop
		opkg --autoremove remove sched-cake-oot
		opkg --autoremove remove tc-adv
		rm /jffs/scripts/"$SCRIPT_NAME"
		return 0
		;;
	*)
		Print_Output "false" "Usage: $SCRIPT_NAME {install|update|start|status|stop|disable|uninstall} (start has required parameters)" "$WARN"
		echo
		Print_Output "false" "install:   only downloads and installs necessary $SCRIPT_NAME binaries" "$PASS"
		Print_Output "false" "update:    update $SCRIPT_NAME binaries (if any available)" "$PASS"
		Print_Output "false" "start:     configure and start $SCRIPT_NAME" "$PASS"
		Print_Output "false" "status:    check the current status of $SCRIPT_NAME" "$PASS"
		Print_Output "false" "stop:      stop $SCRIPT_NAME" "$PASS"
		Print_Output "false" "disable:   stop $SCRIPT_NAME and remove from startup" "$PASS"
		Print_Output "false" "uninstall: stop $SCRIPT_NAME, remove from startup, and remove cake binaries" "$PASS"
		return 1
		;;
esac

exit 0