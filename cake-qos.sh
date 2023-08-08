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
##                        v2.1.1                       ##
##                                                     ##
#########################################################

# shellcheck disable=SC2086

version=2.1.2
readonly SCRIPT_NAME="cake-qos"
readonly SCRIPT_NAME_FANCY="CakeQOS-Merlin"
readonly SCRIPT_BRANCH="master"
readonly SCRIPT_DIR="/jffs/addons/${SCRIPT_NAME}"
readonly SCRIPT_REMOTEDIR="https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/${SCRIPT_BRANCH}"
IPv6_enabled="$(nvram get ipv6_service)"

#readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"

[ -z "$(nvram get odmpid)" ] && RMODEL=$(nvram get productid) || RMODEL=$(nvram get odmpid) #get router model

# shellcheck disable=SC1091
. /usr/sbin/helper.sh

# Update version number in custom_settings.txt for reading in WebUI
if [ "$(am_settings_get cakeqos_ver)" != "$version" ]; then
	am_settings_set cakeqos_ver "$version"
fi

# Detect if script is run from an SSH shell interactively or being invoked via cron or from the WebUI (unattended)
if tty >/dev/null 2>&1; then
	mode="interactive"
	clear
	sed -n '6,21p' "$0"
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
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "9" ]; then
		logger -t "$SCRIPT_NAME_FANCY" "Cake QoS not enabled in firmware. Skipping configuration."
		return 1
	fi
	logger -t "$SCRIPT_NAME_FANCY" "Configuring Cake options..."

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
			Print_Output "false" "Downloaded $(echo "$1" | awk -F / '{print $NF}')" "$PASS"
		else
			Print_Output "false" "Downloading $(echo "$1" | awk -F / '{print $NF}') Failed" "$ERR"
			return 1
		fi
	else
		return 1
	fi
}

Cake_Mount_UI(){
	# Check if the webpage is already mounted in the GUI and reuse that page
	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	/usr/bin/flock -x "$FD"
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPT_NAME_FANCY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "$prev_webui_page" ]; then
		# use the same filename as before
		am_webui_page="$prev_webui_page"
	else
		# get a new mountpoint
		am_get_webui_page "${SCRIPT_DIR}/${SCRIPT_NAME}.asp"
	fi
	if [ "$am_webui_page" = "none" ]; then
		Print_Output "true" "No API slots available to install web page"
	else
		cp -p "${SCRIPT_DIR}/${SCRIPT_NAME}.asp" /www/user/"$am_webui_page"
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
	fi
	/usr/bin/flock -u "$FD"
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
		if nvram get buildno | /bin/grep -q "^386"; then
			Print_Output "false" "This version of the script is not compatible with your router firmware version. Installing legacy version 1.0.8!" "$WARN"
			curl -fsL --retry 3 --connect-timeout 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/386/cake-qos.sh" -o "$0" && exec sh "$0" install
			exit 1
		else
			Print_Output "false" "This version of the script is not compatible with your router firmware version. Installing legacy version 1.0.7!" "$WARN"
			curl -fsL --retry 3 --connect-timeout 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/384/cake-qos.sh" -o "$0" && exec sh "$0" install
			exit 1
		fi
	fi
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "9" ]; then
		Print_Output "true" "Enable Cake QoS scheduler in the firmware..." "$PASS"
		tc qdisc del dev eth0 root 2>/dev/null
		tc qdisc del dev br0 root 2>/dev/null
		nvram set qos_enable=1
		nvram set qos_type=9
		nvram set fc_disable=0
		nvram set runner_disable=0
		if [ "$RMODEL" = "RT-AX58U" ] || [ "$RMODEL" = "RT-AX3000" ]; then
			fc config --hw-accel 0
		else
			runner disable 2>/dev/null
		fi
		fc disable 2>/dev/null
		fc flush 2>/dev/null
		if [ -z "$(nvram get qos_ibw)" ]; then
			Print_Output "true" "Download bandwidth not set, setting to Automatic..." "$PASS"
			nvram set qos_ibw=0;
		fi
		if [ -z "$(nvram get qos_obw)" ]; then
			Print_Output "true" "Upload bandwidth not set, setting to Automatic..." "$PASS"
			nvram set qos_obw=0;
		fi
		nvram commit
	fi
	if [ "$(nvram get jffs2_scripts)" != "1" ]; then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output "true" "Custom JFFS scripts enabled" "$WARN"
	fi

	# Remove old Cake packages
	if [ -f /opt/lib/modules/sch_cake.ko ]; then
		Print_Output "true" "Removing old CakeQOS-Merlin 1.0 packages and modifications" "$WARN"
		oldiface="$(nvram get wan0_ifname)"
		cru d "$SCRIPT_NAME_FANCY"
		sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/nat-start /jffs/scripts/services-stop
		/opt/sbin/tc qdisc del dev ${oldiface} ingress 2>/dev/null
		/opt/sbin/tc qdisc del dev ifb9${oldiface} root 2>/dev/null
		/opt/sbin/tc qdisc del dev ${oldiface} root 2>/dev/null
		ip link del ifb9${oldiface} 2>/dev/null
		rmmod sch_cake 2>/dev/null
		opkg --autoremove remove sched-cake-oot
		opkg --autoremove remove tc-adv
		rm "${SCRIPT_DIR}/${SCRIPT_NAME}.cfg" 2>/dev/null
	fi

	Print_Output "false" "Installing CakeQOS-Merlin $version..." "$PASS"
	# Add to service-event
	Init_UserScript "service-event"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event
	echo "[ \"\$2\" = \"qos\" ] && ${SCRIPT_DIR}/${SCRIPT_NAME} config # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event

	# Add to service-event-end
	Init_UserScript "service-event-end"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event-end
	echo "if echo \"\$2\" | /bin/grep -q \"^${cakeqos}\"; then { sh ${SCRIPT_DIR}/${SCRIPT_NAME} \"\${2#${cakeqos}}\" & } ; fi # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event-end
	echo "[ \"\$2\" = \"qos\" ] && ${SCRIPT_DIR}/${SCRIPT_NAME} statsupdate # $SCRIPT_NAME_FANCY" >> /jffs/scripts/service-event-end

	# Add to services-start
	Init_UserScript "services-start"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/services-start
	echo "sh ${SCRIPT_DIR}/${SCRIPT_NAME} mountui # $SCRIPT_NAME_FANCY" >> /jffs/scripts/services-start

	# Add to firewall-start
	Init_UserScript "firewall-start"
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/firewall-start
	echo "sh ${SCRIPT_DIR}/${SCRIPT_NAME} startup # $SCRIPT_NAME_FANCY" >> /jffs/scripts/firewall-start

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
	sed -i '\~# CakeQOS-Merlin~d' /jffs/scripts/service-event /jffs/scripts/service-event-end /jffs/scripts/services-start /jffs/scripts/firewall-start #/jffs/scripts/qos-start
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

Display_Line(){
	printf '\n#########################################################\n\n'
}

Is_Valid_CIDR() {
	/bin/grep -qE '^[!]?([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'
} # Is_Valid_CIDR

Is_Valid_Port() {
	/bin/grep -qE '^[!]?([0-9]{1,5})((:[0-9]{1,5})?|(,[0-9]{1,5})*)$'
} # Is_Valid_Port

get_tin_dscp() {
	case "${1}" in
		0) printf "%s\n" "CS1"  ;;  # Bulk
		1) printf "%s\n" "AF31" ;;  # Streaming
		2) printf "%s\n" "EF"   ;;  # Voice
		3) printf "%s\n" "AF41" ;;  # Conferencing
		4) printf "%s\n" "CS4"  ;;  # Gaming
		*) printf "%s\n" "CS0"  ;;  # Other
	esac
}

apply_iptablesrule() {
	# Process an iptables custom rule into the appropriate iptables syntax
	# Input: $1 = local IP (e.g. 192.168.1.100 !192.168.1.100 192.168.1.100/31 !192.168.1.100/31)
	#        $2 = remote IP (e.g. 9.9.9.9 !9.9.9.9 9.9.9.0/24 !9.9.9.0/24)
	#        $3 = protocol (e.g. both, tcp, or udp)
	#        $4 = local port (e.g. 443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853)
	#        $5 = remote port (e.g. 443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853)
	#        $6 = CAKE tin (e.g. 0-7)
	tmp_OLDIFS="$IFS"
	IFS="$OLDIFS"
	# local IP
	# Check for acceptable IP format
	if echo "${1}" | Is_Valid_CIDR; then
		# print ! (if present) and remaining CIDR
		UP_Lip="$(echo "${1}" | sed -E 's/^([!])?/\1 -s /')"
	else
		UP_Lip=""
	fi

	# remote IP
	# Check for acceptable IP format
	if echo "${2}" | Is_Valid_CIDR; then
		# print ! (if present) and remaining CIDR
		UP_Rip="$(echo "${2}" | sed -E 's/^([!])?/\1 -d /')"
	else
		UP_Rip=""
	fi

	# protocol (required when port specified)
	if [ "${3}" = "tcp" ] || [ "${3}" = "udp" ]; then
		# print protocol directly
		PROTOS="${3}"
	elif [ "${#4}" -gt "1" ] || [ "${#5}" -gt "1" ]; then
		# proto=both & ports are defined
		PROTOS="tcp udp"		# separated by > because IFS will be temporarily set to '>' by calling function. TODO Fix Me
	else
		# neither proto nor ports defined
		PROTOS="all"
	fi

	# local port
	if echo "${4}" | Is_Valid_Port; then
		# Use multiport to specify any port specification:
		# single port, multiple ports, port range
		UP_Lport="-m multiport $(echo "${4}" | sed -E 's/^([!])?/\1 --sports /')"
	else
		UP_Lport=""
	fi

	# remote port
	if echo "${5}" | Is_Valid_Port; then
		# Use multiport to specify any port specification:
		# single port, multiple ports, port range
		UP_Rport="-m multiport $(echo "${5}" | sed -E 's/^([!])?/\1 --dports /')"
	else
		UP_Rport=""
	fi

	# if all parameters are empty stop processing the rule
	if [ -z "${UP_Lip}${UP_Rip}${UP_Lport}${UP_Rport}" ]; then
		return
	fi

	# destination tin
	# numbers come from webui select options for Tin field
	Dst_tin="$(get_tin_dscp "${6}")"
	if [ -z "${Dst_tin}" ]; then
		return
	fi
	UP_dst="-j DSCP --set-dscp-class ${Dst_tin}"

	# This block is redirected to the /tmp/cake-qos_iprules file, so no extraneous output, please
	# If proto=both we have to create 2 statements, one for tcp and one for udp.
	for proto in ${PROTOS}; do
		# upload ipv4
		iptables -t mangle -A "${SCRIPT_NAME_FANCY}" -o "${iface}" ${UP_Lip} ${UP_Rip} -p ${proto} ${UP_Lport} ${UP_Rport} ${UP_dst}
		# If rule contains no IPv4 local or remote addresses, and IPv6 is enabled, add a corresponding rule for IPv6
		if [ "${IPv6_enabled}" != "disabled" ] && [ -z "${UP_Lip}" ] && [ -z "${UP_Rip}" ]; then
			# upload ipv6
			ip6tables -t mangle -A "${SCRIPT_NAME_FANCY}" -o "${iface}" -p ${proto} ${UP_Lport} ${UP_Rport} ${UP_dst}
		fi
	done
	IFS="$tmp_OLDIFS"
} # apply_iptablesrule

startup() {
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "9" ]; then
		Print_Output "true" "Cake QoS is not enabled. Skipping ${SCRIPT_NAME_FANCY} startup."
		return 1
	fi # Cake qos not enabled

	Check_Lock
	# Read settings from Addon API config file.
	if [ "$(am_settings_get cakeqos_ulrules)" = "1" ]; then
		iptables_rules="$(am_settings_get cakeqos_iptables)"
		# Only apply iptables rules if user defined any
		if [ -n "${iptables_rules}" ]; then
			Print_Output "true" "Applying iptables rules"
			iptables -t mangle -N "${SCRIPT_NAME_FANCY}" 2>/dev/null
			if ! iptables -t mangle -C POSTROUTING -j "${SCRIPT_NAME_FANCY}" 2>/dev/null; then
				iptables -t mangle -A POSTROUTING -j "${SCRIPT_NAME_FANCY}"
			fi
			if [ "${IPv6_enabled}" != "disabled" ]; then
				ip6tables -t mangle -N "${SCRIPT_NAME_FANCY}" 2>/dev/null
				if ! ip6tables -t mangle -C POSTROUTING -j "${SCRIPT_NAME_FANCY}" 2>/dev/null; then
					ip6tables -t mangle -A POSTROUTING -j "${SCRIPT_NAME_FANCY}"
				fi
			fi
			iptables -t mangle -F "${SCRIPT_NAME_FANCY}" 2>/dev/null
			if [ "${IPv6_enabled}" != "disabled" ]; then
				ip6tables -t mangle -F "${SCRIPT_NAME_FANCY}" 2>/dev/null
			fi
			# loop through iptables rules and write an iptables command to a temporary file for later execution
			OLDIFS="${IFS}"		# Save existing field separator
			IFS=">"				# Set custom field separator to match rule format
			# read the rules, 1 per line and break into separate fields
			echo "${iptables_rules}" | sed 's/</\n/g' | while read -r localip remoteip proto lport rport tin
			do
				# Ensure at least one criteria field is populated
				if [ -n "${localip}${remoteip}${proto}${lport}${rport}" ]; then
					# Process the rule and the stdout containing the resulting rule gets saved to the temporary script file
					apply_iptablesrule "${localip}" "${remoteip}" "${proto}" "${lport}" "${rport}" "${tin}"
				fi
			done
			IFS="${OLDIFS}"		# Restore saved field separator
			# Flush conntrack table so that existing connections will be processed by new iptables rules
			Print_Output "true" "Flushing conntrack table"
			/usr/sbin/conntrack -F conntrack >/dev/null 2>&1
		fi
	fi
} # startup

Kill_Lock() {
	if [ -f "/tmp/${SCRIPT_NAME}.lock" ] && [ -d "/proc/$(sed -n '1p' "/tmp/${SCRIPT_NAME}.lock")" ]; then
		logmsg "[*] Killing Running Process (pid=$(sed -n '1p' "/tmp/${SCRIPT_NAME}.lock"))"
		logmsg "[*] $(ps | awk -v pid="$(sed -n '1p' "/tmp/${SCRIPT_NAME}.lock")" '$1 == pid')"
		kill "$(sed -n '1p' "/tmp/${SCRIPT_NAME}.lock")"
	fi
	rm -rf "/tmp/${SCRIPT_NAME}.lock"
} # Kill_Lock

Check_Lock() {
	if [ -f "/tmp/${SCRIPT_NAME}.lock" ] && [ -d "/proc/$(sed -n '1p' "/tmp/${SCRIPT_NAME}.lock")" ] && [ "$(sed -n '1p' "/tmp/${SCRIPT_NAME}.lock")" != "$$" ]; then
		Kill_Lock
	fi
	printf "%s\n" "$$" > "/tmp/${SCRIPT_NAME}.lock"
	lock="true"
} # Check_Lock

Cake_Menu(){
	reloadmenu="1"
	echo "Select an option"
	echo "[1]  --> Check cake status"
	echo "[2]  --> Update $SCRIPT_NAME_FANCY"
	echo "[3]  --> Install $SCRIPT_NAME_FANCY"
	echo "[4]  --> Uninstall $SCRIPT_NAME_FANCY"
	echo "[5]  --> Debug info"
	echo
	echo "[e]  --> Exit"
	echo
	Display_Line
	while true; do
		echo
		printf "[1-5]: "
		read -r "menu1"
		echo
		case "$menu1" in
			1)
				option1="status"
				while true; do
					echo "Select Status Option:"
					echo "[1]  --> Download Status"
					echo "[2]  --> Upload Status"
					echo "[3]  --> General Status"
					echo
					echo "[e]  --> Exit"
					echo
					printf "[1-3]: "
					read -r "menu2"
					echo
					case "$menu2" in
						1)
							option2="download"
							break
						;;
						2)
							option2="upload"
							break
						;;
						3)
							option2="general"
							break
						;;
						e|exit|back|menu)
							unset "option1" "option2"
							clear
							Cake_Menu
							break
						;;
					esac
				done
				break
			;;
			2)
				option1="updatecheck"
				break
			;;
			3)
				option1="install"
				break
			;;
			4)
				option1="uninstall"
				break
			;;
			5)
				option1="debug"
				break
			;;
			e)
				echo "Exiting!"
				echo
				exit 0
			;;
			*)
				echo "$menu1 Isn't An Option!"
				echo
			;;
		esac
	done
}

if [ -z "$1" ]; then
	Cake_Menu
fi

if [ -n "$option1" ]; then
	set "$option1" "$option2"
	echo "[$] $0 $*" | tr -s " "
fi

arg1="$1"

Display_Line

iface="$(get_wanif)"

case "$arg1" in
	config)
		Cake_Write_QOS
	;;
	startup)
		Print_Output "true" "$0 (pid=$$) called in ${mode} mode with $# args: $*"
		startup
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
					tc -s qdisc show dev ${iface} root
				;;
				general)
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
	install|start)		# start is used to upgrade v1.0.x users from nat-start invocation
		Cake_Install
		printf "Restarting QoS..."
		service "restart_qos;restart_firewall"
	;;
	uninstall)
		Cake_Uninstall
		service "restart_qos;restart_firewall"
		echo
		exit 0
	;;
	debug)
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
		printf '%-32s |  %-55s\n\n' "cake-qos status general" "check the current general status of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos install" "install and configure $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos uninstall" "uninstall and remove all traces of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos update" "check for updates of $SCRIPT_NAME"
		printf '%-32s |  %-55s\n' "cake-qos debug" "show debug info from $SCRIPT_NAME"
	;;
esac
Display_Line
if [ -n "$reloadmenu" ]; then echo; printf "[*] Press Enter To Continue..."; read -r "reloadmenu"; exec "$0"; fi
if [ "${lock}" = "true" ]; then rm -rf "/tmp/${SCRIPT_NAME}.lock"; fi
