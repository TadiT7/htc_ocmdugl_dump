#---------------change history-----------------------------
# nucca@20170412: merge several logs into a single log. log files are rotated
#                 when they grow bigger than 5MB ($LOG_ROTATE_SIZE). Each log
#                 is separated by $LOG_LINEBREAK. Some definitions are modified
#                 for this change
#                 LOG_PREFIX : RouteInfo --> routeinfo
#                 LOG_LIMIT  : 900 --> 36
# nucca@20161230: change temporary directory to avoid file explorer UI flickering
#                 because it is monitoring root folder of /sdcard
#                 TMPDIR: /sdcard --> /sdcard/htclog/routeinfo/tmp
# nucca@20161125: 1. change definition
#                    maximum number of log files: 300 --> 900
#                    log path: /sdcard/htclog --> /data/htclog/routeinfo
#                 2. change log permission to 777 for adb pull
#                 3. when high watermark of log amount ($LOG_LIMIT * 1.1) is reached,
#                    the oldest log files are deleted until log amount is less than
#                    $LOG_LIMIT.
# nucca@20160815: initial release
#

#---------------release note-------------------------------
#For user:
# This script invokes dump_route_info.cmd to get route
# information repeatedly. The oldest logs will be deleted
# when log amount limit is reached
#
#For developer:
# 1. use dos2unix to remove newline before release
#

#---------------definition---------------------------------
# LOG_INTERVAL      : time interval, in seconds, of log capture
# LOG_LIMIT         : maximum number of log files
# LOG_PATH          : log path
# LOG_PREFIX        : prefix of log file name
# LOG_ROTATE_SIZE   : log rotate size by bytes
# LOG_LINEBREAK     : signifying the end of log and the start of a new log
#
LOG_INTERVAL=5
LOG_LIMIT=36
LOG_PATH=/data/htclog/routeinfo
LOG_PREFIX=routeinfo
LOG_ROTATE_SIZE=5242880
LOG_LINEBREAK=********************************************************************************

#---------------redirect temporary directory---------------
# dump_route_info.cmd need access temporary folder but it
# may not have permission to create temporary file on
# default temporary folder /data/local/. Besides system_app and system_server,
# other apps are partially limited to access \data by "system_data_file:file no_w_file_perms"
# in system\sepolicy\domain.te
#
# workaround: redirect temporary folder to /sdcard
#
export TMPDIR=/sdcard/htclog/routeinfo/tmp

#---------------main---------------------------------------
# main script entry
#
# Function  : main
# Input     : (none)
# Output    : (none)
#
function main(){
    create_temporary_directory
    create_log_directory

while true
do
    dump_route_info
    rotate_log_files

    sleep $LOG_INTERVAL
done
}

#---------------create temporary directory-----------------
# Create temporary directory $TMPDIR for generated temporary files
#
# Function  : create_temporary_directory
# Input     : (none)
# Output    : (none)
#
function create_temporary_directory(){
    if [ -d $TMPDIR ]
    then
        echo "Directory $TMPDIR has existed."
    else
        echo "Directory $TMPDIR does not exist. Creating $TMPDIR.."
        mkdir -p $TMPDIR
    fi
}

#---------------create log directory-----------------------
# Create log directory $LOG_PATH to save route information logs
#
# Function  : create_log_directory
# Input     : (none)
# Output    : (none)
#
function create_log_directory(){
    if [ -d $LOG_PATH ]
    then
        echo "Directory $LOG_PATH has existed."
    else
        echo "Directory $LOG_PATH does not exist. Creating $LOG_PATH.."
        mkdir -p $LOG_PATH
        chmod 777 $LOG_PATH
        restorecon $LOG_PATH
    fi
}

#---------------count log amount---------------------------
# because some sku doesn't have command "wc", the following line
# can't be invoked
# log count: $(find ./ -maxdepth 1 -name "${LOG_PREFIX}*.txt" | wc -l)
#
# workaround: count file amount manually by loop
#
# Function  : count_log_amount
# Input     : (none)
# Output    : $RET: current log amount
#
function count_log_amount(){
    RET=0
    for name in $(ls $LOG_PATH | grep $LOG_PREFIX)
    do
      echo "file #${RET}: $name"
      RET=$(( $RET + 1 ))
    done
}

#---------------dump routing information-------------------
# invoke "dump_route_info.cmd" to dump routing information and
# save logs to $LOG_PATH. Log files are rotated when they grow
# bigger than size bytes $LOG_ROTATE_SIZE
#
# Function  : dump_route_info
# Input     : (none)
# Output    : (none)
#
function dump_route_info(){
    local need_create_file=0

    count_log_amount
    local log_count=${RET}

    # creating new log decision
    # when no log exists or log rotate size is reached, create a new log file.
    # if the last log file doesn't reach log rotate size, attach current log to
    # it.
    if [ $log_count -eq 0 ]; then
        need_create_file=1;
    else
        local lastlog_path=$(ls $LOG_PATH/${LOG_PREFIX}*.txt -t 2>&1 | head -1)
        local lastlog_size=$(stat -c %s $lastlog_path)
        echo "last log inforamtion: $lastlog_path ($lastlog_size bytes)"

        if [ $lastlog_size -gt $LOG_ROTATE_SIZE ]; then
            need_create_file=1;
        else
            need_create_file=0;
        fi
    fi

    # dump route inforamtion
    dump_route_info.cmd

    # save route inforamtion
    if [ $need_create_file -eq 1 ]; then
        local current_date=`date +%Y%m%d_%H%M%S`
        local newlog_path=$LOG_PATH/${LOG_PREFIX}_$current_date.txt
        echo "$LOG_LINEBREAK" >> $newlog_path
        cat $TMPDIR/RouteInfo.txt >> $newlog_path
        chmod 777 $newlog_path

        echo "create file: $newlog_path"
    else
        echo "$LOG_LINEBREAK" >> $lastlog_path
        cat $TMPDIR/RouteInfo.txt >> $lastlog_path

        echo "attach file: $lastlog_path"
    fi
}

#---------------rotate log files---------------------------
# when high watermark of log amount ($LOG_LIMIT * 1.1) is reached,
# the oldest log files are deleted until log amount is less than $LOG_LIMIT.
# the high watermark is used for reducing the frequency of file deletion
# which may cause "adb pull" failed during pulling files.
#
# Function  : rotate_log_files
# Input     : (none)
# Output    : (none)
#
function rotate_log_files(){
    local high_watermark=$(($LOG_LIMIT*11/10))
    echo "high watermark of log amount is $high_watermark"
    count_log_amount
    local log_count=${RET}
    echo "log count: $log_count"
    if [ $log_count -gt $high_watermark ]; then
        echo "deleting the oldest logs because file amount is over high watermark ($high_watermark).."
        echo "log files will be deleted until log amount is under log limit ($LOG_LIMIT)"
        ls $LOG_PATH/${LOG_PREFIX}*.txt -t | sed -e "1,${LOG_LIMIT}d" | xargs rm -rf
    else
        echo "log amount is under high watermark ($high_watermark)"
    fi
}

#---------------main entry---------------------------------
#
main $*
exit