#!/bin/sh
# CakeQOS-Merlin - port for Merlin firmware supported routers
# Site: https://github.com/ttgapers/cakeqos-merlin
# Thread: https://www.snbforums.com/threads/release-cakeqos-merlin.64800/
# Credits: robcore, Odkrys, ttgapers, jackiechun, maghuro, Adamm, Jack Yaz, dave14305

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

version=2.0.0
readonly SCRIPT_NAME="cake-qos"
readonly SCRIPT_NAME_FANCY="CakeQOS-Merlin"
readonly SCRIPT_BRANCH="alpha"
readonly SCRIPT_DIR="/jffs/addons/${SCRIPT_NAME}"
readonly SCRIPT_REMOTEDIR="https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/${SCRIPT_BRANCH}"

readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"

# shellcheck disable=SC1091
. /usr/sbin/helper.sh

# Update version number in custom_settings.txt for reading in WebUI
if [ "$(am_settings_get cakeqos_ver)" != "$version" ]; then
	am_settings_set cakeqos_ver "$version"
fi

# Detect if script is run from an SSH shell interactively or being invoked via cron or from the WebUI (unattended)
if tty >/dev/null 2>&1; then
	mode="interactive"
else
	mode="unattended"
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
	DLIF="$(am_settings_get cakeqos_dlif)"
	[ -z "$DLIF" ] && DLIF="0"
	case $DLIF in
		1) printf "%s\n" "$(nvram get lan_ifname)" ;;
		*) printf "%s\n" "$(get_wanif)" ;;
	esac
}

# Cake_Get_Overhead(){
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
DLOPTIONS="ingress $(Cake_Get_FlowIso 'dl') $(Cake_Get_NAT 'dl') $(Cake_Get_Wash 'dl') $(Cake_Get_ACK 'dl') $(Cake_Get_CustomOpts 'dl')"
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

Cake_GetStatus(){
	STATS_TIME="$(/bin/date +%s)"
	STATS_UPLOAD="$(tc -s -j qdisc show dev ${iface} root 2>/dev/null)"
	STATS_DOWNLOAD="$(tc -s -j qdisc show dev ifb4${iface} root 2>/dev/null)"
	STATS_UPLOAD="${STATS_UPLOAD#[}"; STATS_UPLOAD="${STATS_UPLOAD%]}"
	STATS_DOWNLOAD="${STATS_DOWNLOAD#[}"; STATS_DOWNLOAD="${STATS_DOWNLOAD%]}"
	[ -z "$STATS_UPLOAD" ] && STATS_UPLOAD='{}'
	[ -z "$STATS_DOWNLOAD" ] && STATS_DOWNLOAD='{}'
	printf "var cake_upload_stats=%s;\nvar cake_download_stats=%s;\nvar cake_statstime=%d;\n" "$STATS_UPLOAD" "$STATS_DOWNLOAD" "$STATS_TIME" > /www/ext/${SCRIPT_NAME}/cake_status.js
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

Cake_Mount_UI(){
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
	[ ! -d "/www/ext/${SCRIPT_NAME}" ] && mkdir -p "/www/ext/${SCRIPT_NAME}"
}

Init_UserScript() {
	# Properly setup an empty Merlin user script
	if [ -z "$1" ]; then
		return
	fi
	userscript="/jffs/scripts/$1"
	if [ ! -f "$userscript" ]; then
		# If script doesn't exist yet, create with shebang
		printf "#!/bin/sh\n\n" > "$userscript"
	elif [ -f "$userscript" ] && ! head -1 "$userscript" | /bin/grep -qE "^#!/bin/sh"; then
		#  Script exists but no shebang, so insert it at line 1
		sed -i '1s~^~#!/bin/sh\n~' "$userscript"
	elif [ "$(tail -c1 "$userscript" | wc -l)" = "0" ]; then
		# Script exists with shebang, but no linefeed before EOF; makes appending content unpredictable if missing
		printf "\n" >> "$userscript"
	fi
	if [ ! -x "$userscript" ]; then
		# Ensure script is executable by owner
		chmod 755 "$userscript"
	fi
	unset userscript
} # Init_UserScript

Cake_Install(){
	if ! nvram get rc_support | /bin/grep -q "cake"; then
		Print_Output "false" "This version of the script is not compatible with your router firmware version. Installing legacy version 1.0.7!" "$WARN"
		curl -fsL --retry 3 --connect-timeout 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/384/cake-qos.sh" -o "$0" && exec sh "$0" install
		exit 1
	fi
	if [ "$(nvram get jffs2_scripts)" != "1" ]; then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output "true" "Custom JFFS scripts enabled" "$WARN"
	fi

	# Add to service-event
	Init_UserScript "service-event"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event
	echo "[ \"\$2\" = \"qos\" ] && ${SCRIPT_DIR}/${SCRIPT_NAME} config # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event

	# Add to service-event-end
	Init_UserScript "service-event-end"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event-end
	echo "if echo \"\$2\" | /bin/grep -q \"^${SCRIPT_NAME}\"; then { sh ${SCRIPT_DIR}/${SCRIPT_NAME} \"\${2#${SCRIPT_NAME}}\" & } ; fi # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event-end
	echo "[ \"\$2\" = \"qos\" ] && ${SCRIPT_DIR}/${SCRIPT_NAME} statsupdate # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event-end

	# Add to services-start
	Init_UserScript "services-start"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/services-start
	echo "sh ${SCRIPT_DIR}/${SCRIPT_NAME} mountui # $SCRIPT_NAME_FANCY" >> /jffs/scripts/services-start

	if [ ! -L "/opt/bin/${SCRIPT_NAME}" ] || [ "$(readlink /opt/bin/${SCRIPT_NAME})" != "${SCRIPT_DIR}/${SCRIPT_NAME}" ]; then
		rm -rf /opt/bin/${SCRIPT_NAME}
		ln -s "${SCRIPT_DIR}/${SCRIPT_NAME}" "/opt/bin/${SCRIPT_NAME}"
	fi
	Download_File "${SCRIPT_NAME}.asp" "${SCRIPT_DIR}/${SCRIPT_NAME}.asp"
	Cake_Mount_UI
	Print_Output "false" "Customize Cake in the WebUI under Adaptive QoS / $SCRIPT_NAME_FANCY" "$PASS"
}

Cake_Uninstall(){
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
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event /jffs/scripts/service-event-end /jffs/scripts/services-start #/jffs/scripts/qos-start
	sed -i "/^cakeqos_/d" /jffs/addons/custom_settings.txt
	rm -rf "/opt/bin/${SCRIPT_NAME}" "${SCRIPT_DIR}" "/www/ext/${SCRIPT_NAME}" /jffs/configs/cake-qos.conf.add 2>/dev/null
}

compare_remote_version() {
	# Check version on Github and determine the difference with the installed version
	# Outcomes: Version update, Hotfix (w/o version change), or no update
	# Fetch version of the shell script on Github
	remotever="$(curl -fsN --retry 3 --connect-timeout 3 "${SCRIPT_REMOTEDIR}/${SCRIPT_NAME}.sh" | /bin/grep "^version=" | sed -e 's/version=//')"
	if [ "$(echo $version | sed 's/[^0-9]*//g')" -lt "$(echo $remotever | sed 's/[^0-9]*//g')" ]; then		# strip the . from version string for numeric comparison
		# version upgrade
		echo "$remotever"
	else
		# If no version change, calculate md5sum of local and remote files
		# to determine if a hotfix has been published
		localmd5="$(md5sum "$0" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 3 --connect-timeout 3 "${SCRIPT_REMOTEDIR}/${SCRIPT_NAME}.sh" | md5sum | awk '{print $1}')"
		localmd5asp="$(md5sum "${SCRIPT_DIR}/${SCRIPT_NAME}.asp" | awk '{print $1}')"
		remotemd5asp="$(curl -fsL --retry 3 --connect-timeout 3 "${SCRIPT_REMOTEDIR}/${SCRIPT_NAME}.asp" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ] || [ "$localmd5asp" != "$remotemd5asp" ]; then
			# hotfix
			printf "Hotfix\n"
		else
			printf "NoUpdate\n"
		fi
	fi
} # compare_remote_version

Cake_Update(){
	# Check for, and optionally apply updates.
	# Parameter options: check (do not update), silent (update without prompting)
	printf "Checking for updates\n"
	# Update the webui status thorugh detect_update.js ajax call.
	printf "var verUpdateStatus = \"%s\";\n" "InProgress" > /www/ext/${SCRIPT_NAME}/detect_update.js
	updatestatus="$(compare_remote_version)"
	# Check to make sure we got back a valid status from compare_remote_version(). If not, indicate Error.
	case "$updatestatus" in
		'NoUpdate'|'Hotfix'|[0-9].[0-9].[0-9]) ;;
		*) updatestatus="Error"
	esac
	printf "var verUpdateStatus = \"%s\";\n" "$updatestatus" > /www/ext/${SCRIPT_NAME}/detect_update.js

	if [ "$1" = "check" ]; then
		# Do not proceed with any updating if check function requested
		return
	fi
	if [ "$mode" = "interactive" ] && [ -z "$1" ]; then
		case "$updatestatus" in
		'NoUpdate')
			printf " You have the latest version installed\n"
			printf " Would you like to overwrite your existing installation anyway? [1=Yes 2=No]: "
			;;
		'Hotfix')
			printf " %s hotfix is available.\n" "$SCRIPT_NAME_FANCY"
			printf " Would you like to update now? [1=Yes 2=No]: "
			;;
		'Error')
			printf " Error determining remote version status!\n"
			return
			;;
		*)
			# New Version Number
			printf " %s v%s is now available!\n" "$SCRIPT_NAME_FANCY" "$updatestatus"
			printf " Would you like to update now? [1=Yes 2=No]: "
			;;
		esac
		read -r yn
		printf "\n"
		if [ "$yn" != "1" ]; then
			printf " No Changes have been made\n"
			return 0
		fi
	fi
	printf "Installing: %s...\n\n" "$SCRIPT_NAME_FANCY"
	Download_File "${SCRIPT_NAME}.sh" "$0"
	Download_File "${SCRIPT_NAME}.asp" "${SCRIPT_DIR}/${SCRIPT_NAME}.asp"
	exec sh "$0" install
	exit
}

arg1="$1"
iface="$(get_wanif)"

case "$arg1" in
	config)
		Cake_Write_QOS
	;;
	init)
		#Nothing to do yet. Future enhancements
	;;
	mountui)
		Cake_Mount_UI
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
				*)
					Print_Output "false" "> Download Status:" "$PASS"
					echo "$STATUS_DOWNLOAD"
					echo
					Print_Output "false" "> Upload Status:" "$PASS"
					echo "$STATUS_UPLOAD"
				;;
			esac
		else
			Print_Output "false" "Not running..." "$WARN"
		fi
	;;
	update*)		# updatecheck, updatesilent, or plain update
		Cake_Update "${arg1#update}"		# strip 'update' from arg1 to pass to update function
		;;
	install)
		Cake_Install
		printf "Restarting QoS..."
		service restart_qos
	;;
	uninstall)
		Cake_Uninstall
		service restart_qos
		echo
		exit 0
	;;
	debug)
#		printf "DLIF: %s\n" "$(Cake_Get_DLIF)"
#		printf "Overhead: %s\n" "$(Cake_Get_Overhead)"
		printf "Prio: %s %s\n" "$(Cake_Get_Prio 'dl')" "$(Cake_Get_Prio 'ul')"
		printf "Flow Iso: %s %s\n" "$(Cake_Get_FlowIso 'dl')" "$(Cake_Get_FlowIso 'ul')"
		printf "NAT: %s %s\n" "$(Cake_Get_NAT 'dl')" "$(Cake_Get_NAT 'ul')"
		printf "Wash: %s %s\n" "$(Cake_Get_Wash 'dl')" "$(Cake_Get_Wash 'ul')"
		printf "ACK: %s %s\n" "$(Cake_Get_ACK 'dl')" "$(Cake_Get_ACK 'ul')"
		printf "Custom: %s %s\n" "$(Cake_Get_CustomOpts 'dl')" "$(Cake_Get_CustomOpts 'ul')"
	;;	
	statsupdate)
		Cake_GetStatus
	;;
	*)
		Print_Output "false" "Usage;" "$WARN"
		printf '\n%-32s |  %-55s\n' "cake-qos status download" "check the current download status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos status upload" "check the current upload status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n\n' "cake-qos status" "check the current general status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos install" "install and configure $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos uninstall" "uninstall and remove all traces of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos update" "check for updates of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos debug" "show debug info from $SCRIPT_NAME"
	;;
esac
