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

### Start of script variables ###
readonly SCRIPT_NAME="modmon"
readonly SCRIPT_VERSION="v0.9.9"
readonly SCRIPT_BRANCH="master"
readonly SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/""$SCRIPT_NAME""/""$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/jackyaz/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
readonly CSV_OUTPUT_DIR="$SCRIPT_DIR/csv"
[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL=$(nvram get productid) || ROUTER_MODEL=$(nvram get odmpid)
[ -f /opt/bin/sqlite3 ] && SQLITE3_PATH=/opt/bin/sqlite3 || SQLITE3_PATH=/usr/sbin/sqlite3
### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
### End of output format variables ###

# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME" "$2"
		printf "\\e[1m$3%s: $2\\e[0m\\n\\n" "$SCRIPT_NAME"
	else
		printf "\\e[1m$3%s: $2\\e[0m\\n\\n" "$SCRIPT_NAME"
	fi
}

Firmware_Version_Check(){
	if [ "$1" = "install" ]; then
		if [ "$(uname -o)" = "ASUSWRT-Merlin" ] && [ "$(nvram get buildno | tr -d '.')" -ge "38415" ]; then
			return 0
		elif [ "$(uname -o)" = "ASUSWRT-Merlin" ] && nvram get rc_support | grep -qF "am_addons"; then
			return 0
		else
			return 1
		fi
	elif [ "$1" = "webui" ]; then
		if nvram get rc_support | grep -qF "am_addons"; then
			return 0
		else
			return 1
		fi
	fi
}

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock(){
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]; then
		ageoflock=$(($(date +%s) - $(date +%s -r /tmp/$SCRIPT_NAME.lock)))
		if [ "$ageoflock" -gt 60 ]; then
			Print_Output "true" "Stale lock file found (>60 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' /tmp/$SCRIPT_NAME.lock)" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output "true" "Lock file found (age: $ageoflock seconds) - modem stat generation likely in progress" "$ERR"
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

Update_Version(){
	if [ -z "$1" ]; then
		doupdate="false"
		localver=$(grep "SCRIPT_VERSION=" /jffs/scripts/"$SCRIPT_NAME" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
		/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || { Print_Output "true" "404 error detected - stopping update" "$ERR"; return 1; }
		serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
		if [ "$localver" != "$serverver" ]; then
			doupdate="version"
		else
			localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
			remotemd5="$(curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
			if [ "$localmd5" != "$remotemd5" ]; then
				doupdate="md5"
			fi
		fi
		
		if [ "$doupdate" = "version" ]; then
			Print_Output "true" "New version of $SCRIPT_NAME available - updating to $serverver" "$PASS"
		elif [ "$doupdate" = "md5" ]; then
			Print_Output "true" "MD5 hash of $SCRIPT_NAME does not match - downloading updated $serverver" "$PASS"
		fi
		
		Update_File "modmonstats_www.asp"
		Update_File "redirect.htm"
		Update_File "addons.png"
		Update_File "chart.js"
		Update_File "chartjs-plugin-zoom.js"
		Update_File "chartjs-plugin-annotation.js"
		Update_File "chartjs-plugin-datasource.js"
		Update_File "hammerjs.js"
		Update_File "moment.js"
		
		if [ "$doupdate" != "false" ]; then
			/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" -o "/jffs/scripts/$SCRIPT_NAME" && Print_Output "true" "$SCRIPT_NAME successfully updated"
			chmod 0755 /jffs/scripts/"$SCRIPT_NAME"
			Clear_Lock
			exit 0
		else
			Print_Output "true" "No new version - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi
	
	case "$1" in
		force)
			serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
			Print_Output "true" "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
			Update_File "modmonstats_www.asp"
			Update_File "redirect.htm"
			Update_File "addons.png"
			Update_File "chart.js"
			Update_File "chartjs-plugin-zoom.js"
			Update_File "chartjs-plugin-annotation.js"
			Update_File "chartjs-plugin-datasource.js"
			Update_File "hammerjs.js"
			Update_File "moment.js"
			/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" -o "/jffs/scripts/$SCRIPT_NAME" && Print_Output "true" "$SCRIPT_NAME successfully updated"
			chmod 0755 /jffs/scripts/"$SCRIPT_NAME"
			Clear_Lock
			exit 0
		;;
	esac
}
############################################################################

Update_File(){
	if [ "$1" = "modmonstats_www.asp" ]; then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			Print_Output "true" "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "chart.js" ] || [ "$1" = "chartjs-plugin-zoom.js" ] || [ "$1" = "chartjs-plugin-annotation.js" ] || [ "$1" = "moment.js" ] || [ "$1" =  "hammerjs.js" ] || [ "$1" = "chartjs-plugin-datasource.js" ] || [ "$1" = "redirect.htm" ] || [ "$1" = "addons.png" ]; then
		tmpfile="/tmp/$1"
		Download_File "$SHARED_REPO/$1" "$tmpfile"
		if [ ! -f "$SHARED_DIR/$1" ]; then
			touch "$SHARED_DIR/$1"
		fi
		if ! diff -q "$tmpfile" "$SHARED_DIR/$1" >/dev/null 2>&1; then
			Print_Output "true" "New version of $1 downloaded" "$PASS"
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
		fi
		rm -f "$tmpfile"
	else
		return 1
	fi
}

Validate_Number(){
	if [ "$2" -eq "$2" ] 2>/dev/null; then
		return 0
	else
		formatted="$(echo "$1" | sed -e 's/|/ /g')"
		if [ -z "$3" ]; then
			Print_Output "false" "$formatted - $2 is not a number" "$ERR"
		fi
		return 1
	fi
}

Validate_IP(){
	if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
		for i in 1 2 3 4; do
			if [ "$(echo "$1" | cut -d. -f$i)" -gt 255 ]; then
				Print_Output "false" "Octet $i ($(echo "$1" | cut -d. -f$i)) - is invalid, must be less than 255" "$ERR"
				return 1
			fi
		done
	else
		Print_Output "false" "$1 - is not a valid IPv4 address, valid format is 1.2.3.4" "$ERR"
		return 1
	fi
}


Create_Dirs(){
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
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
	
	if [ ! -d "$SHARED_WEB_DIR" ]; then
		mkdir -p "$SHARED_WEB_DIR"
	fi
}

Create_Symlinks(){
	rm -f "$SCRIPT_WEB_DIR/"* 2>/dev/null
	rm -f "$SHARED_WEB_DIR/"* 2>/dev/null
	
	ln -s "$SCRIPT_DIR/modstatsdata.js" "$SCRIPT_WEB_DIR/modstatsdata.js" 2>/dev/null
	ln -s "$SCRIPT_DIR/modstatstext.js" "$SCRIPT_WEB_DIR/modstatstext.js" 2>/dev/null
	ln -s "$CSV_OUTPUT_DIR" "$SCRIPT_WEB_DIR/csv" 2>/dev/null
	
	ln -s "$SHARED_DIR/chart.js" "$SHARED_WEB_DIR/chart.js" 2>/dev/null
	ln -s "$SHARED_DIR/chartjs-plugin-zoom.js" "$SHARED_WEB_DIR/chartjs-plugin-zoom.js" 2>/dev/null
	ln -s "$SHARED_DIR/chartjs-plugin-annotation.js" "$SHARED_WEB_DIR/chartjs-plugin-annotation.js" 2>/dev/null
	ln -s "$SHARED_DIR/chartjs-plugin-datasource.js" "$SHARED_WEB_DIR/chartjs-plugin-datasource.js" 2>/dev/null
	ln -s "$SHARED_DIR/hammerjs.js" "$SHARED_WEB_DIR/hammerjs.js" 2>/dev/null
	ln -s "$SHARED_DIR/moment.js" "$SHARED_WEB_DIR/moment.js" 2>/dev/null
	ln -s "$SHARED_DIR/redirect.htm" "$SHARED_WEB_DIR/redirect.htm" 2>/dev/null
	ln -s "$SHARED_DIR/addons.png" "$SHARED_WEB_DIR/addons.png" 2>/dev/null
}
	
Auto_ServiceEvent(){
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				# shellcheck disable=SC2016
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME generate"' "$1" "$2" &'' # '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					# shellcheck disable=SC2016
					echo "/jffs/scripts/$SCRIPT_NAME generate"' "$1" "$2" &'' # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/service-event
				echo "" >> /jffs/scripts/service-event
				# shellcheck disable=SC2016
				echo "/jffs/scripts/$SCRIPT_NAME generate"' "$1" "$2" &'' # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
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
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME startup"' # '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/scripts/$SCRIPT_NAME startup"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/services-start
				echo "" >> /jffs/scripts/services-start
				echo "/jffs/scripts/$SCRIPT_NAME startup"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				chmod 0755 /jffs/scripts/services-start
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
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

Get_WebUI_Page () {
	for i in 1 2 3 4 5 6 7 8 9 10; do
		page="$SCRIPT_WEBPAGE_DIR/user$i.asp"
		if [ ! -f "$page" ] || [ "$(md5sum < "$1")" = "$(md5sum < "$page")" ]; then
			MyPage="user$i.asp"
			return
		fi
	done
	MyPage="none"
}

Mount_WebUI(){
	Get_WebUI_Page "$SCRIPT_DIR/modmonstats_www.asp"
	if [ "$MyPage" = "none" ]; then
		Print_Output "true" "Unable to mount $SCRIPT_NAME WebUI page, exiting" "$CRIT"
		exit 1
	fi
	Print_Output "true" "Mounting $SCRIPT_NAME WebUI page as $MyPage" "$PASS"
	cp -f "$SCRIPT_DIR/modmonstats_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyPage"
	
	if [ ! -f "/tmp/index_style.css" ]; then
		cp -f "/www/index_style.css" "/tmp/"
	fi
	
	if ! grep -q '.menu_Addons' /tmp/index_style.css ; then
		echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
	fi
	
	umount /www/index_style.css 2>/dev/null
	mount -o bind /tmp/index_style.css /www/index_style.css
	
	if [ ! -f "/tmp/menuTree.js" ]; then
		cp -f "/www/require/modules/menuTree.js" "/tmp/"
	fi
	
	sed -i "\\~$MyPage~d" /tmp/menuTree.js
	
	if ! grep -q 'menuName: "Addons"' /tmp/menuTree.js ; then
		lineinsbefore="$(( $(grep -n "exclude:" /tmp/menuTree.js | cut -f1 -d':') - 1))"
		sed -i "$lineinsbefore"'i,\n{\nmenuName: "Addons",\nindex: "menu_Addons",\ntab: [\n{url: "ext/shared-jy/redirect.htm", tabName: "Help & Support"},\n{url: "NULL", tabName: "__INHERIT__"}\n]\n}' /tmp/menuTree.js
	fi
	
	if ! grep -q "javascript:window.open('/ext/shared-jy/redirect.htm'" /tmp/menuTree.js ; then
		sed -i "s~ext/shared-jy/redirect.htm~javascript:window.open('/ext/shared-jy/redirect.htm','_blank')~" /tmp/menuTree.js
	fi
	sed -i "/url: \"javascript:window.open('\/ext\/shared-jy\/redirect.htm'/i {url: \"$MyPage\", tabName: \"Modem Monitoring\"}," /tmp/menuTree.js
	umount /www/require/modules/menuTree.js 2>/dev/null
	mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
}

WriteData_ToJS(){
	metricarray="$1"
	inputfile="$2"
	outputfile="$3"
	shift;shift;shift
	
	for var in "$@"; do
	{
		echo "var $var;"
		echo "$var = [];"; } >> "$outputfile"
		contents="$var"'.unshift('
		while IFS='' read -r line || [ -n "$line" ]; do
			if echo "$line" | grep -q "NaN"; then continue; fi
			datapoint="{ x: moment.unix(""$(echo "$line" | awk 'BEGIN{FS=","}{ print $1 }' | awk '{$1=$1};1')""), y: ""$(echo "$line" | awk 'BEGIN{FS=","}{ print $2 }' | awk '{$1=$1};1')"" }"
			contents="$contents""$datapoint"","
		done < "$inputfile"
		contents=$(echo "$contents" | sed 's/,$//')
		contents="$contents"");"
		printf "%s\\r\\n" "$contents" >> "$outputfile"
		printf "%s.push(%s);\\r\\n\\r\\n" "$metricarray" "$var" >> "$outputfile"
	done
}

WriteStats_ToJS(){
	echo "function $3(){" > "$2"
	html='document.getElementById("'"$4"'").innerHTML="'
	while IFS='' read -r line || [ -n "$line" ]; do
		html="$html""$line""\\r\\n"
	done < "$1"
	html="$html"'"'
	printf "%s\\r\\n}\\r\\n" "$html" >> "$2"
}

#$1 fieldname $2 tablename $3 frequency (hours) $4 length (days) $5 outputfile $6 outputfrequency $7 sqlfile $8 timestamp
WriteSql_ToFile(){
	timenow="$8"
	earliest="$((24*$4/$3))"
	{
		echo ".mode list"
		echo "select count(distinct ChannelNum) from modstats_$metric WHERE [Timestamp] >= ($timenow - ((60*60*$3)*$earliest));"
	} > "$7"
	
	channelcount="$("$SQLITE3_PATH" "$SCRIPT_DIR/modstats.db" < "$7")"
	rm -f "$7"
	
	{
		echo ".mode csv"
		echo ".output $5$6.tmp"
	} >> "$7"
	
	dividefactor=1
	if echo "$2" | grep -qF "RxPwr" || echo "$2" | grep -qF "RxSnr" ; then
		dividefactor=10
	fi
	
	channelcounter=1
	until [ $channelcounter -gt "$channelcount" ]; do
		{
			echo "SELECT 'Ch. ' || [ChannelNum],Min([Timestamp]) ChunkStart, IFNULL(Avg([Measurement])/$dividefactor,'NaN') Value FROM"
			echo "( SELECT NTILE($((24*$4/$3))) OVER (ORDER BY [Timestamp]) Chunk, * FROM $2 WHERE [Timestamp] >= ($timenow - ((60*60*$3)*$earliest)) AND [ChannelNum] = $channelcounter ) AS T"
			echo "GROUP BY Chunk"
			echo "ORDER BY ChunkStart;"
		} >> "$7"
		channelcounter=$((channelcounter + 1))
	done
	echo "var $metric$6""size = $channelcount;" >> "$SCRIPT_DIR/modstatsdata.js"
}

Aggregate_Stats(){
	metricname="$1"
	period="$2"
	sed -i '1iChannelNum,Time,Value' "$CSV_OUTPUT_DIR/$metricname$period.tmp"
	head -c -2 "$CSV_OUTPUT_DIR/$metricname$period.tmp" > "$CSV_OUTPUT_DIR/$metricname$period.htm"
	dos2unix "$CSV_OUTPUT_DIR/$metricname$period.htm"
	cp "$CSV_OUTPUT_DIR/$metricname$period.htm" "$CSV_OUTPUT_DIR/$metricname$period.tmp"
	sed -i '1d' "$CSV_OUTPUT_DIR/$metricname$period.tmp"
	min="$(cut -f3 -d"," "$CSV_OUTPUT_DIR/$metricname$period.tmp" | sort -n | head -1)"
	max="$(cut -f3 -d"," "$CSV_OUTPUT_DIR/$metricname$period.tmp" | sort -n | tail -1)"
	avg="$(cut -f3 -d"," "$CSV_OUTPUT_DIR/$metricname$period.tmp" | sort -n | awk '{ total += $1; count++ } END { print total/count }')"
	{
	echo "var $metricname$period""min = $min;"
	echo "var $metricname$period""max = $max;"
	echo "var $metricname$period""avg = $avg;"
	} >> "$SCRIPT_DIR/modstatsdata.js"
}

Generate_Stats(){
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Create_Dirs
	Create_Symlinks
	
	TZ=$(cat /etc/TZ)
	export TZ
	timestamp="$(date '+%s')"
	timetitle="$(date +"%c")"
	shstatsfile="/tmp/shstats.csv"
	
	metriclist="RxPwr RxSnr RxPstRs TxPwr TxT3Out TxT4Out"
	
	/usr/sbin/curl -fs --retry 3 --connect-timeout 15 "http://192.168.100.1/getRouterStatus" | sed s/1.3.6.1.2.1.10.127.1.1.1.1.6/RxPwr/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.2.1.1/TxPwr/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.2.1.2/TxT3Out/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.2.1.3/TxT4Out/ | sed s/1.3.6.1.4.1.4491.2.1.20.1.24.1.1/RxMer/ | sed s/1.3.6.1.2.1.10.127.1.1.4.1.4/RxPstRs/ | sed s/1.3.6.1.2.1.10.127.1.1.4.1.5/RxSnr/ | sed s/1.3.6.1.2.1.69.1.5.8.1.2/DevEvFirstTimeOid/ | sed s/1.3.6.1.2.1.69.1.5.8.1.5/DevEvId/ | sed s/1.3.6.1.2.1.69.1.5.8.1.7/DevEvText/ | sed 's/"//g' | sed 's/,$//g' | sed 's/\./,/' | sed 's/:/,/' | grep "^[A-Za-z]" > "$shstatsfile"
	
	if [ "$(wc -l < /tmp/shstats.csv )" -gt 1 ]; then
		rm -f "$SCRIPT_DIR/modstatsdata.js"
		rm -f "$CSV_OUTPUT_DIR/"*
		rm -f /tmp/modmon-stats.sql
		
		for metric in $metriclist; do
		{
			echo "CREATE TABLE IF NOT EXISTS [modstats_$metric] ([StatID] INTEGER PRIMARY KEY NOT NULL, [Timestamp] NUMERIC NOT NULL, [ChannelNum] INTEGER NOT NULL, [Measurement] REAL NOT NULL);" >> /tmp/modmon-stats.sql
			
			channelcount="$(grep -c "$metric" $shstatsfile)"
			
			counter=1
			until [ $counter -gt "$channelcount" ]; do
				measurement="$(grep "$metric" $shstatsfile | sed "$counter!d" | cut -d',' -f3)"
				echo "INSERT INTO modstats_$metric ([Timestamp],[ChannelNum],[Measurement]) values($timestamp,$counter,$measurement);" >> /tmp/modmon-stats.sql
				counter=$((counter + 1))
			done
			"$SQLITE3_PATH" "$SCRIPT_DIR/modstats.db" < /tmp/modmon-stats.sql
			rm -f /tmp/modmon-stats.sql
		}
		done
		
		for metric in $metriclist; do
		{
			{
				echo ".mode list"
				echo "select count(distinct ChannelNum) from modstats_$metric WHERE [Timestamp] >= ($timestamp - 86400);"
			} > /tmp/modmon-stats.sql
			
			channelcount="$("$SQLITE3_PATH" "$SCRIPT_DIR/modstats.db" < /tmp/modmon-stats.sql)"
			rm -f /tmp/modmon-stats.sql
			
			{
				echo ".mode csv"
				echo ".output $CSV_OUTPUT_DIR/$metric""daily.tmp"
			} > /tmp/modmon-stats.sql
			
			dividefactor=1
			if echo "$metric" | grep -qF "RxPwr" || echo "$metric" | grep -qF "RxSnr" ; then
				dividefactor=10
			fi
			
			counter=1
			until [ $counter -gt "$channelcount" ]; do
				echo "select 'Ch. ' || [ChannelNum],[Timestamp],[Measurement]/$dividefactor from modstats_$metric WHERE [Timestamp] >= ($timestamp - 86400) AND [ChannelNum] = $counter;" >> /tmp/modmon-stats.sql
				counter=$((counter + 1))
			done
			"$SQLITE3_PATH" "$SCRIPT_DIR/modstats.db" < /tmp/modmon-stats.sql
			{
			echo "var $metric""dailysize = $channelcount;"
			} >> "$SCRIPT_DIR/modstatsdata.js"
			Aggregate_Stats "$metric" "daily"
			rm -f "$CSV_OUTPUT_DIR/$metric""daily.tmp"*
			rm -f /tmp/modmon-stats.sql
			
			WriteSql_ToFile "Measurement" "modstats_$metric" 3 7 "$CSV_OUTPUT_DIR/$metric" "weekly" "/tmp/modmon-stats.sql" "$timestamp"
			"$SQLITE3_PATH" "$SCRIPT_DIR/modstats.db" < /tmp/modmon-stats.sql
			Aggregate_Stats "$metric" "weekly"
			rm -f "$CSV_OUTPUT_DIR/$metric""weekly.tmp"
			rm -f /tmp/modmon-stats.sql
			
			WriteSql_ToFile "Measurement" "modstats_$metric" 12 30 "$CSV_OUTPUT_DIR/$metric" "monthly" "/tmp/modmon-stats.sql" "$timestamp"
			"$SQLITE3_PATH" "$SCRIPT_DIR/modstats.db" < /tmp/modmon-stats.sql
			Aggregate_Stats "$metric" "monthly"
			rm -f "$CSV_OUTPUT_DIR/$metric""monthly.tmp"
			rm -f /tmp/modmon-stats.sql
		}
		done
		
		echo "Superhub stats retrieved on $timetitle" > "/tmp/modstatstitle.txt"
		WriteStats_ToJS "/tmp/modstatstitle.txt" "$SCRIPT_DIR/modstatstext.js" "SetModStatsTitle" "statstitle"
		Print_Output "false" "Superhub stats successfully retrieved" "$PASS"
	else
		Print_Output "true" "Something went wrong trying to retrieve Superhub stats" "$ERR"
	fi
	rm -f "/tmp/modmon-stats.sql"
	rm -f "/tmp/modstatstitle.txt"
	rm -f "/tmp/modmon-"*".csv"
	rm -f "$shstatsfile"
}

Shortcut_script(){
	case $1 in
		create)
			if [ -d "/opt/bin" ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && [ -f "/jffs/scripts/$SCRIPT_NAME" ]; then
				ln -s /jffs/scripts/"$SCRIPT_NAME" /opt/bin
				chmod 0755 /opt/bin/"$SCRIPT_NAME"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME" ]; then
				rm -f /opt/bin/"$SCRIPT_NAME"
			fi
		;;
	esac
}

PressEnter(){
	while true; do
		printf "Press enter to continue..."
		read -r "key"
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
	printf "\\e[1m##                 %s on %-9s                 ##\\e[0m\\n" "$SCRIPT_VERSION" "$ROUTER_MODEL"
	printf "\\e[1m##                                                     ##\\e[0m\\n"
	printf "\\e[1m##          https://github.com/jackyaz/modmon          ##\\e[0m\\n"
	printf "\\e[1m##                                                     ##\\e[0m\\n"
	printf "\\e[1m#########################################################\\e[0m\\n"
	printf "\\n"
}

MainMenu(){
	printf "1.    Check stats now\\n\\n"
	printf "u.    Check for updates\\n"
	printf "uf.   Update %s with latest version (force update)\\n\\n" "$SCRIPT_NAME"
	printf "e.    Exit %s\\n\\n" "$SCRIPT_NAME"
	printf "z.    Uninstall %s\\n" "$SCRIPT_NAME"
	printf "\\n"
	printf "\\e[1m#########################################################\\e[0m\\n"
	printf "\\n"
	
	while true; do
		printf "Choose an option:    "
		read -r "menu"
		case "$menu" in
			1)
				printf "\\n"
				if Check_Lock "menu"; then
					Menu_GenerateStats
				fi
				PressEnter
				break
			;;
			u)
				printf "\\n"
				if Check_Lock "menu"; then
					Menu_Update
				fi
				PressEnter
				break
			;;
			uf)
				printf "\\n"
				if Check_Lock "menu"; then
					Menu_ForceUpdate
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
					printf "\\n\\e[1mAre you sure you want to uninstall %s? (y/n)\\e[0m\\n" "$SCRIPT_NAME"
					read -r "confirm"
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
		Print_Output "true" "Custom JFFS Scripts enabled" "$WARN"
	fi
	
	/usr/sbin/curl -fsL --retry 3 "http://192.168.100.1/getRouterStatus" >/dev/null || { Print_Output "true" "Modem not compatible - error detected when trying to access modem's stats" "$ERR"; CHECKSFAILED="true"; }
	
	if [ ! -f "/opt/bin/opkg" ]; then
		Print_Output "true" "Entware not detected!" "$ERR"
		CHECKSFAILED="true"
	fi
	
	if ! Firmware_Version_Check "install" ; then
		Print_Output "true" "Older Merlin firmware detected - $SCRIPT_NAME requires 384.13_4/384.15 or later" "$ERR"
		CHECKSFAILED="true"
	fi
		
	if [ "$CHECKSFAILED" = "false" ]; then
		Print_Output "true" "Installing required packages from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
		return 0
	else
		return 1
	fi
}

Menu_Install(){
	Print_Output "true" "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by JackYaz"
	sleep 1
	
	Print_Output "true" "Checking your router meets the requirements for $SCRIPT_NAME"
	
	if ! Check_Requirements; then
		Print_Output "true" "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
		exit 1
	fi
	
	Create_Dirs
	Create_Symlinks
	
	Update_File "modmonstats_www.asp"
	Update_File "redirect.htm"
	Update_File "addons.png"
	Update_File "chart.js"
	Update_File "chartjs-plugin-zoom.js"
	Update_File "chartjs-plugin-annotation.js"
	Update_File "chartjs-plugin-datasource.js"
	Update_File "hammerjs.js"
	Update_File "moment.js"
	
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_script create
	
	Clear_Lock
}

Menu_Startup(){
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_script create
	Create_Dirs
	Create_Symlinks
	Mount_WebUI
	Clear_Lock
}

Menu_GenerateStats(){
	Generate_Stats
	Clear_Lock
}

Menu_Update(){
	Update_Version
	Clear_Lock
}

Menu_ForceUpdate(){
	Update_Version force
	Clear_Lock
}

Menu_Uninstall(){
	Print_Output "true" "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_Cron delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Shortcut_script delete
	Get_WebUI_Page "$SCRIPT_DIR/modmonstats_www.asp"
	if [ -n "$MyPage" ] && [ "$MyPage" != "none" ] && [ -f "/tmp/menuTree.js" ]; then
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		umount /www/require/modules/menuTree.js
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		rm -rf "{$SCRIPT_WEBPAGE_DIR:?}/$MyPage"
	fi
	rm -f "$SCRIPT_DIR/modmonstats_www.asp" 2>/dev/null
	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	while true; do
		printf "\\n\\e[1mDo you want to delete %s stats? (y/n)\\e[0m\\n" "$SCRIPT_NAME"
		read -r "confirm"
		case "$confirm" in
			y|Y)
				rm -rf "$SCRIPT_DIR" 2>/dev/null
				break
			;;
			*)
				break
			;;
		esac
	done
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output "true" "Uninstall completed" "$PASS"
}

if [ -z "$1" ]; then
	Create_Dirs
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_script create
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
		Check_Lock
		Menu_Startup
		exit 0
	;;
	generate)
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME" ]; then
			Check_Lock
			Menu_GenerateStats
		elif [ -z "$2" ] && [ -z "$3" ]; then
			Check_Lock
			Menu_GenerateStats
		fi
		exit 0
	;;
	update)
		Check_Lock
		Menu_Update
		exit 0
	;;
	forceupdate)
		Check_Lock
		Menu_ForceUpdate
		exit 0
	;;
	uninstall)
		Check_Lock
		Menu_Uninstall
		exit 0
	;;
	*)
		Check_Lock
		echo "Command not recognised, please try again"
		Clear_Lock
		exit 1
	;;
esac
