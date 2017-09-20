#!/bin/bash

#-------------xen_install_V1.0.2-------------
#for Hetzner's servers with default Debian installation with static network settings

#-------------common variables-------------
#1 - log file name
log_file_name="xen_installation.log"
#2 - admin's e-mails
admin_email="e.vasilev@scout-gps.ru" #may use comma to separate addresses
#3 - time format
time_format="[`date +"%Y/%m/%d %H:%M:%S"`]:"
#4 - need to be root? 1 - Yes, 0 - No
need_to_be_root=1

#-------------basic_template_V1.0.2-------------
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
        if [ 0 -ne $? ]
                then
						echo "${time_format} $1 - Error!!! Full command for debug: $2" &>> ${log_file_name}
						mail -s "ERROR!!! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name}
                else
						echo "${time_format} $1 - Success" &>> ${log_file_name}
        fi
		#if you need to ignore exit code and continue work, define third variables. Example: execute command "Show date" "date 123" 1
		if [ 0 -ne $? -a 1 -eq $3 ]
				then exit
		fi
}

#need to set ${need_to_be_root}
function run_by_root {
		if [ 0 -ne "$( id -u )" -a 1 -eq "${need_to_be_root}" ]
				then echo "${time_format} Need to be root. Exit..." &>> ${log_file_name} ; mail -s "${time_format} Need to be root! `hostname -f` - $BASH_SOURCE" ${admin_email} < ${log_file_name} ; exit
		fi
}

#-------------task-dependent parameters-------------
#some variables and functions

#-------------script start-------------
echo "${time_format} $BASH_SOURCE starting work" &> ${log_file_name}
run_by_root

if [ 0 -eq "$( egrep '(vmx|svm)' /proc/cpuinfo | wc -l )" ]
		then echo "${time_format} Warning!!! This server haven't hardware virtualization support" &>> ${log_file_name}
fi

echo "${time_format} Info! This script has optimized for configuring Hetzner's default Debian installation" &>> ${log_file_name}

execute_command "Install XEN-related packages" "apt-get -q -y install xen-linux-system"

execute_command "Configure GRUB" "dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen"

execute_command "Update GRUB" "update-grub"

echo "${time_format} Xen installation has finished. Done..." &>> ${log_file_name}

echo "${time_format} Network configure starting..." &>> ${log_file_name}

echo "${time_format} Save network settings" &>> ${log_file_name}
123

execute_command "Backup network settings" "mv /etc/network/interfaces /etc/network/interfaces.backup"

execute_command "Bridge create" "brctl addbr xenbr0"

#Attention! After this step email will not send if error has occured. Use local log file for debug.
#But if ping to server will be successfull, script worked fine.
execute_command "Add interface to bridge" "brctl addif xenbr0 eth0"

echo "${time_format} Change network settings" &>> ${log_file_name}
cat <<'EOF' > /etc/network/interfaces
auto lo
iface lo inet loopback
iface lo inet6 loopback

iface eth0 inet manual

auto xenbr0
iface xenbr0 inet static
  address 88.99.97.158
  netmask 255.255.255.192
  gateway 88.99.97.129
  # route 88.99.97.128/26 via 88.99.97.129
  up route add -net 88.99.97.128 netmask 255.255.255.192 gw 88.99.97.129 dev eth0

iface xenbr0 inet6 static
  address 2a01:4f8:221:d9d::2
  netmask 64
  gateway fe80::1
EOF

cat <<'EOF' >> /etc/sysctl.conf
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
EOF

execute_command "Configure kernel" "sysctl -p /etc/sysctl.conf"

execute_command "Network restart" "service networking restart"

echo "${time_format} Network configuring has finished. Done..." &>> ${log_file_name}

echo "${time_format} $BASH_SOURCE has finished work. Reboot..." &>> ${log_file_name}

reboot