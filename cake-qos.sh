#!/bin/sh
# CakeQOS-Merlin - port for Merlin firmware supported routers
# Site: https://github.com/ttgapers/cakeqos-merlin
# Thread: https://www.snbforums.com/threads/release-cakeqos-merlin.64800/
# Credits: robcore, Odkrys, ttgapers, jackiechun, maghuro, Adamm, Jack Yaz

#########################################################
##               _                                     ##
##              | |                                    ##
##    ___  __ _ | | __ ___          __ _   ___   ___   ##
##   / __|/ _` || |/ // _ \ ______ / _` | / _ \ / __|  ##
##  | (__ |(_| ||   <|  __/|______| (_| || (_) |\__ \  ##
##   \___|\__,_||_|\_\\___|        \__, | \___/ |___/  ##
##                                    | |              ##
##                                    |_|              ##
##                                                     ##
##      https://github.com/ttgapers/cakeqos-merlin     ##
##                        v2.0.0                       ##
##                                                     ##
#########################################################

# shellcheck disable=SC2086

clear
sed -n '6,21p' "$0"

readonly version=2.0.0
readonly SCRIPT_NAME="cake-qos"
readonly SCRIPT_NAME_FANCY="CakeQOS-Merlin"
readonly SCRIPT_BRANCH="develop"
readonly SCRIPT_DIR="/jffs/addons/${SCRIPT_NAME}"
readonly SCRIPT_REMOTEDIR="https://raw.githubusercontent.com/dave14305/cakeqos-merlin/${SCRIPT_BRANCH}"

readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"

[ -z "$(nvram get odmpid)" ] && RMODEL=$(nvram get productid) || RMODEL=$(nvram get odmpid) #get router model

. /usr/sbin/helper.sh

# Update version number in custom_settings.txt for reading in WebUI
if [ "$(am_settings_get cakeqos_ver)" != "$version" ]; then
	am_settings_set cakeqos_ver "$version"
fi

Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME_FANCY" "$2"
		printf "\\e[1m$3%s: $2\\e[0m\\n" "$SCRIPT_NAME_FANCY"
	else
		printf "\\e[1m$3%s: $2\\e[0m\\n" "$SCRIPT_NAME_FANCY"
	fi
}

Validate_Bandwidth(){
	grep -qE "^[0-9]{1,3}(\.[0-9]+)?$"
}

Display_Line(){
	printf '\n#########################################################\n\n'
}

get_wanif() {
	prefixes="wan0_ wan1_"

	if [ "$(nvram get wans_mode)" = "lb" ] ; then
		for prefix in $prefixes; do
			state=$(nvram get "${prefix}"state_t)
			sbstate=$(nvram get "${prefix}"sbstate_t)
			auxstate=$(nvram get "${prefix}"auxstate_t)

			# is_wan_connect()
			[ "$state" = "2" ] || continue
			[ "$sbstate" = "0" ] || continue
			[ "$auxstate" = "0" ] || [ "$auxstate" = "2" ] || continue

			# get_wan_ifname()
			proto=$(nvram get "${prefix}"proto)
			if [ "$proto" = "pppoe" ] || [ "$proto" = "pptp" ] || [ "$proto" = "l2tp" ] ; then
				ifname=$(nvram get "${prefix}"pppoe_ifname)
			else
				ifname=$(nvram get "${prefix}"ifname)
			fi
		done
	else
		for prefix in $prefixes; do
			primary=$(nvram get "${prefix}"primary)
			[ "$primary" = "1" ] && break
		done

		[ "$primary" = "1" ] || ifname="eth0"

		# get_wan_ifname()
		proto=$(nvram get "${prefix}"proto)
		if [ "$proto" = "pppoe" ] || [ "$proto" = "pptp" ] || [ "$proto" = "l2tp" ] ; then
			ifname=$(nvram get "${prefix}"pppoe_ifname)
		else
			ifname=$(nvram get "${prefix}"ifname)
		fi
	fi
	printf "%s" "$ifname"
}

Cake_Get_DLIF(){
	local DLIF
	DLIF="$(am_settings_get cakeqos_dlif)"
	[ -z "$DLIF" ] && DLIF="0"
	case $DLIF in
		1) printf "%s\n" "$(nvram get lan_ifname)" ;;
		*) printf "%s\n" "$(get_wanif)" ;;
	esac
}

# Cake_Get_Overhead(){
	# local OVERHEAD MPU ATM
	# OVERHEAD="$(nvram get qos_overhead)"
	# MPU="$(nvram get qos_mpu)"
	# ATM="$(nvram get qos_atm)"
	# [ -z "$OVERHEAD" ] && OVERHEAD="0"
	# [ -z "$MPU" ] && MPU="0"
	# [ -z "$ATM" ] && ATM=""
	# case $ATM in
		# 1) ATM="atm" ;;
		# 2) ATM="ptm" ;;
		# *) ATM="" ;;
	# esac
	# printf "overhead %d mpu %d %s\n" "$OVERHEAD" "$MPU" "$ATM"
# }

Cake_Get_Prio(){
	local DIR PRIO
	DIR="$1"
	PRIO="$(am_settings_get cakeqos_${DIR}prio)"
	if [ -z "$PRIO" ]; then
		case $DIR in
			'dl') PRIO="3" ;;
			'ul') PRIO="0" ;;
		esac
	fi
	case $PRIO in
		0) printf "diffserv3\n" ;;
		1) printf "diffserv4\n" ;;
		2) printf "diffserv8\n" ;;
		3) printf "besteffort\n" ;;
		*) printf "\n" ;;
	esac
}

Cake_Get_FlowIso(){
	local DIR FLOWISO
	DIR="$1"
	FLOWISO="$(am_settings_get cakeqos_${DIR}flowiso)"
	if [ -z "$FLOWISO" ]; then
		case $DIR in
			'dl') FLOWISO="6" ;;
			'ul') FLOWISO="5" ;;
		esac
	fi
	case $FLOWISO in
		0) printf "flowblind\n" ;;
		1) printf "srchost\n" ;;
		2) printf "dsthost\n" ;;
		3) printf "hosts\n" ;;
		4) printf "flows\n" ;;
		5) printf "dual-srchost\n" ;;
		6) printf "dual-dsthost\n" ;;
		7) printf "triple-isolate\n" ;;
		*) printf "\n" ;;
	esac
}

Cake_Get_NAT(){
	local DIR NAT
	DIR="$1"
	NAT="$(am_settings_get cakeqos_${DIR}nat)"
	[ -z "$NAT" ] && NAT="$(nvram get wan0_nat_x)"
	case $NAT in
		0) printf "nonat\n" ;;
		1) printf "nat\n" ;;
		*) printf "\n" ;;
	esac
}

Cake_Get_Wash(){
	local DIR WASH
	DIR="$1"
	WASH="$(am_settings_get cakeqos_${DIR}wash)"
	if [ -z "$WASH" ]; then
		case $DIR in
			'dl') WASH="1" ;;
			'ul') WASH="0" ;;
		esac
	fi
	case $WASH in
		0) printf "nowash\n" ;;
		1) printf "wash\n" ;;
		*) printf "\n" ;;
	esac
}

Cake_Get_ACK(){
	local DIR ACK
	DIR="$1"
	ACK="$(am_settings_get cakeqos_${DIR}ack)"
	[ -z "$ACK" ] && ACK="0"
	case $ACK in
		0) printf "no-ack-filter\n" ;;
		1) printf "ack-filter\n" ;;
		*) printf "\n" ;;
	esac
}

Cake_Get_CustomOpts(){
	local DIR CUST
	DIR="$1"
	CUST="$(am_settings_get cakeqos_${DIR}cust | /usr/sbin/openssl enc -a -d)"
	[ -z "$CUST" ] || printf "%s\n" "$CUST"
}

Cake_Write_QOS(){
	logger -t "$SCRIPT_NAME_FANCY" "Configuring Cake options..."
	# cat >/tmp/qos2 <<EOF
#  !/bin/sh
# source /etc/cake-qos.conf
# case "\$1" in
# start)
	# /jffs/addons/cakeqos-merlin/cake-qos.sh start
	# ;;
# stop)
	# /jffs/addons/cakeqos-merlin/cake-qos.sh stop
	# ;;
# *)
	# /jffs/addons/cakeqos-merlin/cake-qos.sh status
	# ;;
# esac
# EOF

	cat >/jffs/configs/cake-qos.conf.add <<EOF
ULPRIOQUEUE="$(Cake_Get_Prio 'ul')"
DLPRIOQUEUE="$(Cake_Get_Prio 'dl')"
ULOPTIONS="$(Cake_Get_FlowIso 'ul') $(Cake_Get_NAT 'ul') $(Cake_Get_Wash 'ul') $(Cake_Get_ACK 'ul') $(Cake_Get_CustomOpts 'ul')"
DLOPTIONS="$(Cake_Get_FlowIso 'dl') $(Cake_Get_NAT 'dl') $(Cake_Get_Wash 'dl') $(Cake_Get_ACK 'dl') $(Cake_Get_CustomOpts 'dl')"
EOF

}

Cake_CheckStatus(){
	STATUS_UPLOAD=$(tc qdisc | grep -E "^qdisc cake .* dev ${iface} root")
	STATUS_DOWNLOAD=$(tc qdisc | grep -E "^qdisc cake .* dev ifb4${iface} root")
	if [ -n "$STATUS_UPLOAD" ] && [ -n "$STATUS_DOWNLOAD" ]; then
		return 0
	else
		return 1
	fi
}

Download_File() {
	if [ "$(curl -fsL --retry 3 --connect-timeout 3 "${SCRIPT_REMOTEDIR}/${1}" | md5sum | awk '{print $1}')" != "$(md5sum "$2" 2>/dev/null | awk '{print $1}')" ]; then
		if curl -fsL --retry 3 --connect-timeout 3 "${SCRIPT_REMOTEDIR}/${1}" -o "$2"; then
			Print_Output "false" "Updated $(echo "$1" | awk -F / '{print $NF}')" "$PASS"
		else
			Print_Output "false" "Updating $(echo "$1" | awk -F / '{print $NF}') Failed" "$ERR"
			return 1
		fi
	else
		return 1
	fi
}

Cake_Install(){
	local prev_webui_page
	local LOCKFILE FD
	if ! nvram get rc_support | /bin/grep -q "cake"; then
		Print_Output "false" "Cake isn't available in your firmware. Please upgrade to 386.2 or higher!" "$CRIT"
		exit 1
	fi
	if [ "$(nvram get jffs2_scripts)" != "1" ]; then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output "true" "Custom JFFS scripts enabled" "$WARN"
	fi

	# Add to service-event
	if [ ! -f "/jffs/scripts/service-event" ]; then
		echo "#!/bin/sh" > /jffs/scripts/service-event
		echo >> /jffs/scripts/service-event
	elif [ -f "/jffs/scripts/service-event" ] && ! head -1 /jffs/scripts/service-event | grep -qE "^#!/bin/sh"; then
		sed -i '1s~^~#!/bin/sh\n~' /jffs/scripts/service-event
	fi
	if ! grep -q "${SCRIPT_DIR}/${SCRIPT_NAME}.sh config # $SCRIPT_NAME_FANCY" /jffs/scripts/service-event; then
		sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event
		echo "[ \"\$2\" = \"qos\" ] && ${SCRIPT_DIR}/${SCRIPT_NAME}.sh config # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event
		chmod 0755 /jffs/scripts/service-event
	fi

	# Add to qos-start
	if [ ! -f "/jffs/scripts/qos-start" ]; then
		echo "#!/bin/sh" > /jffs/scripts/qos-start
		echo >> /jffs/scripts/qos-start
	elif [ -f "/jffs/scripts/qos-start" ] && ! head -1 /jffs/scripts/qos-start | grep -qE "^#!/bin/sh"; then
		sed -i '1s~^~#!/bin/sh\n~' /jffs/scripts/qos-start
	fi
	if ! grep -q "# $SCRIPT_NAME_FANCY" /jffs/scripts/qos-start; then
		echo "${SCRIPT_DIR}/${SCRIPT_NAME} \$1 # $SCRIPT_NAME_FANCY" >> /jffs/scripts/qos-start
		chmod 0755 /jffs/scripts/qos-start
	fi

	if [ ! -L "/opt/bin/${SCRIPT_NAME}" ] || [ "$(readlink /opt/bin/${SCRIPT_NAME})" != "${SCRIPT_DIR}/${SCRIPT_NAME}" ]; then
		rm -rf /opt/bin/${SCRIPT_NAME}
		ln -s "${SCRIPT_DIR}/${SCRIPT_NAME}" "/opt/bin/${SCRIPT_NAME}"
	fi
	Download_File "${SCRIPT_NAME}.asp" "${SCRIPT_DIR}/${SCRIPT_NAME}.asp"
	# Check if the webpage is already mounted in the GUI and reuse that page
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPT_NAME_FANCY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "$prev_webui_page" ]; then
		# use the same filename as before
		am_webui_page="$prev_webui_page"
	else
		# get a new mountpoint
		am_get_webui_page "${SCRIPT_DIR}/${SCRIPT_NAME}.asp"
	fi
	if [ "$am_webui_page" = "none" ]; then
		logmsg "No API slots available to install web page"
	else
		cp -p "${SCRIPT_DIR}/${SCRIPT_NAME}.asp" /www/user/"$am_webui_page"
		LOCKFILE=/tmp/addonwebui.lock
		FD=386
		eval exec "$FD>$LOCKFILE"
		/usr/bin/flock -x "$FD"
		if [ ! -f /tmp/menuTree.js ]; then
			cp /www/require/modules/menuTree.js /tmp/
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		if ! /bin/grep -q "{url: \"$am_webui_page\", tabName: \"${SCRIPT_NAME_FANCY}\"}," /tmp/menuTree.js; then
			umount /www/require/modules/menuTree.js 2>/dev/null
			sed -i "\~tabName: \"${SCRIPT_NAME_FANCY}\"},~d" /tmp/menuTree.js
			sed -i "/url: \"QoS_Stats.asp\", tabName:/i {url: \"$am_webui_page\", tabName: \"${SCRIPT_NAME_FANCY}\"}," /tmp/menuTree.js
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		/usr/bin/flock -u "$FD"
	fi
}

Cake_Uninstall(){
	local prev_webui_page
	local LOCKFILE FD
	printf "Removing WebUI...\n"
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPT_NAME_FANCY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "$prev_webui_page" ]; then
		# Remove page from the UI menu system
		LOCKFILE=/tmp/addonwebui.lock
		FD=386
		eval exec "$FD>$LOCKFILE"
		/usr/bin/flock -x "$FD"
		umount /www/require/modules/menuTree.js 2>/dev/null
		sed -i "\~tabName: \"${SCRIPT_NAME_FANCY}\"},~d" /tmp/menuTree.js
		if diff -q /tmp/menuTree.js /www/require/modules/menuTree.js >/dev/null 2>&1; then
			# no more custom pages mounted, so remove the file
			rm /tmp/menuTree.js
		else
			# Still some modifications from another script so remount
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		/usr/bin/flock -u "$FD"
		# Remove last mounted asp page
		rm -f /www/user/"$prev_webui_page" 2>/dev/null
	fi
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event /jffs/scripts/qos-start
	rm -rf "/opt/bin/${SCRIPT_NAME}" "${SCRIPT_DIR}" /jffs/configs/cake-qos.conf.add 2>/dev/null
}

if [ -n "$option1" ]; then
	set "$option1" "$option2" "$option3"
	echo "[$] $0 $*" | tr -s " "
fi

iface="$(get_wanif)"

case $1 in
	config)
		Cake_Write_QOS
	;;
	init)
		#Cake_Start
	;;
	status)
		if Cake_CheckStatus; then
			case "$2" in
				download)
					tc -s qdisc show dev ifb4${iface}
				;;
				upload)
					tc -s qdisc show dev ${iface}
				;;
				general)
					Print_Output "false" "> Download Status:" "$PASS"
					echo "$STATUS_DOWNLOAD"
					echo
					Print_Output "false" "> Upload Status:" "$PASS"
					echo "$STATUS_UPLOAD"
				;;
				*)
					echo "Command Not Recognized, Please Try Again"
					echo; exit 2
				;;
			esac
		else
			Print_Output "false" "Not running..." "$WARN"
		fi
	;;
	update)
		VERSION_LOCAL_SCRIPT="$version"
		VERSION_REMOTE_SCRIPT="$(/usr/sbin/curl -fsL --retry 3 ${SCRIPT_REMOTEDIR}/${SCRIPT_NAME}.sh | /bin/grep "^version=" | sed -e 's/version=//' )"
		MD5_LOCAL_SCRIPT="$(md5sum "$0" | awk '{print $1}')"
		MD5_LOCAL_ASP="$(md5sum "${SCRIPT_DIR}/${SCRIPT_NAME}.asp" | awk '{print $1}')"
		MD5_REMOTE_SCRIPT="$(/usr/sbin/curl -fsL --retry 3 ${SCRIPT_REMOTEDIR}/${SCRIPT_NAME}.sh | md5sum | awk '{print $1}')"
		MD5_REMOTE_ASP="$(/usr/sbin/curl -fsL --retry 3 ${SCRIPT_REMOTEDIR}/${SCRIPT_NAME}.asp | md5sum | awk '{print $1}')"
		if [ -n "$VERSION_REMOTE_SCRIPT" ]; then
			if [ "$MD5_LOCAL_SCRIPT" != "$MD5_REMOTE_SCRIPT" ] || [ "$MD5_LOCAL_ASP" != "$MD5_REMOTE_ASP" ]; then
				if [ "$VERSION_LOCAL_SCRIPT" != "$VERSION_REMOTE_SCRIPT" ]; then
					Print_Output "true" "New $SCRIPT_NAME_FANCY detected ($VERSION_REMOTE_SCRIPT, currently running $VERSION_LOCAL_SCRIPT), updating..." "$WARN"
				else
					Print_Output "true" "Local and remote md5 don't match, updating..." "$WARN"
				fi
				Download_File "${SCRIPT_NAME}.sh" "$0"
				Download_File "${SCRIPT_NAME}.asp" "${SCRIPT_DIR}/${SCRIPT_NAME}.asp"
				exec sh "$0" install
				echo; exit 1
			else
				Print_Output "false" "${SCRIPT_NAME_FANCY} is up-to-date." "$PASS"
			fi
		else
			Print_Output "false" "Updating ${SCRIPT_NAME_FANCY} Failed" "$ERR"
		fi
	;;
	install)
		Cake_Install
		service restart_qos
	;;
	uninstall)
		Cake_Uninstall
		echo
		exit 0
	;;
	debug)
		printf "DLIF: %s\n" "$(Cake_Get_DLIF)"
#		printf "Overhead: %s\n" "$(Cake_Get_Overhead)"
		printf "Prio: %s %s\n" "$(Cake_Get_Prio 'dl')" "$(Cake_Get_Prio 'ul')"
		printf "Flow Iso: %s %s\n" "$(Cake_Get_FlowIso 'dl')" "$(Cake_Get_FlowIso 'ul')"
		printf "NAT: %s %s\n" "$(Cake_Get_NAT 'dl')" "$(Cake_Get_NAT 'ul')"
		printf "Wash: %s %s\n" "$(Cake_Get_Wash 'dl')" "$(Cake_Get_Wash 'ul')"
		printf "ACK: %s %s\n" "$(Cake_Get_ACK 'dl')" "$(Cake_Get_ACK 'ul')"
		printf "Custom: %s %s\n" "$(Cake_Get_CustomOpts 'dl')" "$(Cake_Get_CustomOpts 'ul')"
	;;	
	*)
		Print_Output "false" "Usage;" "$WARN"
		printf '\n%-32s |  %-55s\n' "cake-qos start" "start $SCRIPT_NAME"
		printf '%-32s |  %-55s\n\n' "cake-qos stop" "stop $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos status download" "check the current download status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos status upload" "check the current upload status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n\n' "cake-qos status general" "check the current general status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos settings dlspeed xxx" "configure download speed setting for $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos settings upspeed xxx" "configure upload speed setting for $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos settings queueprio xxx" "configure queue priority setting for $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos settings optionsdl xxx" "configure download options setting for $SCRIPT_NAME"
		printf '%-32s |  %-55s\n\n' "cake-qos settings optionsup xxx" "configure upload options setting for $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos install" "install and configure $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos uninstall" "uninstall and remove all traces of $SCRIPT_NAME"
	;;
esac
