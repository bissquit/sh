#!/bin/bash
#=========================================================================
#         FILE: basic_template_V1.2.0.sh
#
#        USAGE: 
#
#  DESCRIPTION: contain several function for formatting output and analize
#               exit code of certain single commands (if needed)
#
#        NOTES: do not use as single script; this is only a template
#       AUTHOR: E.S.Vasilyev
#      VERSION: 1.2.0
#      CREATED: 18.10.2017
#=========================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#-------------------------------------------------------------------------
# common variables; do not include task-dependent params in this section
#-------------------------------------------------------------------------

log_file_name=$( sed 's/^\.\///' <<< $BASH_SOURCE.log ) # log file name
admin_email="change_me"						# admin's e-mails; use comma to separate addresses
time_format="[`date +"%Y/%m/%d %H:%M:%S"`]:"# time format
need_to_be_root=1							# need to be root? 1 - Yes, 0 - No

#=========================================================================
#  DESCRIPTION: display time in certain ouput format
#				e.d. [2017/10/19 11:02:39]:
#=========================================================================
function time_format {
	echo "[`date +"%Y/%m/%d %H:%M:%S"`]:"
}

#=========================================================================
#  DESCRIPTION: check package and install if it doesn't installed
#  PARAMETER 1: package name (e.g. nano)
#=========================================================================
function check_package {
	if [ 0 -eq "$( dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "install ok installed" )" ] ; then
		echo $(time_format) "$1 has not installed. Installation starts after 10 second!" >> ${log_file_name}
		sleep 10
		echo $(time_format) "Execute apt-get update" >> ${log_file_name}
		apt-get update 2>> ${log_file_name} 1> /dev/null
		echo $(time_format) "$1 installation" >> ${log_file_name}
		apt-get install -q -y $1 2>> ${log_file_name} 1> /dev/null
	else 
		echo $(time_format) "$1 has been installed" >> ${log_file_name}
	fi
}

check_package "mailutils"

#=========================================================================
#  DESCRIPTION: check package and install if it doesn't installed
#  PARAMETER 1: description of task
#  PARAMETER 2: command
#  PARAMETER 3: set 1 to ignore error exit code
#=========================================================================
function execute_command {
    #execute command
    $2 2>> ${log_file_name} 1> /dev/null
    #check exit code
    if [ 0 -ne $? ] ; then
		if [ -z $3 ] ; then
			echo $(time_format) "$1 - Error!!! Full command for debug: $2" >> ${log_file_name}
			mail -s "ERROR!!! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name}
			exit
		else
			echo $(time_format) "Previous command has returned error, but need to continue script execution" >> ${log_file_name}
		fi
	else
		echo $(time_format) "$1 - Success" >> ${log_file_name}
	fi
}

#need to set ${need_to_be_root}

#=========================================================================
#  DESCRIPTION: check root permissions
#=========================================================================
function run_by_root {
	if [ 0 -ne "$( id -u )" -a 1 -eq "${need_to_be_root}" ] ; then
		echo $(time_format) "Need to be root. Exit..." >> ${log_file_name}
		mail -s "Need to be root! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name}
		exit
	fi
}

#-------------------------------------------------------------------------
# script start
#-------------------------------------------------------------------------
echo "${time_format} $BASH_SOURCE starting work" >> ${log_file_name}
run_by_root

#-------------------------------------------------------------------------
# some task-dependent variables and functions
#-------------------------------------------------------------------------






#-------------------------------------------------------------------------
# script finished
#-------------------------------------------------------------------------
mail -s "${time_format} 123" ${admin_email} < ${log_file_name}
