#!/bin/bash

#-------------task-dependent parameters-------------
#some variables and functions

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#-------------xen_install_V1.0.3-------------
#for Hetzner's servers with default Debian installation with static network settings

#-------------common variables-------------
#1 - log file name
log_file_name="xen_installation.log"
#2 - admin's e-mails
admin_email="change_me" #may use comma to separate addresses
#3 - time format
time_format="[`date +"%Y/%m/%d %H:%M:%S"`]:"
#4 - need to be root? 1 - Yes, 0 - No
need_to_be_root=1

#time format
function time_format {
	echo "[`date +"%Y/%m/%d %H:%M:%S"`]:"
}

#$1 - package name, example: check_package "mailutils"
function check_package {
	if [ 0 -eq "$( dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "install ok installed" )" ]
		then
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

#execute command and check exit code
#$1 - description of task, $2 - command, $3 - set 1 to ignore error exit code. Example: execute_command "Show inodes statistic" "df -hi"
function execute_command {
    #execute command
    $2 2>> ${log_file_name} 1> /dev/null
    #check exit code
    if [ 0 -ne $? ]
		then
			if [[ 1 -ne $3 ]]
				then 
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
function run_by_root {
	if [ 0 -ne "$( id -u )" -a 1 -eq "${need_to_be_root}" ]
		then 
			echo $(time_format) "Need to be root. Exit..." >> ${log_file_name} ; mail -s "Need to be root! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name} ; exit
	fi
}

#-------------script start-------------
echo "${time_format} $BASH_SOURCE starting work" >> ${log_file_name}
run_by_root

#--
echo "${time_format} Check hardware virtualization support"
if [ 0 -eq "$( egrep '(vmx|svm)' /proc/cpuinfo | wc -l )" ]
	then
		echo "${time_format} Warning!!! This server haven't hardware virtualization support" >> ${log_file_name}
fi

#--
echo "${time_format} Info! This script has optimized for configuring Hetzner's default Debian installation" >> ${log_file_name}

#--
execute_command "Install XEN" "apt-get -q -y install xen-linux-system-amd64 xen-tools"
execute_command "Configure GRUB" "dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen"
execute_command "Update GRUB" "update-grub"
echo "${time_format} Warning! Reboot needed!" >> ${log_file_name}
echo "${time_format} Xen installation has finished. Done..." >> ${log_file_name}

#--
echo "${time_format} Network configure starting..." >> ${log_file_name}
execute_command "Backup network settings" "mv /etc/network/interfaces /etc/network/interfaces.backup"
echo "${time_format} Configuring /etc/network/interfaces" >> ${log_file_name}
cat /etc/network/interfaces.backup > /etc/network/interfaces
sed -i 's/eth0/xenbr0/' /etc/network/interfaces
sed -i '/iface xenbr0 inet static/ a\  bridge_ports eth0' /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "auto eth0" >> /etc/network/interfaces
echo "iface eth0 inet manual" >> /etc/network/interfaces
echo "${time_format} Network configuring has finished. Done..." >> ${log_file_name}

#--
echo "${time_format} $BASH_SOURCE has finished work. Reboot..." >> ${log_file_name}

#--
reboot
