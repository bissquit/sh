#!/bin/bash

#-------------V 1.0.1-------------

#-------------common variables-------------
#1 - log file name
log_file_name="change_me"
#2 - admin's e-mails
admin_email="change_me" #may use comma to separate addresses
#3 - time format
time_format="[`date +"%Y/%m/%d %H:%M:%S"`]:"
#4 - need to be root? 1 - Yes, 0 - No
need_to_be_root=1

#-------------static functions-------------
#$1 - package name, example: check_package "mailutils"
function check_package {
        if [ 0 -eq "$( dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "install ok installed" )" ]
                then
                        echo "${time_format} $1 has not installed. Installation starts after 10 second!" &>> ${log_file_name}
                        sleep 10
                        echo "${time_format} Execute apt-get update" 
						apt-get update
						echo "${time_format} $1 installation"
						apt-get install -q -y $1
                else echo "${time_format} $1 has been installed" &>> ${log_file_name}
        fi
}
check_package "mailutils"

#execute command and check exit code
#$1 - description of task, $2 - command, example: execute_command "Show inodes statistic" "df -hi"
function execute_command {
        #execute command
        $2 &>> ${log_file_name}
        #check exit code
        if [ $?  != 0 ]
                then echo "${time_format} $1 - Error, exit..." && echo "${time_format} Full command for debug: $2" &>> ${log_file_name} ; mail -s "ERROR!!! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name} ; exit
                else echo "${time_format} $1 - Success" &>> ${log_file_name}
        fi
}

#need to set ${need_to_be_root}
function run_by_root {
		if [ 0 -ne "$( id -u )"  -a 1 -eq "${need_to_be_root}" ]
				then echo "${time_format} Need to be root. Exit..." &>> ${log_file_name} ; mail -s "${time_format} Need to be root! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name} ; exit
		fi
}

#-------------task-dependent parameters-------------
#some variables and functions

#-------------script start-------------
echo "${time_format} $BASH_SOURCE starting work" &> ${log_file_name}
#run_by_root