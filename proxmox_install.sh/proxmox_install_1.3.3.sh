#!/bin/bash
#=========================================================================
#         FILE: proxmox_install_1.3.3.sh
#
#        USAGE: ./proxmox_install_1.3.3.sh [ preffered hostname ]
#
#  DESCRIPTION: Proxmox installation. Script has optimized for Hetzner's
#               servers with single network interface.
#
#        NOTES: 
#       AUTHOR: E.S.Vasilyev - bq@bissquit.com; e.s.vasilyev@mail.ru
#      VERSION: 1.3.3
#      CREATED: 03.11.2017
#=========================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#-------------------------------------------------------------------------
# common variables; do not include task-dependent params in this section
#-------------------------------------------------------------------------

log_file_name="$( sed 's/.*\/\(.*\)/\1/' <<< "$BASH_SOURCE.log" )" # log file name
admin_email="bq@bissquit.com"				# admin's e-mails; use comma to separate addresses
need_to_be_root=1					# need to be root? 1 - Yes, 0 - No

#=========================================================================
#  DESCRIPTION: display time in certain ouput format
#		e.d. [2017/10/19 11:02:39]:
#=========================================================================
function time_format {
	printf -- '%s' "[$(date +"%Y/%m/%d %H:%M:%S")]:"
}

#=========================================================================
#  DESCRIPTION: check package and install if it doesn't installed
#  PARAMETER 1: package name (e.g. nano)
#=========================================================================
function check_package {
	if [ 0 -eq "$( dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "install ok installed" )" ]; then
		printf -- '%s\n' "$(time_format) $1 has not installed. Installation starts after 10 second!" >> "$log_file_name"
		sleep -- 10
		printf -- '%s\n' "$(time_format) Execute apt-get update" >> "$log_file_name"
		apt-get update >> "$log_file_name"
		printf -- '%s\n' "$(time_format) $1 installation" >> "$log_file_name"
		apt-get install -q -y "$1" >> "$log_file_name"
	else
		printf -- '%s\n' "$(time_format) $1 has been installed" >> "$log_file_name"
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
	$2 >> "$log_file_name"
	#check exit code
	if [ 0 -ne "$?" ]; then
		if [ -z "$3" ]; then
			printf -- '%s\n' "$(time_format) $1 - Error!!! Full command for debug: $2" >> "$log_file_name"
			mail -s "ERROR!!! $(hostname -f) - $BASH_SOURCE" "$admin_email" < "$log_file_name"
			exit
		else
			printf -- '%s\n' "$(time_format) Previous command has returned error, but need to continue script execution" >> "$log_file_name"
		fi
	else
		printf -- '%s\n' "$(time_format) $1 - Success" >> "$log_file_name"
	fi
}

#=========================================================================
#  DESCRIPTION: check root permissions
#  need to set ${need_to_be_root}
#=========================================================================
function run_by_root {
	if [ 0 -ne "$( id -u )" -a 1 -eq "${need_to_be_root}" ]; then
		printf -- '%s\n' "$(time_format) Need to be root. Exit..." >> "$log_file_name"
		mail -s "Need to be root! $(hostname -f) - $BASH_SOURCE" "$admin_email" < "$log_file_name"
		exit
	fi
}

#-------------------------------------------------------------------------
# script start
#-------------------------------------------------------------------------
printf -- '%s\n' "$(time_format) $BASH_SOURCE starting work" >> "$log_file_name"
run_by_root

#-------------------------------------------------------------------------
# some task-dependent variables and functions
#-------------------------------------------------------------------------

# https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_Stretch

proxmox_hostname="$1"				# set new hostname
iso_storage_path="/var/iso"			# path for iso image storage
firewall_script_path="./firewall_proxmox.sh"	# path to optional iptables script
if_name="$( sed -r '/auto [^lo]/!d;s/auto (.*)/\1/' /etc/network/interfaces )" # get interface name

#-------------------------------------------------------------------------
# redefine /etc/hosts ( need for proper Proxmox installation ) and
# change hostname
#-------------------------------------------------------------------------
printf -- '%s\n' "$(time_format) Change hostname to $proxmox_hostname" >> "$log_file_name"
# bash variable substitution in sed: be carefull with regex patterns in filename
sed -i 's/'"$(hostname)"'/'"$proxmox_hostname"'/' -- "/etc/hosts"
printf -- '%s\n' "$proxmox_hostname" > "/etc/hostname"
execute_command "Run hostnamectl" "hostnamectl set-hostname $proxmox_hostname"

#-------------------------------------------------------------------------
# add repo
#-------------------------------------------------------------------------
printf -- '%s\n' "deb http://download.proxmox.com/debian/pve stretch pve-no-subscription" > "/etc/apt/sources.list.d/pve-install-repo.list"
wget -- http://download.proxmox.com/debian/proxmox-ve-release-5.x.gpg -O "/etc/apt/trusted.gpg.d/proxmox-ve-release-5.x.gpg"

#-------------------------------------------------------------------------
# create answer files
#-------------------------------------------------------------------------
printf -- '%s\n' "postfix postfix/main_mailer_type string Internet site" > "postfix_silent_install.txt"
printf -- '%s\n' "postfix postfix/mailname string localhost.localdomain" >> "postfix_silent_install.txt"
printf -- '%s\n' "iptables-persistent iptables-persistent/autosave_v4 boolean true" > "iptables-persistent_silent_install.txt"
printf -- '%s\n'  "iptables-persistent iptables-persistent/autosave_v6 boolean true" >> "iptables-persistent_silent_install.txt"
debconf-set-selections -- "postfix_silent_install.txt"
debconf-set-selections -- "iptables-persistent_silent_install.txt"

#-------------------------------------------------------------------------
# Proxmox installation
#-------------------------------------------------------------------------
execute_command "Repo update" "apt-get update"
DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade >> "$log_file_name"
execute_command "Proxmox installation" "apt-get install -y proxmox-ve postfix open-iscsi"

#-------------------------------------------------------------------------
# bridge configuring
#-------------------------------------------------------------------------
printf -- '%s\n' "$(time_format) Bridge configure" >> "$log_file_name"
cat "/etc/network/interfaces" > "/etc/network/interfaces.backup"
# bash variable substitution in sed: be carefull with regex patterns in filename
sed -i 's/'"$if_name"'/vmbr0/' -- "/etc/network/interfaces"
sed -i 's/auto vmbr0/auto vmbr0\nallow-hotplug vmbr0/' -- "/etc/network/interfaces"
sed -i '/iface vmbr0 inet.*/ a\  bridge_ports '"$if_name"'' -- "/etc/network/interfaces"
printf -- '%s\n' "" >> "/etc/network/interfaces"
printf -- '%s\n' "auto $if_name" >> "/etc/network/interfaces"
printf -- '%s\n' "allow-hotplug $if_name" >> "/etc/network/interfaces"
printf -- '%s\n' "iface $if_name inet manual" >> "/etc/network/interfaces"

#-------------------------------------------------------------------------
# create local iso storage
# https://pve.proxmox.com/wiki/Storage
# https://pve.proxmox.com/pve-docs/pvesm.1.html
#-------------------------------------------------------------------------
printf -- '%s\n' "$(time_format) Configuring local iso storage" >> "$log_file_name"
mkdir -- "$iso_storage_path"
execute_command "Configure iso storage" "pvesm add dir iso --path $iso_storage_path --content iso" "1"
#pvesm add dir iso --path "${iso_storage_path}" --content iso
printf -- '%s\n' "$(time_format) INFO: Put your iso images in ${iso_storage_path}/template/iso" >> "$log_file_name"

#-------------------------------------------------------------------------
# iptables definition. This step will be omitted if file
# $firewall_script_path does not exist
#-------------------------------------------------------------------------
check_package "iptables-persistent"
if [ -f "$firewall_script_path" ]; then
	printf -- '%s\n' "$(time_format) Configure firewall rules" >> "$log_file_name"
	bash "$firewall_script_path" 2>> "$log_file_name"
	iptables-save > "/etc/iptables/rules.v4" 2>> "$log_file_name"
	ip6tables-save > "etc/iptables/rules.v6" 2>> "$log_file_name"
	printf -- '%s\n' "$(time_format) Iptables configuring has finished. Done..." >> "$log_file_name"
else
	printf -- '%s\n' "$(time_format) WARNING!!! Firewall script is missing. Any rules does not apply" >> "$log_file_name"
fi

#-------------------------------------------------------------------------
# script finished
#-------------------------------------------------------------------------
printf -- '%s\n' "$(time_format) $BASH_SOURCE has finished work. Reboot..." >> "$log_file_name"
mail -s "$(time_format) 123" "$admin_email" < "$log_file_name"
reboot
