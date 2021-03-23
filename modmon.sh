#!/bin/sh

#########################################################
##                        _                            ##
##                       | |                           ##
##  _ __ ___    ___    __| | _ __ ___    ___   _ __    ##
## | '_ ` _ \  / _ \  / _` || '_ ` _ \  / _ \ | '_ \   ##
## | | | | | || (_) || (_| || | | | | || (_) || | | |  ##
## |_| |_| |_| \___/  \__,_||_| |_| |_| \___/ |_| |_|  ##
##                                                     ##
##         https://github.com/jackyaz/modmon           ##
##                                                     ##
#########################################################

#############        Shellcheck directives      #########
# shellcheck disable=SC2018
# shellcheck disable=SC2019
# shellcheck disable=SC2059
#########################################################

### Start of script variables ###
readonly SCRIPT_NAME="modmon"
readonly SCRIPT_VERSION="v1.1.3"
SCRIPT_BRANCH="master"
SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/jackyaz/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL=$(nvram get productid) || ROUTER_MODEL=$(nvram get odmpid)
[ -f /opt/bin/sqlite3 ] && SQLITE3_PATH=/opt/bin/sqlite3 || SQLITE3_PATH=/usr/sbin/sqlite3
### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
readonly SETTING="\\e[1m\\e[36m"
### End of output format variables ###

# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME" "$2"
	fi
	printf "\\e[1m${3}%s\\e[0m\\n\\n" "$2"
}

Firmware_Version_Check(){
	if nvram get rc_support | grep -qF "am_addons"; then
		return 0
	else
		return 1
	fi
}

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock(){
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]; then
		ageoflock=$(($(date +%s) - $(date +%s -r /tmp/$SCRIPT_NAME.lock)))
		if [ "$ageoflock" -gt 600 ]; then
			Print_Output true "Stale lock file found (>600 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' /tmp/$SCRIPT_NAME.lock)" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output true "Lock file found (age: $ageoflock seconds) - cable modem stat generation likely in progress" "$ERR"
			if [ -z "$1" ]; then
				exit 1
			else
				return 1
			fi
		fi
	else
		echo "$$" > "/tmp/$SCRIPT_NAME.lock"
		return 0
	fi
}

Clear_Lock(){
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}

############################################################################

Set_Version_Custom_Settings(){
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	case "$1" in
		local)
			if [ -f "$SETTINGSFILE" ]; then
				if [ "$(grep -c "modmon_version_local" $SETTINGSFILE)" -gt 0 ]; then
					if [ "$2" != "$(grep "modmon_version_local" /jffs/addons/custom_settings.txt | cut -f2 -d' ')" ]; then
						sed -i "s/modmon_version_local.*/modmon_version_local $2/" "$SETTINGSFILE"
					fi
				else
					echo "modmon_version_local $2" >> "$SETTINGSFILE"
				fi
			else
				echo "modmon_version_local $2" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -f "$SETTINGSFILE" ]; then
				if [ "$(grep -c "modmon_version_server" $SETTINGSFILE)" -gt 0 ]; then
					if [ "$2" != "$(grep "modmon_version_server" /jffs/addons/custom_settings.txt | cut -f2 -d' ')" ]; then
						sed -i "s/modmon_version_server.*/modmon_version_server $2/" "$SETTINGSFILE"
					fi
				else
					echo "modmon_version_server $2" >> "$SETTINGSFILE"
				fi
			else
				echo "modmon_version_server $2" >> "$SETTINGSFILE"
			fi
		;;
	esac
}

Update_Check(){
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localver=$(grep "SCRIPT_VERSION=" "/jffs/scripts/$SCRIPT_NAME" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
	/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || { Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
	if [ "$localver" != "$serverver" ]; then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]; then
			doupdate="md5"
			Set_Version_Custom_Settings server "$serverver-hotfix"
			echo 'var updatestatus = "'"$serverver-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localver,$serverver"
}

Update_Version(){
	if [ -z "$1" ]; then
		updatecheckresult="$(Update_Check)"
		isupdate="$(echo "$updatecheckresult" | cut -f1 -d',')"
		localver="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverver="$(echo "$updatecheckresult" | cut -f3 -d',')"
		
		if [ "$isupdate" = "version" ]; then
			Print_Output true "New version of $SCRIPT_NAME available - $serverver" "$PASS"
		elif [ "$isupdate" = "md5" ]; then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - hotfix available - $serverver" "$PASS"
		fi
		
		if [ "$isupdate" != "false" ]; then
			printf "\\n\\e[1mDo you want to continue with the update? (y/n)\\e[0m  "
			read -r confirm
			case "$confirm" in
				y|Y)
					printf "\\n"
					Update_File shared-jy.tar.gz
					Update_File modmonstats_www.asp
					/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" -o "/jffs/scripts/$SCRIPT_NAME" && Print_Output true "$SCRIPT_NAME successfully updated"
					chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
					Set_Version_Custom_Settings local "$serverver"
					Set_Version_Custom_Settings server "$serverver"
					Clear_Lock
					PressEnter
					exec "$0"
					exit 0
				;;
				*)
					printf "\\n"
					Clear_Lock
					return 1
				;;
			esac
		else
			Print_Output true "No updates available - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi
	
	if [ "$1" = "force" ]; then
		serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File shared-jy.tar.gz
		Update_File modmonstats_www.asp
		/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" -o "/jffs/scripts/$SCRIPT_NAME" && Print_Output true "$SCRIPT_NAME successfully updated"
		chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
		Set_Version_Custom_Settings local "$serverver"
		Set_Version_Custom_Settings server "$serverver"
		Clear_Lock
		if [ -z "$2" ]; then
			PressEnter
			exec "$0"
		elif [ "$2" = "unattended" ]; then
			exec "$0" postupdate
		fi
		exit 0
	fi
}

Update_File(){
	if [ "$1" = "modmonstats_www.asp" ]; then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "shared-jy.tar.gz" ]; then
		if [ ! -f "$SHARED_DIR/$1.md5" ]; then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/$1.md5")"
			remotemd5="$(curl -fsL --retry 3 "$SHARED_REPO/$1.md5")"
			if [ "$localmd5" != "$remotemd5" ]; then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	else
		return 1
	fi
}

Validate_Number(){
	if [ "$1" -eq "$1" ] 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

Conf_FromSettings(){
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/modmon_settings.txt"
	if [ -f "$SETTINGSFILE" ]; then
		if [ "$(grep "modmon_" $SETTINGSFILE | grep -v "version" -c)" -gt 0 ]; then
			Print_Output true "Updated settings from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "$SCRIPT_CONF.bak"
			grep "modmon_" "$SETTINGSFILE" | grep -v "version" > "$TMPFILE"
			sed -i "s/modmon_//g;s/ /=/g" "$TMPFILE"
			while IFS='' read -r line || [ -n "$line" ]; do
				SETTINGNAME="$(echo "$line" | cut -f1 -d'=' | awk '{ print toupper($1) }')"
				SETTINGVALUE="$(echo "$line" | cut -f2 -d'=')"
				sed -i "s/$SETTINGNAME=.*/$SETTINGNAME=$SETTINGVALUE/" "$SCRIPT_CONF"
			done < "$TMPFILE"
			grep 'modmon_version' "$SETTINGSFILE" > "$TMPFILE"
			sed -i "\\~modmon_~d" "$SETTINGSFILE"
			mv "$SETTINGSFILE" "$SETTINGSFILE.bak"
			cat "$SETTINGSFILE.bak" "$TMPFILE" > "$SETTINGSFILE"
			rm -f "$TMPFILE"
			rm -f "$SETTINGSFILE.bak"
			
			ScriptStorageLocation "$(ScriptStorageLocation check)"
			Create_Symlinks
			
			Generate_CSVs
			
			Print_Output true "Merge of updated settings from WebUI completed successfully" "$PASS"
		else
			Print_Output false "No updated settings from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
	fi
}

Create_Dirs(){
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
	fi
	
	if [ ! -d "$SCRIPT_STORAGE_DIR" ]; then
		mkdir -p "$SCRIPT_STORAGE_DIR"
	fi
	
	if [ ! -d "$CSV_OUTPUT_DIR" ]; then
		mkdir -p "$CSV_OUTPUT_DIR"
	fi
	
	if [ ! -d "$SHARED_DIR" ]; then
		mkdir -p "$SHARED_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi
}

Create_Symlinks(){
	rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null
	
	ln -s /tmp/detect_modmon.js "$SCRIPT_WEB_DIR/detect_modmon.js" 2>/dev/null
	ln -s "$SCRIPT_STORAGE_DIR/modlogs.js"  "$SCRIPT_WEB_DIR/modlogs.js" 2>/dev/null
	ln -s "$SCRIPT_STORAGE_DIR/modstatstext.js" "$SCRIPT_WEB_DIR/modstatstext.js" 2>/dev/null
	
	ln -s "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/config.htm" 2>/dev/null
	
	ln -s "$CSV_OUTPUT_DIR" "$SCRIPT_WEB_DIR/csv" 2>/dev/null
	
	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

Conf_Exists(){
	if [ -f "$SCRIPT_CONF" ]; then
		dos2unix "$SCRIPT_CONF"
		chmod 0644 "$SCRIPT_CONF"
		sed -i -e 's/"//g' "$SCRIPT_CONF"
		if [ "$(wc -l < "$SCRIPT_CONF")" -eq 2 ]; then
			echo "STORAGELOCATION=jffs" >> "$SCRIPT_CONF"
		fi
		if [ "$(wc -l < "$SCRIPT_CONF")" -eq 3 ]; then
			echo "FIXTXPWR=false" >> "$SCRIPT_CONF"
		fi
		return 0
	else
		{ echo "OUTPUTDATAMODE=average"; echo "OUTPUTTIMEMODE=unix"; echo "STORAGELOCATION=jffs"; echo "FIXTXPWR=false"; } > "$SCRIPT_CONF"
		return 1
	fi
}

Auto_ServiceEvent(){
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				# shellcheck disable=SC2016
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME service_event"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					# shellcheck disable=SC2016
					echo "/jffs/scripts/$SCRIPT_NAME service_event"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/service-event
				echo "" >> /jffs/scripts/service-event
				# shellcheck disable=SC2016
				echo "/jffs/scripts/$SCRIPT_NAME service_event"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}

Auto_Startup(){
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -f /jffs/scripts/post-mount ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/post-mount)
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/post-mount)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/post-mount
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/post-mount
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/post-mount
				echo "" >> /jffs/scripts/post-mount
				echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/post-mount
				chmod 0755 /jffs/scripts/post-mount
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -f /jffs/scripts/post-mount ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/post-mount)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/post-mount
				fi
			fi
		;;
	esac
}

Auto_Cron(){
	case $1 in
		create)
			STARTUPLINECOUNT=$(cru l | grep -c "$SCRIPT_NAME")
			
			if [ "$STARTUPLINECOUNT" -eq 0 ]; then
				cru a "$SCRIPT_NAME" "16,46 * * * * /jffs/scripts/$SCRIPT_NAME generate"
			fi
		;;
		delete)
			STARTUPLINECOUNT=$(cru l | grep -c "$SCRIPT_NAME")
			
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "$SCRIPT_NAME"
			fi
		;;
	esac
}

Download_File(){
	/usr/sbin/curl -fsL --retry 3 "$1" -o "$2"
}

Get_WebUI_Page(){
	MyPage="none"
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
		page="/www/user/user$i.asp"
		if [ -f "$page" ] && [ "$(md5sum < "$1")" = "$(md5sum < "$page")" ]; then
			MyPage="user$i.asp"
			return
		elif [ "$MyPage" = "none" ] && [ ! -f "$page" ]; then
			MyPage="user$i.asp"
		fi
	done
}

### function based on @dave14305's FlexQoS webconfigpage function ###
Get_WebUI_URL(){
	urlpage=""
	urlproto=""
	urldomain=""
	urlport=""

	urlpage="$(sed -nE "/$SCRIPT_NAME/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" /tmp/menuTree.js)"
	if [ "$(nvram get http_enable)" -eq 1 ]; then
		urlproto="https"
	else
		urlproto="http"
	fi
	if [ -n "$(nvram get lan_domain)" ]; then
		urldomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
	else
		urldomain="$(nvram get lan_ipaddr)"
	fi
	if [ "$(nvram get ${urlproto}_lanport)" -eq 80 ] || [ "$(nvram get ${urlproto}_lanport)" -eq 443 ]; then
		urlport=""
	else
		urlport=":$(nvram get ${urlproto}_lanport)"
	fi

	if echo "$urlpage" | grep -qE "user[0-9]+\.asp"; then
		echo "${urlproto}://${urldomain}${urlport}/${urlpage}" | tr "A-Z" "a-z"
	else
		echo "WebUI page not found"
	fi
}
### ###

### locking mechanism code credit to Martineau (@MartineauUK) ###
Mount_WebUI(){
	Print_Output true "Mounting WebUI tab for $SCRIPT_NAME" "$PASS"
	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/modmonstats_www.asp"
	if [ "$MyPage" = "none" ]; then
		Print_Output true "Unable to mount $SCRIPT_NAME WebUI page, exiting" "$CRIT"
		flock -u "$FD"
		return 1
	fi
	cp -f "$SCRIPT_DIR/modmonstats_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyPage"
	echo "$SCRIPT_NAME" > "$SCRIPT_WEBPAGE_DIR/$(echo $MyPage | cut -f1 -d'.').title"
	
	if [ "$(uname -o)" = "ASUSWRT-Merlin" ]; then
		if [ ! -f /tmp/index_style.css ]; then
			cp -f /www/index_style.css /tmp/
		fi
		
		if ! grep -q '.menu_Addons' /tmp/index_style.css ; then
			echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
		fi
		
		umount /www/index_style.css 2>/dev/null
		mount -o bind /tmp/index_style.css /www/index_style.css
		
		if [ ! -f /tmp/menuTree.js ]; then
			cp -f /www/require/modules/menuTree.js /tmp/
		fi
		
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		
		if ! grep -q 'menuName: "Addons"' /tmp/menuTree.js ; then
			lineinsbefore="$(( $(grep -n "exclude:" /tmp/menuTree.js | cut -f1 -d':') - 1))"
			sed -i "$lineinsbefore"'i,\n{\nmenuName: "Addons",\nindex: "menu_Addons",\ntab: [\n{url: "ext/shared-jy/redirect.htm", tabName: "Help & Support"},\n{url: "NULL", tabName: "__INHERIT__"}\n]\n}' /tmp/menuTree.js
		fi
		
		if ! grep -q "javascript:window.open('/ext/shared-jy/redirect.htm'" /tmp/menuTree.js ; then
			sed -i "s~ext/shared-jy/redirect.htm~javascript:window.open('/ext/shared-jy/redirect.htm','_blank')~" /tmp/menuTree.js
		fi
		sed -i "/url: \"javascript:window.open('\/ext\/shared-jy\/redirect.htm'/i {url: \"$MyPage\", tabName: \"$SCRIPT_NAME\"}," /tmp/menuTree.js
		umount /www/require/modules/menuTree.js 2>/dev/null
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
	fi
	flock -u "$FD"
	Print_Output true "Mounted $SCRIPT_NAME WebUI page as $MyPage" "$PASS"
}

ScriptStorageLocation(){
	case "$1" in
		usb)
			sed -i 's/^STORAGELOCATION.*$/STORAGELOCATION=usb/' "$SCRIPT_CONF"
			mkdir -p "/opt/share/$SCRIPT_NAME.d/"
			mv "/jffs/addons/$SCRIPT_NAME.d/csv" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/jffs/addons/$SCRIPT_NAME.d/config" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/jffs/addons/$SCRIPT_NAME.d/config.bak" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/jffs/addons/$SCRIPT_NAME.d/modstatstext.js" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/jffs/addons/$SCRIPT_NAME.d/modstats.db" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			SCRIPT_CONF="/opt/share/$SCRIPT_NAME.d/config"
			ScriptStorageLocation load
		;;
		jffs)
			sed -i 's/^STORAGELOCATION.*$/STORAGELOCATION=jffs/' "$SCRIPT_CONF"
			mkdir -p "/jffs/addons/$SCRIPT_NAME.d/"
			mv "/opt/share/$SCRIPT_NAME.d/csv" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/opt/share/$SCRIPT_NAME.d/config" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/opt/share/$SCRIPT_NAME.d/config.bak" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/opt/share/$SCRIPT_NAME.d/modstatstext.js" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv "/opt/share/$SCRIPT_NAME.d/modstats.db" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			SCRIPT_CONF="/jffs/addons/$SCRIPT_NAME.d/config"
			ScriptStorageLocation load
		;;
		check)
			STORAGELOCATION=$(grep "STORAGELOCATION" "$SCRIPT_CONF" | cut -f2 -d"=")
			echo "$STORAGELOCATION"
		;;
		load)
			STORAGELOCATION=$(grep "STORAGELOCATION" "$SCRIPT_CONF" | cut -f2 -d"=")
			if [ "$STORAGELOCATION" = "usb" ]; then
				SCRIPT_STORAGE_DIR="/opt/share/$SCRIPT_NAME.d"
			elif [ "$STORAGELOCATION" = "jffs" ]; then
				SCRIPT_STORAGE_DIR="/jffs/addons/$SCRIPT_NAME.d"
			fi
			
			CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"
		;;
	esac
}

OutputDataMode(){
	case "$1" in
		raw)
			sed -i 's/^OUTPUTDATAMODE.*$/OUTPUTDATAMODE=raw/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		average)
			sed -i 's/^OUTPUTDATAMODE.*$/OUTPUTDATAMODE=average/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		check)
			OUTPUTDATAMODE=$(grep "OUTPUTDATAMODE" "$SCRIPT_CONF" | cut -f2 -d"=")
			echo "$OUTPUTDATAMODE"
		;;
	esac
}

OutputTimeMode(){
	case "$1" in
		unix)
			sed -i 's/^OUTPUTTIMEMODE.*$/OUTPUTTIMEMODE=unix/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		non-unix)
			sed -i 's/^OUTPUTTIMEMODE.*$/OUTPUTTIMEMODE=non-unix/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		check)
			OUTPUTTIMEMODE=$(grep "OUTPUTTIMEMODE" "$SCRIPT_CONF" | cut -f2 -d"=")
			echo "$OUTPUTTIMEMODE"
		;;
	esac
}

FixTxPwr(){
	case "$1" in
		true)
			sed -i 's/^FIXTXPWR.*$/FIXTXPWR=true/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		false)
			sed -i 's/^FIXTXPWR.*$/FIXTXPWR=false/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		check)
			FIXTXPWR=$(grep "FIXTXPWR" "$SCRIPT_CONF" | cut -f2 -d"=")
			echo "$FIXTXPWR"
		;;
	esac
}

WritePlainData_ToJS(){
	inputfile="$1"
	outputfile="$2"
	shift;shift
	i=0
	for var in "$@"; do
		i=$((i+1))
		{
			echo "var $var;"
			echo "$var = [];"
			echo "${var}.unshift('$(awk -v i=$i '{printf t $i} {t=","}' "$inputfile" | sed "s~,~\\',\\'~g")');"
			echo
		} >> "$outputfile"
	done
	sed -i 's/@/ /g' "$outputfile"
}

WriteStats_ToJS(){
	echo "function $3(){" > "$2"
	html='document.getElementById("'"$4"'").innerHTML="'
	while IFS='' read -r line || [ -n "$line" ]; do
		html="${html}${line}\r\\n"
	done < "$1"
	html="$html"'"'
	printf "%s\\r\\n}\\r\\n" "$html" >> "$2"
}

#$1 fieldname $2 tablename $3 frequency (hours) $4 length (days) $5 outputfile $6 outputfrequency $7 sqlfile $8 timestamp
WriteSql_ToFile(){
	timenow="$8"
	maxcount="$(echo "$3" "$4" | awk '{printf ((24*$2)/$1)}')"
	multiplier="$(echo "$3" | awk '{printf (60*60*$1)}')"
	
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output ${5}${6}.htm"
	} > "$7"
	
	dividefactor=1
	if echo "$2" | grep -qF "RxPwr" || echo "$2" | grep -qF "RxSnr" ; then
		dividefactor=10
	fi
	
	if echo "$2" | grep -qF "TxPwr" && [ "$(FixTxPwr "check")" = "true" ]; then
		dividefactor=10
	fi
	
	echo "SELECT ('Ch. ' || [ChannelNum]) Channel, Min([Timestamp]) Time, IFNULL(Avg([$1])/$dividefactor,'NaN') Value FROM $2 WHERE ([Timestamp] >= $timenow - ($multiplier*$maxcount)) GROUP BY Channel,([Timestamp]/($multiplier)) ORDER BY [ChannelNum] ASC;" >> "$7"
}

Get_Modem_Stats(){
	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	
	TZ=$(cat /etc/TZ)
	export TZ
	timenow="$(date '+%s')"
	timenowfriendly="$(date +"%c")"
	shstatsfile="/tmp/shstats.csv"
	
	metriclist="RxPwr RxSnr RxPstRs TxPwr TxT3Out TxT4Out"
	
	echo 'var modmonstatus = "InProgress";' > /tmp/detect_modmon.js
	
	/usr/sbin/curl -fs --retry 3 --connect-timeout 15 "http://192.168.100.1/getRouterStatus" | sed s/1.3.6.1.2.1.10.127.1.1.1.1.6/RxPwr/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.2.1.1/TxPwr/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.2.1.2/TxT3Out/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.2.1.3/TxT4Out/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.24.1.1/RxMer/ | sed s/1.3.6.1.2.1.10.127.1.1.4.1.4/RxPstRs/ | sed s/1.3.6.1.2.1.10.127.1.1.4.1.5/RxSnr/ | sed s/1.3.6.1.2.1.69.1.5.8.1.2/DevEvFirstTimeOid/ | sed s/1.3.6.1.2.1.69.1.5.8.1.5/DevEvId/ | sed s/1.3.6.1.2.1.69.1.5.8.1.7/DevEvText/ | sed 's/"//g' | sed 's/,$//g' | sed 's/\./,/' | sed 's/:/,/' | grep "^[A-Za-z]" > "$shstatsfile"
	
	if [ "$(wc -l < "$shstatsfile" )" -gt 1 ]; then
		for metric in $metriclist; do
		{
			echo "CREATE TABLE IF NOT EXISTS [modstats_$metric] ([StatID] INTEGER PRIMARY KEY NOT NULL, [Timestamp] NUMERIC NOT NULL, [ChannelNum] INTEGER NOT NULL, [Measurement] REAL NOT NULL);" > /tmp/modmon-stats.sql
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
			rm -f /tmp/modmon-stats.sql
			
			channelcount="$(grep -c "$metric" $shstatsfile)"
			
			counter=1
			until [ $counter -gt "$channelcount" ]; do
				measurement="$(grep "$metric" $shstatsfile | sed "$counter!d" | cut -d',' -f3)"
				echo "INSERT INTO modstats_$metric ([Timestamp],[ChannelNum],[Measurement]) values($timenow,$counter,$measurement);" >> /tmp/modmon-stats.sql
				counter=$((counter + 1))
			done
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
			
			echo "DELETE FROM [modstats_$metric] WHERE [Timestamp] < ($timenow - (86400*30));" > /tmp/modmon-stats.sql
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
			rm -f /tmp/modmon-stats.sql
		}
		done
		
		Generate_CSVs
		
		logcount="$(grep -c "DevEv" $shstatsfile)"
		counter=1
		until [ $counter -gt "$logcount" ]; do
			logtime="$(grep "DevEv" $shstatsfile | sed "$counter!d" | cut -d',' -f3 | sed 's/ /@/g')"
			logprio="$(grep "DevEv" $shstatsfile | sed "$((counter+1))!d" | cut -d',' -f3 | sed 's/3/Critical/;s/4/Error/;s/5/Warning/;s/6/Notice/')"
			logmessage="$(grep "DevEv" $shstatsfile | sed "$((counter+2))!d" | cut -d',' -f3  | sed 's/ /@/g')"
			echo "$logtime $logprio $logmessage" >> /tmp/modlogs.csv
			counter=$((counter + 3))
		done
		
		rm -f "$SCRIPT_STORAGE_DIR/modlogs.js"
		WritePlainData_ToJS "/tmp/modlogs.csv" "$SCRIPT_STORAGE_DIR/modlogs.js" "DataTimestamp" "DataPrio" "DataText"
		
		rm -f /tmp/modlogs.csv
		
		echo "Stats last updated: $timenowfriendly" > "/tmp/modstatstitle.txt"
		WriteStats_ToJS /tmp/modstatstitle.txt "$SCRIPT_STORAGE_DIR/modstatstext.js" SetModStatsTitle statstitle
		Print_Output true "Cable modem stats successfully retrieved" "$PASS"
		
		echo 'var modmonstatus = "Done";' > /tmp/detect_modmon.js
		
		rm -f /tmp/modmon-stats.sql
		rm -f /tmp/modstatstitle.txt
	else
		Print_Output true "Something went wrong trying to retrieve cable modem stats" "$ERR"
	fi
	
	rm -f "$shstatsfile"
}

Generate_CSVs(){
	OUTPUTDATAMODE="$(OutputDataMode check)"
	OUTPUTTIMEMODE="$(OutputTimeMode check)"
	TZ=$(cat /etc/TZ)
	export TZ
	timenow="$(date '+%s')"
	timenowfriendly="$(date +"%c")"
	
	metriclist="RxPwr RxSnr RxPstRs TxPwr TxT3Out TxT4Out"
	
	for metric in $metriclist; do
	{
		dividefactor=1
		if echo "$metric" | grep -qF "RxPwr" || echo "$metric" | grep -qF "RxSnr" ; then
			dividefactor=10
		fi
		
		if echo "$metric" | grep -qF "TxPwr" && [ "$(FixTxPwr "check")" = "true" ]; then
			dividefactor=10
		fi
		
		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${metric}daily.htm"
			echo "SELECT ('Ch. ' || [ChannelNum]) Channel, [Timestamp] Time, ([Measurement]/$dividefactor) Value FROM modstats_$metric WHERE ([Timestamp] >= $timenow - 86400) ORDER BY [ChannelNum] ASC;"
		} > /tmp/modmon-stats.sql
		"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
		
		if [ "$OUTPUTDATAMODE" = "raw" ]; then
			{
				echo ".mode csv"
				echo ".headers on"
				echo ".output $CSV_OUTPUT_DIR/${metric}weekly.htm"
				echo "SELECT ('Ch. ' || [ChannelNum]) Channel, [Timestamp] Time, ([Measurement]/$dividefactor) Value FROM modstats_$metric WHERE [Timestamp] >= ($timenow - 86400*7) ORDER BY [ChannelNum] ASC;"
			} > /tmp/modmon-stats.sql
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
			
			{
				echo ".mode csv"
				echo ".headers on"
				echo ".output $CSV_OUTPUT_DIR/${metric}monthly.htm"
				echo "SELECT ('Ch. ' || [ChannelNum]) Channel, [Timestamp] Time, ([Measurement]/$dividefactor) Value FROM modstats_$metric WHERE [Timestamp] >= ($timenow - 86400*30) ORDER BY [ChannelNum] ASC;"
			} > /tmp/modmon-stats.sql
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
		elif [ "$OUTPUTDATAMODE" = "average" ]; then
			WriteSql_ToFile Measurement "modstats_$metric" 3 7 "$CSV_OUTPUT_DIR/$metric" weekly /tmp/modmon-stats.sql "$timenow"
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
			
			WriteSql_ToFile Measurement "modstats_$metric" 12 30 "$CSV_OUTPUT_DIR/$metric" monthly /tmp/modmon-stats.sql "$timenow"
			"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-stats.sql
		fi
	}
	done
	
	rm -f /tmp/modmon-stats.sql
	
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output /tmp/CompleteResults_RxTimes.htm"
		echo "SELECT [Timestamp] FROM modstats_RxPwr WHERE [Timestamp] >= ($timenow - 86400*30) ORDER BY [Timestamp] DESC;"
	} > /tmp/modmon-complete.sql
	"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-complete.sql
	
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output /tmp/CompleteResults_TxTimes.htm"
		echo "SELECT [Timestamp] FROM modstats_TxPwr WHERE [Timestamp] >= ($timenow - 86400*30) ORDER BY [Timestamp] DESC;"
	} > /tmp/modmon-complete.sql
	"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-complete.sql
	
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output /tmp/CompleteResults_RxChannels.htm"
		echo "SELECT ('Ch. ' || [ChannelNum]) Channel FROM modstats_RxPwr WHERE [Timestamp] >= ($timenow - 86400*30) ORDER BY [Timestamp] DESC;"
	} > /tmp/modmon-complete.sql
	"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-complete.sql
	
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output /tmp/CompleteResults_TxChannels.htm"
		echo "SELECT ('Ch. ' || [ChannelNum]) Channel FROM modstats_TxPwr WHERE [Timestamp] >= ($timenow - 86400*30) ORDER BY [Timestamp] DESC;"
	} > /tmp/modmon-complete.sql
	"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-complete.sql
	
	metriclist="RxPwr RxSnr RxPstRs TxPwr TxT3Out TxT4Out"
	for metric in $metriclist; do
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output /tmp/CompleteResults_$metric.htm"
		echo "SELECT [Measurement] $metric FROM modstats_$metric WHERE [Timestamp] >= ($timenow - 86400*30) ORDER BY [Timestamp] DESC;"
	} > /tmp/modmon-complete.sql
	"$SQLITE3_PATH" "$SCRIPT_STORAGE_DIR/modstats.db" < /tmp/modmon-complete.sql
	done
	
	rm -f /tmp/modmon-complete.sql
	
	dos2unix /tmp/*.htm
	
	if [ ! -f /opt/bin/paste ]; then
		opkg update
		opkg install coreutils-paste
	fi
	paste -d ',' /tmp/CompleteResults_RxTimes.htm /tmp/CompleteResults_RxChannels.htm /tmp/CompleteResults_RxPwr.htm /tmp/CompleteResults_RxSnr.htm /tmp/CompleteResults_RxPstRs.htm > "$CSV_OUTPUT_DIR/CompleteResults_Rx.htm"
	paste -d ',' /tmp/CompleteResults_TxTimes.htm /tmp/CompleteResults_TxChannels.htm /tmp/CompleteResults_TxPwr.htm /tmp/CompleteResults_TxT3Out.htm /tmp/CompleteResults_TxT4Out.htm > "$CSV_OUTPUT_DIR/CompleteResults_Tx.htm"
	
	rm -f /tmp/CompleteResults*.htm
	
	dos2unix "$CSV_OUTPUT_DIR/"*.htm
	
	tmpoutputdir="/tmp/${SCRIPT_NAME}results"
	mkdir -p "$tmpoutputdir"
	mv "$CSV_OUTPUT_DIR/CompleteResults"*.htm "$tmpoutputdir/."
	
	if [ "$OUTPUTTIMEMODE" = "unix" ]; then
		find "$tmpoutputdir/" -name '*.htm' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm}.csv"' _ {} \;
	elif [ "$OUTPUTTIMEMODE" = "non-unix" ]; then
		for i in "$tmpoutputdir/"*".htm"; do
			awk -F"," 'NR==1 {OFS=","; print} NR>1 {OFS=","; $1=strftime("%Y-%m-%d %H:%M:%S", $1); print }' "$i" > "$i.out"
		done
		
		find "$tmpoutputdir/" -name '*.htm.out' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm.out}.csv"' _ {} \;
		rm -f "$tmpoutputdir/"*.htm
	fi
	
	if [ ! -f /opt/bin/7za ]; then
		opkg update
		opkg install p7zip
	fi
	/opt/bin/7za a -y -bsp0 -bso0 -tzip "/tmp/${SCRIPT_NAME}data.zip" "$tmpoutputdir/*"
	mv "/tmp/${SCRIPT_NAME}data.zip" "$CSV_OUTPUT_DIR"
	rm -rf "$tmpoutputdir"
}

Shortcut_Script(){
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && [ -f "/jffs/scripts/$SCRIPT_NAME" ]; then
				ln -s "/jffs/scripts/$SCRIPT_NAME" /opt/bin
				chmod 0755 "/opt/bin/$SCRIPT_NAME"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME" ]; then
				rm -f "/opt/bin/$SCRIPT_NAME"
			fi
		;;
	esac
}

PressEnter(){
	while true; do
		printf "Press enter to continue..."
		read -r key
		case "$key" in
			*)
				break
			;;
		esac
	done
	return 0
}

ScriptHeader(){
	clear
	printf "\\n"
	printf "\\e[1m#########################################################\\e[0m\\n"
	printf "\\e[1m##                        _                            ##\\e[0m\\n"
	printf "\\e[1m##                       | |                           ##\\e[0m\\n"
	printf "\\e[1m##  _ __ ___    ___    __| | _ __ ___    ___   _ __    ##\\e[0m\\n"
	printf "\\e[1m## |  _ \` _ \  / _ \  / _\` ||  _ \` _ \  / _ \ |  _ \   ##\\e[0m\\n"
	printf "\\e[1m## | | | | | || (_) || (_| || | | | | || (_) || | | |  ##\\e[0m\\n"
	printf "\\e[1m## |_| |_| |_| \___/  \__,_||_| |_| |_| \___/ |_| |_|  ##\\e[0m\\n"
	printf "\\e[1m##                                                     ##\\e[0m\\n"
	printf "\\e[1m##                 %s on %-11s               ##\\e[0m\\n" "$SCRIPT_VERSION" "$ROUTER_MODEL"
	printf "\\e[1m##                                                     ##\\e[0m\\n"
	printf "\\e[1m##          https://github.com/jackyaz/modmon          ##\\e[0m\\n"
	printf "\\e[1m##                                                     ##\\e[0m\\n"
	printf "\\e[1m#########################################################\\e[0m\\n"
	printf "\\n"
}

MainMenu(){
	FIXTXPWR_MENU=""
	if [ "$(FixTxPwr check)" = "true" ]; then
		FIXTXPWR_MENU="Enabled"
	else
		FIXTXPWR_MENU="Disabled"
	fi
	printf "WebUI for %s is available at:\\n${SETTING}%s\\e[0m\\n\\n" "$SCRIPT_NAME" "$(Get_WebUI_URL)"
	printf "1.    Check stats now\\n\\n"
	printf "2.    Toggle data output mode\\n      Currently ${SETTING}%s\\e[0m values will be used for weekly and monthly charts\\n\\n" "$(OutputDataMode check)"
	printf "3.    Toggle time output mode\\n      Currently ${SETTING}%s\\e[0m time values will be used for CSV exports\\n\\n" "$(OutputTimeMode check)"
	printf "s.    Toggle storage location for stats and config\\n      Current location is ${SETTING}%s\\e[0m \\n\\n" "$(ScriptStorageLocation check)"
	printf "f.    Fix Upstream Power level reporting (reduce by 10x, needed in newer Hub 3 firmware)\\n      Currently: ${SETTING}%s\\e[0m \\n\\n" "$FIXTXPWR_MENU"
	printf "u.    Check for updates\\n"
	printf "uf.   Update %s with latest version (force update)\\n\\n" "$SCRIPT_NAME"
	printf "e.    Exit %s\\n\\n" "$SCRIPT_NAME"
	printf "z.    Uninstall %s\\n" "$SCRIPT_NAME"
	printf "\\n"
	printf "\\e[1m#########################################################\\e[0m\\n"
	printf "\\n"
	
	while true; do
		printf "Choose an option:  "
		read -r menu
		case "$menu" in
			1)
				printf "\\n"
				if Check_Lock menu; then
					Get_Modem_Stats
					Clear_Lock
				fi
				PressEnter
				break
			;;
			2)
				printf "\\n"
				if [ "$(OutputDataMode check)" = "raw" ]; then
					OutputDataMode average
				elif [ "$(OutputDataMode check)" = "average" ]; then
					OutputDataMode raw
				fi
				break
			;;
			3)
				printf "\\n"
				if [ "$(OutputTimeMode check)" = "unix" ]; then
					OutputTimeMode non-unix
				elif [ "$(OutputTimeMode check)" = "non-unix" ]; then
					OutputTimeMode unix
				fi
				break
			;;
			s)
				printf "\\n"
				if [ "$(ScriptStorageLocation check)" = "jffs" ]; then
					ScriptStorageLocation usb
					Create_Symlinks
				elif [ "$(ScriptStorageLocation check)" = "usb" ]; then
					ScriptStorageLocation jffs
					Create_Symlinks
				fi
				break
			;;
			f)
				printf "\\n"
				if [ "$(FixTxPwr check)" = "true" ]; then
					FixTxPwr false
				elif [ "$(FixTxPwr check)" = "false" ]; then
					FixTxPwr true
				fi
				break
			;;
			u)
				printf "\\n"
				if Check_Lock menu; then
					Update_Version
					Clear_Lock
				fi
				PressEnter
				break
			;;
			uf)
				printf "\\n"
				if Check_Lock menu; then
					Update_Version force
					Clear_Lock
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader
				printf "\\n\\e[1mThanks for using %s!\\e[0m\\n\\n\\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true; do
					printf "\\n\\e[1mAre you sure you want to uninstall %s? (y/n)\\e[0m  " "$SCRIPT_NAME"
					read -r confirm
					case "$confirm" in
						y|Y)
							Menu_Uninstall
							exit 0
						;;
						*)
							break
						;;
					esac
				done
			;;
			*)
				printf "\\nPlease choose a valid option\\n\\n"
			;;
		esac
	done
	
	ScriptHeader
	MainMenu
}

Check_Requirements(){
	CHECKSFAILED="false"
	
	if [ "$(nvram get jffs2_scripts)" -ne 1 ]; then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output false "Custom JFFS Scripts enabled" "$WARN"
	fi
	
	/usr/sbin/curl -fsL --retry 3 "http://192.168.100.1/getRouterStatus" >/dev/null || { Print_Output false "Cable modem not compatible - error detected when trying to access cable modem's stats" "$ERR"; CHECKSFAILED="true"; }
	
	if [ ! -f /opt/bin/opkg ]; then
		Print_Output false "Entware not detected!" "$ERR"
		CHECKSFAILED="true"
	fi
	
	if ! Firmware_Version_Check; then
		Print_Output false "Unsupported firmware version detected" "$ERR"
		Print_Output false "$SCRIPT_NAME requires Merlin 384.15/384.13_4 or Fork 43E5 (or later)" "$ERR"
		CHECKSFAILED="true"
	fi
		
	if [ "$CHECKSFAILED" = "false" ]; then
		Print_Output false "Installing required packages from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
		opkg install p7zip
		opkg install coreutils-paste
		return 0
	else
		return 1
	fi
}

Menu_Install(){
	Print_Output true "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by JackYaz"
	sleep 1
	
	Print_Output false "Checking your router meets the requirements for $SCRIPT_NAME"
	
	if ! Check_Requirements; then
		Print_Output false "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
		exit 1
	fi
	
	Create_Dirs
	Conf_Exists
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Set_Version_Custom_Settings server "$SCRIPT_VERSION"
	ScriptStorageLocation load
	Create_Symlinks
	
	Update_File modmonstats_www.asp
	Update_File shared-jy.tar.gz
	
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	
	Clear_Lock
}

Menu_Startup(){
	if [ -z "$1" ]; then
		Print_Output true "Missing argument for startup, not starting $SCRIPT_NAME" "$WARN"
		exit 1
	elif [ "$1" != "force" ]; then
		if [ ! -f "$1/entware/bin/opkg" ]; then
			Print_Output true "$1 does not contain Entware, not starting $SCRIPT_NAME" "$WARN"
			exit 1
		else
			Print_Output true "$1 contains Entware, starting $SCRIPT_NAME" "$WARN"
		fi
	fi
	
	NTP_Ready
	
	Check_Lock
	
	if [ "$1" != "force" ]; then
		sleep 10
	fi
	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	Mount_WebUI
	Clear_Lock
}

Menu_Uninstall(){
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_Cron delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Shortcut_Script delete
	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/modmonstats_www.asp"
	if [ -n "$MyPage" ] && [ "$MyPage" != "none" ] && [ -f "/tmp/menuTree.js" ]; then
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		umount /www/require/modules/menuTree.js
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		rm -rf "{$SCRIPT_WEBPAGE_DIR:?}/$MyPage"
	fi
	flock -u "$FD"
	rm -f "$SCRIPT_DIR/modmonstats_www.asp" 2>/dev/null
	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	printf "\\n\\e[1mDo you want to delete %s stats? (y/n)\\e[0m  " "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			rm -rf "$SCRIPT_DIR" 2>/dev/null
			rm -rf "$SCRIPT_STORAGE_DIR" 2>/dev/null
		;;
		*)
			:
		;;
	esac
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	sed -i '/modmon_version_local/d' "$SETTINGSFILE"
	sed -i '/modmon_version_server/d' "$SETTINGSFILE"
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"
}

NTP_Ready(){
	if [ "$(nvram get ntp_ready)" -eq 0 ]; then
		ntpwaitcount=0
		Check_Lock
		while [ "$(nvram get ntp_ready)" -eq 0 ] && [ "$ntpwaitcount" -lt 600 ]; do
			ntpwaitcount="$((ntpwaitcount + 30))"
			Print_Output true "Waiting for NTP to sync..." "$WARN"
			sleep 30
		done
		if [ "$ntpwaitcount" -ge 600 ]; then
			Print_Output true "NTP failed to sync after 10 minutes. Please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "NTP synced, $SCRIPT_NAME will now continue" "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @Adamm00's Skynet USB wait function ###
Entware_Ready(){
	if [ ! -f /opt/bin/opkg ]; then
		Check_Lock
		sleepcount=1
		while [ ! -f /opt/bin/opkg ] && [ "$sleepcount" -le 10 ]; do
			Print_Output true "Entware not found, sleeping for 10s (attempt $sleepcount of 10)" "$ERR"
			sleepcount="$((sleepcount + 1))"
			sleep 10
		done
		if [ ! -f /opt/bin/opkg ]; then
			Print_Output true "Entware not found and is required for $SCRIPT_NAME to run, please resolve" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "Entware found, $SCRIPT_NAME will now continue" "$PASS"
			Clear_Lock
		fi
	fi
}
### ###

### function based on @dave14305's FlexQoS about function ###
Show_About(){
	cat <<EOF
About
  $SCRIPT_NAME is a tool that tracks your cable modem's stats
  (such as signal power levels) for AsusWRT Merlin with charts
  for daily, weekly and monthly summaries.
License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0
Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=21
Source code
  https://github.com/jackyaz/$SCRIPT_NAME
EOF
	printf "\\n"
}
### ###

### function based on @dave14305's FlexQoS show_help function ###
Show_Help(){
	cat <<EOF
Available commands:
  $SCRIPT_NAME about              explains functionality
  $SCRIPT_NAME update             checks for updates
  $SCRIPT_NAME forceupdate        updates to latest version (force update)
  $SCRIPT_NAME startup force      runs startup actions such as mount WebUI tab
  $SCRIPT_NAME install            installs script
  $SCRIPT_NAME uninstall          uninstalls script
  $SCRIPT_NAME generate           get modem stats and logs. also runs outputcsv
  $SCRIPT_NAME outputcsv          create CSVs from database, used by WebUI and export
  $SCRIPT_NAME develop            switch to development branch
  $SCRIPT_NAME stable             switch to stable branch
EOF
	printf "\\n"
}
### ###

if [ -f "/opt/share/$SCRIPT_NAME.d/config" ]; then
	SCRIPT_CONF="/opt/share/$SCRIPT_NAME.d/config"
	SCRIPT_STORAGE_DIR="/opt/share/$SCRIPT_NAME.d"
else
	SCRIPT_CONF="/jffs/addons/$SCRIPT_NAME.d/config"
	SCRIPT_STORAGE_DIR="/jffs/addons/$SCRIPT_NAME.d"
fi

CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"

if [ -z "$1" ]; then
	NTP_Ready
	Entware_Ready
	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	ScriptHeader
	MainMenu
	exit 0
fi

case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	startup)
		Menu_Startup "$2"
		exit 0
	;;
	generate)
		NTP_Ready
		Entware_Ready
		Check_Lock
		Get_Modem_Stats
		Clear_Lock
		exit 0
	;;
	outputcsv)
		NTP_Ready
		Entware_Ready
		Check_Lock
		Generate_CSVs
		Clear_Lock
		exit 0
	;;
	service_event)
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME" ]; then
			Check_Lock
			Get_Modem_Stats
			Clear_Lock
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}config" ]; then
			Conf_FromSettings
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}checkupdate" ]; then
			Update_Check
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}doupdate" ]; then
			Update_Version force unattended
			exit 0
		fi
		exit 0
	;;
	update)
		Update_Version
		exit 0
	;;
	forceupdate)
		Update_Version force
		exit 0
	;;
	setversion)
		Create_Dirs
		Conf_Exists
		ScriptStorageLocation load
		Create_Symlinks
		Auto_Startup create 2>/dev/null
		Auto_Cron create 2>/dev/null
		Auto_ServiceEvent create 2>/dev/null
		Shortcut_Script create
		Set_Version_Custom_Settings local "$SCRIPT_VERSION"
		Set_Version_Custom_Settings server "$SCRIPT_VERSION"
		exit 0
	;;
	postupdate)
		Create_Dirs
		Conf_Exists
		ScriptStorageLocation load
		Create_Symlinks
		Auto_Startup create 2>/dev/null
		Auto_Cron create 2>/dev/null
		Auto_ServiceEvent create 2>/dev/null
		Shortcut_Script create
		exit 0
	;;
	checkupdate)
		Update_Check
		exit 0
	;;
	uninstall)
		Check_Lock
		Menu_Uninstall
		exit 0
	;;
	develop)
		SCRIPT_BRANCH="develop"
		SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	stable)
		SCRIPT_BRANCH="master"
		SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	about)
		ScriptHeader
		Show_About
		exit 0
	;;
	help)
		ScriptHeader
		Show_Help
		exit 0
	;;
	*)
		ScriptHeader
		Print_Output false "Command not recognised." "$ERR"
		Print_Output false "For a list of available commands run: $SCRIPT_NAME help"
		exit 1
	;;
esac
