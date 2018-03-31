: #---------------definition (linux)-----------------------
: # LOG_TMPDIR     : temporary log directory
:; LOG_TMPDIR=/sdcard/htclog/routeinfo/tmp
:<<"::CMDLITERAL"
@ECHO OFF
REM ---------------definition (windows)---------------------
set LOG_TMPDIR=/sdcard/htclog/routeinfo/tmp
GOTO :CMDSCRIPT
::CMDLITERAL
#---------------change history------------------------------
#nucca@20170124: change temporary directory to avoid file explorer UI flickering
#				 because it is monitoring root folder of /sdcard
#				 TMPDIR: /sdcard --> /sdcard/htclog/routeinfo/tmp
#terry_lu@20170109: Don't resolve domain name in netstat command for power issue
#				 add "-n" option to netstat to avoid DNS PTR packet
#nucca@20160829: execute ip and ip[6]tables with interval.
#				 continuous execution may block corresponding command with
#				 hundreds of milliseconds. If device is busy, the blocking time
#				 may increase. A short delay could help to improve it.
#nucca@20160824: merge command from QCT's "iptables_rules_routes_v2.bat"
#				 cat /proc/net/xfrm_stat
#nucca@20160815: change output folder from /data to /sdcard
#				 because daemon may have no permission to access /sdcard
#junyu@20150727: add dumpsys package for uid<->package mapping
#junyu@20150721: add /proc/ip_tables_targets for iptables targets
#junyu@20150626: add dumpsys connectivity
#junyu@20150623: add dumpsys netpolicy & netstats
#nucca@20150528: add iptables -t security
#junyu@20150425: add netd log (dumpsys network_management)
#junyu@20150425: adjuct format of iface specific files
#junyu@20141201: initial release
#junyu@20141217: add /proc/sys/net/ipv6/conf/*/accept_ra_defrtr
#junyu@20150205: add
#	/proc/sys/net/ipv4/ip_local_reserved_ports
#	/proc/sys/net/ipv4/ip_local_port_range
#	/proc/sys/net/ipv4/tcp_fin_timeout
#junyu@20150206: add ip ro sh table 9 for ims
#junyu@20150327: print routing table based on ip ru parsing result
#---------------release note--------------------------------
#For Users:
# For this issue, we'll need routing information at issue happen time.
# Please kindly help to follow below steps to collect routing information for us:
# 1. enable htclog/network traffic log from device boot up
# 2. connect device to PC with USB cable, and install driver if necessary
# 3. make sure USB debugging notification is shown on device title bar
# 4. reproduce issue
# 5. run(double click) attached script at issue happen time
# 6. collect RouteInfo.txt generated by script or feedback problem if there is any error message
# 7. collect htclog/network traffic log from device
# 8. feedback logs and timestamp for us to analysis
# Thanks.
#For Developers:
# 1. the script can be run in linux, windows and android
# 2. use dos2unix to remove newline before release
# 3. if you are using embedded tty inside non-root device, invoke with TMPDIR=~ /data/routeinfo
#---------------below is linux common part------------------
function main()
{
	if [ "$SHELL" == "/bin/bash" ]; then
		linux_main $*
	else
		android_main
	fi
}

#---------------below is linux host part--------------------

#Function	: 1. push script into device  2.run  3.collect file
function linux_main(){
	# this is linux pc
	adb wait-for-device root
	adb wait-for-device
	adb push $0 /data/routeinfo
	adb shell TMPDIR=/data /data/routeinfo
	decideOutputName $1
	adb pull $LOG_TMPDIR/RouteInfo.txt ${RET}
	echo "Output: ${RET}"
}

#Function	:
#Input		: 1. use $1 as file name prefix if available
#		  2. use [device]_[changelist]_ as file name prefix if available
#Output	$RET	: prefix
function decideOutputName(){
	test -n "$1" && RET=$1 && return
	local CL=`adb shell getprop ro.build.changelist | sed 's/[^0-9]//g'`
	local DEV=`adb shell getprop ro.build.product | sed 's/[^0-9A-Za-z]//g'`
	RET=`echo ${DEV}_${CL}_RouteInfo.txt`
}

#---------------below is android part-----------------------
function android_main(){
	create_temporary_directory
	dump_all > $LOG_TMPDIR/RouteInfo.txt 2>&1
}

function dump_all(){
	dump_misc
	dump_service
	dump_config
	dumpV4
	dumpV6
	dump_bridge
	dump_tc
}

function dump_header(){
	echo "====================================================="
	echo "$1"
	echo "====================================================="
}

function dump_misc(){
	dump_header "[Route Info v5.0]"

	#use here document syntax to simplify commands
	while read LINE; do logcmd $LINE; done <<CMDLIST
	date
	getprop
	netcfg
	netstat -n
	ip xfrm policy show
	ip xfrm state show
	cat /proc/net/xfrm_stat
	getenforce
CMDLIST
}

function dump_service(){
	dump_header "[Service]"
	#use here document syntax to simplify commands
	while read LINE; do logcmd dumpsys $LINE; done <<CMDLIST
	connectivity
	network_management
	netstats --uid --tag
	netpolicy
	package --checkin
CMDLIST
}

function dump_bridge(){
	dump_header "[Bridge]"
	while read LINE; do logcmd $LINE; done <<CMDLIST
	ebtables -t nat -L
	ebtables -t filter -L
	ebtables -t broute -L
	brctl show
	brctl showmacs bridge0
	brctl showstp bridge0
CMDLIST
}

function dump_tc(){
	dump_header "[Traffic Control]"
	while read LINE; do logcmd $LINE; done <<CMDLIST
	tc -s -d -r -p qdisc show
	tc -s -d -r -p class show dev rmnet0
	tc -s -d -r -p class show dev bridge0
	tc -s -d -r -p class show dev usb0
	tc filter show dev rmnet0
	tc filter show dev bridge0
	tc filter show dev usb0
CMDLIST
}

function dump_config(){
	dump_header "[Configuration]"
	#for long file
	while read LINE ; do logcmd cat $LINE ; done <<CONFLIST
	/data/misc/dhcp/dnsmasq.leases
	/proc/net/arp
	/proc/net/dev_snmp6/rmnet0
	/proc/net/dev_snmp6/bridge0
	/proc/net/dev_snmp6/usb0
	/proc/net/xt_qtaguid/iface_stat_fmt
	/proc/net/xt_qtaguid/iface_stat_all
	/proc/net/ip_tables_matches
	/proc/net/ip_tables_targets
	/sys/kernel/debug/tracing/events/net/enable
	/sys/module/xt_qtaguid/parameters/debug_mask
	/sys/module/msm_rmnet_bam/parameters/debug_enable
	/sys/module/bam_dmux/parameters/debug_enable
	/data/misc/net/rt_tables
CONFLIST

	#for short file
	while read LINE ; do logcmd_inline cat $LINE ; done <<CONFLIST
	/proc/sys/net/ipv4/ip_forward
	/proc/sys/net/ipv4/icmp_echo_ignore_all
	/proc/sys/net/ipv6/conf/all/forwarding
	/proc/sys/net/ipv4/fwmark_reflect
	/proc/sys/net/ipv6/fwmark_reflect
	/proc/sys/net/ipv4/tcp_fwmark_accept
	/proc/sys/net/ipv4/ip_local_reserved_ports
	/proc/sys/net/ipv4/ip_local_port_range
	/proc/sys/net/ipv4/tcp_fin_timeout
CONFLIST

	#for interface specific file
	local IFLIST=`ls /proc/sys/net/ipv6/conf/`
	echo "IFLIST=$(echo $IFLIST)"
	while read LINE ; do
		unset OUTPUT
		for f in $IFLIST; do
			LINE2=${LINE/IFNAME/$f}
			OUTPUT+=" `cat $LINE2`"
#			logcmd_inline cat $LINE2;
		done
		echo "$LINE --> $OUTPUT";
	done <<CONFLIST
	/proc/sys/net/ipv6/conf/IFNAME/use_tempaddr
	/proc/sys/net/ipv6/conf/IFNAME/disable_ipv6
	/proc/sys/net/ipv6/conf/IFNAME/accept_ra_rt_table
	/proc/sys/net/ipv6/conf/IFNAME/accept_ra_defrtr
CONFLIST
}

function dumpV4()
{
	dump_header "[IPv4]"
	executeAndWaitDelay logcmd ip addr
	executeAndWaitDelay logcmd ip rule list
	getRtNames
	for f in $RET; do
		executeAndWaitDelay logcmd ip route show table $f
	done
	executeAndWaitDelay logcmd iptables -t raw -nvL
	executeAndWaitDelay logcmd iptables -t nat -nvL
	executeAndWaitDelay logcmd iptables -t filter -nvL
	executeAndWaitDelay logcmd iptables -t mangle -nvL
	executeAndWaitDelay logcmd iptables -t security -nvL
}

function dumpV6()
{
	dump_header "[IPv6]"
	executeAndWaitDelay logcmd ip -6 addr
	executeAndWaitDelay logcmd ip -6 link
	executeAndWaitDelay logcmd ip -6 neigh sh
	executeAndWaitDelay logcmd ip -6 rule list
	getRtNames
	for f in $RET; do
		executeAndWaitDelay logcmd ip -6 route show table $f
	done
	executeAndWaitDelay logcmd ip6tables -t raw -nvL
	executeAndWaitDelay logcmd ip6tables -t nat -nvL
	executeAndWaitDelay logcmd ip6tables -t filter -nvL
	executeAndWaitDelay logcmd ip6tables -t mangle -nvL
}

#Function	:	print cmd itself and its execute result
#Input $*	:	command
#Output			: None
function logcmd() {
	echo "----- $* -----"
	$*
	echo " "
}

function logcmd_inline() {
	echo -n "$* --> "
	$*
}

#Function	: get nth column of a line
#Input $1	: n
#      $2~	: params
#Output $RET: n>0 nth parameter count from start; n<0 nth parameter count from end
function getNthParam(){
	local N=$1
	shift
	RET=
	ARR=($*)
	if [ $N -lt 0 ]; then
		local SIZE=${#ARR[@]}
		RET=${ARR[SIZE+N]}
	else
		RET=${ARR[N-1]}
	fi
}

#Function		: get routing table name list
#Output $RET: routing table name list
function getRtNames(){
	local MYRET=

	#if fail, parse from ip ru result
	while read LINE; do
		if echo $LINE | grep -q -v lookup; then
			continue;
		fi
		getNthParam -1 $LINE
		test `echo $MYRET | grep $RET -c` -ne 1 && MYRET+="$RET "
	done << EOF
	`ip ru`
EOF
	RET=$MYRET
	return
}

#Function	: Execute command and delay a specified number of
#			  seconds ($INTERVAL_IN_SECOND) before next command execution
#Input $*	: command which needs to be executed
#Output		: (none)
#Description: The continuous execution may block corresponding command with
#			  hundreds of milliseconds. If device is busy, the blocking time
#			  may increase. A short delay could help to improve it.
function executeAndWaitDelay(){
	local DELAY_IN_SECOND=0.1
	$*
	sleep $DELAY_IN_SECOND
}

#Function	: Create temporary directory $LOG_TMPDIR for generated temporary files
#Input		: (none)
#Output		: (none)
function create_temporary_directory(){
    if [ -d $LOG_TMPDIR ]
    then
        echo "Directory $LOG_TMPDIR has existed."
    else
        echo "Directory $LOG_TMPDIR does not exist. Creating $LOG_TMPDIR.."
        mkdir -p $LOG_TMPDIR
    fi
}

main $*
exit

:CMDSCRIPT
REM ---------------this is windows part------------------
adb wait-for-device root
adb wait-for-device
adb push %0 /data/routeinfo
adb shell TMPDIR=/data /data/routeinfo
adb pull %LOG_TMPDIR%/RouteInfo.txt .
echo Output: RouteInfo.txt
pause
REM ---------------this is windows part------------------
