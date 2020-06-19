#!/bin/sh
# CAKE QoS port for Merlin firmware supported routers
# https://www.snbforums.com/threads/rt-ac86u-i-built-cake.49190/
# Credits: robcore, Odkrys, ttgapers, jackiechun

readonly SCRIPT_NAME="cake-qos"

### Cake Start
cake_start() {
	logger "Cake Queue Management Starting - settings: ${2} | ${3} | ${4}"
	runner disable 2>/dev/null
	fc disable 2>/dev/null
	fc flush 2>/dev/null
	insmod /opt/lib/modules/sch_cake.ko 2>/dev/null
	/opt/sbin/tc qdisc replace dev eth0 root cake bandwidth "${3}" besteffort nat "${4}"
	ip link add name ifb9eth0 type ifb
	/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
	/opt/sbin/tc qdisc add dev eth0 handle ffff: ingress
	/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
	/opt/sbin/tc qdisc add dev ifb9eth0 root cake bandwidth "${2}" besteffort nat wash ingress "${4}"
	ifconfig ifb9eth0 up
	/opt/sbin/tc filter add dev eth0 parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb9eth0
}

### Cake Stop
cake_stop() {
	logger "Cake Queue Management Stopping"
	/opt/sbin/tc qdisc del dev eth0 ingress 2>/dev/null
	/opt/sbin/tc qdisc del dev ifb9eth0 root 2>/dev/null
	/opt/sbin/tc qdisc del dev eth0 root 2>/dev/null
	ip link del ifb9eth0
	rmmod sch_cake 2>/dev/null
	fc enable
	runner enable
}

### Check Requirements
FAIL="0"
if [ "$(nvram get jffs2_scripts)" -ne 1 ]; then
	echo "ERROR: Custom JFFS Scripts must be enabled."
	FAIL="1"
fi
if [ ! -f "/opt/bin/opkg" ]; then
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
		echo "Example #2: $SCRIPT_NAME ${1} 30Mbit 5Mbit \"docsis ack-filter\""
		return 1
	fi	
fi
if [ "${1}" = "install" ] && [ -z "$2" ]; then
	echo "Required model missing: $SCRIPT_NAME ${1} {ac86u|ax88u}"
	echo ""
	echo "Example #1: $SCRIPT_NAME ${1} ac86u"
	echo "Example #2: $SCRIPT_NAME ${1} ax88u"
	return 1
fi

case $1 in
	install)
		if [ "${2}" = "ac86u" ]; then
			FILE1="https://5m.ca/cake/sched-cake-oot_2020-05-28-a5dccfd8-1_aarch64-3.10.ipk"
		elif [ "${2}" = "ax88u" ]; then
			FILE1="sched-cake-oot_2020-05-28-a5dccfd8-ax_aarch64-3.10.ipk"
		fi
		FILE2="tc-adv_4.16.0-git-20191110_aarch64-3.10.ipk"
		/usr/sbin/curl --retry 3 "https://5m.ca/cake/${FILE1}" -o "/tmp/home/root/${FILE1}"
		/usr/sbin/curl --retry 3 "https://5m.ca/cake/${FILE2}" -o "/tmp/home/root/${FILE2}"
		/opt/bin/opkg install "/tmp/home/root/${FILE1}"
		/opt/bin/opkg install "/tmp/home/root/${FILE2}"
		rm "/tmp/home/root/${FILE1}"
		rm "/tmp/home/root/${FILE2}"
		return 0
		;;
	enable)
		# Start
		if [ -f /jffs/scripts/firewall-start ]; then
			LINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/firewall-start)
			LINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME start"' # '"$SCRIPT_NAME" /jffs/scripts/firewall-start)
			
			if [ "$LINECOUNT" -gt 1 ] || { [ "$LINECOUNTEX" -eq 0 ] && [ "$LINECOUNT" -gt 0 ]; }; then
				sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/firewall-start
			fi
			
			if [ "$LINECOUNTEX" -eq 0 ]; then
				echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\""' # '"$SCRIPT_NAME" >> /jffs/scripts/firewall-start
			fi
		else
			echo "#!/bin/sh" > /jffs/scripts/firewall-start
			echo "" >> /jffs/scripts/firewall-start
			echo "/jffs/scripts/$SCRIPT_NAME start ${2} ${3} \"${4}\""' # '"$SCRIPT_NAME" >> /jffs/scripts/firewall-start
			chmod 0755 /jffs/scripts/firewall-start
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
		logger "Cake Queue Management Enabled - settings: ${2} | ${3} | ${4}"
		cake_start "${@}"
		return 0
		;;
	disable)
		cake_stop
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
		logger "Cake Queue Management Disabled"
		return 0
		;;
	start)
		cake_start "${@}"
		return 0
		;;
	stop)
		cake_stop
		return 0
		;;
	*)
		echo "Usage: $SCRIPT_NAME {install|enable|start|stop|disable} (install, enable, and start have required parameters)"
		echo ""
		echo "install: install necessary $SCRIPT_NAME binaries"
		echo "enable:  start $SCRIPT_NAME and add to startup"
		echo "start:   start $SCRIPT_NAME"
		echo "stop:    stop $SCRIPT_NAME"
		echo "disable: stop $SCRIPT_NAME and remove from startup"
		return 1
		;;
esac
